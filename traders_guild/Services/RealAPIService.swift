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

final class AsyncSingleFlight<Value> {
    private final class Flight {
        let id = UUID()
        let task: Task<Value, Error>

        init(task: Task<Value, Error>) {
            self.task = task
        }
    }

    private let lock = NSLock()
    private var inFlight: Flight?

    func run(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let flight = lockFlight(for: operation)
        defer { clearFlightIfCurrent(flight) }
        return try await flight.task.value
    }

    private func lockFlight(
        for operation: @escaping @Sendable () async throws -> Value
    ) -> Flight {
        lock.lock()
        defer { lock.unlock() }

        if let inFlight {
            return inFlight
        }

        let created = Flight(task: Task {
            try await operation()
        })
        inFlight = created
        return created
    }

    private func clearFlightIfCurrent(_ flight: Flight) {
        lock.lock()
        defer { lock.unlock() }

        guard inFlight?.id == flight.id else { return }
        inFlight = nil
    }
}

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
    case auth       // Registration, login, tokens (port 8000)
    case core       // Users, guilds, memberships, messaging REST (port 8001)
    case chart      // Chart, symbols, candles, markers, watchlists (port 8003)
    case realtime   // WebSocket connections only (port 8002)
    case reputation // Reputation system (port 8005)

    var baseURL: String {
        switch AppConfig.apiRoutingMode {
        case .apiGateway:
            switch APIEnvironment.current {
            case .development:
                return AppConfig.developmentGatewayBaseURL
            case .production:
                return AppConfig.productionGatewayBaseURL
            }
        case .directServices:
            switch APIEnvironment.current {
            case .development:
                #if DEBUG
                #if targetEnvironment(simulator)
                switch self {
                case .auth:       return "http://localhost:8000/api/v1"
                case .core:       return "http://localhost:8001/api/v1"
                case .chart:      return "http://localhost:8003/api/v1"
                case .realtime:   return "http://localhost:8002/api/v1"
                case .reputation: return "http://localhost:8005/api/v1"
                }
                #else
                // Device testing: set TG_DEV_MAC_IP in the scheme's env vars.
                let macIP = ProcessInfo.processInfo.environment["TG_DEV_MAC_IP"] ?? "127.0.0.1"
                switch self {
                case .auth:       return "http://\(macIP):8000/api/v1"
                case .core:       return "http://\(macIP):8001/api/v1"
                case .chart:      return "http://\(macIP):8003/api/v1"
                case .realtime:   return "http://\(macIP):8002/api/v1"
                case .reputation: return "http://\(macIP):8005/api/v1"
                }
                #endif
                #else
                return AppConfig.productionGatewayBaseURL
                #endif
            case .production:
                return AppConfig.productionGatewayBaseURL
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
        case .invalidURL: return "Unable to complete the request."
        case .invalidResponse: return "Invalid response from server."
        case .serverError: return "Service is temporarily unavailable."
        case .unauthorized: return "Please log in again."
        case .badRequest: return "We couldn't complete that request."
        case .decodingError: return "Unexpected response received."
        case .networkError: return "Network issue detected."
        }
    }
}

// MARK: - Real API Service

class RealAPIService {
    
    // MARK: - Properties
    
    private var accessToken: String?
    private var refreshToken: String?
    
    /// Callback when authentication fails completely (refresh token expired)
    /// RLAppState should set this to handle logout
    var onAuthenticationFailure: (() -> Void)?
    
    /// Callback when tokens are refreshed - allows RLAppState to update keychain
    var onTokensRefreshed: ((_ accessToken: String, _ refreshToken: String) -> Void)?
    private let tokenRefreshSingleFlight = AsyncSingleFlight<RLTokenDTO>()
    
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

            // Try "yyyy-MM-dd'T'HH:mm:ss" (no timezone)
            let noTZDateTime = DateFormatter()
            noTZDateTime.locale = Locale(identifier: "en_US_POSIX")
            noTZDateTime.timeZone = TimeZone(secondsFromGMT: 0)
            noTZDateTime.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = noTZDateTime.date(from: dateString) {
                return date
            }

