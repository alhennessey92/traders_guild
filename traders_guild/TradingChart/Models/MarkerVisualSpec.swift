//
//  MarkerVisualSpec.swift
//  traders_guild
//
//  Shared marker glass-button spec used by chart rendering and SwiftUI badges.
//

import SwiftUI

/// Unique key for each pre-rendered palette symbol in the Canvas `symbols:` closure.
struct MarkerSymbolID: Hashable {
    let intent: RLMarkerIntent
    let alertSeverity: MarkerAlertSeverity?
    let isSelected: Bool

    var tag: String {
        "\(intent.rawValue)_\(alertSeverity?.rawValue ?? "none")_\(isSelected ? "sel" : "std")"
    }
}

enum MarkerVisualSpec {
    // MARK: - Glass Material

    private static var isLightGreyTheme: Bool {
        ThemeManager.shared.currentTheme == .lightGrey
    }

    /// Thin white stroke matching iOS glass button style.
    static var glassStrokeColor: Color {
        isLightGreyTheme ? Color.black.opacity(0.12) : AppColors.surfaceWhite24
    }
    static let glassStrokeWidth: CGFloat = 0.8
    static let glassShadowRadius: CGFloat = 2
    static let glassShadowOpacity: Double = 0.35

    /// Tint overlay — neutral grey for all standard markers, severity-colored for alerts.
    static func glassTint(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil
    ) -> Color {
        if intent == .alert, let severity {
            return severity.color.opacity(0.25)
        }
        return isLightGreyTheme ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
    }

    // MARK: - Border

    static func borderWidth(isSelected: Bool) -> CGFloat {
        glassStrokeWidth
    }

    static func borderColor(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil,
        displayColor: Color = .clear,
        isSelected: Bool = false
    ) -> Color {
        if intent == .alert, let severity {
            return severity.color.opacity(0.4)
        }
        return glassStrokeColor
    }

    // MARK: - Symbol IDs for Canvas

    /// All symbol IDs needed for palette-rendered Canvas symbols.
    /// 8 non-alert intents × 2 (normal + selected) + 4 alert severities × 2 = 24 total.
    static var allSymbolIDs: [MarkerSymbolID] {
        var ids: [MarkerSymbolID] = []
        for intent in RLMarkerIntent.allCases {
            if intent == .alert {
                for sev in MarkerAlertSeverity.allCases {
                    ids.append(.init(intent: intent, alertSeverity: sev, isSelected: false))
                    ids.append(.init(intent: intent, alertSeverity: sev, isSelected: true))
                }
            } else {
                ids.append(.init(intent: intent, alertSeverity: nil, isSelected: false))
                ids.append(.init(intent: intent, alertSeverity: nil, isSelected: true))
            }
        }
        return ids
    }

    // MARK: - Size

    /// Base diameter for chart canvas markers (matches cancel button).
    static let baseCanvasDiameter: CGFloat = 36

    /// The scale a selected glyph settles at. The chart animates towards it, so
    /// anything sized for the selected state is sized from this.
    static let selectedScale: CGFloat = 1.5

    /// Canvas symbol tag for one author's avatar.
    ///
    /// `GraphicsContext` cannot render an image it was not handed up front, so each avatar
    /// is registered in the chart's `symbols:` closure and resolved by tag here — the same
    /// escape hatch the reaction emoji already uses.
    ///
    /// One symbol per author, rendered at selected resolution and drawn scaled to
    /// whatever size the disc is at — see `MarkerAvatarLayout`. Keyed by author rather
    /// than "the viewer": the face on a marker belongs to whoever placed it.
    static func avatarSymbolTag(authorId: String) -> String {
        "marker.avatar.\(authorId)"
    }

    /// The avatar sits inside the glass disc with a hairline of it left showing,
    /// so the marker still reads as a marker and not a floating profile picture.
    static func avatarDiameter(for discDiameter: CGFloat) -> CGFloat {
        discDiameter - (glassStrokeWidth * 2) - (discDiameter * 0.10)
    }

    // MARK: - Icon

    static var iconBaseColor: Color {
        isLightGreyTheme
            ? (Color(hex: "#676D78") ?? Color(red: 103.0 / 255, green: 109.0 / 255, blue: 120.0 / 255))
            : (Color(hex: "#D9D9D9") ?? Color(white: 0.85))
    }

