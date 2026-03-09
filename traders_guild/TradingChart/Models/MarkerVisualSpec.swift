//
//  MarkerVisualSpec.swift
//  traders_guild
//
//  Shared marker shell/icon/border spec used by chart rendering and SwiftUI badges.
//

import SwiftUI
import UIKit

enum MarkerVisualSpec {
    static let shellGradientColors: [Color] = [
        Color(hex: "#000127") ?? AppColors.gradientBackgroundLight,
        Color(hex: "#111111") ?? AppColors.gradientBackgroundMid,
    ]

    static func shellGradient(
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        LinearGradient(colors: shellGradientColors, startPoint: startPoint, endPoint: endPoint)
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

    static func borderWidth(isSelected: Bool) -> CGFloat {
        isSelected
            ? max(3.2, AppColors.markerSelectedBorderWidth)
            : max(2.4, AppColors.markerUnselectedBorderWidth)
    }

    static func borderColor(
        for intent: RLMarkerIntent,
        displayColor: Color,
        isSelected _: Bool
    ) -> Color {
        switch intent.markerBorderStyle {
        case .white:
            return .white
        case .intentDark:
            return darkIntentBorderColor(from: displayColor)
        }
    }

    static func iconSize(for diameter: CGFloat) -> CGFloat {
        diameter * 0.58
    }

    static func iconPrimaryColor(
        for intent: RLMarkerIntent,
        severity: MarkerAlertSeverity? = nil
    ) -> Color {
        palette(for: intent, severity: severity).first ?? Color.white.opacity(0.96)
    }

    private static func darkIntentBorderColor(from color: Color) -> Color {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return color
        }
        let darkenFactor: CGFloat = 0.34
        return Color(
            red: red * darkenFactor,
            green: green * darkenFactor,
            blue: blue * darkenFactor
        )
    }
}
