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

    /// Thin white stroke matching iOS glass button style.
    static let glassStrokeColor: Color = AppColors.surfaceWhite24
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
        return Color.white.opacity(0.06)
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

    // MARK: - Icon

    static let iconBaseColor: Color = Color(hex: "#D9D9D9") ?? Color(white: 0.85)

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
