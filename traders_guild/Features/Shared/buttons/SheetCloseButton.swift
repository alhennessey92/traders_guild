import SwiftUI

struct SheetCloseButton: View {
    let action: () -> Void
    var tint: Color = AppColors.greyText
    var font: Font = .subheadline.weight(.bold)

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(font)
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(AppColors.sheetBackground.opacity(0.92))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
