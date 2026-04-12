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
    let extendedProfile: RLUserProfileDTO?
    let markersSummary: RLUserGlobalStatisticsDTO?
    let userMarkers: [RLTopMarkerDTO]
    let awards: [RLUserAwardDTO]
    let awardsSummary: RLAwardsSummaryDTO?
    let stats: [ProfileStatDTO]
    
    // Configuration
    let isCurrentUser: Bool
    let username: String
    var tabs: [ProfileTab] = [.overview, .markers, .awards]
    var activityItems: [RLActivityItem] = []
    var isActivityLoading: Bool = false
    var activityLoadError: String? = nil
    var guildReputationProfile: RLReputationProfileDTO? = nil
    var guildAccuracyProfile: RLAccuracyProfileDTO? = nil
    var onOpenGuildReputationBreakdown: (() -> Void)? = nil
    var onOpenGuildAccuracyBreakdown: (() -> Void)? = nil
    
    // Callbacks
    var onMarkerTap: ((RLTopMarkerDTO) -> Void)? = nil
    
    @State private var selectedTab: ProfileTab = .overview
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar - unified style
            UnifiedTabBar(
                selectedTab: $selectedTab,
                tabs: tabs,
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
                            isCurrentUser: isCurrentUser,
                            guildReputationProfile: guildReputationProfile,
                            guildAccuracyProfile: guildAccuracyProfile,
                            onOpenGuildReputationBreakdown: onOpenGuildReputationBreakdown,
                            onOpenGuildAccuracyBreakdown: onOpenGuildAccuracyBreakdown
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
                    case .activity:
                        ActivityTabContent(
                            items: activityItems,
                            isLoading: isActivityLoading,
                            errorMessage: activityLoadError
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
        case .activity: return activityItems.count
        }
    }
}

// MARK: - ================================================================================================
// MARK: - OVERVIEW TAB CONTENT
// MARK: - ================================================================================================

struct OverviewTabContent: View {
    let extendedProfile: RLUserProfileDTO?
    let stats: [ProfileStatDTO]
    let isCurrentUser: Bool
    let guildReputationProfile: RLReputationProfileDTO?
    let guildAccuracyProfile: RLAccuracyProfileDTO?
    var onOpenGuildReputationBreakdown: (() -> Void)? = nil
    var onOpenGuildAccuracyBreakdown: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats grid
            if !stats.isEmpty {
                statsSection
            }

            if isCurrentUser,
               (onOpenGuildReputationBreakdown != nil || onOpenGuildAccuracyBreakdown != nil) {
                guildBreakdownEntrySection
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
                if !profile.tradingInterests.isEmpty {
                    interestsSection(interests: profile.tradingInterests)
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

    private var guildBreakdownEntrySection: some View {
        VStack(spacing: 10) {
            if let onOpenGuildReputationBreakdown {
                BreakdownEntryCard(
                    title: "Guild Reputation Breakdown",
                    subtitle: "Tier, weekly delta, contribution sources",
                    value: guildReputationProfile.map { "\($0.reputation)" } ?? "--",
                    icon: "shield.checkered",
                    iconColor: AppColors.guildReputationAccent,
                    action: onOpenGuildReputationBreakdown
                )
            }

            if let onOpenGuildAccuracyBreakdown {
                BreakdownEntryCard(
                    title: "Guild Accuracy Breakdown",
                    subtitle: "Win/loss, streaks, R:R metrics",
                    value: guildAccuracyProfile?.accuracyFormatted ?? "--",
                    icon: "target",
                    iconColor: AppColors.statusPositive,
                    action: onOpenGuildAccuracyBreakdown
                )
            }
        }
    }
    
    private func personalInfoSection(profile: RLUserProfileDTO) -> some View {
        ProfileInfoCard(title: "Personal", icon: "person.fill") {
            VStack(spacing: 12) {
                if let location = profile.location {
                    infoRow(icon: "location.fill", label: "Location", value: location)
                }
                
                if let timezone = profile.timezone {
                    infoRow(icon: "clock.fill", label: "Timezone", value: timezone)
                }
                
                infoRow(icon: "person.badge.clock", label: "Member since", value: profile.createdAt.memberSinceFormatted)
            }
        }
    }
    
    // MARK: - Trading Info Section
    
    private func tradingInfoSection(profile: RLUserProfileDTO) -> some View {
        ProfileInfoCard(title: "Trading", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                HStack {
                    Text("Experience")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(profile.experienceLevelDisplay)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(profile.experienceColor)
                    }
                }
                
                if let style = profile.tradingStyle {
                    infoRow(icon: "speedometer", label: "Style", value: style)
                }
            }
        }
    }
    
