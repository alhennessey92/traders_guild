//
//  PrimaryButton.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import SwiftUI

/// A reusable primary button for your app.
/// - Styled consistently (so all primary actions look the same).
/// - Can be reused across signup/login and anywhere else.
/// - Takes a title (string) and an action (closure).
struct PrimaryButton: View {
    
    /// The text shown inside the button (e.g. "Continue", "Sign Up").
    let title: String
    
    /// The action (function) to run when the button is tapped.
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // Text label inside the button
            Text(title)
                .font(.headline)          // Medium-bold font, readable size
                .foregroundColor(.white)  // White text for contrast
                .padding()                // Add some space inside the button
                .frame(maxWidth: .infinity) // Button stretches full width of parent container
                .background(Color.blue)   // Background color (changeable later if needed)
                .cornerRadius(12)         // Rounded corners for a modern look
                .shadow(radius: 2)        // Small shadow to make it pop
        }
        .padding(.horizontal) // Space around the button (so it doesn’t touch screen edges)
    }
}

#Preview {
    // Example usage of PrimaryButton in previews
    VStack(spacing: 20) {
        PrimaryButton(title: "Continue") {
            print("Continue tapped")
        }
        PrimaryButton(title: "Sign Up") {
            print("Sign Up tapped")
        }
    }
    .padding()
}
