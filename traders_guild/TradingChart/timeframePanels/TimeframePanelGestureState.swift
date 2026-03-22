//
//  TimeframePanelGestureState.swift
//  traders_guild
//
//  Independent gesture state for a single timeframe panel.
//  Not linked to the main chart gesture state — allows independent pan & pinch.
//

import SwiftUI

class TimeframePanelGestureState: ObservableObject {

    // MARK: - Published State

    @Published var panOffset: CGSize = .zero
    @Published var candleWidthScale: CGFloat = 1.0

    // MARK: - Private

    private var accumulatedOffset: CGSize = .zero
    private var lastPinchScale: CGFloat = 1.0

    // MARK: - Pan

    func beginDrag() {
        accumulatedOffset = panOffset
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

    // MARK: - Pinch

    func applyPinch(scale: CGFloat) {
        let newScale = lastPinchScale * scale
        candleWidthScale = min(4.0, max(0.3, newScale))
    }

    func endPinch() {
        lastPinchScale = candleWidthScale
    }

    // MARK: - Reset

    func reset() {
        panOffset = .zero
        candleWidthScale = 1.0
        accumulatedOffset = .zero
        lastPinchScale = 1.0
    }

    /// Center the view on a specific candle index.
    func centerOn(candleIndex: Int, totalCandleWidth: CGFloat, chartWidth: CGFloat) {
        let candleX = CGFloat(candleIndex) * totalCandleWidth
        panOffset.width = chartWidth / 2 - candleX
        accumulatedOffset = panOffset
    }
}
