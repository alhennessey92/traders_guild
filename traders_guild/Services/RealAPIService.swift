//
//  RealAPIService.swift
//  traders_guild
//
//  Real API service for backend communication.
//  Uses DTOs that match backend Pydantic schemas exactly.
//
//  Supports multiple backend services (auth, core) with different ports in development.
//  In production, Kong routes everything through one URL.
//

import Foundation

// MARK: - API Configuration

enum APIEnvironment {
    case development
    case production
    
    static var current: APIEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

enum APIService {
    case auth    // Registration, login, tokens (port 8000)
    case core    // Users, guilds, memberships, etc. (port 8001)
    
    var baseURL: String {
        switch APIEnvironment.current {
        case .development:
            #if targetEnvironment(simulator)
            switch self {
            case .auth: return "http://localhost:8000/api/v1"
            case .core: return "http://localhost:8001/api/v1"
            }
            #else
            // ⚠️ UPDATE THIS to your Mac's IP for device testing
            let macIP = "192.168.1.182"
            switch self {
            case .auth: return "http://\(macIP):8000/api/v1"
            case .core: return "http://\(macIP):8001/api/v1"
            }
            #endif
            
        case .production:
            // Kong routes all services through one URL
            return "https://api.tradersguild.com/api/v1"
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case unauthorized
    case badRequest(String)
    case decodingError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .unauthorized: return "Please log in again"
        case .badRequest(let msg): return msg
        case .decodingError(let msg): return "Failed to parse response: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

// MARK: - Real API Service

class RealAPIService {
    
    // MARK: - Properties
    
    private var accessToken: String?
    private var refreshToken: String?
    
    /// Flag to prevent multiple simultaneous refresh attempts
    private var isRefreshingToken = false
    
    /// Callback when authentication fails completely (refresh token expired)
    /// RLAppState should set this to handle logout
    var onAuthenticationFailure: (() -> Void)?
    
    /// Callback when tokens are refreshed - allows RLAppState to update keychain
    var onTokensRefreshed: ((_ accessToken: String, _ refreshToken: String) -> Void)?
    
    // MARK: - JSON Decoder
    
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()
    
    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    // MARK: - Token Management
    
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
    }
    
    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
    }
    
    var isAuthenticated: Bool {
        accessToken != nil
    }
    
    // MARK: - Generic Request
    
    /// Main request method with automatic token refresh on 401
    private func request<T: Decodable>(
        _ endpoint: String,
        service: APIService = .core,
        method: String = "GET",
        body: Encodable? = nil,
        auth: Bool = false,
        isRetry: Bool = false  // Prevents infinite retry loops
    ) async throws -> T {
        guard let url = URL(string: "\(service.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if auth {
            guard let token = accessToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        #if DEBUG
        print("🌐 [\(service)] \(method) \(endpoint)")
        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            print("📤 Request: \(str)")
        }
        #endif
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        #if DEBUG
        print("📥 Status: \(httpResponse.statusCode)")
        if let str = String(data: data, encoding: .utf8)?.prefix(1000) {
            print("📥 Response: \(str)")
        }
        #endif
        
        // Handle error responses
        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = extractErrorDetail(from: data)
            
            switch httpResponse.statusCode {
            case 401:
                // Don't retry if this is already a retry or if it's a refresh/auth endpoint
                let isAuthEndpoint = endpoint.contains("/auth/")
                if !isRetry && auth && !isAuthEndpoint {
                    // Try to refresh token and retry the request
                    do {
                        try await performTokenRefresh()
                        #if DEBUG
                        print("🔄 Token refreshed, retrying request...")
                        #endif
                        // Retry with new token (mark as retry to prevent infinite loop)
                        return try await self.request(
                            endpoint,
                            service: service,
                            method: method,
                            body: body,
                            auth: auth,
                            isRetry: true
                        )
                    } catch {
                        #if DEBUG
                        print("❌ Token refresh failed: \(error)")
                        #endif
                        // Refresh failed - notify app to logout
                        await MainActor.run {
                            onAuthenticationFailure?()
                        }
                        throw APIError.unauthorized
                    }
                }
                throw APIError.unauthorized
            case 400, 422:
                throw APIError.badRequest(detail)
            default:
                throw APIError.serverError(httpResponse.statusCode, detail)
            }
        }
        
        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            #if DEBUG
            printDecodingError(error)
            #endif
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    /// Performs token refresh with locking to prevent multiple simultaneous refreshes
    private func performTokenRefresh() async throws {
        // If already refreshing, wait a bit and check if we have a new token
        if isRefreshingToken {
            #if DEBUG
            print("🔄 Token refresh already in progress, waiting...")
            #endif
            // Wait for the other refresh to complete (with timeout)
            for _ in 0..<20 { // 2 second timeout
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if !isRefreshingToken {
                    if accessToken != nil {
                        return // Another call refreshed successfully
                    }
                    break
                }
            }
            throw APIError.unauthorized
        }
        
        isRefreshingToken = true
        defer { isRefreshingToken = false }
        
        guard let refresh = refreshToken else {
            throw APIError.unauthorized
        }
        
        #if DEBUG
        print("🔄 Refreshing access token...")
        #endif
        
        let requestBody = RLRefreshTokenRequestDTO(refreshToken: refresh)
        
        // Direct request without auth (refresh endpoint doesn't need access token)
        guard let url = URL(string: "\(APIService.auth.baseURL)/auth/refresh") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("🔄 Token refresh failed with status: \(httpResponse.statusCode)")
            #endif
            throw APIError.unauthorized
        }
        
        let tokenResponse = try decoder.decode(RLTokenDTO.self, from: data)
        
        // Update tokens
        setTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
        
        // Notify RLAppState to update keychain
        await MainActor.run {
            onTokensRefreshed?(tokenResponse.accessToken, tokenResponse.refreshToken)
        }
        
        #if DEBUG
        print("✅ Token refreshed successfully")
        #endif
    }
    
