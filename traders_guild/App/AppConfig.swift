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
        #if TG_PROD_QA
        return .apiGateway
        #elseif TG_ISOLATED_DEV
        // Unconditional, and deliberately not configurable. Reading the baked
        // value and falling through when it is absent would leave the one path
        // this build exists to make impossible — an environment variable, a
        // persisted UserDefaults entry, or a missing key sending it to
        // production. The isolated build routes through the gateway or not at
        // all.
        return .apiGateway
        #else

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
        #endif
    }

    static var developmentGatewayBaseURL: String {
        #if TG_PROD_QA
        return "https://api.tradersguild.co/api/v1"
        #elseif TG_ISOLATED_DEV
        return isolatedDevGatewayBaseURL
        #else
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
        #endif
    }

    static var productionGatewayBaseURL: String {
        #if TG_PROD_QA
        return "https://api.tradersguild.co/api/v1"
        #elseif TG_ISOLATED_DEV
        // The isolated build has no production endpoint at all. Not "prefers the
        // local one" — every path that would otherwise resolve to
        // api.tradersguild.co resolves to loopback, and no environment variable
        // or persisted default can override it.
        return isolatedDevGatewayBaseURL
        #else
        return normalizedEnvURL(
            keys: ["TG_GATEWAY_BASE_URL_PROD"],
            fallback: "https://api.tradersguild.co/api/v1"
        )
        #endif
    }

    #if TG_ISOLATED_DEV
    /// Where an isolated build sends everything, misconfiguration included.
    ///
    /// Loopback rather than the production host, so a broken or missing bake
    /// fails closed: the app cannot reach a server at all, which is loud and
    /// harmless. Falling back to the real gateway would make the one failure
    /// mode this build exists to prevent also the *quietest* one — an optimized
    /// build silently talking to production while looking fine.
    static let isolatedDevFailClosedBaseURL = "http://127.0.0.1:1/api/v1"

    /// The baked gateway if it is usable, otherwise the fail-closed loopback.
    static var isolatedDevGatewayBaseURL: String {
        bakedDevGatewayBaseURL ?? isolatedDevFailClosedBaseURL
    }

    /// Gateway URL written into the bundle at build time by the isolated DEV
    /// configurations.
    ///
    /// `ProcessInfo.environment` only carries scheme variables when Xcode
    /// launches the app. Tapping the icon — which is how any real profiling run
    /// starts, because a debugger attached from launch distorts the timings —
    /// gives an empty environment, and the `UserDefaults` fallback used
    /// elsewhere only helps *after* one Xcode-launched run has persisted a
    /// value. Baking the value removes the ordering dependency entirely.
    ///
    /// Returns nil rather than something unusable, and the caller substitutes
    /// loopback: see `isolatedDevFailClosedBaseURL`.
    static var bakedDevGatewayBaseURL: String? {
        guard let raw = bakedValue(key: "TGDevGatewayBaseURL") else { return nil }
        return isValidIsolatedDevURL(raw) ? raw : nil
    }

    /// A baked URL is only accepted if it is a real, local, http(s) URL.
    ///
    /// The unexpanded-`$(…)` case is the one that actually happens — Xcode
    /// substitutes build settings into Info.plist values but not keys, and a
    /// misplaced setting leaves the literal behind — but a host check matters
    /// just as much: a bake pointing anywhere public would defeat the isolation
    /// silently, so it is refused rather than trusted.
    ///
    /// It does not catch a *wrong* local address. A stale private LAN host is
    /// valid and is accepted; it simply fails to connect. That is the intended
    /// division: this guard is about never reaching somewhere public, not about
    /// guaranteeing reachability.
    static func isValidIsolatedDevURL(_ raw: String) -> Bool {
        guard !raw.contains("$("), !raw.contains(")") else { return false }
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { return false }
        return isLocalHost(host)
    }

    /// Loopback, `.local`, link-local, or an RFC1918 private address.
    private static func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" || host == "::1" { return true }
        if host.hasSuffix(".local") { return true }

        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        let octets = parts.compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }

        switch (octets[0], octets[1]) {
        case (10, _): return true
        case (127, _): return true
        case (192, 168): return true
        case (169, 254): return true                       // link-local
        case (172, 16...31): return true
        default: return false
        }
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
