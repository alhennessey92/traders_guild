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
    case messaging    // Messaging, threads, messages, etc. (port 8002)
    
    var baseURL: String {
        switch APIEnvironment.current {
        case .development:
            #if targetEnvironment(simulator)
            switch self {
            case .auth: return "http://localhost:8000/api/v1"
            case .core: return "http://localhost:8001/api/v1"
            case .messaging: return "http://localhost:8002/api/v1/messaging"
            }
            #else
            // ⚠️ UPDATE THIS to your Mac's IP for device testing
            let macIP = "192.168.1.182"
            switch self {
            case .auth: return "http://\(macIP):8000/api/v1"
            case .core: return "http://\(macIP):8001/api/v1"
            case .messaging: return "http://\(macIP):8002/api/v1/messaging"
            }
            #endif
            
        case .production:
            // Kong routes all services through one URL
            switch self {
            case .messaging:
                return "https://api.tradersguild.com/api/v1/messaging"
            case .auth, .core:
                return "https://api.tradersguild.com/api/v1"
            }
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
//    func getOpenGuilds() async throws -> [RLGuildDTO] {
//        return try await request(
//            "/guilds?is_open=true",
//            service: .core,
//            auth: true
//        )
//    }
    
    /// Get guilds user is not a member of (for discovery/joining)
    /// Backend endpoint: GET /guilds/not-member
    func getJoinableGuilds() async throws -> [RLGuildDTO] {
        print("🏰 getJoinableGuilds: Fetching guilds user can join")
        let result: [RLGuildDTO] = try await request(
            "/guilds/not-member",
            service: .core,
            auth: true
        )
        print("🏰 getJoinableGuilds: Found \(result.count) guilds")
        return result
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
    
    
    // ================================================================================================
    // MARK: - Statistics Endpoints (port 8001)
    // ================================================================================================
    
    /// Get guild statistics
    func getGuildStatistics(guildId: UUID) async throws -> RLGuildStatisticsResponse {
        print("📊 getGuildStatistics: Calling API for guild \(guildId)")
        let result: RLGuildStatisticsResponse = try await request(
            "/guilds/\(guildId.uuidString)/statistics",
            service: .core,
            auth: true
        )
        print("📊 getGuildStatistics: API returned statistics")
        return result
    }
    
    
    
    
    // NEW Additions for guild members/users
    
    
    // =============================================================================================
    // MARK: - Guild Members
    // =============================================================================================
    
    /// Get guild members with full user data and personalized friend/block status
    /// GET /guilds/{guild_id}/members
    ///
    /// Features:
    /// - Returns embedded user data (no N+1 queries)
    /// - Personalized: includes is_friend, is_blocked for each member relative to current user
    /// - Search by username or display_name
    /// - Pagination support
    func getGuildMembers(
        guildId: UUID,
        skip: Int = 0,
        limit: Int = 50,
        search: String? = nil
    ) async throws -> RLGuildMembersListDTO {
        var path = "/guilds/\(guildId.uuidString)/members?skip=\(skip)&limit=\(limit)"
        if let search = search, !search.isEmpty {
            path += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get a specific guild member's info with relationship data
    /// GET /guilds/{guild_id}/members/{user_id}
    func getGuildMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberDTO {
        
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - User Profile
    // =============================================================================================
    
    /// Get current user's full profile with extended info, stats, and awards
    /// GET /users/me/profile
    ///
    /// - Parameter guildId: Optional guild context for guild-specific data
    /// - Returns: Complete profile with profile, statistics, awards_summary, and optional guild_membership
    func getCurrentUserFullProfile(guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        var path = "/users/me/profile"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get current user's extended profile only (bio, location, interests, etc.)
    /// GET /users/me/profile/extended
    ///
    /// Creates default profile if not exists.
    func getCurrentUserExtendedProfile() async throws -> RLUserProfileDTO {
        return try await request(
            "/users/me/profile/extended",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Update current user's extended profile
    /// PUT /users/me/profile
    ///
    /// - Parameter request: Fields to update (only include fields that should change)
    func updateCurrentUserProfile(_ updateRequest: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO {
        
        return try await request(
            "/users/me/profile",
            service: .core,
            method: "PUT",
            body: updateRequest,
            auth: true
            
        )
        
        
    }
    
    /// Get current user's global statistics
    /// GET /users/me/statistics
    ///
    /// Creates default stats if not exists.
    func getCurrentUserStatistics() async throws -> RLUserGlobalStatisticsDTO {
        
        return try await request(
            "/users/me/statistics",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get another user's full profile
    /// GET /users/{user_id}/profile
    ///
    /// Respects privacy settings and block status.
    /// - Parameters:
    ///   - userId: Target user's ID
    ///   - guildId: Optional guild context for relationship data
    func getUserProfile(userId: UUID, guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        var path = "/users/\(userId.uuidString)/profile"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Awards
    // =============================================================================================
    
    /// Get all awards earned by current user
    /// GET /users/me/awards
    ///
    /// - Parameter guildId: Optional - filter to specific guild's awards
    func getCurrentUserAwards(guildId: UUID? = nil) async throws -> RLUserAwardsListDTO {
        var path = "/users/me/awards"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get awards summary for current user's profile
    /// GET /users/me/awards/summary
    ///
    /// Returns total awards, total points, rarity breakdown, and recent awards
    func getCurrentUserAwardsSummary(guildId: UUID? = nil) async throws -> RLAwardsSummaryDTO {
        var path = "/users/me/awards/summary"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Mark an award as seen (removes 'new' badge)
    /// POST /users/me/awards/{award_id}/mark-seen
    func markAwardAsSeen(awardId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/awards/\(awardId.uuidString)/mark-seen",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// List all available award types
    /// GET /awards/types
    ///
    /// - Parameter category: Optional filter by category (trading, community, milestones, special)
    func getAwardTypes(category: String? = nil) async throws -> [RLAwardTypeDTO] {
        var path = "/awards/types"
        if let category = category {
            path += "?category=\(category)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get a specific award type details
    /// GET /awards/types/{award_id}
    func getAwardType(awardId: UUID) async throws -> RLAwardTypeDTO {
        return try await request(
            "/awards/types/\(awardId.uuidString)",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Friends
    // =============================================================================================
    
    /// Get current user's accepted friends list
    /// GET /users/me/friends
    ///
    /// - Parameter guildId: Required - friends are guild-scoped
    func getFriends(guildId: UUID? = nil) async throws -> RLFriendsListDTO {
        var path = "/users/me/friends"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Get pending friend requests (both incoming and outgoing)
    /// GET /users/me/friends/requests
    ///
    /// - Parameter guildId: Required - requests are guild-scoped
    func getFriendRequests(guildId: UUID? = nil) async throws -> RLFriendRequestsListDTO {
        var path = "/users/me/friends/requests"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a friend request to another user
    /// POST /users/me/friends/request
    ///
    /// Validates:
    /// - Not already friends
    /// - No pending request exists
    /// - Not blocked/blocking
    /// - Both users in same guild
    func sendFriendRequest(toMembershipId: UUID, message: String? = nil) async throws -> RLFriendshipResponseDTO {
        let requestBody = RLFriendRequestCreateRequest(toMembershipId: toMembershipId, message: message)

        return try await request(
            "/users/me/friends/request",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }
    
    
    /// Accept a pending friend request
    /// POST /users/me/friends/requests/{request_id}/accept
    func acceptFriendRequest(requestId: UUID) async throws -> RLFriendshipResponseDTO {
        
        return try await request(
            "/users/me/friends/requests/\(requestId.uuidString)/accept",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    
    /// Decline a pending friend request
    /// POST /users/me/friends/requests/{request_id}/decline
    func declineFriendRequest(requestId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/friends/requests/\(requestId.uuidString)/decline",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    
    /// Remove a friend / cancel pending request
    /// DELETE /users/me/friends/{membership_id}
    ///
    /// Works for both accepted friendships and pending requests
    func removeFriend(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/friends/\(membershipId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Blocks
    // =============================================================================================
    
    /// Get list of users blocked by current user
    /// GET /users/me/blocked
    ///
    /// - Parameter guildId: Required - blocks are guild-scoped
    func getBlockedUsers(guildId: UUID? = nil) async throws -> RLBlockedUsersListDTO {
        var path = "/users/me/blocked"
        if let guildId = guildId {
            path += "?guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Block a user
    /// POST /users/me/blocked/{membership_id}
    ///
    /// Side effects:
    /// - Removes any existing friendship
    /// - Cancels any pending friend requests
    func blockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/blocked/\(membershipId.uuidString)",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Unblock a user
    /// DELETE /users/me/blocked/{membership_id}
    func unblockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/blocked/\(membershipId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }
    

    
    
}

// MARK: - Helper Types

private struct EmptyResponse: Decodable {}



// New Messaging Endpoints

//
//  RealAPIService+Messaging.swift
//  traders_guild
//
//  Messaging API methods for RealAPIService.
//  Add this to your existing RealAPIService.swift file.
//
//  Routes match backend: /guilds/{guild_id}/messaging/...
//



// MARK: - Messaging API Extension
extension RealAPIService {
    
    // =============================================================================================
    // MARK: - Combined Messaging Data (Drawer Preload)
    // =============================================================================================
    
    /// Fetch all messaging data for drawer in one request
    /// GET /guilds/{guild_id}/messaging/drawer-data
    ///
    /// Returns chatrooms + categorized DMs (friends, online, offline)
    func getGuildMessagingData(guildId: UUID) async throws -> RLGuildMessagingDataDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/messaging/drawer-data",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch unread counts for all messaging types
    /// GET /guilds/{guild_id}/messaging/unread-counts
    func getUnreadCounts(guildId: UUID) async throws -> RLUnreadCountsDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/messaging/unread-counts",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Chatrooms
    // =============================================================================================
    
    /// Fetch all chatrooms for a guild
    /// GET /guilds/{guild_id}/chatrooms
    func getGuildChatrooms(guildId: UUID) async throws -> RLGuildChatroomsListDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch a single chatroom by ID
    /// GET /guilds/{guild_id}/chatrooms/{chatroom_id}
    func getChatroom(guildId: UUID, chatroomId: UUID) async throws -> RLGuildChatroomDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch messages for a chatroom (paginated)
    /// GET /guilds/{guild_id}/chatrooms/{chatroom_id}/messages
    ///
    /// - Parameters:
    ///   - limit: Number of messages to fetch (default 50)
    ///   - cursor: Pagination cursor for older messages
    func getChatroomMessages(
        guildId: UUID,
        chatroomId: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLChatroomMessagesListDTO {
        var path = "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a message to a chatroom
    /// POST /guilds/{guild_id}/chatrooms/{chatroom_id}/messages
    func sendChatroomMessage(
        guildId: UUID,
        chatroomId: UUID,
        content: String
    ) async throws -> RLChatroomMessageDTO {
        let body = RLSendMessageRequest(content: content)
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages",
            service: .messaging,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Edit a chatroom message
    /// PUT /guilds/{guild_id}/chatrooms/{chatroom_id}/messages/{message_id}
    func editChatroomMessage(
        guildId: UUID,
        chatroomId: UUID,
        messageId: UUID,
        content: String
    ) async throws -> RLChatroomMessageDTO {
        let body = RLEditMessageRequest(content: content)
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)",
            service: .messaging,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Delete a chatroom message
    /// DELETE /guilds/{guild_id}/chatrooms/{chatroom_id}/messages/{message_id}
    func deleteChatroomMessage(
        guildId: UUID,
        chatroomId: UUID,
        messageId: UUID
    ) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)",
            service: .messaging,
            method: "DELETE",
            auth: true
        )
    }
    
    /// Mark chatroom as read
    /// POST /guilds/{guild_id}/chatrooms/{chatroom_id}/mark-read
    func markChatroomAsRead(guildId: UUID, chatroomId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/mark-read",
            service: .messaging,
            method: "POST",
            auth: true
        )
    }
    
    /// Update chatroom user settings (pin/mute)
    /// PUT /guilds/{guild_id}/chatrooms/{chatroom_id}/settings
    func updateChatroomSettings(
        guildId: UUID,
        chatroomId: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil
    ) async throws -> RLChatroomUserSettingsDTO {
        let body = RLUpdateChatroomSettingsRequest(isPinned: isPinned, isMuted: isMuted)
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/settings",
            service: .messaging,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Create a new chatroom (admin only)
    /// POST /guilds/{guild_id}/chatrooms
    func createChatroom(
        guildId: UUID,
        name: String,
        description: String? = nil
    ) async throws -> RLGuildChatroomDTO {
        let body = RLCreateChatroomRequest(name: name, description: description)
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms",
            service: .messaging,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Direct Messages
    // =============================================================================================
    
    /// Fetch all DM threads for current user in a guild
    /// GET /guilds/{guild_id}/dms
    func getDMThreads(guildId: UUID) async throws -> RLDMThreadsListDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/dms",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch or create a DM thread with another user
    /// POST /guilds/{guild_id}/dms
    ///
    /// If a thread already exists, returns that thread.
    /// If not, creates a new thread.
    func getOrCreateDMThread(
        guildId: UUID,
        participantUserId: UUID
    ) async throws -> RLDMThreadDTO {
        let path = "/guilds/\(guildId.uuidString)/dms?participant_user_id=\(participantUserId.uuidString)"
        return try await request(
            path,
            service: .messaging,
            method: "POST",
            auth: true
        )
    }
    
    /// Fetch a single DM thread by ID
    /// GET /guilds/{guild_id}/dms/{thread_id}
    func getDMThread(guildId: UUID, threadId: UUID) async throws -> RLDMThreadDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)",
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch messages for a DM thread (paginated)
    /// GET /guilds/{guild_id}/dms/{thread_id}/messages
    func getDMMessages(
        guildId: UUID,
        threadId: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLDMMessagesListDTO {
        var path = "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .messaging,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a DM message
    /// POST /guilds/{guild_id}/dms/{thread_id}/messages
    func sendDMMessage(
        guildId: UUID,
        threadId: UUID,
        content: String
    ) async throws -> RLDMMessageDTO {
        let body = RLSendMessageRequest(content: content)
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages",
            service: .messaging,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Edit a DM message
    /// PUT /guilds/{guild_id}/dms/{thread_id}/messages/{message_id}
    func editDMMessage(
        guildId: UUID,
        threadId: UUID,
        messageId: UUID,
        content: String
    ) async throws -> RLDMMessageDTO {
        let body = RLEditMessageRequest(content: content)
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)",
            service: .messaging,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Delete a DM message
    /// DELETE /guilds/{guild_id}/dms/{thread_id}/messages/{message_id}
    func deleteDMMessage(
        guildId: UUID,
        threadId: UUID,
        messageId: UUID
    ) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)",
            service: .messaging,
            method: "DELETE",
            auth: true
        )
    }
    
    /// Mark DM thread as read
    /// POST /guilds/{guild_id}/dms/{thread_id}/mark-read
    func markDMAsRead(guildId: UUID, threadId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/mark-read",
            service: .messaging,
            method: "POST",
            auth: true
        )
    }
    
    /// Delete entire DM conversation
    /// DELETE /guilds/{guild_id}/dms/{thread_id}
    func deleteDMThread(guildId: UUID, threadId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)",
            service: .messaging,
            method: "DELETE",
            auth: true
        )
    }
}


 // User Settings Extensions
extension RealAPIService {

//    // MARK: - Account Management
//
//    func updateBasicUserInfo(_ request: RLBasicUserUpdateRequest) async throws -> RLUserDTO {
//        return try await request(
//            "/users/me/basic",
//            service: .core,
//            method: "PUT",
//            body: request,
//            auth: true
//        )
//    }
//
//    func uploadAvatar(imageData: Data) async throws -> RLAvatarUpdateResponse {
//        // Multipart form data upload
//    }
//
//    func requestEmailChange(_ request: RLEmailChangeRequest) async throws -> RLDetailResponseDTO {
//        return try await request(
//            "/users/me/email/change-request",
//            service: .core,
//            method: "POST",
//            body: request,
//            auth: true
//        )
//    }
//
//    func changePassword(_ request: RLPasswordChangeRequest) async throws -> RLDetailResponseDTO {
//        return try await request(
//            "/users/me/password",
//            service: .core,
//            method: "PUT",
//            body: request,
//            auth: true
//        )
//    }
//
//    func updateDateOfBirth(_ request: RLDOBUpdateRequest) async throws -> RLUserDTO {
//        return try await request(
//            "/users/me/dob",
//            service: .core,
//            method: "PUT",
//            body: request,
//            auth: true
//        )
//    }
//
//    func deleteAccount(_ request: RLDeleteAccountRequest) async throws {
//        let _: EmptyResponse = try await request(
//            "/users/me",
//            service: .core,
//            method: "DELETE",
//            body: request,
//            auth: true
//        )
//    }
//
//    // MARK: - Support
//
//    func submitSupportTicket(_ request: RLSupportTicketRequest) async throws -> RLDetailResponseDTO {
//        return try await request(
//            "/support/tickets",
//            service: .core,
//            method: "POST",
//            body: request,
//            auth: true
//        )
//    }

    // MARK: - Activity Feed

    func getUserActivity(skip: Int = 0, limit: Int = 50) async throws -> RLActivityFeedResponse {
        return try await request(
            "/users/me/activity?skip=\(skip)&limit=\(limit)",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    func requestDataExport() async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/data-export",
            service: .core,
            method: "POST",
            auth: true
        )
    }

    // MARK: - User Settings

    func getUserSettings() async throws -> RLUserSettingsDTO {
        return try await request(
            "/users/me/settings",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    func updateUserSettings(_ updateRequest: RLUserSettingsUpdateRequest) async throws -> RLUserSettingsDTO {
        return try await request(
            "/users/me/settings",
            service: .core,
            method: "PUT",
            body: updateRequest,
            auth: true
        )
    }
}
