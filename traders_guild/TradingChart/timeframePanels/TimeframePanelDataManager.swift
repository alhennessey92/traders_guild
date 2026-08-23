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

enum TimeframePanelHistoricalWindow {
    static func centeredEndTime(
        for timestamp: Date,
        timeframeSeconds: TimeInterval,
        candleLimit: Int
    ) -> Date {
        let safeTimeframeSeconds = max(timeframeSeconds, 1)
        let forwardWindow = safeTimeframeSeconds * Double(max(1, candleLimit / 2))
        return timestamp.addingTimeInterval(forwardWindow)
    }
}

class TimeframePanelDataManager: ObservableObject {

    // MARK: - Published State

    @Published var candles: [RLCandleDTO] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var livePrice: Double?
    @Published private(set) var isLoadingOlderCandles: Bool = false
    @Published private(set) var hasMoreHistoricalCandles: Bool = false
    @Published private(set) var dataRevision: Int = 0

    let timeframe: RLChartTimeframe
    let ownerToken: String

    // MARK: - Private

    private let api: RealAPIService
    private var cancellable: AnyCancellable?
    private var historicalPreloadTask: Task<Void, Never>?
    private var currentTickChannel: String?
    private var currentCandleChannel: String?
    @Published private(set) var currentSymbolId: UUID?
    private var currentGuildId: UUID?
    private var earliestHistoricalCandleTimestamp: Date?
    private let historicalPageSize: Int
    private(set) var historicalRenderIndexOffset: Int = 0

    // MARK: - Init

    init(timeframe: RLChartTimeframe, api: RealAPIService, ownerToken: String) {
        self.timeframe = timeframe
        self.api = api
        self.ownerToken = ownerToken
        self.historicalPageSize = HistoricalPreloadPolicy.pageSize
    }

    deinit {
        historicalPreloadTask?.cancel()
        unsubscribeFromRealTime()
    }

    // MARK: - Load

    @MainActor
    func loadCandles(symbolId: UUID, guildId: UUID, force: Bool = false) async {
        if !force,
           currentSymbolId == symbolId,
           currentGuildId == guildId,
           !candles.isEmpty,
           errorMessage == nil {
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        cancelHistoricalWarmup()
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
            historicalRenderIndexOffset = 0
            candles = chartData.candles
            livePrice = candles.last?.close
            earliestHistoricalCandleTimestamp = candles.first?.timestamp
            hasMoreHistoricalCandles = chartData.hasMoreCandles
            dataRevision += 1
            print("[TimeframePanel] Loaded \(candles.count) candles for \(timeframe.shortName)")

            // Subscribe to real-time updates for this symbol/timeframe
            subscribeToRealTime(symbolId: symbolId)
        } catch {
            print("[TimeframePanel] Failed to load \(timeframe.shortName): \(error)")
            errorMessage = "Failed to load \(timeframe.shortName) data"
            candles = []
            historicalRenderIndexOffset = 0
            earliestHistoricalCandleTimestamp = nil
            hasMoreHistoricalCandles = false
            cancelHistoricalWarmup()
            dataRevision += 1
        }

        isLoading = false
    }

    @MainActor
    func refreshIfPossible() async {
        guard let currentSymbolId, let currentGuildId else { return }
        await loadCandles(symbolId: currentSymbolId, guildId: currentGuildId, force: true)
    }

    @MainActor
    func loadOlderCandlesIfNeeded(
        visibleStartIndex: Int,
        visibleCandleCount: Int,
        beforePublishingPrepend: ((Int) -> Void)? = nil
    ) async -> Int {
        guard HistoricalPreloadPolicy.shouldPreload(
            visibleStartIndex: visibleStartIndex,
            visibleCandleCount: visibleCandleCount,
            hasMoreHistoricalCandles: hasMoreHistoricalCandles
        ) else {
            return 0
        }

        return await loadOlderCandles(beforePublishingPrepend: beforePublishingPrepend)
    }

    @MainActor
    func loadOlderCandles(beforePublishingPrepend: ((Int) -> Void)? = nil) async -> Int {
        guard let currentSymbolId,
              hasMoreHistoricalCandles,
              !isLoading,
              !isLoadingOlderCandles else {
            return 0
        }

        let endTime = earliestHistoricalCandleTimestamp ?? candles.first?.timestamp
        guard let endTime else { return 0 }

        isLoadingOlderCandles = true
        defer { isLoadingOlderCandles = false }

        do {
            let response = try await api.getCandles(
                symbolId: currentSymbolId,
                timeframe: timeframe.toBackendString(),
                limit: historicalPageSize,
                endTime: endTime,
                continuousTime: true
            )
            let prependedCount = mergeHistoricalCandles(
                response.candles,
                beforePublishingPrepend: beforePublishingPrepend
            )
            earliestHistoricalCandleTimestamp = candles.first?.timestamp ?? response.earliestTimestamp
            hasMoreHistoricalCandles = response.hasMore && prependedCount > 0
            livePrice = candles.last?.close ?? livePrice
            return prependedCount
        } catch {
            print("[TimeframePanel] Failed to load older \(timeframe.shortName) candles: \(error)")
            return 0
        }
    }

