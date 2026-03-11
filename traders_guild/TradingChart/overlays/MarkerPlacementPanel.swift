import SwiftUI

struct MarkerPlacementPanel: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?
    let onCancel: (() -> Void)?
    let onPlace: (() -> Void)?

    init(
        placementState: MarkerPlacementState,
        activeChartIndicators: [IndicatorPayload] = [],
        currentChartTimeframe: RLChartTimeframe? = nil,
        onSelectTimeframe: ((RLChartTimeframe) -> Void)? = nil,
        onBeginInteractiveDrawing: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onPlace: (() -> Void)? = nil
    ) {
        self.placementState = placementState
        self.activeChartIndicators = activeChartIndicators
        self.currentChartTimeframe = currentChartTimeframe
        self.onSelectTimeframe = onSelectTimeframe
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.onCancel = onCancel
        self.onPlace = onPlace
    }

    var body: some View {
        VStack(spacing: 0) {
            switch placementState.selectedPlacementTab {
            case .general:
                MarkerPlacementGeneralTab(placementState: placementState)
            case .indicators:
                MarkerPlacementIndicatorsTab(
                    placementState: placementState,
                    activeChartIndicators: activeChartIndicators
                )
            case .drawings:
                MarkerPlacementDrawingsTab(
                    placementState: placementState,
                    onBeginInteractiveDrawing: onBeginInteractiveDrawing
                )
            case .timeframes:
                MarkerPlacementTimeframesTab(
                    placementState: placementState,
                    currentChartTimeframe: currentChartTimeframe,
                    onSelectTimeframe: onSelectTimeframe
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

}
