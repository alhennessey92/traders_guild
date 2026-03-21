import SwiftUI

struct ChartComponentsContent: View {
    @StateObject private var adapter: ChartComponentsAdapter
    let currentChartTimeframe: RLChartTimeframe?
    let symbolId: UUID?
    let anchorTime: Date?
    let anchorPrice: Double?

    init(
        placementState: MarkerPlacementState,
        indicatorManager: IndicatorManager,
        drawingManager: ChartDrawingManager,
        timeframeLinkManager: ChartTimeframeLinkManager,
        currentChartTimeframe: RLChartTimeframe?,
        onSelectTimeframe: ((RLChartTimeframe) -> Void)?,
        onRecalculate: @escaping () -> Void,
        onBeginInteractiveDrawing: (() -> Void)? = nil,
        symbolId: UUID?,
        anchorTime: Date?,
        anchorPrice: Double?
    ) {
        self.currentChartTimeframe = currentChartTimeframe
        self.symbolId = symbolId
        self.anchorTime = anchorTime
        self.anchorPrice = anchorPrice
        _adapter = StateObject(
            wrappedValue: ChartComponentsAdapter(
                placementState: placementState,
                indicatorManager: indicatorManager,
                drawingManager: drawingManager,
                timeframeLinkManager: timeframeLinkManager,
                currentChartTimeframe: currentChartTimeframe,
                onSelectTimeframeAction: onSelectTimeframe,
                onRecalculate: onRecalculate,
                onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                symbolId: symbolId,
                anchorTime: anchorTime,
                anchorPrice: anchorPrice
            )
        )
    }

    var body: some View {
        UnifiedComponentsHostView(adapter: adapter)
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
        .onAppear(perform: updateAdapterContext)
        .onChange(of: currentChartTimeframe) { _, _ in
            updateAdapterContext()
        }
        .onChange(of: symbolId) { _, _ in
            updateAdapterContext()
        }
        .onChange(of: anchorTime) { _, _ in
            updateAdapterContext()
        }
        .onChange(of: anchorPrice) { _, _ in
            updateAdapterContext()
        }
    }

    private func updateAdapterContext() {
        adapter.updateContext(
            currentChartTimeframe: currentChartTimeframe,
            symbolId: symbolId,
            anchorTime: anchorTime,
            anchorPrice: anchorPrice
        )
    }
}
