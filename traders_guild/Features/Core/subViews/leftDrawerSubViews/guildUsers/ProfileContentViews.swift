//
//  ProfileContentViews.swift
//  traders_guild
//
//  Unified profile content views with tabbed interface
//  Used by both CurrentUserProfile and GuildMemberProfile
//  Features: Overview, Markers, and Awards tabs
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - PROFILE CONTENT VIEW (Shared Component)
// MARK: - ================================================================================================

/// Unified profile content with tabbed interface
/// Can be used for both current user and guild member profiles
struct ProfileContentView: View {
    // Profile data
    let extendedProfile: UserProfileExtendedDTO?
    let markersSummary: UserMarkersSummaryDTO?
    let userMarkers: [TopMarkerDTO]
    let awards: [UserAwardDTO]
    let awardsSummary: AwardsSummaryDTO?
    let stats: [ProfileStatDTO]
    
    // Configuration
    let isCurrentUser: Bool
    let username: String
    
    // Callbacks
    var onMarkerTap: ((TopMarkerDTO) -> Void)? = nil
    
    @State private var selectedTab: ProfileTab = .overview
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar - unified style
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in getCountForTab(tab) },
                spacing: 6
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Tab content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .overview:
                        OverviewTabContent(
                            extendedProfile: extendedProfile,
                            stats: stats,
                            isCurrentUser: isCurrentUser
                        )
                    case .markers:
                        MarkersTabContent(
                            summary: markersSummary,
                            markers: userMarkers,
                            onMarkerTap: onMarkerTap
                        )
                    case .awards:
                        AwardsTabContent(
                            awards: awards,
                            summary: awardsSummary
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func getCountForTab(_ tab: ProfileTab) -> Int {
        switch tab {
        case .overview: return 0 // Don't show count for overview
        case .markers: return userMarkers.count
        case .awards: return awards.filter { $0.isEarned }.count
        }
    }
}

// MARK: - ================================================================================================
// MARK: - OVERVIEW TAB CONTENT
// MARK: - ================================================================================================

struct OverviewTabContent: View {
    let extendedProfile: UserProfileExtendedDTO?
    let stats: [ProfileStatDTO]
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats grid
            if !stats.isEmpty {
                statsSection
            }
            
