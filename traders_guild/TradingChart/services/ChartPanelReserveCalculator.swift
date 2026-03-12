import CoreGraphics

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

    /// Height reserve for a panel stack.
    /// Includes each panel's resize handle and includes a label strip only when
    /// the bottom panel is expanded (height > 0).
    static func stackReserve(panelHeights: [CGFloat]) -> CGFloat {
        guard !panelHeights.isEmpty else { return 0 }

        let visibleHeights = panelHeights.map(effectivePanelHeight)
        var total = visibleHeights.reduce(0) { partial, height in
            partial + height + panelResizeHandleHeight
        }

        if let bottomHeight = visibleHeights.last, bottomHeight > 0 {
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
        if let bottomIndicatorHeight = indicatorPanelHeights.last.map(effectivePanelHeight) {
            return bottomIndicatorHeight > 0 ? panelXAxisLabelStripHeight : 0
        }
        if timeframePanelHeights.last.map(effectivePanelHeight) != nil {
            // Timeframe panels render their own x-axis strip inside the panel; keep main chart x-axis visible.
            return 0
        }
        return 0
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
