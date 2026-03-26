//
//  StandardActionButtonFullWidth.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
import SwiftUI
struct StandardActionButtonFullWidth: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: (() -> Void)

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.headline)
                        .scaleEffect(0.9)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, 14)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(Capsule())
            .padding()
        }
        .disabled(isDisabled || isLoading)
    }
}