    static func symbol(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil
    ) -> String {
        intent.markerSymbol(for: severity)
    }

    static func palette(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil
    ) -> [Color] {
        intent.markerPalette(for: severity)
    }

    /// Per-intent icon scale — some SF Symbols are visually larger and need reduction.
    static func iconScale(for intent: RLMarkerIntent) -> CGFloat {
        switch intent {
        case .setup: return 0.64
        case .news, .poll, .personal: return 0.48
        default: return 0.58
        }
    }

    /// Icon size with optional intent-aware scaling.
    static func iconSize(for diameter: CGFloat, intent: RLMarkerIntent? = nil) -> CGFloat {
        let scale = intent.map { iconScale(for: $0) } ?? 0.58
        return diameter * scale
    }

    /// Smaller scale for toolbar context.
    static let toolbarIconScale: CGFloat = 0.45

    static func iconPrimaryColor(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil
    ) -> Color {
        palette(for: intent, severity: severity).first ?? iconBaseColor
    }
}

// MARK: - Marker avatar identity

/// The face a marker wears in place of a glyph: its author's picture, or their
/// initials.
///
/// It is always the marker's *author*, never assumed to be the viewer — a
/// personal marker can be shared with the guild, so its face may be someone
/// else's. It is read off what the caller hands in rather than app state, so
/// each surface stays a pure function of its input.
///
/// - `forMarker` / `forListItem` serve the SwiftUI marker badge, for the
///   intents `MarkerAvatarPresentation.live` gives a face — `.personal`, plus
///   the prototype's three when it is on. Every other intent resolves to
///   `.none`, so call sites can pass it unconditionally. They carry the author
///   id so the badge can prefer the avatar directory over the snapshot.
/// - `forAuthor` serves the chart canvas, for whichever intents
///   `MarkerAvatarPresentation` gives a face, and prefers the avatar directory
///   over the snapshot.
/// - `forCurrentUser` serves placement, where the marker has no author yet.
struct MarkerAvatarIdentity: Equatable {
    let url: String?
    let initials: String?
    /// Lets a badge prefer the avatar directory's fresher picture over `url`,
    /// the snapshot. `nil` where there is no author to look up.
    var authorId: UUID? = nil
    /// For a Setup's intent badge; `.unknown` everywhere else.
    var setupStatus: MarkerIntentBadge.SetupStatus = .unknown

    static let none = MarkerAvatarIdentity(url: nil, initials: nil)

    var isEmpty: Bool {
        (url?.isEmpty ?? true) && (initials?.isEmpty ?? true)
    }

    private static func initials(from username: String?) -> String? {
        let trimmed = (username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(2)).uppercased()
    }

    static func forMarker(_ marker: RLChartMarkerDTO) -> MarkerAvatarIdentity {
        guard MarkerAvatarPresentation.live.contains(marker.intentEnum) else { return .none }
        return MarkerAvatarIdentity(
            url: marker.author.avatarUrl,
            initials: initials(from: marker.author.username),
            authorId: marker.author.userId,
            setupStatus: marker.intentEnum == .setup ? .from(marker) : .unknown
        )
    }

    static func forMarker(_ marker: ChartMarkerUI) -> MarkerAvatarIdentity {
        forMarker(marker.marker)
    }

    /// List rows carry their author on a protocol rather than a DTO.
    static func forListItem(_ marker: some MarkerListItemData) -> MarkerAvatarIdentity {
        guard MarkerAvatarPresentation.live.contains(marker.intentEnum) else { return .none }
        let identity = MarkerAvatarIdentity(
            url: marker.authorAvatarUrl,
            initials: marker.authorInitials,
            authorId: marker.authorId,
            setupStatus: marker.intentEnum == .setup
                ? .from(summaryTrackingState: marker.setupSummary?.trackingState)
                : .unknown
        )
        return identity.isEmpty ? .none : identity
    }

