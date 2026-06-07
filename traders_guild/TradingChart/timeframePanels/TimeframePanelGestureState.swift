//
//  TimeframePanelGestureState.swift
//  traders_guild
//
//  Independent gesture state for a single timeframe panel.
//  Not linked to the main chart gesture state — allows independent pan & pinch.
//

import SwiftUI

class TimeframePanelGestureState: ObservableObject {
    private static let horizontalPinchDamping: CGFloat = 0.55
    private static let verticalPinchDamping: CGFloat = 0.45

    // MARK: - Published State

    @Published var panOffset: CGSize = .zero
    @Published var candleWidthScale: CGFloat = 1.0
    @Published var priceScale: CGFloat = 1.0
    @Published var verticalPanOffset: CGFloat = 0
    @Published private(set) var isUserDrivenPanActive: Bool = false

    // MARK: - Private

    private var accumulatedOffset: CGSize = .zero
    private var bodyDragStartVerticalOffset: CGFloat = 0
    private var lastPinchScale: CGFloat = 1.0
    private var lastPricePinchScale: CGFloat = 1.0

    // MARK: - Pan

    func beginDrag() {
        isUserDrivenPanActive = true
        accumulatedOffset = panOffset
        bodyDragStartVerticalOffset = verticalPanOffset
    }

    func applyPan(
        translationX: CGFloat,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        olderEdgeGuardCandleCount: Int = 0,
        historicalRenderIndexOffset: Int = 0
    ) {
        let renderOffset = max(0, min(historicalRenderIndexOffset, candleCount))
        let totalContentWidth = CGFloat(max(0, candleCount - renderOffset)) * candleWidth
        let guardedMaxOffset = CGFloat(renderOffset - max(0, olderEdgeGuardCandleCount)) * candleWidth
        let maxLeftOffset = olderEdgeGuardCandleCount > 0
            ? guardedMaxOffset
            : CGFloat(renderOffset) * candleWidth + chartWidth * 0.5
        let maxRightOffset = -(totalContentWidth - chartWidth * 0.5)

        // translationX is incremental (delta since last frame), so add to current panOffset
        let newOffset = panOffset.width + translationX
        panOffset.width = min(maxLeftOffset, max(maxRightOffset, newOffset))
    }

    func endDrag() {
        accumulatedOffset = panOffset
        isUserDrivenPanActive = false
    }

    func applyBodyPan(
        translationX: CGFloat,
        translationY: CGFloat,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        panelHeight: CGFloat,
        olderEdgeGuardCandleCount: Int = 0,
        historicalRenderIndexOffset: Int = 0
    ) {
        applyPan(
            translationX: translationX,
            chartWidth: chartWidth,
            candleCount: candleCount,
            candleWidth: candleWidth,
            olderEdgeGuardCandleCount: olderEdgeGuardCandleCount,
            historicalRenderIndexOffset: historicalRenderIndexOffset
        )

        let proposedOffset = verticalPanOffset + translationY
        let bodyLimit = max(24, panelHeight * 0.28)
        let lowerBound = bodyDragStartVerticalOffset - bodyLimit
        let upperBound = bodyDragStartVerticalOffset + bodyLimit
        verticalPanOffset = min(upperBound, max(lowerBound, proposedOffset))
    }

    // MARK: - Pinch

    func applyPinch(scale: CGFloat) {
        let dampedScale = 1 + (scale - 1) * Self.horizontalPinchDamping
        let newScale = lastPinchScale * dampedScale
        candleWidthScale = min(4.0, max(0.3, newScale))
    }

    func endPinch() {
        lastPinchScale = candleWidthScale
    }

    // MARK: - Y Axis

    func applyVerticalPan(deltaY: CGFloat, panelHeight: CGFloat) {
        let proposedOffset = verticalPanOffset + deltaY
        verticalPanOffset = clampedVerticalOffset(proposedOffset, panelHeight: panelHeight)
    }

    func applyPricePinch(scale: CGFloat, panelHeight: CGFloat) {
        let dampedScale = 1 + (scale - 1) * Self.verticalPinchDamping
        let proposedScale = lastPricePinchScale * dampedScale
        priceScale = min(3.0, max(0.5, proposedScale))
        verticalPanOffset = clampedVerticalOffset(verticalPanOffset, panelHeight: panelHeight)
    }

    func applyPriceScale(
        proposedScale: CGFloat,
        initialPriceScale: CGFloat,
        initialVerticalOffset: CGFloat,
        anchorY: CGFloat,
        panelHeight: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        let clampedScale = min(maxScale, max(minScale, proposedScale))
        let safeInitialScale = max(initialPriceScale, 0.0001)
        let scaleRatio = clampedScale / safeInitialScale

        priceScale = clampedScale

        let proposedOffset = initialVerticalOffset * scaleRatio + anchorY * (1.0 - scaleRatio)
        verticalPanOffset = clampedVerticalOffset(proposedOffset, panelHeight: panelHeight)
    }

    func endPricePinch() {
        lastPricePinchScale = priceScale
    }

    // MARK: - Reset

    func reset() {
        isUserDrivenPanActive = false
        panOffset = .zero
        candleWidthScale = 1.0
        priceScale = 1.0
        verticalPanOffset = 0
        accumulatedOffset = .zero
        bodyDragStartVerticalOffset = 0
        lastPinchScale = 1.0
        lastPricePinchScale = 1.0
    }

    func recenterVertical(resetScale: Bool) {
        if resetScale {
            priceScale = 1.0
            lastPricePinchScale = 1.0
        }
        verticalPanOffset = 0
        bodyDragStartVerticalOffset = 0
    }

    /// Center the view on a specific candle index.
    func centerOn(candleIndex: Int, totalCandleWidth: CGFloat, chartWidth: CGFloat, historicalRenderIndexOffset: Int = 0) {
        let candleX = CGFloat(candleIndex - historicalRenderIndexOffset) * totalCandleWidth
        panOffset.width = chartWidth / 2 - candleX
        accumulatedOffset = panOffset
    }

    func shiftForPrependedCandles(count: Int, totalCandleWidth: CGFloat) {
        guard count > 0 else { return }
        accumulatedOffset = panOffset
    }

    private func clampedVerticalOffset(_ offset: CGFloat, panelHeight: CGFloat) -> CGFloat {
        let limit = max(60, panelHeight * max(1.0, priceScale) * 1.75)
        return min(limit, max(-limit, offset))
    }
}
