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

    // MARK: - Private

    private var accumulatedOffset: CGSize = .zero
    private var bodyDragStartVerticalOffset: CGFloat = 0
    private var lastPinchScale: CGFloat = 1.0
    private var lastPricePinchScale: CGFloat = 1.0

    // MARK: - Pan

    func beginDrag() {
        accumulatedOffset = panOffset
        bodyDragStartVerticalOffset = verticalPanOffset
    }

    func applyPan(translationX: CGFloat, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat) {
        let totalContentWidth = CGFloat(candleCount) * candleWidth
        let maxLeftOffset = chartWidth * 0.5
        let maxRightOffset = -(totalContentWidth - chartWidth * 0.5)

        // translationX is incremental (delta since last frame), so add to current panOffset
        let newOffset = panOffset.width + translationX
        panOffset.width = min(maxLeftOffset, max(maxRightOffset, newOffset))
    }

    func endDrag() {
        accumulatedOffset = panOffset
    }

    func applyBodyPan(
        translationX: CGFloat,
        translationY: CGFloat,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        panelHeight: CGFloat
    ) {
        applyPan(
            translationX: translationX,
            chartWidth: chartWidth,
            candleCount: candleCount,
            candleWidth: candleWidth
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
        panOffset = .zero
        candleWidthScale = 1.0
        priceScale = 1.0
        verticalPanOffset = 0
        accumulatedOffset = .zero
        bodyDragStartVerticalOffset = 0
        lastPinchScale = 1.0
        lastPricePinchScale = 1.0
    }

    /// Center the view on a specific candle index.
    func centerOn(candleIndex: Int, totalCandleWidth: CGFloat, chartWidth: CGFloat) {
        let candleX = CGFloat(candleIndex) * totalCandleWidth
        panOffset.width = chartWidth / 2 - candleX
        accumulatedOffset = panOffset
    }

    func shiftForPrependedCandles(count: Int, totalCandleWidth: CGFloat) {
        guard count > 0, totalCandleWidth > 0 else { return }
        panOffset.width -= CGFloat(count) * totalCandleWidth
        accumulatedOffset = panOffset
    }

    private func clampedVerticalOffset(_ offset: CGFloat, panelHeight: CGFloat) -> CGFloat {
        let limit = max(60, panelHeight * max(1.0, priceScale) * 1.75)
        return min(limit, max(-limit, offset))
    }
}
