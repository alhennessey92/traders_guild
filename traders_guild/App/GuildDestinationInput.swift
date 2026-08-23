//
//  GuildDestinationInput.swift
//  traders_guild
//
//  Turns whatever a user pastes or types into a guild destination.
//
//  iOS has no equivalent of Play's install referrer, so a link tapped before
//  the app existed leaves no trace at all — someone who installs from the App
//  Store after seeing a handle has only this. An owner sharing their guild has
//  no control over which form their member ends up holding, so all of them
//  resolve:
//
//      apex-traders                              tradersguild.co/g/apex-traders
//      https://tradersguild.co/g/apex-traders    tradersguild://g/apex-traders
//      ABCD234567                                tradersguild.co/invite/ABCD234567
//      https://tradersguild.co/invite/ABCD2345   tradersguild://invite?code=ABCD234567
//
//  Mirrors `parseGuildDestinationInput` on Android. Kept free of URL parsing so
//  it stays a pure function over text; `AppDeepLink` handles real URLs.
//

import Foundation

enum GuildDestination: Equatable {
    /// A guild's vanity handle. Joins directly when open, requests when private. Credits nobody.
    case slug(String)
    /// A referral invite code. Grants membership directly and credits the inviter.
    case invite(String)
}

enum GuildDestinationInput {

    /// Hosts whose links we recognise, matching `AppDeepLink.trustedWebHosts`.
    private static let knownHosts: Set<String> = [
        "tradersguild.co",
        "www.tradersguild.co",
        "open.tradersguild.co",
    ]

    /// The backend's invite-code alphabet — Crockford-ish, with the ambiguous
    /// characters (I, O, 0, 1) removed so codes survive being read aloud.
    private static let inviteCodeAlphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let inviteCodeLength = 10

    private static let queryCodeKeys = ["code", "ref", "invite", "invite_code"]

    /// Parse `raw` into a destination, or nil if it isn't one.
    ///
    /// An invite code wins wherever both could apply — it grants membership
    /// directly and credits whoever shared it.
    static func parse(_ raw: String?) -> GuildDestination? {
        var value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // A pasted URL may carry the code in the query rather than the path.
        var query = ""
        if let separator = value.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            query = String(value[value.index(after: separator)...])
            value = String(value[..<separator])
        }
        if let code = queryParam(query, keys: queryCodeKeys) {
            return inviteDestination(code)
        }

        value = stripHost(stripScheme(value))
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !value.isEmpty else { return nil }

        let segments = value.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        if segments.count >= 2 {
            switch segments[0].lowercased() {
            case "g": return slugDestination(segments[1])
            case "invite": return inviteDestination(segments[1])
            // A path we don't recognise — refuse rather than guessing at a
            // segment. A marker link is a real link, but not a guild.
            default: return nil
            }
        }
        guard segments.count == 1, let token = segments.first else { return nil }
        return looksLikeInviteCode(token) ? inviteDestination(token) : slugDestination(token)
    }

    /// Codes are a fixed length from a fixed uppercase alphabet; slugs are
    /// lowercase `[a-z0-9-]`. That makes a bare token unambiguous in practice,
    /// so it can be routed without asking which kind the user has.
    private static func looksLikeInviteCode(_ token: String) -> Bool {
        token.count == inviteCodeLength
            && token == token.uppercased()
            && token.allSatisfy { inviteCodeAlphabet.contains($0) }
    }

    private static func stripScheme(_ value: String) -> String {
        guard let range = value.range(of: "://") else { return value }
        return String(value[range.upperBound...])
    }

    private static func stripHost(_ value: String) -> String {
        let host = value.split(separator: "/").first.map(String.init)?.lowercased() ?? ""
        // `tradersguild://g/apex-traders` puts the route where a host would be,
        // so only strip segments that are genuinely hosts.
        guard knownHosts.contains(host) else { return value }
        guard let slash = value.firstIndex(of: "/") else { return "" }
        return String(value[value.index(after: slash)...])
    }

    private static func queryParam(_ query: String, keys: [String]) -> String? {
        guard !query.isEmpty else { return nil }
        var params: [String: String] = [:]
        for pair in query.split(separator: "&") {
            guard let equals = pair.firstIndex(of: "="), equals > pair.startIndex else { continue }
            let key = String(pair[..<equals]).lowercased()
            let value = String(pair[pair.index(after: equals)...])
            params[key] = value
        }
        for key in keys {
            if let value = params[key]?.trimmingCharacters(in: .whitespaces), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func inviteDestination(_ code: String) -> GuildDestination? {
        let cleaned = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleaned.isEmpty else { return nil }
        return .invite(cleaned.uppercased())
    }

    private static func slugDestination(_ slug: String) -> GuildDestination? {
        let cleaned = slug
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" })
        else { return nil }
        return .slug(cleaned)
    }
}
