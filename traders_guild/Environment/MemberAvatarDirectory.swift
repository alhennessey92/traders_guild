//
//  MemberAvatarDirectory.swift
//  traders_guild
//
//  The freshest avatar the app has seen for a user, by user id.
//

import Foundation
import Combine

/// Chat messages carry their author as a snapshot taken when the message was fetched, so a
/// member who changes their avatar keeps the old one — or keeps showing initials — on every
/// message already on screen. The list is not refetched when a sheet closes, so until now the
/// only way to see the new avatar was to quit and relaunch the app.
///
/// This is the same idea as `RLAppState.effectiveOnlineStatus(userId:fallback:)`, which already
/// overrides each message's embedded `isOnline` with live presence: hold the current value per
/// user, and let the row prefer it over its own snapshot. Anything that hands the app a fresher
/// member payload — opening the user list, a new message arriving, changing your own avatar —
/// updates every message that user has ever posted, immediately.
///
/// A singleton rather than state on `RLAppState` so `ChatAvatar` can observe it directly: the
/// avatar is drawn in five places, several of them deep inside sheets that would otherwise each
/// need the app state threaded through them.
@MainActor
final class MemberAvatarDirectory: ObservableObject {
    static let shared = MemberAvatarDirectory()

    /// Empty string means "this user has no avatar" — a real answer, distinct from "not known",
    /// so clearing an avatar also propagates instead of falling back to a stale URL.
    @Published private(set) var avatarByUserId: [UUID: String] = [:]

    private init() {}

    /// The avatar to draw: what the app last learned, else what the message carried.
    func resolved(userId: UUID?, fallback: String?) -> String? {
        Self.resolve(userId: userId, fallback: fallback, in: avatarByUserId)
    }

    /// The rule behind `resolved`, over a snapshot of the directory, for callers
    /// that hold one rather than reading the live instance.
    nonisolated static func resolve(
        userId: UUID?,
        fallback: String?,
        in avatars: [UUID: String]
    ) -> String? {
        guard let userId, let known = avatars[userId] else { return fallback }
        return known.isEmpty ? nil : known
    }

    func note(userId: UUID, avatarURL: String?) {
        let value = avatarURL ?? ""
        guard avatarByUserId[userId] != value else { return }
        avatarByUserId[userId] = value
    }

    func note(members: [RLGuildMemberDTO]) {
        for member in members {
            note(userId: member.userId, avatarURL: member.avatarUrl)
        }
    }

    /// Cleared on logout with the rest of the per-account caches.
    func clear() {
        guard !avatarByUserId.isEmpty else { return }
        avatarByUserId.removeAll()
    }
}
