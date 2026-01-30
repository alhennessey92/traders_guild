//
//  UserGlobalView.swift
//  traders_guild
//
//  UPDATED: Comprehensive global account view with stats, guilds, friends, activity, and more.
//  Created by Al Hennessey on 17/10/2025.
//  Updated: 29/01/2026 - Complete redesign with full functionality
//

import SwiftUI


struct UserGlobalSheetView: View {
    @EnvironmentObject var rlAppState: RLAppState
    
    let onBack: () -> Void
    
    @State private var selectedTab: GlobalTab = .overview
    @State private var isLoading = false
    
    // Sample data for demonstration
    @State private var globalStats = GlobalStatsData.sample
    @State private var userGuilds: [GlobalGuildItem] = GlobalGuildItem.samples
    @State private var friends: [GlobalFriendItem] = GlobalFriendItem.samples
    @State private var recentActivity: [GlobalActivityItem] = GlobalActivityItem.samples
    
    enum GlobalTab: String, CaseIterable {
        case overview = "Overview"
        case guilds = "Guilds"
        case friends = "Friends"
        case activity = "Activity"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .guilds: return "person.3.fill"
            case .friends: return "heart.fill"
            case .activity: return "clock.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.sheetBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                globalHeader
                
                // Tab selector
                tabSelector
                
                // Tab content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .overview:
                            overviewTab
                        case .guilds:
                            guildsTab
                        case .friends:
                            friendsTab
                        case .activity:
                            activityTab
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var globalHeader: some View {
        VStack(spacing: 0) {
            // Back button and title
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.whiteText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            
            // User global profile header
            HStack(spacing: 16) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    UnifiedMemberAvatar(
                        username: rlAppState.currentUser?.displayName ?? "User",
                        avatarURL: rlAppState.currentUser?.avatarUrl,
                        isOnline: rlAppState.currentUser?.isOnline ?? false,
                        size: 70,
                        showOnlineIndicator: false
                    )
                    
                    // Verified badge (if applicable)
                    if rlAppState.currentUser?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .background(Circle().fill(AppColors.sheetBackground).padding(-2))
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(rlAppState.currentUser?.displayName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("@\(rlAppState.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    
                    // Global reputation
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(rlAppState.currentUser?.globalReputation ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("Global Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
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
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GlobalTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.whiteText : AppColors.greyText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? AppColors.accentColor : Color.white.opacity(0.05))
                        )
                    }
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        VStack(spacing: 24) {
            // Quick stats grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                GlobalStatCard(
                    title: "Guilds Joined",
                    value: "\(globalStats.guildsJoined)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                GlobalStatCard(
                    title: "Total Friends",
                    value: "\(globalStats.totalFriends)",
                    icon: "heart.fill",
                    color: .pink
                )
                
                GlobalStatCard(
                    title: "Markers Created",
                    value: "\(globalStats.markersCreated)",
                    icon: "mappin.circle.fill",
                    color: .red
                )
                
                GlobalStatCard(
                    title: "Days Active",
                    value: "\(globalStats.daysActive)",
                    icon: "calendar",
                    color: .green
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)
            
            // Reputation breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Reputation Breakdown")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.horizontal, 25)
                
                VStack(spacing: 10) {
                    ReputationBreakdownRow(
                        title: "Trading Analysis",
                        value: globalStats.reputationFromTrading,
                        total: rlAppState.currentUser?.globalReputation ?? 0,
                        color: AppColors.accentColor
                    )
                    
                    ReputationBreakdownRow(
                        title: "Community Help",
                        value: globalStats.reputationFromCommunity,
                        total: rlAppState.currentUser?.globalReputation ?? 0,
                        color: .blue
                    )
                    
                    ReputationBreakdownRow(
                        title: "Predictions",
                        value: globalStats.reputationFromPredictions,
                        total: rlAppState.currentUser?.globalReputation ?? 0,
                        color: .green
                    )
                }
                .padding()
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .padding(.horizontal, 25)
            }
            
            // Account info
            VStack(alignment: .leading, spacing: 12) {
                Text("Account Information")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.horizontal, 25)
                
                VStack(spacing: 0) {
                    AccountInfoRow(
                        icon: "envelope.fill",
                        title: "Email",
                        value: rlAppState.currentUser?.email ?? "Not set",
                        isVerified: true
                    )
                    
                    Divider()
                        .padding(.leading, 50)
                    
                    AccountInfoRow(
                        icon: "calendar",
                        title: "Member Since",
                        value: rlAppState.currentUser?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
                    )
                    
                    Divider()
                        .padding(.leading, 50)
                    
                    AccountInfoRow(
                        icon: "clock.fill",
                        title: "Last Active",
                        value: rlAppState.currentUser?.lastSeenAt?.formatted(date: .abbreviated, time: .shortened) ?? "Now"
                    )
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .padding(.horizontal, 25)
            }
        }
    }
    
    // MARK: - Guilds Tab
    
    private var guildsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats summary
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(userGuilds.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Guilds")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(userGuilds.reduce(0) { $0 + $1.reputation })")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Combined Rep")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)
            
