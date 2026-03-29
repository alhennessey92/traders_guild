import SwiftUI

struct SheetCloseButton: View {
    let action: () -> Void
    var tint: Color = AppColors.greyText
    var font: Font = .title2

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(font)
                .foregroundColor(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
