import SwiftUI
import Combine

@MainActor
protocol ComponentsHostAdapter {
    var placementState: MarkerPlacementState { get }
    var activeChartIndicators: [IndicatorPayload] { get }
    var activeChartDrawings: [ChartDrawing] { get }
    var currentChartTimeframe: RLChartTimeframe? { get }
    var onBeginInteractiveDrawing: (() -> Void)? { get }
    var timeframePanelManager: TimeframePanelManager? { get }
    var symbolId: UUID? { get }
    var guildId: UUID? { get }
    var showsMirrorButtons: Bool { get }

    func selectTimeframe(_ timeframe: RLChartTimeframe)
}

@MainActor
struct UnifiedComponentsHostView<Adapter: ComponentsHostAdapter>: View {
    let adapter: Adapter

    var body: some View {
        MarkerPlacementComponentsTab(
            placementState: adapter.placementState,
            activeChartIndicators: adapter.activeChartIndicators,
            activeChartDrawings: adapter.activeChartDrawings,
            currentChartTimeframe: adapter.currentChartTimeframe,
            onSelectTimeframe: { timeframe in
                adapter.selectTimeframe(timeframe)
            },
            onBeginInteractiveDrawing: adapter.onBeginInteractiveDrawing,
            timeframePanelManager: adapter.timeframePanelManager,
            symbolId: adapter.symbolId,
            guildId: adapter.guildId,
            showsMirrorButtons: adapter.showsMirrorButtons
        )
    }
}

@MainActor
struct MarkerComponentsAdapter: ComponentsHostAdapter {
    let placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframeAction: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?
    let timeframePanelManager: TimeframePanelManager?
    let symbolId: UUID?
    let guildId: UUID?
    let showsMirrorButtons: Bool

    init(
        placementState: MarkerPlacementState,
        activeChartIndicators: [IndicatorPayload],
        activeChartDrawings: [ChartDrawing] = [],
        currentChartTimeframe: RLChartTimeframe?,
        onSelectTimeframeAction: ((RLChartTimeframe) -> Void)?,
        onBeginInteractiveDrawing: (() -> Void)?,
        timeframePanelManager: TimeframePanelManager?,
        symbolId: UUID?,
        guildId: UUID?,
        showsMirrorButtons: Bool = true
    ) {
        self.placementState = placementState
        self.activeChartIndicators = activeChartIndicators
        self.activeChartDrawings = activeChartDrawings
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframeAction = onSelectTimeframeAction
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.timeframePanelManager = timeframePanelManager
        self.symbolId = symbolId
        self.guildId = guildId
        self.showsMirrorButtons = showsMirrorButtons
    }

    func selectTimeframe(_ timeframe: RLChartTimeframe) {
        onSelectTimeframeAction?(timeframe)
    }
}

@MainActor
final class ChartComponentsAdapter: ObservableObject, ComponentsHostAdapter {
    let placementState: MarkerPlacementState

    private let indicatorManager: IndicatorManager
    private let drawingManager: ChartDrawingManager
    private let timeframeLinkManager: ChartTimeframeLinkManager
    private let onRecalculate: () -> Void
    private let onSelectTimeframeAction: ((RLChartTimeframe) -> Void)?

    var onBeginInteractiveDrawing: (() -> Void)?
    var timeframePanelManager: TimeframePanelManager?
    private(set) var symbolId: UUID?
    private(set) var guildId: UUID?
    private(set) var currentChartTimeframe: RLChartTimeframe?
    private var anchorTime: Date
    private var anchorPrice: Double

    var showsMirrorButtons: Bool { false }

