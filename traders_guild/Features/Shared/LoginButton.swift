//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
import SwiftUI

/// Generic full-width button for login/signup
struct LoginButton: View {
    let title: String
    let iconName: String?
    let backgroundColor: Color
    let foregroundColor: Color
     // Optional navigation
    let action: (() -> Void)? = nil // ✅ default to nil
    
    var body: some View {
        HStack {
            if let icon = iconName {
                Image(systemName: icon)
                    .font(.title2)
            }
            Text(title)
                .font(.headline)
                .scaleEffect(0.9)
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity, maxHeight: 50)
        .background(backgroundColor)
    //  .cornerRadius(12)
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    

}

#Preview {
    // Example usage of PrimaryButton in previews
    VStack(spacing: 20) {
        LoginButton(
            title: "Sign in with Email",
            iconName: "envelope.fill",
            backgroundColor: AppColors.whiteText,
            foregroundColor: AppColors.gradientBackgroundDark,
            
        )

    }
    .padding()
}
