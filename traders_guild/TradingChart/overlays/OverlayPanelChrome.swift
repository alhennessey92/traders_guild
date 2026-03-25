import SwiftUI

enum OverlayPanelChrome {
    static func background(
        cornerRadius: CGFloat,
        showsBorder: Bool = true
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    ThemeManager.shared.currentTheme == .midGrey
                        ? AppColors.panelHeaderBackground.opacity(0.92)
                        : AppColors.surfaceBlack50
                )
        }
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.surfaceWhite18, lineWidth: 1)
            }
        }
    }

    static func sideHandle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.surfaceWhite94)
            .frame(width: 18, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.surfaceWhite12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                    )
            )
    }
}
