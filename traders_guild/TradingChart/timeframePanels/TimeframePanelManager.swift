//
//  TimeframePanelManager.swift
//  traders_guild
//
//  Central manager for active timeframe panels.
//  Manages up to 2 panel entries, each with its own data manager and gesture state.
//

import Foundation
import SwiftUI

class TimeframePanelManager: ObservableObject {

    // MARK: - Constants

    static let maxPanels = 2
    static let defaultPanelHeight: CGFloat = 140
    static let minPanelHeight: CGFloat = 80
    static let maxPanelHeight: CGFloat = 250
    static let maxPanelHeightWith2: CGFloat = 180

    // MARK: - Published

    @Published var panels: [TimeframePanelEntry] = []

    // MARK: - Private

    var api: RealAPIService

    // MARK: - Init

    init(api: RealAPIService = RealAPIService()) {
        self.api = api
    }

    // MARK: - Computed

    var hasActivePanels: Bool { !panels.isEmpty }
    var activePanelCount: Int { panels.count }

    var adjustedMaxHeight: CGFloat {
        panels.count > 1 ? Self.maxPanelHeightWith2 : Self.maxPanelHeight
    }

    // MARK: - Panel Management

    func addPanel(timeframe: RLChartTimeframe, symbolId: UUID, guildId: UUID) {
        // Don't add duplicates
        guard !panels.contains(where: { $0.timeframe == timeframe }) else {
            print("[TimeframePanelManager] Panel for \(timeframe.shortName) already exists, skipping")
            return
        }

        // Enforce limit
        guard panels.count < Self.maxPanels else {
            print("[TimeframePanelManager] Max panels (\(Self.maxPanels)) reached, skipping")
            return
        }

        print("[TimeframePanelManager] Adding panel for \(timeframe.shortName), symbol=\(symbolId), guild=\(guildId)")

        let dataManager = TimeframePanelDataManager(timeframe: timeframe, api: api)
        let gestureState = TimeframePanelGestureState()

        let entry = TimeframePanelEntry(
            id: UUID(),
            timeframe: timeframe,
            dataManager: dataManager,
            gestureState: gestureState
        )
        panels.append(entry)

        // Load candle data
        Task { @MainActor in
            await dataManager.loadCandles(symbolId: symbolId, guildId: guildId)
        }
    }

    func removePanel(timeframe: RLChartTimeframe) {
        panels.removeAll { $0.timeframe == timeframe }
    }

    func removePanel(id: UUID) {
        panels.removeAll { $0.id == id }
    }

    func clearAll() {
        panels.removeAll()
    }

    func hasPanel(for timeframe: RLChartTimeframe) -> Bool {
        panels.contains { $0.timeframe == timeframe }
    }

    /// Reload data for all panels (e.g., when symbol changes).
    func reloadAll(symbolId: UUID, guildId: UUID) {
        for panel in panels {
            Task { @MainActor in
                await panel.dataManager.loadCandles(symbolId: symbolId, guildId: guildId)
            }
        }
    }
}

// MARK: - Panel Entry

struct TimeframePanelEntry: Identifiable {
    let id: UUID
    let timeframe: RLChartTimeframe
    let dataManager: TimeframePanelDataManager
    let gestureState: TimeframePanelGestureState
}
