import Foundation

enum MarkerPlacementPreviewDragResolver {
    static func resolvedPreviewIndex(
        isEditingExistingMarker: Bool,
        currentIndex: Int,
        candidateIndex: Int?
    ) -> Int {
        guard !isEditingExistingMarker, let candidateIndex else {
            return currentIndex
        }
        return candidateIndex
    }
}
