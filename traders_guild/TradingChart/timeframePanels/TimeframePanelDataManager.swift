//
//  TimeframePanelDataManager.swift
//  traders_guild
//
//  Manages candle data for a single linked timeframe panel.
//  Fetches a snapshot of candle history — does NOT subscribe to WebSocket.
//

import Foundation
import SwiftUI

class TimeframePanelDataManager: ObservableObject {

    // MARK: - Published State

    @Published var candles: [RLCandleDTO] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let timeframe: RLChartTimeframe

    // MARK: - Private

    private let api: RealAPIService

    // MARK: - Init

    init(timeframe: RLChartTimeframe, api: RealAPIService) {
        self.timeframe = timeframe
        self.api = api
    }

    // MARK: - Load

    @MainActor
    func loadCandles(symbolId: UUID, guildId: UUID) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let chartData = try await api.getChartData(
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframe.toBackendString(),
                candleLimit: timeframe.initialCandlesCount,
                continuousTime: true
            )
            candles = chartData.candles
            print("[TimeframePanel] Loaded \(candles.count) candles for \(timeframe.shortName)")
        } catch {
            print("[TimeframePanel] Failed to load \(timeframe.shortName): \(error)")
            errorMessage = "Failed to load \(timeframe.shortName) data"
            candles = []
        }

        isLoading = false
    }

    // MARK: - Marker Position

    /// Find the candle index in this timeframe where a given timestamp falls.
    func markerCandleIndex(for timestamp: Date) -> Int? {
        guard !candles.isEmpty else { return nil }

        let timeframeSeconds = timeframe.seconds

        // Find the candle whose time window contains the marker's timestamp
        for (index, candle) in candles.enumerated() {
            let candleStart = candle.timestamp
            let candleEnd = candleStart.addingTimeInterval(timeframeSeconds)
            if timestamp >= candleStart && timestamp < candleEnd {
                return index
            }
        }

        // If not found exactly, find the closest candle
        var closestIndex = 0
        var closestDistance: TimeInterval = .greatestFiniteMagnitude
        for (index, candle) in candles.enumerated() {
            let distance = abs(candle.timestamp.timeIntervalSince(timestamp))
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        return closestIndex
    }

    /// Latest close price for header display.
    var latestClose: Double? {
        candles.last?.close
    }
}
