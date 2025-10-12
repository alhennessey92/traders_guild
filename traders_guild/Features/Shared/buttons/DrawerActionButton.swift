//
//  DrawerActionButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//

import SwiftUI

/// Generic full-width button for login/signup
struct DrawerActionButton: View {
    let title: String?
    let imageName: String?
    let backgroundColor: Color
    let foregroundColor: Color
    let strokeColor: Color?
    let strokeWidth: CGFloat
    let action: () -> Void
    
    init(
        title: String? = nil,
        imageName: String? = nil,
        backgroundColor: Color,
        foregroundColor: Color,
        strokeColor: Color? = nil,
        strokeWidth: CGFloat = 0,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.imageName = imageName
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let imageName = imageName {
                    Image(systemName: imageName)
                        .font(.headline)
                }
                
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)  // ADD THIS
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(strokeColor ?? Color.clear, lineWidth: strokeWidth)
            )
            .fixedSize(horizontal: true, vertical: false) // ADD THIS - prevents wrapping
        }
    }
}
