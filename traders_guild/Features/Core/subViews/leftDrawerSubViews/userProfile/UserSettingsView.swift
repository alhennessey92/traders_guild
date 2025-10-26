//
//  UserSettingsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI

struct UserSettingsSheetView: View {
    @EnvironmentObject var appState: AppState
    let onBack: () -> Void
    
    @State private var showLogoutConfirmation = false
    
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
                    
                    // Logout button
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            Text("Logout")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 20)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                appState.logout()
                onBack() // Close settings sheet
            }
        } message: {
            Text("Are you sure you want to logout?")
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

#Preview {
    UserSettingsSheetView(onBack: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
