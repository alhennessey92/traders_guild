//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
import SwiftUI
struct StandardButton: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void    // no default
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .scaleEffect(0.9)
                .foregroundColor(foregroundColor)
                .padding(.vertical, 14)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .cornerRadius(12)
        }
        .padding()
    }
}
/// Generic full-width button for login/signup
//struct StandardButton: View {
//    let title: String
//    let backgroundColor: Color
//    let foregroundColor: Color
//  // Optional navigation
//    let action: (() -> Void)? = nil // ✅ default to nil
//    
//    var body: some View {
//        Text(title)
//            .font(.headline)
//            .scaleEffect(0.9)
//            .foregroundColor(foregroundColor)
//            .padding(.vertical, 14)      // vertical space, dynamic height
//            .padding(.horizontal)
//            .frame(maxWidth: .infinity)
//            .background(backgroundColor)
//            .cornerRadius(12)
//            .padding()
//    }
//    
//
//}

//#Preview {
//    // Example usage of PrimaryButton in previews
//    VStack(spacing: 20) {
//        StandardButton(
//            title: "Sign in with Email",
//            backgroundColor: AppColors.whiteText,
//            foregroundColor: AppColors.gradientBackgroundDark,
//            destination: LoginView()
//        )
//
//    }
//    .padding()
//}

