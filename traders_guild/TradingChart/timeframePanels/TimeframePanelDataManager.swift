//
//  TimeframePanelDataManager.swift
//  traders_guild
//
//  Manages candle data for a single linked timeframe panel.
//  Fetches a snapshot of candle history and subscribes to real-time candle updates.
//

import Foundation
import SwiftUI
import Combine

class TimeframePanelDataManager: ObservableObject {

    // MARK: - Published State

    @Published var candles: [RLCandleDTO] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var livePrice: Double?

    let timeframe: RLChartTimeframe

    // MARK: - Private

    private let api: RealAPIService
    private var cancellable: AnyCancellable?
    private var currentCandleChannel: String?
    private var currentSymbolId: UUID?

    // MARK: - Init

    init(timeframe: RLChartTimeframe, api: RealAPIService) {
        self.timeframe = timeframe
        self.api = api
    }

    deinit {
        unsubscribeFromRealTime()
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
            livePrice = candles.last?.close
            print("[TimeframePanel] Loaded \(candles.count) candles for \(timeframe.shortName)")

            // Subscribe to real-time updates for this symbol/timeframe
            subscribeToRealTime(symbolId: symbolId)
        } catch {
            print("[TimeframePanel] Failed to load \(timeframe.shortName): \(error)")
            errorMessage = "Failed to load \(timeframe.shortName) data"
            candles = []
        }

        isLoading = false
    }

    // MARK: - Real-Time Subscription

    private func subscribeToRealTime(symbolId: UUID) {
        unsubscribeFromRealTime()

        currentSymbolId = symbolId
        let symbolIdStr = symbolId.uuidString.lowercased()
        let timeframeStr = timeframe.toBackendString()
        let channel = "market:candles:\(symbolIdStr):\(timeframeStr)"
        currentCandleChannel = channel

        RealTimeService.shared.subscribe(to: [channel], owner: "timeframePanel_\(timeframeStr)")

        cancellable = RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeMessage(message)
            }
    }

    private func unsubscribeFromRealTime() {
        cancellable?.cancel()
        cancellable = nil
        if let channel = currentCandleChannel {
            let timeframeStr = timeframe.toBackendString()
            RealTimeService.shared.unsubscribe(from: [channel], owner: "timeframePanel_\(timeframeStr)")
            currentCandleChannel = nil
        }
        currentSymbolId = nil
    }

    private func handleRealTimeMessage(_ message: WSIncomingMessage) {
        guard message.type == "candle_update",
              let payload = message.payload(as: MarketCandlePayload.self),
              payload.timeframe == timeframe.toBackendString() else { return }

        let candleData = payload.candle
        livePrice = candleData.close

        guard !candles.isEmpty else { return }

        let lastCandle = candles[candles.count - 1]
        let timeframeSeconds = timeframe.seconds

        // Check if this update belongs to the current (last) candle or a new one
        if candleData.timestamp == lastCandle.timestamp ||
           (candleData.timestamp >= lastCandle.timestamp &&
            candleData.timestamp < lastCandle.timestamp.addingTimeInterval(timeframeSeconds)) {
            // Update existing last candle
            let updated = RLCandleDTO(
                timestamp: lastCandle.timestamp,
                timestampFormatted: lastCandle.timestampFormatted,
                open: lastCandle.open,
                high: max(lastCandle.high, candleData.high),
                low: min(lastCandle.low, candleData.low),
                close: candleData.close,
                volume: candleData.volume,
                volumeFormatted: nil
            )
            candles[candles.count - 1] = updated
        } else if candleData.timestamp >= lastCandle.timestamp.addingTimeInterval(timeframeSeconds) {
            // New candle — append
            let newCandle = RLCandleDTO(
                timestamp: candleData.timestamp,
                timestampFormatted: nil,
                open: candleData.open,
                high: candleData.high,
                low: candleData.low,
                close: candleData.close,
                volume: candleData.volume,
                volumeFormatted: nil
            )
            candles.append(newCandle)
        }
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
