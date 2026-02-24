//
//  RLTradingSymbolDTO+Extensions.swift
//  traders_guild
//
//  Extension to add computed properties and helpers for RLTradingSymbolDTO
//  to match functionality of old TradingSymbolDTO
//

import SwiftUI

extension RLTradingSymbolDTO {
    /// Color for price change indicator
    var changeColor: Color {
        (isUp ?? true) ? .green : .red
    }
    
    /// Arrow indicator for change direction
    var changeArrow: String {
        (isUp ?? true) ? "↑" : "↓"
    }
    
    /// Primary color as SwiftUI Color
    var primaryColorValue: Color {
        Color(hex: primaryColor) ?? .blue
    }
    
    /// Secondary color as SwiftUI Color
    var secondaryColorValue: Color {
        Color(hex: secondaryColor) ?? .gray
    }
    
    /// Fallback initial letter for symbols without icons
    var fallbackInitial: String {
        String(ticker.prefix(1)).uppercased()
    }
    
    /// Whether this symbol has a custom icon asset
    var hasCustomIcon: Bool {
        iconName != nil
    }
    
    /// Format a price according to this symbol's specifications
    func formatPrice(_ price: Double) -> String {
        let decimals = decimalPlaces
        return String(format: "%.\(decimals)f", price)
    }
    
    /// Get RLAssetClass enum from string (for UI grouping)
    var assetClassEnum: RLAssetClass? {
        RLAssetClass.fromBackendString(assetClass)
    }
    
    /// Change formatted string (fallback if not provided)
    var changeFormattedSafe: String {
        changeFormatted ?? (changePercent24h.map { String(format: "%.2f%%", $0) } ?? "--")
    }
    
    /// Price formatted string (fallback if not provided)
    var priceFormattedSafe: String {
        priceFormatted ?? (currentPrice.map { formatPrice($0) } ?? "--")
    }
}
