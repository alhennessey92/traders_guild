import Foundation
import Combine

extension Notification.Name {
    static let markerOverlayApply = Notification.Name("marker.overlay.apply")
    static let markerOverlayClear = Notification.Name("marker.overlay.clear")
    static let placeMarkerRequested = Notification.Name("marker.placement.placeRequested")
    static let markerCreatedSuccessfully = Notification.Name("marker.created.successfully")
}

@MainActor
final class MarkerOverlayState: ObservableObject {
    @Published private(set) var activeMarkerId: UUID?
    @Published private(set) var isOverlayActive: Bool = false

    private var previousMarkerId: UUID?

    func activateViewing(marker: ChartMarkerUI, indicatorManager: IndicatorManager, candles: [RLCandleDTO]) {
        if !isOverlayActive {
            indicatorManager.saveSnapshot()
        }
        apply(marker: marker)
        indicatorManager.applyMarkerIndicators(marker.components)
        indicatorManager.recalculateIndicators(candles: candles)
    }

    func deactivateViewing(indicatorManager: IndicatorManager, candles: [RLCandleDTO]) {
        if isOverlayActive {
            clear()
        }
        indicatorManager.restoreSnapshot()
        indicatorManager.recalculateIndicators(candles: candles)
    }

    func apply(marker: ChartMarkerUI) {
        previousMarkerId = activeMarkerId
        activeMarkerId = marker.id
        isOverlayActive = true
        NotificationCenter.default.post(
            name: .markerOverlayApply,
            object: nil,
            userInfo: [
                "markerId": marker.id.uuidString,
                "previousMarkerId": previousMarkerId?.uuidString as Any,
                "marker": marker,
            ]
        )
    }

    func clear() {
        let id = activeMarkerId?.uuidString
        activeMarkerId = nil
        isOverlayActive = false
        NotificationCenter.default.post(
            name: .markerOverlayClear,
            object: nil,
            userInfo: [
                "markerId": id as Any,
                "restoreMarkerId": previousMarkerId?.uuidString as Any,
            ]
        )
    }

    func restorePreviousSelectionIfNeeded() {
        activeMarkerId = previousMarkerId
        previousMarkerId = nil
    }
}
