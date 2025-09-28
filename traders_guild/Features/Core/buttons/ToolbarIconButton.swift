//
//  ToolbarIconButton.swift
//  traders_guild
//
//  Created by AI Assistant on 28/09/2025.
//

import SwiftUI

/// A reusable, custom-styled toolbar button that displays an SF Symbol.
/// Supports single- and multi-color foreground styles.


/// A reusable toolbar button supporting SF Symbols with single- or multi-color rendering.
struct ToolbarIconButton: View {
    let systemName: String
    let action: () -> Void

    // Customization
    var backgroundTint: Color
    var fontType: Font
    var symbolRenderingMode: SymbolRenderingMode
    private var foregroundStyles: [AnyShapeStyle]
    

    // MARK: - Initializers

    /// Single color version
    init(
        systemName: String,
        backgroundTint: Color = AppColors.accentDarkColor.opacity(0.5),
        fontType: Font = .headline,
        symbolRenderingMode: SymbolRenderingMode = .monochrome,
        foregroundStyle: Color = .white,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.backgroundTint = backgroundTint
        self.fontType = fontType
        self.symbolRenderingMode = symbolRenderingMode
        self.foregroundStyles = [AnyShapeStyle(foregroundStyle)]
        self.action = action
    }

    /// Multiple colors version (palette)
    init(
        systemName: String,
        backgroundTint: Color = AppColors.accentDarkColor.opacity(0.5),
        fontType: Font = .headline,
        symbolRenderingMode: SymbolRenderingMode = .palette,
        foregroundStyles: [Color],
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.backgroundTint = backgroundTint
        self.fontType = fontType
        self.symbolRenderingMode = symbolRenderingMode
        self.foregroundStyles = foregroundStyles.map { AnyShapeStyle($0) }
        self.action = action
    }

    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(symbolRenderingMode)
                .font(fontType)
                .applyForegroundStyles(foregroundStyles)
                .padding(8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(backgroundTint)
    }
}

// MARK: - ForegroundStyle Helper
private extension View {
    @ViewBuilder
    func applyForegroundStyles(_ styles: [AnyShapeStyle]) -> some View {
        switch styles.count {
        case 0: self.foregroundStyle(Color.primary)
        case 1: self.foregroundStyle(styles[0])
        case 2: self.foregroundStyle(styles[0], styles[1])
        case 3: self.foregroundStyle(styles[0], styles[1], styles[2])
        default: self.foregroundStyle(styles[0], styles[1])
        }
    }
}

#Preview("ToolbarIconButton") {
    ZStack {
        LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ToolbarIconButton(systemName: "ellipsis") {
            // preview action
        }
        .padding()
    }
}

