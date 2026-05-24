//
//  MetricFormatting.swift
//  traders_guild
//
//  Shared formatting + tinting helpers used by the stat charts module so
//  every dashboard surface formats numbers identically and picks the same
//  threshold colour for a given accuracy / percentage.
//

import SwiftUI

enum MetricFormat {
    /// Compact integer formatter shared by every dashboard (e.g. 1.2K, 3.4M).
    static func compactInt(_ value: Int) -> String {
        if value <= -1_000_000 || value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value <= -1_000 || value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    /// One-decimal percentage (e.g. 0.723 → "72.3%").
    static func percent(_ ratio: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", ratio * 100)
    }

    /// Signed delta with explicit sign + compact magnitude (e.g. +540, -12).
    static func signedDelta(_ value: Int) -> String {
        value >= 0 ? "+\(compactInt(value))" : compactInt(value)
    }

    /// Signed percent delta (e.g. +3.2%).
    static func signedPercentDelta(_ ratio: Double, decimals: Int = 1) -> String {
        let formatted = String(format: "%.\(decimals)f%%", ratio * 100)
        return ratio >= 0 ? "+\(formatted)" : formatted
    }
}

enum MetricTint {
    /// Accuracy thresholds shared across the guild statistics screen and the
    /// user reputation / accuracy breakdown sheets so the same percentage maps
    /// to the same colour everywhere.
    static func accuracy(_ value: Double) -> Color {
        if value >= 0.7 { return AppColors.statusPositive }
        if value >= 0.5 { return AppColors.statisticsMetricYellow }
        if value >= 0.35 { return AppColors.statisticsMetricOrange }
        return AppColors.statusNegative
    }

    /// Tint for a signed delta (positive = green, negative = red, zero = grey).
    static func delta<T: SignedNumeric & Comparable>(_ value: T) -> Color {
        if value > 0 { return AppColors.statusPositive }
        if value < 0 { return AppColors.statusNegative }
        return AppColors.greyText
    }
}
