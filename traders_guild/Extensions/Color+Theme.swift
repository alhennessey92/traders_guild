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

    /// Light grey accent anchors + shared ramps (palette audit §41): one nav-blue family for chart tabs + symbol sheet; brand teal for guild/chat.
    private enum LightGreyPalette {
        static var reputationAccent: Color {
            Color(red: 10.0 / 255, green: 138.0 / 255, blue: 158.0 / 255)
        }

        /// Same hue as `reputationAccent`, shifted for outgoing bubble on pale threads.
        static var outgoingChatBubbleFill: Color {
            Color(red: 32.0 / 255, green: 137.0 / 255, blue: 155.0 / 255)
        }

        /// Anchor matches `themeAwareInfoBlue` on light grey — links + nav chrome ladder.
        static var infoBlueAnchor: Color {
            Color(red: 28.0 / 255, green: 82.0 / 255, blue: 168.0 / 255)
        }

        static var navBlueRampTabStart: Color { Color(red: 120.0 / 255, green: 158.0 / 255, blue: 218.0 / 255) }
        static var navBlueRampTabEnd: Color { Color(red: 94.0 / 255, green: 132.0 / 255, blue: 202.0 / 255) }
        static var navBlueRampSubTabStart: Color { Color(red: 88.0 / 255, green: 124.0 / 255, blue: 192.0 / 255) }
        static var navBlueRampSubTabEnd: Color { Color(red: 64.0 / 255, green: 102.0 / 255, blue: 174.0 / 255) }
        static var navBlueRampDeepStart: Color { Color(red: 52.0 / 255, green: 88.0 / 255, blue: 158.0 / 255) }
        static var navBlueRampDeepEnd: Color { Color(red: 36.0 / 255, green: 70.0 / 255, blue: 138.0 / 255) }

        static var symbolHeroLeading: Color { navBlueRampTabStart }
        static var symbolHeroTrailing: Color { navBlueRampTabEnd }
        static var symbolRowSelectedLeading: Color { navBlueRampSubTabStart }
        static var symbolRowSelectedTrailing: Color { navBlueRampSubTabEnd }

        // Semantic color anchors for light grey readability (palette audit §42)
        static var negativeRedAnchor: Color {
            Color(red: 178.0 / 255, green: 34.0 / 255, blue: 34.0 / 255)
        }
        static var warningOrangeAnchor: Color {
            Color(red: 196.0 / 255, green: 92.0 / 255, blue: 22.0 / 255)
        }
        static var highlightYellowAnchor: Color {
            Color(red: 154.0 / 255, green: 120.0 / 255, blue: 12.0 / 255)
        }
        static var secondaryPurpleAnchor: Color {
            Color(red: 108.0 / 255, green: 52.0 / 255, blue: 168.0 / 255)
        }
        static var accentCyanAnchor: Color { reputationAccent }
        static var tealAnchor: Color {
            Color(red: 12.0 / 255, green: 128.0 / 255, blue: 118.0 / 255)
        }
        static var pinkAnchor: Color {
            Color(red: 186.0 / 255, green: 44.0 / 255, blue: 108.0 / 255)
        }
        static var indigoAnchor: Color {
            Color(red: 62.0 / 255, green: 48.0 / 255, blue: 158.0 / 255)
        }

        /// Lifted forest green for semantic positive UI (accuracy, profit, status) on light grey.
        /// Was RGB 14/108/52 — too dark/muddy. Lifted to a brighter forest green that still passes
        /// AA contrast on `#C0C2C9` chrome but reads as crisp rather than near-black.
        /// Separated from `defaultBullishCandleGreen` (RGB 88,185,138) so candle hue is unchanged.
        static var semanticGreenAnchor: Color {
            Color(red: 32.0 / 255, green: 140.0 / 255, blue: 70.0 / 255)
        }

        /// Deeper royal blue for `tgFriend` chrome on light grey (friend tick, user gradients).
        /// Same hue family as the `TGFriend` asset (#0574D5), darkened so it sits coherently on pale chrome.
        static var friendBlueAnchor: Color {
            Color(red: 5.0 / 255, green: 96.0 / 255, blue: 176.0 / 255)
        }

        /// Deep navy for inline link text and "Sign up Here" style affordances on pale chrome.
        /// Darker than `infoBlueAnchor` so links read as ink-on-paper rather than mid-tone-on-grey,
        /// fixing the "too bright / hard to see" feedback for the Welcome / auth landing.
        static var linkInk: Color {
            Color(red: 10.0 / 255, green: 56.0 / 255, blue: 120.0 / 255)
        }
    }

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

    /// TGAccent. Dark/MidGrey: asset #0F9EB4. LightGrey: `LightGreyPalette.reputationAccent` (#0A8A9E) — deeper teal so the brand accent reads
    /// coherently on pale chrome instead of glowing bright. Same routing as `guildReputationAccent`.
    static var tgAccent: Color {
        isLightGrey ? LightGreyPalette.reputationAccent : Color("TGAccent")
    }
    /// TGAccentDark asset. Hex #026675 alpha 1.0.
    static let tgAccentDark = Color("TGAccentDark")
    /// TGFriend. Dark/MidGrey: asset #0574D5. LightGrey: `LightGreyPalette.friendBlueAnchor` (#0560B0) — deeper royal blue.
    static var tgFriend: Color {
        isLightGrey ? LightGreyPalette.friendBlueAnchor : Color("TGFriend")
    }

    /// TGBull asset. Hex #4A9476 alpha 1.0. Theme-stable — candle / chart use only. For semantic
    /// positive chrome (online dots, status badges, etc.) use `onlineStatusGreen` or `statusPositive`.
    static let tgBull = Color("TGBull")
    /// TGBear asset. Hex #A62C2B alpha 1.0. Theme-stable — already a deep red that reads on pale chrome.
    static let tgBear = Color("TGBear")

    /// Semantic positive status (online dot, "+%", liked heart). Light grey: deep forest green from
    /// `themeAwareGreen`; dark/mid: `tgBull` so existing chrome stays visually identical to today.
    /// Use this **instead of `bullCandleGreen`** in non-candle UI surfaces.
    static var onlineStatusGreen: Color {
        isLightGrey ? themeAwareGreen : tgBull
    }

    /// Inline link / "tap to sign up" affordance text on pale chrome. Dark/MidGrey: bright `tgAccent`
    /// (matches existing brand accent links). LightGrey: deep navy `linkInk` — much darker than
    /// `accentColor` so link text reads as ink-on-paper rather than glowing teal.
    static var linkText: Color {
        isLightGrey ? LightGreyPalette.linkInk : tgAccent
    }

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
    /// System `Color.green` wrapper (use `themeAwareGreen` for semantic positive UI).
    static let systemGreen = Color.green

    /// Default bullish chart candle (RGB **88, 185, 138**). Used only for chart rendering — intentionally
    /// kept separate from `themeAwareGreen` so the candle hue is theme-stable.
    static let defaultBullishCandleGreen = Color(red: 88.0 / 255, green: 185.0 / 255, blue: 138.0 / 255)

    /// Canonical positive green: iOS system green on dark/mid; deep forest green on light grey
    /// (high contrast against ~#C0C2C9; candle colour is unaffected — see `defaultBullishCandleGreen`).
    static var themeAwareGreen: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.semanticGreenAnchor
        case .midGrey, .dark:
            return systemGreen
        }
    }

    /// Info / link blue: system blue on dark/mid; deeper blue on light grey (audit 39).
    static var themeAwareInfoBlue: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.infoBlueAnchor
        case .midGrey, .dark:
            return systemBlue
        }
    }

    /// Reports / moderator orange: system orange on dark/mid; darker amber on light grey (audit 40).
    static var themeAwareModerationOrange: Color {
        switch theme {
        case .lightGrey:
            return Color(red: 196.0 / 255, green: 92.0 / 255, blue: 22.0 / 255)
        case .midGrey, .dark:
            return systemOrange
        }
    }

    /// Negative / stop loss red: system red on dark/mid; firebrick on light grey (audit 42).
    static var themeAwareRed: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.negativeRedAnchor
        case .midGrey, .dark: return systemRed
        }
    }

    /// Warning orange: system orange on dark/mid; deep amber on light grey (audit 42).
    static var themeAwareOrange: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.warningOrangeAnchor
        case .midGrey, .dark: return systemOrange
        }
    }

    /// Highlight yellow: system yellow on dark/mid; dark goldenrod on light grey (audit 42).
    static var themeAwareYellow: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.highlightYellowAnchor
        case .midGrey, .dark: return systemYellow
        }
    }

    /// Secondary purple: system purple on dark/mid; deeper purple on light grey (audit 42).
    static var themeAwarePurple: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.secondaryPurpleAnchor
        case .midGrey, .dark: return systemPurple
        }
    }

    /// Accent cyan: system cyan on dark/mid; teal-cyan on light grey (audit 42).
    static var themeAwareCyan: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.accentCyanAnchor
        case .midGrey, .dark: return systemCyan
        }
    }

    /// Teal: system teal on dark/mid; deeper teal on light grey (audit 42).
    static var themeAwareTeal: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.tealAnchor
        case .midGrey, .dark: return systemTeal
        }
    }

    /// Pink: system pink on dark/mid; deeper rose on light grey (audit 42).
    static var themeAwarePink: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.pinkAnchor
        case .midGrey, .dark: return systemPink
        }
    }

    /// Indigo: system indigo on dark/mid; deeper indigo on light grey (audit 42).
    static var themeAwareIndigo: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.indigoAnchor
        case .midGrey, .dark: return systemIndigo
        }
    }

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
    static var adaptiveOverlay12: Color { overlayBase.opacity(0.12) }
    static var adaptiveOverlay15: Color { overlayBase.opacity(0.15) }
    static var adaptiveOverlay18: Color { overlayBase.opacity(0.18) }
    static var adaptiveOverlay20: Color { overlayBase.opacity(0.2) }
    static var adaptiveOverlay24: Color { overlayBase.opacity(0.24) }
    static var adaptiveOverlay30: Color { overlayBase.opacity(0.3) }
    static var adaptiveOverlay40: Color { overlayBase.opacity(0.4) }
    static var adaptiveOverlay45: Color { overlayBase.opacity(0.45) }
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
    static let surfaceWhite16 = systemWhite.opacity(0.16)
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

    static var statusPositive: Color { themeAwareGreen }
    static var statusNegative: Color { themeAwareRed }
    static var statusInfo: Color { themeAwareInfoBlue }
    static var statusWarning: Color { themeAwareOrange }

    // Full-width toast bar: a solid true yellow for warnings with a legible
    // near-black text/icon colour. Fixed (not theme-aware) so the yellow reads
    // identically in light and dark.
    static let toastWarningYellow = Color(red: 245.0 / 255, green: 197.0 / 255, blue: 24.0 / 255)
    static let toastOnYellow = Color(red: 26.0 / 255, green: 20.0 / 255, blue: 8.0 / 255)
    // Deeper, fixed toast palette — the theme-aware system red/green/blue read
    // too bright as full-width bars. These sit at a consistent medium-deep tone
    // (white text on all three; yellow keeps dark text).
    static let toastSuccessGreen = Color(red: 32.0 / 255, green: 140.0 / 255, blue: 70.0 / 255)
    static let toastErrorRed = Color(red: 197.0 / 255, green: 54.0 / 255, blue: 46.0 / 255)
    static let toastInfoBlue = Color(red: 42.0 / 255, green: 102.0 / 255, blue: 194.0 / 255)

    static var statusNegative08: Color { themeAwareRed.opacity(0.08) }
    static var statusNegative10: Color { themeAwareRed.opacity(0.1) }
    static var statusNegative12: Color { themeAwareRed.opacity(0.12) }
    static var statusNegative15: Color { themeAwareRed.opacity(0.15) }
    static var statusNegative20: Color { themeAwareRed.opacity(0.2) }
    static var statusNegative30: Color { themeAwareRed.opacity(0.3) }
    static var statusNegative35: Color { themeAwareRed.opacity(0.35) }
    static var statusNegative40: Color { themeAwareRed.opacity(0.4) }
    static var statusNegative50: Color { themeAwareRed.opacity(0.5) }
    static var statusNegative55: Color { themeAwareRed.opacity(0.55) }
    static var statusNegative60: Color { themeAwareRed.opacity(0.6) }
    static var statusNegative70: Color { themeAwareRed.opacity(0.7) }
    static var statusNegative75: Color { themeAwareRed.opacity(0.75) }
    static var statusNegative80: Color { themeAwareRed.opacity(0.8) }
    static var statusNegative82: Color { themeAwareRed.opacity(0.82) }
    static var statusNegative85: Color { themeAwareRed.opacity(0.85) }
    static var statusNegative86: Color { themeAwareRed.opacity(0.86) }
    static var statusNegative92: Color { themeAwareRed.opacity(0.92) }
    static var statusNegative95: Color { themeAwareRed.opacity(0.95) }

    static var statusPositive06: Color { themeAwareGreen.opacity(0.06) }
    static var statusPositive08: Color { themeAwareGreen.opacity(0.08) }
    static var statusPositive10: Color { themeAwareGreen.opacity(0.1) }
    static var statusPositive14: Color { themeAwareGreen.opacity(0.14) }
    static var statusPositive15: Color { themeAwareGreen.opacity(0.15) }
    static var statusPositive20: Color { themeAwareGreen.opacity(0.2) }
    static var statusPositive25: Color { themeAwareGreen.opacity(0.25) }
    static var statusPositive30: Color { themeAwareGreen.opacity(0.3) }
    static var statusPositive35: Color { themeAwareGreen.opacity(0.35) }
    static var statusPositive40: Color { themeAwareGreen.opacity(0.4) }
    static var statusPositive45: Color { themeAwareGreen.opacity(0.45) }
    static var statusPositive50: Color { themeAwareGreen.opacity(0.5) }
    static var statusPositive60: Color { themeAwareGreen.opacity(0.6) }
    static var statusPositive66: Color { themeAwareGreen.opacity(0.66) }
    static var statusPositive70: Color { themeAwareGreen.opacity(0.7) }
    static var statusPositive72: Color { themeAwareGreen.opacity(0.72) }
    static var statusPositive80: Color { themeAwareGreen.opacity(0.8) }
    static var statusPositive85: Color { themeAwareGreen.opacity(0.85) }
    static var statusPositive90: Color { themeAwareGreen.opacity(0.9) }
    static var statusPositive95: Color { themeAwareGreen.opacity(0.95) }

    static var statusInfo08: Color { themeAwareInfoBlue.opacity(0.08) }
    static var statusInfo10: Color { themeAwareInfoBlue.opacity(0.1) }
    static var statusInfo15: Color { themeAwareInfoBlue.opacity(0.15) }
    static var statusInfo16: Color { themeAwareInfoBlue.opacity(0.16) }
    static var statusInfo20: Color { themeAwareInfoBlue.opacity(0.2) }
    static var statusInfo22: Color { themeAwareInfoBlue.opacity(0.22) }
    static var statusInfo24: Color { themeAwareInfoBlue.opacity(0.24) }
    static var statusInfo25: Color { themeAwareInfoBlue.opacity(0.25) }
    static var statusInfo35: Color { themeAwareInfoBlue.opacity(0.35) }
    static var statusInfo40: Color { themeAwareInfoBlue.opacity(0.4) }
    static var statusInfo45: Color { themeAwareInfoBlue.opacity(0.45) }
    static var statusInfo50: Color { themeAwareInfoBlue.opacity(0.5) }
    static var statusInfo52: Color { themeAwareInfoBlue.opacity(0.52) }
    static var statusInfo55: Color { themeAwareInfoBlue.opacity(0.55) }
    static var statusInfo60: Color { themeAwareInfoBlue.opacity(0.6) }
    static var statusInfo62: Color { themeAwareInfoBlue.opacity(0.62) }
    static var statusInfo65: Color { themeAwareInfoBlue.opacity(0.65) }
    static var statusInfo70: Color { themeAwareInfoBlue.opacity(0.7) }
    static var statusInfo75: Color { themeAwareInfoBlue.opacity(0.75) }
    static var statusInfo80: Color { themeAwareInfoBlue.opacity(0.8) }
    static var statusInfo85: Color { themeAwareInfoBlue.opacity(0.85) }
    static var statusInfo90: Color { themeAwareInfoBlue.opacity(0.9) }
    static var statusInfo92: Color { themeAwareInfoBlue.opacity(0.92) }
    static var statusInfo95: Color { themeAwareInfoBlue.opacity(0.95) }

    static var statusWarning10: Color { themeAwareOrange.opacity(0.1) }
    static var statusWarning14: Color { themeAwareOrange.opacity(0.14) }
    static var statusWarning15: Color { themeAwareOrange.opacity(0.15) }
    static var statusWarning16: Color { themeAwareOrange.opacity(0.16) }
    static var statusWarning18: Color { themeAwareOrange.opacity(0.18) }
    static var statusWarning20: Color { themeAwareOrange.opacity(0.2) }
    static var statusWarning28: Color { themeAwareOrange.opacity(0.28) }
    static var statusWarning30: Color { themeAwareOrange.opacity(0.3) }
    static var statusWarning40: Color { themeAwareOrange.opacity(0.4) }
    static var statusWarning45: Color { themeAwareOrange.opacity(0.45) }
    static var statusWarning50: Color { themeAwareOrange.opacity(0.5) }
    static var statusWarning60: Color { themeAwareOrange.opacity(0.6) }
    static var statusWarning62: Color { themeAwareOrange.opacity(0.62) }
    static var statusWarning70: Color { themeAwareOrange.opacity(0.7) }
    static var statusWarning72: Color { themeAwareOrange.opacity(0.72) }
    static var statusWarning80: Color { themeAwareOrange.opacity(0.8) }
    static var statusWarning90: Color { themeAwareOrange.opacity(0.9) }
    static var statusWarning92: Color { themeAwareOrange.opacity(0.92) }
    static var statusWarning95: Color { themeAwareOrange.opacity(0.95) }

    // MARK: - Audits 36–40 (light grey readability)

    /// Moderation UI, filed reports, moderator role tint (audit 40).
    static var moderationOrange: Color { themeAwareModerationOrange }

    /// Reaction marker intent / labels — saturated amber on dark/mid; deeper amber on light grey (readable on pale chrome).
    static var markerReactionAccent: Color {
        isLightGrey ? moderationOrange : Color(red: 245.0 / 255, green: 158.0 / 255, blue: 11.0 / 255)
    }

    /// Guild switch, drawer guild chrome, reputation numerals — same hue as `TGAccent` (#0F9EB4), slightly deeper on light grey so it’s not as bright on pale chrome; `TGAccent` on dark/mid.
    static var guildReputationAccent: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.reputationAccent
        case .midGrey, .dark:
            return tgAccent
        }
    }

    /// Outgoing chat bubble background (audit 36); dark/mid unchanged from `tgAccentDark`.
    static var chatOutgoingBubbleFill: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.outgoingChatBubbleFill
        case .midGrey, .dark:
            return tgAccentDark
        }
    }

    /// Watchlist / symbol sheet price direction (audit 38); avoids adaptive `.green` on light color scheme.
    static var priceChangePositive: Color { statusPositive }
    static var priceChangeNegative: Color { statusNegative }

    /// Role pill colors; use instead of `RLMemberRole.color` where theme matters (audit 40).
    static func memberRoleColor(_ role: RLMemberRole) -> Color {
        switch role {
        case .member:
            return isLightGrey ? tgMidGrey : systemGray
        case .moderator:
            return moderationOrange
        case .admin:
            return themeAwareRed
        case .owner:
            return isLightGrey ? Color(red: 176.0 / 255, green: 138.0 / 255, blue: 28.0 / 255) : systemYellow
        }
    }

    static var statusHighlight20: Color { themeAwareYellow.opacity(0.2) }
    static var statusHighlight40: Color { themeAwareYellow.opacity(0.4) }
    static var statusHighlight50: Color { themeAwareYellow.opacity(0.5) }
    static var statusHighlight55: Color { themeAwareYellow.opacity(0.55) }
    static var statusHighlight68: Color { themeAwareYellow.opacity(0.68) }
    static var statusHighlight80: Color { themeAwareYellow.opacity(0.8) }
    static var statusHighlight90: Color { themeAwareYellow.opacity(0.9) }
    static var statusHighlight95: Color { themeAwareYellow.opacity(0.95) }

    static var statusSecondary10: Color { themeAwarePurple.opacity(0.1) }
    static var statusSecondary30: Color { themeAwarePurple.opacity(0.3) }
    static var statusSecondary50: Color { themeAwarePurple.opacity(0.5) }
    static var statusSecondary70: Color { themeAwarePurple.opacity(0.7) }

    static var statusAccent40: Color { themeAwareCyan.opacity(0.4) }
    static var statusAccent66: Color { themeAwareCyan.opacity(0.66) }
    static var statusAccent90: Color { themeAwareCyan.opacity(0.9) }

    static var statusTeal22: Color { themeAwareTeal.opacity(0.22) }
    static var statusTeal30: Color { themeAwareTeal.opacity(0.3) }
    static var statusTeal58: Color { themeAwareTeal.opacity(0.58) }
    static var statusTeal95: Color { themeAwareTeal.opacity(0.95) }

    static var statusPink45: Color { themeAwarePink.opacity(0.45) }
    static var statusPink50: Color { themeAwarePink.opacity(0.5) }
    static var statusPink72: Color { themeAwarePink.opacity(0.72) }

    static var statusIndigo58: Color { themeAwareIndigo.opacity(0.58) }

    // MARK: - Theme-Aware Semantic Color Accessors (audit 42 — chart/marker DTOs)

    /// Chart component colors — preserve original hex on dark/mid; route to palette anchors on light grey.
    static var componentEntryGreen: Color {
        switch theme {
        case .lightGrey: return themeAwareGreen
        case .midGrey, .dark: return Color(red: 14.0 / 255, green: 133.0 / 255, blue: 77.0 / 255)
        }
    }
    static var componentStopLossRed: Color {
        switch theme {
        case .lightGrey: return themeAwareRed
        case .midGrey, .dark: return Color(red: 220.0 / 255, green: 38.0 / 255, blue: 38.0 / 255)
        }
    }
    static var componentTakeProfitCyan: Color {
        switch theme {
        case .lightGrey: return themeAwareCyan
        case .midGrey, .dark: return Color(red: 14.0 / 255, green: 165.0 / 255, blue: 233.0 / 255)
        }
    }
    static var componentSupportPurple: Color {
        switch theme {
        case .lightGrey: return themeAwarePurple
        case .midGrey, .dark: return Color(red: 124.0 / 255, green: 58.0 / 255, blue: 237.0 / 255)
        }
    }
    static var componentResistanceRed: Color { componentStopLossRed }
    static var componentTrendlineTeal: Color {
        switch theme {
        case .lightGrey: return themeAwareTeal
        case .midGrey, .dark: return Color(red: 20.0 / 255, green: 184.0 / 255, blue: 166.0 / 255)
        }
    }
    static var componentZoneGreen: Color {
        switch theme {
        case .lightGrey: return themeAwareGreen
        case .midGrey, .dark: return Color(red: 34.0 / 255, green: 197.0 / 255, blue: 94.0 / 255)
        }
    }
    static var componentIndicatorOrange: Color {
        switch theme {
        case .lightGrey: return themeAwareOrange
        case .midGrey, .dark: return Color(red: 245.0 / 255, green: 158.0 / 255, blue: 11.0 / 255)
        }
    }
    static var componentLinkPink: Color {
        switch theme {
        case .lightGrey: return themeAwarePink
        case .midGrey, .dark: return Color(red: 236.0 / 255, green: 72.0 / 255, blue: 153.0 / 255)
        }
    }
    static var componentTimeframeCyan: Color {
        switch theme {
        case .lightGrey: return themeAwareCyan
        case .midGrey, .dark: return Color(red: 56.0 / 255, green: 189.0 / 255, blue: 248.0 / 255)
        }
    }
    static var componentAnchorBlue: Color {
        switch theme {
        case .lightGrey: return themeAwareInfoBlue
        case .midGrey, .dark: return Color(red: 91.0 / 255, green: 127.0 / 255, blue: 255.0 / 255)
        }
    }

    /// Marker intent colors — preserve original hex on dark/mid; route to palette anchors on light grey.
    static var intentAnalysisTeal: Color {
        switch theme {
        case .lightGrey: return themeAwareTeal
        case .midGrey, .dark: return Color(red: 15.0 / 255, green: 158.0 / 255, blue: 180.0 / 255)
        }
    }
    static var intentSetupGreen: Color { componentEntryGreen }
    static var intentQuestionBlue: Color { componentAnchorBlue }
    static var intentPollPurple: Color {
        switch theme {
        case .lightGrey: return themeAwarePurple
        case .midGrey, .dark: return Color(red: 139.0 / 255, green: 92.0 / 255, blue: 246.0 / 255)
        }
    }
    static var intentNewsPink: Color { componentLinkPink }

    /// Alert severity colors — theme-aware for `MarkerAlertSeverity.color`.
    static var alertSeverityMild: Color { themeAwareInfoBlue }
    static var alertSeverityModerate: Color { themeAwareOrange }
    static var alertSeveritySevere: Color { themeAwareYellow }
    static var alertSeverityCritical: Color { themeAwareRed }

    /// Marker palette secondary tints — lighter companions for SF Symbol multi-color rendering.
    static var paletteSetupSecondary: Color {
        switch theme {
        case .lightGrey: return themeAwareGreen.opacity(0.75)
        case .midGrey, .dark: return Color(red: 74.0 / 255, green: 222.0 / 255, blue: 128.0 / 255)
        }
    }
    static var paletteAnalysisSecondary: Color {
        switch theme {
        case .lightGrey: return themeAwareCyan.opacity(0.75)
        case .midGrey, .dark: return Color(red: 34.0 / 255, green: 211.0 / 255, blue: 238.0 / 255)
        }
    }
    static var paletteQuestionSecondary: Color {
        switch theme {
        case .lightGrey: return themeAwareInfoBlue.opacity(0.78)
        case .midGrey, .dark: return Color(red: 147.0 / 255, green: 197.0 / 255, blue: 253.0 / 255)
        }
    }
    static var palettePollSecondary: Color {
        switch theme {
        case .lightGrey: return themeAwarePurple.opacity(0.72)
        case .midGrey, .dark: return Color(red: 196.0 / 255, green: 181.0 / 255, blue: 253.0 / 255)
        }
    }
    static var paletteNewsSecondary: Color {
        switch theme {
        case .lightGrey: return themeAwarePink.opacity(0.72)
        case .midGrey, .dark: return Color(red: 249.0 / 255, green: 168.0 / 255, blue: 212.0 / 255)
        }
    }

    /// Award category colors — theme-aware (audit 42).
    static var awardCategoryTrading: Color { statusPositive }
    static var awardCategoryCommunity: Color { statusInfo }
    static var awardCategoryMilestones: Color { statusWarning }
    static var awardCategorySpecial: Color { themeAwarePurple }

    /// Award rarity colors — theme-aware (audit 42).
    static var awardRarityUncommon: Color { statusPositive }
    static var awardRarityRare: Color { statusInfo }
    static var awardRarityEpic: Color { themeAwarePurple }
    static var awardRarityLegendary: Color { statusWarning }

    /// Social link platform colors — theme-aware (audit 42).
    static var socialBlue: Color { statusInfo }
    static var socialIndigo: Color { themeAwareIndigo }
    static var socialCyan: Color { themeAwareCyan }
    static var socialOrange: Color { statusWarning }
    static var socialRed: Color { statusNegative }

    // MARK: - Chart / Indicator Literal Tokens

    /// Primary blue tab gradient; lightGrey uses shared nav-blue ramp (palette §41).
    static var chartTabGradientStart: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampTabStart
        case .midGrey, .dark: return Color(red: 0.20, green: 0.40, blue: 0.80)
        }
    }

    static var chartTabGradientEnd: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampTabEnd
        case .midGrey, .dark: return Color(red: 0.15, green: 0.25, blue: 0.50)
        }
    }

    // Orange gradient for active/selected tabs (audit 34: slightly lighter on light grey).
    static var chartOrangeGradientStart: Color {
        switch theme {
        case .lightGrey: return Color(red: 0.94, green: 0.58, blue: 0.28)
        case .midGrey, .dark: return Color(red: 0.82, green: 0.42, blue: 0.12)
        }
    }

    static var chartOrangeGradientEnd: Color {
        switch theme {
        case .lightGrey: return Color(red: 0.82, green: 0.44, blue: 0.18)
        case .midGrey, .dark: return Color(red: 0.62, green: 0.28, blue: 0.08)
        }
    }

    // Green gradient for marker "Add" tab — light grey: lighter/darker companions around `defaultBullishCandleGreen`.
    static var chartGreenGradientStart: Color {
        switch theme {
        case .lightGrey: return Color(red: 108.0 / 255, green: 200.0 / 255, blue: 158.0 / 255)
        case .midGrey, .dark: return Color(red: 0.14, green: 0.52, blue: 0.28)
        }
    }

    static var chartGreenGradientEnd: Color {
        switch theme {
        case .lightGrey: return Color(red: 58.0 / 255, green: 145.0 / 255, blue: 108.0 / 255)
        case .midGrey, .dark: return Color(red: 0.09, green: 0.36, blue: 0.18)
        }
    }

    static var chartSubTabGradientStart: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampSubTabStart
        case .midGrey, .dark: return Color(red: 0.12, green: 0.18, blue: 0.38)
        }
    }

    static var chartSubTabGradientEnd: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampSubTabEnd
        case .midGrey, .dark: return Color(red: 0.08, green: 0.12, blue: 0.28)
        }
    }

    static var chartDeepSubTabGradientStart: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampDeepStart
        case .midGrey, .dark: return Color(red: 0.08, green: 0.12, blue: 0.25)
        }
    }

    static var chartDeepSubTabGradientEnd: Color {
        switch theme {
        case .lightGrey: return LightGreyPalette.navBlueRampDeepEnd
        case .midGrey, .dark: return Color(red: 0.05, green: 0.08, blue: 0.18)
        }
    }

    /// Bullish candle on light-grey chart (solid fill); same as `defaultBullishCandleGreen` / `statusPositive`.
    static var chartBullCandleLightGrey: Color {
        defaultBullishCandleGreen
    }

    /// Honeycomb strength for admin / chart-settings sheets only (lighter on lightGrey).
    static var adminSheetPatternOpacity: Double { isLightGrey ? 0.020 : 0.02 }

    /// Dashed crosshair / placement guide on chart canvas.
    static var crosshairGuideStroke: Color {
        isLightGrey ? adaptiveOverlay45 : surfaceWhite40
    }

    /// Crosshair OHLC compact popup — header and chrome text on `infoBoxBackground`.
    static var crosshairInfoPopupHeaderText: Color {
        isLightGrey ? secondaryForeground : surfaceWhite70
    }

    static var crosshairInfoPopupBodySecondaryText: Color {
        isLightGrey ? secondaryForeground.opacity(0.88) : surfaceWhite50
    }

    static var crosshairInfoPopupMutedText: Color {
        isLightGrey ? tgGrey : surfaceWhite40
    }

    static var crosshairInfoPopupDivider: Color {
        isLightGrey ? adaptiveOverlay15 : surfaceWhite15
    }

    static var crosshairInfoPopupBorder: Color {
        isLightGrey ? adaptiveOverlay22 : surfaceWhite15
    }

    private static var adaptiveOverlay22: Color { overlayBase.opacity(0.22) }

    /// Crosshair time pill on x-axis (lightGrey: darker grey chip).
    static var crosshairTimeLabelFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 148.0 / 255, green: 152.0 / 255, blue: 164.0 / 255).opacity(0.96)
        case .midGrey, .dark: return surfaceWhite90
        }
    }

    static var crosshairTimeLabelFillMarkerPlacement: Color {
        switch theme {
        case .lightGrey: return Color(red: 140.0 / 255, green: 144.0 / 255, blue: 158.0 / 255).opacity(0.97)
        case .midGrey, .dark: return surfaceWhite94
        }
    }

    static var crosshairCenterDot: Color {
        isLightGrey ? Color(red: 55.0 / 255, green: 58.0 / 255, blue: 68.0 / 255) : systemWhite
    }

    /// Marker flows: same canonical green as `themeAwareGreen` on lightGrey (audit 35).
    static var markerPositiveForeground: Color {
        isLightGrey ? themeAwareGreen : statusPositive90
    }

    static var markerPositiveForegroundMuted: Color {
        isLightGrey ? themeAwareGreen.opacity(0.92) : statusPositive85
    }

    static var markerPositiveFill: Color {
        isLightGrey ? themeAwareGreen.opacity(0.16) : statusPositive14
    }

    static var markerPositiveFillStrong: Color {
        isLightGrey ? themeAwareGreen.opacity(0.26) : statusPositive20
    }

    /// Chart bottom control strip (Markers / Latest / settings): darker chrome on lightGrey.
    static var chartBottomControlInactiveFill: Color {
        switch theme {
        case .lightGrey: return chartPanelBackgroundDeep.opacity(0.98)
        case .midGrey, .dark: return chartPanelBackgroundMuted.opacity(0.96)
        }
    }

    static var chartBottomControlBorder: Color {
        isLightGrey ? adaptiveOverlay28 : surfaceWhite14
    }

    static var chartBottomControlForeground: Color {
        isLightGrey ? primaryForeground.opacity(0.90) : surfaceWhite66
    }

    static var chartBottomControlActiveBackground: Color {
        isLightGrey ? adaptiveOverlay16 : surfaceWhite68
    }

    static var chartBottomControlActiveBorder: Color {
        isLightGrey ? adaptiveOverlay32 : surfaceWhite24
    }

    private static var adaptiveOverlay16: Color { overlayBase.opacity(0.16) }
    private static var adaptiveOverlay28: Color { overlayBase.opacity(0.28) }
    private static var adaptiveOverlay32: Color { overlayBase.opacity(0.32) }

    static var chartPanelBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 186.0 / 255, green: 189.0 / 255, blue: 198.0 / 255)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundMuted: Color {
        switch theme {
        case .lightGrey: return Color(red: 182.0 / 255, green: 185.0 / 255, blue: 194.0 / 255)
        case .midGrey:   return Color(red: 23.0 / 255, green: 27.0 / 255, blue: 38.0 / 255)
        case .dark:      return Color(red: 20.0 / 255, green: 20.0 / 255, blue: 26.0 / 255)
        }
    }
    static var chartPanelBackgroundInset: Color {
        switch theme {
        case .lightGrey: return Color(red: 176.0 / 255, green: 179.0 / 255, blue: 189.0 / 255)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 36.0 / 255)
        case .dark:      return Color(red: 18.0 / 255, green: 18.0 / 255, blue: 28.0 / 255)
        }
    }
    static var chartPanelBackgroundAlt: Color {
        switch theme {
        case .lightGrey: return Color(red: 194.0 / 255, green: 196.0 / 255, blue: 204.0 / 255)
        case .midGrey:   return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 42.0 / 255)
        case .dark:      return Color(red: 25.0 / 255, green: 25.0 / 255, blue: 33.0 / 255)
        }
    }
    static var chartPanelBackgroundDeep: Color {
        switch theme {
        case .lightGrey: return Color(red: 152.0 / 255, green: 155.0 / 255, blue: 168.0 / 255)
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
        case .lightGrey: return Color(red: 188.0 / 255, green: 191.0 / 255, blue: 200.0 / 255).opacity(0.97)
        case .midGrey:   return Color(red: 22.0 / 255, green: 26.0 / 255, blue: 38.0 / 255).opacity(0.94)
        case .dark:      return Color.black.opacity(0.85)
        }
    }

    /// Panel header background (indicator & timeframe panels). Subtle darker strip.
    static var panelHeaderBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 132.0 / 255, green: 136.0 / 255, blue: 150.0 / 255)
        case .midGrey:   return Color(red: 28.0 / 255, green: 32.0 / 255, blue: 44.0 / 255)
        case .dark:      return Color(red: 16.0 / 255, green: 16.0 / 255, blue: 22.0 / 255)
        }
    }

    /// X-axis bottom area background. Dark: pure black, MidGrey: very dark blue-grey, LightGrey: darker strip (readable vs plot wash).
    static var xAxisBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 108.0 / 255, green: 112.0 / 255, blue: 124.0 / 255)
        case .midGrey:   return Color(red: 14.0 / 255, green: 18.0 / 255, blue: 26.0 / 255)
        case .dark:      return Color.black
        }
    }

    // MARK: Chart overlay & panel chrome (theme audit 13–21)

    /// Chart OHLC / overlay info panels. Lighter than `panelHeaderBackground` on light grey.
    static var chartOverlayInfoPanelFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 200.0 / 255, green: 202.0 / 255, blue: 210.0 / 255).opacity(0.96)
        case .midGrey:   return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255).opacity(0.94)
        case .dark:      return surfaceBlack50.opacity(0.96)
        }
    }

    /// Indicator panel plot canvas — stronger separation from the main chart wash on light grey (audit 25).
    static var indicatorPanelPlotBackground: Color {
        switch theme {
        case .lightGrey: return chartPanelBackground
        case .midGrey, .dark: return chartPanelBackground
        }
    }

    /// Inner value row + legacy chrome: dark strip (timeframe LIVE row, indicator header row) — matches main x-axis field.
    static var indicatorPanelChromeStripBackground: Color { xAxisBackground }

    /// Indicator panel resize handle chrome.
    static var indicatorPanelHandleBackground: Color { panelHeaderBackground }

    /// Timeframe panel resize handle chrome.
    static var timeframePanelHandleBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 145.0 / 255, green: 149.0 / 255, blue: 163.0 / 255)
        case .midGrey: return panelHeaderBackground
        case .dark: return panelHeaderBackground
        }
    }

    /// Legacy shared pull tab strip. Prefer the panel-kind specific handle tokens above.
    static var chartPanelResizeStripBackground: Color { indicatorPanelHandleBackground }

    /// Solid strip behind timeframe live price / LIVE row (not the light blue x-axis area).
    static var timeframePanelPriceHeaderBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 82.0 / 255, green: 86.0 / 255, blue: 96.0 / 255)
        case .midGrey: return xAxisBackground
        case .dark: return Color.black
        }
    }

    /// Timeframe panel x-axis strip only (stacked chart footer — not the grey resize tab).
    /// Dark/mid: neutral grey chrome (audit 22); light grey: grey strip + blue frame lines (audit 24).
    static var timeframePanelAxisGradientTop: Color {
        switch theme {
        case .lightGrey:
            return Color(red: 208.0 / 255, green: 211.0 / 255, blue: 218.0 / 255)
        case .midGrey:
            return Color(red: 20.0 / 255, green: 24.0 / 255, blue: 34.0 / 255)
        case .dark:
            return Color(red: 22.0 / 255, green: 22.0 / 255, blue: 28.0 / 255)
        }
    }

    static var timeframePanelAxisGradientBottom: Color {
        switch theme {
        case .lightGrey:
            return Color(red: 190.0 / 255, green: 194.0 / 255, blue: 202.0 / 255)
        case .midGrey:
            return Color(red: 12.0 / 255, green: 15.0 / 255, blue: 22.0 / 255)
        case .dark:
            return Color(red: 8.0 / 255, green: 8.0 / 255, blue: 12.0 / 255)
        }
    }

    /// 1pt frame lines above/below the timeframe x-axis strip.
    static var timeframePanelAxisFrameBorder: Color {
        switch theme {
        case .lightGrey: return Color(red: 113.0 / 255, green: 118.0 / 255, blue: 129.0 / 255).opacity(0.92)
        case .midGrey: return AppColors.surfaceWhite20
        case .dark: return AppColors.surfaceWhite18
        }
    }

    /// Legacy hairline between chart plot and x-axis strip; kept for compatibility — prefer `timeframePanelAxisFrameBorder` for framing.
    static var timeframePanelAxisHairline: Color { timeframePanelAxisFrameBorder }

    /// Timeframe x-axis tick labels (blue tints on gradient strip).
    static var timeframePanelAxisLabelPrimary: Color {
        switch theme {
        case .lightGrey: return Color(red: 23.0 / 255, green: 77.0 / 255, blue: 138.0 / 255)
        case .midGrey, .dark: return AppColors.statusInfo92
        }
    }

    static var timeframePanelAxisLabelSecondary: Color {
        switch theme {
        case .lightGrey: return Color(red: 40.0 / 255, green: 92.0 / 255, blue: 153.0 / 255).opacity(0.88)
        case .midGrey, .dark: return AppColors.statusInfo75
        }
    }

    /// Shared y-axis lane chrome for timeframe and indicator panels.
    static var panelYAxisLaneBackground: Color {
        switch theme {
        case .lightGrey: return Color(red: 198.0 / 255, green: 201.0 / 255, blue: 209.0 / 255).opacity(0.98)
        case .midGrey: return Color(red: 24.0 / 255, green: 28.0 / 255, blue: 40.0 / 255).opacity(0.96)
        case .dark: return Color(red: 11.0 / 255, green: 11.0 / 255, blue: 16.0 / 255).opacity(0.95)
        }
    }

    static var panelYAxisLaneText: Color {
        isLightGrey ? primaryForeground.opacity(0.92) : surfaceWhite66
    }

    static var panelMiniInfoOverlayFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 214.0 / 255, green: 217.0 / 255, blue: 223.0 / 255).opacity(0.98)
        case .midGrey: return Color(red: 26.0 / 255, green: 30.0 / 255, blue: 43.0 / 255).opacity(0.97)
        case .dark: return Color(red: 13.0 / 255, green: 13.0 / 255, blue: 18.0 / 255).opacity(0.96)
        }
    }

    static var panelMiniInfoOverlayStroke: Color {
        switch theme {
        case .lightGrey: return primaryForeground.opacity(0.18)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    static var panelMiniInfoOverlayPrimaryText: Color {
        isLightGrey ? primaryForeground.opacity(0.96) : surfaceWhite92
    }

    static var panelMiniInfoOverlaySecondaryText: Color {
        isLightGrey ? secondaryForeground.opacity(0.92) : surfaceWhite68
    }

    /// Primary title on panel resize bars — ink on mid-grey header strip (chat list row tone).
    static var panelResizeHandlePrimaryLabel: Color {
        primaryForeground
    }

    /// Suffix label (“Indicator”) on indicator resize bars.
    static var panelResizeHandleIndicatorSuffixForeground: Color {
        isLightGrey ? Color.white.opacity(0.96) : surfaceWhite80
    }

    /// Suffix label (“Timeframe”) on timeframe resize bars.
    static var panelResizeHandleTimeframeSuffixForeground: Color {
        isLightGrey ? Color.white.opacity(0.82) : surfaceWhite68
    }

    /// Chevron on panel resize bars when collapsed.
    static var panelResizeHandleChevronForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.88) : surfaceWhite80
    }

    /// Center “pull” capsule on panel resize bars (light grey: white nub on darker strip).
    static var panelResizeHandleCapsuleIdle: Color {
        isLightGrey ? Color.white : surfaceGray50
    }

    static var panelResizeHandleCapsuleDragging: Color {
        isLightGrey ? Color(white: 0.94) : surfaceWhite80
    }

    /// Primary label in `IndicatorPanelHeaderRow` (title text).
    static var indicatorPanelHeaderTitle: Color {
        isLightGrey ? Color.white.opacity(0.95) : surfaceWhite80
    }

    /// Live / snapshot price tint on timeframe header strip.
    static var timeframePanelHeaderValueForeground: Color {
        isLightGrey ? Color.white.opacity(0.96) : .white
    }

    /// Section icon in marker components placement cards (light grey: ink, not white).
    static var componentsSectionHeaderIconForeground: Color {
        isLightGrey ? secondaryForeground : surfaceWhite88
    }

    /// Components scaffold / overview neutral gradient end (replaces low-contrast white wash on light grey).
    static var componentsScaffoldHeaderNeutralEndpoint: Color {
        isLightGrey ? primaryForeground.opacity(0.14) : whiteText.opacity(0.06)
    }

    static var componentsScaffoldHeaderLeadingOpacity: Double {
        isLightGrey ? 0.50 : 0.22
    }

    static var componentsScaffoldHeaderMidOpacity: Double {
        isLightGrey ? 0.30 : 0.12
    }

    /// Overview / row / section fills for components UI (light grey: ink-tinted; audit 33 — stronger).
    static var componentsOverviewChipFill: Color {
        isLightGrey ? primaryForeground.opacity(0.26) : whiteText.opacity(0.08)
    }

    static var componentsOverviewChipStroke: Color {
        isLightGrey ? primaryForeground.opacity(0.32) : whiteText.opacity(0.09)
    }

    static var componentsRowCardFill: Color {
        isLightGrey ? primaryForeground.opacity(0.12) : whiteText.opacity(0.07)
    }

    static var componentsRowCardStroke: Color {
        isLightGrey ? primaryForeground.opacity(0.16) : whiteText.opacity(0.08)
    }

    static var componentsSectionCardFill: Color {
        isLightGrey ? primaryForeground.opacity(0.10) : whiteText.opacity(0.05)
    }

    static var componentsSectionCardStroke: Color {
        isLightGrey ? primaryForeground.opacity(0.15) : whiteText.opacity(0.08)
    }

    static var componentsMirrorButtonFill: Color {
        isLightGrey ? primaryForeground.opacity(0.12) : whiteText.opacity(0.08)
    }

    static var componentsMirrorButtonStroke: Color {
        isLightGrey ? primaryForeground.opacity(0.18) : whiteText.opacity(0.1)
    }

    /// Disclosure row icons (leading) — light grey: secondary ink.
    static var disclosureHeaderIconForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.92) : surfaceWhite74
    }

    /// Chat composer attachment action sheet (light grey: slightly more see-through vs content behind).
    static var chatAttachmentActionPanelFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 246.0 / 255, green: 247.0 / 255, blue: 249.0 / 255).opacity(0.94)
        case .midGrey, .dark: return panelFillEmphasis
        }
    }

    static var chatAttachmentActionPanelStroke: Color {
        switch theme {
        case .lightGrey: return standardSearchFieldStroke.opacity(0.95)
        case .midGrey, .dark: return standardSearchFieldStroke.opacity(0.8)
        }
    }

    /// Icons on chat attachment sheet (light grey: ink on pale sheet).
    static var chatAttachmentActionIconForeground: Color {
        isLightGrey ? primaryForeground : surfaceWhite92
    }

    static var chatAttachmentActionLabelForeground: Color {
        isLightGrey ? primaryForeground.opacity(0.92) : surfaceWhite80
    }

    static var chatAttachmentIconWellFill: Color {
        isLightGrey ? primaryForeground.opacity(0.12) : surfaceWhite14
    }

    static var chatAttachmentIconWellStroke: Color {
        isLightGrey ? primaryForeground.opacity(0.20) : surfaceWhite24
    }

    /// Expanded marker visibility panel above chart x-axis (mid/light: align with overlay chrome; dark: high contrast).
    static var markerFilterExpandedPanelBackground: Color {
        switch theme {
        case .lightGrey: return panelHeaderBackground.opacity(0.98)
        case .midGrey:   return panelHeaderBackground.opacity(0.98)
        case .dark:      return surfaceBlack50
        }
    }

    /// Secondary control well inside marker filter panel (e.g. Intents button).
    static var markerFilterPanelControlWell: Color {
        switch theme {
        case .lightGrey: return adaptiveOverlay12
        case .midGrey:   return adaptiveOverlay12
        case .dark:      return surfaceWhite12
        }
    }

    /// Primary label on medium-dark chart overlay strips (`markerFilterExpandedPanelBackground`). Not `whiteText` (that is dark ink in lightGrey app chrome).
    static var chartOverlayStripLabel: Color {
        Color.white.opacity(0.92)
    }

    static var signupInterestBlue: Color {
        isLightGrey ? LightGreyPalette.infoBlueAnchor : Color(red: 0.4, green: 0.7, blue: 0.9)
    }
    /// Tutorial / onboarding greens — saturated on dark themes; canonical green on light grey (audit 32).
    static var signupInterestGreen: Color {
        switch theme {
        case .lightGrey: return themeAwareGreen
        case .midGrey, .dark: return Color(red: 0.5, green: 0.8, blue: 0.5)
        }
    }

    static var signupInterestPurple: Color {
        isLightGrey ? LightGreyPalette.secondaryPurpleAnchor : Color(red: 0.7, green: 0.6, blue: 0.9)
    }

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
        isLightGrey ? Color(red: 184.0 / 255, green: 187.0 / 255, blue: 196.0 / 255)
                    : Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 37.0 / 255.0)
    }
    static var markerNeutralFillBottom: Color {
        isLightGrey ? Color(red: 132.0 / 255, green: 136.0 / 255, blue: 150.0 / 255)
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

    /// Subtitle / secondary line on `OverlayPanelChrome` panels (chart info, marker viewing).
    static var overlayPanelSecondaryText: Color {
        isLightGrey ? secondaryForeground : surfaceWhite74
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

    /// Marker placement bar pills on main chart (lightGrey: darker grey chrome vs plot; audit 30).
    static var placementBarSelectedFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 152.0 / 255, green: 156.0 / 255, blue: 170.0 / 255)
        case .midGrey, .dark: return tgGradientBackground
        }
    }

    static var placementBarUnselectedFill: Color {
        switch theme {
        case .lightGrey: return Color(red: 140.0 / 255, green: 144.0 / 255, blue: 158.0 / 255)
        case .midGrey, .dark: return tgGradientBackgroundMid.opacity(0.9)
        }
    }

    static var placementBarSelectedForeground: Color {
        isLightGrey ? primaryForeground : .white
    }

    static var placementBarUnselectedForeground: Color {
        isLightGrey ? tgMidGrey : tgWhiteText.opacity(0.8)
    }

    /// Chart sheet standard tab row (symbol / chat / components). LightGrey: same soft chrome as placement bar; dark/mid: legacy gradients.
    static var chartSheetMainTabSelectedBackground: Color {
        switch theme {
        case .lightGrey: return placementBarSelectedFill
        case .midGrey, .dark: return gradientBackgroundDark
        }
    }

    static var chartSheetMainTabUnselectedBackground: Color {
        switch theme {
        case .lightGrey: return placementBarUnselectedFill
        case .midGrey, .dark: return gradientBackgroundMid.opacity(0.9)
        }
    }

    static var chartSheetMainTabSelectedForeground: Color { placementBarSelectedForeground }

    static var chartSheetMainTabUnselectedForeground: Color { placementBarUnselectedForeground }

    /// Markers tab (inverted on dark/mid). LightGrey: matches other tabs’ soft chrome.
    static var chartSheetMarkersTabSelectedBackground: Color {
        isLightGrey ? placementBarSelectedFill : whiteText
    }

    static var chartSheetMarkersTabUnselectedBackground: Color {
        isLightGrey ? placementBarUnselectedFill : whiteText.opacity(0.5)
    }

    static var chartSheetMarkersTabSelectedForeground: Color {
        isLightGrey ? primaryForeground : gradientBackgroundDark
    }

    static var chartSheetMarkersTabUnselectedForeground: Color {
        isLightGrey ? placementBarUnselectedForeground : gradientBackgroundDark.opacity(0.8)
    }

    /// Canvas marker blob fill. Dark/MidGrey: near-black; LightGrey: softened mid-grey so marker chrome doesn't feel too heavy.
    static var canvasMarkerFill: Color {
        isLightGrey
            ? Color(red: 136.0 / 255, green: 140.0 / 255, blue: 150.0 / 255).opacity(0.90)
            : Color(white: 0.11).opacity(0.94)
    }

    /// Canvas marker drop shadow. Dark/MidGrey: black 25% (current), LightGrey: black 10%.
    static var canvasMarkerShadow: Color {
        isLightGrey ? Color.black.opacity(0.10)
                    : Color.black.opacity(0.25)
    }

    /// Extra tint over non-alert markers so lightGrey markers feel softer without losing contrast.
    static var canvasMarkerNeutralTint: Color {
        isLightGrey ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
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
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return Color.white.opacity(0.10)
        }
    }

    static var messagingListRowFillPressed: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.14)
        case .midGrey, .dark: return Color.white.opacity(0.14)
        }
    }

    /// Guild user list row. Dark/Mid: white 3% / 6% pressed.
    static var userListRowFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return Color.white.opacity(0.09)
        }
    }

    static var userListRowFillPressed: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.13)
        case .midGrey, .dark: return Color.white.opacity(0.12)
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
        case .lightGrey: return tgWhiteText.opacity(0.18)
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    /// Unselected timeframe chip gradient. Dark/Mid: surfaceWhite10→05.
    static var timeframeChipUnselectedLeading: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.14)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    static var timeframeChipUnselectedTrailing: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.08)
        case .midGrey, .dark: return surfaceWhite05
        }
    }

    /// Marker list capsule. Dark/Mid: surfaceWhite04 / surfaceWhite08 stroke.
    static var markerListCapsuleFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.09)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    static var markerListCapsuleStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.13)
        case .midGrey, .dark: return surfaceWhite18
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
        isLightGrey ? tgWhiteText.opacity(0.12) : surfaceWhite08
    }

    /// Symbol list row unselected gradient. Dark/Mid: surfaceWhite05→03.
    static var symbolListRowUnselectedLeading: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.17)
        case .midGrey, .dark: return surfaceWhite05
        }
    }

    static var symbolListRowUnselectedTrailing: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return surfaceWhite03
        }
    }

    /// Symbol sheet hero — light → dark system blue (not symbol grey/secondary mix).
    static var symbolSheetHeroBlueGradientLeading: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.symbolHeroLeading
        case .midGrey:
            return Color(red: 58.0 / 255, green: 92.0 / 255, blue: 142.0 / 255)
        case .dark:
            return Color(red: 44.0 / 255, green: 72.0 / 255, blue: 118.0 / 255)
        }
    }

    static var symbolSheetHeroBlueGradientTrailing: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.symbolHeroTrailing
        case .midGrey:
            return Color(red: 28.0 / 255, green: 52.0 / 255, blue: 96.0 / 255)
        case .dark:
            return Color(red: 22.0 / 255, green: 40.0 / 255, blue: 76.0 / 255)
        }
    }

    static var symbolSheetHeroBlueStroke: Color {
        switch theme {
        case .lightGrey: return AppColors.statusInfo50
        case .midGrey, .dark: return AppColors.statusInfo60
        }
    }

    /// Selected watchlist row — same light→dark blue language, slightly deeper than hero.
    static var symbolListRowSelectedBlueGradientLeading: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.symbolRowSelectedLeading
        case .midGrey:
            return Color(red: 50.0 / 255, green: 82.0 / 255, blue: 132.0 / 255)
        case .dark:
            return Color(red: 40.0 / 255, green: 66.0 / 255, blue: 108.0 / 255)
        }
    }

    static var symbolListRowSelectedBlueGradientTrailing: Color {
        switch theme {
        case .lightGrey:
            return LightGreyPalette.symbolRowSelectedTrailing
        case .midGrey:
            return Color(red: 24.0 / 255, green: 46.0 / 255, blue: 88.0 / 255)
        case .dark:
            return Color(red: 18.0 / 255, green: 36.0 / 255, blue: 72.0 / 255)
        }
    }

    static var symbolListRowSelectedBlueStroke: Color {
        switch theme {
        case .lightGrey: return AppColors.statusInfo55
        case .midGrey, .dark: return AppColors.statusInfo65
        }
    }

    /// Foreground text rendered directly on any blue gradient surface (hero card, selected list row).
    /// Always white regardless of theme — the blue gradient supplies sufficient contrast.
    static var onSymbolBlueBackground: Color { Color.white }

    /// Muted companion for secondary / tertiary text on blue gradient surfaces.
    static var onSymbolBlueBackgroundMuted: Color { Color.white.opacity(0.78) }

    /// Status badge on symbol list rows (global list).
    static var symbolRowBadgeForeground: Color {
        isLightGrey ? primaryForeground : surfaceWhite90
    }

    static var symbolRowBadgeBackground: Color {
        isLightGrey ? tgWhiteText.opacity(0.12) : surfaceWhite14
    }

    /// Symbol details expanded card. Dark/Mid: surfaceWhite08 fill / surfaceWhite12 stroke.
    static var symbolDetailCardFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.13)
        case .midGrey, .dark: return surfaceWhite16
        }
    }

    static var symbolDetailCardStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.22)
        case .midGrey, .dark: return surfaceWhite24
        }
    }

    /// Symbol details disclosure header capsule. Light grey: darker than search bar so it reads on white sheet.
    static var symbolDetailsHeaderGradientLeading: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.22)
        case .midGrey, .dark: return searchBarGradientLeading
        }
    }

    static var symbolDetailsHeaderGradientTrailing: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.12)
        case .midGrey, .dark: return searchBarGradientTrailing
        }
    }

    // MARK: Admin sheet footer (light grey: cancel = filled dark, primary = light pill)

    static var adminFooterCancelForeground: Color {
        isLightGrey ? Color.white.opacity(0.96) : greyText
    }

    static var adminFooterCancelBackground: Color {
        isLightGrey ? primaryForeground.opacity(0.88) : surfaceWhite06
    }

    static var adminFooterPrimaryForeground: Color {
        isLightGrey ? primaryForeground : Color.black
    }

    static var adminFooterPrimaryBackground: Color {
        isLightGrey ? Color.white : whiteText
    }

    /// Chevrons / secondary chrome on sheet headers. Dark/Mid: white 50%; Light: mid grey.
    static var adaptiveAccessoryForeground: Color {
        isLightGrey ? tgMidGrey : Color.white.opacity(0.5)
    }

    /// Count/meta text on disclosure headers and compact chrome.
    static var disclosureMetaForeground: Color {
        isLightGrey ? secondaryForeground : surfaceWhite50
    }

    static var disclosureChevronForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.82) : surfaceWhite50
    }

    /// Selected label on shared capsule tabs.
    static var tabPillSelectedLabel: Color {
        isLightGrey ? primaryForeground : .white
    }

    /// Primary/secondary text for list rows that sit on adaptive light surfaces in lightGrey.
    static var listRowPrimaryForeground: Color {
        isLightGrey ? primaryForeground : whiteText
    }

    static var listRowSecondaryForeground: Color {
        isLightGrey ? secondaryForeground : whiteText.opacity(0.6)
    }

    static var listRowTertiaryForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.88) : whiteText.opacity(0.5)
    }

    static var listRowChevronForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.65) : whiteText.opacity(0.3)
    }

    /// Drawer headers sit on the same pale chrome as other lightGrey surfaces.
    static var drawerHeaderPrimaryForeground: Color {
        isLightGrey ? primaryForeground : whiteText
    }

    static var drawerHeaderSecondaryForeground: Color {
        isLightGrey ? secondaryForeground : whiteText.opacity(0.7)
    }

    static var drawerSectionTitleForeground: Color {
        isLightGrey ? primaryForeground.opacity(0.96) : whiteText.opacity(0.95)
    }

    static var drawerSectionDismissForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.9) : whiteText.opacity(0.8)
    }

    /// Text/icons that sit inside symbol detail cards and similar pale surfaces.
    static var surfaceDetailPrimaryForeground: Color {
        isLightGrey ? primaryForeground : surfaceWhite92
    }

    static var surfaceDetailSecondaryForeground: Color {
        isLightGrey ? secondaryForeground : surfaceWhite70
    }

    static var surfaceDetailTertiaryForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.9) : surfaceWhite65
    }

    static var surfaceDetailQuaternaryForeground: Color {
        isLightGrey ? secondaryForeground.opacity(0.78) : surfaceWhite50
    }

    // MARK: - Chat background overlays & pattern strength

    static var chatBackgroundOverlayStandardStart: Color {
        switch theme {
        case .lightGrey: return Color.black.opacity(0.03)
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

    /// Target opacity for the chat message-area pattern. Use a direct value rather than multiplying the inline pattern twice.
    static var chatBackgroundPatternMultiplyStandard: Double { isLightGrey ? 0.026 : 0.020 }
    static var chatBackgroundPatternMultiplyElevated: Double { isLightGrey ? 0.036 : 0.028 }

    /// Scales `StaticPatternView` in guild discover/switch/create flows (lightGrey only).
    static var guildFlowPatternOpacityScale: Double { isLightGrey ? 0.18 : 1.0 }

    /// Selected row highlight on guild switch list (accent fill/stroke opacity; audit 31 — stronger on light grey).
    static var guildSwitchRowSelectedFillOpacity: Double { isLightGrey ? 0.38 : 0.16 }
    static var guildSwitchRowSelectedStrokeOpacity: Double { isLightGrey ? 0.58 : 0.38 }

    /// Guild statistics cards — darker chrome on light grey (audit 26).
    static var guildStatisticsCardBackground: Color {
        isLightGrey ? tgWhiteText.opacity(0.22) : surfaceWhite06
    }

    static var guildStatisticsCardStroke: Color {
        isLightGrey ? tgWhiteText.opacity(0.32) : surfaceWhite10
    }

    /// Metric accents on statistics rows (audit 27 — readable on pale backgrounds).
    static var statisticsMetricGreen: Color { statusPositive }
    static var statisticsMetricYellow: Color { themeAwareYellow }
    static var statisticsMetricOrange: Color { themeAwareOrange }
    static var statisticsMetricMint: Color {
        isLightGrey ? LightGreyPalette.tealAnchor : systemMint
    }

    /// Personal watchlist star in symbol sheet (audit 29).
    static var symbolDetailPersonalStarActive: Color {
        isLightGrey ? LightGreyPalette.highlightYellowAnchor : systemYellow
    }

    /// Tutorial step accents — saturated on dark; deeper on light grey (audit 32).
    static var tutorialAccentOrange: Color {
        isLightGrey ? LightGreyPalette.warningOrangeAnchor : Color(red: 1.0, green: 0.58, blue: 0.0)
    }
    static var tutorialAccentYellow: Color {
        isLightGrey ? LightGreyPalette.highlightYellowAnchor : Color(red: 1.0, green: 0.84, blue: 0.0)
    }
    static var tutorialAccentPurple: Color {
        isLightGrey ? LightGreyPalette.secondaryPurpleAnchor : systemPurple
    }
    static var tutorialAccentCyan: Color {
        isLightGrey ? LightGreyPalette.accentCyanAnchor : systemCyan
    }

    /// Marker viewing “Components” tab section tints — deeper on light grey (audit 33).
    static var markerViewingTintIndicator: Color {
        isLightGrey ? LightGreyPalette.warningOrangeAnchor : Color(red: 245.0 / 255, green: 158.0 / 255, blue: 11.0 / 255)
    }
    static var markerViewingTintIndicatorPanel: Color {
        isLightGrey ? LightGreyPalette.warningOrangeAnchor : Color(red: 249.0 / 255, green: 115.0 / 255, blue: 22.0 / 255)
    }
    static var markerViewingTintIndicatorOverlay: Color {
        isLightGrey ? LightGreyPalette.accentCyanAnchor : Color(red: 14.0 / 255, green: 165.0 / 255, blue: 233.0 / 255)
    }
    static var markerViewingTintDrawing: Color {
        isLightGrey ? LightGreyPalette.tealAnchor : Color(red: 20.0 / 255, green: 184.0 / 255, blue: 166.0 / 255)
    }
    static var markerViewingTintTimeframe: Color {
        isLightGrey ? LightGreyPalette.navBlueRampDeepEnd : Color(red: 56.0 / 255, green: 189.0 / 255, blue: 248.0 / 255)
    }
    static var markerViewingTintPrimaryStar: Color {
        isLightGrey ? LightGreyPalette.highlightYellowAnchor : Color(red: 251.0 / 255, green: 191.0 / 255, blue: 36.0 / 255)
    }

    /// Discover-style search field (capsule fill + stroke). Light uses explicit fill; dark/mid keep gradient-leading as flat fallback.
    static var standardSearchFieldFill: Color {
        isLightGrey ? tgWhiteText.opacity(0.12) : surfaceWhite16
    }

    static var standardSearchFieldStroke: Color {
        isLightGrey ? tgWhiteText.opacity(0.26) : surfaceWhite24
    }

    static var standardSearchFieldAccessory: Color {
        isLightGrey ? tgMidGrey : surfaceWhite50
    }

    // MARK: - Light grey adaptive drawer / form chrome (palette §41)

    /// Footer neutral actions (Switch Guild, Create Guild, etc.).
    static var drawerNeutralActionButtonFill: Color {
        isLightGrey ? standardSearchFieldFill : whiteText.opacity(0.8)
    }

    static var drawerNeutralActionButtonForeground: Color {
        isLightGrey ? primaryForeground : systemBlack
    }

    static var drawerNeutralActionButtonStroke: Color {
        isLightGrey ? standardSearchFieldStroke : systemBlack
    }

    /// Discover / filter search row backgrounds.
    static var adaptiveChromeSearchFieldFill: Color {
        isLightGrey ? standardSearchFieldFill : unhighlightedTextBoxBackground.opacity(0.92)
    }

    static var adaptiveChromeSearchFieldStroke: Color {
        isLightGrey ? standardSearchFieldStroke : whiteText.opacity(0.2)
    }

    /// Dropdown / form control wells (create guild, etc.).
    static var adaptiveFormControlFill: Color {
        isLightGrey ? standardSearchFieldFill : unhighlightedTextBoxBackground.opacity(0.88)
    }

    static var adaptiveFormControlStroke: Color {
        isLightGrey ? standardSearchFieldStroke : whiteText.opacity(0.15)
    }

    /// Magnifyingglass / accessory on unified search: light grey uses search-field ink; dark/mid use panel white.
    static var adaptiveSearchAccessoryForeground: Color {
        isLightGrey ? standardSearchFieldAccessory : surfaceWhite50
    }

    /// Unselected capsule tabs (UnifiedTabButton / UnifiedCategoryTabButton).
    static var tabPillUnselectedGradientLeading: Color {
        isLightGrey ? tgWhiteText.opacity(0.16) : subtleSurfaceOverlay08
    }

    static var tabPillUnselectedGradientTrailing: Color {
        isLightGrey ? tgWhiteText.opacity(0.10) : subtleSurfaceOverlay04
    }

    static var tabPillUnselectedLabel: Color {
        isLightGrey ? tgGrey : Color.gray
    }

    /// Target opacity for honeycomb fade-in (inline pattern only).
    static var inlineHoneycombPatternOpacity: Double { isLightGrey ? 0.055 : 0.02 }

    /// `StaticMessagingBackgroundView` honeycomb fade-in target.
    static var messagingSheetHoneycombPatternOpacity: Double { isLightGrey ? 0.032 : 0.02 }

    /// Main chart root honeycomb (light theme only branch uses this).
    static let chartLightGreyHoneycombOpacity: Double = 0.018

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
        case .lightGrey: return tgWhiteText.opacity(0.11)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    /// Stronger flat panel (was surfaceWhite10).
    static var panelFillEmphasis: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.18)
        case .midGrey, .dark: return surfaceWhite18
        }
    }

    /// Stroke for attachment-draft rows in chat (was surfaceWhite10).
    static var linkedMarkerAttachmentStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.16)
        case .midGrey, .dark: return surfaceWhite10
        }
    }

    /// Intent picker pills on marker detail (was systemWhite 5% / 11%).
    static var intentPickerPillFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.08)
        case .midGrey, .dark: return Color.white.opacity(0.05)
        }
    }

    static var intentPickerPillFillSelected: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.13)
        case .midGrey, .dark: return Color.white.opacity(0.11)
        }
    }

    /// Drawing line-style picker on chart (surfaceWhite04 / surfaceWhite12 selected).
    static var drawingStyleSwatchFill: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.09)
        case .midGrey, .dark: return surfaceWhite04
        }
    }

    static var drawingStyleSwatchFillSelected: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.16)
        case .midGrey, .dark: return surfaceWhite12
        }
    }

    static var drawingStyleSwatchStroke: Color {
        switch theme {
        case .lightGrey: return tgWhiteText.opacity(0.20)
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
            if isUnread { return tgWhiteText.opacity(isPressed ? 0.15 : 0.12) }
            return tgWhiteText.opacity(isPressed ? 0.12 : 0.09)
        case .midGrey, .dark:
            if isUnread { return Color.white.opacity(isPressed ? 0.10 : 0.08) }
            return Color.white.opacity(isPressed ? 0.06 : 0.03)
        }
    }

    /// `UnifiedLeaderboardRow` background (was systemWhite by rank/press).
    static func leaderboardRowFill(isTopRank: Bool, isPressed: Bool) -> Color {
        switch theme {
        case .lightGrey:
            let base = isTopRank ? (isPressed ? 0.14 : 0.11) : (isPressed ? 0.12 : 0.09)
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
    /// Backward-compatible accent. Computed so it picks up the theme-aware `tgAccent` on lightGrey.
    static var accentColor: Color { tgAccent }
    static let accentDarkColor = tgAccentDark
    /// Backward-compatible friend accent. Computed so it picks up the theme-aware `tgFriend` on lightGrey.
    static var friendAccent: Color { tgFriend }
    static let bullCandleGreen = tgBull
    static let bearCandleRed = tgBear

    static var unhighlightedTextBoxBackground: Color { tgButtonSearchBackground }
    static var unhighlightedButtonBackground: Color { tgUnhighlightedWhite }
    static var fadedBackground: Color { tgFadedBackground }
    static let chartLogo = tgChartLogo
}
