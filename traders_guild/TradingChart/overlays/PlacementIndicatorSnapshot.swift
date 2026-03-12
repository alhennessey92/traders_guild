import Foundation

/// Captures a stable indicator payload snapshot when placement mode begins.
/// This allows "Mirror Chart Setup" to keep using pre-placement indicators
/// even after temporary placement indicators are applied to the live chart.
struct PlacementIndicatorSnapshot {
    private(set) var didCapture = false
    private(set) var payloads: [IndicatorPayload] = []

    mutating func captureIfNeeded(from activeIndicators: ActiveIndicators) {
        guard !didCapture else { return }
        payloads = MarkerPlacementIndicatorFactory.activePayloads(from: activeIndicators)
        didCapture = true
    }

    mutating func reset() {
        didCapture = false
        payloads = []
    }
}