    var activeChartIndicators: [IndicatorPayload] {
        MarkerPlacementIndicatorFactory.activePayloads(from: indicatorManager.activeIndicators)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var activeChartDrawings: [ChartDrawing] {
        drawingManager.activeDrawings
    }

    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromHost = false
    private var isApplyingToHost = false
    private var syncFromHostScheduled = false
    private var applyToHostScheduled = false
    private var indicatorIDsByName: [String: UUID] = [:]
    private var timeframeIDsByBackend: [String: UUID] = [:]

    init(
        placementState: MarkerPlacementState,
        indicatorManager: IndicatorManager,
        drawingManager: ChartDrawingManager,
        timeframeLinkManager: ChartTimeframeLinkManager,
        currentChartTimeframe: RLChartTimeframe?,
        onSelectTimeframeAction: ((RLChartTimeframe) -> Void)?,
        onRecalculate: @escaping () -> Void,
        onBeginInteractiveDrawing: (() -> Void)?,
        timeframePanelManager: TimeframePanelManager?,
        symbolId: UUID?,
        guildId: UUID?,
        anchorTime: Date?,
        anchorPrice: Double?
    ) {
        self.placementState = placementState
        self.indicatorManager = indicatorManager
        self.drawingManager = drawingManager
        self.timeframeLinkManager = timeframeLinkManager
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframeAction = onSelectTimeframeAction
        self.onRecalculate = onRecalculate
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.timeframePanelManager = timeframePanelManager
        self.symbolId = symbolId
        self.guildId = guildId
        self.anchorTime = anchorTime ?? Date()
        self.anchorPrice = anchorPrice ?? 0

        timeframeLinkManager.symbolId = symbolId
        placementState.intent = .analysis
        setupSubscriptions()
        syncFromHost()
        reconcileTimeframePanels(
            previousLinks: [],
            currentLinks: timeframeLinkManager.linkedTimeframes,
            forceReload: true
        )
    }

    func selectTimeframe(_ timeframe: RLChartTimeframe) {
        currentChartTimeframe = timeframe
        onSelectTimeframeAction?(timeframe)
    }

    func updateContext(
        currentChartTimeframe: RLChartTimeframe?,
        timeframePanelManager: TimeframePanelManager?,
        symbolId: UUID?,
        guildId: UUID?,
        anchorTime: Date?,
        anchorPrice: Double?
    ) {
        let previousPanelManager = self.timeframePanelManager
        let previousGuildId = self.guildId
        let previousTimeframe = self.currentChartTimeframe
        let previousSymbol = self.symbolId

        self.currentChartTimeframe = currentChartTimeframe
        self.timeframePanelManager = timeframePanelManager
        self.guildId = guildId
        if let anchorTime { self.anchorTime = anchorTime }
        if let anchorPrice { self.anchorPrice = anchorPrice }

        self.symbolId = symbolId
        var previousLinks = timeframeLinkManager.linkedTimeframes
        let didSwitchSymbol = previousSymbol != symbolId
        let didChangePanelManager = previousPanelManager !== timeframePanelManager
        let didChangeGuild = previousGuildId != guildId
        let didChangeTimeframe = previousTimeframe != currentChartTimeframe

        guard didSwitchSymbol || didChangePanelManager || didChangeGuild || didChangeTimeframe else {
            return
        }

        if previousSymbol != symbolId {
            timeframePanelManager?.clearAll()
            timeframeLinkManager.symbolId = symbolId
            syncFromHost()
            previousLinks = []
        }
        if didChangePanelManager {
            previousLinks = []
        }

        reconcileTimeframePanels(
            previousLinks: previousLinks,
            currentLinks: timeframeLinkManager.linkedTimeframes,
            forceReload: didSwitchSymbol || didChangePanelManager || didChangeGuild || didChangeTimeframe
        )
    }

    private func setupSubscriptions() {
        indicatorManager.$activeIndicators
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingToHost else { return }
                self.scheduleSyncFromHost()
            }
            .store(in: &cancellables)

        timeframeLinkManager.$linkedTimeframes
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingToHost else { return }
                self.scheduleSyncFromHost()
            }
            .store(in: &cancellables)