            // Try date-only "yyyy-MM-dd"
            let dateOnly = DateFormatter()
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
            dateOnly.dateFormat = "yyyy-MM-dd"
            if let date = dateOnly.date(from: dateString) {
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
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: date)
            try container.encode(dateString)
        }
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

    // MARK: - Proactive Token Refresh

    /// Refresh the access token if it's near expiry. No-op if no refresh token,
    /// no access token, or expiry is comfortably in the future.
    func refreshAccessTokenIfNeeded(thresholdSeconds: TimeInterval = 300) async {
        guard let token = accessToken,
              refreshToken != nil else { return }

        guard let exp = Self.expirationDate(forJWT: token) else { return }
        let secondsRemaining = exp.timeIntervalSinceNow
        guard secondsRemaining < thresholdSeconds else { return }

        do {
            try await performTokenRefresh()
        } catch {
            #if DEBUG
            print("🔄 Proactive token refresh failed: \(error)")
            #endif
        }
    }

    /// Decode a JWT and return its `exp` claim as a Date. Pure parsing; no
    /// signature verification (the backend does that).
    static func expirationDate(forJWT token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        let payloadSegment = String(segments[1])

        // Base64URL → base64 + padding
        var base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padCount = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padCount))

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
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
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            #if DEBUG
            let context = "\(request.url?.absoluteString ?? "\(service.baseURL)\(endpoint)") [mode=\(AppConfig.apiRoutingMode.rawValue)]"
            print("❌ API network request failed: \(error.localizedDescription) | \(context)")
            #endif
            throw APIError.networkError("request_failed")
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
                        if case APIError.unauthorized = error {
                            // Refresh token itself is invalid/expired - notify app to logout.
                            await MainActor.run {
                                onAuthenticationFailure?()
                            }
                            throw APIError.unauthorized
                        }
                        throw error
                    }
                }
                throw APIError.unauthorized
            case 400, 422:
                throw APIError.badRequest(detail)
            default:
                throw APIError.serverError(httpResponse.statusCode, detail)
            }
        }
        
        // Handle 204 No Content or empty body for EmptyResponse
        if data.isEmpty || httpResponse.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            #if DEBUG
            printDecodingError(error)
            #endif
            throw APIError.decodingError("response_decode_failed")
        }
    }
    
    /// Performs token refresh with locking to prevent multiple simultaneous refreshes
    private func performTokenRefresh() async throws {
        _ = try await tokenRefreshSingleFlight.run { [self] in
            try await executeTokenRefresh()
        }
    }

    private func executeTokenRefresh() async throws -> RLTokenDTO {
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
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            throw APIError.networkError("token_refresh_failed")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("🔄 Token refresh failed with status: \(httpResponse.statusCode)")
            #endif
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
        
        let tokenResponse: RLTokenDTO
        do {
            tokenResponse = try decoder.decode(RLTokenDTO.self, from: data)
        } catch {
            throw APIError.decodingError("token_refresh_decode_failed")
        }
        
        // Update tokens
        setTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
        
        // Notify RLAppState to update keychain
        await MainActor.run {
            onTokensRefreshed?(tokenResponse.accessToken, tokenResponse.refreshToken)
        }
        
        #if DEBUG
        print("✅ Token refreshed successfully")
        #endif
        return tokenResponse
    }
    
    private func extractErrorDetail(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String {
                return detail
            }
            if let detailObj = json["detail"] as? [String: Any] {
                if let message = detailObj["message"] as? String, !message.isEmpty {
                    return message
                }
                if let code = detailObj["code"] as? String, !code.isEmpty {
                    return code
                }
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
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
    
    
    

    
    
    

    

    
    
    
    
    
    
    
    // NEW Additions for guild members/users
    
    
    
    
    
    
    
    

    
    


    
    
}

// MARK: - Helper Types

private struct EmptyResponse: Decodable {}



// ================================================================================================
// MARK: - Auth Endpoints (port 8000)
// ================================================================================================
extension RealAPIService {
    
    
    
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

    func checkEmailAvailability(email: String) async throws -> RLFieldAvailabilityResponseDTO {
        let requestBody = RLEmailAvailabilityRequestDTO(email: email)

        return try await request(
            "/auth/register/check-email",
            service: .auth,
            method: "POST",
            body: requestBody
        )
    }

    func checkUsernameAvailability(username: String) async throws -> RLFieldAvailabilityResponseDTO {
        let requestBody = RLUsernameAvailabilityRequestDTO(username: username)

        return try await request(
            "/auth/register/check-username",
            service: .auth,
            method: "POST",
            body: requestBody
        )
    }
    
    /// Login with identifier (email or username) and password
    func login(identifier: String, password: String) async throws -> RLLoginResponseDTO {
        let requestBody = RLLoginRequestDTO(identifier: identifier, password: password)
        
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

    /// Request password reset email
    func requestPasswordReset(identifier: String) async throws -> RLPasswordForgotResponseDTO {
        let requestBody = RLPasswordForgotRequestDTO(identifier: identifier)
        return try await request(
            "/auth/password/forgot",
            service: .auth,
            method: "POST",
            body: requestBody
        )
    }

    /// Verify reset token validity
    func verifyPasswordResetToken(_ token: String) async throws -> RLPasswordResetVerifyResponseDTO {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        return try await request(
            "/auth/password/reset/verify?token=\(encoded)",
            service: .auth,
            method: "GET"
        )
    }

    /// Reset password with token
    func resetPassword(token: String, newPassword: String) async throws -> RLPasswordResetResponseDTO {
        let requestBody = RLPasswordResetRequestDTO(token: token, newPassword: newPassword)
        return try await request(
            "/auth/password/reset",
            service: .auth,
            method: "POST",
            body: requestBody
        )
    }
    
    /// Login with Apple Sign In identity token
    func loginWithApple(identityToken: String, authorizationCode: String, fullName: String?, email: String?) async throws -> RLAppleSignInResponseDTO {
        let requestBody = RLAppleSignInRequestDTO(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName,
            email: email
        )

        let response: RLAppleSignInResponseDTO = try await request(
            "/auth/apple",
            service: .auth,
            method: "POST",
            body: requestBody
        )

        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken)
        return response
    }

    /// Verify email with token
    func verifyEmail(token: String) async throws -> RLEmailVerifyResponseDTO {
        let requestBody = RLEmailVerifyRequestDTO(token: token)
        return try await request(
            "/auth/email/verify",
            service: .auth,
            method: "POST",
            body: requestBody
        )
    }

    /// Resend email verification link (requires auth)
    func resendVerificationEmail() async throws -> RLPasswordForgotResponseDTO {
        return try await request(
            "/auth/email/resend-verification",
            service: .auth,
            method: "POST",
            auth: true
        )
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
}


// ================================================================================================
// MARK: - User Endpoints (port 8001)
// ================================================================================================
extension RealAPIService {
    
    
    
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
    
    
}



// ================================================================================================
// MARK: - Guild Endpoints (port 8001)
// ================================================================================================
extension RealAPIService {
    
    
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

    /// Get public/open guilds without authentication (signup discovery).
    func getPublicOpenGuilds(
        search: String? = nil,
        language: String? = nil,
        location: String? = nil,
        sort: String? = nil,
        skip: Int = 0,
        limit: Int = 50
    ) async throws -> [RLGuildDTO] {
        var queryParts: [String] = ["skip=\(skip)", "limit=\(limit)"]
        if let search = search, !search.isEmpty {
            queryParts.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }
        if let language = language, !language.isEmpty {
            queryParts.append("language=\(language.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? language)")
        }
        if let location = location, !location.isEmpty {
            queryParts.append("location=\(location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location)")
        }
        if let sort = sort, !sort.isEmpty {
            queryParts.append("sort=\(sort)")
        }
        return try await request(
            "/guilds/public/open?\(queryParts.joined(separator: "&"))",
            service: .core,
            auth: false
        )
    }
    
    /// Get guilds user is not a member of (for discovery/joining)
    /// Backend endpoint: GET /guilds/not-member
    func getJoinableGuilds(
        search: String? = nil,
        isOpen: Bool? = nil,
        language: String? = nil,
        location: String? = nil,
        sort: String? = nil,
        skip: Int = 0,
        limit: Int = 100
    ) async throws -> [RLGuildDTO] {
        print("🏰 getJoinableGuilds: Fetching guilds user can join")
        var queryParts: [String] = ["skip=\(skip)", "limit=\(limit)"]
        if let search = search, !search.isEmpty {
            queryParts.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }
        if let isOpen = isOpen {
            queryParts.append("is_open=\(isOpen ? "true" : "false")")
        }
        if let language = language, !language.isEmpty {
            queryParts.append("language=\(language.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? language)")
        }
        if let location = location, !location.isEmpty {
            queryParts.append("location=\(location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location)")
        }
        if let sort = sort, !sort.isEmpty {
            queryParts.append("sort=\(sort)")
        }
        let result: [RLGuildDTO] = try await request(
            "/guilds/not-member?\(queryParts.joined(separator: "&"))",
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

    /// Assign user to system-managed onboarding guild fallback.
    func assignOnboardingGuild() async throws -> RLJoinGuildResponseDTO {
        return try await request(
            "/guilds/onboarding/assign",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Create a new guild - returns both guild and membership
    func createGuild(
        name: String,
        description: String?,
        isOpen: Bool,
        language: String,
        location: String,
        joinQuestions: [RLGuildJoinQuestionInputDTO] = [],
        initialAnnouncementTitle: String,
        initialAnnouncementContent: String,
        initialAnnouncementPreview: String? = nil,
        initialAnnouncementIsImportant: Bool = true
    ) async throws -> RLCreateGuildResponseDTO {
        let requestBody = RLCreateGuildRequestDTO(
            name: name,
            description: description,
            isOpen: isOpen,
            language: language,
            location: location,
            joinQuestions: joinQuestions,
            initialAnnouncementTitle: initialAnnouncementTitle,
            initialAnnouncementContent: initialAnnouncementContent,
            initialAnnouncementPreview: initialAnnouncementPreview,
            initialAnnouncementIsImportant: initialAnnouncementIsImportant
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

    func getGuildJoinQuestions(guildId: UUID) async throws -> RLGuildJoinQuestionsListDTO {
        try await request(
            "/guilds/\(guildId.uuidString)/join-questions",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    func updateGuildJoinQuestions(guildId: UUID, questions: [RLGuildJoinQuestionInputDTO]) async throws -> RLGuildJoinQuestionsListDTO {
        let body = RLGuildJoinQuestionsUpdateRequestDTO(questions: questions)
        return try await request(
            "/guilds/\(guildId.uuidString)/join-questions",
            service: .core,
            method: "PUT",
            body: body,
            auth: true
        )
    }

    func createGuildJoinRequest(guildId: UUID, note: String?, answers: [RLGuildJoinRequestAnswerInputDTO]) async throws -> RLGuildJoinRequestDTO {
        let body = RLGuildJoinRequestCreateRequestDTO(note: note, answers: answers)
        return try await request(
            "/guilds/\(guildId.uuidString)/join-requests",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func getGuildJoinRequests(guildId: UUID, status: String? = "pending") async throws -> RLGuildJoinRequestsListDTO {
        var path = "/guilds/\(guildId.uuidString)/join-requests"
        if let status = status, !status.isEmpty {
            path += "?status=\(status)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }

    func approveGuildJoinRequest(guildId: UUID, requestId: UUID, reviewNote: String?) async throws -> RLGuildJoinRequestDTO {
        let body = RLGuildJoinRequestDecisionRequestDTO(reviewNote: reviewNote)
        return try await request(
            "/guilds/\(guildId.uuidString)/join-requests/\(requestId.uuidString)/approve",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func declineGuildJoinRequest(guildId: UUID, requestId: UUID, reviewNote: String?) async throws -> RLGuildJoinRequestDTO {
        let body = RLGuildJoinRequestDecisionRequestDTO(reviewNote: reviewNote)
        return try await request(
            "/guilds/\(guildId.uuidString)/join-requests/\(requestId.uuidString)/decline",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
}



// ================================================================================================
// MARK: - Announcement Endpoints (port 8001)
// ================================================================================================
extension RealAPIService {
    
    
    
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
            "/guilds/announcements/\(announcementId.uuidString)",
            service: .core,
            auth: true
        )
    }
    
    /// Create announcement (admin/mod only)
    func createAnnouncement(
        guildId: UUID,
        title: String,
        content: String,
        preview: String,
        isImportant: Bool,
        iconKey: GuildPostIconKey?
    ) async throws -> RLGuildAnnouncementWithAuthorDTO {
        let requestBody = RLCreateGuildAnnouncementRequestDTO(
            title: title,
            content: content,
            preview: preview,
            isImportant: isImportant,
            iconKey: iconKey
        )
        
        return try await request(
            "/guilds/\(guildId.uuidString)/announcements",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }

    /// Create a platform-wide announcement (superuser only).
    func createGlobalAnnouncement(
        title: String,
        content: String,
        preview: String? = nil,
        isImportant: Bool,
        iconKey: GuildPostIconKey?
    ) async throws -> RLGlobalAnnouncementBroadcastResponseDTO {
        let requestBody = RLCreateGlobalAnnouncementRequestDTO(
            title: title,
            content: content,
            preview: preview,
            isImportant: isImportant,
            iconKey: iconKey
        )

        return try await request(
            "/admin/announcements/global",
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
}



// ================================================================================================
// MARK: - Event Endpoints (port 8001)
// ================================================================================================
extension RealAPIService {
    
    
    
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
    
    /// Share event with a friend (pending backend support)
    func shareEvent(guildId: UUID, eventId: UUID, friendId: UUID) async throws -> RLDetailResponseDTO {
        let body = RLShareEventRequest(friendId: friendId)
        return try await request(
            "/guilds/\(guildId.uuidString)/events/\(eventId.uuidString)/share",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    
    /// Create event (admin/mod only)
    /// NOTE: Backend returns GuildEventResponse, we return the raw response
    func createEvent(
        guildId: UUID,
        title: String,
        content: String,
        preview: String,
        eventDate: Date,
        isImportant: Bool,
        iconKey: GuildPostIconKey?,
        locationType: RLEventLocationType? = nil,
        locationId: UUID? = nil
    ) async throws -> RLGuildEventResponseDTO {
        let requestBody = RLCreateGuildEventRequestDTO(
            title: title,
            content: content,
            preview: preview,
            eventDate: eventDate,
            isImportant: isImportant,
            iconKey: iconKey,
            locationType: locationType?.rawValue,
            locationId: locationId
        )

        return try await request(
            "/guilds/\(guildId.uuidString)/events",
            service: .core,
            method: "POST",
            body: requestBody,
            auth: true
        )
    }

    /// Fetch the list of members attending a guild event.
    func fetchEventAttendees(
        guildId: UUID,
        eventId: UUID
    ) async throws -> [RLGuildSimpleMembershipResponse] {
        return try await request(
            "/guilds/\(guildId.uuidString)/events/\(eventId.uuidString)/attendees",
            service: .core,
            method: "GET",
            auth: true
        )
    }

}



// ================================================================================================
// MARK: - Statistics Endpoints (port 8001)
// ================================================================================================
extension RealAPIService {
    
    
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
}




// =============================================================================================
// MARK: - Guild Members
// =============================================================================================
extension RealAPIService {
    
    
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
}


// =============================================================================================
// MARK: - Guild Admin Panel
// =============================================================================================
extension RealAPIService {

    // MARK: Guild Settings

    /// Update guild settings (name, description, is_open)
    /// PATCH /guilds/{guild_id}
    func updateGuild(guildId: UUID, name: String?, description: String?, isOpen: Bool?) async throws -> RLGuildDTO {
        let body = RLUpdateGuildRequestDTO(name: name, description: description, isOpen: isOpen)
        return try await request(
            "/guilds/\(guildId.uuidString)",
            service: .core,
            method: "PATCH",
            body: body,
            auth: true
        )
    }

    // MARK: Invite Members

    /// Search users by username/display_name for inviting
    /// GET /guilds/{guild_id}/invites/search?search=
    func searchUsersForInvite(guildId: UUID, search: String) async throws -> RLUserSearchResultsDTO {
        let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
        return try await request(
            "/guilds/\(guildId.uuidString)/invites/search?search=\(encoded)",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    /// Create a guild invite
    /// POST /guilds/{guild_id}/invites
    func createGuildInvite(guildId: UUID, username: String) async throws -> RLGuildInvitationDTO {
        struct Body: Codable { let username: String }
        return try await request(
            "/guilds/\(guildId.uuidString)/invites",
            service: .core,
            method: "POST",
            body: Body(username: username),
            auth: true
        )
    }

    /// List pending guild invitations
    /// GET /guilds/{guild_id}/invites
    func getGuildInvites(guildId: UUID) async throws -> RLGuildInvitationsListDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/invites",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    /// Cancel a pending guild invite
    /// DELETE /guilds/{guild_id}/invites/{invite_id}
    func cancelGuildInvite(guildId: UUID, inviteId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/invites/\(inviteId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    /// Accept a guild invite
    /// POST /guilds/{guild_id}/invites/{invite_id}/accept
    func acceptGuildInvite(guildId: UUID, inviteId: UUID) async throws -> RLGuildWithMembership {
        return try await request(
            "/guilds/\(guildId.uuidString)/invites/\(inviteId.uuidString)/accept",
            service: .core,
            method: "POST",
            auth: true
        )
    }

    /// Decline a guild invite
    /// POST /guilds/{guild_id}/invites/{invite_id}/decline
    func declineGuildInvite(guildId: UUID, inviteId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/invites/\(inviteId.uuidString)/decline",
            service: .core,
            method: "POST",
            auth: true
        )
    }

    // MARK: Ban & Kick

    /// Ban a member from the guild
    /// POST /guilds/{guild_id}/members/{user_id}/ban
    func banMember(guildId: UUID, userId: UUID, reason: String?) async throws -> RLGuildBanDTO {
        let body = RLGuildBanRequestDTO(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/ban",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// List banned users
    /// GET /guilds/{guild_id}/bans
    func getGuildBans(guildId: UUID) async throws -> RLGuildBansListDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/bans",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    /// Unban a member
    /// DELETE /guilds/{guild_id}/bans/{ban_id}
    func unbanMember(guildId: UUID, banId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/bans/\(banId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    /// Kick a member (remove without ban)
    /// POST /guilds/{guild_id}/members/{user_id}/kick
    func kickMember(guildId: UUID, userId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/kick",
            service: .core,
            method: "POST",
            auth: true
        )
    }

    // MARK: Mute / Suspend

    /// Mute a member
    /// POST /guilds/{guild_id}/members/{user_id}/mute
    func muteMember(guildId: UUID, userId: UUID, durationMinutes: Int, reason: String?) async throws -> RLGuildMemberActionResponseDTO {
        let body = RLGuildMuteRequestDTO(durationMinutes: durationMinutes, reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/mute",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Unmute a member
    /// DELETE /guilds/{guild_id}/members/{user_id}/mute
    func unmuteMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberActionResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/mute",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    /// Suspend a member
    /// POST /guilds/{guild_id}/members/{user_id}/suspend
    func suspendMember(guildId: UUID, userId: UUID, durationMinutes: Int, reason: String?) async throws -> RLGuildMemberActionResponseDTO {
        let body = RLGuildSuspendRequestDTO(durationMinutes: durationMinutes, reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/suspend",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Unsuspend a member
    /// DELETE /guilds/{guild_id}/members/{user_id}/suspend
    func unsuspendMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberActionResponseDTO {
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/suspend",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    // MARK: Manage Roles

    /// Change a member's role
    /// PATCH /guilds/{guild_id}/members/{user_id}/role
    func changeMemberRole(guildId: UUID, userId: UUID, role: String) async throws -> RLGuildMemberRoleResponseDTO {
        let body = RLGuildRoleChangeRequestDTO(role: role)
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/role",
            service: .core,
            method: "PATCH",
            body: body,
            auth: true
        )
    }

    // MARK: Content Reports

    /// List guild reports
    /// GET /guilds/{guild_id}/reports
    func getGuildReports(guildId: UUID, status: String? = nil, contentType: String? = nil) async throws -> RLContentReportsListDTO {
        var path = "/guilds/\(guildId.uuidString)/reports"
        var params: [String] = []
        if let status = status { params.append("status=\(status)") }
        if let contentType = contentType { params.append("content_type=\(contentType)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await request(path, service: .core, method: "GET", auth: true)
    }

    /// Resolve or dismiss a report
    /// PATCH /guilds/{guild_id}/reports/{report_id}
    func resolveReport(guildId: UUID, reportId: UUID, action: String, note: String?) async throws -> RLContentReportDTO {
        let body = RLResolveReportRequestDTO(action: action, resolutionNote: note)
        return try await request(
            "/guilds/\(guildId.uuidString)/reports/\(reportId.uuidString)",
            service: .core,
            method: "PATCH",
            body: body,
            auth: true
        )
    }
}


// =============================================================================================
// MARK: - User Profile
// =============================================================================================
extension RealAPIService {
    
    
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
    
}



// =============================================================================================
// MARK: - Awards
// =============================================================================================
extension RealAPIService {
    
    
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
    
}



// =============================================================================================
// MARK: - Friends
// =============================================================================================
extension RealAPIService {
    
    
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
}



// =============================================================================================
// MARK: - Messaging API Extension
// =============================================================================================
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
            "/messaging/guilds/\(guildId.uuidString)/messaging/drawer-data",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch unread counts for all messaging types
    /// GET /guilds/{guild_id}/messaging/unread-counts
    func getUnreadCounts(guildId: UUID) async throws -> RLUnreadCountsDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/messaging/unread-counts",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/chatrooms",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Fetch a single chatroom by ID
    /// GET /guilds/{guild_id}/chatrooms/{chatroom_id}
    func getChatroom(guildId: UUID, chatroomId: UUID) async throws -> RLGuildChatroomDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)",
            service: .core,
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
        var path = "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }

    /// Search chatroom messages across the guild.
    /// GET /guilds/{guild_id}/messages/search
    func searchMessages(
        guildId: UUID,
        query: String,
        chatroomId: UUID? = nil,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> RLMessageSearchResponseDTO {
        var path = "/messaging/guilds/\(guildId.uuidString)/messages/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)"
        if let chatroomId {
            path += "&chatroom_id=\(chatroomId.uuidString)"
        }
        if let cursor {
            path += "&before=\(cursor)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a message to a chatroom
    /// POST /guilds/{guild_id}/chatrooms/{chatroom_id}/messages
    func sendChatroomMessage(
        guildId: UUID,
        chatroomId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLChatroomMessageDTO {
        let body = RLSendMessageRequest(
            content: content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            attachments: attachments.isEmpty ? nil : attachments,
            replyToMessageId: replyToMessageId
        )
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    func toggleChatroomMessageReaction(
        guildId: UUID,
        chatroomId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLChatroomMessageDTO {
        let body = RLToggleMessageReactionRequest(emoji: emoji)
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)/reactions",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func getChatroomMessageReactionReactors(
        guildId: UUID,
        chatroomId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? emoji
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)/reactions?emoji=\(encodedEmoji)",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Mark chatroom as read
    /// POST /guilds/{guild_id}/chatrooms/{chatroom_id}/mark-read
    func markChatroomAsRead(guildId: UUID, chatroomId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/mark-read",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/settings",
            service: .core,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Create a new chatroom (owner/admin only)
    /// POST /guilds/{guild_id}/chatrooms
    func createChatroom(
        guildId: UUID,
        name: String,
        description: String,
        icon: String? = nil
    ) async throws -> RLGuildChatroomDTO {
        let body = RLCreateChatroomRequest(name: name, description: description, icon: icon)
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Update chatroom metadata (owner/admin only)
    /// PUT /guilds/{guild_id}/chatrooms/{chatroom_id}
    func updateChatroom(
        guildId: UUID,
        chatroomId: UUID,
        name: String? = nil,
        description: String? = nil,
        icon: String? = nil
    ) async throws -> RLGuildChatroomDTO {
        let body = RLUpdateChatroomRequest(name: name, description: description, icon: icon)
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)",
            service: .core,
            method: "PUT",
            body: body,
            auth: true
        )
    }

    /// Archive a chatroom (owner/admin only)
    /// DELETE /guilds/{guild_id}/chatrooms/{chatroom_id}
    func deleteChatroom(guildId: UUID, chatroomId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)",
            service: .core,
            method: "DELETE",
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
            "/messaging/guilds/\(guildId.uuidString)/dms",
            service: .core,
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
        let path = "/messaging/guilds/\(guildId.uuidString)/dms?participant_user_id=\(participantUserId.uuidString)"
        return try await request(
            path,
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Fetch a single DM thread by ID
    /// GET /guilds/{guild_id}/dms/{thread_id}
    func getDMThread(guildId: UUID, threadId: UUID) async throws -> RLDMThreadDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)",
            service: .core,
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
        var path = "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a DM message
    /// POST /guilds/{guild_id}/dms/{thread_id}/messages
    func sendDMMessage(
        guildId: UUID,
        threadId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLDMMessageDTO {
        let body = RLSendMessageRequest(
            content: content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            attachments: attachments.isEmpty ? nil : attachments,
            replyToMessageId: replyToMessageId
        )
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)",
            service: .core,
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
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    func toggleDMMessageReaction(
        guildId: UUID,
        threadId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLDMMessageDTO {
        let body = RLToggleMessageReactionRequest(emoji: emoji)
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)/reactions",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func getDMMessageReactionReactors(
        guildId: UUID,
        threadId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? emoji
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)/reactions?emoji=\(encodedEmoji)",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Mark DM thread as read
    /// POST /guilds/{guild_id}/dms/{thread_id}/mark-read
    func markDMAsRead(guildId: UUID, threadId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/mark-read",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    /// Delete entire DM conversation
    /// DELETE /guilds/{guild_id}/dms/{thread_id}
    func deleteDMThread(guildId: UUID, threadId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }

    // MARK: - Reporting
    
    func reportChatroom(guildId: UUID, chatroomId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLChatroomReportRequest(reason: reason)
        return try await request(
            "/messaging/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    // Report user to admin (user_id = the reported user's id)
    func reportUser(guildId: UUID, userId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLUserReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/members/\(userId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    // MARK: - Content Reporting

    /// Report a chatroom message
    func reportChatroomMessage(guildId: UUID, chatroomId: UUID, messageId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLContentReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/chatrooms/\(chatroomId.uuidString)/messages/\(messageId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Report a DM message
    func reportDMMessage(guildId: UUID, threadId: UUID, messageId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLContentReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/dms/\(threadId.uuidString)/messages/\(messageId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Report a chart chat message
    func reportChartChatMessage(guildId: UUID, messageId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLContentReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/chart-chats/messages/\(messageId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Report a chart marker
    func reportMarker(guildId: UUID, markerId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLContentReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Report a marker comment
    func reportMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID, reason: String) async throws -> RLDetailResponseDTO {
        let body = RLContentReportRequest(reason: reason)
        return try await request(
            "/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments/\(commentId.uuidString)/report",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }
}


// =============================================================================================
// MARK: - Account Management Extensions
// =============================================================================================
extension RealAPIService {
    
    // =============================================================================================
    // MARK: - Basic User Info
    // =============================================================================================
    
    /// Update basic user info (display name and/or username)
    /// PUT /users/me/basic
    func updateBasicUserInfo(_ updateRequest: RLBasicUserUpdateRequest) async throws -> RLUserDTO {
        return try await request(
            "/users/me/basic",
            service: .core,
            method: "PUT",
            body: updateRequest,
            auth: true
        )
    }
    
    
    // MARK: - Activity Feed

    func getUserActivity(skip: Int = 0, limit: Int = 50, guildId: UUID? = nil) async throws -> RLActivityFeedResponse {
        var path = "/users/me/activity?skip=\(skip)&limit=\(limit)"
        if let guildId = guildId {
            path += "&guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Extended Profile
    // =============================================================================================
    
    /// Get current user's extended profile
    /// GET /users/me/profile/extended
    func getExtendedProfile() async throws -> RLUserProfileDTO {
        return try await request(
            "/users/me/profile/extended",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Update current user's extended profile (bio, location, interests, etc.)
    /// PUT /users/me/profile
    func updateUserProfile(_ updateRequest: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO {
        return try await request(
            "/users/me/profile",
            service: .core,
            method: "PUT",
            body: updateRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Avatar
    // =============================================================================================
    
    /// Upload avatar image
    /// PUT /users/me/avatar (multipart/form-data)
    func uploadAvatar(imageData: Data, mimeType: String = "image/jpeg") async throws -> RLAvatarUpdateResponse {
        // Build multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        
        guard let url = URL(string: "\(APIService.core.baseURL)/users/me/avatar") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw APIError.unauthorized
        }
        
        // Build body
        var body = Data()
        
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = extractErrorDetailFromData(data)
            switch httpResponse.statusCode {
            case 401: throw APIError.unauthorized
            case 400, 422: throw APIError.badRequest(detail)
            default: throw APIError.serverError(httpResponse.statusCode, detail)
            }
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RLAvatarUpdateResponse.self, from: data)
    }
    
    // MARK: - Message Attachment Upload

    /// Upload response from attachment endpoints
    struct RLAttachmentUploadResponse: Codable {
        let attachmentUrl: String
        let attachmentType: String
        let attachmentName: String
    }

    /// Generic attachment upload helper (multipart/form-data)
    private func uploadAttachment(
        endpoint: String,
        service: APIService,
        fileData: Data,
        filename: String,
        mimeType: String
    ) async throws -> RLAttachmentUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"

        guard let url = URL(string: "\(service.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw APIError.unauthorized
        }

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = extractErrorDetailFromData(data)
            switch httpResponse.statusCode {
            case 401: throw APIError.unauthorized
            case 400, 422: throw APIError.badRequest(detail)
            default: throw APIError.serverError(httpResponse.statusCode, detail)
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RLAttachmentUploadResponse.self, from: data)
    }

    /// Upload attachment for a chatroom message
    func uploadChatroomAttachment(guildId: UUID, chatroomId: UUID, fileData: Data, filename: String, mimeType: String) async throws -> RLAttachmentUploadResponse {
        try await uploadAttachment(
            endpoint: "/messaging/guilds/\(guildId)/chatrooms/\(chatroomId)/upload",
            service: .core,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType
        )
    }

    /// Upload attachment for a DM message
    func uploadDMAttachment(guildId: UUID, threadId: UUID, fileData: Data, filename: String, mimeType: String) async throws -> RLAttachmentUploadResponse {
        try await uploadAttachment(
            endpoint: "/messaging/guilds/\(guildId)/dms/\(threadId)/upload",
            service: .core,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType
        )
    }

    /// Upload attachment for a chart chat message
    func uploadChartChatAttachment(guildId: UUID, chatId: UUID, fileData: Data, filename: String, mimeType: String) async throws -> RLAttachmentUploadResponse {
        try await uploadAttachment(
            endpoint: "/chart/guilds/\(guildId)/chart-chats/\(chatId)/upload",
            service: .chart,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType
        )
    }

    /// Upload attachment for a marker comment
    func uploadMarkerCommentAttachment(guildId: UUID, markerId: UUID, fileData: Data, filename: String, mimeType: String) async throws -> RLAttachmentUploadResponse {
        try await uploadAttachment(
            endpoint: "/chart/guilds/\(guildId)/markers/\(markerId)/comments/upload",
            service: .chart,
            fileData: fileData,
            filename: filename,
            mimeType: mimeType
        )
    }

    /// Remove avatar (revert to default)
    /// DELETE /users/me/avatar
    func removeAvatar() async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/avatar",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }
    
    // Helper to extract error detail from response data
    private func extractErrorDetailFromData(_ data: Data) -> String {
        extractErrorDetail(from: data)
    }
    
    // =============================================================================================
    // MARK: - Email Change
    // =============================================================================================
    
    /// Request email change (sends verification to new email)
    /// POST /users/me/email/change-request
    func requestEmailChange(_ emailRequest: RLEmailChangeRequest) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/email/change-request",
            service: .core,
            method: "POST",
            body: emailRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Password Change
    // =============================================================================================
    
    /// Change password
    /// PUT /users/me/password
    func changePassword(_ passwordRequest: RLPasswordChangeRequest) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/password",
            service: .core,
            method: "PUT",
            body: passwordRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Date of Birth
    // =============================================================================================
    
    /// Update date of birth
    /// PUT /users/me/dob
    func updateDateOfBirth(_ dobRequest: RLDOBUpdateRequest) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/dob",
            service: .core,
            method: "PUT",
            body: dobRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Blocked Users
    // =============================================================================================
    
    /// Get list of blocked users
    /// GET /users/me/blocked
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
    
    // =============================================================================================
    // MARK: - User Settings
    // =============================================================================================
    
    /// Get current user settings
    /// GET /users/me/settings
    func getUserSettings() async throws -> RLUserSettingsDTO {
        return try await request(
            "/users/me/settings",
            service: .core,
            method: "GET",
            auth: true
        )
    }
    
    /// Update user settings
    /// PUT /users/me/settings
    func updateUserSettings(_ updateRequest: RLUserSettingsUpdateRequest) async throws -> RLUserSettingsDTO {
        return try await request(
            "/users/me/settings",
            service: .core,
            method: "PUT",
            body: updateRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Device Tokens (Push Notifications)
    // =============================================================================================

    /// Register a device token for APNs push notifications
    /// POST /users/me/device-tokens
    func registerDeviceToken(deviceToken: String, platform: String = "ios") async throws {
        let body = RLDeviceTokenRegisterRequest(deviceToken: deviceToken, platform: platform)
        let _: RLDeviceTokenResponse = try await request(
            "/users/me/device-tokens",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Deregister a device token (on logout)
    /// DELETE /users/me/device-tokens
    func deregisterDeviceToken(deviceToken: String) async throws {
        let body = RLDeviceTokenDeleteRequest(deviceToken: deviceToken)
        let _: EmptyResponse = try await request(
            "/users/me/device-tokens",
            service: .core,
            method: "DELETE",
            body: body,
            auth: true
        )
    }

    // =============================================================================================
    // MARK: - Push Notification Preferences
    // =============================================================================================

    /// Fetch push notification preferences
    /// GET /users/me/push-preferences
    func getPushPreferences() async throws -> RLPushNotificationPreferences {
        return try await request(
            "/users/me/push-preferences",
            service: .core,
            method: "GET",
            auth: true
        )
    }

    /// Update push notification preferences (partial update)
    /// PATCH /users/me/push-preferences
    func updatePushPreferences(_ update: RLPushPreferencesUpdateRequest) async throws -> RLPushNotificationPreferences {
        return try await request(
            "/users/me/push-preferences",
            service: .core,
            method: "PATCH",
            body: update,
            auth: true
        )
    }

    // =============================================================================================
    // MARK: - Data Export
    // =============================================================================================
    
    /// Request data export (GDPR compliance)
    /// POST /users/me/data-export
    func requestDataExport() async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me/data-export",
            service: .core,
            method: "POST",
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Account Deletion
    // =============================================================================================
    
    /// Delete account permanently
    /// DELETE /users/me
    func deleteAccount(_ deleteRequest: RLDeleteAccountRequest) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/me",
            service: .core,
            method: "DELETE",
            body: deleteRequest,
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Support Tickets
    // =============================================================================================
    
    /// Submit a support ticket
    /// POST /users/support/tickets
    func submitSupportTicket(_ ticketRequest: RLSupportTicketRequest) async throws -> RLDetailResponseDTO {
        return try await request(
            "/users/support/tickets",
            service: .core,
            method: "POST",
            body: ticketRequest,
            auth: true
        )
    }

    /// Fetch authenticated runtime feature flags
    /// GET /users/me/runtime-flags
    func getRuntimeFlags() async throws -> RLRuntimeFlagsDTO {
        try await request(
            "/users/me/runtime-flags",
            service: .core,
            method: "GET",
            auth: true
        )
    }
}


// =============================================================================================
// MARK: - Notifications
// =============================================================================================
extension RealAPIService {
    
    // =============================================================================
    // CORRECTED NOTIFICATION METHODS - REPLACE in RealAPIService.swift
    // =============================================================================
    //
    // Your request() method signature is:
    //
    //   private func request<T: Decodable>(
    //       _ endpoint: String,           // positional, no label
    //       service: APIService = .core,
    //       method: String = "GET",
    //       body: Encodable? = nil,
    //       auth: Bool = false,
    //       isRetry: Bool = false
    //   ) async throws -> T
    //
    // Issues in the original:
    //   1. Used named `endpoint:` label — should be positional (no label)
    //   2. Used `queryItems:` parameter — doesn't exist on request()
    //   3. Missing `auth: true` on all calls (all notification endpoints require auth)
    //
    // Fix: Build query strings manually in the endpoint URL (same pattern
    // you use elsewhere, e.g. clearReadNotifications already did this).
    // =============================================================================


    // MARK: - Notification Endpoints

    /// Fetch paginated notifications
    /// GET /api/v1/notifications?page=1&page_size=20&notification_types=dm,chatroom&is_read=false
    func getNotifications(
        types: [String]? = nil,
        isRead: Bool? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> RLNotificationListDTO {
        // Build query string manually since request() doesn't support queryItems
        var queryParts: [String] = [
            "page=\(page)",
            "page_size=\(pageSize)"
        ]
        if let types = types, !types.isEmpty {
            queryParts.append("notification_types=\(types.joined(separator: ","))")
        }
        if let isRead = isRead {
            queryParts.append("is_read=\(isRead)")
        }
        let queryString = queryParts.joined(separator: "&")

        return try await request(
            "/notifications?\(queryString)",
            service: .core,
            auth: true
        )
    }


    /// Fetch notification badge counts
    /// GET /api/v1/notifications/stats
    func getNotificationStats() async throws -> RLNotificationStatsDTO {
        return try await request(
            "/notifications/stats",
            service: .core,
            auth: true
        )
    }


    /// Mark specific notifications as read
    /// POST /api/v1/notifications/mark-read
    func markNotificationsAsRead(ids: [UUID]) async throws {
        let body = RLNotificationMarkReadRequest(notificationIds: ids)
        let _: EmptyResponse = try await request(
            "/notifications/mark-read",
            service: .core,
            method: "POST",
            body: body,
            auth: true
        )
    }


    /// Mark all notifications as read
    /// POST /api/v1/notifications/mark-all-read
    func markAllNotificationsAsRead() async throws {
        let _: EmptyResponse = try await request(
            "/notifications/mark-all-read",
            service: .core,
            method: "POST",
            auth: true
        )
    }


    /// Record a notification view (analytics)
    /// POST /api/v1/notifications/{id}/view
    func recordNotificationView(notificationId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/notifications/\(notificationId)/view",
            service: .core,
            method: "POST",
            auth: true
        )
    }


    /// Delete specific notifications
    /// DELETE /api/v1/notifications
    func deleteNotifications(ids: [UUID], softDelete: Bool = true) async throws {
        let body = RLNotificationDeleteRequest(notificationIds: ids, softDelete: softDelete)
        let _: EmptyResponse = try await request(
            "/notifications",
            service: .core,
            method: "DELETE",
            body: body,
            auth: true
        )
    }


    /// Clear all read notifications
    /// DELETE /api/v1/notifications/clear-read
    func clearReadNotifications(softDelete: Bool = true) async throws {
        let _: EmptyResponse = try await request(
            "/notifications/clear-read?soft_delete=\(softDelete)",
            service: .core,
            method: "DELETE",
            auth: true
        )
    }
}






//
//  RealAPIService+Chart.swift
//  TradersGuild
//
//  Chart & Market Data API extension for RealAPIService.
//  Maps to backend chart_routes.py endpoints.
//
//  Base path: /api/v1/chart (via chart-service or core-service)
//
//  Route pattern follows messaging extension:
//    - Symbols: /chart/symbols/...
//    - Candles: /chart/symbols/{id}/candles
//    - Personal watchlist: /chart/watchlist/personal
//    - Guild watchlist: /chart/guilds/{id}/watchlist
//    - Markers: /chart/guilds/{id}/markers/...
//    - Chart chats: /chart/chart-chats/...
//    - Combined: /chart/guilds/{id}/symbols/{id}/chart-data
//


// MARK: - Chart API Extension
// =============================================================================================
extension RealAPIService {
    
    // =============================================================================================
    // MARK: - Symbol Search & Listing
    // =============================================================================================
    
    /// Search trading symbols by ticker or name
    /// GET /chart/symbols/search?query=...&asset_class=...&limit=...
    func searchSymbols(
        query: String,
        assetClass: String? = nil,
        limit: Int = 20
    ) async throws -> RLSymbolSearchDTO {
        var path = "/chart/symbols/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&limit=\(limit)"
        if let assetClass = assetClass {
            path += "&asset_class=\(assetClass)"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Get a single trading symbol with live price
    /// GET /chart/symbols/{symbol_id}
    func getSymbol(symbolId: UUID) async throws -> RLTradingSymbolDTO {
        return try await request(
            "/chart/symbols/\(symbolId.uuidString)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// List active trading symbols
    /// GET /chart/symbols?asset_class=...&limit=...
    func listSymbols(
        assetClass: String? = nil,
        limit: Int = 50
    ) async throws -> [RLTradingSymbolDTO] {
        var path = "/chart/symbols?limit=\(limit)"
        if let assetClass = assetClass {
            path += "&asset_class=\(assetClass)"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// Get active market data provider status.
    /// GET /chart/market-data/provider
    func getMarketDataProviderStatus() async throws -> RLMarketDataProviderStatusDTO {
        return try await request(
            "/chart/market-data/provider",
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// List global active symbols with membership flags for the current guild.
    /// GET /chart/symbols/global?guild_id=...&limit=...&cursor=...&asset_class=...
    func getGlobalSymbols(
        guildId: UUID,
        limit: Int = 100,
        cursor: String? = nil,
        assetClass: String? = nil
    ) async throws -> RLGlobalSymbolsListDTO {
        var queryParts: [String] = [
            "guild_id=\(guildId.uuidString)",
            "limit=\(limit)"
        ]
        if let cursor = cursor, !cursor.isEmpty {
            let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            queryParts.append("cursor=\(encodedCursor)")
        }
        if let assetClass = assetClass, !assetClass.isEmpty {
            queryParts.append("asset_class=\(assetClass)")
        }

        let path = "/chart/symbols/global?\(queryParts.joined(separator: "&"))"
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Candle History
    // =============================================================================================
    
    /// Fetch historical candles for a symbol + timeframe
    /// GET /chart/symbols/{symbol_id}/candles?timeframe=...&limit=...&end_time=...
    ///
    /// Returns paginated candles with cursor-based pagination via end_time.
    /// Base timeframe (1m) queries directly; aggregated timeframes use TimescaleDB time_bucket.
    func getCandles(
        symbolId: UUID,
        timeframe: String = "1m",
        limit: Int = 200,
        endTime: Date? = nil,
        continuousTime: Bool = false
    ) async throws -> RLCandleListDTO {
        var path = "/chart/symbols/\(symbolId.uuidString)/candles?timeframe=\(timeframe)&limit=\(limit)"
        if let endTime = endTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            path += "&end_time=\(formatter.string(from: endTime))"
        }
        if continuousTime {
            path += "&continuous_time=true"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Personal Watchlist
    // =============================================================================================
    
    /// Get user's personal watchlist with live prices
    /// GET /chart/watchlist/personal
    func getPersonalWatchlist() async throws -> RLPersonalWatchlistDTO {
        return try await request(
            "/chart/watchlist/personal",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Add symbol to personal watchlist
    /// POST /chart/watchlist/personal
    func addToPersonalWatchlist(symbolId: UUID) async throws -> RLWatchlistSymbolDTO {
        let body = RLWatchlistAddRequest(symbolId: symbolId)
        return try await request(
            "/chart/watchlist/personal",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Remove symbol from personal watchlist
    /// DELETE /chart/watchlist/personal/{symbol_id}
    func removeFromPersonalWatchlist(symbolId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/chart/watchlist/personal/\(symbolId.uuidString)",
            service: .chart,
            method: "DELETE",
            auth: true
        )
    }
    
    /// Reorder personal watchlist
    /// PUT /chart/watchlist/personal/reorder
    func reorderPersonalWatchlist(symbolIds: [UUID]) async throws -> RLDetailResponseDTO {
        let body = RLWatchlistReorderRequest(symbolIds: symbolIds)
        return try await request(
            "/chart/watchlist/personal/reorder",
            service: .chart,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Guild Watchlist
    // =============================================================================================
    
    /// Get guild's shared watchlist with live prices
    /// GET /chart/guilds/{guild_id}/watchlist
    func getGuildWatchlist(guildId: UUID) async throws -> RLGuildWatchlistDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/watchlist",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Add symbol to guild watchlist (admin/owner only)
    /// POST /chart/guilds/{guild_id}/watchlist
    func addToGuildWatchlist(guildId: UUID, symbolId: UUID) async throws -> RLWatchlistSymbolDTO {
        let body = RLWatchlistAddRequest(symbolId: symbolId)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/watchlist",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Remove symbol from guild watchlist (admin/owner only)
    /// DELETE /chart/guilds/{guild_id}/watchlist/{symbol_id}
    func removeFromGuildWatchlist(guildId: UUID, symbolId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/watchlist/\(symbolId.uuidString)",
            service: .chart,
            method: "DELETE",
            auth: true
        )
    }
    
    /// Request a guild watchlist addition
    /// POST /chart/guilds/{guild_id}/watchlist/requests
    func requestGuildWatchlistAddition(guildId: UUID, symbolId: UUID, reason: String? = nil) async throws -> RLGuildWatchlistRequestResponseDTO {
        let body = RLGuildWatchlistAddRequestDTO(symbolId: symbolId, reason: reason)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/watchlist/requests",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// List guild watchlist requests
    /// GET /chart/guilds/{guild_id}/watchlist/requests?status={status}
    func getGuildWatchlistRequests(
        guildId: UUID,
        status: String = "pending"
    ) async throws -> RLGuildWatchlistRequestsListResponseDTO {
        let path = "/chart/guilds/\(guildId.uuidString)/watchlist/requests?status=\(status)"
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// Review a guild watchlist request (approve/reject)
    /// PATCH /chart/guilds/{guild_id}/watchlist/requests/{request_id}
    func reviewGuildWatchlistRequest(
        guildId: UUID,
        requestId: UUID,
        action: String,
        reviewNote: String? = nil
    ) async throws -> RLGuildWatchlistRequestResponseDTO {
        let body = RLGuildWatchlistReviewRequestDTO(action: action, reviewNote: reviewNote)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/watchlist/requests/\(requestId.uuidString)",
            service: .chart,
            method: "PATCH",
            body: body,
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Chart Markers
    // =============================================================================================
    
    /// Get markers for a symbol within a guild
    /// GET /chart/guilds/{guild_id}/symbols/{symbol_id}/markers?timeframe=...&limit=...&cursor=...
    func getMarkers(
        guildId: UUID,
        symbolId: UUID,
        timeframe: String = "1m",
        limit: Int = 50,
        cursor: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws -> RLMarkersListDTO {
        var path = "/chart/guilds/\(guildId.uuidString)/symbols/\(symbolId.uuidString)/markers?timeframe=\(timeframe)&limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let startTime = startTime {
            path += "&start_time=\(formatter.string(from: startTime))"
        }
        if let endTime = endTime {
            path += "&end_time=\(formatter.string(from: endTime))"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// Get a single marker by ID for notification recovery/deep linking.
    /// GET /chart/markers/{marker_id}
    func getMarker(markerId: UUID) async throws -> RLChartMarkerDTO {
        try await request(
            "/chart/markers/\(markerId.uuidString)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Create a new chart marker
    /// POST /chart/guilds/{guild_id}/markers
    func createMarkerV2(
        guildId: UUID,
        request body: RLCreateMarkerRequest
    ) async throws -> RLChartMarkerDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }

    /// Update a chart marker (owner only)
    /// PUT /chart/guilds/{guild_id}/markers/{marker_id}
    func updateMarkerV2(
        guildId: UUID,
        markerId: UUID,
        request body: RLUpdateMarkerRequest
    ) async throws -> RLChartMarkerDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)",
            service: .chart,
            method: "PUT",
            body: body,
            auth: true
        )
    }

    /// Delete a chart marker
    /// DELETE /chart/guilds/{guild_id}/markers/{marker_id}
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLDetailResponseDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)",
            service: .chart,
            method: "DELETE",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Marker Likes
    // =============================================================================================
    
    /// Toggle like on a marker
    /// POST /chart/guilds/{guild_id}/markers/{marker_id}/like
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/like",
            service: .chart,
            method: "POST",
            auth: true
        )
    }
    
    /// Get top markers (trending, by symbol, following, mine)
    /// GET /chart/guilds/{guild_id}/top-markers
    func getTopMarkers(guildId: UUID, timeWindowHours: Int = 48) async throws -> RLTopMarkersListDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/top-markers?time_window_hours=\(timeWindowHours)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// Get marker activity feed for marker-management surfaces
    /// GET /chart/guilds/{guild_id}/marker-activity
    func getMarkerActivity(
        guildId: UUID,
        symbolId: UUID? = nil,
        scope: RLMarkerActivityScope,
        state: RLMarkerActivityState,
        window: RLMarkerActivityWindow? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        intent: String? = nil,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLMarkerActivityListDTO {
        var queryItems = [
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(name: "state", value: state.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let formatter = ISO8601DateFormatter()

        if let symbolId {
            queryItems.append(URLQueryItem(name: "symbol_id", value: symbolId.uuidString))
        }
        if let window {
            queryItems.append(URLQueryItem(name: "window", value: window.rawValue))
        }
        if let startTime {
            queryItems.append(URLQueryItem(name: "start_time", value: formatter.string(from: startTime)))
        }
        if let endTime {
            queryItems.append(URLQueryItem(name: "end_time", value: formatter.string(from: endTime)))
        }
        if let intent, !intent.isEmpty {
            queryItems.append(URLQueryItem(name: "intent", value: intent))
        }
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""

        return try await request(
            "/chart/guilds/\(guildId.uuidString)/marker-activity\(query)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    /// Get markers placed by a specific user in a guild (for viewing other users' profiles)
    /// GET /chart/guilds/{guild_id}/users/{user_id}/markers
    func getUserMarkers(guildId: UUID, userId: UUID) async throws -> RLTopMarkersListDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/users/\(userId.uuidString)/markers",
            service: .chart,
            method: "GET",
            auth: true
        )
    }

    // =============================================================================================
    // MARK: - Marker Comments
    // =============================================================================================
    
    /// Get comments for a marker (paginated)
    /// GET /chart/markers/{marker_id}/comments?limit=...&cursor=...
    func getMarkerComments(
        markerId: UUID,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> RLMarkerCommentsListDTO {
        var path = "/chart/markers/\(markerId.uuidString)/comments?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Add a comment to a marker
    /// POST /chart/guilds/{guild_id}/markers/{marker_id}/comments
    func addMarkerComment(
        guildId: UUID,
        markerId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        replyToMessageId: UUID? = nil
    ) async throws -> RLMarkerCommentDTO {
        let body = RLCreateMarkerCommentRequest(
            content: content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            replyToMessageId: replyToMessageId
        )
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Edit a marker comment (owner only)
    /// PUT /chart/guilds/{guild_id}/markers/{marker_id}/comments/{comment_id}
    func editMarkerComment(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        content: String
    ) async throws -> RLMarkerCommentDTO {
        let body = RLEditMarkerCommentRequest(content: content)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments/\(commentId.uuidString)",
            service: .chart,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Delete a marker comment
    /// DELETE /chart/guilds/{guild_id}/markers/{marker_id}/comments/{comment_id}
    func deleteMarkerComment(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID
    ) async throws -> RLDetailResponseDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments/\(commentId.uuidString)",
            service: .chart,
            method: "DELETE",
            auth: true
        )
    }

    func toggleMarkerCommentReaction(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMarkerCommentDTO {
        let body = RLToggleMessageReactionRequest(emoji: emoji)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments/\(commentId.uuidString)/reactions",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func getMarkerCommentReactionReactors(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? emoji
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/comments/\(commentId.uuidString)/reactions?emoji=\(encodedEmoji)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Marker Polls
    // =============================================================================================
    
    /// Vote on a poll marker
    /// POST /chart/guilds/{guild_id}/markers/{marker_id}/vote
    func voteOnPoll(
        guildId: UUID,
        markerId: UUID,
        optionId: UUID
    ) async throws -> RLVotePollDTO {
        let body = RLVotePollRequest(optionId: optionId)
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/markers/\(markerId.uuidString)/vote",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Chart Chats
    // =============================================================================================
    
    /// Get or create a chart chat for a specific symbol + guild
    /// POST /chart/guilds/{guild_id}/symbols/{symbol_id}/chart-chat
    func getOrCreateChartChat(
        guildId: UUID,
        symbolId: UUID
    ) async throws -> RLChartChatDTO {
        return try await request(
            "/chart/guilds/\(guildId.uuidString)/symbols/\(symbolId.uuidString)/chart-chat",
            service: .chart,
            method: "POST",
            auth: true
        )
    }
    
    /// Get paginated messages for a chart chat
    /// GET /chart/chart-chats/{chat_id}/messages?limit=...&cursor=...
    func getChartChatMessages(
        chatId: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLChartChatMessagesListDTO {
        var path = "/chart/chart-chats/\(chatId.uuidString)/messages?limit=\(limit)"
        if let cursor = cursor {
            path += "&cursor=\(cursor)"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    /// Send a message to a chart chat
    /// POST /chart/chart-chats/{chat_id}/messages
    func sendChartChatMessage(
        chatId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO] = [],
        replyToMessageId: UUID? = nil
    ) async throws -> RLChartChatMessageDTO {
        let body = RLSendChartChatMessageRequest(
            content: content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            attachments: attachments.isEmpty ? nil : attachments,
            replyToMessageId: replyToMessageId
        )
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/messages",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
    
    /// Edit a chart chat message (owner only, within 15 min)
    /// PUT /chart/chart-chats/{chat_id}/messages/{message_id}
    func editChartChatMessage(
        chatId: UUID,
        messageId: UUID,
        content: String
    ) async throws -> RLChartChatMessageDTO {
        let body = RLEditChartChatMessageRequest(content: content)
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/messages/\(messageId.uuidString)",
            service: .chart,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Delete a chart chat message
    /// DELETE /chart/chart-chats/{chat_id}/messages/{message_id}
    func deleteChartChatMessage(
        chatId: UUID,
        messageId: UUID
    ) async throws -> RLDetailResponseDTO {
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/messages/\(messageId.uuidString)",
            service: .chart,
            method: "DELETE",
            auth: true
        )
    }

    func toggleChartChatMessageReaction(
        chatId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLChartChatMessageDTO {
        let body = RLToggleMessageReactionRequest(emoji: emoji)
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/messages/\(messageId.uuidString)/reactions",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }

    func getChartChatMessageReactionReactors(
        chatId: UUID,
        messageId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? emoji
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/messages/\(messageId.uuidString)/reactions?emoji=\(encodedEmoji)",
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    
    // =============================================================================================
    // MARK: - Combined Chart Data
    // =============================================================================================
    
    /// Fetch symbol + candles + markers in one request (for initial chart load)
    /// GET /chart/guilds/{guild_id}/symbols/{symbol_id}/chart-data?timeframe=...&candle_limit=...
    func getChartData(
        guildId: UUID,
        symbolId: UUID,
        timeframe: String = "1m",
        candleLimit: Int = 200,
        continuousTime: Bool = false
    ) async throws -> RLChartDataDTO {
        var path = "/chart/guilds/\(guildId.uuidString)/symbols/\(symbolId.uuidString)/chart-data?timeframe=\(timeframe)&candle_limit=\(candleLimit)"
        if continuousTime {
            path += "&continuous_time=true"
        }
        return try await request(
            path,
            service: .chart,
            method: "GET",
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Chart Chat Settings
    // =============================================================================================
    
    /// Update mute/pin settings for a chart chat
    /// PUT /chart/chart-chats/{chat_id}/settings
    func updateChartChatSettings(
        chatId: UUID,
        isMuted: Bool? = nil,
        isPinned: Bool? = nil
    ) async throws -> RLChartChatUserSettingsDTO {
        let body = RLUpdateChartChatSettingsRequest(isMuted: isMuted, isPinned: isPinned)
        return try await request(
            "/chart/chart-chats/\(chatId.uuidString)/settings",
            service: .chart,
            method: "PUT",
            body: body,
            auth: true
        )
    }
    
    /// Mark chart chat as read (resets unread count)
    /// POST /chart/chart-chats/{chat_id}/mark-read
    func markChartChatRead(chatId: UUID) async throws {
        let _: EmptyResponse = try await request(
            "/chart/chart-chats/\(chatId.uuidString)/mark-read",
            service: .chart,
            method: "POST",
            auth: true
        )
    }
    
    // =============================================================================================
    // MARK: - Content Reporting
    // =============================================================================================
    
    /// Report content (works for all content types: messages, markers, comments)
    /// POST /chart/report
    func reportContent(
        contentType: String,
        contentId: UUID,
        guildId: UUID? = nil,
        reason: String,
        details: String? = nil
    ) async throws -> RLContentReportDTO {
        let body = RLReportContentRequest(
            contentType: contentType,
            contentId: contentId,
            guildId: guildId,
            reason: reason,
            details: details
        )
        return try await request(
            "/chart/report",
            service: .chart,
            method: "POST",
            body: body,
            auth: true
        )
    }
}


// ================================================================================================
// MARK: - Reputation API Extension
// ================================================================================================

extension RealAPIService {

    // MARK: - Tier Definitions

    /// Get all reputation tier definitions for client display
    func getReputationTiers() async throws -> [RLReputationTierDTO] {
        return try await request(
            "/reputation/tiers",
            service: .reputation,
            auth: true
        )
    }

    // MARK: - Guild Reputation Profile

    /// Get current user's reputation profile within a specific guild
    func getMyGuildReputation(guildId: UUID) async throws -> RLReputationProfileDTO {
        return try await request(
            "/reputation/me/guild/\(guildId.uuidString)",
            service: .reputation,
            auth: true
        )
    }

    /// Get another user's reputation profile within a specific guild
    func getUserGuildReputation(userId: UUID, guildId: UUID) async throws -> RLReputationProfileDTO {
        return try await request(
            "/reputation/users/\(userId.uuidString)/guild/\(guildId.uuidString)",
            service: .reputation,
            auth: true
        )
    }

    // MARK: - Global Reputation

    /// Get current user's global cross-guild reputation
    func getMyGlobalReputation() async throws -> RLGlobalReputationDTO {
        return try await request(
            "/reputation/me/global",
            service: .reputation,
            auth: true
        )
    }

    /// Get another user's global cross-guild reputation
    func getUserGlobalReputation(userId: UUID) async throws -> RLGlobalReputationDTO {
        return try await request(
            "/reputation/users/\(userId.uuidString)/global",
            service: .reputation,
            auth: true
        )
    }

    // MARK: - Leaderboard

    /// Get guild reputation leaderboard
    func getGuildReputationLeaderboard(guildId: UUID, limit: Int = 50) async throws -> RLReputationLeaderboardDTO {
        return try await request(
            "/reputation/guilds/\(guildId.uuidString)/leaderboard?limit=\(limit)",
            service: .reputation,
            auth: true
        )
    }

    // MARK: - History

    /// Get paginated reputation event history for current user
    func getReputationHistory(guildId: UUID? = nil, page: Int = 1, pageSize: Int = 20) async throws -> RLReputationHistoryDTO {
        var path = "/reputation/me/history?page=\(page)&page_size=\(pageSize)"
        if let guildId = guildId {
            path += "&guild_id=\(guildId.uuidString)"
        }
        return try await request(
            path,
            service: .reputation,
            auth: true
        )
    }

    // =========================================================================
    // MARK: - Trading Accuracy
    // =========================================================================

    /// Get my accuracy profile within a specific guild.
    func getMyGuildAccuracy(guildId: UUID) async throws -> RLAccuracyProfileDTO {
        return try await request(
            "/reputation/me/accuracy/guild/\(guildId.uuidString)",
            service: .reputation,
            auth: true
        )
    }

    /// Get another user's accuracy profile within a specific guild.
    func getUserGuildAccuracy(userId: UUID, guildId: UUID) async throws -> RLAccuracyProfileDTO {
        return try await request(
            "/reputation/users/\(userId.uuidString)/accuracy/guild/\(guildId.uuidString)",
            service: .reputation,
            auth: true
        )
    }

    /// Get my global accuracy profile (weighted across all guilds).
    func getMyGlobalAccuracy() async throws -> RLAccuracyProfileDTO {
        return try await request(
            "/reputation/me/accuracy/global",
            service: .reputation,
            auth: true
        )
    }

    /// Get the accuracy leaderboard for a guild.
    func getGuildAccuracyLeaderboard(guildId: UUID, minPredictions: Int = 10, limit: Int = 50) async throws -> RLAccuracyLeaderboardDTO {
        return try await request(
            "/reputation/guilds/\(guildId.uuidString)/accuracy-leaderboard?min_predictions=\(minPredictions)&limit=\(limit)",
            service: .reputation,
            auth: true
        )
    }

    func getGlobalUsersLeaderboard(limit: Int = 100, minPredictions: Int = 0) async throws -> RLGlobalUserLeaderboardDTO {
        return try await request(
            "/reputation/global-users-leaderboard?limit=\(limit)&min_predictions=\(minPredictions)",
            service: .reputation,
            auth: true
        )
    }
}
