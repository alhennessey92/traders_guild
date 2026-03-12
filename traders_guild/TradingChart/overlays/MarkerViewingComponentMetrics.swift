import Foundation

struct MarkerViewingComponentMetrics {
    let orderedComponents: [RLMarkerComponentDTO]

    init(marker: ChartMarkerUI) {
        self.orderedComponents = marker.components.sorted {
            if $0.ordering != $1.ordering { return $0.ordering < $1.ordering }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var drawingComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum?.isDrawing == true }
    }

    var indicatorComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum == .indicator }
    }

    var timeframeComponents: [RLMarkerComponentDTO] {
        orderedComponents.filter { $0.componentTypeEnum == .timeframeLink }
    }

    var displayedComponentCount: Int {
        indicatorComponents.count + drawingComponents.count + timeframeComponents.count
    }

    var hiddenComponentCount: Int {
        max(0, orderedComponents.count - displayedComponentCount)
    }
}