            // Guilds list
            VStack(spacing: 12) {
                ForEach(userGuilds) { guild in
                    GlobalGuildCard(guild: guild)
                }
            }
            .padding(.horizontal, 25)
            
            // Join more guilds button
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Discover More Guilds")
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.accentColor.opacity(0.15))
                .cornerRadius(12)
            }
            .padding(.horizontal, 25)
        }
    }
    
    // MARK: - Friends Tab
    
    private var friendsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats and search
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(friends.count) Friends")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("\(friends.filter { $0.isOnline }.count) online now")
                        .font(.caption)
                        .foregroundColor(AppColors.bullCandleGreen)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundColor(AppColors.accentColor)
                        .padding(10)
                        .background(AppColors.accentColor.opacity(0.15))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 16)
            
            // Online friends first
            let onlineFriends = friends.filter { $0.isOnline }
            let offlineFriends = friends.filter { !$0.isOnline }
            
            if !onlineFriends.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Online")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 25)
                    
                    ForEach(onlineFriends) { friend in
                        GlobalFriendCard(friend: friend)
                    }
                }
            }
            
            if !offlineFriends.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Offline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 25)
                        .padding(.top, onlineFriends.isEmpty ? 0 : 16)
                    
                    ForEach(offlineFriends) { friend in
                        GlobalFriendCard(friend: friend)
                    }
                }
            }
            
            if friends.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.greyText.opacity(0.5))
                    
                    Text("No Friends Yet")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("Start connecting with traders in your guilds!")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            }
        }
    }
    
    // MARK: - Activity Tab
    
    private var activityTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(AppColors.whiteText)
                .padding(.horizontal, 25)
                .padding(.top, 16)
            
            if recentActivity.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.greyText.opacity(0.5))
                    
                    Text("No Recent Activity")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("Your activity across all guilds will appear here.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                // Activity timeline
                VStack(spacing: 0) {
                    ForEach(Array(recentActivity.enumerated()), id: \.element.id) { index, activity in
                        GlobalActivityRow(
                            activity: activity,
                            isLast: index == recentActivity.count - 1
                        )
                    }
                }
                .padding(.horizontal, 25)
            }
        }
    }
}


// MARK: - Supporting Components

struct GlobalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct ReputationBreakdownRow: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                
                Spacer()
                
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct AccountInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var isVerified: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(AppColors.greyText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                
                HStack(spacing: 6) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                    
                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GlobalGuildCard: View {
    let guild: GlobalGuildItem
    
    var body: some View {
        HStack(spacing: 14) {
            // Guild icon
            RoundedRectangle(cornerRadius: 10)
                .fill(guild.color.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(guild.name.prefix(2)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(guild.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(guild.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    if guild.isCurrentGuild {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(guild.role.color)
                        Text(guild.role.displayName)
                            .font(.caption)
                            .foregroundColor(guild.role.color)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(guild.reputation)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}

struct GlobalFriendCard: View {
    let friend: GlobalFriendItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(friend.displayName.prefix(2)).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    )
                
                Circle()
                    .fill(friend.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(AppColors.sheetBackground, lineWidth: 2)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                
                Text(friend.isOnline ? "Online" : "Last seen \(friend.lastSeen)")
                    .font(.caption)
                    .foregroundColor(friend.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "message.fill")
                        .font(.subheadline)
                        .foregroundColor(AppColors.accentColor)
                        .padding(8)
                        .background(AppColors.accentColor.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 8)
    }
}

struct GlobalActivityRow: View {
    let activity: GlobalActivityItem
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(activity.type.color)
                    .frame(width: 10, height: 10)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: activity.type.icon)
                        .font(.caption)
                        .foregroundColor(activity.type.color)
                    
                    Text(activity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                }
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                
                HStack(spacing: 8) {
                    Text(activity.timestamp)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.7))
                    
                    if let guild = activity.guildName {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.5))
                        Text(guild)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.7))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.bottom, isLast ? 0 : 16)
    }
}


// MARK: - Sample Data Models

struct GlobalStatsData {
    let guildsJoined: Int
    let totalFriends: Int
    let markersCreated: Int
    let daysActive: Int
    let reputationFromTrading: Int
    let reputationFromCommunity: Int
    let reputationFromPredictions: Int
    
    static let sample = GlobalStatsData(
        guildsJoined: 3,
        totalFriends: 24,
        markersCreated: 156,
        daysActive: 89,
        reputationFromTrading: 650,
        reputationFromCommunity: 280,
        reputationFromPredictions: 420
    )
}

struct GlobalGuildItem: Identifiable {
    let id = UUID()
    let name: String
    let role: RLMemberRole
    let reputation: Int
    let memberCount: Int
    let color: Color
    let isCurrentGuild: Bool
    
    static let samples: [GlobalGuildItem] = [
        GlobalGuildItem(name: "Forex Masters", role: .admin, reputation: 850, memberCount: 342, color: .blue, isCurrentGuild: true),
        GlobalGuildItem(name: "Crypto Traders", role: .moderator, reputation: 420, memberCount: 567, color: .orange, isCurrentGuild: false),
        GlobalGuildItem(name: "Stock Analysis", role: .member, reputation: 80, memberCount: 189, color: .green, isCurrentGuild: false),
    ]
}

