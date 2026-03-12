import SwiftUI
import Combine

@MainActor
protocol ComponentsHostAdapter {
    var placementState: MarkerPlacementState { get }
    var activeChartIndicators: [IndicatorPayload] { get }
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
    let placementState = MarkerPlacementState()

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

    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromHost = false
    private var isApplyingToHost = false
    private var syncFromHostScheduled = false
    private var applyToHostScheduled = false
    private var indicatorIDsByName: [String: UUID] = [:]
    private var timeframeIDsByBackend: [String: UUID] = [:]

    init(
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

        drawingManager.$drawings
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

        var nextComponents: [MarkerComponentDraft] = [anchorDraft()]
        nextComponents.append(contentsOf: indicatorDraftsFromHost())
        nextComponents.append(contentsOf: drawingDraftsFromHost())
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
        applyIndicatorPayloads(indicatorPayloads)

        let updatedDrawings = drawingDraftsToChartDrawings(placementState.components)
        drawingManager.setDrawings(updatedDrawings)

        let oldLinks = timeframeLinkManager.linkedTimeframes
        let newLinks = placementState.timeframeLinkDrafts.compactMap { draft -> String? in
            guard case let .timeframeLink(payload) = draft.payload else { return nil }
            return payload.timeframe
        }
        timeframeLinkManager.setLinkedTimeframes(newLinks)
        let currentLinks = timeframeLinkManager.linkedTimeframes
        reconcileTimeframePanels(previousLinks: oldLinks, currentLinks: currentLinks)
        if oldLinks != currentLinks {
            // Keep Active tab and linked-timeframe drafts aligned with the persisted chart link state.
            syncFromHost()
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

    private func drawingDraftsFromHost() -> [MarkerComponentDraft] {
        drawingManager.drawings.map { drawing in
            markerDraft(from: drawing)
        }
    }

    private func markerDraft(from drawing: ChartDrawing) -> MarkerComponentDraft {
        switch drawing.type {
        case .trendline:
            let first = drawing.points.first ?? ChartDrawingPoint(time: anchorTime, price: anchorPrice)
            let second = drawing.points.dropFirst().first ?? ChartDrawingPoint(
                time: first.time.addingTimeInterval(30 * 60),
                price: first.price
            )
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingTrendline,
                payload: .drawingTrendline(
                    TrendlinePayload(
                        startTime: first.time,
                        startPrice: first.price,
                        endTime: second.time,
                        endPrice: second.price,
                        colorHex: drawing.colorHex
                    )
                )
            )
        case .horizontalLine:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingHorizontalLine,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: price,
                        label: drawing.note,
                        colorHex: drawing.colorHex
                    )
                )
            )
        case .zone:
            let topPrice = drawing.points.first?.price ?? anchorPrice
            let bottomPrice = drawing.points.dropFirst().first?.price ?? anchorPrice
            let startTime = drawing.points.first?.time ?? anchorTime
            let endTime = drawing.points.dropFirst().first?.time ?? anchorTime
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingZone,
                payload: .drawingZone(
                    ZonePayload(
                        topPrice: max(topPrice, bottomPrice),
                        bottomPrice: min(topPrice, bottomPrice),
                        startTime: startTime,
                        endTime: endTime,
                        colorHex: drawing.colorHex
                    )
                )
            )
        case .supportLevel:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .levelSupport,
                payload: .levelSupport(LevelPayload(price: price, label: drawing.note))
            )
        case .resistanceLevel:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .levelResistance,
                payload: .levelResistance(LevelPayload(price: price, label: drawing.note))
            )
        case .textNote:
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .textNote,
                payload: .note(NotePayload(text: drawing.note ?? "Add your context"))
            )
        case .emoji:
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .reactionEmoji,
                payload: .reactionEmoji(EmojiPayload(emoji: drawing.emoji ?? "🎯"))
            )
        }
    }

    private func drawingDraftsToChartDrawings(_ components: [MarkerComponentDraft]) -> [ChartDrawing] {
        components.compactMap { draft in
            switch draft.payload {
            case let .drawingTrendline(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .trendline,
                    points: [
                        ChartDrawingPoint(time: payload.startTime, price: payload.startPrice),
                        ChartDrawingPoint(time: payload.endTime, price: payload.endPrice),
                    ],
                    colorHex: payload.colorHex ?? ChartDrawingType.trendline.defaultColorHex
                )
            case let .drawingHorizontalLine(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .horizontalLine,
                    points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                    colorHex: payload.colorHex ?? ChartDrawingType.horizontalLine.defaultColorHex,
                    note: payload.label
                )
            case let .drawingZone(payload):
                let start = payload.startTime ?? anchorTime
                let end = payload.endTime ?? anchorTime
                return ChartDrawing(
                    id: draft.id,
                    type: .zone,
                    points: [
                        ChartDrawingPoint(time: start, price: payload.topPrice),
                        ChartDrawingPoint(time: end, price: payload.bottomPrice),
                    ],
                    colorHex: payload.colorHex ?? ChartDrawingType.zone.defaultColorHex
                )
            case let .levelSupport(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .supportLevel,
                    points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                    colorHex: ChartDrawingType.supportLevel.defaultColorHex,
                    note: payload.label
                )
            case let .levelResistance(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .resistanceLevel,
                    points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                    colorHex: ChartDrawingType.resistanceLevel.defaultColorHex,
                    note: payload.label
                )
            case let .note(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .textNote,
                    colorHex: ChartDrawingType.textNote.defaultColorHex,
                    note: payload.text
                )
            case let .reactionEmoji(payload):
                return ChartDrawing(
                    id: draft.id,
                    type: .emoji,
                    colorHex: ChartDrawingType.emoji.defaultColorHex,
                    emoji: payload.emoji
                )
            default:
                return nil
            }
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
