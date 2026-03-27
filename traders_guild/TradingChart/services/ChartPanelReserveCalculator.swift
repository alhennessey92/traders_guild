import CoreGraphics

enum ChartPanelStackOwner: Equatable {
    case timeframe(index: Int)
    case indicator(index: Int)
}

struct CombinedChartPanelLayout: Equatable {
    let totalReserve: CGFloat
    let bottomBoundaryLabelReserve: CGFloat
    let bottomOwner: ChartPanelStackOwner?
}

enum ChartPanelReserveCalculator {
    static let panelResizeHandleHeight: CGFloat = 22
    static let panelXAxisLabelStripHeight: CGFloat = 24
    /// Heights below this are treated as collapsed to avoid sub-pixel UI jitter.
    static let expandedPanelHeightThreshold: CGFloat = 2

    private static func effectivePanelHeight(_ rawHeight: CGFloat) -> CGFloat {
        let clamped = max(0, rawHeight)
        guard clamped >= expandedPanelHeightThreshold else { return 0 }
        return clamped.rounded(.toNearestOrAwayFromZero)
    }

    private static func bottomExpandedPanelIndex(in panelHeights: [CGFloat]) -> Int? {
        for (index, height) in panelHeights.enumerated().reversed() {
            if effectivePanelHeight(height) > 0 {
                return index
            }
        }
        return nil
    }

    static func combinedLayout(
        timeframePanelHeights: [CGFloat],
        indicatorPanelHeights: [CGFloat]
    ) -> CombinedChartPanelLayout {
        let effectiveTimeframeHeights = timeframePanelHeights.map(effectivePanelHeight)
        let effectiveIndicatorHeights = indicatorPanelHeights.map(effectivePanelHeight)

        var totalReserve = effectiveTimeframeHeights.reduce(0) { partial, height in
            partial + height + panelResizeHandleHeight
        }
        totalReserve += effectiveIndicatorHeights.reduce(0) { partial, height in
            partial + height + panelResizeHandleHeight
        }

        let bottomOwner: ChartPanelStackOwner?
        if let indicatorIndex = bottomExpandedPanelIndex(in: indicatorPanelHeights) {
            bottomOwner = .indicator(index: indicatorIndex)
        } else if let timeframeIndex = bottomExpandedPanelIndex(in: timeframePanelHeights) {
            bottomOwner = .timeframe(index: timeframeIndex)
        } else {
            bottomOwner = nil
        }

        if bottomOwner != nil {
            totalReserve += panelXAxisLabelStripHeight
        }

        let bottomBoundaryLabelReserve: CGFloat
        switch bottomOwner {
        case .indicator:
            bottomBoundaryLabelReserve = panelXAxisLabelStripHeight
        case .timeframe, .none:
            bottomBoundaryLabelReserve = 0
        }

        return CombinedChartPanelLayout(
            totalReserve: totalReserve,
            bottomBoundaryLabelReserve: bottomBoundaryLabelReserve,
            bottomOwner: bottomOwner
        )
    }

    /// Height reserve for a panel stack.
    /// Includes each panel's resize handle and includes a label strip only when
    /// the last expanded panel in the stack is visible.
    static func stackReserve(panelHeights: [CGFloat]) -> CGFloat {
        guard !panelHeights.isEmpty else { return 0 }

        let visibleHeights = panelHeights.map(effectivePanelHeight)
        var total = visibleHeights.reduce(0) { partial, height in
            partial + height + panelResizeHandleHeight
        }

        if bottomExpandedPanelIndex(in: panelHeights) != nil {
            total += panelXAxisLabelStripHeight
        }

        return total
    }

    /// Label strip reserve that sits at the chart/panel boundary.
    /// Only the bottom-most visible panel stack contributes this reserve.
    static func bottomBoundaryLabelReserve(
        indicatorPanelHeights: [CGFloat],
        timeframePanelHeights: [CGFloat]
    ) -> CGFloat {
        combinedLayout(
            timeframePanelHeights: timeframePanelHeights,
            indicatorPanelHeights: indicatorPanelHeights
        ).bottomBoundaryLabelReserve
    }

    /// Removes only the bottom-boundary label strip reserve from a combined panel reserve.
    static func normalizedPanelReserve(
        totalPanelReserve: CGFloat,
        bottomBoundaryLabelReserve: CGFloat
    ) -> CGFloat {
        guard totalPanelReserve > 0 else { return 0 }
        return max(0, totalPanelReserve - bottomBoundaryLabelReserve)
            .rounded(.toNearestOrAwayFromZero)
    }
}
