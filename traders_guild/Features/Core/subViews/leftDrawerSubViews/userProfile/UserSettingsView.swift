//
//  UserSettingsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI
struct UserSettingsSheetView: View {
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.whiteText)
                }
                .padding(.top, 20)
                
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                
                // Settings content
                VStack(spacing: 16) {
                    SettingsRow(title: "Notifications", icon: "bell.fill")
                    SettingsRow(title: "Privacy", icon: "lock.fill")
                    SettingsRow(title: "Account", icon: "person.fill")
                    SettingsRow(title: "Appearance", icon: "paintbrush.fill")
                    SettingsRow(title: "Language", icon: "globe")
                    SettingsRow(title: "Help & Support", icon: "questionmark.circle.fill")
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
    }
}




struct SettingsRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Handle setting tap
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(AppColors.accentColor)
                    .frame(width: 30)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
    }
}