    private func extractErrorDetail(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = json["detail"] as? String {
            return detail
        }
        return "Unknown error"
    }
    
    #if DEBUG
    private func printDecodingError(_ error: DecodingError) {
        print("❌ Decoding error:")
        switch error {
        case .keyNotFound(let key, let context):
            print("   Key '\(key.stringValue)' not found")
            print("   Path: \(context.codingPath.map { $0.stringValue })")
        case .typeMismatch(let type, let context):
            print("   Type '\(type)' mismatch")
            print("   Path: \(context.codingPath.map { $0.stringValue })")
        case .valueNotFound(let type, let context):
            print("   Value of type '\(type)' not found")
            print("   Path: \(context.codingPath.map { $0.stringValue })")
        case .dataCorrupted(let context):
            print("   Data corrupted: \(context.debugDescription)")
        @unknown default:
            print("   Unknown error: \(error)")
        }
    }
    #endif
    
    // ================================================================================================
    // MARK: - Auth Endpoints (port 8000)
    // ================================================================================================
    
    /// Register new user
    func register(data: RLSignupData) async throws -> RLRegistrationResponseDTO {
        let requestBody = data.toRequest()
        
        let response: RLRegistrationResponseDTO = try await request(
            "/auth/register",
            service: .auth,
            method: "POST",
            body: requestBody
        )
        
        // Store tokens
        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken)
        
        return response
    }
    
    /// Login with email and password
    func login(email: String, password: String) async throws -> RLLoginResponseDTO {
        let requestBody = RLLoginRequestDTO(email: email, password: password)
        
        let response: RLLoginResponseDTO = try await request(
            "/auth/login",
            service: .auth,
            method: "POST",
            body: requestBody
        )
        
        // Store tokens
        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken)
        
