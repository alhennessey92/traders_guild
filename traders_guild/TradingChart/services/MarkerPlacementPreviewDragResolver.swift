import CoreGraphics
import Foundation

enum MarkerPlacementPreviewDragResolver {
    static func resolvedPreviewIndex(
        isEditingExistingMarker: Bool,
        currentIndex: Int,
        candidateIndex: Int?,
        candleCount: Int
    ) -> Int {
        guard !isEditingExistingMarker,
              candleCount > 0,
              let candidateIndex,
              candidateIndex >= 0,
              candidateIndex < candleCount else {
            return currentIndex
        }
        return candidateIndex
    }

    static func clampedDragLocation(
        _ location: CGPoint,
        plotSize: CGSize,
        minimumVisibleInset: CGFloat = 46
    ) -> CGPoint {
        guard plotSize.width.isFinite,
              plotSize.height.isFinite,
              plotSize.width > 0,
              plotSize.height > 0 else {
            return location
        }

        let insetX = min(max(0, minimumVisibleInset), plotSize.width / 2)
        let insetY = min(max(0, minimumVisibleInset), plotSize.height / 2)
        let minX = insetX
        let maxX = max(minX, plotSize.width - insetX)
        let minY = insetY
        let maxY = max(minY, plotSize.height - insetY)
        let finiteX = location.x.isFinite ? location.x : plotSize.width / 2
        let finiteY = location.y.isFinite ? location.y : plotSize.height / 2

        return CGPoint(
            x: min(max(finiteX, minX), maxX),
            y: min(max(finiteY, minY), maxY)
        )
    }
}
