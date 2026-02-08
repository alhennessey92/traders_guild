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
    static let tabGradientStart = Color(red: 0.2, green: 0.4, blue: 0.8)
    
    /// Primary blue gradient end color
    /// Hex: #263F80 | RGB: (38, 63, 128)
    static let tabGradientEnd = Color(red: 0.15, green: 0.25, blue: 0.5)
    
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
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Tab Border Colors
    
    /// Border color for selected tabs
    static let tabSelectedBorder = Color.blue.opacity(0.4)
    
    // MARK: - Asset Class Colors (for Disclosure Groups & Categories)
    
    /// Forex - Blue
    static let assetClassForex = Color.blue
    
    /// Crypto - Orange
    static let assetClassCrypto = Color.orange
    
    /// Stocks - Green
    static let assetClassStocks = Color.green
    
    /// Commodities - Yellow
    static let assetClassCommodities = Color.yellow
    
    /// Indices - Purple
    static let assetClassIndices = Color.purple
    
    /// Futures - Cyan
    static let assetClassFutures = Color.cyan
    
    // MARK: - Indicator Add Button Colors
    
    /// EMA indicator button color - Cyan
    static let indicatorEMA = Color.cyan
    
    /// SMA indicator button color - Orange
    static let indicatorSMA = Color.orange
    
    /// RSI indicator color - Purple
    static let indicatorRSI = Color.purple
    
    /// MACD indicator color - Green
    static let indicatorMACD = Color.green
    
    /// Bollinger Bands indicator color - Yellow
    static let indicatorBollinger = Color.yellow
    
    /// ATR indicator color - Red
    static let indicatorATR = Color.red
    
    // MARK: - Watchlist Action Button Colors
    
    /// Personal watchlist star color (filled)
    static let personalWatchlistActive = Color.yellow
    
    /// Personal watchlist star color (unfilled)
    static let personalWatchlistInactive = Color.gray
    
    /// Guild watchlist icon color (filled)
    static let guildWatchlistActive = Color.blue
    
    /// Guild watchlist icon color (unfilled)
    static let guildWatchlistInactive = Color.gray
    
    // MARK: - Price Change Colors
    
    /// Price up / positive change
    static let priceUp = Color.green
    
    /// Price down / negative change
    static let priceDown = Color.red
    
    // MARK: - Background Colors & Opacities
    
    /// Card/row background
    static let cardBackground = Color.white.opacity(0.05)
    
    /// Selected/highlighted card background
    static let cardBackgroundSelected = Color.blue.opacity(0.2)
    
    /// Success/just selected feedback background
    static let cardBackgroundSuccess = Color.green.opacity(0.2)
    
    /// Subtle border color
    static let subtleBorder = Color.white.opacity(0.15)
    
    /// Selected item border
    static let selectedBorder = Color.blue.opacity(0.4)
    
    // MARK: - Text Colors
    
    /// Primary text - White
    static let textPrimary = Color.white
    
    /// Secondary text - Gray
    static let textSecondary = Color.gray
    
    /// Tertiary/hint text
    static let textTertiary = Color.gray.opacity(0.7)
    
    /// Placeholder/empty state text
    static let textPlaceholder = Color.gray.opacity(0.5)
    
    // MARK: - Disclosure Group Colors
    
    /// Disclosure header background (collapsed)
    static var disclosureHeaderBackground: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Disclosure content background
    static let disclosureContentBackground = Color.white.opacity(0.03)
    
    /// Disclosure count badge background
    static let disclosureCountBadge = Color.white.opacity(0.15)
    
    // MARK: - Search Bar Colors
    
    /// Search bar background
    static let searchBarBackground = Color.white.opacity(0.08)
    
    /// Search bar border
    static let searchBarBorder = Color.white.opacity(0.1)
    
    /// Search bar focused border
    static let searchBarFocusedBorder = Color.blue.opacity(0.5)
    
    // MARK: - Empty State Colors
    
    /// Empty state icon color
    static let emptyStateIcon = Color.gray.opacity(0.5)
    
    /// Empty state title color
    static let emptyStateTitle = Color.gray
    
    /// Empty state subtitle color
    static let emptyStateSubtitle = Color.gray.opacity(0.7)
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
