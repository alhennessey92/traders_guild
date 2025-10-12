//
//  UserProfileView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI


// MARK: - Handle the sheet content for the User Profile View
enum UserSheetContent {
    case profile
    case switchGuild
    case settings
}


struct UserProfileDetailView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @State private var currentContent: UserSheetContent = .profile
    @Binding var selectedDetent: PresentationDetent  // ADD THIS

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Switch content based on state with slide transitions
            Group {
                switch currentContent {
                case .profile:
                    profileView
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .identity  // Instant removal
                        ))
                case .switchGuild:
                    SwitchGuildView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.35)  // Shrink back
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                case .settings:
                    UserSettingsSheetView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.35)  // Shrink back
                        }
                    })
                    .transition(.opacity)
                }
            }
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
    }
    
    private var profileView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // User header
            HStack(spacing: 15) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 60, height: 60)
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
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text("Member Since")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                // User guild reputation
                HStack(alignment: .center, spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(user.reputation)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Guild Reputation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            
            Spacer(minLength: 0)
            
            Divider()

            HStack(spacing: 8) {
                DrawerActionButton(
                    title: "Switch Guild",
                    imageName: "arrow.trianglehead.2.counterclockwise",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                    foregroundColor: AppColors.whiteText.opacity(0.8),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .switchGuild
                            // Keep current detent for switch guild
                        }
                    }
                )
                
                Spacer()
                
                DrawerActionButton(
                    imageName: "gear",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                    foregroundColor: AppColors.whiteText.opacity(0.8),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .settings
                            selectedDetent = .large  // EXPAND TO LARGE FOR SETTINGS
                        }
                    }
                )
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
        .padding(.horizontal)
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
// MARK: - Enhanced Announcement Detail View
//struct UserProfileDetailView: View {
//    let user: User
//    @Environment(\.dismiss) private var dismiss
//
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            // Main content - starts higher
//            VStack(alignment: .leading, spacing: 20) {
//                // User header (no spacer at top now)
//                HStack(spacing: 15) {
//                    // Avatar with online indicator
//                    ZStack(alignment: .bottomTrailing) {
//                        Circle()
//                            .fill(AppColors.accentColor.opacity(0.3))
//                            .frame(width: 60, height: 60)
//                            .overlay(
//                                Text(String(user.name.prefix(2)))
//                                    .font(.caption)
//                                    .fontWeight(.bold)
//                                    .foregroundColor(AppColors.accentColor)
//                            )
//                        
//                        if user.isOnline {
//                            Circle()
//                                .fill(AppColors.bullCandleGreen)
//                                .frame(width: 12, height: 12)
//                                .overlay(
//                                    Circle()
//                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
//                                )
//                        }
//                    }
//                    
//                    // User info
//                    VStack(alignment: .leading, spacing: 3) {
//                        Text(user.name)
//                            .font(.title3)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        Text(user.role.rawValue)
//                            .font(.caption)
//                            .foregroundColor(roleForegroundColor(for: user.role))
//                            .fontWeight(roleWeight(for: user.role))
//                            .lineLimit(1)
//                    }
//                    
//                    Spacer(minLength: 60) // Leave space for dismiss button
//                }
//                .padding(.horizontal)
//                .padding(.top, 20)
//                
//                VStack(alignment: .leading, spacing: 6) {
//                    // member since
//                    HStack(spacing: 6) {
//                        Image(systemName: "calendar")
//                            .font(.caption)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.greyText)
//                        Text("Member Since")
//                            .font(.caption)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                    
//                    // User guild reputation
//                    HStack(alignment: .center, spacing: 2) {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(user.reputation)")
//                            .font(.caption)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("Guild Reputation")
//                            .font(.caption)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.greyText)
//                            .padding(.leading, 4)
//                    }
//                }
//                .padding(.horizontal)
//                
//                Spacer(minLength: 0)
//                
//                Divider()
//
//                HStack(spacing: 8) {
//                    DrawerActionButton(
//                        title: " Switch Guild",
//                        imageName: "arrow.trianglehead.2.counterclockwise",
//                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
//                        foregroundColor: AppColors.whiteText.opacity(0.8),
//                        strokeColor: AppColors.whiteText.opacity(0.3),
//                        strokeWidth: 0.5,
//                        action: { }
//                    )
//                    
//                    Spacer()
//                    
//                    DrawerActionButton(
//                        imageName: "gear",
//                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
//                        foregroundColor: AppColors.whiteText.opacity(0.8),
//                        strokeColor: AppColors.whiteText.opacity(0.3),
//                        strokeWidth: 0.5,
//                        action: { }
//                    )
//
//                    
//                }
////                .padding(.bottom, 20)
//                .padding(.horizontal)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//            .padding(.top, 20)
//            .padding(.horizontal)
//
//            
//            // Floating dismiss button overlaid on top
//            Button(action: { dismiss() }) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(.title2)
//                    .foregroundColor(.secondary)
//            }
//            .padding(.top, 20)
//            .padding(.trailing, 20)
//        }
//        .background(AppColors.drawerBackground.opacity(0.2))
//    }
//    
//    private func roleForegroundColor(for role: UserRole) -> Color {
//        switch role {
//        case .admin: return .orange
//        case .moderator: return .blue
//        case .member: return AppColors.whiteText.opacity(0.7)
//        }
//    }
//    
//    private func roleWeight(for role: UserRole) -> Font.Weight {
//        switch role {
//        case .admin: return .bold
//        case .moderator: return .bold
//        case .member: return .regular
//        }
//    }
//}
