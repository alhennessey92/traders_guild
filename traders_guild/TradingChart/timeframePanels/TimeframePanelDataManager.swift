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
    let ownerToken: String

    // MARK: - Private

    private let api: RealAPIService
    private var cancellable: AnyCancellable?
    private var currentTickChannel: String?
    private var currentCandleChannel: String?
    private var currentSymbolId: UUID?
    private var currentGuildId: UUID?

    // MARK: - Init

    init(timeframe: RLChartTimeframe, api: RealAPIService, ownerToken: String) {
        self.timeframe = timeframe
        self.api = api
        self.ownerToken = ownerToken
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
        currentSymbolId = symbolId
        currentGuildId = guildId

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

    @MainActor
    func refreshIfPossible() async {
        guard let currentSymbolId, let currentGuildId else { return }
        await loadCandles(symbolId: currentSymbolId, guildId: currentGuildId)
    }

    // MARK: - Real-Time Subscription

    private func subscribeToRealTime(symbolId: UUID) {
        unsubscribeFromRealTime()

        let symbolIdStr = symbolId.uuidString.lowercased()
        let timeframeStr = timeframe.toBackendString()
        currentTickChannel = "market:ticks:\(symbolIdStr)"
        currentCandleChannel = "market:candles:\(symbolIdStr):\(timeframeStr)"

        RealTimeService.shared.subscribe(
            to: [currentTickChannel, currentCandleChannel].compactMap { $0 },
            owner: ownerToken
        )

        cancellable = RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeMessage(message)
            }
    }

    private func unsubscribeFromRealTime() {
        cancellable?.cancel()
        cancellable = nil
        let channels = [currentTickChannel, currentCandleChannel].compactMap { $0 }
        if !channels.isEmpty {
            RealTimeService.shared.unsubscribe(from: channels, owner: ownerToken)
        }
        currentTickChannel = nil
        currentCandleChannel = nil
    }

    private func handleRealTimeMessage(_ message: WSIncomingMessage) {
        guard let channel = message.channel,
              channel == currentTickChannel || channel == currentCandleChannel else {
            return
        }

        if message.type == "tick" {
            guard let payload = message.payload(as: MarketTickPayload.self) else { return }
            let result = RealtimeCandleStreamReducer.processTick(
                candles: candles,
                timeframe: timeframe,
                price: payload.price,
                volume: payload.volume ?? 0,
                timestamp: payload.timestamp
            )
            candles = result.candles
            livePrice = result.currentPrice
            return
        }

        guard let payload = message.payload(as: MarketCandlePayload.self),
              payload.timeframe == timeframe.toBackendString() else {
            return
        }

        if message.type == "candle_complete" {
            let candle = RLCandleDTO(
                timestamp: payload.candle.timestamp,
                timestampFormatted: nil,
                open: payload.candle.open,
                high: payload.candle.high,
                low: payload.candle.low,
                close: payload.candle.close,
                volume: payload.candle.volume,
                volumeFormatted: nil,
                isGapFill: false
            )
            let result = RealtimeCandleStreamReducer.processCompletedCandle(
                candles: candles,
                timeframe: timeframe,
                candle: candle
            )
            candles = result.candles
            livePrice = result.currentPrice
            return
        }

        if message.type == "candle_update" {
            let result = RealtimeCandleStreamReducer.processTick(
                candles: candles,
                timeframe: timeframe,
                price: payload.candle.close,
                volume: payload.candle.volume,
                timestamp: payload.candle.timestamp
            )
            candles = result.candles
            livePrice = result.currentPrice
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
