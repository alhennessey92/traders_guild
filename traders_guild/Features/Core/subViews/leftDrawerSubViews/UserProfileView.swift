//
//  UserProfileView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI
// MARK: - Enhanced Announcement Detail View
struct UserProfileDetailView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content - starts higher
            VStack(alignment: .leading, spacing: 20) {
                // User header (no spacer at top now)
                HStack(spacing: 15) {
                    // Avatar with online indicator
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(String(user.name.prefix(2)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accentColor)
                            )
                        
                        if user.isOnline {
                            Circle()
                                .fill(AppColors.bullCandleGreen)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
                                )
                        }
                    }
                    
                    // User info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text(user.role.rawValue)
                            .font(.caption)
                            .foregroundColor(roleForegroundColor(for: user.role))
                            .fontWeight(roleWeight(for: user.role))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 60) // Leave space for dismiss button
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    // member since
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.greyText)
                        Text("Member Since")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                    }
                    
                    // User guild reputation
                    HStack(alignment: .center, spacing: 1) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(user.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        Text("Guild Reputation")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 0)
                
                Divider()

                HStack(spacing: 8) {
                    DrawerActionButton(
                        imageName: "nosign",
                        backgroundColor: AppColors.bearCandleRed.opacity(0.3),
                        foregroundColor: AppColors.whiteText,
                        strokeColor: AppColors.bearCandleRed.opacity(0.6),
                        strokeWidth: 0.5,
                        action: { }
                    )
                    
                    Spacer()
                    
                    DrawerActionButton(
                        imageName: "person.fill.badge.plus",
                        backgroundColor: AppColors.whiteText.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: { }
                    )

                    DrawerActionButton(
                        title: "Chat",
                        imageName: "message.fill",
                        backgroundColor: AppColors.whiteText.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: { }
                    )
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
            .padding(.horizontal)
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 16)
        }
    }
    
    private func roleForegroundColor(for role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    private func roleWeight(for role: UserRole) -> Font.Weight {
        switch role {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
}
