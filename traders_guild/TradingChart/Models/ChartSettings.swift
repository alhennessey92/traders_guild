//
//  ChartSettings.swift
//  traders_guild
//
//  Chart display settings for grid lines, candle colors, etc.
//

import SwiftUI

class ChartSettings: ObservableObject {
    static let shared = ChartSettings()

    // MARK: - Grid Settings

    @Published var showGridLines: Bool = true
    @Published var gridOpacity: Double = 0.18

    // MARK: - Candle Color Settings

    @Published var bullishCandleColor: Color = .green
    @Published var bearishCandleColor: Color = .red
}
