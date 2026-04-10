import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import traders_guild

@MainActor
struct PanelAuditViewportTests {
    @Test
    func fixedDomainPanelsClampZoomOutToFullRange() {
        let state = IndicatorPanelViewportState()

        state.applyPriceScale(
            proposedScale: 0.2,
            initialPriceScale: 1.0,
            initialVerticalOffset: 0,
            anchorY: 100,
            panelHeight: 220,
            minScale: 1.0,
            maxScale: 5.0
        )

        #expect(abs(state.priceScale - 1.0) < 0.0001)
        #expect(abs(state.verticalPanOffset) < 0.0001)
    }

    @Test
    func dynamicPanelsRespectZoomOutFloor() {
        let state = IndicatorPanelViewportState()

        state.applyPriceScale(
            proposedScale: 0.1,
            initialPriceScale: 1.0,
            initialVerticalOffset: 0,
            anchorY: 110,
            panelHeight: 240,
            minScale: 0.8,
            maxScale: 5.0
        )

        #expect(abs(state.priceScale - 0.8) < 0.0001)
    }

    @Test
    func viewportYPositionRespondsToLocalScaleAndPan() {
        let baseViewport = IndicatorPanelViewport(
            rawValueRange: (min: 0, max: 100),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 200,
            priceScale: 1.0,
            verticalPanOffset: 0
        )
        let zoomedViewport = IndicatorPanelViewport(
            rawValueRange: (min: 0, max: 100),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 200,
            priceScale: 2.0,
            verticalPanOffset: 0
        )
        let pannedViewport = IndicatorPanelViewport(
            rawValueRange: (min: 0, max: 100),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 200,
            priceScale: 2.0,
            verticalPanOffset: 24
        )

        let baseY = baseViewport.yPosition(for: 75)
        let zoomedY = zoomedViewport.yPosition(for: 75)
        let pannedY = pannedViewport.yPosition(for: 75)

        #expect(zoomedY < baseY)
        #expect(abs(pannedY - (zoomedY + 24)) < 0.0001)
    }

    @Test
    func localIndicatorVerticalStateStaysIndependentFromSharedChartState() {
        let chartState = ChartGestureState()
        let localVerticalState = IndicatorPanelViewportState()

        chartState.priceScale = 1.6
        chartState.verticalPanOffset = 32

        localVerticalState.applyPriceScale(
            proposedScale: 2.2,
            initialPriceScale: 1.0,
            initialVerticalOffset: 0,
            anchorY: 90,
            panelHeight: 200,
            minScale: 0.8,
            maxScale: 5.0
        )
        localVerticalState.applyBodyPan(translationY: 18, panelHeight: 200)

        #expect(abs(chartState.priceScale - 1.6) < 0.0001)
        #expect(abs(chartState.verticalPanOffset - 32) < 0.0001)

        chartState.applyPan(
            translation: CGSize(width: 24, height: 0),
            chartWidth: 320,
            candleCount: 80,
            candleWidth: 16,
            chartHeight: 200,
            priceScale: chartState.priceScale,
            trackVelocity: false
        )

        #expect(chartState.panOffset.width != 0)
        #expect(localVerticalState.verticalPanOffset != chartState.verticalPanOffset)
    }

    @Test
    func themeTokensSeparateAxisBorderAndKeepLightGreyChromeLighterThanPlot() {
        let manager = ThemeManager.shared
        let originalTheme = manager.currentTheme
        defer { manager.currentTheme = originalTheme }

        manager.currentTheme = .dark
        #expect(colorDistance(AppColors.timeframePanelAxisFrameBorder, AppColors.timeframePanelAxisLabelPrimary) > 0.1)

        manager.currentTheme = .lightGrey
        #expect(colorDistance(AppColors.panelYAxisLaneBackground, AppColors.indicatorPanelPlotBackground) > 0.08)
        #expect(colorDistance(AppColors.timeframePanelHandleBackground, AppColors.indicatorPanelHandleBackground) > 0.04)
    }
}

private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        return (red, green, blue, alpha)
    }
    return (0, 0, 0, 0)
}

private func colorDistance(_ lhs: Color, _ rhs: Color) -> CGFloat {
    let lhsRGBA = rgba(lhs)
    let rhsRGBA = rgba(rhs)
    let dr = lhsRGBA.0 - rhsRGBA.0
    let dg = lhsRGBA.1 - rhsRGBA.1
    let db = lhsRGBA.2 - rhsRGBA.2
    return sqrt((dr * dr) + (dg * dg) + (db * db))
}
