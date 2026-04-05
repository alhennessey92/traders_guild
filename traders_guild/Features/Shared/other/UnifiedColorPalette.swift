//
//  UnifiedColorPalette.swift
//  traders_guild
//
//  Comprehensive color palette for unified components across the app.
//  Add these colors to your existing color definitions or AppColors.
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - UNIFIED COLOR PALETTE
// MARK: - ================================================================================================

/// All colors used in UnifiedComponents and related views
struct UnifiedColors {
    
    // MARK: - Tab Gradient Colors (Primary - Used Across All Tabs)
    
    /// Primary blue gradient start color
    /// Hex: #3366CC | RGB: (51, 102, 204)
    static let tabGradientStart = AppColors.chartTabGradientStart
    
    /// Primary blue gradient end color
    /// Hex: #263F80 | RGB: (38, 63, 128)
    static let tabGradientEnd = AppColors.chartTabGradientEnd
    
    /// Standard blue gradient for all selected tabs
    static var tabSelectedGradient: LinearGradient {
        LinearGradient(
            colors: [tabGradientStart, tabGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Unselected tab background gradient
    static var tabUnselectedGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.subtleSurfaceOverlay08, AppColors.subtleSurfaceOverlay04],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Tab Border Colors
    
    /// Border color for selected tabs
    static let tabSelectedBorder = AppColors.statusInfo40
    
    // MARK: - Asset Class Colors (for Disclosure Groups & Categories)
    
    /// Forex - Blue
    static let assetClassForex = AppColors.statusInfo
    
    /// Crypto - Orange
    static let assetClassCrypto = AppColors.statusWarning
    
    /// Stocks - Green
    static let assetClassStocks = AppColors.statusPositive
    
    /// Commodities - Yellow
    static let assetClassCommodities = AppColors.systemYellow
    
    /// Indices - Purple
    static let assetClassIndices = AppColors.systemPurple
    
    /// Futures - Cyan
    static let assetClassFutures = AppColors.systemCyan
    
    // MARK: - Indicator Add Button Colors
    
    /// EMA indicator button color - Cyan
    static let indicatorEMA = AppColors.systemCyan
    
    /// SMA indicator button color - Orange
    static let indicatorSMA = AppColors.statusWarning
    
    /// RSI indicator color - Purple
    static let indicatorRSI = AppColors.systemPurple
    
    /// MACD indicator color - Green
    static let indicatorMACD = AppColors.statusPositive
    
    /// Bollinger Bands indicator color - Yellow
    static let indicatorBollinger = AppColors.systemYellow
    
    /// ATR indicator color - Red
    static let indicatorATR = AppColors.statusNegative
    
    // MARK: - Watchlist Action Button Colors
    
    /// Personal watchlist star color (filled)
    static let personalWatchlistActive = AppColors.systemYellow
    
    /// Personal watchlist star color (unfilled)
    static let personalWatchlistInactive = AppColors.systemGray
    
    /// Guild watchlist icon color (filled)
    static let guildWatchlistActive = AppColors.statusInfo
    
    /// Guild watchlist icon color (unfilled)
    static let guildWatchlistInactive = AppColors.systemGray
    
    // MARK: - Price Change Colors
    
    /// Price up / positive change
    static let priceUp = AppColors.statusPositive
    
    /// Price down / negative change
    static let priceDown = AppColors.statusNegative
    
    // MARK: - Background Colors & Opacities
    
    /// Card/row background
    static var cardBackground: Color { AppColors.symbolSheetGroupedPanelFill }
    
    /// Selected/highlighted card background
    static let cardBackgroundSelected = AppColors.statusInfo20
    
    /// Success/just selected feedback background
    static let cardBackgroundSuccess = AppColors.statusPositive20
    
    /// Subtle border color
    static let subtleBorder = AppColors.surfaceWhite15
    
    /// Selected item border
    static let selectedBorder = AppColors.statusInfo40
    
    // MARK: - Text Colors
    
    /// Primary text - White
    static let textPrimary = AppColors.systemWhite
    
    /// Secondary text - Gray
    static let textSecondary = AppColors.systemGray
    
    /// Tertiary/hint text
    static let textTertiary = AppColors.surfaceGray70
    
    /// Placeholder/empty state text
    static let textPlaceholder = AppColors.surfaceGray50
    
    // MARK: - Disclosure Group Colors
    
    /// Disclosure header background (collapsed)
    static var disclosureHeaderBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.subtleSurfaceOverlay08, AppColors.subtleSurfaceOverlay04],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Disclosure content background
    static var disclosureContentBackground: Color { AppColors.insetPanelBackground }
    
    /// Disclosure count badge background
    static let disclosureCountBadge = AppColors.surfaceWhite15
    
    // MARK: - Search Bar Colors
    
    /// Search bar background
    static var searchBarBackground: Color { AppColors.symbolDetailCardFill }
    
    /// Search bar border
    static var searchBarBorder: Color { AppColors.panelFillEmphasis }
    
    /// Search bar focused border
    static let searchBarFocusedBorder = AppColors.statusInfo50
    
    // MARK: - Empty State Colors
    
    /// Empty state icon color
    static let emptyStateIcon = AppColors.surfaceGray50
    
    /// Empty state title color
    static let emptyStateTitle = AppColors.systemGray
    
    /// Empty state subtitle color
    static let emptyStateSubtitle = AppColors.surfaceGray70
}

// MARK: - ================================================================================================
// NOTE: Color(hex:) extension is defined in ChartDTOs.swift - do not duplicate here
// MARK: - ================================================================================================
// MARK: - QUICK REFERENCE: HEX VALUES
// MARK: - ================================================================================================

/*
 
 TAB GRADIENTS:
 - Tab Selected Start:     #3366CC  (51, 102, 204)
 - Tab Selected End:       #263F80  (38, 63, 128)
 
 ASSET CLASS COLORS (System Colors):
 - Forex:       .blue
 - Crypto:      .orange
 - Stocks:      .green
 - Commodities: .yellow
 - Indices:     .purple
 - Futures:     .cyan
 
 INDICATOR COLORS (System Colors):
 - EMA:         .cyan
 - SMA:         .orange
 - RSI:         .purple
 - MACD:        .green
 - Bollinger:   .yellow
 - ATR:         .red
 
 WATCHLIST ACTIONS:
 - Personal Star (active):   .yellow
 - Personal Star (inactive): .gray
 - Guild Icon (active):      .blue
 - Guild Icon (inactive):    .gray
 
 PRICE CHANGES:
 - Up:   .green
 - Down: .red
 
 BACKGROUNDS (with opacities):
 - Card:                     .white @ 0.05
 - Card Selected:            .blue @ 0.2
 - Card Success:             .green @ 0.2
 - Disclosure Header:        .white @ 0.08 → 0.04 gradient
 - Disclosure Content:       .white @ 0.03
 - Count Badge:              .white @ 0.15
 - Search Bar:               .white @ 0.08
 
 BORDERS (with opacities):
 - Subtle:           .white @ 0.15
 - Selected:         .blue @ 0.4
 - Search Normal:    .white @ 0.1
 - Search Focused:   .blue @ 0.5
 
 TEXT COLORS:
 - Primary:     .white
 - Secondary:   .gray
 - Tertiary:    .gray @ 0.7
 - Placeholder: .gray @ 0.5
 
*/

// MARK: - ================================================================================================
// MARK: - USAGE EXAMPLES
// MARK: - ================================================================================================

/*
 
 // Using the tab gradient:
 .background(UnifiedColors.tabSelectedGradient)
 
// Using asset class colors:
func colorForAssetClass(_ assetClass: RLAssetClass) -> Color {
     switch assetClass {
     case .forex: return UnifiedColors.assetClassForex
     case .crypto: return UnifiedColors.assetClassCrypto
     case .stocks: return UnifiedColors.assetClassStocks
     case .commodities: return UnifiedColors.assetClassCommodities
     case .indices: return UnifiedColors.assetClassIndices
     case .futures: return UnifiedColors.assetClassFutures
     }
 }
 
 // Using indicator colors:
 UnifiedIndicatorAddButton(title: "EMA", color: UnifiedColors.indicatorEMA) { ... }
 UnifiedIndicatorAddButton(title: "SMA", color: UnifiedColors.indicatorSMA) { ... }
 
 // Using text colors:
 Text("Primary")
     .foregroundColor(UnifiedColors.textPrimary)
 Text("Secondary")
     .foregroundColor(UnifiedColors.textSecondary)
 
*/
