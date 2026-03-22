//
//  TimeframePanelContainer.swift
//  traders_guild
//
//  Container view that manages stacked timeframe panels (max 2).
//  Mirrors IndicatorPanelContainer structure.
//

import SwiftUI

struct TimeframePanelContainer: View {

    // MARK: - Properties

    @ObservedObject var timeframePanelManager: TimeframePanelManager

    let markerTimestamp: Date
    let intentColor: Color
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var mainChartVisibleStart: Date? = nil
    var mainChartVisibleEnd: Date? = nil
    var mainChartTimeframeSeconds: TimeInterval = 0
    var showMarkerLine: Bool = false
    var indicatorPanelCount: Int = 0

    // MARK: - Computed

    private var adjustedMaxHeight: CGFloat {
        let totalPanels = timeframePanelManager.activePanelCount + indicatorPanelCount
        if totalPanels >= 3 {
            return 140
        } else if totalPanels >= 2 {
            return TimeframePanelManager.maxPanelHeightWith2
        }
        return TimeframePanelManager.maxPanelHeight
    }

    // MARK: - Body

    var body: some View {
        if timeframePanelManager.hasActivePanels {
            VStack(spacing: 0) {
                ForEach(Array(timeframePanelManager.panels.enumerated()), id: \.element.id) { index, entry in
                    let isBottom = isBottomPanel(index: index)
                    TimeframePanelView(
                        entry: entry,
                        markerTimestamp: markerTimestamp,
                        intentColor: intentColor,
                        baseCandleWidth: baseCandleWidth,
                        candleSpacing: candleSpacing,
                        mainChartVisibleStart: mainChartVisibleStart,
                        mainChartVisibleEnd: mainChartVisibleEnd,
                        mainChartTimeframeSeconds: mainChartTimeframeSeconds,
                        showMarkerLine: showMarkerLine,
                        minPanelHeight: TimeframePanelManager.minPanelHeight,
                        maxPanelHeight: adjustedMaxHeight,
                        isBottomPanel: isBottom
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func isBottomPanel(index: Int) -> Bool {
        index == timeframePanelManager.panels.count - 1
    }

    // MARK: - Total Height

    var totalPanelHeight: CGFloat {
        let panelHeights = timeframePanelManager.panels.map(\.currentHeight)
        var total = panelHeights.reduce(0) { partial, height in
            partial + height + ChartPanelReserveCalculator.panelResizeHandleHeight
        }

        // X-axis labels on bottom panel
        if let bottomHeight = panelHeights.last, bottomHeight > 0 {
            total += ChartPanelReserveCalculator.panelXAxisLabelStripHeight
        }

        return total
    }
}
