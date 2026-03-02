//
//  Color+Theme.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

enum AppColors {
    static let gradientBackgroundDark = Color("TGGradientBackground") // #00000E
    static let gradientBackgroundLight = Color("TGGradientBackgroundLight") // #000127
    static let unhighlightedButtonBackground = Color("TGUnhighlightedWhite") // #C3C3C3
    static let whiteText = Color("TGWhiteText") // #ECECEC
    static let unhighlightedTextBoxBackground = Color("TGButtonSearchBackground") // #191921
    static let fadedBackground = Color("TGFadedBackground") // #2F303A
    static let greyText = Color("TGMidGrey") // #7A7878
    static let accentColor = Color("TGAccent") //#0F9EB4
    static let accentDarkColor = Color("TGAccentDark") //026675
    static let bullCandleGreen = Color("TGBull") //0E854D
    static let bearCandleRed = Color("TGBear") //820808
    static let gradientBackgroundMid = Color("TGGradientBackgroundMid") //#101018
    static let toolbarBackground = Color("TGToolbarBackground") //#00000E
    static let drawerBackground = Color("TGDrawerBackground")
    
    static let sheetBackground = Color("TGSheetBackground")
    static let sheetBackgroundDark = Color("TGSheetBackgroundDark")
    
    static let friendAccent = Color("TGFriend")

    // Shared marker-like token colors (chart badges + marker hearts across surfaces)
    static let markerHeartTint = Color(red: 0.88, green: 0.24, blue: 0.28)
    static let markerHeartMuted = markerHeartTint.opacity(0.55)
    static let markerHeartBadge = markerHeartTint.opacity(0.92)
    static let markerHeartBackground = markerHeartTint.opacity(0.22)
    static let markerHeartBorder = markerHeartTint.opacity(0.42)
    
    // Marker shell tokens (weather-app–inspired neutral look)
    static let markerShellBorderLight = Color(white: 0.72)
    static let markerShellBorderDark = Color(white: 0.22)
    static let markerShellFillLight = Color(white: 0.92)
    static let markerShellFillDark = Color(white: 0.18)
    static let markerIconOnDark = Color(white: 0.95)
    static let markerIconOnLight = Color(white: 0.12)
    static let markerSelectedBorder = Color(white: 0.5)
    static let markerSelectedBorderWidth: CGFloat = 3.0
    static let markerUnselectedBorderWidth: CGFloat = 1.8
    /// Light grey icon for all markers (prediction-style)
    static let markerIconLight = Color(white: 0.72)
    /// Darker grey border for all markers
    static let markerBorderGrey = Color(white: 0.20)
}
