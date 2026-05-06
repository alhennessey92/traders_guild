import SwiftUI

struct MarkerPlacementPanel: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?
    let onCancel: (() -> Void)?
    let onPlace: (() -> Void)?
    let viewportAnchorProvider: (() -> (time: Date, price: Double)?)?

    init(
        placementState: MarkerPlacementState,
        activeChartIndicators: [IndicatorPayload] = [],
        activeChartDrawings: [ChartDrawing] = [],
        currentChartTimeframe: RLChartTimeframe? = nil,
        onSelectTimeframe: ((RLChartTimeframe) -> Void)? = nil,
        onBeginInteractiveDrawing: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onPlace: (() -> Void)? = nil,
        viewportAnchorProvider: (() -> (time: Date, price: Double)?)? = nil
    ) {
        self.placementState = placementState
        self.activeChartIndicators = activeChartIndicators
        self.activeChartDrawings = activeChartDrawings
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframe = onSelectTimeframe
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.onCancel = onCancel
        self.onPlace = onPlace
        self.viewportAnchorProvider = viewportAnchorProvider
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
                        activeChartDrawings: activeChartDrawings,
                        currentChartTimeframe: currentChartTimeframe,
                        onSelectTimeframeAction: onSelectTimeframe,
                        onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                        showsMirrorButtons: true,
                        viewportAnchorProvider: viewportAnchorProvider
                    )
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

}
