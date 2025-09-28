//
//  ToolbarIconButton.swift
//  traders_guild
//
//  Created by AI Assistant on 28/09/2025.
//

import SwiftUI

/// A reusable, custom-styled toolbar button that displays an SF Symbol.
/// Use inside `.toolbar` just like a normal view.
struct ToolbarIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    // Customization knobs
    var foregroundColor: Color = .white
    var backgroundColor: Color = Color.white.opacity(0.10)
    var cornerRadius: CGFloat = 10

    init(systemName: String,
         label: String,
         foregroundColor: Color = .white,
         backgroundColor: Color = Color.white.opacity(0.10),
         cornerRadius: CGFloat = 10,
         action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(foregroundColor)
                .padding(8)
        }
        .accessibilityLabel(label)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("ToolbarIconButton") {
    ZStack {
        LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ToolbarIconButton(systemName: "ellipsis", label: "Options") {
            // preview action
        }
        .padding()
    }
}