        return response
    }
    
    /// Refresh access token (manual call - usually automatic refresh handles this)
    func refreshAccessToken() async throws -> RLTokenDTO {
        try await performTokenRefresh()
        
        // Return current tokens as DTO
        guard let access = accessToken, let refresh = refreshToken else {
            throw APIError.unauthorized
        }
        
        return RLTokenDTO(
            accessToken: access,
            refreshToken: refresh,
            tokenType: "bearer",
            expiresIn: 3600 // Default, actual value came from server
        )
    }
    
    /// Logout
    func logout() async {
        // Try to call logout endpoint (ignore errors)
        do {
            let _: EmptyResponse = try await request(
                "/auth/logout",
                service: .auth,
                method: "POST",
                auth: true
            )
        } catch {
            #if DEBUG
            print("⚠️ Logout endpoint failed (ignoring): \(error)")
            #endif
        }
        
        // Always clear local tokens
        clearTokens()
    }
    
    // ================================================================================================
    // MARK: - User Endpoints (port 8001)
    // ================================================================================================
    
    /// Get current user profile
    func getCurrentUser() async throws -> RLUserDTO {
        return try await request(
            "/users/me",
            service: .core,
            auth: true
        )
    }
    
    /// Get user by ID
    func getUser(id: UUID) async throws -> RLUserDTO {
        return try await request(
            "/users/\(id.uuidString)",
            service: .core,
            auth: true
        )
    }
    
    // ================================================================================================
    // MARK: - Guild Endpoints (port 8001)
    // ================================================================================================
    
    /// Get user's guild memberships - Backend Implemented
    func getUserGuilds() async throws -> RLGuildListResponseDTO {
        return try await request(
            "/users/me/guilds",
            service: .core,
            auth: true
        )
    }
    
    /// Get guild by ID - Backend Implemented (Not tested)
    func getGuild(id: UUID) async throws -> RLGuildDTO {
        return try await request(
            "/guilds/\(id.uuidString)",
            service: .core,
            auth: true
        )
    }
    
    /// Get open guilds (for discovery) - Backend Implemented (Not tested)
    func getOpenGuilds() async throws -> [RLGuildDTO] {
        return try await request(
            "/guilds?is_open=true",
            service: .core,
            auth: true
        )
    }
    
    /// Join a guild - returns both guild and membership
    func joinGuild(guildId: UUID) async throws -> RLJoinGuildResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/join",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Create a new guild - returns both guild and membership
    func createGuild(name: String, description: String?, isOpen: Bool) async throws -> RLCreateGuildResponseDTO {
        let requestBody = RLCreateGuildRequestDTO(
            name: name,
            description: description,
            isOpen: isOpen
        )
        
        return try await request(
            "/guilds",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }
    
    /// Leave a guild
    func leaveGuild(guildId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/guilds/\(guildId.uuidString)/leave",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    // ================================================================================================
    // MARK: - Announcement Endpoints (port 8001)
    // ================================================================================================
    
    /// Get guild announcements
    func getGuildAnnouncements(guildId: UUID) async throws -> RLGuildAnnouncementsListDTO {
        print("🌐 getGuildAnnouncements: Calling API for guild \(guildId)")
        let result: RLGuildAnnouncementsListDTO = try await request(
            "/guilds/\(guildId.uuidString)/announcements",
            service: .core,
            auth: true
        )
        print("🌐 getGuildAnnouncements: API returned \(result.announcements.count) announcements")
        return result
    }
    
    /// Get single announcement
    func getAnnouncement(announcementId: UUID) async throws -> RLGuildAnnouncementWithAuthorDTO {
        return try await request(
            "/announcements/\(announcementId.uuidString)",
            service: .core,
            auth: true
        )
    }
    
    /// Create announcement (admin/mod only)
    func createAnnouncement(guildId: UUID, title: String, content: String, preview: String?, isImportant: Bool) async throws -> RLGuildAnnouncementWithAuthorDTO {
        let requestBody = RLCreateGuildAnnouncementRequestDTO(
            title: title,
            content: content,
            preview: preview,
            isImportant: isImportant
        )
        
        return try await request(
            "/guilds/\(guildId.uuidString)/announcements",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }
    
    /// Record announcement view (marks as read for current user)
    /// Requires both guildId and announcementId per backend API
    func recordAnnouncementView(guildId: UUID, announcementId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/guilds/\(guildId.uuidString)/announcements/\(announcementId.uuidString)/read",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    // ================================================================================================
    // MARK: - Event Endpoints (port 8001)
    // ================================================================================================
    
    /// Get guild events
    func getGuildEvents(guildId: UUID) async throws -> RLGuildEventsListDTO {
        print("🌐 getGuildEvents: Calling API for guild \(guildId)")
        let result: RLGuildEventsListDTO = try await request(
            "/guilds/\(guildId.uuidString)/events",
            service: .core,
            auth: true
        )
        print("🌐 getGuildEvents: API returned \(result.events.count) events")
        return result
    }
    
    /// Record event view (marks as read for current user)
    func recordEventView(guildId: UUID, eventId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/guilds/\(guildId.uuidString)/events/\(eventId.uuidString)/read",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Attend event (RSVP yes)
    func attendEvent(guildId: UUID, eventId: UUID) async throws -> RLGuildEventResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/events/\(eventId.uuidString)/attendees",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Unattend event (cancel RSVP)
    func unattendEvent(guildId: UUID, eventId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/guilds/\(guildId.uuidString)/events/\(eventId.uuidString)/attendees",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }
    
    
    /// Create event (admin/mod only)
    /// NOTE: Backend returns GuildEventResponse, we return the raw response
    func createEvent(guildId: UUID, title: String, content: String, preview: String, eventDate: Date, isImportant: Bool) async throws -> RLGuildEventResponseDTO {
        let requestBody = RLCreateGuildEventRequestDTO(
            title: title,
            content: content,
            preview: preview,
            eventDate: eventDate,
            isImportant: isImportant
        )
        
        return try await request(
            "/guilds/\(guildId.uuidString)/events",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }
}

// MARK: - Helper Types

private struct EmptyResponse: Decodable {}




////
////  RealAPIService.swift
////  traders_guild
////
////  Real API service for backend communication.
////  Uses DTOs that match backend Pydantic schemas exactly.
////
////  Supports multiple backend services (auth, core) with different ports in development.
////  In production, Kong routes everything through one URL.
////
//
//import Foundation
//
//// MARK: - API Configuration
//
//enum APIEnvironment {
//    case development
//    case production
//    
//    static var current: APIEnvironment {
//        #if DEBUG
//        return .development
//        #else
//        return .production
//        #endif
//    }
//}
//
//enum APIService {
//    case auth    // Registration, login, tokens (port 8000)
//    case core    // Users, guilds, memberships, etc. (port 8001)
//    
//    var baseURL: String {
//        switch APIEnvironment.current {
//        case .development:
//            #if targetEnvironment(simulator)
//            switch self {
//            case .auth: return "http://localhost:8000/api/v1"
//            case .core: return "http://localhost:8001/api/v1"
//            }
//            #else
//            // ⚠️ UPDATE THIS to your Mac's IP for device testing
//            let macIP = "192.168.1.182"
//            switch self {
//            case .auth: return "http://\(macIP):8000/api/v1"
//            case .core: return "http://\(macIP):8001/api/v1"
//            }
//            #endif
//            
//        case .production:
//            // Kong routes all services through one URL
//            return "https://api.tradersguild.com/api/v1"
//        }
//    }
//}
//
//// MARK: - API Errors
//
//enum APIError: LocalizedError {
//    case invalidURL
//    case invalidResponse
//    case serverError(Int, String)
//    case unauthorized
//    case badRequest(String)
//    case decodingError(String)
//    case networkError(String)
//    
//    var errorDescription: String? {
//        switch self {
//        case .invalidURL: return "Invalid URL"
//        case .invalidResponse: return "Invalid response from server"
//        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
//        case .unauthorized: return "Please log in again"
//        case .badRequest(let msg): return msg
//        case .decodingError(let msg): return "Failed to parse response: \(msg)"
//        case .networkError(let msg): return "Network error: \(msg)"
//        }
//    }
//}
//
//// MARK: - Real API Service
//
//class RealAPIService {
//    
//    // MARK: - Properties
//    
//    private var accessToken: String?
//    private var refreshToken: String?
//    
//    /// Flag to prevent multiple simultaneous refresh attempts
//    private var isRefreshingToken = false
//    
//    /// Callback when authentication fails completely (refresh token expired)
//    /// RLAppState should set this to handle logout
//    var onAuthenticationFailure: (() -> Void)?
//    
//    /// Callback when tokens are refreshed - allows RLAppState to update keychain
//    var onTokensRefreshed: ((_ accessToken: String, _ refreshToken: String) -> Void)?
//    
//    // MARK: - JSON Decoder
//    
//    private lazy var decoder: JSONDecoder = {
//        let decoder = JSONDecoder()
//        decoder.keyDecodingStrategy = .convertFromSnakeCase
//        decoder.dateDecodingStrategy = .custom { decoder in
//            let container = try decoder.singleValueContainer()
//            let dateString = try container.decode(String.self)
//            
//            // Try ISO8601 with fractional seconds
//            let formatter = ISO8601DateFormatter()
//            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//            if let date = formatter.date(from: dateString) {
//                return date
//            }
//            
//            // Try ISO8601 without fractional seconds
//            formatter.formatOptions = [.withInternetDateTime]
//            if let date = formatter.date(from: dateString) {
//                return date
//            }
//            
//            throw DecodingError.dataCorruptedError(
//                in: container,
//                debugDescription: "Cannot decode date: \(dateString)"
//            )
//        }
//        return decoder
//    }()
//    
//    private lazy var encoder: JSONEncoder = {
//        let encoder = JSONEncoder()
//        encoder.keyEncodingStrategy = .convertToSnakeCase
//        return encoder
//    }()
//    
//    // MARK: - Token Management
//    
//    func setAccessToken(_ token: String?) {
//        self.accessToken = token
//    }
//    
//    func setTokens(access: String, refresh: String) {
//        self.accessToken = access
//        self.refreshToken = refresh
//    }
//    
//    func clearTokens() {
//        self.accessToken = nil
//        self.refreshToken = nil
//    }
//    
//    var isAuthenticated: Bool {
//        accessToken != nil
//    }
//    
//    // MARK: - Generic Request
//    
//    /// Main request method with automatic token refresh on 401
//    private func request<T: Decodable>(
//        _ endpoint: String,
//        service: APIService = .core,
//        method: String = "GET",
//        body: Encodable? = nil,
//        auth: Bool = false,
//        isRetry: Bool = false  // Prevents infinite retry loops
//    ) async throws -> T {
//        guard let url = URL(string: "\(service.baseURL)\(endpoint)") else {
//            throw APIError.invalidURL
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = method
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        
//        if auth {
//            guard let token = accessToken else {
//                throw APIError.unauthorized
//            }
//            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        }
//        
//        if let body = body {
//            request.httpBody = try encoder.encode(body)
//        }
//        
//        #if DEBUG
//        print("🌐 [\(service)] \(method) \(endpoint)")
//        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
//            print("📤 Request: \(str)")
//        }
//        #endif
//        
//        let (data, response): (Data, URLResponse)
//        do {
//            (data, response) = try await URLSession.shared.data(for: request)
//        } catch {
//            throw APIError.networkError(error.localizedDescription)
//        }
//        
//        guard let httpResponse = response as? HTTPURLResponse else {
//            throw APIError.invalidResponse
//        }
//        
//        #if DEBUG
//        print("📥 Status: \(httpResponse.statusCode)")
//        if let str = String(data: data, encoding: .utf8)?.prefix(1000) {
//            print("📥 Response: \(str)")
//        }
//        #endif
//        
//        // Handle error responses
//        guard (200...299).contains(httpResponse.statusCode) else {
//            let detail = extractErrorDetail(from: data)
//            
//            switch httpResponse.statusCode {
//            case 401:
//                // Don't retry if this is already a retry or if it's a refresh/auth endpoint
//                let isAuthEndpoint = endpoint.contains("/auth/")
//                if !isRetry && auth && !isAuthEndpoint {
//                    // Try to refresh token and retry the request
//                    do {
//                        try await performTokenRefresh()
//                        #if DEBUG
//                        print("🔄 Token refreshed, retrying request...")
//                        #endif
//                        // Retry with new token (mark as retry to prevent infinite loop)
//                        return try await self.request(
//                            endpoint,
//                            service: service,
//                            method: method,
//                            body: body,
//                            auth: auth,
//                            isRetry: true
//                        )
//                    } catch {
//                        #if DEBUG
//                        print("❌ Token refresh failed: \(error)")
//                        #endif
//                        // Refresh failed - notify app to logout
//                        await MainActor.run {
//                            onAuthenticationFailure?()
//                        }
//                        throw APIError.unauthorized
//                    }
//                }
//                throw APIError.unauthorized
//            case 400, 422:
//                throw APIError.badRequest(detail)
//            default:
//                throw APIError.serverError(httpResponse.statusCode, detail)
//            }
//        }
//        
//        // Decode response
//        do {
//            return try decoder.decode(T.self, from: data)
//        } catch let error as DecodingError {
//            #if DEBUG
//            printDecodingError(error)
//            #endif
//            throw APIError.decodingError(error.localizedDescription)
//        }
//    }
//    
//    /// Performs token refresh with locking to prevent multiple simultaneous refreshes
//    private func performTokenRefresh() async throws {
//        // If already refreshing, wait a bit and check if we have a new token
//        if isRefreshingToken {
//            #if DEBUG
//            print("🔄 Token refresh already in progress, waiting...")
//            #endif
//            // Wait for the other refresh to complete (with timeout)
//            for _ in 0..<20 { // 2 second timeout
//                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
//                if !isRefreshingToken {
//                    if accessToken != nil {
//                        return // Another call refreshed successfully
//                    }
//                    break
//                }
//            }
//            throw APIError.unauthorized
//        }
//        
//        isRefreshingToken = true
//        defer { isRefreshingToken = false }
//        
//        guard let refresh = refreshToken else {
//            throw APIError.unauthorized
//        }
//        
//        #if DEBUG
//        print("🔄 Refreshing access token...")
//        #endif
//        
//        let requestBody = RLRefreshTokenRequestDTO(refreshToken: refresh)
//        
//        // Direct request without auth (refresh endpoint doesn't need access token)
//        guard let url = URL(string: "\(APIService.auth.baseURL)/auth/refresh") else {
//            throw APIError.invalidURL
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try encoder.encode(requestBody)
//        
//        let (data, response) = try await URLSession.shared.data(for: request)
//        
//        guard let httpResponse = response as? HTTPURLResponse else {
//            throw APIError.invalidResponse
//        }
//        
//        guard (200...299).contains(httpResponse.statusCode) else {
//            #if DEBUG
//            print("🔄 Token refresh failed with status: \(httpResponse.statusCode)")
//            #endif
//            throw APIError.unauthorized
//        }
//        
//        let tokenResponse = try decoder.decode(RLTokenDTO.self, from: data)
//        
//        // Update tokens
//        setTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
//        
//        // Notify RLAppState to update keychain
//        await MainActor.run {
//            onTokensRefreshed?(tokenResponse.accessToken, tokenResponse.refreshToken)
//        }
//        
//        #if DEBUG
//        print("✅ Token refreshed successfully")
//        #endif
//    }
//    
//    private func extractErrorDetail(from data: Data) -> String {
//        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//           let detail = json["detail"] as? String {
//            return detail
//        }
//        return "Unknown error"
//    }
//    
//    #if DEBUG
//    private func printDecodingError(_ error: DecodingError) {
//        print("❌ Decoding error:")
//        switch error {
//        case .keyNotFound(let key, let context):
//            print("   Key '\(key.stringValue)' not found")
//            print("   Path: \(context.codingPath.map { $0.stringValue })")
//        case .typeMismatch(let type, let context):
//            print("   Type '\(type)' mismatch")
//            print("   Path: \(context.codingPath.map { $0.stringValue })")
//        case .valueNotFound(let type, let context):
//            print("   Value of type '\(type)' not found")
//            print("   Path: \(context.codingPath.map { $0.stringValue })")
//        case .dataCorrupted(let context):
//            print("   Data corrupted: \(context.debugDescription)")
//        @unknown default:
//            print("   Unknown error: \(error)")
//        }
//    }
//    #endif
//    
//    // ================================================================================================
//    // MARK: - Auth Endpoints (port 8000)
//    // ================================================================================================
//    
//    /// Register new user
//    func register(data: RLSignupData) async throws -> RLRegistrationResponseDTO {
//        let requestBody = data.toRequest()
//        
//        let response: RLRegistrationResponseDTO = try await request(
//            "/auth/register",
//            service: .auth,
//            method: "POST",
//            body: requestBody
//        )
//        
//        // Store tokens
//        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken)
//        
//        return response
//    }
//    
//    /// Login with email and password
//    func login(email: String, password: String) async throws -> RLLoginResponseDTO {
//        let requestBody = RLLoginRequestDTO(email: email, password: password)
//        
//        let response: RLLoginResponseDTO = try await request(
//            "/auth/login",
//            service: .auth,
//            method: "POST",
//            body: requestBody
//        )
//        
//        // Store tokens
//        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken)
//        
//        return response
//    }
//    
//    /// Refresh access token (manual call - usually automatic refresh handles this)
//    func refreshAccessToken() async throws -> RLTokenDTO {
//        try await performTokenRefresh()
//        
//        // Return current tokens as DTO
//        guard let access = accessToken, let refresh = refreshToken else {
//            throw APIError.unauthorized
//        }
//        
//        return RLTokenDTO(
//            accessToken: access,
//            refreshToken: refresh,
//            tokenType: "bearer",
//            expiresIn: 3600 // Default, actual value came from server
//        )
//    }
//    
//    /// Logout
//    func logout() async {
//        // Try to call logout endpoint (ignore errors)
//        do {
//            let _: EmptyResponse = try await request(
//                "/auth/logout",
//                service: .auth,
//                method: "POST",
//                auth: true
//            )
//        } catch {
//            #if DEBUG
//            print("⚠️ Logout endpoint failed (ignoring): \(error)")
//            #endif
//        }
//        
//        // Always clear local tokens
//        clearTokens()
//    }
//    
//    // ================================================================================================
//    // MARK: - User Endpoints (port 8001)
//    // ================================================================================================
//    
//    /// Get current user profile
//    func getCurrentUser() async throws -> RLUserDTO {
//        return try await request(
//            "/users/me",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    /// Get user by ID
//    func getUser(id: UUID) async throws -> RLUserDTO {
//        return try await request(
//            "/users/\(id.uuidString)",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    // ================================================================================================
//    // MARK: - Guild Endpoints (port 8001)
//    // ================================================================================================
//    
//    /// Get user's guild memberships - Backend Implemented
//    func getUserGuilds() async throws -> RLGuildListResponseDTO {
//        return try await request(
//            "/users/me/guilds",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    /// Get guild by ID - Backend Implemented (Not tested)
//    func getGuild(id: UUID) async throws -> RLGuildDTO {
//        return try await request(
//            "/guilds/\(id.uuidString)",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    /// Get open guilds (for discovery) - Backend Implemented (Not tested)
//    func getOpenGuilds() async throws -> [RLGuildDTO] {
//        return try await request(
//            "/guilds?is_open=true",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    /// Join a guild - returns both guild and membership
//    func joinGuild(guildId: UUID) async throws -> RLJoinGuildResponseDTO {
//        return try await request(
//            "/guilds/\(guildId.uuidString)/join",
//            service: .core,
//            method: "POST",
//            auth: true
//        )
//    }
//    
//    /// Create a new guild - returns both guild and membership
//    func createGuild(name: String, description: String?, isOpen: Bool) async throws -> RLCreateGuildResponseDTO {
//        let requestBody = RLCreateGuildRequestDTO(
//            name: name,
//            description: description,
//            isOpen: isOpen
//        )
//        
//        return try await request(
//            "/guilds",
//            service: .core,
//            method: "POST",
//            body: requestBody,
//            auth: true
//        )
//    }
//    
//    /// Leave a guild
//    func leaveGuild(guildId: UUID) async throws {
//        let _: EmptyResponse = try await request(
//            "/guilds/\(guildId.uuidString)/leave",
//            service: .core,
//            method: "POST",
//            auth: true
//        )
//    }
//    
//    // ================================================================================================
//    // MARK: - Announcement Endpoints (port 8001)
//    // ================================================================================================
//    
//    /// Get guild announcements
//    func getGuildAnnouncements(guildId: UUID) async throws -> RLGuildAnnouncementsListDTO {
//        print("🌐 getGuildAnnouncements: Calling API for guild \(guildId)")
//        let result: RLGuildAnnouncementsListDTO = try await request(
//            "/guilds/\(guildId.uuidString)/announcements",
//            service: .core,
//            auth: true
//        )
//        print("🌐 getGuildAnnouncements: API returned \(result.announcements.count) announcements")
//        return result
//    }
//    
//    /// Get single announcement
//    func getAnnouncement(announcementId: UUID) async throws -> RLGuildAnnouncementWithAuthorDTO {
//        return try await request(
//            "/announcements/\(announcementId.uuidString)",
//            service: .core,
//            auth: true
//        )
//    }
//    
//    /// Create announcement (admin/mod only)
//    func createAnnouncement(guildId: UUID, title: String, content: String, preview: String?, isImportant: Bool) async throws -> RLGuildAnnouncementWithAuthorDTO {
//        let requestBody = RLCreateGuildAnnouncementRequestDTO(
//            title: title,
//            content: content,
//            preview: preview,
//            isImportant: isImportant
//        )
//        
//        return try await request(
//            "/guilds/\(guildId.uuidString)/announcements",
//            service: .core,
//            method: "POST",
//            body: requestBody,
//            auth: true
//        )
//    }
//    
//    /// Record announcement view (marks as read for current user)
//    /// Requires both guildId and announcementId per backend API
//    func recordAnnouncementView(guildId: UUID, announcementId: UUID) async throws {
//        let _: EmptyResponse = try await request(
//            "/guilds/\(guildId.uuidString)/announcements/\(announcementId.uuidString)/read",
//            service: .core,
//            method: "POST",
//            auth: true
//        )
//    }
//}
//
//// MARK: - Helper Types
//
//private struct EmptyResponse: Decodable {}
