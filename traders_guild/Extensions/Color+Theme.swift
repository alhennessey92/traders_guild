//
//  Color+Theme.swift
//  traders_guild
//
//  App-wide color source of truth.
//  NOTE: Tokens in this file must remain value-stable unless explicitly retuning design.
//

import SwiftUI

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

    /// TGGradientBackground. Dark: #010105, MidGrey: #181C28, LightGrey: #B3BACC.
    static var tgGradientBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 179.0 / 255, green: 186.0 / 255, blue: 204.0 / 255)
        case .midGrey:   return Color(red: 0x18 / 255.0, green: 0x1C / 255.0, blue: 0x28 / 255.0)
        case .dark:      return Color("TGGradientBackground")
        }
    }
    /// TGGradientBackgroundMid. Dark: #111111, MidGrey: dimmed, LightGrey: dimmed.
    static var tgGradientBackgroundMid: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 177.0 / 255, blue: 192.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 36.0 / 255)
        case .dark:      return Color("TGGradientBackgroundMid")
        }
    }
    /// TGGradientBackgroundLight. Dark: #000127, MidGrey: lifted, LightGrey: lifted.
    static var tgGradientBackgroundLight: Color {
        switch theme {
        case .lightGrey: return Color(red: 192.0 / 255, green: 198.0 / 255, blue: 212.0 / 255)
        case .midGrey:   return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 42.0 / 255)
        case .dark:      return Color("TGGradientBackgroundLight")
        }
    }

    /// TGSheetBackground. Dark: #1B1A1F, MidGrey: #181C28, LightGrey: #B9C0CE.
    static var tgSheetBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 185.0 / 255, green: 192.0 / 255, blue: 206.0 / 255)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255)
        case .dark:      return Color("TGSheetBackground")
        }
    }
    /// TGSheetDarkBackground. Dark: #1F1E1A, MidGrey: slightly darker, LightGrey: darker.
    static var tgSheetDarkBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 177.0 / 255, blue: 192.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 38.0 / 255)
        case .dark:      return Color("TGSheetDarkBackground")
        }
    }
    /// TGDrawerBackground. Dark: #00000A, MidGrey: #171B27, LightGrey: #A8AFBE.
    static var tgDrawerBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 168.0 / 255, green: 175.0 / 255, blue: 190.0 / 255)
        case .midGrey:   return Color(red: 23.0 / 255, green: 27.0 / 255, blue: 39.0 / 255)
        case .dark:      return Color("TGDrawerBackground")
        }
    }
    /// TGToolbarBackground. Dark: #00000E/0.35, MidGrey: #181C28/0.55, LightGrey: #B3BACC/0.85.
    static var tgToolbarBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 179.0 / 255, green: 186.0 / 255, blue: 204.0 / 255).opacity(0.85)
        case .midGrey:   return Color(red: 0x18 / 255.0, green: 0x1C / 255.0, blue: 0x28 / 255.0).opacity(0.55)
        case .dark:      return Color("TGToolbarBackground")
        }
    }

    /// TGWhiteText. Dark/MidGrey: #ECECEC, LightGrey: #1E2233 (dark blue-grey).
    static var tgWhiteText: Color {
        isLightGrey ? Color(red: 30.0 / 255, green: 34.0 / 255, blue: 51.0 / 255)
                    : Color("TGWhiteText")
    }
    /// TGWhite. Dark/MidGrey: #FFFFFF, LightGrey: #1E2233.
    static var tgWhite: Color {
        isLightGrey ? Color(red: 30.0 / 255, green: 34.0 / 255, blue: 51.0 / 255)
                    : Color("TGWhite")
    }
    /// TGMidGrey. Dark/MidGrey: #7A7878, LightGrey: #6A6E7C.
    static var tgMidGrey: Color {
        isLightGrey ? Color(red: 106.0 / 255, green: 110.0 / 255, blue: 124.0 / 255)
                    : Color("TGMidGrey")
    }
    /// TGGrey. Dark/MidGrey: #A9A9A9, LightGrey: #4A4E5C.
    static var tgGrey: Color {
        isLightGrey ? Color(red: 74.0 / 255, green: 78.0 / 255, blue: 92.0 / 255)
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

    /// TGButtonSearchBackground. Dark: #191921, MidGrey: same ratio, LightGrey: #C4CAD7.
    static var tgButtonSearchBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 196.0 / 255, green: 202.0 / 255, blue: 215.0 / 255)
        case .midGrey:   return Color(red: 20.0 / 255, green: 24.0 / 255, blue: 34.0 / 255)
        case .dark:      return Color("TGButtonSearchBackground")
        }
    }
    /// TGUnhighlightedWhite. Dark/MidGrey: #C3C3C3, LightGrey: #5A5E6C.
    static var tgUnhighlightedWhite: Color {
        isLightGrey ? Color(red: 90.0 / 255, green: 94.0 / 255, blue: 108.0 / 255)
                    : Color("TGUnhighlightedWhite")
    }
    /// TGFadedBackground. Dark: #3F404D, MidGrey: lifted, LightGrey: #C8CEDA.
    static var tgFadedBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 200.0 / 255, green: 206.0 / 255, blue: 218.0 / 255)
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
        case .lightGrey: return Color(red: 179.0 / 255, green: 186.0 / 255, blue: 204.0 / 255)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundMuted: Color {
        switch theme {
        case .lightGrey: return Color(red: 175.0 / 255, green: 182.0 / 255, blue: 198.0 / 255)
        case .midGrey:   return Color(red: 23.0 / 255, green: 27.0 / 255, blue: 38.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 26.0 / 255)
        }
    }
    static var chartPanelBackgroundInset: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 177.0 / 255, blue: 192.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 36.0 / 255)
        case .dark:      return Color(red: 18.0 / 255, green: 18.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundAlt: Color {
        switch theme {
        case .lightGrey: return Color(red: 185.0 / 255, green: 192.0 / 255, blue: 206.0 / 255)
        case .midGrey:   return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 42.0 / 255)
        case .dark:      return Color(red: 25.0 / 255, green: 25.0 / 255, blue: 33.0 / 255)
        }
    }
    static var chartPanelBackgroundDeep: Color {
        switch theme {
        case .lightGrey: return Color(red: 155.0 / 255, green: 162.0 / 255, blue: 178.0 / 255)
        case .midGrey:   return Color(red: 18.0 / 255, green: 22.0 / 255, blue: 32.0 / 255)
        case .dark:      return Color(red: 10.0 / 255, green: 10.0 / 255, blue: 12.0 / 255)
        }
    }
    static var chartIndicatorHandleFill: Color {
        switch theme {
        case .lightGrey: return Color(white: 0.90)
        case .midGrey:   return Color(white: 0.10)
        case .dark:      return Color(white: 0.08)
        }
    }

    // MARK: - Component-Level Theme Tokens

    /// Info box background (crosshair OHLCV popup). Blends with chart background.
    static var infoBoxBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 170.0 / 255, green: 177.0 / 255, blue: 192.0 / 255).opacity(0.94)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 38.0 / 255).opacity(0.94)
        case .dark:      return Color.black.opacity(0.85)
        }
    }

    /// Panel header background (indicator & timeframe panels). Subtle darker strip.
    static var panelHeaderBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 155.0 / 255, green: 162.0 / 255, blue: 178.0 / 255)
        case .midGrey:   return Color(red: 18.0 / 255, green: 22.0 / 255, blue: 32.0 / 255)
        case .dark:      return Color(red: 16.0 / 255, green: 16.0 / 255, blue: 22.0 / 255)
        }
    }

    /// X-axis bottom area background. Dark: pure black, MidGrey: very dark blue-grey, LightGrey: darker blue-grey.
    static var xAxisBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 145.0 / 255, green: 152.0 / 255, blue: 168.0 / 255)
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
        isLightGrey ? Color(red: 185.0 / 255, green: 192.0 / 255, blue: 206.0 / 255)
                    : Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 37.0 / 255.0)
    }
    static var markerNeutralFillBottom: Color {
        isLightGrey ? Color(red: 155.0 / 255, green: 162.0 / 255, blue: 178.0 / 255)
                    : Color(red: 12.0 / 255.0, green: 12.0 / 255.0, blue: 14.0 / 255.0)
    }
    static let markerIconLight = Color(white: 0.72)
    static let markerBorderGrey = surfaceWhite24

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
