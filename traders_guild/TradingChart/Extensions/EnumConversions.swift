//
//  EnumConversions.swift
//  traders_guild
//
//  Helper extensions for converting between iOS enums and backend string values
//

import Foundation

// =============================================================================
// MARK: - RLChartTimeframe Conversions
// =============================================================================

extension RLChartTimeframe {
    /// Convert to backend string format (e.g., "1m", "5m", "1h")
    func toBackendString() -> String {
        return self.rawValue
    }
    
    /// Create from backend string format
    static func fromBackendString(_ string: String) -> RLChartTimeframe? {
        return RLChartTimeframe(rawValue: string)
    }
}

// =============================================================================
// MARK: - RLMarkerType Conversions
// =============================================================================

extension RLMarkerType {
    /// Convert to backend string format
    /// Maps iOS enum values to backend marker type strings
    func toBackendString() -> String {
        switch self {
        // Core markers
        case .note: return "analysis"
        case .question: return "question"
        case .alert: return "alert"
        case .entry: return "entry"
        case .exit: return "exit"
        
        // Trading markers (distinct types so they round-trip correctly)
        case .stopLoss: return "stop_loss"
        case .takeProfit: return "take_profit"
        
        // Analysis markers
        case .support: return "support"
        case .resistance: return "resistance"
        case .indicator: return "indicator"
        case .trendline: return "trendline"
        case .pattern: return "pattern"
        case .volumeSpike: return "volume_spike"
        
        // Prediction markers
        case .predictionTarget: return "prediction"
        
        // Social markers
        case .emoji: return "emoji"
        case .poll: return "poll"
        case .personal: return "personal"
        }
    }
    
}

// =============================================================================
// MARK: - RLAssetClass Conversions
// =============================================================================

extension RLAssetClass {
    /// Convert to backend string format (lowercase)
    func toBackendString() -> String {
        return self.rawValue.lowercased()
    }
    
}

// =============================================================================
// MARK: - MarkerAlertSeverity Conversions
// =============================================================================

extension MarkerAlertSeverity {
    /// Convert to backend string format (lowercase)
    func toBackendString() -> String {
        switch self {
        case .mild: return "low"
        case .moderate: return "medium"
        case .severe: return "high"
        case .critical: return "critical"
        }
    }
    
    /// Create from backend string format
    static func fromBackendString(_ string: String) -> MarkerAlertSeverity? {
        switch string.lowercased() {
        case "low", "mild": return .mild
        case "medium", "moderate": return .moderate
        case "high", "severe": return .severe
        case "critical": return .critical
        default: return nil
        }
    }
}

// =============================================================================
// MARK: - TrendlineDirection Conversions (if exists)
// =============================================================================

extension TrendlineDirection {
    static func fromBackendString(_ string: String) -> TrendlineDirection? {
        switch string.lowercased() {
        case "up", "uptrend": return .up
        case "down", "downtrend": return .down
        case "sideways": return .sideways
        default: return nil
        }
    }
    
    func toBackendString() -> String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .sideways: return "sideways"
        }
    }
}

// =============================================================================
// MARK: - ChartPattern Conversions
// =============================================================================

extension ChartPattern {
    static func fromBackendString(_ string: String) -> ChartPattern? {
        switch string.lowercased() {
        case "head_and_shoulders", "headandshoulders": return .headAndShoulders
        case "inverse_head_and_shoulders", "inverse_headandshoulders": return .inverseHeadAndShoulders
        case "double_top", "doubletop": return .doubleTop
        case "double_bottom", "doublebottom": return .doubleBottom
        case "triple_top", "tripletop": return .tripleTop
        case "triple_bottom", "triplebottom": return .tripleBottom
        case "ascending_triangle", "ascendingtriangle": return .ascendingTriangle
        case "descending_triangle", "descendingtriangle": return .descendingTriangle
        case "symmetrical_triangle", "symmetricaltriangle": return .symmetricalTriangle
        case "wedge": return .wedge
        case "flag": return .flag
        case "pennant": return .pennant
        case "cup_and_handle", "cuphandle", "cup&handle": return .cup
        case "rectangle": return .rectangle
        case "other": return .other
        default: return nil
        }
    }
    
    func toBackendString() -> String {
        switch self {
        case .headAndShoulders: return "head_and_shoulders"
        case .inverseHeadAndShoulders: return "inverse_head_and_shoulders"
        case .doubleTop: return "double_top"
        case .doubleBottom: return "double_bottom"
        case .tripleTop: return "triple_top"
        case .tripleBottom: return "triple_bottom"
        case .ascendingTriangle: return "ascending_triangle"
        case .descendingTriangle: return "descending_triangle"
        case .symmetricalTriangle: return "symmetrical_triangle"
        case .wedge: return "wedge"
        case .flag: return "flag"
        case .pennant: return "pennant"
        case .cup: return "cup_and_handle"
        case .rectangle: return "rectangle"
        case .other: return "other"
        }
    }
}
