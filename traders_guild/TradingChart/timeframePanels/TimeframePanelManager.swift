//
//  TimeframePanelManager.swift
//  traders_guild
//
//  Central manager for active timeframe panels.
//  Maintains separate panel stacks for chart defaults, marker placement,
//  and marker viewing so their UI state cannot bleed across modes.
//

import Combine
import Foundation
import SwiftUI

enum TimeframePanelSource: String, CaseIterable, Hashable {
    case chartDefaults
    case markerPlacement
    case markerViewing
}

private enum TimeframePanelLayoutDefaults {
    static let defaultHeight: CGFloat = 140
    static let minHeight: CGFloat = 80
    static let maxHeight: CGFloat = 250
    static let maxHeightWithTwoPanels: CGFloat = 180
}

@MainActor
final class TimeframePanelEntry: ObservableObject, Identifiable {
    let id: UUID
    let source: TimeframePanelSource
    let timeframe: RLChartTimeframe
    let dataManager: TimeframePanelDataManager
    let gestureState: TimeframePanelGestureState

    @Published var currentHeight: CGFloat
    @Published var expandedHeight: CGFloat
    @Published var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        source: TimeframePanelSource,
        timeframe: RLChartTimeframe,
        dataManager: TimeframePanelDataManager,
        gestureState: TimeframePanelGestureState,
        initialHeight: CGFloat = TimeframePanelLayoutDefaults.defaultHeight,
        startCollapsed: Bool = false
    ) {
        let clampedHeight = max(TimeframePanelLayoutDefaults.minHeight, initialHeight)

        self.id = id
        self.source = source
        self.timeframe = timeframe
        self.dataManager = dataManager
        self.gestureState = gestureState
        self.currentHeight = startCollapsed ? 0 : clampedHeight
        self.expandedHeight = clampedHeight
        self.isCollapsed = startCollapsed
    }

    func resetPresentationState(
        initialHeight: CGFloat = TimeframePanelLayoutDefaults.defaultHeight
    ) {
        let clampedHeight = max(TimeframePanelLayoutDefaults.minHeight, initialHeight)
        currentHeight = clampedHeight
        expandedHeight = clampedHeight
        isCollapsed = false
    }

    func collapse(minHeight: CGFloat = TimeframePanelLayoutDefaults.minHeight) {
        guard !isCollapsed else { return }
        expandedHeight = max(minHeight, currentHeight)
        currentHeight = 0
        isCollapsed = true
    }

    func expand(
        minHeight: CGFloat = TimeframePanelLayoutDefaults.minHeight,
        maxHeight: CGFloat = TimeframePanelLayoutDefaults.maxHeight
    ) {
        let restoredHeight = expandedHeight > 0 ? expandedHeight : minHeight
        let clampedHeight = min(maxHeight, max(minHeight, restoredHeight))
        currentHeight = clampedHeight
        expandedHeight = clampedHeight
        isCollapsed = false
    }

    func setHeight(
        _ height: CGFloat,
        minHeight: CGFloat = TimeframePanelLayoutDefaults.minHeight,
        maxHeight: CGFloat = TimeframePanelLayoutDefaults.maxHeight
    ) {
        let clampedHeight = min(maxHeight, max(minHeight, height))
        currentHeight = clampedHeight
        expandedHeight = clampedHeight
        isCollapsed = false
    }

    func clampPresentation(
        minHeight: CGFloat = TimeframePanelLayoutDefaults.minHeight,
        maxHeight: CGFloat = TimeframePanelLayoutDefaults.maxHeight
    ) {
        if isCollapsed {
            expandedHeight = min(maxHeight, max(minHeight, expandedHeight > 0 ? expandedHeight : minHeight))
            currentHeight = 0
            return
        }

        let sourceHeight = currentHeight > 0 ? currentHeight : expandedHeight
        let clampedHeight = min(maxHeight, max(minHeight, sourceHeight))
        currentHeight = clampedHeight
        expandedHeight = clampedHeight
    }
}

@MainActor
final class TimeframePanelManager: ObservableObject {

    // MARK: - Constants

    static let maxPanels = 2
    static let defaultPanelHeight: CGFloat = TimeframePanelLayoutDefaults.defaultHeight
    static let minPanelHeight: CGFloat = TimeframePanelLayoutDefaults.minHeight
    static let maxPanelHeight: CGFloat = TimeframePanelLayoutDefaults.maxHeight
    static let maxPanelHeightWith2: CGFloat = TimeframePanelLayoutDefaults.maxHeightWithTwoPanels

