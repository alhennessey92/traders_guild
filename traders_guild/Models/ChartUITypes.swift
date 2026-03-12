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

extension LinePriceSource {
    /// Extract the relevant price from a candle based on this line source
    func priceFromCandle(_ candle: RLCandleDTO) -> Double {
        switch self {
        case .candleOpen: return candle.open
        case .candleClose: return candle.close
        case .candleHigh: return candle.high
        case .candleLow: return candle.low
        case .custom, .none: return candle.close
        }
    }
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
    
    /// Alert marker color by severity: Mild=blue, Moderate=orange, Severe=yellow, Critical=red
    var color: Color {
        switch self {
        case .mild: return .blue
        case .moderate: return .orange
        case .severe: return .yellow
        case .critical: return .red
        }
    }

    /// SF Symbol used when rendering alert markers in marker-badge contexts.
    var markerIcon: String {
        switch self {
        case .critical:
            return "exclamationmark.octagon.fill"
        case .severe:
            return "exclamationmark.triangle.fill"
        case .moderate:
            return "exclamationmark.shield.fill"
        case .mild:
            return "info.circle.fill"
        }
    }

    /// Multi-color palette for SF Symbol palette rendering.
    var markerPalette: [Color] {
        let base = MarkerVisualSpec.iconBaseColor
        switch self {
        case .critical:
            return [base, AppColors.statusNegative92, AppColors.statusNegative60]
        case .severe:
            return [base, AppColors.statusWarning92, AppColors.statusHighlight68]
        case .moderate:
            return [base, AppColors.statusHighlight90, AppColors.statusWarning62]
        case .mild:
            return [base, AppColors.statusInfo90, AppColors.statusAccent66]
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

// MARK: - Marker Placement Tabs

enum MarkerPlacementTab: String, CaseIterable, UnifiedTabItem {
    case general = "General"
    case components = "Components"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .components: return "plus.viewfinder"
        }
    }
}

// MARK: - Marker Viewing Tabs

enum MarkerViewingTab: String, CaseIterable, UnifiedTabItem {
    case general = "General"
    case components = "Components"
    case chat = "Chat"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "info.circle.fill"
        case .components: return "square.stack.3d.up.fill"
        case .chat: return "message.fill"
        }
    }
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
