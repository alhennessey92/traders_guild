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

    /// The live pan/zoom + crosshair state of the main chart.
    ///
    /// Observed *here* rather than in `MainView`. These panels are the only thing outside the chart
    /// that needs the main chart's viewport, and `panOffset` publishes on every frame of a drag —
    /// so observing it from the app's root view meant a pan re-evaluated the entire shell (drawers,
    /// toolbars, panels, chart) ~37×/sec, and rebuilt `TradingChartView` on top of that. Keeping the
    /// subscription down here confines that churn to this small stack.
    @ObservedObject var gestureState: ChartGestureState

    /// Candles + render offset behind the visible-window calculation below.
    @ObservedObject var chartData: ChartDataManager

    let markerTimestamp: Date
    let intentColor: Color
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var mainChartTimeframeSeconds: TimeInterval = 0
    var showMarkerLine: Bool = false
    var indicatorPanelCount: Int = 0
    var bottomAxisPanelIndex: Int? = nil
    var formatPrice: (Double) -> String = TimeframePanelView.defaultPriceFormatter

    // MARK: - Main chart viewport (drives the window overlay on each panel)

    private var mainChartVisibleWindow: (start: Date?, end: Date?) {
        MainChartViewport.visibleWindow(
            panOffsetX: gestureState.panOffset.width,
            candleWidthScale: gestureState.candleWidthScale,
            baseCandleWidth: baseCandleWidth,
            candleSpacing: candleSpacing,
            historicalRenderIndexOffset: chartData.historicalRenderIndexOffset,
            viewportWidth: UIScreen.main.bounds.width,
            candleTimestamps: chartData.candles.map(\.timestamp),
            timeframeSeconds: mainChartTimeframeSeconds
        )
    }

    // MARK: - Bottom-axis crosshair overlay

    private var bottomAxisOverlayTimestamp: Date? {
        if gestureState.crosshairActive {
            return gestureState.crosshairTimestamp
        }
        if gestureState.markerPlacementGuide.isActive {
            return gestureState.markerPlacementGuide.timestamp
        }
        return nil
    }

    private var bottomAxisOverlayStyle: CrosshairTimeLabelStyle {
        gestureState.crosshairActive ? .standard : .markerPlacement
    }

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
            // Computed once per body pass, not once per panel.
            let visibleWindow = mainChartVisibleWindow
            VStack(spacing: 0) {
                ForEach(Array(timeframePanelManager.panels.enumerated()), id: \.element.id) { index, entry in
                    TimeframePanelView(
                        entry: entry,
                        markerTimestamp: markerTimestamp,
                        intentColor: intentColor,
                        baseCandleWidth: baseCandleWidth,
                        candleSpacing: candleSpacing,
                        mainChartVisibleStart: visibleWindow.start,
                        mainChartVisibleEnd: visibleWindow.end,
                        mainChartTimeframeSeconds: mainChartTimeframeSeconds,
                        showMarkerLine: showMarkerLine,
                        minPanelHeight: TimeframePanelManager.minPanelHeight,
                        maxPanelHeight: adjustedMaxHeight,
                        isBottomPanel: bottomAxisPanelIndex == index,
                        bottomAxisOverlayTimestamp: bottomAxisOverlayTimestamp,
                        bottomAxisOverlayStyle: bottomAxisOverlayStyle,
                        formatPrice: formatPrice
                    )
                }
            }
        }
    }

    // MARK: - Total Height

    var totalPanelHeight: CGFloat {
        ChartPanelReserveCalculator.timeframeStackReserve(panelHeights: timeframePanelManager.panels.map(\.currentHeight))
    }
}