    // MARK: - Interests Section
    
    private func interestsSection(interests: [RLTradingInterestItem]) -> some View {
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
                            .fill(interest.isPrimary ? AppColors.accentColor : AppColors.panelFillEmphasis)
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
                                .fill(AppColors.symbolDetailCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.linkedMarkerAttachmentStroke, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
    
    // MARK: - Social Links Section
    
    private func socialLinksSection(links: [RLSocialLinkItem]) -> some View {
        ProfileInfoCard(title: "Social", icon: "link") {
            VStack(spacing: 10) {
                ForEach(links) { link in
                    HStack(spacing: 12) {
                        Image(systemName: link.icon)
                            .font(.subheadline)
                            .foregroundColor(link.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.displayName)
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

struct BreakdownEntryCard: View {
    let title: String
    let subtitle: String
    let value: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.accentColor)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppColors.markerListCapsuleFill)
                        )
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.markerListCapsuleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ================================================================================================
// MARK: - MARKERS TAB CONTENT
// MARK: - ================================================================================================

struct MarkersTabContent: View {
    let summary: RLUserGlobalStatisticsDTO?
    let markers: [RLTopMarkerDTO]
    var onMarkerTap: ((RLTopMarkerDTO) -> Void)? = nil
    
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
                        MarkerListItem(
                            marker: marker,
                            style: .capsule,
                            showMyBadge: marker.isCurrentUserMarker
                        ) {
                            onMarkerTap?(marker)
                        }
                    }
                }
            }
        }
    }
    
    private func markersSummarySection(summary: RLUserGlobalStatisticsDTO) -> some View {
        VStack(spacing: 12) {
            // Top row stats
            HStack(spacing: 12) {
                SummaryStatBadge(
                    value: "\(summary.totalMarkersPlaced)",
                    label: "Markers",
                    icon: "mappin.and.ellipse",
                    color: AppColors.statusInfo
                )
                SummaryStatBadge(
                    value: summary.accuracyFormatted,
                    label: "Accuracy",
                    icon: "target",
                    color: AppColors.statusPositive
                )
                SummaryStatBadge(
                    value: "\(summary.totalLikesReceived)",
                    label: "Likes",
                    icon: "heart.fill",
                    color: AppColors.statusNegative
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
                                    .fill(AppColors.panelFillEmphasis)
                            )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.markerListCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - ================================================================================================
// MARK: - ACTIVITY TAB CONTENT
// MARK: - ================================================================================================

struct ActivityTabContent: View {
    let items: [RLActivityItem]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(AppColors.accentColor)
                    .padding(.top, 24)
            } else if let errorMessage {
                UnifiedEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Unable to load activity",
                    subtitle: errorMessage
                )
                .padding(.top, 16)
            } else if items.isEmpty {
                UnifiedEmptyState(
                    icon: "clock.badge.questionmark",
                    title: "No guild activity yet",
                    subtitle: "Your current guild activity will appear here."
                )
                .padding(.top, 20)
            } else {
                UnifiedActivityTimeline(items: items, style: .card)
            }
        }
    }
}

enum UnifiedActivityTimelineStyle {
    case card
    case plain
}

struct UnifiedActivityTimeline: View {
    let items: [RLActivityItem]
    var style: UnifiedActivityTimelineStyle = .card
    var horizontalPadding: CGFloat = 0

    var body: some View {
        let content = LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                UnifiedActivityRow(item: item, isLast: index == items.count - 1)
            }
        }

        switch style {
        case .card:
            content
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.markerListCapsuleFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                        )
                )
        case .plain:
            content
                .padding(.horizontal, horizontalPadding)
        }
    }
}

struct UnifiedActivityRow: View {
    let item: RLActivityItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(item.activityColor)
                    .frame(width: 9, height: 9)

