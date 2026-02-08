//
//  ChartUITypes.swift
//  traders_guild
//
//  UI-focused helper enums and utilities for charting.
//

import SwiftUI

// MARK: - Horizontal Line Price Source

enum LinePriceSource: String, Codable {
    case none
    case candleOpen
    case candleClose
    case candleHigh
    case candleLow
    case custom
}

// MARK: - Marker Categories

enum MarkerCategory: String, CaseIterable {
    case core = "Core Markers"
    case analysis = "Analysis Markers"
    case prediction = "Prediction Markers"
    case social = "Social Markers"
}

// MARK: - Marker Alert Severity

enum MarkerAlertSeverity: String, Codable, CaseIterable {
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .mild: return .green
        case .moderate: return .yellow
        case .severe: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Trendline Direction

enum TrendlineDirection: String, Codable, CaseIterable {
    case up = "Uptrend"
    case down = "Downtrend"
    case sideways = "Sideways"
}

// MARK: - Chart Pattern

enum ChartPattern: String, Codable, CaseIterable {
    case headAndShoulders = "Head & Shoulders"
    case inverseHeadAndShoulders = "Inverse H&S"
    case doubleTop = "Double Top"
    case doubleBottom = "Double Bottom"
    case tripleTop = "Triple Top"
    case tripleBottom = "Triple Bottom"
    case ascendingTriangle = "Ascending Triangle"
    case descendingTriangle = "Descending Triangle"
    case symmetricalTriangle = "Symmetrical Triangle"
    case wedge = "Wedge"
    case flag = "Flag"
    case pennant = "Pennant"
    case cup = "Cup & Handle"
    case rectangle = "Rectangle"
    case other = "Other"
}

// MARK: - Color Hex Helper

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