    @MainActor
    func loadCandlesAround(
        _ timestamp: Date,
        beforePublishingPrepend: ((Int) -> Void)? = nil
    ) async -> Int {
        guard let currentSymbolId,
              !isLoading,
              !isLoadingOlderCandles else {
            return 0
        }

        let endTime = TimeframePanelHistoricalWindow.centeredEndTime(
            for: timestamp,
            timeframeSeconds: timeframe.seconds,
            candleLimit: historicalPageSize
        )

        isLoadingOlderCandles = true
        defer { isLoadingOlderCandles = false }

        do {
            let response = try await api.getCandles(
                symbolId: currentSymbolId,
                timeframe: timeframe.toBackendString(),
                limit: historicalPageSize,
                endTime: endTime,
                continuousTime: true
            )
            let prependedCount = mergeHistoricalCandles(
                response.candles,
                beforePublishingPrepend: beforePublishingPrepend
            )
            earliestHistoricalCandleTimestamp = candles.first?.timestamp ?? response.earliestTimestamp
            hasMoreHistoricalCandles = response.hasMore && (prependedCount > 0 || hasMoreHistoricalCandles)
            livePrice = candles.last?.close ?? livePrice
            return prependedCount
        } catch {
            print("[TimeframePanel] Failed to load \(timeframe.shortName) window around \(timestamp): \(error)")
            return 0
        }
    }

    @MainActor
    private func scheduleHistoricalWarmupIfNeeded() {
        cancelHistoricalWarmup()
        guard HistoricalPreloadPolicy.shouldWarmup(
            candleCount: candles.count,
            timeframe: timeframe,
            hasMoreHistoricalCandles: hasMoreHistoricalCandles
        ) else {
            return
        }

        let symbolId = currentSymbolId
        let guildId = currentGuildId
        historicalPreloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self else { return }
            while !Task.isCancelled,
                  self.currentSymbolId == symbolId,
                  self.currentGuildId == guildId,
                  HistoricalPreloadPolicy.shouldWarmup(
                    candleCount: self.candles.count,
                    timeframe: self.timeframe,
                    hasMoreHistoricalCandles: self.hasMoreHistoricalCandles
                  ) {
                let prependedCount = await self.loadOlderCandles()
                guard prependedCount > 0 else { break }
            }
            if self.historicalPreloadTask?.isCancelled == false {
                self.historicalPreloadTask = nil
            }
        }
    }

    @MainActor
    private func cancelHistoricalWarmup() {
        historicalPreloadTask?.cancel()
        historicalPreloadTask = nil
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
                open: payload.candle.open,
                high: payload.candle.high,
                low: payload.candle.low,
                close: payload.candle.close,
                volume: payload.candle.volume,
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

    private func mergeHistoricalCandles(
        _ incoming: [RLCandleDTO],
        beforePublishingPrepend: ((Int) -> Void)? = nil
    ) -> Int {
        guard !incoming.isEmpty else { return 0 }

        guard let oldFirstTimestamp = candles.first?.timestamp else {
            historicalRenderIndexOffset = 0
            candles = sortedUniqueCandles(incoming)
            return 0
        }

        let existingTimestamps = Set(candles.map(\.timestamp))
        var uniqueIncoming: [RLCandleDTO] = []
        uniqueIncoming.reserveCapacity(incoming.count)
        var seenIncoming = Set<Date>()

        for candle in incoming {
            guard !existingTimestamps.contains(candle.timestamp),
                  !seenIncoming.contains(candle.timestamp) else {
                continue
            }
            seenIncoming.insert(candle.timestamp)
            uniqueIncoming.append(candle)
        }

        guard !uniqueIncoming.isEmpty else { return 0 }

        let prependedCount = uniqueIncoming.filter { $0.timestamp < oldFirstTimestamp }.count
        if uniqueIncoming.allSatisfy({ $0.timestamp < oldFirstTimestamp }) {
            if prependedCount > 0 {
                historicalRenderIndexOffset += prependedCount
                beforePublishingPrepend?(prependedCount)
            }
            candles = uniqueIncoming.sorted { $0.timestamp < $1.timestamp } + candles
            return prependedCount
        }

        if prependedCount > 0 {
            historicalRenderIndexOffset += prependedCount
            beforePublishingPrepend?(prependedCount)
        }
        candles = sortedUniqueCandles(incoming + candles)
        return prependedCount
    }

    private func sortedUniqueCandles(_ source: [RLCandleDTO]) -> [RLCandleDTO] {
        var byTimestamp: [Date: RLCandleDTO] = [:]
        for candle in source {
            byTimestamp[candle.timestamp] = candle
        }
        return byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
    }
}
