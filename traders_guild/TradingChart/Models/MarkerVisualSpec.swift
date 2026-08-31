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

    /// Canvas symbol tag for one author's personal-marker avatar.
    ///
    /// `GraphicsContext` cannot render an image it was not handed up front, so each avatar
    /// is registered in the chart's `symbols:` closure and resolved by tag here — the same
    /// escape hatch the reaction emoji already uses.
    ///
    /// Keyed by author rather than "the viewer": a personal marker may be shared with the
    /// guild, in which case the face on it belongs to whoever placed it.
    static func avatarSymbolTag(authorId: String, isSelected: Bool) -> String {
        "marker.avatar.\(authorId)\(isSelected ? ".selected" : "")"
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

// MARK: - Personal marker identity

/// The face a personal marker wears in place of a glyph.
///
/// A personal marker is private by construction — `.personal` forces
/// `visibility == "private"`, and `ChartMarkerSystem.canRenderMarker` only shows
/// private markers to their author — so this is always the viewer's own avatar.
/// It is still read off the marker rather than app state, so the badge stays a
/// pure function of what it is handed.
///
/// Every other intent resolves to `.none`, which lets call sites pass it
/// unconditionally instead of branching on the intent themselves.
struct MarkerAvatarIdentity: Equatable {
    let url: String?
    let initials: String?

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
        guard marker.intentEnum == .personal else { return .none }
        return MarkerAvatarIdentity(
            url: marker.author.avatarUrl,
            initials: initials(from: marker.author.username)
        )
    }

    static func forMarker(_ marker: ChartMarkerUI) -> MarkerAvatarIdentity {
        forMarker(marker.marker)
    }

    /// List rows carry their author on a protocol rather than a DTO.
    static func forListItem(_ marker: some MarkerListItemData) -> MarkerAvatarIdentity {
        guard marker.intentEnum == .personal else { return .none }
        let identity = MarkerAvatarIdentity(
            url: marker.authorAvatarUrl,
            initials: marker.authorInitials
        )
        return identity.isEmpty ? .none : identity
    }

    /// For the placement picker, where no marker exists yet and the author is by
    /// definition whoever is holding the phone.
    static func forCurrentUser(username: String?, avatarUrl: String?) -> MarkerAvatarIdentity {
        let identity = MarkerAvatarIdentity(url: avatarUrl, initials: initials(from: username))
        return identity.isEmpty ? .none : identity
    }
}
