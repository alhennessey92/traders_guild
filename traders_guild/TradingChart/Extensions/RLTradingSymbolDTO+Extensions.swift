//
//  RLTradingSymbolDTO+Extensions.swift
//  traders_guild
//
//  Extension to add computed properties and helpers for RLTradingSymbolDTO
//  to match functionality of old TradingSymbolDTO
//

import Foundation
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
        (iconUrl?.isEmpty == false) || (iconName?.isEmpty == false)
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

    /// Human-friendly asset class name for compact UI labels.
    var assetClassDisplayName: String {
        assetClassEnum?.displayName ?? "Other"
    }

    /// Trading timezone used for chart x-axis boundaries and date labels.
    ///
    /// Priority:
    /// 1) Known exchange code/name mapping
    /// 2) Asset-class fallback
    /// 3) Device timezone
    var exchangeTimeZone: TimeZone {
        if let mappedFromExchange = mappedExchangeTimeZone {
            return mappedFromExchange
        }

        switch assetClassEnum {
        case .crypto:
            return TimeZone(secondsFromGMT: 0) ?? .current
        case .futures, .commodities:
            return TimeZone(identifier: "America/Chicago") ?? .current
        case .stocks, .indices:
            return TimeZone(identifier: "America/New_York") ?? .current
        case .forex:
            return TimeZone(identifier: "Europe/London") ?? .current
        case .none:
            return .current
        }
    }

    /// Descriptive timezone metadata for diagnostics/future timezone settings UI.
    var exchangeTimeZoneDescription: String {
        let identifier = exchangeTimeZone.identifier
        if let exchange, !exchange.isEmpty {
            return "\(exchange.uppercased()) (\(identifier))"
        }
        return identifier
    }
    
    /// Change formatted string (fallback if not provided)
    var changeFormattedSafe: String {
        changeFormatted ?? (changePercent24h.map { String(format: "%.2f%%", $0) } ?? "--")
    }
    
    /// Price formatted string (fallback if not provided)
    var priceFormattedSafe: String {
        priceFormatted ?? (currentPrice.map { formatPrice($0) } ?? "--")
    }

    // MARK: - Market Session Schedule

    struct MarketSession {
        let openHour: Int
        let openMinute: Int
        let closeHour: Int
        let closeMinute: Int
        let isContinuous: Bool
        let closedWeekend: Bool

        var openFraction: Double {
            (Double(openHour) + Double(openMinute) / 60.0) / 24.0
        }
        var closeFraction: Double {
            (Double(closeHour) + Double(closeMinute) / 60.0) / 24.0
        }
        var sessionLengthFraction: Double {
            closeFraction - openFraction
        }

        static let always = MarketSession(openHour: 0, openMinute: 0, closeHour: 24, closeMinute: 0, isContinuous: true, closedWeekend: false)
        static let forexWeekday = MarketSession(openHour: 0, openMinute: 0, closeHour: 24, closeMinute: 0, isContinuous: true, closedWeekend: true)
        static let nyse = MarketSession(openHour: 9, openMinute: 30, closeHour: 16, closeMinute: 0, isContinuous: false, closedWeekend: true)
        static let lse = MarketSession(openHour: 8, openMinute: 0, closeHour: 16, closeMinute: 30, isContinuous: false, closedWeekend: true)
        static let jpx = MarketSession(openHour: 9, openMinute: 0, closeHour: 15, closeMinute: 0, isContinuous: false, closedWeekend: true)
        static let hkex = MarketSession(openHour: 9, openMinute: 30, closeHour: 16, closeMinute: 0, isContinuous: false, closedWeekend: true)
        static let asx = MarketSession(openHour: 10, openMinute: 0, closeHour: 16, closeMinute: 0, isContinuous: false, closedWeekend: true)
        static let eurex = MarketSession(openHour: 8, openMinute: 0, closeHour: 22, closeMinute: 0, isContinuous: false, closedWeekend: true)
        static let cme = MarketSession(openHour: 17, openMinute: 0, closeHour: 16, closeMinute: 0, isContinuous: false, closedWeekend: true)
    }

    var marketSession: MarketSession {
        switch assetClassEnum {
        case .crypto:
            return .always
        case .forex:
            return .forexWeekday
        case .stocks, .indices:
            if let exchange, !exchange.isEmpty {
                let normalized = exchange.uppercased()
                if normalized.contains("LSE") || normalized.contains("LONDON") { return .lse }
                if normalized.contains("JPX") || normalized.contains("TSE") || normalized.contains("TOKYO") { return .jpx }
                if normalized.contains("HKEX") || normalized.contains("HONG KONG") { return .hkex }
                if normalized.contains("ASX") || normalized.contains("SYDNEY") { return .asx }
                if normalized.contains("EUREX") || normalized.contains("XETRA") || normalized.contains("FRANKFURT") { return .eurex }
            }
            return .nyse
        case .commodities, .futures:
            return .cme
        case .none:
            return .nyse
        }
    }

    private var mappedExchangeTimeZone: TimeZone? {
        guard let exchange, !exchange.isEmpty else { return nil }
        let normalized = exchange.uppercased()

        let mappings: [(patterns: [String], timeZone: String)] = [
            (["NYSE", "NASDAQ", "AMEX", "US", "ARCA"], "America/New_York"),
            (["CME", "CBOT", "COMEX", "NYMEX"], "America/Chicago"),
            (["LSE", "LONDON"], "Europe/London"),
            (["EUREX", "XETRA", "FRANKFURT"], "Europe/Berlin"),
            (["JPX", "TSE", "TOKYO"], "Asia/Tokyo"),
            (["HKEX", "HONG KONG"], "Asia/Hong_Kong"),
            (["ASX", "SYDNEY"], "Australia/Sydney"),
            (["SGX", "SINGAPORE"], "Asia/Singapore")
        ]

        for mapping in mappings {
            if mapping.patterns.contains(where: { normalized.contains($0) }) {
                return TimeZone(identifier: mapping.timeZone)
            }
        }

        return nil
    }
}
