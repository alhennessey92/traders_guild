//
//  LearnBasicsBox.swift
//  traders_guild
//
//  Created by Al Hennessey on 24/09/2025.
//

import SwiftUI

/// Generic full-width button for login/signup
struct LearnBasicsBox: View {
    let title: String
    let iconName: String
    let description: String
    
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
            }
            Spacer()
            
            Image(systemName: iconName)
                .foregroundColor(AppColors.accentColor)
                .font(.system(size: 25))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColors.fadedBackground, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.gradientBackgroundLight))
        )
        .padding(.horizontal)
        .fixedSize(horizontal: false, vertical: true) // ensures dynamic height
    }
    
    

}

#Preview {
    VStack(spacing: 20) {
        // Example usage of PrimaryButton in previews
        LearnBasicsBox(title: "Guilds", iconName: "shield.pattern.checkered", description: "The basics")
        LearnBasicsBox(title: "Guilds", iconName: "shield.pattern.checkered", description: "The basics")
        Spacer()
    }
    .padding(.top, 20) // optional top padding
    .background(AppColors.gradientBackgroundDark)
    .ignoresSafeArea(edges: .bottom)
}
