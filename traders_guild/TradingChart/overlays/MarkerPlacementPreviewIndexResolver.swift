import Foundation

enum MarkerPlacementPreviewIndexResolver {
    static func fixedPreviewIndex(
        currentPreviewIndex: Int,
        centerIndex: Int,
        candleCount: Int
    ) -> Int {
        guard candleCount > 0 else { return -1 }
        if currentPreviewIndex >= 0 && currentPreviewIndex < candleCount {
            return currentPreviewIndex
        }
        return min(max(centerIndex, 0), candleCount - 1)
    }
}
