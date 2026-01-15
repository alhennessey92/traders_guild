//
//  UserProfileView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//  UPDATED: Now uses ProfileContentView for unified tab styling
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
    
    @EnvironmentObject var rlAppState: RLAppState
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var currentContent: UserSheetContent = .profile
    @Binding var selectedDetent: PresentationDetent
    
    // Profile data loading
    @State private var extendedProfile: UserProfileExtendedDTO? = nil
    @State private var markersSummary: UserMarkersSummaryDTO? = nil
    @State private var userMarkers: [TopMarkerDTO] = []
    @State private var awards: [UserAwardDTO] = []
    @State private var awardsSummary: AwardsSummaryDTO? = nil
    @State private var isLoading = true

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
        .task {
            await loadProfileData()
        }
    }
    
    // MARK: - Profile View
    
    private var profileView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Keep existing header
            UserProfileHeaderView()
            
            // New unified profile content with tabs (Overview, Markers, Awards)
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .padding(.top, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProfileContentView(
                    extendedProfile: extendedProfile,
                    markersSummary: markersSummary,
                    userMarkers: userMarkers,
                    awards: awards,
                    awardsSummary: awardsSummary,
                    stats: buildStats(),
                    isCurrentUser: true,
                    username: rlAppState.currentUser?.username ?? "", // TODO: check for change
                    onMarkerTap: { marker in
                        // Navigate to marker on chart
                        leftDrawerViewModel.requestNavigationToMarker(marker)
                        dismiss()
                    }
                )
            }
            
            Divider()
            
            // Keep existing footer buttons
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
    
    // MARK: - Load Profile Data
    // TODO: Need prod functionality
    private func loadProfileData() async {
        // In production, these would be API calls via LeftDrawerViewModel
        // For now, use sample data with a small delay to show loading state
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        await MainActor.run {
            extendedProfile = SampleData.currentUserExtendedProfile
            markersSummary = SampleData.currentUserMarkersSummary
            userMarkers = SampleData.userPlacedMarkers
            awards = SampleData.currentUserAwards
            awardsSummary = SampleData.awardsSummary
            isLoading = false
        }
    }
    
    // MARK: - Build Stats
    
    // TODO: Need prod functionality
    private func buildStats() -> [ProfileStatDTO] {
        guard let user = rlAppState.currentUser else { return [] }
        guard let membership = rlAppState.currentMembership else { return [] }
        
        return [
            ProfileStatDTO(
                label: "Guild Reputation",
                value: "\(membership.reputation)",
                icon: "shield.checkered",
                color: AppColors.accentColor,
                trend: .up("+32 this week")
            ),
            ProfileStatDTO(
                label: "Global Reputation",
                value: "\(user.globalReputation)",
                icon: "globe",
                color: .blue,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Days in Guild",
                value: "\(membership.daysInGuild)",
                icon: "calendar",
                color: .green,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Contribution",
                value: "\(membership.contributionScore)%",
                icon: "chart.bar.fill",
                color: .orange,
                trend: .up("+5%")
            )
        ]
    }
}


// MARK: - User Profile Header Component
struct UserProfileHeaderView: View {
    
    @EnvironmentObject var rlAppState: RLAppState
    
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
                            Text(String(rlAppState.currentUser?.displayName.prefix(2) ?? "Unknown"))
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
                    Text(rlAppState.currentUser?.displayName ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text(rlAppState.currentMembership?.role ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(rlAppState.currentMembership?.memberRole.color)
                        .fontWeight(.bold) // TODO: add bold
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
                Text("\(rlAppState.currentMembership?.memberSince ?? "Member Since - Unknown")")
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
                Text("\(rlAppState.currentMembership?.reputation ?? 0)")
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


// MARK: - User Profile Footer Component (Legacy - kept for reference)
struct UserProfileFooterView: View {
    @State private var currentContent: UserSheetContent = .profile
    @Binding var selectedDetent: PresentationDetent
    
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
        
    }
    
}

