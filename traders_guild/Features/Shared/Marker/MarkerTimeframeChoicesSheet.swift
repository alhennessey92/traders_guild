import SwiftUI

/// Reuse the thesis loader, permissions and pagination instead of introducing
/// a second cross-timeframe browser. Navigation starts after sheet dismissal.
struct MarkerTimeframeChoicesSheet: View {
    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    @ObservedObject var store: MarkerThreadStore
    let onOpenMarker: (RLMarkerLinkPreviewDTO) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AdminSheetBackground()
            VStack(alignment: .leading, spacing: 12) {
                AdminSheetHeader(
                    icon: "clock.arrow.circlepath",
                    iconColor: AppColors.accentColor,
                    title: "Choose a linked marker",
                    subtitle: "Each marker stays on its own timeframe."
                )
                Text("Tap a row to open that marker’s chart. More branches can be loaded in this list.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.greyText)
                ScrollView {
                    MarkerThesisDisclosure(marker: marker, markerManager: markerManager, store: store,
                                           onOpenMarker: onOpenMarker)
                }
            }
            .padding(16)
            .padding(.top, 24)
            SheetCloseButton(action: { dismiss() })
                .padding(16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