                if !isLast {
                    Rectangle()
                        .fill(AppColors.panelFillEmphasis)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: item.activityIcon)
                        .font(.caption)
                        .foregroundColor(item.activityColor)
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                }

                Text(item.description)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                HStack(spacing: 8) {
                    Text(item.relativeTimestamp)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.8))
                    if let guildName = item.guildName {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.5))
                        Text(guildName)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.8))
                    }
                }

                HStack(spacing: 6) {
                    if let guildDelta = item.guildRepDelta {
                        UnifiedActivityDeltaBadge(label: "Guild", value: guildDelta)
                    }
                    if let globalDelta = item.globalRepDelta {
                        UnifiedActivityDeltaBadge(label: "Global", value: globalDelta)
                    }
                    if let metricDelta = item.metricDelta, let metricLabel = item.metricLabel {
                        UnifiedActivityDeltaBadge(
                            label: metricLabel.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: metricDelta
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(.bottom, isLast ? 0 : 14)
    }
}

struct UnifiedActivityDeltaBadge: View {
    let label: String
    let value: Int

    private var tint: Color {
        value >= 0 ? AppColors.statusPositive : AppColors.statusNegative
    }

    var body: some View {
        Text("\(label) \(value >= 0 ? "+" : "")\(value)")
            .font(.caption2)
            .foregroundColor(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15))
            .cornerRadius(6)
    }
}

extension RLActivityItem {
    var activityIcon: String {
        switch type {
        case "marker": return "mappin.circle.fill"
        case "reputation": return "shield.checkered"
        case "achievement": return "medal.fill"
        case "guild": return "person.3.fill"
        case "event": return "calendar.badge.clock"
        case "role": return "person.crop.circle.badge.checkmark"
        case "report": return "exclamationmark.bubble.fill"
        case "moderation": return "gavel.fill"
        default: return "clock.fill"
        }
    }

    var activityColor: Color {
        switch type {
        case "marker": return .red
        case "reputation": return AppColors.accentColor
        case "achievement": return .yellow
        case "guild": return .blue
        case "event": return .mint
        case "role": return .indigo
        case "report": return AppColors.moderationOrange
        case "moderation": return .purple
        default: return AppColors.greyText
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - ================================================================================================
// MARK: - AWARDS TAB CONTENT
// MARK: - ================================================================================================

struct AwardsTabContent: View {
    let awards: [RLUserAwardDTO]
    let summary: RLAwardsSummaryDTO?
    
    @State private var selectedCategory: RLAwardCategory? = nil
    
    private var filteredAwards: [RLUserAwardDTO] {
        if let category = selectedCategory {
            return awards.filter { $0.categoryEnum == category }
        }
        return awards
    }
    
    private var earnedAwards: [RLUserAwardDTO] {
        filteredAwards.filter { $0.isEarned }
    }
    
    private var inProgressAwards: [RLUserAwardDTO] {
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
    
    private func awardsSummarySection(summary: RLAwardsSummaryDTO) -> some View {
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
                .background(AppColors.surfaceWhite20)
            
            // Total points
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.moderationOrange)
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
                .background(AppColors.surfaceWhite20)
            
            // Rarity breakdown mini
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach([RLAwardRarity.epic, .rare, .uncommon], id: \.self) { rarity in
                        if summary.count(for: rarity) > 0 {
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
                .fill(AppColors.markerListCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
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
                
                ForEach(RLAwardCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        title: category.displayName,
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
    let award: RLUserAwardDTO
    
    var body: some View {
        let category = award.categoryEnum
        let rarity = award.rarityEnum
        VStack(spacing: 8) {
            // Icon with rarity glow
            ZStack {
                // Glow effect for rare+ awards
                if rarity != .common {
                    Circle()
                        .fill(rarity.glowColor)
                        .frame(width: 56, height: 56)
                        .blur(radius: 8)
                }
                
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(rarity.color, lineWidth: 2)
                    )
                
                Image(systemName: award.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(category.color)
                
                // New badge
                if award.isNew {
                    Text("NEW")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(AppColors.onAccentForeground)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.statusNegative))
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
                                .fill(AppColors.panelFillEmphasis)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(category.color)
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
                Text(rarity.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(rarity.color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(award.isEarned ? AppColors.userListRowFillPressed : AppColors.userListRowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            award.isNew ? rarity.color.opacity(0.5) : AppColors.markerListCapsuleStroke,
                            lineWidth: award.isNew ? 1.5 : 1
                        )
                )
        )
        .opacity(award.isEarned ? 1.0 : 0.7)
    }
}

private extension Date {
    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
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
                .fill(AppColors.markerListCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
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
                .fill(AppColors.markerListCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
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
                    .fill(isSelected ? color : AppColors.symbolDetailCardFill)
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