    /// Thesis rows, which carry their author on a link preview.
    ///
    /// Only the avatar prototype's intents, and only while it is on: thesis rows
    /// have never shown a personal marker's face, and keep not doing so. The
    /// preview carries no tracking state, so a Setup's badge cannot show its
    /// lifecycle here (`.unknown`).
    static func forPreview(
        _ preview: RLMarkerLinkPreviewDTO,
        avatarIntents: Set<RLMarkerIntent> = MarkerAvatarPresentation.live
    ) -> MarkerAvatarIdentity {
        guard !preview.isUnavailable,
              let intent = preview.intentEnum,
              MarkerAvatarPresentation.experimentIntents.contains(intent),
              avatarIntents.contains(intent) else { return .none }
        let identity = MarkerAvatarIdentity(
            url: preview.authorAvatarUrl,
            initials: initials(from: preview.authorUsername ?? preview.authorDisplayName),
            authorId: preview.authorId,
            setupStatus: .unknown
        )
        return identity.isEmpty ? .none : identity
    }

    /// For the placement picker, where no marker exists yet and the author is by
    /// definition whoever is holding the phone.
    static func forCurrentUser(username: String?, avatarUrl: String?) -> MarkerAvatarIdentity {
        let identity = MarkerAvatarIdentity(url: avatarUrl, initials: initials(from: username))
        return identity.isEmpty ? .none : identity
    }

    /// The face for a marker's author on the chart canvas, whatever the intent.
    ///
    /// A marker carries its author as a snapshot from when it was fetched, which
    /// can be older than what the app has since learned. The directory's answer
    /// wins — including an explicit removal, which must not fall back to the
    /// snapshot's stale picture — and the snapshot is only used for authors the
    /// directory has never heard of. Same rule as every chat avatar:
    /// `MemberAvatarDirectory.resolve(userId:fallback:in:)`.
    static func forAuthor(
        _ author: RLGuildMemberDTO,
        directory: [UUID: String]
    ) -> MarkerAvatarIdentity {
        let url = MemberAvatarDirectory.resolve(
            userId: author.userId,
            fallback: author.avatarUrl,
            in: directory
        )
        let identity = MarkerAvatarIdentity(
            url: (url?.isEmpty ?? true) ? nil : url,
            initials: initials(from: author.username)
        )
        return identity.isEmpty ? .none : identity
    }
}

// MARK: - Avatar presentation

/// Which intents wear their author's face on the chart canvas.
enum MarkerAvatarPresentation {
    /// The prototype's intents. Everything else keeps its glyph.
    static let experimentIntents: Set<RLMarkerIntent> = [.analysis, .question, .setup]

    /// `.personal` always has; the prototype adds its three.
    static func avatarIntents(experimentEnabled: Bool) -> Set<RLMarkerIntent> {
        experimentEnabled ? experimentIntents.union([.personal]) : [.personal]
    }

    /// What this launch's live chart and marker badges use.
    static let live: Set<RLMarkerIntent> = avatarIntents(experimentEnabled: MarkerAvatarExperiment.isEnabled)
}

/// Where an avatar is drawn inside its disc, at any point of the selection
/// animation.
///
/// The symbol is rendered once per author at selected resolution. The disc
/// grows continuously with the animated selection scale, so the face is drawn
/// into bounds computed from the disc's *current* diameter — never at the
/// symbol's native size, which overflowed a disc still growing towards 1.5x.
enum MarkerAvatarLayout {
    /// The disc diameter the symbol is rendered for.
    static let symbolDiscDiameter: CGFloat = MarkerVisualSpec.baseCanvasDiameter * MarkerVisualSpec.selectedScale

    /// The face's diameter inside that disc.
    static var symbolAvatarDiameter: CGFloat {
        MarkerVisualSpec.avatarDiameter(for: symbolDiscDiameter)
    }

    /// The face's bounds for a disc of `discDiameter` centred on `center`.
    static func avatarRect(center: CGPoint, discDiameter: CGFloat) -> CGRect {
        let diameter = max(0, MarkerVisualSpec.avatarDiameter(for: discDiameter))
        return CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    /// How much to scale a symbol of `symbolSize` so it fills `avatarRect`.
    static func drawScale(symbolSize: CGSize, discDiameter: CGFloat) -> CGFloat {
        let native = max(symbolSize.width, symbolSize.height)
        guard native > 0 else { return 0 }
        return max(0, MarkerVisualSpec.avatarDiameter(for: discDiameter)) / native
    }
}
