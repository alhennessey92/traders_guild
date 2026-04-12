import SwiftUI
import Combine

struct ChartComponentsSnapshot {
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let currentChartTimeframe: RLChartTimeframe?
}

@MainActor
protocol ComponentsHostAdapter {
    var placementState: MarkerPlacementState { get }
    var activeChartIndicators: [IndicatorPayload] { get }
    var activeChartDrawings: [ChartDrawing] { get }
    var currentChartTimeframe: RLChartTimeframe? { get }
    var onBeginInteractiveDrawing: (() -> Void)? { get }
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
    let showsMirrorButtons: Bool

    init(
        placementState: MarkerPlacementState,
        activeChartIndicators: [IndicatorPayload],
        activeChartDrawings: [ChartDrawing] = [],
        currentChartTimeframe: RLChartTimeframe?,
        onSelectTimeframeAction: ((RLChartTimeframe) -> Void)?,
        onBeginInteractiveDrawing: (() -> Void)?,
        showsMirrorButtons: Bool = true
    ) {
        self.placementState = placementState
        self.activeChartIndicators = activeChartIndicators
        self.activeChartDrawings = activeChartDrawings
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframeAction = onSelectTimeframeAction
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
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
    private(set) var symbolId: UUID?
    @Published private(set) var snapshot: ChartComponentsSnapshot
    private var anchorTime: Date
    private var anchorPrice: Double

    var showsMirrorButtons: Bool { false }

    var activeChartIndicators: [IndicatorPayload] {
        snapshot.activeChartIndicators
    }

    var activeChartDrawings: [ChartDrawing] {
        snapshot.activeChartDrawings
    }

    var currentChartTimeframe: RLChartTimeframe? {
        snapshot.currentChartTimeframe
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
        symbolId: UUID?,
        anchorTime: Date?,
        anchorPrice: Double?
    ) {
        self.placementState = placementState
        self.indicatorManager = indicatorManager
        self.drawingManager = drawingManager
        self.timeframeLinkManager = timeframeLinkManager
        self.onSelectTimeframeAction = onSelectTimeframeAction
        self.onRecalculate = onRecalculate
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.symbolId = symbolId
        self.anchorTime = anchorTime ?? Date()
        self.anchorPrice = anchorPrice ?? 0
        self.snapshot = ChartComponentsSnapshot(
            activeChartIndicators: Self.makeIndicatorPayloads(from: indicatorManager),
            activeChartDrawings: drawingManager.activeDrawings,
            currentChartTimeframe: currentChartTimeframe
        )

        timeframeLinkManager.symbolId = symbolId
        setupSubscriptions()
        scheduleSyncFromHost()
    }

    func selectTimeframe(_ timeframe: RLChartTimeframe) {
        updateSnapshot(currentChartTimeframe: timeframe)
        onSelectTimeframeAction?(timeframe)
    }

    func updateContext(
        currentChartTimeframe: RLChartTimeframe?,
        symbolId: UUID?,
        anchorTime: Date?,
        anchorPrice: Double?
    ) {
        let previousTimeframe = snapshot.currentChartTimeframe
        let previousSymbol = self.symbolId

        if let anchorTime { self.anchorTime = anchorTime }
        if let anchorPrice { self.anchorPrice = anchorPrice }

        self.symbolId = symbolId
        updateSnapshot(currentChartTimeframe: currentChartTimeframe)
        let didSwitchSymbol = previousSymbol != symbolId
        let didChangeTimeframe = previousTimeframe != currentChartTimeframe

        guard didSwitchSymbol || didChangeTimeframe else {
            return
        }

        if previousSymbol != symbolId {
            timeframeLinkManager.symbolId = symbolId
            scheduleSyncFromHost()
        }
    }

    private func setupSubscriptions() {
        indicatorManager.$activeIndicators
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingToHost else { return }
                self.refreshSnapshot()
                self.scheduleSyncFromHost()
            }
            .store(in: &cancellables)

        drawingManager.$drawings
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingToHost else { return }
                self.refreshSnapshot()
            }
            .store(in: &cancellables)

        timeframeLinkManager.$linkedTimeframes
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isApplyingToHost else { return }
                self.refreshSnapshot()
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
        guard !isApplyingToHost, !applyToHostScheduled else { return }
        syncFromHost()
    }

    private func syncFromHost() {
        isSyncingFromHost = true
        defer { isSyncingFromHost = false }
        refreshSnapshot()

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
            if oldLinks != currentLinks {
                // Keep Active tab and linked-timeframe drafts aligned with the persisted chart link state.
                syncFromHost()
            }
        }

        refreshSnapshot()
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
        let linkedTimeframes = timeframeLinkManager.linkedTimeframes.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        timeframeIDsByBackend = timeframeIDsByBackend.filter { linkedTimeframes.contains($0.key) }

        return linkedTimeframes.map { backendValue in
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

    private func refreshSnapshot() {
        updateSnapshot(currentChartTimeframe: snapshot.currentChartTimeframe)
    }

    private func updateSnapshot(currentChartTimeframe: RLChartTimeframe?) {
        snapshot = ChartComponentsSnapshot(
            activeChartIndicators: Self.makeIndicatorPayloads(from: indicatorManager),
            activeChartDrawings: drawingManager.activeDrawings,
            currentChartTimeframe: currentChartTimeframe
        )
    }

    private static func makeIndicatorPayloads(from indicatorManager: IndicatorManager) -> [IndicatorPayload] {
        MarkerPlacementIndicatorFactory.activePayloads(from: indicatorManager.activeIndicators)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
