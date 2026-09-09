//
//  AppConfig.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation

enum APIRoutingMode: String {
    case directServices = "DIRECT_SERVICES"
    case apiGateway = "API_GATEWAY"
}

// A struct to hold app constants like API endpoints, keys, and feature flags
struct AppConfig {
    // Base URL for your backend API (legacy)
    static let baseURL = "https://api.yourapp.com"

    // Apple Sign-In Client ID for authentication
    static let appleSignInClientID = "co.tradersguild.app"

    // Routing mode for dev-first direct services vs future gateway
    static var apiRoutingMode: APIRoutingMode {
        #if TG_ISOLATED_DEV
        // The isolated DEV build bakes its routing into the bundle, ahead of any
        // environment lookup. See `bakedDevGatewayBaseURL` for why.
        if let raw = bakedValue(key: "TGDevRoutingMode"),
           let mode = APIRoutingMode(rawValue: raw.uppercased()) {
            return mode
        }
        #endif

        if let raw = normalizedEnvValue(key: "TG_API_ROUTING_MODE"),
           let mode = APIRoutingMode(rawValue: raw.uppercased()) {
            return mode
        }

        #if DEBUG
        #if !targetEnvironment(simulator)
        // Device debug runs should prefer gateway when a device gateway URL is configured,
        // even if the explicit routing mode env var is missing.
        if normalizedEnvValue(key: "TG_GATEWAY_BASE_URL_DEV_DEVICE") != nil
            || normalizedEnvValue(key: "TG_GATEWAY_BASE_URL_DEV") != nil {
            return .apiGateway
        }
        #endif
        return .directServices
        #else
        return .apiGateway
        #endif
    }

    static var developmentGatewayBaseURL: String {
        let devDefault = "http://localhost:30080/api/v1"
        #if TG_ISOLATED_DEV
        if let baked = bakedDevGatewayBaseURL { return baked }
        #endif
        #if targetEnvironment(simulator)
        return normalizedEnvURL(
            keys: ["TG_GATEWAY_BASE_URL_DEV_SIMULATOR", "TG_GATEWAY_BASE_URL_DEV"],
            fallback: devDefault
        )
        #else
        return normalizedEnvURL(
            keys: ["TG_GATEWAY_BASE_URL_DEV_DEVICE", "TG_GATEWAY_BASE_URL_DEV"],
            fallback: devDefault
        )
        #endif
    }

    static var productionGatewayBaseURL: String {
        #if TG_ISOLATED_DEV
        // The isolated build has no production endpoint. Every routing path
        // that would otherwise reach api.tradersguild.co resolves to the local
        // gateway instead, so an optimized build launched from the home screen
        // — with no scheme environment to read — cannot fall through to
        // production. This is the difference between "configured for DEV" and
        // "incapable of reaching production".
        if let baked = bakedDevGatewayBaseURL { return baked }
        #endif

        return normalizedEnvURL(
            keys: ["TG_GATEWAY_BASE_URL_PROD"],
            fallback: "https://api.tradersguild.co/api/v1"
        )
    }

    #if TG_ISOLATED_DEV
    /// Gateway URL written into the bundle at build time by the isolated DEV
    /// configurations.
    ///
    /// `ProcessInfo.environment` only carries scheme variables when Xcode
    /// launches the app. Tapping the icon — which is how any real profiling run
    /// starts, because a debugger attached from launch distorts the timings —
    /// gives an empty environment. The `UserDefaults` fallback below papers over
    /// that only *after* one Xcode-launched run has persisted a value, so a
    /// fresh install would resolve to the production gateway on first launch.
    /// Baking the value removes the ordering dependency entirely.
    static var bakedDevGatewayBaseURL: String? {
        guard let raw = bakedValue(key: "TGDevGatewayBaseURL") else { return nil }
        // An unexpanded "$(TG_LAN_HOST)" means the xcconfig was not applied;
        // treat it as absent rather than issuing requests to a literal.
        guard !raw.contains("$(") else { return nil }
        return raw
    }

    private static func bakedValue(key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    #endif

    static var sessionStorageNamespace: String {
        switch apiRoutingMode {
        case .directServices:
            #if DEBUG
            #if targetEnvironment(simulator)
            return "direct-simulator"
            #else
            return "direct-device"
            #endif
            #else
            return "direct"
            #endif
        case .apiGateway:
            let activeGatewayURL: String
            #if DEBUG
            activeGatewayURL = developmentGatewayBaseURL
            #else
            activeGatewayURL = productionGatewayBaseURL
            #endif
            return "gateway-\(sanitizedStorageComponent(from: activeGatewayURL))"
        }
    }

    private static func normalizedEnvURL(keys: [String], fallback: String) -> String {
        for key in keys {
            if let normalized = normalizedEnvValue(key: key) {
                return normalized
            }
        }
        return fallback
    }

    private static func normalizedEnvValue(key: String) -> String? {
        if let raw = ProcessInfo.processInfo.environment[key] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: key)
                return trimmed
            }
        }

        if let persisted = UserDefaults.standard.string(forKey: key) {
            let trimmed = persisted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    private static func sanitizedStorageComponent(from urlString: String) -> String {
        let fallback = urlString
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/api/v1", with: "")

        let components = URLComponents(string: urlString)
        let host = components?.host ?? fallback
        let portSuffix = components?.port.map { "-\($0)" } ?? ""
        let rawValue = "\(host)\(portSuffix)"

        let sanitized = rawValue
            .lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9]+",
                with: "-",
                options: .regularExpression
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return sanitized.isEmpty ? "unknown" : sanitized
    }
}
