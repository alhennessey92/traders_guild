//
//  AppDeepLink.swift
//  traders_guild
//
//  Trusted parsing for custom-scheme and Universal Link entry points.
//

import Foundation

enum AppDeepLink: Equatable, Sendable {
    case referralInvite(String)
    case guildSlug(String)
    case marker(UUID)
    case passwordReset(String)
    case emailVerification(String)

    private static let customScheme = "tradersguild"
    private static let trustedWebHosts: Set<String> = [
        "tradersguild.co",
        "open.tradersguild.co",
    ]

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let scheme = (components.scheme ?? "").lowercased()
        let host = (components.host ?? "").lowercased()
        let isCustomScheme = scheme == Self.customScheme
        let isTrustedWebLink = scheme == "https" && Self.trustedWebHosts.contains(host)
        guard isCustomScheme || isTrustedWebLink else { return nil }

        let pathParts = components.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        let fullRoute = "\(host)\(components.path.lowercased())"

        if let inviteCode = Self.referralInviteCode(
            from: components,
            pathParts: pathParts,
            fullRoute: fullRoute
        ) {
            self = .referralInvite(inviteCode)
            return
        }

        if let slug = Self.pathValue(route: "g", host: host, pathParts: pathParts) {
            self = .guildSlug(slug)
            return
        }

        if let markerIdString = Self.pathValue(route: "marker", host: host, pathParts: pathParts),
           let markerId = UUID(uuidString: markerIdString) {
            self = .marker(markerId)
            return
        }

        if fullRoute.contains("reset-password") || fullRoute.contains("password/reset") {
            guard let token = Self.queryValue(named: "token", in: components) else { return nil }
            self = .passwordReset(token)
            return
        }

        if fullRoute.contains("verify-email") || fullRoute.contains("email/verify") {
            guard let token = Self.queryValue(named: "token", in: components) else { return nil }
            self = .emailVerification(token)
            return
        }

        return nil
    }

    private static func referralInviteCode(
        from components: URLComponents,
        pathParts: [String],
        fullRoute: String
    ) -> String? {
        for key in ["code", "ref", "invite", "invite_code"] {
            if let value = queryValue(named: key, in: components) {
                return value
            }
        }

        guard fullRoute.contains("invite"),
              let last = pathParts.last,
              last.lowercased() != "invite" else {
            return nil
        }
        return last
    }

    private static func pathValue(route: String, host: String, pathParts: [String]) -> String? {
        if host == route, let first = pathParts.first, !first.isEmpty {
            return first
        }
        guard let routeIndex = pathParts.firstIndex(where: { $0.lowercased() == route }),
              routeIndex + 1 < pathParts.count else {
            return nil
        }
        return pathParts[routeIndex + 1]
    }

    private static func queryValue(named name: String, in components: URLComponents) -> String? {
        components.queryItems?
            .first(where: { $0.name.lowercased() == name })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

@MainActor
protocol AppDeepLinkDestinationHandling: AnyObject {
    func setPendingReferralInviteCode(_ code: String?)
    func setPendingGuildSlug(_ slug: String?)
    func setPendingMarkerLinkId(_ markerId: UUID)
    func setPendingPasswordResetToken(_ token: String?)
    func setPendingEmailVerificationToken(_ token: String?)
}

enum AppDeepLinkRouter {
    /// Both cold Universal Link launches and warm-app URL callbacks use this
    /// same route, so pending destinations survive authentication consistently.
    @MainActor
    @discardableResult
    static func route(
        _ url: URL,
        to destination: any AppDeepLinkDestinationHandling
    ) -> Bool {
        guard let deepLink = AppDeepLink(url: url) else { return false }

        switch deepLink {
        case .referralInvite(let inviteCode):
            destination.setPendingReferralInviteCode(inviteCode)
        case .guildSlug(let slug):
            destination.setPendingGuildSlug(slug)
        case .marker(let markerId):
            destination.setPendingMarkerLinkId(markerId)
        case .passwordReset(let token):
            destination.setPendingPasswordResetToken(token)
        case .emailVerification(let token):
            destination.setPendingEmailVerificationToken(token)
        }
        return true
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
