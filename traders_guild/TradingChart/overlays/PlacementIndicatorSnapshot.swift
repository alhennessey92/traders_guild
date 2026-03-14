import Foundation

/// Captures a stable chart context snapshot when placement mode begins.
/// This keeps mirror-chart setup pinned to the pre-placement chart, even while
/// temporary placement overlays are being shown on the live chart.
struct ChartMirrorContextSnapshot {
    private(set) var didCapture = false
    private(set) var indicators: [IndicatorPayload] = []
    private(set) var drawings: [ChartDrawing] = []

    // Backwards-compatible alias used by older tests/helpers.
    var payloads: [IndicatorPayload] { indicators }

    mutating func captureIfNeeded(from activeIndicators: ActiveIndicators, drawings activeDrawings: [ChartDrawing]) {
        guard !didCapture else { return }
        indicators = MarkerPlacementIndicatorFactory.activePayloads(from: activeIndicators)
        drawings = activeDrawings
        didCapture = true
    }

    mutating func reset() {
        didCapture = false
        indicators = []
        drawings = []
    }
}

typealias PlacementIndicatorSnapshot = ChartMirrorContextSnapshot
