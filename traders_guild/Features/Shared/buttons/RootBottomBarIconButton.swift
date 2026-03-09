//
//  RootBottomBarIconButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 29/09/2025.
//

import SwiftUI

struct RootBottomBarIconButton: View {
    let systemName: String
    var fontSize: CGFloat = 20
    let backgroundColor: Color
    let foregroundColor: Color
    var palettePrimary: Color? = nil
    var paletteSecondary: Color? = nil
    var paletteTertiary: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            symbolView
                .frame(width: 50, height: 50)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var symbolView: some View {
        if let primary = palettePrimary {
            if let secondary = paletteSecondary, let tertiary = paletteTertiary {
                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(primary, secondary, tertiary)
            } else if let secondary = paletteSecondary {
                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(primary, secondary)
            } else {
                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(primary)
            }
        } else {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(foregroundColor)
        }
    }
}

//
#Preview {
    RootBottomBarIconButton(
        systemName: "message.fill",
        fontSize: 20,
        backgroundColor: AppColors.fadedBackground.opacity(0.1),
        foregroundColor: AppColors.fadedBackground,
        action: { print("Tapped message") }
    )
}
