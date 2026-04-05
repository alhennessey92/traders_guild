//
//  Color+Theme.swift
//  traders_guild
//
//  App-wide color source of truth.
//  NOTE: Tokens in this file must remain value-stable unless explicitly retuning design.
//

import SwiftUI
import UIKit

enum AppColors {
    // MARK: - Theme Helpers

    private static var theme: AppTheme {
        ThemeManager.shared.currentTheme
    }

    private static var isMidGrey: Bool { theme == .midGrey }
    private static var isLightGrey: Bool { theme == .lightGrey }

    /// Base color used for adaptive overlays: white on dark themes, black on light.
    private static var overlayBase: Color { isLightGrey ? .black : .white }

    // MARK: - Foundation Assets (theme-aware backgrounds)

    /// TGGradientBackground. Dark: #010105, MidGrey: #181C28, LightGrey: #C0C2C9.
    static var tgGradientBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 192.0 / 255, green: 194.0 / 255, blue: 201.0 / 255)
        case .midGrey:   return Color(red: 0x18 / 255.0, green: 0x1C / 255.0, blue: 0x28 / 255.0)
        case .dark:      return Color("TGGradientBackground")
        }
    }
    /// TGGradientBackgroundMid. Dark: #111111, MidGrey: dimmed, LightGrey: #B5B7C0.
    static var tgGradientBackgroundMid: Color {
        switch theme {
        case .lightGrey: return Color(red: 181.0 / 255, green: 183.0 / 255, blue: 192.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 36.0 / 255)
        case .dark:      return Color("TGGradientBackgroundMid")
        }
    }
    /// TGGradientBackgroundLight. Dark: #000127, MidGrey: lifted, LightGrey: #C8CAD0.
    static var tgGradientBackgroundLight: Color {
        switch theme {
        case .lightGrey: return Color(red: 200.0 / 255, green: 202.0 / 255, blue: 208.0 / 255)
        case .midGrey:   return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 42.0 / 255)
        case .dark:      return Color("TGGradientBackgroundLight")
        }
    }

    /// TGSheetBackground. Dark: #1B1A1F, MidGrey: #181C28, LightGrey: #C8CAD0.
    static var tgSheetBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 200.0 / 255, green: 202.0 / 255, blue: 208.0 / 255)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255)
        case .dark:      return Color("TGSheetBackground")
        }
    }
    /// TGSheetDarkBackground. Dark: #1F1E1A, MidGrey: slightly darker, LightGrey: #BDBFC7.
    static var tgSheetDarkBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 189.0 / 255, green: 191.0 / 255, blue: 199.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 38.0 / 255)
        case .dark:      return Color("TGSheetDarkBackground")
        }
    }
    /// TGDrawerBackground. Dark: #00000A, MidGrey: #171B27, LightGrey: #AAADB6.
    static var tgDrawerBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 173.0 / 255, blue: 182.0 / 255)
        case .midGrey:   return Color(red: 23.0 / 255, green: 27.0 / 255, blue: 39.0 / 255)
        case .dark:      return Color("TGDrawerBackground")
        }
    }
    /// TGToolbarBackground. Dark: #00000E/0.35, MidGrey: #181C28/0.55, LightGrey: #C0C2C9/0.88.
    static var tgToolbarBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 192.0 / 255, green: 194.0 / 255, blue: 201.0 / 255).opacity(0.88)
        case .midGrey:   return Color(red: 0x18 / 255.0, green: 0x1C / 255.0, blue: 0x28 / 255.0).opacity(0.55)
        case .dark:      return Color("TGToolbarBackground")
        }
    }

    /// TGWhiteText. Dark/MidGrey: #ECECEC, LightGrey: #292B32.
    static var tgWhiteText: Color {
        isLightGrey ? Color(red: 41.0 / 255, green: 43.0 / 255, blue: 50.0 / 255)
                    : Color("TGWhiteText")
    }
    /// TGWhite. Dark/MidGrey: #FFFFFF, LightGrey: #292B32.
    static var tgWhite: Color {
        isLightGrey ? Color(red: 41.0 / 255, green: 43.0 / 255, blue: 50.0 / 255)
                    : Color("TGWhite")
    }
    /// TGMidGrey. Dark/MidGrey: #7A7878, LightGrey: #6D717E.
    static var tgMidGrey: Color {
        isLightGrey ? Color(red: 109.0 / 255, green: 113.0 / 255, blue: 126.0 / 255)
                    : Color("TGMidGrey")
    }
    /// TGGrey. Dark/MidGrey: #A9A9A9, LightGrey: #494C55.
    static var tgGrey: Color {
        isLightGrey ? Color(red: 73.0 / 255, green: 76.0 / 255, blue: 85.0 / 255)
                    : Color("TGGrey")
    }

    /// TGAccent asset. Hex #0F9EB4 alpha 1.0.
    static let tgAccent = Color("TGAccent")
    /// TGAccentDark asset. Hex #026675 alpha 1.0.
    static let tgAccentDark = Color("TGAccentDark")
    /// TGFriend asset. Hex #0574D5 alpha 1.0.
    static let tgFriend = Color("TGFriend")

    /// TGBull asset. Hex #4A9476 alpha 1.0.
    static let tgBull = Color("TGBull")
    /// TGBear asset. Hex #A62C2B alpha 1.0.
    static let tgBear = Color("TGBear")

    /// TGButtonSearchBackground. Dark: #191921, MidGrey: same ratio, LightGrey: #D0D2D7.
    static var tgButtonSearchBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 208.0 / 255, green: 210.0 / 255, blue: 215.0 / 255)
        case .midGrey:   return Color(red: 20.0 / 255, green: 24.0 / 255, blue: 34.0 / 255)
        case .dark:      return Color("TGButtonSearchBackground")
        }
    }
    /// TGUnhighlightedWhite. Dark/MidGrey: #C3C3C3, LightGrey: #5A5D68.
    static var tgUnhighlightedWhite: Color {
        isLightGrey ? Color(red: 90.0 / 255, green: 93.0 / 255, blue: 104.0 / 255)
                    : Color("TGUnhighlightedWhite")
    }
    /// TGFadedBackground. Dark: #3F404D, MidGrey: lifted, LightGrey: #CBCCD2.
    static var tgFadedBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 203.0 / 255, green: 204.0 / 255, blue: 210.0 / 255)
        case .midGrey:   return Color(red: 28.0 / 255, green: 32.0 / 255, blue: 46.0 / 255)
        case .dark:      return Color("TGFadedBackground")
        }
    }
    /// TGChartLogo asset. Hex #7A7878 alpha 1.0.
    static let tgChartLogo = Color("TGChartLogo")
    /// TGGreen asset. Hex #089B1C alpha 1.0.
    static let tgGreen = Color("TGGreen")

    // MARK: - System Base Colors

    /// System `Color.white` wrapper.
    static let systemWhite = Color.white
    /// System `Color.black` wrapper.
    static let systemBlack = Color.black
    /// System `Color.gray` wrapper.
    static let systemGray = Color.gray
    /// System `Color.red` wrapper.
    static let systemRed = Color.red
    /// System `Color.green` wrapper.
    static let systemGreen = Color.green
    /// System `Color.blue` wrapper.
    static let systemBlue = Color.blue
    /// System `Color.orange` wrapper.
    static let systemOrange = Color.orange
    /// System `Color.yellow` wrapper.
    static let systemYellow = Color.yellow
    /// System `Color.purple` wrapper.
    static let systemPurple = Color.purple
    /// System `Color.cyan` wrapper.
    static let systemCyan = Color.cyan
    /// System `Color.teal` wrapper.
    static let systemTeal = Color.teal
    /// System `Color.pink` wrapper.
    static let systemPink = Color.pink
    /// System `Color.mint` wrapper.
    static let systemMint = Color.mint
    /// System `Color.indigo` wrapper.
    static let systemIndigo = Color.indigo

    // MARK: - Adaptive Surfaces (theme-aware overlays)

    /// Adaptive overlay: white on dark themes, black on light. Use for borders, dividers, subtle fills.
    static var adaptiveOverlay03: Color { overlayBase.opacity(0.03) }
    static var adaptiveOverlay05: Color { overlayBase.opacity(0.05) }
    static var adaptiveOverlay08: Color { overlayBase.opacity(0.08) }
    static var adaptiveOverlay10: Color { overlayBase.opacity(0.1) }
    static var adaptiveOverlay15: Color { overlayBase.opacity(0.15) }
    static var adaptiveOverlay18: Color { overlayBase.opacity(0.18) }
    static var adaptiveOverlay20: Color { overlayBase.opacity(0.2) }
    static var adaptiveOverlay24: Color { overlayBase.opacity(0.24) }
    static var adaptiveOverlay30: Color { overlayBase.opacity(0.3) }
    static var adaptiveOverlay40: Color { overlayBase.opacity(0.4) }
    static var adaptiveOverlay50: Color { overlayBase.opacity(0.5) }
    static var adaptiveOverlay60: Color { overlayBase.opacity(0.6) }
    static var adaptiveOverlay70: Color { overlayBase.opacity(0.7) }
    static var adaptiveOverlay80: Color { overlayBase.opacity(0.8) }
    static var adaptiveOverlay90: Color { overlayBase.opacity(0.9) }
    static var adaptiveOverlay94: Color { overlayBase.opacity(0.94) }

    // MARK: - Surfaces (Neutral Overlays)

    static let surfaceWhite00 = systemWhite.opacity(0.0)
    static let surfaceWhite0015 = systemWhite.opacity(0.015)
    static let surfaceWhite03 = systemWhite.opacity(0.03)
    static let surfaceWhite04 = systemWhite.opacity(0.04)
    static let surfaceWhite05 = systemWhite.opacity(0.05)
    static let surfaceWhite06 = systemWhite.opacity(0.06)
    static let surfaceWhite07 = systemWhite.opacity(0.07)
    static let surfaceWhite08 = systemWhite.opacity(0.08)
    static let surfaceWhite09 = systemWhite.opacity(0.09)
    static let surfaceWhite10 = systemWhite.opacity(0.1)
    static let surfaceWhite11 = systemWhite.opacity(0.11)
    static let surfaceWhite12 = systemWhite.opacity(0.12)
    static let surfaceWhite14 = systemWhite.opacity(0.14)
    static let surfaceWhite15 = systemWhite.opacity(0.15)
    static let surfaceWhite18 = systemWhite.opacity(0.18)
    static let surfaceWhite20 = systemWhite.opacity(0.2)
    static let surfaceWhite22 = systemWhite.opacity(0.22)
    static let surfaceWhite24 = systemWhite.opacity(0.24)
    static let surfaceWhite25 = systemWhite.opacity(0.25)
    static let surfaceWhite30 = systemWhite.opacity(0.3)
    static let surfaceWhite32 = systemWhite.opacity(0.32)
    static let surfaceWhite40 = systemWhite.opacity(0.4)
    static let surfaceWhite50 = systemWhite.opacity(0.5)
    static let surfaceWhite58 = systemWhite.opacity(0.58)
    static let surfaceWhite60 = systemWhite.opacity(0.6)
    static let surfaceWhite62 = systemWhite.opacity(0.62)
    static let surfaceWhite65 = systemWhite.opacity(0.65)
    static let surfaceWhite66 = systemWhite.opacity(0.66)
    static let surfaceWhite68 = systemWhite.opacity(0.68)
    static let surfaceWhite70 = systemWhite.opacity(0.7)
    static let surfaceWhite74 = systemWhite.opacity(0.74)
    static let surfaceWhite75 = systemWhite.opacity(0.75)
    static let surfaceWhite76 = systemWhite.opacity(0.76)
    static let surfaceWhite78 = systemWhite.opacity(0.78)
    static let surfaceWhite80 = systemWhite.opacity(0.8)
    static let surfaceWhite82 = systemWhite.opacity(0.82)
    static let surfaceWhite84 = systemWhite.opacity(0.84)
    static let surfaceWhite85 = systemWhite.opacity(0.85)
    static let surfaceWhite86 = systemWhite.opacity(0.86)
    static let surfaceWhite88 = systemWhite.opacity(0.88)
    static let surfaceWhite90 = systemWhite.opacity(0.9)
    static let surfaceWhite92 = systemWhite.opacity(0.92)
    static let surfaceWhite93 = systemWhite.opacity(0.93)
    static let surfaceWhite94 = systemWhite.opacity(0.94)
    static let surfaceWhite95 = systemWhite.opacity(0.95)
    static let surfaceWhite96 = systemWhite.opacity(0.96)

    static let surfaceBlack10 = systemBlack.opacity(0.1)
    static let surfaceBlack20 = systemBlack.opacity(0.2)
    static let surfaceBlack28 = systemBlack.opacity(0.28)
    static let surfaceBlack30 = systemBlack.opacity(0.3)
    static let surfaceBlack32 = systemBlack.opacity(0.32)
    static let surfaceBlack40 = systemBlack.opacity(0.4)
    static let surfaceBlack45 = systemBlack.opacity(0.45)
    static let surfaceBlack50 = systemBlack.opacity(0.5)
    static let surfaceBlack62 = systemBlack.opacity(0.62)
    static let surfaceBlack66 = systemBlack.opacity(0.66)
    static let surfaceBlack70 = systemBlack.opacity(0.7)
    static let surfaceBlack75 = systemBlack.opacity(0.75)
    static let surfaceBlack80 = systemBlack.opacity(0.8)
    static let surfaceBlack82 = systemBlack.opacity(0.82)
    static let surfaceBlack85 = systemBlack.opacity(0.85)
    static let surfaceBlack96 = systemBlack.opacity(0.96)

    static let surfaceGray10 = systemGray.opacity(0.1)
    static let surfaceGray15 = systemGray.opacity(0.15)
    static let surfaceGray20 = systemGray.opacity(0.2)
    static let surfaceGray30 = systemGray.opacity(0.3)
    static let surfaceGray40 = systemGray.opacity(0.4)
    static let surfaceGray50 = systemGray.opacity(0.5)
    static let surfaceGray70 = systemGray.opacity(0.7)
    static let surfaceGray75 = systemGray.opacity(0.75)
    static let surfaceGray80 = systemGray.opacity(0.8)
    static let surfaceGray90 = systemGray.opacity(0.9)

    // MARK: - Semantic / Status

    static let statusPositive = systemGreen
    static let statusNegative = systemRed
    static let statusInfo = systemBlue
    static let statusWarning = systemOrange

    static let statusNegative08 = systemRed.opacity(0.08)
    static let statusNegative10 = systemRed.opacity(0.1)
    static let statusNegative12 = systemRed.opacity(0.12)
    static let statusNegative15 = systemRed.opacity(0.15)
    static let statusNegative20 = systemRed.opacity(0.2)
    static let statusNegative30 = systemRed.opacity(0.3)
    static let statusNegative35 = systemRed.opacity(0.35)
    static let statusNegative40 = systemRed.opacity(0.4)
    static let statusNegative50 = systemRed.opacity(0.5)
    static let statusNegative55 = systemRed.opacity(0.55)
    static let statusNegative60 = systemRed.opacity(0.6)
    static let statusNegative70 = systemRed.opacity(0.7)
    static let statusNegative75 = systemRed.opacity(0.75)
    static let statusNegative80 = systemRed.opacity(0.8)
    static let statusNegative82 = systemRed.opacity(0.82)
    static let statusNegative85 = systemRed.opacity(0.85)
    static let statusNegative86 = systemRed.opacity(0.86)
    static let statusNegative92 = systemRed.opacity(0.92)
    static let statusNegative95 = systemRed.opacity(0.95)

    static let statusPositive06 = systemGreen.opacity(0.06)
    static let statusPositive08 = systemGreen.opacity(0.08)
    static let statusPositive10 = systemGreen.opacity(0.1)
    static let statusPositive14 = systemGreen.opacity(0.14)
    static let statusPositive15 = systemGreen.opacity(0.15)
    static let statusPositive20 = systemGreen.opacity(0.2)
    static let statusPositive25 = systemGreen.opacity(0.25)
    static let statusPositive30 = systemGreen.opacity(0.3)
    static let statusPositive35 = systemGreen.opacity(0.35)
    static let statusPositive40 = systemGreen.opacity(0.4)
    static let statusPositive45 = systemGreen.opacity(0.45)
    static let statusPositive50 = systemGreen.opacity(0.5)
    static let statusPositive60 = systemGreen.opacity(0.6)
    static let statusPositive66 = systemGreen.opacity(0.66)
    static let statusPositive70 = systemGreen.opacity(0.7)
    static let statusPositive72 = systemGreen.opacity(0.72)
    static let statusPositive80 = systemGreen.opacity(0.8)
    static let statusPositive85 = systemGreen.opacity(0.85)
    static let statusPositive90 = systemGreen.opacity(0.9)
    static let statusPositive95 = systemGreen.opacity(0.95)

    static let statusInfo08 = systemBlue.opacity(0.08)
    static let statusInfo10 = systemBlue.opacity(0.1)
    static let statusInfo15 = systemBlue.opacity(0.15)
    static let statusInfo16 = systemBlue.opacity(0.16)
    static let statusInfo20 = systemBlue.opacity(0.2)
    static let statusInfo22 = systemBlue.opacity(0.22)
    static let statusInfo24 = systemBlue.opacity(0.24)
    static let statusInfo25 = systemBlue.opacity(0.25)
    static let statusInfo40 = systemBlue.opacity(0.4)
    static let statusInfo45 = systemBlue.opacity(0.45)
    static let statusInfo50 = systemBlue.opacity(0.5)
    static let statusInfo52 = systemBlue.opacity(0.52)
    static let statusInfo60 = systemBlue.opacity(0.6)
    static let statusInfo70 = systemBlue.opacity(0.7)
    static let statusInfo80 = systemBlue.opacity(0.8)
    static let statusInfo85 = systemBlue.opacity(0.85)
    static let statusInfo90 = systemBlue.opacity(0.9)
    static let statusInfo95 = systemBlue.opacity(0.95)

    static let statusWarning10 = systemOrange.opacity(0.1)
    static let statusWarning14 = systemOrange.opacity(0.14)
    static let statusWarning15 = systemOrange.opacity(0.15)
    static let statusWarning16 = systemOrange.opacity(0.16)
    static let statusWarning18 = systemOrange.opacity(0.18)
    static let statusWarning20 = systemOrange.opacity(0.2)
    static let statusWarning28 = systemOrange.opacity(0.28)
    static let statusWarning30 = systemOrange.opacity(0.3)
    static let statusWarning40 = systemOrange.opacity(0.4)
    static let statusWarning45 = systemOrange.opacity(0.45)
    static let statusWarning50 = systemOrange.opacity(0.5)
    static let statusWarning60 = systemOrange.opacity(0.6)
    static let statusWarning62 = systemOrange.opacity(0.62)
    static let statusWarning70 = systemOrange.opacity(0.7)
    static let statusWarning72 = systemOrange.opacity(0.72)
    static let statusWarning80 = systemOrange.opacity(0.8)
    static let statusWarning90 = systemOrange.opacity(0.9)
    static let statusWarning92 = systemOrange.opacity(0.92)
    static let statusWarning95 = systemOrange.opacity(0.95)

    static let statusHighlight20 = systemYellow.opacity(0.2)
    static let statusHighlight40 = systemYellow.opacity(0.4)
    static let statusHighlight50 = systemYellow.opacity(0.5)
    static let statusHighlight55 = systemYellow.opacity(0.55)
    static let statusHighlight68 = systemYellow.opacity(0.68)
    static let statusHighlight80 = systemYellow.opacity(0.8)
    static let statusHighlight90 = systemYellow.opacity(0.9)
    static let statusHighlight95 = systemYellow.opacity(0.95)

    static let statusSecondary10 = systemPurple.opacity(0.1)
    static let statusSecondary30 = systemPurple.opacity(0.3)
    static let statusSecondary50 = systemPurple.opacity(0.5)
    static let statusSecondary70 = systemPurple.opacity(0.7)

    static let statusAccent40 = systemCyan.opacity(0.4)
    static let statusAccent66 = systemCyan.opacity(0.66)
    static let statusAccent90 = systemCyan.opacity(0.9)

    static let statusTeal22 = systemTeal.opacity(0.22)
    static let statusTeal30 = systemTeal.opacity(0.3)
    static let statusTeal58 = systemTeal.opacity(0.58)
    static let statusTeal95 = systemTeal.opacity(0.95)

    static let statusPink45 = systemPink.opacity(0.45)
    static let statusPink50 = systemPink.opacity(0.5)
    static let statusPink72 = systemPink.opacity(0.72)

    static let statusIndigo58 = systemIndigo.opacity(0.58)

    // MARK: - Chart / Indicator Literal Tokens

    static let chartTabGradientStart = Color(red: 0.20, green: 0.40, blue: 0.80)
    static let chartTabGradientEnd = Color(red: 0.15, green: 0.25, blue: 0.50)

    // Orange gradient for active/selected tabs in specific contexts
    static let chartOrangeGradientStart = Color(red: 0.82, green: 0.42, blue: 0.12)
    static let chartOrangeGradientEnd = Color(red: 0.62, green: 0.28, blue: 0.08)

    // Green gradient for marker "Add" tab
    static let chartGreenGradientStart = Color(red: 0.14, green: 0.52, blue: 0.28)
    static let chartGreenGradientEnd = Color(red: 0.09, green: 0.36, blue: 0.18)
    static let chartSubTabGradientStart = Color(red: 0.12, green: 0.18, blue: 0.38)
    static let chartSubTabGradientEnd = Color(red: 0.08, green: 0.12, blue: 0.28)
    static let chartDeepSubTabGradientStart = Color(red: 0.08, green: 0.12, blue: 0.25)
    static let chartDeepSubTabGradientEnd = Color(red: 0.05, green: 0.08, blue: 0.18)

    static var chartPanelBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 202.0 / 255, green: 204.0 / 255, blue: 210.0 / 255)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundMuted: Color {
        switch theme {
        case .lightGrey: return Color(red: 199.0 / 255, green: 201.0 / 255, blue: 208.0 / 255)
        case .midGrey:   return Color(red: 23.0 / 255, green: 27.0 / 255, blue: 38.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 26.0 / 255)
        }
    }
    static var chartPanelBackgroundInset: Color {
        switch theme {
        case .lightGrey: return Color(red: 192.0 / 255, green: 194.0 / 255, blue: 202.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 36.0 / 255)
        case .dark:      return Color(red: 18.0 / 255, green: 18.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundAlt: Color {
        switch theme {
        case .lightGrey: return Color(red: 206.0 / 255, green: 208.0 / 255, blue: 214.0 / 255)
        case .midGrey:   return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 42.0 / 255)
        case .dark:      return Color(red: 25.0 / 255, green: 25.0 / 255, blue: 33.0 / 255)
        }
    }
    static var chartPanelBackgroundDeep: Color {
        switch theme {
        case .lightGrey: return Color(red: 178.0 / 255, green: 181.0 / 255, blue: 190.0 / 255)
        case .midGrey:   return Color(red: 18.0 / 255, green: 22.0 / 255, blue: 32.0 / 255)
        case .dark:      return Color(red: 10.0 / 255, green: 10.0 / 255, blue: 12.0 / 255)
        }
    }
    static var chartIndicatorHandleFill: Color {
        switch theme {
        case .lightGrey: return Color(white: 0.92)
        case .midGrey:   return Color(white: 0.10)
        case .dark:      return Color(white: 0.08)
        }
    }

    // MARK: - Component-Level Theme Tokens

    /// Info box background (crosshair OHLCV popup). Blends with chart background.
    static var infoBoxBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 173.0 / 255, blue: 182.0 / 255).opacity(0.96)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 38.0 / 255).opacity(0.94)
        case .dark:      return Color.black.opacity(0.85)
        }
    }

    /// Panel header background (indicator & timeframe panels). Subtle darker strip.
    static var panelHeaderBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 156.0 / 255, green: 159.0 / 255, blue: 171.0 / 255)
        case .midGrey:   return Color(red: 18.0 / 255, green: 22.0 / 255, blue: 32.0 / 255)
        case .dark:      return Color(red: 16.0 / 255, green: 16.0 / 255, blue: 22.0 / 255)
        }
    }

    /// X-axis bottom area background. Dark: pure black, MidGrey: very dark blue-grey, LightGrey: #9195A1.
    static var xAxisBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 168.0 / 255, green: 171.0 / 255, blue: 182.0 / 255)
        case .midGrey:   return Color(red: 14.0 / 255, green: 18.0 / 255, blue: 26.0 / 255)
        case .dark:      return Color.black
        }
    }

    static let signupInterestBlue = Color(red: 0.4, green: 0.7, blue: 0.9)
    static let signupInterestGreen = Color(red: 0.5, green: 0.8, blue: 0.5)
    static let signupInterestPurple = Color(red: 0.7, green: 0.6, blue: 0.9)

    // MARK: - Marker

    static let markerHeartTint = Color(red: 0.88, green: 0.24, blue: 0.28)
    static let markerHeartMuted = markerHeartTint.opacity(0.55)
    static let markerHeartBadge = markerHeartTint.opacity(0.92)
    static let markerHeartBackground = markerHeartTint.opacity(0.22)
    static let markerHeartBorder = markerHeartTint.opacity(0.42)

    static let markerShellBorderLight = Color(white: 0.72)
    static let markerShellBorderDark = Color(white: 0.22)
    static let markerShellFillLight = Color(white: 0.92)
    static let markerShellFillDark = Color(white: 0.18)
    static let markerIconOnDark = Color(white: 0.95)
    static let markerIconOnLight = Color(white: 0.12)
    static let markerSelectedBorder = Color(white: 0.5)
    static let markerSelectedBorderWidth: CGFloat = 0.8
    static let markerUnselectedBorderWidth: CGFloat = 0.8
    static var markerNeutralFillTop: Color {
        isLightGrey ? Color(red: 196.0 / 255, green: 198.0 / 255, blue: 205.0 / 255)
                    : Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 37.0 / 255.0)
    }
    static var markerNeutralFillBottom: Color {
        isLightGrey ? Color(red: 156.0 / 255, green: 159.0 / 255, blue: 171.0 / 255)
                    : Color(red: 12.0 / 255.0, green: 12.0 / 255.0, blue: 14.0 / 255.0)
    }
    static let markerIconLight = Color(white: 0.72)
    static let markerBorderGrey = surfaceWhite24

    // MARK: - Semantic Foreground Tokens
    // Dark/mid-grey values return the EXACT hardcoded value previously used in UI files.

    /// Primary foreground for text/icons on theme backgrounds. Dark/MidGrey: pure white, LightGrey: #292B32.
    static var primaryForeground: Color {
        isLightGrey ? Color(red: 41.0 / 255, green: 43.0 / 255, blue: 50.0 / 255)
                    : Color.white
    }

    /// Secondary foreground for muted text. Dark/MidGrey: system gray, LightGrey: #6D717E.
    static var secondaryForeground: Color {
        isLightGrey ? Color(red: 109.0 / 255, green: 113.0 / 255, blue: 126.0 / 255)
                    : Color.gray
    }

    /// Foreground for text on saturated colored backgrounds (accent, tabs, bull/bear). Always white.
    static let onAccentForeground = Color.white

    /// Crosshair OHLC value text. Dark/MidGrey: pure white, LightGrey: #292B32.
    static var crosshairText: Color {
        isLightGrey ? Color(red: 41.0 / 255, green: 43.0 / 255, blue: 50.0 / 255)
                    : Color.white
    }

    // MARK: - Semantic Chart / Canvas Tokens

    /// Fade-to-background color for chart edge masks. Must match primary BG for seamless fade.
    static var chartMaskFade: Color {
        switch theme {
        case .lightGrey: return chartPanelBackground
        case .midGrey:   return Color.white
        case .dark:      return Color.white
        }
    }

    /// Y-axis / indicator scale labels on the chart canvas.
    static var chartAxisLabelPrimary: Color {
        isLightGrey ? tgGrey : surfaceWhite84
    }

    static var chartAxisLabelSecondary: Color {
        isLightGrey ? secondaryForeground : surfaceWhite76
    }

    /// Drawing / emoji toolbar on chart (over light panel chrome).
    static var chartOverlayToolbarPrimary: Color {
        isLightGrey ? primaryForeground : surfaceWhite94
    }

    static var chartOverlayToolbarSecondary: Color {
        isLightGrey ? secondaryForeground : surfaceWhite90
    }

    static var chartOverlayToolbarTertiary: Color {
        isLightGrey ? secondaryForeground.opacity(0.92) : surfaceWhite70
    }

    /// Marker placement bar pills on main chart (lightGrey: soft grey chrome vs plot).
    static var placementBarSelectedFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 222.0 / 255, green: 224.0 / 255, blue: 230.0 / 255)
        case .midGrey, .dark: return tgGradientBackground
        }
    }

    static var placementBarUnselectedFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 212.0 / 255, green: 214.0 / 255, blue: 221.0 / 255)
        case .midGrey, .dark: return tgGradientBackgroundMid.opacity(0.9)
        }
    }

    static var placementBarSelectedForeground: Color {
        isLightGrey ? primaryForeground : .white
    }

    static var placementBarUnselectedForeground: Color {
        isLightGrey ? tgMidGrey : tgWhiteText.opacity(0.8)
    }

    /// Canvas marker blob fill. Dark/MidGrey: near-black; LightGrey: mid grey so white glyphs read.
    static var canvasMarkerFill: Color {
        isLightGrey
            ? Color(red: 88.0 / 255, green: 92.0 / 255, blue: 102.0 / 255).opacity(0.94)
            : Color(white: 0.11).opacity(0.94)
    }

    /// Canvas marker drop shadow. Dark/MidGrey: black 25% (current), LightGrey: black 10%.
    static var canvasMarkerShadow: Color {
        isLightGrey ? Color.black.opacity(0.10)
                    : Color.black.opacity(0.25)
    }

    /// Viewport dimming color for timeframe panels. Black on all themes.
    static var viewportDim: Color { Color.black }

    /// Pattern overlay stroke. Dark/MidGrey: white (current), LightGrey: black.
    static var patternStroke: Color {
        isLightGrey ? Color.black : Color.white
    }

    // MARK: - List rows & symbol sheet (light contrast; dark/mid preserve prior literals)

    /// Chat / DM list row pill. Dark/Mid: white 3% / 10% pressed.
    static var messagingListRowFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.07)
        case .midGrey, .dark: return Color.white.opacity(0.03)
        }
    }

    static var messagingListRowFillPressed: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return Color.white.opacity(0.10)
        }
    }

    /// Guild user list row. Dark/Mid: white 3% / 6% pressed.
    static var userListRowFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.07)
        case .midGrey, .dark: return Color.white.opacity(0.03)
        }
    }

    static var userListRowFillPressed: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return Color.white.opacity(0.06)
        }
    }

    /// Search bar capsule gradient. Dark/Mid: surfaceWhite 8%→4%; Light: adaptive overlay (matches disclosure).
    static var searchBarGradientLeading: Color {
        switch theme {
        case .lightGrey: return adaptiveOverlay08
        case .midGrey, .dark: return surfaceWhite08
        }
    }

    static var searchBarGradientTrailing: Color {
        switch theme {
        case .lightGrey: return adaptiveOverlay05
        case .midGrey, .dark: return surfaceWhite04
        }
    }

    /// Chat composer action panel (dark/mid: surfaceWhite12→08; light: search bar adaptive).
    static var composerActionPanelGradientLeading: Color {
        switch theme {
        case .lightGrey: return searchBarGradientLeading
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    static var composerActionPanelGradientTrailing: Color {
        switch theme {
        case .lightGrey: return searchBarGradientTrailing
        case .midGrey, .dark: return surfaceWhite08
        }
    }

    /// Symbol sheet timeframe section container. Dark/Mid: surfaceWhite05.
    static var symbolSheetGroupedPanelFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.06)
        case .midGrey, .dark: return surfaceWhite05
        }
    }

    /// Unselected timeframe chip gradient. Dark/Mid: surfaceWhite10→05.
    static var timeframeChipUnselectedLeading: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    static var timeframeChipUnselectedTrailing: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.06)
        case .midGrey, .dark: return surfaceWhite05
        }
    }

    /// Marker list capsule. Dark/Mid: surfaceWhite04 / surfaceWhite08 stroke.
    static var markerListCapsuleFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.07)
        case .midGrey, .dark: return surfaceWhite04
        }
    }

    static var markerListCapsuleStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return surfaceWhite08
        }
    }

    /// Text on marker/list cards (replaces surfaceWhite78/80… on dark only).
    static var listCardSecondaryText: Color {
        isLightGrey ? tgGrey : surfaceWhite78
    }

    static var listCardTertiaryText: Color {
        isLightGrey ? secondaryForeground : surfaceWhite60
    }

    static var listCardBodyEmphasisText: Color {
        isLightGrey ? primaryForeground : surfaceWhite90
    }

    static var listCardBodyText: Color {
        isLightGrey ? primaryForeground.opacity(0.92) : surfaceWhite85
    }

    static var listCardHighlightText: Color {
        isLightGrey ? primaryForeground : surfaceWhite92
    }

    static var listCardContextSummaryFallback: Color {
        isLightGrey ? secondaryForeground : surfaceWhite70
    }

    /// Neutral meta chip fill on marker rows (was surfaceWhite08).
    static var metaChipNeutralBackground: Color {
        isLightGrey ? tgWhiteText.opacity(0.10) : surfaceWhite08
    }

    /// Symbol list row unselected gradient. Dark/Mid: surfaceWhite05→03.
    static var symbolListRowUnselectedLeading: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.08)
        case .midGrey, .dark: return surfaceWhite05
        }
    }

    static var symbolListRowUnselectedTrailing: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.04)
        case .midGrey, .dark: return surfaceWhite03
        }
    }

    /// Status badge on symbol list rows (global list).
    static var symbolRowBadgeForeground: Color {
        isLightGrey ? primaryForeground : surfaceWhite90
    }

    static var symbolRowBadgeBackground: Color {
        isLightGrey ? tgWhiteText.opacity(0.10) : surfaceWhite14
    }

    /// Symbol details expanded card. Dark/Mid: surfaceWhite08 fill / surfaceWhite12 stroke.
    static var symbolDetailCardFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.07)
        case .midGrey, .dark: return surfaceWhite08
        }
    }

    static var symbolDetailCardStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    /// Symbol details disclosure header capsule (matches search / disclosure strip).
    static var symbolDetailsHeaderGradientLeading: Color { searchBarGradientLeading }
    static var symbolDetailsHeaderGradientTrailing: Color { searchBarGradientTrailing }

    /// Chevrons / secondary chrome on sheet headers. Dark/Mid: white 50%; Light: mid grey.
    static var adaptiveAccessoryForeground: Color {
        isLightGrey ? tgMidGrey : Color.white.opacity(0.5)
    }

    // MARK: - Chat background overlays & pattern strength

    static var chatBackgroundOverlayStandardStart: Color {
        switch theme {
        case .lightGrey: return Color.black.opacity(0.045)
        case .midGrey, .dark: return surfaceWhite03
        }
    }

    static var chatBackgroundOverlayStandardEnd: Color { surfaceWhite00 }

    static var chatBackgroundOverlayElevatedStart: Color {
        switch theme {
        case .lightGrey: return Color.black.opacity(0.09)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    static var chatBackgroundOverlayElevatedEnd: Color {
        switch theme {
        case .lightGrey: return Color.black.opacity(0.035)
        case .midGrey, .dark: return surfaceWhite04
        }
    }

    /// Multiplier on `StaticPatternView` when used inside `ChatBackground`.
    static var chatBackgroundPatternMultiplyStandard: Double { isLightGrey ? 0.24 : 0.06 }
    static var chatBackgroundPatternMultiplyElevated: Double { isLightGrey ? 0.30 : 0.10 }

    /// Scales `StaticPatternView` in guild discover/switch/create flows (lightGrey only).
    static var guildFlowPatternOpacityScale: Double { isLightGrey ? 0.58 : 1.0 }

    /// Selected row highlight on guild switch list (accent fill/stroke opacity).
    static var guildSwitchRowSelectedFillOpacity: Double { isLightGrey ? 0.24 : 0.16 }
    static var guildSwitchRowSelectedStrokeOpacity: Double { isLightGrey ? 0.50 : 0.38 }

    /// Discover-style search field (capsule fill + stroke). Light uses explicit fill; dark/mid keep gradient-leading as flat fallback.
    static var standardSearchFieldFill: Color {
        isLightGrey ? unhighlightedTextBoxBackground.opacity(0.92) : searchBarGradientLeading
    }

    static var standardSearchFieldStroke: Color {
        isLightGrey ? tgWhiteText.opacity(0.2) : surfaceWhite12
    }

    static var standardSearchFieldAccessory: Color {
        isLightGrey ? tgMidGrey : surfaceWhite50
    }

    /// Unselected capsule tabs (UnifiedTabButton / UnifiedCategoryTabButton).
    static var tabPillUnselectedGradientLeading: Color {
        isLightGrey ? tgWhiteText.opacity(0.14) : subtleSurfaceOverlay08
    }

    static var tabPillUnselectedGradientTrailing: Color {
        isLightGrey ? tgWhiteText.opacity(0.08) : subtleSurfaceOverlay04
    }

    static var tabPillUnselectedLabel: Color {
        isLightGrey ? tgGrey : Color.gray
    }

    /// Target opacity for honeycomb fade-in (inline pattern only).
    static var inlineHoneycombPatternOpacity: Double { isLightGrey ? 0.055 : 0.02 }

    /// `StaticMessagingBackgroundView` honeycomb fade-in target.
    static var messagingSheetHoneycombPatternOpacity: Double { isLightGrey ? 0.048 : 0.02 }

    /// Main chart root honeycomb (light theme only branch uses this).
    static let chartLightGreyHoneycombOpacity: Double = 0.028

    /// Modal surfaces that used `UIColor.systemBackground` / `systemGray6`. Light: TG palette; dark/mid: system dynamic.
    static var duplicateDialogCardBackground: Color {
        switch theme {
        case .lightGrey: return tgSheetBackground
        case .midGrey, .dark: return Color(uiColor: .systemBackground)
        }
    }

    static var duplicateDialogSecondaryButtonFill: Color {
        switch theme {
        case .lightGrey: return tgSheetDarkBackground
        case .midGrey, .dark: return Color(uiColor: .systemGray6)
        }
    }

    /// Profile/settings inset blocks (was surfaceWhite03). Dark/Mid: unchanged.
    static var insetPanelBackground: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.05)
        case .midGrey, .dark: return surfaceWhite03
        }
    }

    /// Stronger flat panel (was surfaceWhite10).
    static var panelFillEmphasis: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    /// Stroke for attachment-draft rows in chat (was surfaceWhite10).
    static var linkedMarkerAttachmentStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.14)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    /// Intent picker pills on marker detail (was systemWhite 5% / 11%).
    static var intentPickerPillFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.06)
        case .midGrey, .dark: return Color.white.opacity(0.05)
        }
    }

    static var intentPickerPillFillSelected: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return Color.white.opacity(0.11)
        }
    }

    /// Drawing line-style picker on chart (surfaceWhite04 / surfaceWhite12 selected).
    static var drawingStyleSwatchFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.07)
        case .midGrey, .dark: return surfaceWhite04
        }
    }

    static var drawingStyleSwatchFillSelected: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.14)
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    static var drawingStyleSwatchStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.18)
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    /// Dash preview line inside drawing style swatch (surfaceWhite84 on dark).
    static var drawingStylePreviewLine: Color {
        isLightGrey ? tgGrey : surfaceWhite84
    }

    /// `UnifiedContentCard` background wash (was `systemWhite.opacity` by state).
    static func contentCardFill(isUnread: Bool, isPressed: Bool) -> Color {
        switch theme {
        case .lightGrey:
            if isUnread { return tgWhiteText.opacity(isPressed ? 0.13 : 0.10) }
            return tgWhiteText.opacity(isPressed ? 0.10 : 0.07)
        case .midGrey, .dark:
            if isUnread { return Color.white.opacity(isPressed ? 0.10 : 0.08) }
            return Color.white.opacity(isPressed ? 0.06 : 0.03)
        }
    }

    /// `UnifiedLeaderboardRow` background (was systemWhite by rank/press).
    static func leaderboardRowFill(isTopRank: Bool, isPressed: Bool) -> Color {
        switch theme {
        case .lightGrey:
            let base = isTopRank ? (isPressed ? 0.12 : 0.09) : (isPressed ? 0.10 : 0.07)
            return tgWhiteText.opacity(base)
        case .midGrey, .dark:
            return Color.white.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03))
        }
    }

    // MARK: - Subtle Surface Overlays (adaptive for tabs/strips/disclosures)

    /// Replaces surfaceWhite08 in tab/strip backgrounds. Adaptive: white 8% on dark, black 8% on light.
    static var subtleSurfaceOverlay08: Color { adaptiveOverlay08 }
    /// Replaces surfaceWhite04 in tab/strip backgrounds. Adaptive: white 5% on dark, black 5% on light.
    static var subtleSurfaceOverlay04: Color { adaptiveOverlay05 }

    // MARK: - Backward-Compatible Aliases

    static var gradientBackgroundDark: Color { tgGradientBackground }
    static var gradientBackgroundMid: Color { tgGradientBackgroundMid }
    static var gradientBackgroundLight: Color { tgGradientBackgroundLight }

    static var sheetBackground: Color { tgSheetBackground }
    static var sheetBackgroundDark: Color { tgSheetDarkBackground }
    static var drawerBackground: Color { tgDrawerBackground }
    static var toolbarBackground: Color { tgToolbarBackground }

    static var whiteText: Color { tgWhiteText }
    static var greyText: Color { tgMidGrey }
    static let accentColor = tgAccent
    static let accentDarkColor = tgAccentDark
    static let friendAccent = tgFriend
    static let bullCandleGreen = tgBull
    static let bearCandleRed = tgBear

    static var unhighlightedTextBoxBackground: Color { tgButtonSearchBackground }
    static var unhighlightedButtonBackground: Color { tgUnhighlightedWhite }
    static var fadedBackground: Color { tgFadedBackground }
    static let chartLogo = tgChartLogo
}
