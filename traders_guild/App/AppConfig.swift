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
        if let raw = ProcessInfo.processInfo.environment["TG_API_ROUTING_MODE"],
           let mode = APIRoutingMode(rawValue: raw.uppercased()) {
            return mode
        }

        #if DEBUG
        return .directServices
        #else
        return .apiGateway
        #endif
    }

    static var developmentGatewayBaseURL: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["TG_GATEWAY_BASE_URL_DEV_SIMULATOR"]
            ?? ProcessInfo.processInfo.environment["TG_GATEWAY_BASE_URL_DEV"]
            ?? "http://localhost:30080/api/v1"
        #else
        return ProcessInfo.processInfo.environment["TG_GATEWAY_BASE_URL_DEV_DEVICE"]
            ?? ProcessInfo.processInfo.environment["TG_GATEWAY_BASE_URL_DEV"]
            ?? "http://localhost:30080/api/v1"
        #endif
    }

    static var productionGatewayBaseURL: String {
        ProcessInfo.processInfo.environment["TG_GATEWAY_BASE_URL_PROD"] ?? "https://api.tradersguild.com/api/v1"
    }
}
