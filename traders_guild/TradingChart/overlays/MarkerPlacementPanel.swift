import SwiftUI

struct MarkerPlacementPanel: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?
    let onCancel: (() -> Void)?
    let onPlace: (() -> Void)?
    var timeframePanelManager: TimeframePanelManager?
    var symbolId: UUID?
    var guildId: UUID?

    init(
        placementState: MarkerPlacementState,
        activeChartIndicators: [IndicatorPayload] = [],
        currentChartTimeframe: RLChartTimeframe? = nil,
        onSelectTimeframe: ((RLChartTimeframe) -> Void)? = nil,
        onBeginInteractiveDrawing: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onPlace: (() -> Void)? = nil,
        timeframePanelManager: TimeframePanelManager? = nil,
        symbolId: UUID? = nil,
        guildId: UUID? = nil
    ) {
        self.placementState = placementState
        self.activeChartIndicators = activeChartIndicators
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframe = onSelectTimeframe
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.onCancel = onCancel
        self.onPlace = onPlace
        self.timeframePanelManager = timeframePanelManager
        self.symbolId = symbolId
        self.guildId = guildId
    }

    var body: some View {
        VStack(spacing: 0) {
            switch placementState.selectedPlacementTab {
            case .general:
                MarkerPlacementGeneralTab(placementState: placementState)
            case .components:
                UnifiedComponentsHostView(
                    adapter: MarkerComponentsAdapter(
                        placementState: placementState,
                        activeChartIndicators: activeChartIndicators,
                        currentChartTimeframe: currentChartTimeframe,
                        onSelectTimeframeAction: onSelectTimeframe,
                        onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                        timeframePanelManager: timeframePanelManager,
                        symbolId: symbolId,
                        guildId: guildId,
                        showsMirrorButtons: true
                    )
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

}
