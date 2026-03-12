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
    var indicatorPanelCount: Int = 0

    @Binding var panel1Height: CGFloat
    @Binding var panel2Height: CGFloat

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
                        dataManager: entry.dataManager,
                        gestureState: entry.gestureState,
                        markerTimestamp: markerTimestamp,
                        intentColor: intentColor,
                        baseCandleWidth: baseCandleWidth,
                        candleSpacing: candleSpacing,
                        panelHeight: heightBinding(for: index),
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

    private func heightBinding(for index: Int) -> Binding<CGFloat> {
        index == 0 ? $panel1Height : $panel2Height
    }

    // MARK: - Total Height

    var totalPanelHeight: CGFloat {
        var total: CGFloat = 0
        let count = timeframePanelManager.activePanelCount

        if count >= 1 {
            total += panel1Height + 22  // panel + handle
        }
        if count >= 2 {
            total += panel2Height + 22
        }

        // X-axis labels on bottom panel
        if count > 0 {
            total += 24
        }

        return total
    }
}
