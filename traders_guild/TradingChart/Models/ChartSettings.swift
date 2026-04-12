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

    // MARK: - Grid Settings

    @Published var showGridLines: Bool = true
    @Published var gridOpacity: Double = 0.18

    // MARK: - Candle Color Settings

    @Published var bullishCandleColor: Color = AppColors.defaultBullishCandleGreen
    @Published var bearishCandleColor: Color = .red

    // MARK: - Viewport Window Settings (timeframe panel)

    @Published var showViewportWindow: Bool = true {
        didSet { UserDefaults.standard.set(showViewportWindow, forKey: "chartShowViewportWindow") }
    }
    @Published var viewportWindowStyle: ViewportWindowStyle = .dimmed {
        didSet { UserDefaults.standard.set(viewportWindowStyle.rawValue, forKey: "chartViewportWindowStyle") }
    }
    @Published var viewportWindowOpacity: Double = 0.35 {
        didSet { UserDefaults.standard.set(viewportWindowOpacity, forKey: "chartViewportWindowOpacity") }
    }

    init() {
        // Restore persisted viewport settings
        if UserDefaults.standard.object(forKey: "chartShowViewportWindow") != nil {
            showViewportWindow = UserDefaults.standard.bool(forKey: "chartShowViewportWindow")
        }
        if let styleRaw = UserDefaults.standard.string(forKey: "chartViewportWindowStyle"),
           let style = ViewportWindowStyle(rawValue: styleRaw) {
            viewportWindowStyle = style
        }
        if UserDefaults.standard.object(forKey: "chartViewportWindowOpacity") != nil {
            viewportWindowOpacity = UserDefaults.standard.double(forKey: "chartViewportWindowOpacity")
        }
    }
}
