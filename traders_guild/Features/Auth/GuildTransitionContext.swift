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

    /// The verb for a guild operation. Launch has none: it is the brand.
    var headline: String {
        switch self {
        case .launch: return "Traders Guild"
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

/// What the transition overlay draws for a request.
///
/// Pure, so it can be tested without a view. The overlay used to branch on
/// `action == .launch` in three places and draw two unrelated compositions —
/// a pulsing pair of text lines for launch, a crest in a ring for everything
/// else. Both now share one layout: a badge in a ring, a title, an optional
/// subtitle. The only thing the action decides is what sits in the badge and
/// what the lines say.
struct GuildTransitionPresentation: Equatable {
    enum Badge: Equatable {
        /// The square app icon — launch, session restore, and the end of
        /// signup or onboarding.
        case appLogo
        /// The guild's crest, for an operation on a guild.
        case guildCrest
    }

    /// Where the words go relative to the badge.
    enum Layout: Equatable {
        /// The icon alone in the centre of the screen, the wordmark at the
        /// bottom — a splash, in the way Coinbase's is: nothing competes with
        /// the mark, and the name sits where the eye lands last.
        case standaloneMark
        /// The crest in its progress ring with the verb and name directly
        /// beneath — the guild-operation treatment.
        case badgeWithCaption
    }

    let badge: Badge
    let layout: Layout
    /// The brand at launch, the verb during an operation.
    let title: String
    /// The guild's name during an operation; nothing at launch, where the
    /// title already is the name and repeating it would be noise.
    let subtitle: String?
    /// Whether a progress ring is drawn at all. A guild operation shows one;
    /// launch shows the icon on its own.
    let showsRing: Bool
    /// Whether that ring turns. Off under Reduce Motion — the ring is still
    /// drawn, so the state still reads as "working", it simply holds.
    let animatesRing: Bool
    /// Spoken as one element, so VoiceOver announces the state rather than a
    /// decorative image followed by two fragments.
    let accessibilityLabel: String

    init(request: GuildTransitionRequest, reduceMotion: Bool) {
        switch request.action {
        case .launch:
            badge = .appLogo
            layout = .standaloneMark
            title = request.headline
            subtitle = nil
            showsRing = false
            animatesRing = false
            accessibilityLabel = "\(request.headline), loading"
        case .creating, .joining, .deleting, .switching:
            badge = .guildCrest
            layout = .badgeWithCaption
            title = request.headline
            subtitle = request.subject
            showsRing = true
            animatesRing = !reduceMotion
            accessibilityLabel = "\(request.headline) \(request.subject)"
        }
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
