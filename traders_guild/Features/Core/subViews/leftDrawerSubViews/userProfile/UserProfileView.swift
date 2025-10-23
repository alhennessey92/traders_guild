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
    case help
}


struct UserProfileDetailView: View {
    let user: GuildMembership
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currentUser: UserStore
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
                    SwitchGuildView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentContent = .profile
                                selectedDetent = .fraction(0.6)  // Shrink back
                            }
                        },
                        selectedDetent: $selectedDetent
                    )
                    .transition(.opacity)
                case .settings:
                    UserSettingsSheetView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.6)  // Shrink back
                        }
                    })
                    .transition(.opacity)
                case .help:
                    UserHelpSheetView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.6)  // Shrink back
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
        
        
//        .background(AppColors.drawerBackground.opacity(0.8))
    }
    
    private var profileView: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            UserProfileHeaderView(user: user)
            
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .center, spacing: 2) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(currentUser.user?.globalReputation ?? 0)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Global Reputation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 20)
            
//            Spacer(minLength: 0)
            
            Divider()
                

            HStack(spacing: 8) {
                DrawerActionButton(
                    title: "Switch Guild",
                    imageName: "arrow.trianglehead.2.counterclockwise",
                    backgroundColor: AppColors.whiteText.opacity(0.8),
                    foregroundColor: Color.black,
                    strokeColor: Color.black,
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .switchGuild
                            //selectedDetent = .large
                            // Keep current detent for switch guild
                        }
                    }
                )
                
                Spacer()
                
                DrawerActionButton(
                    imageName: "questionmark.circle",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .help
                            selectedDetent = .large  // EXPAND TO LARGE FOR SETTINGS
                        }
                    }
                )
                
                DrawerActionButton(
                    imageName: "gear",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
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
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .background(AppColors.sheetBackground)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
                
            }
        )
    }
    
}



// MARK: - User Profile Header Component
struct UserProfileHeaderView: View {
    let user: GuildMembership
    
    @EnvironmentObject var currentUser: UserStore
    
    var body: some View {
        // Top header section with gradient background
        VStack(alignment: .leading, spacing: 20) {
            // User header
            HStack(spacing: 15) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(currentUser.user?.name.prefix(2) ?? "Unknown"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    if currentUser.user?.isOnline == true {
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
                    Text(currentUser.user?.name ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text(user.roleInGuild.rawValue)
                        .font(.caption)
                        .foregroundColor(user.roleInGuild.foregroundColor)
                        .fontWeight(user.roleInGuild.fontWeight)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 60) // Leave space for dismiss button
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)
        
        VStack(alignment: .leading, spacing: 6) {
            // member since
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.greyText)
                Text("Member for \(user.timeInGuild)")
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
        .padding(.horizontal, 25)
        
        
        Divider()
            
        }
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        
    }
}


// MARK: - User Profile Footer Component
struct UserProfileFooterView: View {
    @State private var currentContent: UserSheetContent = .profile
    @Binding var selectedDetent: PresentationDetent  // ADD THIS
    
    var body: some View {
        
        Divider()
            .padding(.horizontal)

        HStack(spacing: 8) {
            DrawerActionButton(
                title: "Switch Guild",
                imageName: "arrow.trianglehead.2.counterclockwise",
                backgroundColor: AppColors.whiteText.opacity(0.8),
                foregroundColor: Color.black,
                strokeColor: Color.black,
                strokeWidth: 0.5,
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentContent = .switchGuild
                        //selectedDetent = .large
                        // Keep current detent for switch guild
                    }
                }
            )
            
            Spacer()
            
            DrawerActionButton(
                imageName: "questionmark.circle",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                foregroundColor: AppColors.whiteText.opacity(0.9),
                strokeColor: AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentContent = .help
                        selectedDetent = .large  // EXPAND TO LARGE FOR SETTINGS
                    }
                }
            )
            
            DrawerActionButton(
                imageName: "gear",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                foregroundColor: AppColors.whiteText.opacity(0.9),
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
        .padding(.horizontal, 25)
        
    }
    
}
