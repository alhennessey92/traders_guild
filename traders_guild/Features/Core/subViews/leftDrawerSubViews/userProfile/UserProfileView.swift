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
    @State private var extendedProfile: RLUserProfileDTO? = nil
    @State private var markersSummary: RLUserGlobalStatisticsDTO? = nil
    @State private var userMarkers: [RLTopMarkerDTO] = []
    @State private var awards: [RLUserAwardDTO] = []
    @State private var awardsSummary: RLAwardsSummaryDTO? = nil
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
    private func loadProfileData() async {
        await rlAppState.refreshCurrentGuildReputation()
        let data = await leftDrawerViewModel.loadCurrentUserProfile(rlAppState: rlAppState)
        await MainActor.run {
            extendedProfile = data.profile
            markersSummary = data.statistics
            userMarkers = data.userMarkers
            awards = data.awards
            awardsSummary = data.awardsSummary
            isLoading = false
        }
    }
    
    // MARK: - Build Stats (real data from currentMembership and currentUser; no placeholder trends)
    private func buildStats() -> [ProfileStatDTO] {
        guard let user = rlAppState.currentUser else { return [] }
        guard let membership = rlAppState.currentMembership else { return [] }
        var items: [ProfileStatDTO] = [
            ProfileStatDTO(
                label: "Guild Reputation",
                value: "\(membership.reputation)",
                icon: "shield.checkered",
                color: AppColors.accentColor,
                trend: nil
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
                trend: nil
            )
        ]
        if let accuracy = membership.accuracyFormatted {
            items.insert(
                ProfileStatDTO(
                    label: "Guild Accuracy",
                    value: accuracy,
                    icon: "target",
                    color: .green,
                    trend: nil
                ),
                at: 2
            )
        }
        return items
    }
}


// MARK: - User Profile Header Component (unified: username · role · reputation · accuracy)
struct UserProfileHeaderView: View {
    @EnvironmentObject var rlAppState: RLAppState

    private var isOnline: Bool {
        guard let currentUser = rlAppState.currentUser else { return false }
        return rlAppState.effectiveOnlineStatus(userId: currentUser.id, fallback: currentUser.isOnline)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 15) {
                UnifiedMemberAvatar(
                    username: rlAppState.currentUser?.username ?? "Unknown",
                    avatarURL: rlAppState.currentUser?.avatarUrl,
                    isOnline: isOnline,
                    size: 60
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(rlAppState.currentUser?.username ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    if let membership = rlAppState.currentMembership {
                        UnifiedRoleBadge(
                            roleName: membership.memberRole.displayName,
                            roleColor: membership.memberRole.color,
                            reputation: membership.reputation,
                            accuracy: membership.accuracyFormatted,
                            showReputation: true,
                            fontSize: .subheadline,
                            iconSize: .caption
                        )
                    }
                }
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text(rlAppState.currentMembership?.memberSince ?? "Member Since – Unknown")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
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

