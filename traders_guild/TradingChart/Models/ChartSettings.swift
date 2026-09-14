//
//  ChartSettings.swift
//  traders_guild
//
//  Chart display settings for grid lines, candle colors, etc.
//

import SwiftUI

/// Style options for the timeframe panel viewport window
enum ViewportWindowStyle: String, CaseIterable, Identifiable {
    case dimmed = "Dimmed"
    case bordered = "Bordered"
    case tinted = "Tinted"

    var id: String { rawValue }
}

class ChartSettings: ObservableObject {
    static let shared = ChartSettings()

    private enum StorageKey {
        static let showViewportWindow = "chartShowViewportWindow"
        static let viewportWindowStyle = "chartViewportWindowStyle"
        static let viewportWindowOpacity = "chartViewportWindowOpacity"
        static let useSemiTransparentBullishCandles = "chartUseSemiTransparentBullishCandles"
        static let linkLineWidth = "chartLinkLineWidth"
        static let linkCurvature = "chartLinkCurvature"
    }

    // MARK: - Linked-marker connectors

    /// Stroke width of thesis connectors, in points. 1.5 matches the stack
    /// spine it sits beside; 3 is as heavy as a dashed line can go before the
    /// dashes stop reading as a pattern.
    static let linkLineWidthRange: ClosedRange<CGFloat> = 1.0...3.0
    static let defaultLinkLineWidth: CGFloat = 1.5

    /// Multiplier on how far a connector bows away from the stack. Below 1
    /// flattens, above rounds. Bounded so the flattest setting still clears
    /// the spine and the roundest does not loop back over a neighbour.
    static let linkCurvatureRange: ClosedRange<CGFloat> = MarkerLinkGeometry.curvatureRange
    static let defaultLinkCurvature: CGFloat = MarkerLinkGeometry.defaultCurvature

    // MARK: - Grid Settings

    @Published var showGridLines: Bool = true
    @Published var gridOpacity: Double = 0.18

    // MARK: - Candle Color Settings

    @Published var bullishCandleColor: Color = AppColors.defaultBullishCandleGreen
    @Published var bearishCandleColor: Color = .red
    @Published var useSemiTransparentBullishCandles: Bool = true {
        didSet { UserDefaults.standard.set(useSemiTransparentBullishCandles, forKey: StorageKey.useSemiTransparentBullishCandles) }
    }

    // MARK: - Viewport Window Settings (timeframe panel)

    @Published var showViewportWindow: Bool = true {
        didSet { UserDefaults.standard.set(showViewportWindow, forKey: StorageKey.showViewportWindow) }
    }
    @Published var viewportWindowStyle: ViewportWindowStyle = .dimmed {
        didSet { UserDefaults.standard.set(viewportWindowStyle.rawValue, forKey: StorageKey.viewportWindowStyle) }
    }
    @Published var viewportWindowOpacity: Double = 0.35 {
        didSet { UserDefaults.standard.set(viewportWindowOpacity, forKey: StorageKey.viewportWindowOpacity) }
    }

    // MARK: - Linked-marker connector settings

    @Published var linkLineWidth: CGFloat = ChartSettings.defaultLinkLineWidth {
        didSet {
            let clamped = Self.clamp(linkLineWidth, to: Self.linkLineWidthRange)
            if clamped != linkLineWidth { linkLineWidth = clamped; return }
            UserDefaults.standard.set(Double(linkLineWidth), forKey: StorageKey.linkLineWidth)
        }
    }
    @Published var linkCurvature: CGFloat = ChartSettings.defaultLinkCurvature {
        didSet {
            let clamped = Self.clamp(linkCurvature, to: Self.linkCurvatureRange)
            if clamped != linkCurvature { linkCurvature = clamped; return }
            UserDefaults.standard.set(Double(linkCurvature), forKey: StorageKey.linkCurvature)
        }
    }

    func resetLinkAppearance() {
        linkLineWidth = Self.defaultLinkLineWidth
        linkCurvature = Self.defaultLinkCurvature
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    init() {
        if UserDefaults.standard.object(forKey: StorageKey.useSemiTransparentBullishCandles) != nil {
            useSemiTransparentBullishCandles = UserDefaults.standard.bool(forKey: StorageKey.useSemiTransparentBullishCandles)
        }

        // Restore persisted viewport settings
        if UserDefaults.standard.object(forKey: StorageKey.showViewportWindow) != nil {
            showViewportWindow = UserDefaults.standard.bool(forKey: StorageKey.showViewportWindow)
        }
        if let styleRaw = UserDefaults.standard.string(forKey: StorageKey.viewportWindowStyle),
           let style = ViewportWindowStyle(rawValue: styleRaw) {
            viewportWindowStyle = style
        }
        if UserDefaults.standard.object(forKey: StorageKey.viewportWindowOpacity) != nil {
            viewportWindowOpacity = UserDefaults.standard.double(forKey: StorageKey.viewportWindowOpacity)
        }

        // Connector appearance. Read through the clamp so a value written by a
        // build with different bounds can never put the geometry out of range.
        if UserDefaults.standard.object(forKey: StorageKey.linkLineWidth) != nil {
            linkLineWidth = Self.clamp(
                CGFloat(UserDefaults.standard.double(forKey: StorageKey.linkLineWidth)),
                to: Self.linkLineWidthRange
            )
        }
        if UserDefaults.standard.object(forKey: StorageKey.linkCurvature) != nil {
            linkCurvature = Self.clamp(
                CGFloat(UserDefaults.standard.double(forKey: StorageKey.linkCurvature)),
                to: Self.linkCurvatureRange
            )
        }
    }

    func bullishBodyFillOpacity(isLightGreyTheme: Bool) -> Double {
        guard useSemiTransparentBullishCandles else { return 1.0 }
        return isLightGreyTheme ? 1.0 : 0.3
    }
}
