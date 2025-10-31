
//
//  ErrorToastView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI

struct ErrorToastView: View {
    let alert: AppAlert
    let onDismiss: () -> Void
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: alert.severity.icon)
                .font(.title3)
                .foregroundColor(alert.severity.color)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)  // ✅ Increased horizontal padding for capsule
        .padding(.vertical, 14)     // ✅ Adjusted vertical padding
        .background(
            Capsule()  // ✅ Changed from RoundedRectangle to Capsule
                .fill(AppColors.gradientBackgroundDark)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()  // ✅ Changed from RoundedRectangle to Capsule
                .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                opacity = 1
                offset = 0
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismissToast()
            }
        }
    }
    
    private func dismissToast() {
        withAnimation(.easeIn(duration: 0.3)) {
            opacity = 0
            offset = 20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}
