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
    case global
}

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var currentContent: UserSheetContent = .profile
    @State private var selectedTab: ProfileTab = .overview  // ADD THIS
    @Binding var selectedDetent: PresentationDetent

    // Define your tabs
    enum ProfileTab: String, CaseIterable {
        case overview = "Overview"
        case activity = "Activity"
        case achievements = "Achievements"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch currentContent {
                case .profile:
                    profileView
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .identity
                        ))
                case .switchGuild:
                    SwitchGuildView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentContent = .profile
                                selectedDetent = .fraction(0.6)
                            }
                        },
                        selectedDetent: $selectedDetent
                    )
                    .transition(.opacity)
                case .settings:
                    UserSettingsSheetView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.6)
                        }
                    })
                    .transition(.opacity)
                case .global:
                    UserGlobalSheetView(onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .profile
                            selectedDetent = .fraction(0.6)
                        }
                    })
                    .transition(.opacity)
                }
            }
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }
    
    private var profileView: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            UserProfileHeaderView()
            
            
            
            // Tab Headers - Fixed
            tabHeader
            
            Divider()
            
            // Scrollable Tab Content
            ScrollView(.vertical, showsIndicators: false) {
                tabContent
                    .padding(.horizontal, 25)
                    .padding(.vertical, 20)
            }
            
            Divider()
            
            // Action Buttons
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
                        }
                    }
                )
                
                Spacer()
                
                DrawerActionButton(
                    imageName: "globe",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .global
                            selectedDetent = .large
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
                            selectedDetent = .large
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
    
    // MARK: - Tab Header
    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
                        
                        // Active indicator
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 12)
        .background(AppColors.sheetBackground)
    }
    
    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .activity:
            activityContent
        case .achievements:
            achievementsContent
        }
    }
    
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title3)
                .fontWeight(.bold)
            
            // Add your overview content here
            Text("User stats, bio, and other overview information...")
                .foregroundColor(AppColors.greyText)
            
            // Example content to demonstrate scrolling
            ForEach(0..<5) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Section \(i + 1)")
                        .font(.headline)
                    Text("Some content here that makes the view scrollable...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    
    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title3)
                .fontWeight(.bold)
            
            // Add your activity content here
            ForEach(0..<8) { i in
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity \(i + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Description of the activity")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    private var achievementsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.title3)
                .fontWeight(.bold)
            
            // Add your achievements content here
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<10) { i in
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundColor(AppColors.accentColor)
                        Text("Achievement \(i + 1)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
    }
}


// MARK: - User Profile Header Component
struct UserProfileHeaderView: View {
    
    @EnvironmentObject var appState: AppState
    
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
                            Text(String(appState.currentUser?.name.prefix(2) ?? "Unknown"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    //always going to be online as is current user
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 2)
                        )
                    
                }
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.currentUser?.name ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text(appState.currentUser?.guildMembership.roleInGuild.displayName ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(appState.currentUser?.guildMembership.roleInGuild.roleForegroundColor)
                        .fontWeight(appState.currentUser?.guildMembership.roleInGuild.roleFontWeight)
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
                Text("\(appState.currentUser?.guildMembership.memberSince ?? "Member Since - Unknown")")
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
                Text("\(appState.currentUser?.guildMembership.reputation ?? 0)")
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
                        currentContent = .global
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