    // MARK: - Published

    @Published private(set) var activeSource: TimeframePanelSource = .chartDefaults
    @Published private var panelsBySource: [TimeframePanelSource: [TimeframePanelEntry]] = [:]

    // MARK: - Private

    var api: RealAPIService
    private var panelSubscriptions: [UUID: AnyCancellable] = [:]

    // MARK: - Init

    init(api: RealAPIService = RealAPIService()) {
        self.api = api
        self.panelsBySource = Dictionary(
            uniqueKeysWithValues: TimeframePanelSource.allCases.map { ($0, []) }
        )
    }

    // MARK: - Computed

    var panels: [TimeframePanelEntry] { panels(for: activeSource) }
    var hasActivePanels: Bool { !panels.isEmpty }
    var activePanelCount: Int { panels.count }

    var adjustedMaxHeight: CGFloat {
        panels.count > 1 ? Self.maxPanelHeightWith2 : Self.maxPanelHeight
    }

    // MARK: - Source Management

    func setActiveSource(_ source: TimeframePanelSource) {
        guard activeSource != source else { return }
        activeSource = source
    }

    func panels(for source: TimeframePanelSource) -> [TimeframePanelEntry] {
        panelsBySource[source] ?? []
    }

    func clearPanels(for source: TimeframePanelSource) {
        let removed = panels(for: source)
        removed.forEach(removeSubscription(for:))
        panelsBySource[source] = []
    }

    func replacePanels(
        for source: TimeframePanelSource,
        backendValues: [String],
        symbolId: UUID?,
        guildId: UUID?,
        resetPresentationState: Bool = false
    ) {
        let requestedTimeframes = normalizedRequestedTimeframes(from: backendValues)

        let existingPanels = panels(for: source)
        let existingByTimeframe = Dictionary(uniqueKeysWithValues: existingPanels.map { ($0.timeframe, $0) })
        var nextPanels: [TimeframePanelEntry] = []

        for timeframe in requestedTimeframes {
            if let existing = existingByTimeframe[timeframe] {
                if resetPresentationState {
                    existing.resetPresentationState()
                }
                nextPanels.append(existing)
            } else {
                let entry = TimeframePanelEntry(
                    source: source,
                    timeframe: timeframe,
                    dataManager: TimeframePanelDataManager(timeframe: timeframe, api: api),
                    gestureState: TimeframePanelGestureState()
                )
                nextPanels.append(entry)
                subscribe(to: entry)
            }
        }

        let nextIDs = Set(nextPanels.map(\.id))
        for stale in existingPanels where !nextIDs.contains(stale.id) {
            removeSubscription(for: stale)
        }

        let sourceMaxHeight = maxHeight(forPanelCount: nextPanels.count)
        nextPanels.forEach {
            if resetPresentationState {
                $0.resetPresentationState(initialHeight: Self.defaultPanelHeight)
            }
            $0.clampPresentation(maxHeight: sourceMaxHeight)
        }

        panelsBySource[source] = nextPanels

        guard let symbolId, let guildId else { return }
        for panel in nextPanels {
            Task { @MainActor in
                await panel.dataManager.loadCandles(symbolId: symbolId, guildId: guildId)
            }
        }
    }

    // MARK: - Helpers

    private func maxHeight(forPanelCount panelCount: Int) -> CGFloat {
        panelCount > 1 ? Self.maxPanelHeightWith2 : Self.maxPanelHeight
    }

    private func normalizedRequestedTimeframes(from backendValues: [String]) -> [RLChartTimeframe] {
        var seen = Set<RLChartTimeframe>()
        var requested: [RLChartTimeframe] = []

        for value in backendValues {
            guard let timeframe = RLChartTimeframe.fromBackendString(value),
                  !seen.contains(timeframe) else {
                continue
            }
            seen.insert(timeframe)
            requested.append(timeframe)
            if requested.count == Self.maxPanels {
                break
            }
        }

        return requested
    }

    private func subscribe(to entry: TimeframePanelEntry) {
        guard panelSubscriptions[entry.id] == nil else { return }
        panelSubscriptions[entry.id] = entry.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func removeSubscription(for entry: TimeframePanelEntry) {
        panelSubscriptions[entry.id]?.cancel()
        panelSubscriptions[entry.id] = nil
    }
}
