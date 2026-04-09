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
                    ThemeManager.shared.currentTheme == .dark
                        ? AppColors.surfaceBlack50.opacity(0.96)
                        : AppColors.chartOverlayInfoPanelFill
                )
        }
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.adaptiveOverlay18, lineWidth: 1)
            }
        }
    }

    static func sideHandle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.adaptiveOverlay94)
            .frame(width: 18, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.adaptiveOverlay10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.adaptiveOverlay20, lineWidth: 1)
                    )
            )
    }
}
