//
//  GuildTransitionContext.swift
//  traders_guild
//
//  What the brand transition says while it covers a guild swap.
//

import Foundation

enum GuildTransitionAction: Equatable {
    case launch
    case creating
    case joining
    case deleting
    case switching

    var headline: String {
        switch self {
        case .launch: return "Welcome to"
        case .creating: return "Creating"
        case .joining: return "Joining"
        case .deleting: return "Deleting"
        case .switching: return "Switching"
        }
    }
}

/// A snapshot of the guild identity shown by a transition.
///
/// Values are copied from the DTO when the operation succeeds. A later guild
/// selection or avatar update therefore cannot make an in-flight transition
/// describe a different guild.
struct GuildTransitionIdentity: Equatable {
    let id: UUID
    let name: String
    let imageURL: String?
    let crestSymbol: String?
    let crestColor: String?

    init(
        id: UUID,
        name: String,
        imageURL: String?,
        crestSymbol: String?,
        crestColor: String?
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.crestSymbol = crestSymbol
        self.crestColor = crestColor
    }

    init(guild: RLGuildDTO) {
        self.init(
            id: guild.id,
            name: guild.name,
            imageURL: guild.imageUrl,
            crestSymbol: guild.crestSymbol,
            crestColor: guild.crestColor
        )
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your guild" : trimmed
    }

    var fallbackInitial: Character {
        // Some Unicode characters expand when uppercased (for example ß →
        // "SS"). Taking the first resulting grapheme avoids trapping while still
        // giving the crest a useful initial.
        displayName.uppercased().first ?? "G"
    }

    var usesInitialFallback: Bool {
        let hasImage = !(imageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasSymbol = !(crestSymbol?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return !hasImage && !hasSymbol
    }
}

/// One appearance of the transition overlay.
///
/// `id` is behavioural, not merely SwiftUI identity: delayed chart-readiness
/// and failsafe callbacks may finish only the request that scheduled them.
struct GuildTransitionRequest: Identifiable, Equatable {
    let id: UUID
    let action: GuildTransitionAction
    let guild: GuildTransitionIdentity?

    init(
        id: UUID = UUID(),
        action: GuildTransitionAction,
        guild: GuildTransitionIdentity? = nil
    ) {
        self.id = id
        self.action = action
        self.guild = guild
    }

    static func launch(id: UUID = UUID()) -> GuildTransitionRequest {
        GuildTransitionRequest(id: id, action: .launch)
    }

    static func guild(
        _ action: GuildTransitionAction,
        guild: RLGuildDTO,
        id: UUID = UUID()
    ) -> GuildTransitionRequest {
        precondition(action != .launch, "A guild operation cannot use the launch action")
        return GuildTransitionRequest(
            id: id,
            action: action,
            guild: GuildTransitionIdentity(guild: guild)
        )
    }

    var headline: String { action.headline }

    var subject: String {
        action == .launch ? "Traders Guild" : (guild?.displayName ?? "your guild")
    }
}

/// A post-transition sheet tied to the exact transition that created it.
struct GuildArrivalRequest: Identifiable, Equatable {
    let transitionRequestID: UUID
    let guild: RLGuildDTO

    var id: UUID { transitionRequestID }
}

/// A queued current-user profile presentation tied to its guild.
struct GuildProfilePresentationRequest: Identifiable, Equatable {
    let id: UUID
    let guildID: UUID

    init(id: UUID = UUID(), guildID: UUID) {
        self.id = id
        self.guildID = guildID
    }
}