            // Profile info sections
            if let profile = extendedProfile {
                // Bio section
                if let bio = profile.bio, !bio.isEmpty {
                    ProfileInfoCard(title: "About", icon: "text.quote") {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Personal info
                personalInfoSection(profile: profile)
                
                // Trading info
                tradingInfoSection(profile: profile)
                
                // Interests
                if !profile.interests.isEmpty {
                    interestsSection(interests: profile.interests)
                }
                
                // Preferred pairs
                if !profile.preferredPairs.isEmpty {
                    preferredPairsSection(pairs: profile.preferredPairs)
                }
                
                // Social links (only show for current user or if they've shared)
                if !profile.socialLinks.isEmpty {
                    socialLinksSection(links: profile.socialLinks)
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stats) { stat in
                ProfileStatCard(stat: stat)
            }
        }
    }
    
    // MARK: - Personal Info Section
    
    private func personalInfoSection(profile: UserProfileExtendedDTO) -> some View {
        ProfileInfoCard(title: "Personal", icon: "person.fill") {
            VStack(spacing: 12) {
                if let location = profile.location {
                    infoRow(icon: "location.fill", label: "Location", value: location)
                }
                
                if let age = profile.age {
                    infoRow(icon: "calendar", label: "Age", value: "\(age) years old")
                }
                
                if let timezone = profile.timezone {
                    infoRow(icon: "clock.fill", label: "Timezone", value: timezone)
                }
                
                infoRow(icon: "person.badge.clock", label: "Member since", value: profile.memberSinceFormatted)
            }
        }
    }
    
    // MARK: - Trading Info Section
    
    private func tradingInfoSection(profile: UserProfileExtendedDTO) -> some View {
        ProfileInfoCard(title: "Trading", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                HStack {
                    Text("Experience")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(profile.experience.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(profile.experience.color)
                        Text("(\(profile.experience.yearsRange))")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                if let style = profile.tradingStyle {
                    infoRow(icon: "speedometer", label: "Style", value: style)
                }
            }
        }
    }
    
    // MARK: - Interests Section
    
    private func interestsSection(interests: [TradingInterestDTO]) -> some View {
        ProfileInfoCard(title: "Interests", icon: "star.fill") {
            FlowLayout(spacing: 8) {
                ForEach(interests) { interest in
                    HStack(spacing: 6) {
                        Image(systemName: interest.icon)
                            .font(.caption)
                        Text(interest.name)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(interest.isPrimary ? .white : AppColors.whiteText.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(interest.isPrimary ? AppColors.accentColor : Color.white.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Preferred Pairs Section
    
    private func preferredPairsSection(pairs: [String]) -> some View {
        ProfileInfoCard(title: "Preferred Pairs", icon: "dollarsign.circle.fill") {
            FlowLayout(spacing: 8) {
                ForEach(pairs, id: \.self) { pair in
                    Text(pair)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
    
    // MARK: - Social Links Section
    
    private func socialLinksSection(links: [SocialLinkDTO]) -> some View {
        ProfileInfoCard(title: "Social", icon: "link") {
            VStack(spacing: 10) {
                ForEach(links) { link in
                    HStack(spacing: 12) {
                        Image(systemName: link.platform.icon)
                            .font(.subheadline)
                            .foregroundColor(link.platform.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.platform.rawValue)
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(link.username)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)
                        }
                        
                        Spacer()
                        
                        if link.url != nil {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(AppColors.accentColor)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppColors.accentColor)
                    .frame(width: 16)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.whiteText)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - MARKERS TAB CONTENT
// MARK: - ================================================================================================

struct MarkersTabContent: View {
    let summary: UserMarkersSummaryDTO?
    let markers: [TopMarkerDTO]
    var onMarkerTap: ((TopMarkerDTO) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary stats
            if let summary = summary {
                markersSummarySection(summary: summary)
            }
            
            // Markers list
            if markers.isEmpty {
                UnifiedEmptyState(
                    icon: "mappin.slash",
                    title: "No markers yet",
                    subtitle: "Markers placed on charts will appear here"
                )
                .padding(.top, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(markers) { marker in
                        ProfileMarkerCard(marker: marker) {
                            onMarkerTap?(marker)
                        }
                    }
                }
            }
        }
    }
    
    private func markersSummarySection(summary: UserMarkersSummaryDTO) -> some View {
        VStack(spacing: 12) {
            // Top row stats
            HStack(spacing: 12) {
                SummaryStatBadge(
                    value: "\(summary.totalMarkers)",
                    label: "Markers",
                    icon: "mappin.and.ellipse",
                    color: .blue
                )
                SummaryStatBadge(
                    value: summary.accuracyFormatted,
                    label: "Accuracy",
                    icon: "target",
                    color: .green
                )
                SummaryStatBadge(
                    value: "\(summary.totalLikes)",
                    label: "Likes",
                    icon: "heart.fill",
                    color: .red
                )
            }
            
            // Top symbols
            if !summary.topSymbols.isEmpty {
                HStack(spacing: 6) {
                    Text("Top symbols:")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    
                    ForEach(summary.topSymbols.prefix(3), id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Profile Marker Card

struct ProfileMarkerCard: View {
    let marker: TopMarkerDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticFeedback.light.trigger()
            onTap()
        }) {
            HStack(alignment: .top, spacing: 10) {
                // Marker type icon
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(marker.type.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: marker.type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(marker.type.color)
                    }
                    
                    Text(marker.type.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(marker.type.color)
                        .lineLimit(1)
                }
                .frame(width: 44)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Symbol and time
                    HStack {
                        Text(marker.symbolTicker)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.whiteText)
                        
                        Spacer()
                        
                        Text(marker.createdAtFormatted)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }
                    
                    // Note preview
                    if let note = marker.notePreview, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    // Stats row
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .font(.caption2)
                                .foregroundColor(marker.isLikedByCurrentUser ? .red : AppColors.greyText)
                            Text("\(marker.likeCount)")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                            Text("\(marker.commentCount)")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - ================================================================================================
// MARK: - AWARDS TAB CONTENT
// MARK: - ================================================================================================

struct AwardsTabContent: View {
    let awards: [UserAwardDTO]
    let summary: AwardsSummaryDTO?
    
    @State private var selectedCategory: AwardCategory? = nil
    
    private var filteredAwards: [UserAwardDTO] {
        if let category = selectedCategory {
            return awards.filter { $0.category == category }
        }
        return awards
    }
    
    private var earnedAwards: [UserAwardDTO] {
        filteredAwards.filter { $0.isEarned }
    }
    
    private var inProgressAwards: [UserAwardDTO] {
        filteredAwards.filter { !$0.isEarned }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Summary section
            if let summary = summary {
                awardsSummarySection(summary: summary)
            }
            
            // Category filter
            categoryFilter
            
            // Awards content
            if filteredAwards.isEmpty {
                UnifiedEmptyState(
                    icon: "trophy",
                    title: "No awards yet",
                    subtitle: "Keep trading to earn awards!"
                )
                .padding(.top, 20)
            } else {
                // Earned awards
                if !earnedAwards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Earned")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(earnedAwards) { award in
                                AwardCard(award: award)
                            }
                        }
                    }
                }
                
                // In progress awards
                if !inProgressAwards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("In Progress")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(inProgressAwards) { award in
                                AwardCard(award: award)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Summary Section
    
    private func awardsSummarySection(summary: AwardsSummaryDTO) -> some View {
        HStack(spacing: 16) {
            // Total awards
            VStack(spacing: 4) {
                Text("\(summary.totalAwards)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Awards")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))
            
            // Total points
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(summary.pointsFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                }
                Text("Points")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))
            
            // Rarity breakdown mini
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach([AwardRarity.epic, .rare, .uncommon], id: \.self) { rarity in
                        if let count = summary.rarityBreakdown[rarity], count > 0 {
                            Circle()
                                .fill(rarity.color)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                Text("Rare+")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryFilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }
                
                ForEach(AwardCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Award Card

struct AwardCard: View {
    let award: UserAwardDTO
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon with rarity glow
            ZStack {
                // Glow effect for rare+ awards
                if award.rarity != .common {
                    Circle()
                        .fill(award.rarity.glowColor)
                        .frame(width: 56, height: 56)
                        .blur(radius: 8)
                }
                
                Circle()
                    .fill(award.category.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(award.rarity.color, lineWidth: 2)
                    )
                
                Image(systemName: award.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(award.category.color)
                
                // New badge
                if award.isNew {
                    Text("NEW")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 20, y: -20)
                }
            }
            
            // Name
            Text(award.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Progress bar for incomplete awards
            if !award.isEarned, let progress = award.progress {
                VStack(spacing: 2) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(award.category.color)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(award.progressPercentage)%")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.greyText)
                }
            } else {
                // Rarity label
                Text(award.rarity.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(award.rarity.color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(award.isEarned ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            award.isNew ? award.rarity.color.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: award.isNew ? 1.5 : 1
                        )
                )
        )
        .opacity(award.isEarned ? 1.0 : 0.7)
    }
}

// MARK: - ================================================================================================
// MARK: - SUPPORTING COMPONENTS
// MARK: - ================================================================================================

// MARK: - Profile Info Card

struct ProfileInfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppColors.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
            }
            
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Profile Stat Card

struct ProfileStatCard: View {
    let stat: ProfileStatDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.icon)
                    .font(.caption)
                    .foregroundColor(stat.color)
                Spacer()
                if let trend = stat.trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 8, weight: .bold))
                        switch trend {
                        case .up(let value), .down(let value):
                            Text(value)
                                .font(.system(size: 9, weight: .medium))
                        case .neutral:
                            EmptyView()
                        }
                    }
                    .foregroundColor(trend.color)
                }
            }
            
            Text(stat.value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
            
            Text(stat.label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Summary Stat Badge

struct SummaryStatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : AppColors.whiteText.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout (for tags/interests)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x - spacing)
            }
            
            self.size.height = y + rowHeight
        }
    }
}