        placementState.$components
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isSyncingFromHost else { return }
                self.scheduleApplyToHost()
            }
            .store(in: &cancellables)
    }

    private func scheduleSyncFromHost() {
        guard !syncFromHostScheduled else { return }
        syncFromHostScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncFromHostScheduled = false
            self.syncFromHostIfNeeded()
        }
    }

    private func scheduleApplyToHost() {
        guard !applyToHostScheduled else { return }
        applyToHostScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyToHostScheduled = false
            self.applyToHostIfNeeded()
        }
    }

    private func syncFromHostIfNeeded() {
        guard !isApplyingToHost else { return }
        syncFromHost()
    }

    private func syncFromHost() {
        isSyncingFromHost = true
        defer { isSyncingFromHost = false }

        let preservedDrawingComponents = placementState.components.filter {
            isChartDrawingPlacementComponent($0.componentType)
        }
        var nextComponents: [MarkerComponentDraft] = [anchorDraft()]
        nextComponents.append(contentsOf: indicatorDraftsFromHost())
        nextComponents.append(contentsOf: preservedDrawingComponents)
        nextComponents.append(contentsOf: timeframeDraftsFromHost())
        placementState.components = nextComponents
    }

    private func applyToHostIfNeeded() {
        guard !isSyncingFromHost else { return }
        applyToHost()
    }

    private func applyToHost() {
        isApplyingToHost = true
        defer { isApplyingToHost = false }

        if let anchor = placementState.anchorDraft,
           case let .anchor(payload) = anchor.payload {
            anchorTime = payload.time
            anchorPrice = payload.price
        }

        let indicatorPayloads = placementState.indicatorDrafts.compactMap { draft -> IndicatorPayload? in
            guard case let .indicator(payload) = draft.payload else { return nil }
            return payload
        }
        if indicatorSyncSignature(for: indicatorPayloads) != indicatorSyncSignature(for: activeChartIndicators) {
            applyIndicatorPayloads(indicatorPayloads)
        }

        let oldLinks = timeframeLinkManager.linkedTimeframes
        let newLinks = placementState.timeframeLinkDrafts.compactMap { draft -> String? in
            guard case let .timeframeLink(payload) = draft.payload else { return nil }
            return payload.timeframe
        }
        if timeframeSyncSignature(for: oldLinks) != timeframeSyncSignature(for: newLinks) {
            timeframeLinkManager.setLinkedTimeframes(newLinks)
            let currentLinks = timeframeLinkManager.linkedTimeframes
            reconcileTimeframePanels(previousLinks: oldLinks, currentLinks: currentLinks)
            if oldLinks != currentLinks {
                // Keep Active tab and linked-timeframe drafts aligned with the persisted chart link state.
                syncFromHost()
            }
        }
    }

    private func applyIndicatorPayloads(_ payloads: [IndicatorPayload]) {
        let sortedPayloads = payloads.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let components = sortedPayloads.enumerated().map { index, payload in
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.indicator.rawValue,
                payload: .indicator(payload),
                ordering: index
            )
        }
        indicatorManager.applyMarkerIndicators(components)
        onRecalculate()
    }

    private func anchorDraft() -> MarkerComponentDraft {
        let existingID = placementState.anchorDraft?.id ?? UUID()
        return MarkerComponentDraft(
            id: existingID,
            componentType: .anchor,
            payload: .anchor(AnchorPayload(time: anchorTime, price: anchorPrice))
        )
    }

    private func indicatorDraftsFromHost() -> [MarkerComponentDraft] {
        activeChartIndicators.map { payload in
            let key = normalizedIndicatorKey(payload.name)
            let id = indicatorIDsByName[key] ?? UUID()
            indicatorIDsByName[key] = id
            return MarkerComponentDraft(
                id: id,
                componentType: .indicator,
                payload: .indicator(payload)
            )
        }
    }

    private func normalizedIndicatorKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func indicatorSyncSignature(for payloads: [IndicatorPayload]) -> [String] {
        let encoder = JSONEncoder()
        return payloads
            .map { payload in
                let encoded = (try? encoder.encode(payload))
                    .flatMap { String(data: $0, encoding: .utf8) }
                    ?? payload.name
                return "\(payload.name.uppercased())|\(encoded)"
            }
            .sorted()
    }

    private func timeframeSyncSignature(for values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .sorted()
    }

    private func isChartDrawingPlacementComponent(_ componentType: RLComponentType) -> Bool {
        switch componentType {
        case .drawingTrendline,
             .drawingHorizontalLine,
             .drawingZone,
             .levelSupport,
             .levelResistance,
             .textNote,
             .reactionEmoji:
            return true
        default:
            return false
        }
    }

    private func drawingDraftsToChartDrawings(_ components: [MarkerComponentDraft]) -> [ChartDrawing] {
        components.compactMap { draft in
            ChartDrawingBridge.chartDrawing(from: draft, anchorTime: anchorTime, anchorPrice: anchorPrice)
        }
    }

    private func timeframeDraftsFromHost() -> [MarkerComponentDraft] {
        timeframeLinkManager.linkedTimeframes.map { backendValue in
            let normalized = backendValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let id = timeframeIDsByBackend[normalized] ?? UUID()
            timeframeIDsByBackend[normalized] = id
            return MarkerComponentDraft(
                id: id,
                componentType: .timeframeLink,
                payload: .timeframeLink(TimeframeLinkPayload(timeframe: normalized, note: nil))
            )
        }
    }

    private func reconcileTimeframePanels(
        previousLinks: [String],
        currentLinks: [String],
        forceReload: Bool = false
    ) {
        guard let timeframePanelManager else { return }

        let previousFrames = Set(previousLinks.compactMap { RLChartTimeframe.fromBackendString($0) })
        let currentFrames = Set(currentLinks.compactMap { RLChartTimeframe.fromBackendString($0) })

        for timeframe in previousFrames.subtracting(currentFrames) {
            timeframePanelManager.removePanel(timeframe: timeframe)
        }

        if let symbolId, let guildId {
            for timeframe in currentFrames.subtracting(previousFrames) {
                timeframePanelManager.addPanel(timeframe: timeframe, symbolId: symbolId, guildId: guildId)
            }

            if forceReload || !timeframePanelManager.panels.isEmpty {
                timeframePanelManager.reloadAll(symbolId: symbolId, guildId: guildId)
            }
        }
    }
}
