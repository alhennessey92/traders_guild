import SwiftUI

struct ChartComponentsContent: View {
    let indicatorManager: IndicatorManager
    let drawingManager: ChartDrawingManager
    let timeframeLinkManager: ChartTimeframeLinkManager
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onRecalculate: () -> Void
    let onBeginInteractiveDrawing: (() -> Void)?
    let timeframePanelManager: TimeframePanelManager?
    let symbolId: UUID?
    let guildId: UUID?
    let anchorTime: Date?
    let anchorPrice: Double?

    @StateObject private var adapter: ChartComponentsAdapter

    init(
        indicatorManager: IndicatorManager,
        drawingManager: ChartDrawingManager,
        timeframeLinkManager: ChartTimeframeLinkManager,
        currentChartTimeframe: RLChartTimeframe?,
        onSelectTimeframe: ((RLChartTimeframe) -> Void)?,
        onRecalculate: @escaping () -> Void,
        onBeginInteractiveDrawing: (() -> Void)? = nil,
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
        self.onSelectTimeframe = onSelectTimeframe
        self.onRecalculate = onRecalculate
        self.onBeginInteractiveDrawing = onBeginInteractiveDrawing
        self.timeframePanelManager = timeframePanelManager
        self.symbolId = symbolId
        self.guildId = guildId
        self.anchorTime = anchorTime
        self.anchorPrice = anchorPrice

        _adapter = StateObject(
            wrappedValue: ChartComponentsAdapter(
                indicatorManager: indicatorManager,
                drawingManager: drawingManager,
                timeframeLinkManager: timeframeLinkManager,
                currentChartTimeframe: currentChartTimeframe,
                onSelectTimeframeAction: onSelectTimeframe,
                onRecalculate: onRecalculate,
                onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                timeframePanelManager: timeframePanelManager,
                symbolId: symbolId,
                guildId: guildId,
                anchorTime: anchorTime,
                anchorPrice: anchorPrice
            )
        )
    }

    var body: some View {
        UnifiedComponentsHostView(adapter: adapter)
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
            .onAppear(perform: refreshAdapterContext)
            .onChange(of: currentChartTimeframe) {
                refreshAdapterContext()
            }
            .onChange(of: symbolId) {
                refreshAdapterContext()
            }
            .onChange(of: guildId) {
                refreshAdapterContext()
            }
            .onChange(of: anchorTime) {
                refreshAdapterContext()
            }
            .onChange(of: anchorPrice) {
                refreshAdapterContext()
            }
    }

    private func refreshAdapterContext() {
        adapter.updateContext(
            currentChartTimeframe: currentChartTimeframe,
            timeframePanelManager: timeframePanelManager,
            symbolId: symbolId,
            guildId: guildId,
            anchorTime: anchorTime,
            anchorPrice: anchorPrice
        )
    }
}
