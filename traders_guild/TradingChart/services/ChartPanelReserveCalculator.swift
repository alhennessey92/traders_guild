import CoreGraphics

enum ChartPanelStackOwner: Equatable {
    case timeframe(index: Int)
    case indicator(index: Int)
}

struct CombinedChartPanelLayout: Equatable {
    let totalReserve: CGFloat
    let bottomBoundaryLabelReserve: CGFloat
    let mainChartXAxisClearance: CGFloat
    let controlRowReserve: CGFloat
    let indicatorAxisPanelIndex: Int?
    let bottomBoundaryOwner: ChartPanelStackOwner?
}

struct ChartPanelPresentationState: Equatable {
    let currentHeight: CGFloat
    let expandedHeight: CGFloat

    var isCollapsed: Bool {
        ChartPanelReserveCalculator.isCollapsedPanelHeight(currentHeight)
    }
}

enum ChartPanelPresentationPolicy {
    static func collapsed(
        currentHeight: CGFloat,
        expandedHeight: CGFloat,
        minHeight: CGFloat
    ) -> ChartPanelPresentationState {
        ChartPanelPresentationState(
            currentHeight: 0,
            expandedHeight: max(minHeight, currentHeight > 0 ? currentHeight : expandedHeight)
        )
    }

    static func expanded(
        expandedHeight: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> ChartPanelPresentationState {
        let restoredHeight = expandedHeight > 0 ? expandedHeight : minHeight
        let clampedHeight = min(maxHeight, max(minHeight, restoredHeight))
        return ChartPanelPresentationState(
            currentHeight: clampedHeight,
            expandedHeight: clampedHeight
        )
    }

    static func clamped(
        currentHeight: CGFloat,
        expandedHeight: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> ChartPanelPresentationState {
        if ChartPanelReserveCalculator.isCollapsedPanelHeight(currentHeight) {
            return ChartPanelPresentationState(
                currentHeight: 0,
                expandedHeight: min(maxHeight, max(minHeight, expandedHeight > 0 ? expandedHeight : minHeight))
            )
        }

        let sourceHeight = currentHeight > 0 ? currentHeight : expandedHeight
        let clampedHeight = min(maxHeight, max(minHeight, sourceHeight))
        return ChartPanelPresentationState(
            currentHeight: clampedHeight,
            expandedHeight: clampedHeight
        )
    }

    static func restoredActiveHeight(
        currentHeight: CGFloat,
        expandedHeight: CGFloat,
        defaultHeight: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> ChartPanelPresentationState {
        guard ChartPanelReserveCalculator.isCollapsedPanelHeight(currentHeight) else {
            return clamped(
                currentHeight: currentHeight,
                expandedHeight: expandedHeight,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
        }

        let restoredHeight = expandedHeight > 0 ? expandedHeight : defaultHeight
        let clampedHeight = min(maxHeight, max(minHeight, restoredHeight))
        return ChartPanelPresentationState(
            currentHeight: clampedHeight,
            expandedHeight: clampedHeight
        )
    }
}

enum ChartPanelReserveCalculator {
    static let panelResizeHandleHeight: CGFloat = 22
    /// Canvas height for time labels (unchanged typography / layout).
    static let panelXAxisTimeLabelAreaHeight: CGFloat = 24
    /// Solid strip below labels, matching x-axis fill — keeps times off the physical panel edge.
    static let panelXAxisLabelBottomFootHeight: CGFloat = 4
    /// Full stacked-panel x-axis chrome height (labels + foot). Used for layout reserve everywhere.
    static let panelXAxisLabelStripHeight: CGFloat =
        panelXAxisTimeLabelAreaHeight + panelXAxisLabelBottomFootHeight
    /// Consistent gap between chart layout and floating panel stack (avoids jumps when panels expand/collapse).
    static let panelStackChartUniformGap: CGFloat = 4
    /// No-panel state uses TradingChartView's native bottom control baseline.
    static var mainChartControlRowBaselineClearance: CGFloat {
        0
    }
    /// TradingChartView positions chart controls from the main x-axis base plus
    /// the x-axis strip and a small visual lift. Panel reserves are relative to
    /// that existing control baseline.
    static var chartControlRowXAxisBaseOffset: CGFloat {
        panelXAxisLabelStripHeight + 6
    }
    /// Heights below this are treated as collapsed to avoid sub-pixel UI jitter.
    static let expandedPanelHeightThreshold: CGFloat = 2

    private static func effectivePanelHeight(_ rawHeight: CGFloat) -> CGFloat {
        let clamped = max(0, rawHeight)
        guard clamped >= expandedPanelHeightThreshold else { return 0 }
        return clamped.rounded(.toNearestOrAwayFromZero)
    }

    static func isCollapsedPanelHeight(_ rawHeight: CGFloat) -> Bool {
        effectivePanelHeight(rawHeight) == 0
    }

    private static func bottomExpandedPanelIndex(in panelHeights: [CGFloat]) -> Int? {
        for (index, height) in panelHeights.enumerated().reversed() {
            if effectivePanelHeight(height) > 0 {
                return index
            }
        }
        return nil
    }

    private static func lastRenderedPanelOwner(
        timeframePanelHeights: [CGFloat],
        indicatorPanelHeights: [CGFloat]
    ) -> ChartPanelStackOwner? {
        if !indicatorPanelHeights.isEmpty {
            return .indicator(index: indicatorPanelHeights.count - 1)
        }
        if !timeframePanelHeights.isEmpty {
            return .timeframe(index: timeframePanelHeights.count - 1)
        }
        return nil
    }

    private static func isExpanded(index: Int, in panelHeights: [CGFloat]) -> Bool {
        panelHeights.indices.contains(index) && effectivePanelHeight(panelHeights[index]) > 0
    }

    private static func stackBaseReserve(for panelHeights: [CGFloat]) -> CGFloat {
        guard !panelHeights.isEmpty else { return 0 }

        let handlesReserve = CGFloat(panelHeights.count) * panelResizeHandleHeight
        let expandedContentReserve = panelHeights
            .map(effectivePanelHeight)
            .reduce(0, +)
        return handlesReserve + expandedContentReserve
    }

    private static func expandedPanelCount(in panelHeights: [CGFloat]) -> Int {
        panelHeights.reduce(0) { count, height in
            count + (effectivePanelHeight(height) > 0 ? 1 : 0)
        }
    }

    private static func timeframeStackReserve(for panelHeights: [CGFloat]) -> CGFloat {
        stackBaseReserve(for: panelHeights)
            + CGFloat(expandedPanelCount(in: panelHeights)) * panelXAxisLabelStripHeight
    }

    static func combinedLayout(
        timeframePanelHeights: [CGFloat],
        indicatorPanelHeights: [CGFloat]
    ) -> CombinedChartPanelLayout {
        var totalReserve = timeframeStackReserve(for: timeframePanelHeights)
        totalReserve += stackBaseReserve(for: indicatorPanelHeights)

        let indicatorAxisPanelIndex: Int? = nil

        let bottomRenderedOwner = lastRenderedPanelOwner(
            timeframePanelHeights: timeframePanelHeights,
            indicatorPanelHeights: indicatorPanelHeights
        )
        let bottomBoundaryOwner: ChartPanelStackOwner?
        switch bottomRenderedOwner {
        case .indicator:
            bottomBoundaryOwner = nil
        case .timeframe(let index):
            bottomBoundaryOwner = isExpanded(index: index, in: timeframePanelHeights)
                ? .timeframe(index: index)
                : nil
        case .none:
            bottomBoundaryOwner = nil
        }

        let bottomBoundaryLabelReserve: CGFloat
        switch bottomBoundaryOwner {
        case .timeframe, .indicator, .none:
            bottomBoundaryLabelReserve = 0
        }

        let mainChartXAxisClearance =
            totalReserve > 0 ? panelXAxisLabelStripHeight : 0
        let controlRowReserve: CGFloat
        if totalReserve > 0 {
            controlRowReserve = max(
                0,
                totalReserve
                    + panelStackBottomSpacerClearance(mainChartXAxisClearance: mainChartXAxisClearance)
                    + panelStackChartUniformGap
                    - chartControlRowXAxisBaseOffset
            )
        } else {
            controlRowReserve = mainChartControlRowBaselineClearance
        }

        return CombinedChartPanelLayout(
            totalReserve: totalReserve,
            bottomBoundaryLabelReserve: bottomBoundaryLabelReserve,
            mainChartXAxisClearance: mainChartXAxisClearance,
            controlRowReserve: controlRowReserve,
            indicatorAxisPanelIndex: indicatorAxisPanelIndex,
            bottomBoundaryOwner: bottomBoundaryOwner
        )
    }

    /// Height reserve for a panel stack.
    /// Includes each panel's resize handle and includes a label strip only when
    /// the last expanded panel in the stack is visible.
    static func stackReserve(panelHeights: [CGFloat]) -> CGFloat {
        guard !panelHeights.isEmpty else { return 0 }

        var total = stackBaseReserve(for: panelHeights)

        if bottomExpandedPanelIndex(in: panelHeights) != nil {
            total += panelXAxisLabelStripHeight
        }

        return total
    }

    /// Height reserve for timeframe panels. Every expanded timeframe panel owns its
    /// own x-axis strip, unlike indicator panels where only the bottom panel owns one.
    static func timeframeStackReserve(panelHeights: [CGFloat]) -> CGFloat {
        timeframeStackReserve(for: panelHeights)
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

    static func panelStackBottomSpacerClearance(mainChartXAxisClearance: CGFloat) -> CGFloat {
        guard mainChartXAxisClearance > 0 else { return 0 }
        return mainChartXAxisClearance + panelStackChartUniformGap
    }
}
