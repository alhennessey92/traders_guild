//
//  TextBoxView.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//
import SwiftUI

/// Generic full-width button for login/signup
struct TextBoxView: View {
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    
    var body: some View {
        
    }
    
}

#Preview {
    // Example usage of PrimaryButton in previews
    VStack(spacing: 20) {
        TextBoxView(
            title: "Sign in with Email",
            iconName: "envelope.fill",
            backgroundColor: AppColors.whiteText,
            foregroundColor: AppColors.gradientBackgroundDark,
            destination: LoginView()
        )

    }
    .padding()
}
