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
    }

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
    }

    func bullishBodyFillOpacity(isLightGreyTheme: Bool) -> Double {
        guard useSemiTransparentBullishCandles else { return 1.0 }
        return isLightGreyTheme ? 1.0 : 0.3
    }
}
