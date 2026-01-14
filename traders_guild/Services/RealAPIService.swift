
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
    
    private func request<T: Decodable>(
        _ endpoint: String,
        service: APIService = .core,  // Default to core service
        method: String = "GET",
        body: Encodable? = nil,
        auth: Bool = false
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
    
    /// Refresh access token
    func refreshAccessToken() async throws -> RLTokenDTO {
        guard let refresh = refreshToken else {
            throw APIError.unauthorized
        }
        
        let requestBody = RLRefreshTokenRequestDTO(refreshToken: refresh)
        
        let response: RLTokenDTO = try await request(
            "/auth/refresh",
            service: .auth,
            method: "POST",
            body: requestBody
        )
        
        // Update tokens
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        
        return response
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
    
    /// Get user's guild memberships
    func getUserGuilds() async throws -> RLGuildListResponseDTO {
        return try await request(
            "/users/me/guilds",
            service: .core,
            auth: true
        )
    }
    
    /// Get guild by ID
    func getGuild(id: UUID) async throws -> RLGuildDTO {
        return try await request(
            "/guilds/\(id.uuidString)",
            service: .core,
            auth: true
        )
    }
    
    /// Get open guilds (for discovery)
    func getOpenGuilds() async throws -> [RLGuildDTO] {
        return try await request(
            "/guilds?is_open=true",
            service: .core,
            auth: true
        )
    }
    
    /// Join a guild
    func joinGuild(guildId: UUID) async throws -> RLGuildMembershipDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/join",
            service: .core,
            method: "POST",
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
//
//import Foundation
//
//// MARK: - API Configuration
//
//enum APIConfig {
//    #if targetEnvironment(simulator)
//    static let baseURL = "http://localhost:8000/api/v1"
//    #else
//    // ⚠️ UPDATE THIS to your Mac's IP for device testing
//    static let baseURL = "http://192.168.1.182:8000/api/v1"
//    #endif
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
//    private func request<T: Decodable>(
//        _ endpoint: String,
//        method: String = "GET",
//        body: Encodable? = nil,
//        auth: Bool = false
//    ) async throws -> T {
//        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
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
//        print("🌐 \(method) \(endpoint)")
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
//    // MARK: - Auth Endpoints
//    // ================================================================================================
//    
//    /// Register new user
//    func register(data: RLSignupData) async throws -> RLRegistrationResponseDTO {
//        let requestBody = data.toRequest()
//        
//        let response: RLRegistrationResponseDTO = try await request(
//            "/auth/register",
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
//    /// Refresh access token
//    func refreshAccessToken() async throws -> RLTokenDTO {
//        guard let refresh = refreshToken else {
//            throw APIError.unauthorized
//        }
//        
//        let requestBody = RLRefreshTokenRequestDTO(refreshToken: refresh)
//        
//        let response: RLTokenDTO = try await request(
//            "/auth/refresh",
//            method: "POST",
//            body: requestBody
//        )
//        
//        // Update tokens
//        setTokens(access: response.accessToken, refresh: response.refreshToken)
//        
//        return response
//    }
//    
//    /// Logout
//    func logout() async {
//        // Try to call logout endpoint (ignore errors)
//        do {
//            let _: EmptyResponse = try await request("/auth/logout", method: "POST", auth: true)
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
//    // MARK: - User Endpoints
//    // ================================================================================================
//    
//    /// Get current user profile
//    func getCurrentUser() async throws -> RLUserDTO {
//        return try await request("/users/me", auth: true)
//    }
//    
//    /// Get user by ID
//    func getUser(id: UUID) async throws -> RLUserDTO {
//        return try await request("/users/\(id.uuidString)", auth: true)
//    }
//    
//    // ================================================================================================
//    // MARK: - Guild Endpoints
//    // ================================================================================================
//    
//    /// Get user's guild memberships
//    func getUserGuilds() async throws -> RLGuildListResponseDTO {
//        return try await request("/users/me/guilds", auth: true)
//    }
//    
//    /// Get guild by ID
//    func getGuild(id: UUID) async throws -> RLGuildDTO {
//        return try await request("/guilds/\(id.uuidString)", auth: true)
//    }
//    
//    /// Get open guilds (for discovery)
//    func getOpenGuilds() async throws -> [RLGuildDTO] {
//        return try await request("/guilds?is_open=true", auth: true)
//    }
//    
//    /// Join a guild
//    func joinGuild(guildId: UUID) async throws -> RLGuildMembershipDTO {
//        return try await request("/guilds/\(guildId.uuidString)/join", method: "POST", auth: true)
//    }
//    
//    /// Leave a guild
//    func leaveGuild(guildId: UUID) async throws {
//        let _: EmptyResponse = try await request("/guilds/\(guildId.uuidString)/leave", method: "POST", auth: true)
//    }
//}
//
//// MARK: - Helper Types
//
//private struct EmptyResponse: Decodable {}