struct GlobalFriendItem: Identifiable {
    let id = UUID()
    let displayName: String
    let username: String
    let isOnline: Bool
    let lastSeen: String
    
    static let samples: [GlobalFriendItem] = [
        GlobalFriendItem(displayName: "Sarah Chen", username: "sarahc", isOnline: true, lastSeen: ""),
        GlobalFriendItem(displayName: "Mike Johnson", username: "mikej", isOnline: true, lastSeen: ""),
        GlobalFriendItem(displayName: "Alex Kim", username: "alexk", isOnline: false, lastSeen: "2h ago"),
        GlobalFriendItem(displayName: "Emma Wilson", username: "emmaw", isOnline: false, lastSeen: "Yesterday"),
        GlobalFriendItem(displayName: "James Brown", username: "jbrown", isOnline: false, lastSeen: "3 days ago"),
    ]
}

struct GlobalActivityItem: Identifiable {
    let id = UUID()
    let type: ActivityType
    let title: String
    let description: String
    let timestamp: String
    let guildName: String?
    
    enum ActivityType {
        case marker
        case reputation
        case achievement
        case social
        case guild
        
        var icon: String {
            switch self {
            case .marker: return "mappin.circle.fill"
            case .reputation: return "shield.pattern.checkered"
            case .achievement: return "medal.fill"
            case .social: return "heart.fill"
            case .guild: return "person.3.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .marker: return .red
            case .reputation: return AppColors.accentColor
            case .achievement: return .yellow
            case .social: return .pink
            case .guild: return .blue
            }
        }
    }
    
    static let samples: [GlobalActivityItem] = [
        GlobalActivityItem(type: .reputation, title: "+25 Reputation", description: "Your EUR/USD analysis was well received", timestamp: "2 hours ago", guildName: "Forex Masters"),
        GlobalActivityItem(type: .marker, title: "Marker Hit Target", description: "Your BTC/USD long target was reached", timestamp: "5 hours ago", guildName: "Crypto Traders"),
        GlobalActivityItem(type: .achievement, title: "New Award!", description: "Earned 'Consistent Analyst' badge", timestamp: "Yesterday", guildName: nil),
        GlobalActivityItem(type: .social, title: "New Friend", description: "You and Sarah Chen are now friends", timestamp: "2 days ago", guildName: nil),
        GlobalActivityItem(type: .guild, title: "Joined Guild", description: "Joined Stock Analysis guild", timestamp: "1 week ago", guildName: nil),
    ]
}


// MARK: - Preview

#Preview {
    UserGlobalSheetView(onBack: {})
        .environmentObject(RLAppState())
        .preferredColorScheme(.dark)
}








// //
// //  UserHelpView.swift
// //  traders_guild
// //
// //  Created by Al Hennessey on 17/10/2025.
// //

// import SwiftUI
// struct UserGlobalSheetView: View {
//     let onBack: () -> Void
    
//     var body: some View {
//         ScrollView {
//             VStack(alignment: .leading, spacing: 20) {
//                 // Back button
//                 Button(action: onBack) {
//                     HStack(spacing: 6) {
//                         Image(systemName: "chevron.left")
//                             .font(.headline)
//                         Text("Back")
//                             .font(.headline)
//                     }
//                     .foregroundColor(AppColors.whiteText)
//                 }
//                 .padding(.top, 20)
                
//                 Text("Your Global Account")
//                     .font(.title)
//                     .fontWeight(.bold)
//                     .foregroundColor(AppColors.whiteText)
                
//                 // Settings content
//                 VStack(spacing: 16) {
//                     HelpRow(title: "Notifications", icon: "bell.fill")
//                     HelpRow(title: "Privacy", icon: "lock.fill")
//                     HelpRow(title: "Account", icon: "person.fill")
//                     HelpRow(title: "Appearance", icon: "paintbrush.fill")
//                     HelpRow(title: "Language", icon: "globe")
//                     HelpRow(title: "Help & Support", icon: "questionmark.circle.fill")
//                 }
                
//                 Spacer(minLength: 100)
//             }
//             .padding(.horizontal)
//         }
//     }
// }




// struct HelpRow: View {
//     let title: String
//     let icon: String
    
//     var body: some View {
//         Button(action: {
//             // Handle setting tap
//         }) {
//             HStack {
//                 Image(systemName: icon)
//                     .font(.headline)
//                     .foregroundColor(AppColors.accentColor)
//                     .frame(width: 30)
                
//                 Text(title)
//                     .font(.subheadline)
//                     .foregroundColor(AppColors.whiteText)
                
//                 Spacer()
                
//                 Image(systemName: "chevron.right")
//                     .font(.caption)
//                     .foregroundColor(AppColors.greyText)
//             }
//             .padding()
//             .background(Color.white.opacity(0.05))
//             .cornerRadius(10)
//         }
//     }
// }
