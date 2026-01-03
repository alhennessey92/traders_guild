//
//  RealApiService.swift
//  traders_guild
//
//  Created by Al Hennessey on 02/01/2026.
//

//
//  RealAPIService.swift
//  traders_guild
//
//  Real API service - works alongside MockAPIService
//  Migrate endpoints gradually: real for auth, mock for everything else
//

import Foundation

// MARK: - API Configuration
enum APIConfig {
    #if targetEnvironment(simulator)
    static let baseURL = "http://localhost:8001/api/v1"
    #else
    // ⚠️ UPDATE THIS to your Mac's IP for device testing
    static let baseURL = "http://192.168.1.182:8001/api/v1"
    #endif
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case unauthorized
    case badRequest(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .unauthorized: return "Please log in again"
        case .badRequest(let msg): return msg
        }
    }
}

// MARK: - Real API Service
class RealAPIService {
    
    private var accessToken: String?
    
    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    // MARK: - Token Management
    
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }
    
    // MARK: - Generic Request
    
    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        auth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if auth {
            guard let token = accessToken else { throw APIError.unauthorized }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        #if DEBUG
        print("🌐 \(method) \(endpoint)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        #if DEBUG
        print("📥 \(http.statusCode)")
        print(data)
        if let str = String(data: data, encoding: .utf8)?.prefix(500) { print("📥 \(str)") }
        #endif
        
        guard (200...299).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? "Error"
            if http.statusCode == 401 { throw APIError.unauthorized }
            if http.statusCode == 400 || http.statusCode == 422 { throw APIError.badRequest(detail) }
            throw APIError.serverError(http.statusCode, detail)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // ================================================================================================
    // MARK: - Auth API (REAL) - Same signatures as MockAPIService
    // ================================================================================================
    
    /// Sign up - returns same authResponse type as MockAPIService
    func signUp(data: SignupData) async throws -> authResponse {
    
        let tokens: TokenRes = try await request("/auth/register", method: "POST", body: [
            "email": data.email,
            "username": data.username,
            "password": data.password,
            "name": data.name
        ])
        
        self.accessToken = tokens.accessToken
        
        let user: UserRes = try await request("/users/me", auth: true)
        
        return authResponse(
            user: user.toCurrentUserDTO(),
            token: tokens.accessToken
        )
    }
    
    /// Login - returns same authResponse type as MockAPIService
    func login(email: String, password: String) async throws -> authResponse {
        let tokens: TokenRes = try await request("/auth/login", method: "POST", body: [
            "email": email,
            "password": password
        ])
        
        self.accessToken = tokens.accessToken
        
        let user: UserRes = try await request("/users/me", auth: true)
        
        return authResponse(
            user: user.toCurrentUserDTO(),
            token: tokens.accessToken
        )
    }
    
    // ================================================================================================
    // MARK: - Guild API (Uncomment when backend ready)
    // ================================================================================================
    
    /*
    func fetchOpenGuilds() async throws -> [GuildDTO] {
        let res: GuildListRes = try await request("/guilds?is_open=true")
        return res.items.map { $0.toGuildDTO() }
    }
    
    func joinGuild(guildId: UUID) async throws {
        struct Empty: Codable {}
        let _: Empty = try await request("/guilds/\(guildId)/members", method: "POST", auth: true)
    }
    */
}

// ================================================================================================
// MARK: - Backend Response Types (Private)
// ================================================================================================

private struct TokenRes: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}

private struct UserRes: Codable {
    let email: String
    let username: String
    let displayName: String
    let avatarUrl: String?
    let id: UUID
    let globalReputation: Int
    let isOnline: Bool
    let isVerified: Bool
    let isSuperuser: Bool
    let lastSeenAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let dateOfBirth: Date?
    
    /// Convert backend response to your existing CurrentUserDTO
    func toCurrentUserDTO() -> CurrentUserDTO {
        // Reuse SampleData's membership structure as placeholder
        // This gets replaced when user actually joins/selects a guild
        let placeholderMembership = SampleData.currentUser.guildMembership
        
        return CurrentUserDTO(
            id: id,
            email: email,
            name: displayName,
            username: username,
            avatarURL: avatarUrl,
            globalReputation: globalReputation,
            notificationCount: 0,
            unreadMessages: 0,
            guildMembership: placeholderMembership
        )
    }
}
