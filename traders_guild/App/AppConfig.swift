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
    static let appleSignInClientID = "com.yourapp.ios"

    // Routing mode for dev-first direct services vs future gateway
    static var apiRoutingMode: APIRoutingMode {
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
        normalizedEnvURL(
            keys: ["TG_GATEWAY_BASE_URL_PROD"],
            fallback: "https://api.tradersguild.com/api/v1"
        )
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
}
