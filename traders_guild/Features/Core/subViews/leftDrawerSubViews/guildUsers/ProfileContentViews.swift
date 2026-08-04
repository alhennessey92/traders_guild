//
//  ProfileContentViews.swift
//  traders_guild
//
//  Unified profile content views with tabbed interface
//  Used by both CurrentUserProfile and GuildMemberProfile
//  Features: Overview, Markers, and Awards tabs
//

import SwiftUI

extension Notification.Name {
    static let profileTabRequested = Notification.Name("profileTabRequested")
}

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
    var awardsEnabled: Bool = true
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

    private var visibleTabs: [ProfileTab] {
        tabs.filter { tab in
            tab != .awards || awardsEnabled
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar - unified style
            UnifiedTabBar(
                selectedTab: $selectedTab,
                tabs: visibleTabs,
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
        .onAppear {
            if !visibleTabs.contains(selectedTab) {
                selectedTab = .overview
            }
        }
        .onChange(of: awardsEnabled) { _, _ in
            if !visibleTabs.contains(selectedTab) {
                selectedTab = .overview
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileTabRequested)) { notification in
            guard let tab = notification.object as? ProfileTab,
                  visibleTabs.contains(tab) else { return }
            selectedTab = tab
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

    /// Profile overview stats use a hero + secondary tiles layout (in contrast
    /// to the global profile's uniform 2-col grid). The first stat is the
    /// headline metric (Guild Reputation) and gets a wide hero card with its
    /// 30-day sparkline; everything else collapses into a single horizontal
    /// row of compact tiles below.
    private var statsSection: some View {
        VStack(spacing: 10) {
            if let hero = stats.first {
                ProfileHeroStatCard(stat: hero)
            }
            if stats.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(stats.dropFirst())) { stat in
                        ProfileCompactStatTile(stat: stat)
                    }
                }
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
                    icon: ReputationGlyph.symbolName,
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
                let languageCode = LocaleOptionCatalog.languageCode(from: profile.language)
                let countryCode = LocaleOptionCatalog.countryCode(from: profile.location)

                if !languageCode.isEmpty {
                    infoRow(icon: "globe", label: "Language", value: LocaleOptionCatalog.languageLabel(for: languageCode))
                }

                if !countryCode.isEmpty {
                    infoRow(icon: "location.fill", label: "Location", value: LocaleOptionCatalog.countryDisplay(for: countryCode))
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
        case "reputation": return ReputationGlyph.symbolName
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

private enum AwardDisplayState: Equatable {
    case earned
    case inProgress
    case locked
}

private struct AwardDisplayItem: Identifiable, Equatable {
    let id: UUID
    let awardTypeId: UUID
    let name: String
    let description: String
    let icon: String
    let category: String
    let rarity: String
    let pointsValue: Int
    let requiredValue: Int?
    let familyKey: String?
    let tier: Int?
    let scope: String?
    let progress: Double?
    let currentValue: Int?
    let isNew: Bool
    let state: AwardDisplayState

    init(userAward: RLUserAwardDTO, awardType: RLAwardTypeDTO?) {
        self.id = userAward.id
        self.awardTypeId = userAward.awardTypeId
        self.name = userAward.name
        self.description = userAward.description
        self.icon = userAward.icon
        self.category = userAward.category
        self.rarity = userAward.rarity
        self.pointsValue = userAward.pointsValue
        self.requiredValue = awardType?.requiredValue
        self.familyKey = userAward.familyKey
        self.tier = userAward.tier
        self.scope = userAward.scope
        self.progress = userAward.progress
        self.currentValue = userAward.currentValue
        self.isNew = userAward.isNew
        self.state = userAward.isEarned ? .earned : .inProgress
    }

    init(awardType: RLAwardTypeDTO) {
        self.id = awardType.id
        self.awardTypeId = awardType.id
        self.name = awardType.name
        self.description = awardType.description
        self.icon = awardType.icon
        self.category = awardType.category
        self.rarity = awardType.rarity
        self.pointsValue = awardType.pointsValue
        self.requiredValue = awardType.requiredValue
        self.familyKey = awardType.familyKey
        self.tier = awardType.tier
        self.scope = awardType.scope
        self.progress = 0
        self.currentValue = 0
        self.isNew = false
        self.state = .locked
    }

    var categoryEnum: RLAwardCategory {
        RLAwardCategory(rawValue: category) ?? .special
    }

    var rarityEnum: RLAwardRarity {
        RLAwardRarity(rawValue: rarity) ?? .common
    }

    var progressPercentage: Int {
        Int((progress ?? 0) * 100)
    }

    var progressDisplay: String {
        switch state {
        case .earned:
            return "Completed"
        case .inProgress:
            if let currentValue, let requiredValue {
                return "\(currentValue)/\(requiredValue)"
            }
            return "\(progressPercentage)%"
        case .locked:
            if let requiredValue {
                return "Goal \(requiredValue)"
            }
            return "Not started"
        }
    }
}

struct AwardsTabContent: View {
    let awards: [RLUserAwardDTO]
    let summary: RLAwardsSummaryDTO?

    @EnvironmentObject private var rlAppState: RLAppState
    @State private var selectedCategory: RLAwardCategory? = nil
    @State private var awardTypes: [RLAwardTypeDTO] = []
    @State private var isLoadingAwardTypes = false
    @State private var didFailAwardTypesLoad = false

    private var awardTypesById: [UUID: RLAwardTypeDTO] {
        Dictionary(uniqueKeysWithValues: awardTypes.map { ($0.id, $0) })
    }

    private var displayAwards: [AwardDisplayItem] {
        let awardedTypeIds = Set(awards.map(\.awardTypeId))
        let userItems = awards.map { award in
            AwardDisplayItem(userAward: award, awardType: awardTypesById[award.awardTypeId])
        }
        let lockedItems = awardTypes
            .filter { !awardedTypeIds.contains($0.id) }
            .map { AwardDisplayItem(awardType: $0) }

        return (userItems + lockedItems).sorted { lhs, rhs in
            let lhsCategoryIndex = RLAwardCategory.allCases.firstIndex(of: lhs.categoryEnum) ?? RLAwardCategory.allCases.count
            let rhsCategoryIndex = RLAwardCategory.allCases.firstIndex(of: rhs.categoryEnum) ?? RLAwardCategory.allCases.count
            if lhsCategoryIndex != rhsCategoryIndex {
                return lhsCategoryIndex < rhsCategoryIndex
            }
            if lhs.familyKey != rhs.familyKey {
                return (lhs.familyKey ?? lhs.name) < (rhs.familyKey ?? rhs.name)
            }
            if lhs.tier != rhs.tier {
                return (lhs.tier ?? 0) < (rhs.tier ?? 0)
            }
            return lhs.name < rhs.name
        }
    }

    private var filteredAwards: [AwardDisplayItem] {
        if let category = selectedCategory {
            return displayAwards.filter { $0.categoryEnum == category }
        }
        return displayAwards
    }

    private var earnedAwards: [AwardDisplayItem] {
        filteredAwards.filter { $0.state == .earned }
    }

    private var inProgressAwards: [AwardDisplayItem] {
        filteredAwards.filter { $0.state == .inProgress }
    }

    private var lockedAwards: [AwardDisplayItem] {
        filteredAwards.filter { $0.state == .locked }
    }

    private var categories: [RLAwardCategory] {
        let present = Set(displayAwards.map(\.categoryEnum))
        let dynamic = RLAwardCategory.allCases.filter { present.contains($0) }
        return dynamic.isEmpty ? RLAwardCategory.allCases : dynamic
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
            if isLoadingAwardTypes && awards.isEmpty {
                ProgressView()
                    .scaleEffect(1.1)
                    .padding(.top, 20)
            } else if filteredAwards.isEmpty {
                UnifiedEmptyState(
                    icon: "trophy",
                    title: "No awards yet",
                    subtitle: didFailAwardTypesLoad ? "Available awards could not be loaded." : "Keep trading to earn awards!"
                )
                .padding(.top, 20)
            } else {
                awardSection(title: "Earned", awards: earnedAwards)
                awardSection(title: "In Progress", awards: inProgressAwards)
                awardSection(title: "Available", awards: lockedAwards)
            }
        }
        .task {
            await loadAvailableAwards()
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

                ForEach(categories, id: \.self) { category in
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

    @ViewBuilder
    private func awardSection(title: String, awards: [AwardDisplayItem]) -> some View {
        if !awards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(awards) { award in
                        AwardCard(award: award)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadAvailableAwards() async {
        guard awardTypes.isEmpty, !isLoadingAwardTypes else { return }
        isLoadingAwardTypes = true
        didFailAwardTypesLoad = false

        do {
            awardTypes = try await rlAppState.realApi.getAwardTypes()
        } catch {
            didFailAwardTypesLoad = true
            print("⚠️ Failed to load available awards: \(error)")
        }

        isLoadingAwardTypes = false
    }
}

// MARK: - Award Card

private struct AwardCard: View {
    let award: AwardDisplayItem

    var body: some View {
        let category = award.categoryEnum
        let rarity = award.rarityEnum
        let isLocked = award.state == .locked
        let isEarned = award.state == .earned
        let progress = min(max(award.progress ?? 0, 0), 1)

        VStack(spacing: 8) {
            // Icon with rarity glow
            ZStack {
                // Glow effect for rare+ awards
                if rarity != .common && !isLocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [rarity.glowColor, rarity.glowColor.opacity(0)],
                                center: .center,
                                startRadius: 12,
                                endRadius: 32
                            )
                        )
                        .frame(width: 64, height: 64)
                }

                Circle()
                    .fill(isLocked ? AppColors.panelFillEmphasis : category.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(isLocked ? AppColors.surfaceWhite20 : rarity.color, lineWidth: 2)
                    )

                Image(systemName: award.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isLocked ? AppColors.greyText : category.color)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.greyText)
                        .padding(4)
                        .background(Circle().fill(AppColors.sheetBackground))
                        .offset(x: 18, y: -18)
                }

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
                .foregroundColor(isLocked ? AppColors.greyText : AppColors.whiteText)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(award.description)
                .font(.system(size: 9))
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(minHeight: 32, alignment: .top)

            // Progress bar for incomplete and available awards
            if !isEarned {
                VStack(spacing: 2) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.panelFillEmphasis)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isLocked ? AppColors.surfaceWhite20 : category.color)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 4)

                    Text(award.progressDisplay)
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
                .fill(isEarned ? AppColors.userListRowFillPressed : AppColors.userListRowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            award.isNew ? rarity.color.opacity(0.5) : AppColors.markerListCapsuleStroke,
                            lineWidth: award.isNew ? 1.5 : 1
                        )
                )
        )
        .opacity(isLocked ? 0.55 : (isEarned ? 1.0 : 0.78))
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
        // Same elevation as the guild cards, so the profile sheet's sections and
        // its guild list read as one family rather than flat panels beside raised ones.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.guildCardBase)
                .shadow(color: AppColors.guildCardShadow, radius: 10, x: 0, y: 3)
        )
    }
}

// MARK: - Profile Stat Card

private func profileStatDelta(_ trend: ProfileStatDTO.StatTrend?) -> (text: String, tint: Color, icon: String)? {
    guard let trend else { return nil }
    switch trend {
    case .up(let value):
        return (value, trend.color, trend.icon)
    case .down(let value):
        return (value, trend.color, trend.icon)
    case .neutral:
        return nil
    }
}

/// Wide headline card used for the profile's primary metric (Guild Reputation).
/// Renders the value, an optional delta chip, and an optional 30-day sparkline.
struct ProfileHeroStatCard: View {
    let stat: ProfileStatDTO

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: stat.icon)
                        .font(.caption)
                        .foregroundColor(stat.color)
                    Text(stat.label)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                    if let delta = profileStatDelta(stat.trend) {
                        HStack(spacing: 2) {
                            Image(systemName: delta.icon)
                                .font(.system(size: 8, weight: .bold))
                            Text(delta.text)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(delta.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(delta.tint.opacity(0.12)))
                    }
                }

                Text(stat.value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(stat.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let sparkline = stat.sparkline, !sparkline.isEmpty {
                StatSparkline(values: sparkline, tint: stat.color, height: 40)
                    .frame(width: 110)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.guildStatisticsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.guildStatisticsCardStroke, lineWidth: 1)
                )
        )
    }
}

/// Compact secondary tile: label + value only. Sized to share a single
/// horizontal row of four below the hero card. No icons, no sparkline, no
/// gauge — visual diversity belongs in the hero card and the breakdown sheets.
struct ProfileCompactStatTile: View {
    let stat: ProfileStatDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(stat.value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(stat.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.guildStatisticsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.guildStatisticsCardStroke, lineWidth: 1)
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
