
# Traders Guild - Comprehensive DTO Examples & Usage Guide

This document provides extensive examples for every DTO in your application, including:
- JSON response examples (what your backend should return)
- Swift decoding examples
- API endpoint examples
- SwiftUI integration examples
- Edge cases and validation
- Real-world usage scenarios

---

## Table of Contents
1. [User & Member DTOs](#user--member-dtos)
2. [Guild DTOs](#guild-dtos)
3. [Messaging DTOs](#messaging-dtos)
4. [Symbol/Trading DTOs](#symboltrading-dtos)
5. [API Integration Examples](#api-integration-examples)
6. [SwiftUI View Examples](#swiftui-view-examples)
7. [Error Handling & Edge Cases](#error-handling--edge-cases)

---

## User & Member DTOs

### CurrentUserDTO

#### Example JSON Response
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "john.developer@email.com",
  "name": "John Developer",
  "username": "johndev",
  "avatarURL": "https://cdn.tradersguild.com/avatars/johndev.jpg",
  "globalReputation": 2450,
  "notificationCount": 3,
  "unreadMessages": 7
}
```

#### Swift Usage Example
```swift
// Decoding from API response
func fetchCurrentUser() async throws -> CurrentUserDTO {
    let url = URL(string: "https://api.tradersguild.co/api/v1/users/me")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(CurrentUserDTO.self, from: data)
}

// Using in AppState
class AppState: ObservableObject {
    @Published var currentUser: CurrentUserDTO?
    
    func login(email: String, password: String) async throws {
        // After successful authentication...
        self.currentUser = try await fetchCurrentUser()
        
        // Save to Keychain
        try KeychainManager.save(currentUser!, for: "current_user")
        
        // Update app badge
        UIApplication.shared.applicationIconBadgeNumber = currentUser!.totalBadgeCount
    }
}

// Display in UI
struct ProfileHeaderView: View {
    let user: CurrentUserDTO
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.title2)
                        .bold()
                    Text(user.displayUsername)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Badge indicator
                if user.hasUnreadItems {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(user.totalBadgeCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                }
            }
            
            HStack {
                Label("\(user.globalReputation)", systemImage: "star.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}
```

---

### GlobalMemberDTO

#### Example JSON Response
```json
{
  "id": "987e6543-e21b-32d1-a654-426614174111",
  "email": "alex.thompson@email.com",
  "name": "Alex Thompson",
  "username": "alexthompson",
  "avatarURL": "https://cdn.tradersguild.com/avatars/alexthompson.jpg",
  "isOnline": true,
  "globalReputation": 1825
}
```

#### Swift Usage Example
```swift
// Display member in a list
struct MemberRowView: View {
    let member: GlobalMemberDTO
    
    var body: some View {
        HStack {
            // Avatar with online status
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: member.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // Online indicator
                if member.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.headline)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Reputation
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                Text("\(member.globalReputation)")
                    .font(.caption)
            }
            .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}
```

---

### GuildMembershipDTO

#### Example JSON Response
```json
{
  "id": "456e7890-e12c-34d5-a789-426614174222",
  "globalMember": {
    "id": "987e6543-e21b-32d1-a654-426614174111",
    "email": "alex.thompson@email.com",
    "name": "Alex Thompson",
    "username": "alexthompson",
    "avatarURL": "https://cdn.tradersguild.com/avatars/alexthompson.jpg",
    "isOnline": true,
    "globalReputation": 1825
  },
  "guild": {
    "id": "111e2222-e33b-44d5-a666-426614174333",
    "name": "KAOS Trading",
    "memberCount": 156,
    "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
    "reputation": 45000,
    "owner": {
      "id": "owner-membership-id",
      "globalMember": {
        "id": "owner-user-id",
        "email": "owner@example.com",
        "name": "Guild Owner",
        "username": "guildowner",
        "avatarURL": null,
        "isOnline": false,
        "globalReputation": 5000
      },
      "guild": {
        "id": "111e2222-e33b-44d5-a666-426614174333",
        "name": "KAOS Trading",
        "memberCount": 156,
        "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
        "reputation": 45000,
        "owner": null,
        "isOpen": true
      },
      "roleInGuild": "admin",
      "dateJoined": "2024-01-15T10:30:00Z",
      "reputation": 5000,
      "daysInGuild": 282,
      "contributionScore": 95,
      "isOnline": false
    },
    "isOpen": true
  },
  "roleInGuild": "moderator",
  "dateJoined": "2024-06-20T14:45:00Z",
  "reputation": 850,
  "daysInGuild": 127,
  "contributionScore": 78,
  "isOnline": true
}
```

#### Swift Usage Example
```swift
// Display member profile
struct GuildMemberProfileView: View {
    let membership: GuildMembershipDTO
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    AsyncImage(url: URL(string: membership.globalMember.avatarURL ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(membership.statusColor, lineWidth: 4)
                    )
                    
                    Text(membership.globalMember.name)
                        .font(.title)
                        .bold()
                    
                    Text("@\(membership.globalMember.username)")
                        .foregroundColor(.secondary)
                    
                    // Role badge
                    Text(membership.roleInGuild.displayName)
                        .font(.caption)
                        .fontWeight(membership.roleInGuild.fontWeight)
                        .foregroundColor(membership.roleInGuild.foregroundColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(membership.roleInGuild.foregroundColor.opacity(0.1))
                        )
                    
                    // Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(membership.statusColor)
                            .frame(width: 8, height: 8)
                        Text(membership.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(membership.reputation)")
                            .font(.title2)
                            .bold()
                        Text("Guild Rep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(membership.contributionScore)")
                            .font(.title2)
                            .bold()
                        Text("Activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(membership.globalMember.globalReputation)")
                            .font(.title2)
                            .bold()
                        Text("Global Rep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Badges
                HStack {
                    if membership.isNewMember {
                        Label("New Member", systemImage: "sparkles")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    if membership.isVeteran {
                        Label("Veteran", systemImage: "star.fill")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Member since
                Text(membership.memberSince)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Member Profile")
    }
}

// Member list with role filtering
struct GuildMemberListView: View {
    let members: [GuildMembershipDTO]
    @State private var selectedRole: MemberRole? = nil
    
    var filteredMembers: [GuildMembershipDTO] {
        if let role = selectedRole {
            return members.filter { $0.roleInGuild == role }
        }
        return members
    }
    
    var body: some View {
        VStack {
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button("All") {
                        selectedRole = nil
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: selectedRole == nil))
                    
                    ForEach(MemberRole.allCases, id: \.self) { role in
                        Button(role.displayName) {
                            selectedRole = role
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: selectedRole == role))
                    }
                }
                .padding(.horizontal)
            }
            
            List(filteredMembers) { membership in
                NavigationLink {
                    GuildMemberProfileView(membership: membership)
                } label: {
                    MembershipRowView(membership: membership)
                }
            }
        }
        .navigationTitle("Members (\(filteredMembers.count))")
    }
}

struct MembershipRowView: View {
    let membership: GuildMembershipDTO
    
    var body: some View {
        HStack {
            MemberRowView(member: membership.globalMember)
            
            VStack(alignment: .trailing) {
                Text(membership.roleInGuild.displayName)
                    .font(.caption)
                    .fontWeight(membership.roleInGuild.fontWeight)
                    .foregroundColor(membership.roleInGuild.foregroundColor)
                
                Text("\(membership.reputation) rep")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
    }
}
```

---

## Guild DTOs

### GuildSummaryDTO

#### Example JSON Response
```json
{
  "id": "111e2222-e33b-44d5-a666-426614174333",
  "name": "KAOS Trading",
  "memberCount": 156,
  "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
  "reputation": 45000,
  "owner": {
    "id": "owner-membership-id",
    "globalMember": {
      "id": "owner-user-id",
      "email": "owner@example.com",
      "name": "Guild Owner",
      "username": "guildowner",
      "avatarURL": null,
      "isOnline": false,
      "globalReputation": 5000
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "admin",
    "dateJoined": "2024-01-15T10:30:00Z",
    "reputation": 5000,
    "daysInGuild": 282,
    "contributionScore": 95,
    "isOnline": false
  },
  "isOpen": true
}
```

#### Swift Usage Example
```swift
// Guild selector dropdown
struct GuildSelectorView: View {
    let guilds: [GuildSummaryDTO]
    @Binding var selectedGuild: GuildSummaryDTO?
    
    var body: some View {
        Menu {
            ForEach(guilds, id: \.id) { guild in
                Button {
                    selectedGuild = guild
                } label: {
                    HStack {
                        Text(guild.name)
                        Spacer()
                        Text("\(guild.memberCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } label: {
            HStack {
                if let selected = selectedGuild {
                    Text(selected.displayName)
                } else {
                    Text("Select Guild")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// Mutual guilds display
struct MutualGuildsView: View {
    let guilds: [GuildSummaryDTO]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Mutual Guilds")
                .font(.headline)
            
            ForEach(guilds, id: \.id) { guild in
                HStack {
                    AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text(guild.name)
                            .font(.subheadline)
                        Text(guild.formattedMemberCount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: guild.isOpen ? "lock.open" : "lock")
                        .foregroundColor(guild.isOpen ? .green : .gray)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
```

---

### GuildDTO (Full)

#### Example JSON Response
```json
{
  "id": "111e2222-e33b-44d5-a666-426614174333",
  "name": "KAOS Trading Guild",
  "description": "Premier guild for forex and cryptocurrency traders. We focus on technical analysis, risk management, and collaborative learning. All skill levels welcome!",
  "reputation": 45000,
  "accuracy": 78,
  "memberCount": 156,
  "owner": {
    "id": "owner-user-id",
    "email": "sarah.masters@email.com",
    "name": "Sarah Masters",
    "username": "tradingqueen",
    "avatarURL": "https://cdn.tradersguild.com/avatars/sarah.jpg",
    "isOnline": true,
    "globalReputation": 5820
  },
  "dateCreated": "2024-01-15T10:30:00Z",
  "imageURL": "https://cdn.tradersguild.com/guilds/kaos-banner.jpg",
  "isJoined": true,
  "currentMemberRole": "moderator",
  "isOpen": true
}
```

#### Swift Usage Example
```swift
// Complete guild detail view
struct GuildDetailView: View {
    let guild: GuildDTO
    @StateObject private var viewModel = GuildDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header banner
                AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .frame(height: 200)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading) {
                        Text(guild.name)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        HStack {
                            Label(guild.statusText, systemImage: guild.isOpen ? "lock.open" : "lock")
                            Label("\(guild.memberCount) members", systemImage: "person.2")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Action buttons
                    HStack {
                        if guild.isJoined {
                            if guild.canManage {
                                Button {
                                    viewModel.showManageGuild = true
                                } label: {
                                    Label("Manage", systemImage: "gear")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button {
                                viewModel.showChatrooms = true
                            } label: {
                                Label("Chat", systemImage: "message")
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button {
                                Task {
                                    await viewModel.joinGuild(guild.id)
                                }
                            } label: {
                                Label("Join Guild", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!guild.isOpen)
                        }
                        
                        Spacer()
                        
                        ShareLink(item: URL(string: "tradersguild://guild/\(guild.id)")!)
                    }
                    .padding(.horizontal)
                    
                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Reputation",
                            value: guild.reputationDisplay,
                            icon: "star.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Accuracy",
                            value: "\(guild.accuracy)%",
                            icon: "target",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Age",
                            value: "\(guild.ageInDays)d",
                            icon: "calendar",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(guild.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Owner info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Guild Owner")
                            .font(.headline)
                        
                        HStack {
                            MemberRowView(member: guild.owner)
                            
                            Spacer()
                            
                            Button {
                                viewModel.showOwnerProfile = true
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Created date
                    Text("Founded \(guild.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// ViewModel for guild actions
@MainActor
class GuildDetailViewModel: ObservableObject {
    @Published var showManageGuild = false
    @Published var showChatrooms = false
    @Published var showOwnerProfile = false
    
    func joinGuild(_ guildId: UUID) async {
        // API call to join guild
        let url = URL(string: "https://api.tradersguild.co/api/v1/guilds/\(guildId)/join")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Success - refresh guild data
            }
        } catch {
            print("Failed to join guild: \(error)")
        }
    }
}
```

---

### GuildAnnouncementDTO

#### Example JSON Response
```json
{
  "id": "aaa11111-b222-3333-c444-555566667777",
  "guildId": "111e2222-e33b-44d5-a666-426614174333",
  "author": {
    "id": "author-membership-id",
    "globalMember": {
      "id": "author-user-id",
      "email": "sarah.masters@email.com",
      "name": "Sarah Masters",
      "username": "tradingqueen",
      "avatarURL": "https://cdn.tradersguild.com/avatars/sarah.jpg",
      "isOnline": true,
      "globalReputation": 5820
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "admin",
    "dateJoined": "2024-01-15T10:30:00Z",
    "reputation": 5820,
    "daysInGuild": 282,
    "contributionScore": 95,
    "isOnline": true
  },
  "title": "New Trading Hours and Market Analysis Session",
  "content": "Hey everyone! 👋\n\nStarting next week, we're adjusting our live trading sessions to align with the London market open. Sessions will now be at 8:00 AM GMT.\n\nAlso, we're introducing weekly market analysis sessions every Friday at 5:00 PM GMT. Come prepared with your charts and questions!\n\nLooking forward to seeing you all there. Let's make some profitable trades together! 📈",
  "preview": "Starting next week, we're adjusting our live trading sessions to align with the London market open...",
  "postedAt": "2025-10-23T14:30:00Z",
  "timeAgoFormatted": "2 hours ago",
  "isImportant": true,
  "isRead": false,
  "readCount": 89
}
```

#### Swift Usage Example
```swift
// Announcement list view
struct AnnouncementListView: View {
    let announcements: [GuildAnnouncementDTO]
    
    var body: some View {
        List {
            // Important announcements first
            if announcements.contains(where: { $0.isImportant && !$0.isRead }) {
                Section("Important") {
                    ForEach(announcements.filter { $0.isImportant && !$0.isRead }) { announcement in
                        NavigationLink {
                            AnnouncementDetailView(announcement: announcement)
                        } label: {
                            AnnouncementRowView(announcement: announcement)
                        }
                    }
                }
            }
            
            Section("Recent") {
                ForEach(announcements.filter { !$0.isImportant || $0.isRead }) { announcement in
                    NavigationLink {
                        AnnouncementDetailView(announcement: announcement)
                    } label: {
                        AnnouncementRowView(announcement: announcement)
                    }
                }
            }
        }
        .navigationTitle("Announcements")
    }
}

struct AnnouncementRowView: View {
    let announcement: GuildAnnouncementDTO
    
    var body: some View {
        HStack(alignment: .top) {
            // Unread indicator
            if announcement.showUnreadIndicator {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title with importance indicator
                HStack {
                    if announcement.isImportant {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(announcement.importanceColor)
                    }
                    
                    Text(announcement.title)
                        .font(.headline)
                        .foregroundColor(announcement.isRead ? .secondary : .primary)
                }
                
                // Preview
                Text(announcement.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Meta info
                HStack {
                    // Author avatar
                    AsyncImage(url: URL(string: announcement.author.globalMember.avatarURL ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    
                    Text(announcement.author.globalMember.name)
                        .font(.caption)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(announcement.timeAgoFormatted)
                        .font(.caption)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label("\(announcement.readCount)", systemImage: "eye")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
}

// Announcement detail view
struct AnnouncementDetailView: View {
    let announcement: GuildAnnouncementDTO
    @StateObject private var viewModel = AnnouncementViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    if announcement.isImportant {
                        Label("Important", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(announcement.importanceColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(announcement.importanceColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Text(announcement.title)
                        .font(.title2)
                        .bold()
                    
                    // Author info
                    HStack {
                        AsyncImage(url: URL(string: announcement.author.globalMember.avatarURL ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(announcement.author.globalMember.name)
                                .font(.subheadline)
                                .bold()
                            Text(announcement.author.roleInGuild.displayName)
                                .font(.caption)
                                .foregroundColor(announcement.author.roleInGuild.foregroundColor)
                        }
                        
                        Spacer()
                        
                        Text(announcement.timeAgoFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Content
                Text(announcement.content)
                    .font(.body)
                
                Divider()
                
                // Read stats (for admins)
                if announcement.author.roleInGuild.canModerate {
                    HStack {
                        Label("\(announcement.readCount) members read", systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", announcement.readPercentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Mark as read when viewing
            await viewModel.markAsRead(announcement.id)
        }
    }
}

@MainActor
class AnnouncementViewModel: ObservableObject {
    func markAsRead(_ announcementId: UUID) async {
        let url = URL(string: "https://api.tradersguild.co/api/v1/announcements/\(announcementId)/read")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }
}
```

---

### GuildEventDTO

#### Example JSON Response
```json
{
  "id": "event-1111-2222-3333-444444444444",
  "guildId": "111e2222-e33b-44d5-a666-426614174333",
  "author": {
    "id": "author-membership-id",
    "globalMember": {
      "id": "moderator-user-id",
      "email": "mike.trader@email.com",
      "name": "Mike Trader",
      "username": "miketrader",
      "avatarURL": "https://cdn.tradersguild.com/avatars/mike.jpg",
      "isOnline": false,
      "globalReputation": 3200
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "moderator",
    "dateJoined": "2024-03-10T09:00:00Z",
    "reputation": 3200,
    "daysInGuild": 228,
    "contributionScore": 88,
    "isOnline": false
  },
  "title": "Live EUR/USD Trading Session",
  "content": "Join us for a live trading session focusing on EUR/USD. We'll be analyzing the current market conditions, discussing entry and exit strategies, and taking live trades based on our analysis.\n\n**What to bring:**\n- Your charts ready\n- Questions about current positions\n- Trading journal\n\n**Topics covered:**\n- Support/resistance analysis\n- Fibonacci retracements\n- Risk management strategies\n- Position sizing\n\nPerfect for intermediate to advanced traders. Beginners welcome but please review basic concepts first!",
  "preview": "Join us for a live trading session focusing on EUR/USD. We'll be analyzing the current market conditions...",
  "eventDate": "2025-10-26T14:00:00Z",
  "eventDateFormatted": "Saturday, Oct 26 at 2:00 PM GMT",
  "timeUntilEvent": "in 2 days",
  "postedAt": "2025-10-20T10:00:00Z",
  "postedTimeAgo": "4 days ago",
  "attendeeCount": 42,
  "isAttending": true,
  "attendees": [
    {
      "id": "attendee-1-membership-id",
      "globalMember": {
        "id": "attendee-1-user-id",
        "email": "user1@email.com",
        "name": "Alice Forex",
        "username": "aliceforex",
        "avatarURL": "https://cdn.tradersguild.com/avatars/alice.jpg",
        "isOnline": true,
        "globalReputation": 1500
      },
      "guild": {
        "id": "111e2222-e33b-44d5-a666-426614174333",
        "name": "KAOS Trading",
        "memberCount": 156,
        "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
        "reputation": 45000,
        "owner": null,
        "isOpen": true
      },
      "roleInGuild": "member",
      "dateJoined": "2024-07-15T12:00:00Z",
      "reputation": 450,
      "daysInGuild": 101,
      "contributionScore": 65,
      "isOnline": true
    },
    {
      "id": "attendee-2-membership-id",
      "globalMember": {
        "id": "attendee-2-user-id",
        "email": "user2@email.com",
        "name": "Bob Charts",
        "username": "bobcharts",
        "avatarURL": null,
        "isOnline": false,
        "globalReputation": 980
      },
      "guild": {
        "id": "111e2222-e33b-44d5-a666-426614174333",
        "name": "KAOS Trading",
        "memberCount": 156,
        "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
        "reputation": 45000,
        "owner": null,
        "isOpen": true
      },
      "roleInGuild": "member",
      "dateJoined": "2024-08-20T16:30:00Z",
      "reputation": 320,
      "daysInGuild": 65,
      "contributionScore": 52,
      "isOnline": false
    }
  ],
  "isImportant": true,
  "canEdit": false
}
```

#### Swift Usage Example
```swift
// Event list view
struct EventListView: View {
    let events: [GuildEventDTO]
    @State private var showPastEvents = false
    
    var upcomingEvents: [GuildEventDTO] {
        events.filter { !$0.isPastEvent }.sorted { $0.eventDate < $1.eventDate }
    }
    
    var pastEvents: [GuildEventDTO] {
        events.filter { $0.isPastEvent }.sorted { $0.eventDate > $1.eventDate }
    }
    
    var body: some View {
        List {
            Section("Upcoming Events") {
                if upcomingEvents.isEmpty {
                    Text("No upcoming events")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(upcomingEvents) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            EventRowView(event: event)
                        }
                    }
                }
            }
            
            Section {
                Toggle("Show Past Events", isOn: $showPastEvents)
            }
            
            if showPastEvents {
                Section("Past Events") {
                    ForEach(pastEvents) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            EventRowView(event: event)
                        }
                    }
                }
            }
        }
        .navigationTitle("Events")
    }
}

struct EventRowView: View {
    let event: GuildEventDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Circle()
                .fill(event.statusColor)
                .frame(width: 12, height: 12)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title with importance badge
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(event.isPastEvent ? .secondary : .primary)
                    
                    if event.isImportant && !event.isPastEvent {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Date/time
                Label(event.eventDateFormatted, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !event.isPastEvent {
                    Label(event.timeUntilEvent, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Attendance
                HStack(spacing: 4) {
                    // Avatar stack (first 3 attendees)
                    HStack(spacing: -8) {
                        ForEach(event.attendees.prefix(3)) { attendee in
                            AsyncImage(url: URL(string: attendee.globalMember.avatarURL ?? "")) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        }
                    }
                    
                    Text(event.attendanceDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }
}

// Event detail view
struct EventDetailView: View {
    let event: GuildEventDTO
    @StateObject private var viewModel = EventViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    // Status badges
                    HStack {
                        if event.isImportant {
                            Label("Important", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(6)
                        }
                        
                        if event.isPastEvent {
                            Label("Past Event", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        } else if event.isAttending {
                            Label("You're Going", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(event.title)
                        .font(.title)
                        .bold()
                    
                    // Date/time info
                    VStack(alignment: .leading, spacing: 8) {
                        Label(event.eventDateFormatted, systemImage: "calendar")
                            .font(.subheadline)
                        
                        if !event.isPastEvent {
                            Label(event.timeUntilEvent, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Organizer
                    HStack {
                        Text("Organized by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        AsyncImage(url: URL(string: event.author.globalMember.avatarURL ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        
                        Text(event.author.globalMember.name)
                            .font(.caption)
                            .bold()
                        
                        Text(event.author.roleInGuild.displayName)
                            .font(.caption2)
                            .foregroundColor(event.author.roleInGuild.foregroundColor)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Action buttons
                if !event.isPastEvent {
                    HStack {
                        Button {
                            Task {
                                await viewModel.toggleAttendance(event.id, currentStatus: event.isAttending)
                            }
                        } label: {
                            Label(
                                event.isAttending ? "Not Going" : "I'm Going",
                                systemImage: event.isAttending ? "xmark.circle" : "checkmark.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(event.isAttending ? .red : .green)
                        
                        ShareLink(item: URL(string: "tradersguild://event/\(event.id)")!) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Attendees section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Attendees (\(event.attendeeCount))")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(event.attendees) { attendee in
                                VStack {
                                    ZStack(alignment: .bottomTrailing) {
                                        AsyncImage(url: URL(string: attendee.globalMember.avatarURL ?? "")) { image in
                                            image.resizable()
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        
                                        if attendee.isOnline {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 14, height: 14)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                        }
                                    }
                                    
                                    Text(attendee.globalMember.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(width: 70)
                                }
                            }
                            
                            if event.attendeeCount > event.attendees.count {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                        
                                        Text("+\(event.attendeeCount - event.attendees.count)")
                                            .font(.caption)
                                            .bold()
                                    }
                                    
                                    Text("more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.headline)
                    
                    Text(event.content)
                        .font(.body)
                }
                
                // Edit button (if authorized)
                if event.canEdit {
                    Button {
                        viewModel.showEditSheet = true
                    } label: {
                        Label("Edit Event", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class EventViewModel: ObservableObject {
    @Published var showEditSheet = false
    
    func toggleAttendance(_ eventId: UUID, currentStatus: Bool) async {
        let endpoint = currentStatus ? "leave" : "join"
        let url = URL(string: "https://api.tradersguild.co/api/v1/events/\(eventId)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            _ = try await URLSession.shared.data(for: request)
            // Refresh event data
        } catch {
            print("Failed to update attendance: \(error)")
        }
    }
}
```

---

### GuildWatchlistDTO

#### Example JSON Response
```json
{
  "id": "watch-1111-2222-3333-444444444444",
  "guildId": "111e2222-e33b-44d5-a666-426614174333",
  "name": "Tech Stocks Q4 2025",
  "author": {
    "id": "author-membership-id",
    "globalMember": {
      "id": "author-user-id",
      "email": "sarah.masters@email.com",
      "name": "Sarah Masters",
      "username": "tradingqueen",
      "avatarURL": "https://cdn.tradersguild.com/avatars/sarah.jpg",
      "isOnline": true,
      "globalReputation": 5820
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "admin",
    "dateJoined": "2024-01-15T10:30:00Z",
    "reputation": 5820,
    "daysInGuild": 282,
    "contributionScore": 95,
    "isOnline": true
  },
  "dateCreated": "2025-10-01T09:00:00Z",
  "symbols": [
    {
      "id": "symbol-aapl-id",
      "ticker": "AAPL",
      "name": "Apple Inc.",
      "price": 182.52,
      "priceFormatted": "$182.52",
      "change": 4.27,
      "changeFormatted": "+2.34%",
      "changeColor": "green",
      "volume": 52345678,
      "volumeFormatted": "52.3M",
      "marketCap": "2.85T",
      "symbolType": "Stocks",
      "symbolStatus": "Closed"
    },
    {
      "id": "symbol-msft-id",
      "ticker": "MSFT",
      "name": "Microsoft Corporation",
      "price": 378.91,
      "priceFormatted": "$378.91",
      "change": -2.15,
      "changeFormatted": "-0.56%",
      "changeColor": "red",
      "volume": 28934521,
      "volumeFormatted": "28.9M",
      "marketCap": "2.81T",
      "symbolType": "Stocks",
      "symbolStatus": "Closed"
    },
    {
      "id": "symbol-googl-id",
      "ticker": "GOOGL",
      "name": "Alphabet Inc.",
      "price": 141.73,
      "priceFormatted": "$141.73",
      "change": 1.89,
      "changeFormatted": "+1.35%",
      "changeColor": "green",
      "volume": 19876543,
      "volumeFormatted": "19.9M",
      "marketCap": "1.76T",
      "symbolType": "Stocks",
      "symbolStatus": "Closed"
    }
  ],
  "symbolCount": 15,
  "lastUpdated": "Updated 5 min ago"
}
```

#### Swift Usage Example
```swift
// Watchlist list view
struct WatchlistListView: View {
    let watchlists: [GuildWatchlistDTO]
    
    var body: some View {
        List {
            ForEach(watchlists) { watchlist in
                NavigationLink {
                    WatchlistDetailView(watchlist: watchlist)
                } label: {
                    WatchlistRowView(watchlist: watchlist)
                }
            }
        }
        .navigationTitle("Watchlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Create new watchlist
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct WatchlistRowView: View {
    let watchlist: GuildWatchlistDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(watchlist.name)
                    .font(.headline)
                
                Spacer()
                
                if watchlist.isEmpty {
                    Label("Empty", systemImage: "tray")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("\(watchlist.symbolCount)", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Symbol preview
            if !watchlist.isEmpty {
                Text(watchlist.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Meta info
            HStack {
                AsyncImage(url: URL(string: watchlist.author.globalMember.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())
                
                Text(watchlist.author.globalMember.name)
                    .font(.caption)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(watchlist.lastUpdated)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Watchlist detail view
struct WatchlistDetailView: View {
    let watchlist: GuildWatchlistDTO
    @StateObject private var viewModel = WatchlistViewModel()
    
    var body: some View {
        List {
            // Header section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(watchlist.name)
                                .font(.title2)
                                .bold()
                            
                            Text("Created by \(watchlist.author.globalMember.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                viewModel.showShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive) {
                                viewModel.showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    
                    HStack {
                        Label("\(watchlist.symbolCount) symbols", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(watchlist.lastUpdated)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Symbols section
            Section("Symbols") {
                ForEach(watchlist.symbols) { symbol in
                    NavigationLink {
                        SymbolDetailView(symbol: symbol)
                    } label: {
                        SymbolRowView(symbol: symbol)
                    }
                }
                
                if watchlist.symbolCount > watchlist.symbols.count {
                    Button {
                        Task {
                            await viewModel.loadMoreSymbols(watchlist.id)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load \(watchlist.symbolCount - watchlist.symbols.count) more symbols")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var showShareSheet = false
    @Published var showDeleteAlert = false
    
    func loadMoreSymbols(_ watchlistId: UUID) async {
        // API call to load more symbols
    }
}
```

---

### GuildFriendDTO

#### Example JSON Response
```json
{
  "id": "friend-1111-2222-3333-444444444444",
  "guild": "111e2222-e33b-44d5-a666-426614174333",
  "friend": {
    "id": "friend-membership-id",
    "globalMember": {
      "id": "friend-user-id",
      "email": "jessica.day@email.com",
      "name": "Jessica Day",
      "username": "jessday",
      "avatarURL": "https://cdn.tradersguild.com/avatars/jessica.jpg",
      "isOnline": true,
      "globalReputation": 2890
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "member",
    "dateJoined": "2024-05-12T11:20:00Z",
    "reputation": 720,
    "daysInGuild": 165,
    "contributionScore": 71,
    "isOnline": true
  },
  "friendshipDate": "2024-06-01T14:30:00Z",
  "friendshipDuration": "Friends for 5 months",
  "mutualGuilds": [
    {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    {
      "id": "guild-2222-3333-4444-555555555555",
      "name": "Crypto Warriors",
      "memberCount": 203,
      "imageURL": "https://cdn.tradersguild.com/guilds/crypto.jpg",
      "reputation": 38000,
      "owner": null,
      "isOpen": true
    }
  ],
  "mutualGuildCount": 2,
  "lastSeen": "Active 15 min ago"
}
```

#### Swift Usage Example
```swift
// Friends list view
struct FriendsListView: View {
    let friends: [GuildFriendDTO]
    @State private var searchText = ""
    
    var filteredFriends: [GuildFriendDTO] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter {
            $0.friend.globalMember.name.localizedCaseInsensitiveContains(searchText) ||
            $0.friend.globalMember.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var onlineFriends: [GuildFriendDTO] {
        filteredFriends.filter { $0.friend.isOnline }
    }
    
    var offlineFriends: [GuildFriendDTO] {
        filteredFriends.filter { !$0.friend.isOnline }
    }
    
    var body: some View {
        List {
            if !onlineFriends.isEmpty {
                Section("Online (\(onlineFriends.count))") {
                    ForEach(onlineFriends) { friendship in
                        NavigationLink {
                            FriendProfileView(friendship: friendship)
                        } label: {
                            FriendRowView(friendship: friendship)
                        }
                    }
                }
            }
            
            if !offlineFriends.isEmpty {
                Section("Offline (\(offlineFriends.count))") {
                    ForEach(offlineFriends) { friendship in
                        NavigationLink {
                            FriendProfileView(friendship: friendship)
                        } label: {
                            FriendRowView(friendship: friendship)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search friends")
        .navigationTitle("Friends (\(friends.count))")
    }
}

struct FriendRowView: View {
    let friendship: GuildFriendDTO
    
    var body: some View {
        HStack {
            // Avatar with online status
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: friendship.friend.globalMember.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                if friendship.friend.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friend.globalMember.name)
                    .font(.headline)
                
                Text("@\(friendship.friend.globalMember.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if friendship.hasCommonGuilds {
                    Label(friendship.commonGuildsDisplay, systemImage: "person.2")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(friendship.friend.globalMember.globalReputation)")
                        .font(.caption)
                }
                .foregroundColor(.orange)
                
                if let lastSeen = friendship.lastSeen {
                    Text(lastSeen)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Friend profile view
struct FriendProfileView: View {
    let friendship: GuildFriendDTO
    @StateObject private var viewModel = FriendViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: friendship.friend.globalMember.avatarURL ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        
                        if friendship.friend.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        }
                    }
                    
                    Text(friendship.friend.globalMember.name)
                        .font(.title)
                        .bold()
                    
                    Text("@\(friendship.friend.globalMember.username)")
                        .foregroundColor(.secondary)
                    
                    if let lastSeen = friendship.lastSeen {
                        Text(lastSeen)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action buttons
                HStack {
                    Button {
                        viewModel.showMessageComposer = true
                    } label: {
                        Label("Message", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        viewModel.showRemoveFriendAlert = true
                    } label: {
                        Label("Remove Friend", systemImage: "person.badge.minus")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(friendship.friend.globalMember.globalReputation)")
                            .font(.title2)
                            .bold()
                        Text("Reputation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(friendship.friend.reputation)")
                            .font(.title2)
                            .bold()
                        Text("Guild Rep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(friendship.mutualGuildCount)")
                            .font(.title2)
                            .bold()
                        Text("Mutual Guilds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Friendship info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Friendship")
                        .font(.headline)
                    
                    Text(friendship.friendshipDuration)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Mutual guilds
                if friendship.hasCommonGuilds {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mutual Guilds")
                            .font(.headline)
                        
                        ForEach(friendship.mutualGuilds, id: \.id) { guild in
                            NavigationLink {
                                // Navigate to guild detail
                            } label: {
                                HStack {
                                    AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                                    
                                    VStack(alignment: .leading) {
                                        Text(guild.name)
                                            .font(.subheadline)
                                        Text(guild.formattedMemberCount)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Friend Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class FriendViewModel: ObservableObject {
    @Published var showMessageComposer = false
    @Published var showRemoveFriendAlert = false
}
```

---

## Messaging DTOs

### GuildChatroomDTO

#### Example JSON Response
```json
{
  "id": "chatroom-1111-2222-3333-444444444444",
  "guildId": "111e2222-e33b-44d5-a666-426614174333",
  "name": "general",
  "description": "Main chat for guild discussions",
  "lastMessage": {
    "id": "msg-9999-8888-7777-666666666666",
    "chatroom": "chatroom-1111-2222-3333-444444444444",
    "author": {
      "id": "author-membership-id",
      "globalMember": {
        "id": "author-user-id",
        "email": "mike.trader@email.com",
        "name": "Mike Trader",
        "username": "miketrader",
        "avatarURL": "https://cdn.tradersguild.com/avatars/mike.jpg",
        "isOnline": true,
        "globalReputation": 3200
      },
      "guild": {
        "id": "111e2222-e33b-44d5-a666-426614174333",
        "name": "KAOS Trading",
        "memberCount": 156,
        "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
        "reputation": 45000,
        "owner": null,
        "isOpen": true
      },
      "roleInGuild": "moderator",
      "dateJoined": "2024-03-10T09:00:00Z",
      "reputation": 3200,
      "daysInGuild": 228,
      "contributionScore": 88,
      "isOnline": true
    },
    "content": "Just saw a great setup on EUR/USD! 📈",
    "timestamp": "2025-10-24T16:45:00Z",
    "timestampFormatted": "4:45 PM",
    "isEdited": false,
    "isCurrentUserMessage": false,
    "canEdit": false,
    "canDelete": false
  },
  "isActive": true,
  "lastActivity": "2025-10-24T16:45:00Z",
  "lastActivityFormatted": "Active 2 min ago",
  "unreadCount": 5,
  "memberCount": 156,
  "isPinned": false,
  "isMuted": false,
  "canSendMessages": true
}
```

#### Swift Usage Example
```swift
// Chatroom list view
struct ChatroomListView: View {
    let chatrooms: [GuildChatroomDTO]
    
    var pinnedChatrooms: [GuildChatroomDTO] {
        chatrooms.filter { $0.isPinned }
    }
    
    var regularChatrooms: [GuildChatroomDTO] {
        chatrooms.filter { !$0.isPinned }.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    var body: some View {
        List {
            if !pinnedChatrooms.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedChatrooms) { chatroom in
                        NavigationLink {
                            ChatroomView(chatroom: chatroom)
                        } label: {
                            ChatroomRowView(chatroom: chatroom)
                        }
                    }
                }
            }
            
            Section("Channels") {
                ForEach(regularChatrooms) { chatroom in
                    NavigationLink {
                        ChatroomView(chatroom: chatroom)
                    } label: {
                        ChatroomRowView(chatroom: chatroom)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            // Toggle pin
                        } label: {
                            Label("Pin", systemImage: "pin")
                        }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            // Toggle mute
                        } label: {
                            Label(chatroom.isMuted ? "Unmute" : "Mute", systemImage: chatroom.isMuted ? "bell" : "bell.slash")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Channels")
    }
}

struct ChatroomRowView: View {
    let chatroom: GuildChatroomDTO
    
    var body: some View {
        HStack {
            // Channel indicator
            Image(systemName: "number")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chatroom.name)
                        .font(.headline)
                        .foregroundColor(chatroom.isMuted ? .secondary : .primary)
                    
                    if chatroom.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    if chatroom.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = chatroom.lastMessage {
                    Text("\(lastMessage.author.globalMember.name): \(lastMessage.content)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Text(chatroom.lastActivityFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Unread badge
            if chatroom.hasUnread && !chatroom.isMuted {
                Text("\(chatroom.unreadCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(chatroom.activityColor)
                    .clipShape(Capsule())
            } else if chatroom.hasUnread {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// Chatroom conversation view
struct ChatroomView: View {
    let chatroom: GuildChatroomDTO
    @StateObject private var viewModel = ChatroomViewModel()
    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatroomMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            if chatroom.canSendMessages {
                HStack(spacing: 12) {
                    TextField("Message #\(chatroom.name)", text: $messageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                    
                    Button {
                        Task {
                            await viewModel.sendMessage(messageText, in: chatroom.id)
                            messageText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("You don't have permission to send messages")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding()
                .background(Color.secondary.opacity(0.1))
            }
        }
        .navigationTitle("#\(chatroom.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        // View channel info
                    } label: {
                        Label("Channel Info", systemImage: "info.circle")
                    }
                    
                    Button {
                        // Search messages
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    
                    Divider()
                    
                    Button {
                        viewModel.togglePin(chatroom.id, currentStatus: chatroom.isPinned)
                    } label: {
                        Label(chatroom.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                    }
                    
                    Button {
                        viewModel.toggleMute(chatroom.id, currentStatus: chatroom.isMuted)
                    } label: {
                        Label(chatroom.isMuted ? "Unmute" : "Mute", systemImage: chatroom.isMuted ? "bell" : "bell.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.loadMessages(for: chatroom.id)
        }
    }
}

@MainActor
class ChatroomViewModel: ObservableObject {
    @Published var messages: [ChatroomMessageDTO] = []
    
    func loadMessages(for chatroomId: UUID) async {
        let url = URL(string: "https://api.tradersguild.co/api/v1/chatrooms/\(chatroomId)/messages")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            messages = try decoder.decode([ChatroomMessageDTO].self, from: data)
        } catch {
            print("Failed to load messages: \(error)")
        }
    }
    
    func sendMessage(_ content: String, in chatroomId: UUID) async {
        let url = URL(string: "https://api.tradersguild.co/api/v1/chatrooms/\(chatroomId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["content": content]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            _ = try await URLSession.shared.data(for: request)
            // Reload messages or append via WebSocket
            await loadMessages(for: chatroomId)
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    func togglePin(_ chatroomId: UUID, currentStatus: Bool) {
        // API call to toggle pin
    }
    
    func toggleMute(_ chatroomId: UUID, currentStatus: Bool) {
        // API call to toggle mute
    }
}
```

---

### ChatroomMessageDTO

#### Example JSON Response
```json
{
  "id": "msg-1111-2222-3333-444444444444",
  "chatroom": "chatroom-1111-2222-3333-444444444444",
  "author": {
    "id": "author-membership-id",
    "globalMember": {
      "id": "author-user-id",
      "email": "alex.thompson@email.com",
      "name": "Alex Thompson",
      "username": "alexthompson",
      "avatarURL": "https://cdn.tradersguild.com/avatars/alexthompson.jpg",
      "isOnline": true,
      "globalReputation": 1825
    },
    "guild": {
      "id": "111e2222-e33b-44d5-a666-426614174333",
      "name": "KAOS Trading",
      "memberCount": 156,
      "imageURL": "https://cdn.tradersguild.com/guilds/kaos.jpg",
      "reputation": 45000,
      "owner": null,
      "isOpen": true
    },
    "roleInGuild": "moderator",
    "dateJoined": "2024-06-20T14:45:00Z",
    "reputation": 850,
    "daysInGuild": 127,
    "contributionScore": 78,
    "isOnline": true
  },
  "content": "Anyone else watching the Fed announcement today? Expecting a 0.25% hike based on recent inflation data.",
  "timestamp": "2025-10-24T14:32:15Z",
  "timestampFormatted": "2:32 PM",
  "isEdited": false,
  "isCurrentUserMessage": false,
  "canEdit": false,
  "canDelete": false
}
```

#### Swift Usage Example
```swift
// Message bubble component
struct ChatroomMessageBubble: View {
    let message: ChatroomMessageDTO
    @State private var showActions = false
    
    var body: some View {
        HStack(alignment: .top) {
            if message.alignment == .trailing {
                Spacer()
            }
            
            if !message.isCurrentUserMessage {
                // Avatar for other users
                AsyncImage(url: URL(string: message.author.globalMember.avatarURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }
            
            VStack(alignment: message.alignment == .trailing ? .trailing : .leading, spacing: 4) {
                // Author name and role (for other users)
                if !message.isCurrentUserMessage {
                    HStack(spacing: 4) {
                        Text(message.author.globalMember.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(message.author.roleInGuild.displayName)
                            .font(.caption2)
                            .foregroundColor(message.author.roleInGuild.foregroundColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(message.author.roleInGuild.foregroundColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                // Message content
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isCurrentUserMessage ?
                        Color.blue :
                        Color.secondary.opacity(0.2)
                    )
                    .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    .cornerRadius(16)
                    .contextMenu {
                        if message.canEdit {
                            Button {
                                // Edit message
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        if message.canDelete {
                            Button(role: .destructive) {
                                // Delete message
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                
                // Timestamp and edit indicator
                HStack(spacing: 4) {
                    Text(message.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            
            if message.alignment == .leading {
                Spacer()
            }
        }
    }
}

// Example usage in a list
struct MessageListExample: View {
    let messages: [ChatroomMessageDTO]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    ChatroomMessageBubble(message: message)
                }
            }
            .padding()
        }
    }
}
```

---

## Symbol/Trading DTOs

### SymbolDTO

#### Example JSON Response (Multiple Symbols)
```json
[
  {
    "id": "symbol-aapl-uuid",
    "ticker": "AAPL",
    "name": "Apple Inc.",
    "price": 182.52,
    "priceFormatted": "$182.52",
    "change": 4.27,
    "changeFormatted": "+2.34%",
    "changeColor": "green",
    "volume": 52345678,
    "volumeFormatted": "52.3M",
    "marketCap": "2.85T",
    "symbolType": "Stocks",
    "symbolStatus": "Closed"
  },
  {
    "id": "symbol-eurusd-uuid",
    "ticker": "EUR/USD",
    "name": "Euro / US Dollar",
    "price": 1.0856,
    "priceFormatted": "1.0856",
    "change": -0.0023,
    "changeFormatted": "-0.21%",
    "changeColor": "red",
    "volume": 0,
    "volumeFormatted": "N/A",
    "marketCap": null,
    "symbolType": "Forex",
    "symbolStatus": "Open"
  },
  {
    "id": "symbol-btc-uuid",
    "ticker": "BTC",
    "name": "Bitcoin",
    "price": 67234.50,
    "priceFormatted": "$67,234.50",
    "change": 1832.75,
    "changeFormatted": "+2.80%",
    "changeColor": "green",
    "volume": 28934521000,
    "volumeFormatted": "28.9B",
    "marketCap": "1.32T",
    "symbolType": "Cryptocurrency",
    "symbolStatus": "Open"
  },
  {
    "id": "symbol-gold-uuid",
    "ticker": "XAUUSD",
    "name": "Gold",
    "price": 2654.30,
    "priceFormatted": "$2,654.30",
    "change": -12.45,
    "changeFormatted": "-0.47%",
    "changeColor": "red",
    "volume": 0,
    "volumeFormatted": "N/A",
    "marketCap": null,
    "symbolType": "Commodities",
    "symbolStatus": "Open"
  }
]
```

#### Swift Usage Example
```swift
// Symbol row for lists
struct SymbolRowView: View {
    let symbol: SymbolDTO
    
    var body: some View {
        HStack {
            // Symbol info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(symbol.ticker)
                        .font(.headline)
                    
                    // Status indicator
                    Circle()
                        .fill(symbol.symbolStatus == .open ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                }
                
                Text(symbol.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Type badge
                Text(symbol.symbolType.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Price and change
            VStack(alignment: .trailing, spacing: 4) {
                Text(symbol.priceFormatted)
                    .font(.headline)
                
                HStack(spacing: 2) {
                    Text(symbol.changeArrow)
                        .font(.caption)
                    Text(symbol.changeFormatted)
                        .font(.caption)
                }
                .foregroundColor(symbol.changeColorSwiftUI)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(symbol.changeColorSwiftUI.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// Symbol detail view
struct SymbolDetailView: View {
    let symbol: SymbolDTO
    @StateObject private var viewModel = SymbolViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Text(symbol.ticker)
                            .font(.title)
                            .bold()
                        
                        Spacer()
                        
                        // Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(symbol.symbolStatus == .open ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(symbol.symbolStatus.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Text(symbol.name)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(symbol.symbolType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Price card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(symbol.priceFormatted)
                            .font(.system(size: 48, weight: .bold))
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            HStack(spacing: 4) {
                                Image(systemName: symbol.isUp ? "arrow.up.right" : "arrow.down.right")
                                Text(symbol.changeFormatted)
                                    .fontWeight(.semibold)
                            }
                            .font(.title3)
                            .foregroundColor(symbol.changeColorSwiftUI)
                        }
                    }
                    
                    // Additional stats
                    VStack(spacing: 12) {
                        HStack {
                            Text("Volume")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(symbol.volumeFormatted)
                                .fontWeight(.medium)
                        }
                        
                        if let marketCap = symbol.marketCap {
                            HStack {
                                Text("Market Cap")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(marketCap)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Chart placeholder
                VStack(alignment: .leading) {
                    Text("Price Chart")
                        .font(.headline)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Text("Chart would go here")
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(12)
                }
                
                // Action buttons
                HStack {
                    Button {
                        viewModel.addToWatchlist(symbol.id)
                    } label: {
                        Label("Add to Watchlist", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    ShareLink(item: URL(string: "tradersguild://symbol/\(symbol.ticker)")!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(symbol.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
class SymbolViewModel: ObservableObject {
    func addToWatchlist(_ symbolId: UUID) {
        // API call to add symbol to watchlist
    }
}

// Symbol type filter view
struct SymbolTypeFilterView: View {
    @Binding var selectedType: SymbolDTOType?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button("All") {
                    selectedType = nil
                }
                .buttonStyle(TypeFilterButtonStyle(isSelected: selectedType == nil))
                
                ForEach([SymbolDTOType.forex, .stocks, .cryptocurrency, .commodities], id: \.self) { type in
                    Button(type.rawValue) {
                        selectedType = type
                    }
                    .buttonStyle(TypeFilterButtonStyle(isSelected: selectedType == type))
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TypeFilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
    }
}

// Market overview
struct MarketOverviewView: View {
    let symbols: [SymbolDTO]
    @State private var selectedType: SymbolDTOType? = nil
    
    var filteredSymbols: [SymbolDTO] {
        if let type = selectedType {
            return symbols.filter { $0.symbolType == type }
        }
        return symbols
    }
    
    var gainers: [SymbolDTO] {
        filteredSymbols.filter { $0.isUp }.sorted { $0.change > $1.change }.prefix(5).map { $0 }
    }
    
    var losers: [SymbolDTO] {
        filteredSymbols.filter { !$0.isUp }.sorted { $0.change < $1.change }.prefix(5).map { $0 }
    }
    
    var body: some View {
        List {
            Section {
                SymbolTypeFilterView(selectedType: $selectedType)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            if !gainers.isEmpty {
                Section("Top Gainers") {
                    ForEach(gainers) { symbol in
                        NavigationLink {
                            SymbolDetailView(symbol: symbol)
                        } label: {
                            SymbolRowView(symbol: symbol)
                        }
                    }
                }
            }
            
            if !losers.isEmpty {
                Section("Top Losers") {
                    ForEach(losers) { symbol in
                        NavigationLink {
                            SymbolDetailView(symbol: symbol)
                        } label: {
                            SymbolRowView(symbol: symbol)
                        }
                    }
                }
            }
            
            Section("All Symbols") {
                ForEach(filteredSymbols) { symbol in
                    NavigationLink {
                        SymbolDetailView(symbol: symbol)
                    } label: {
                        SymbolRowView(symbol: symbol)
                    }
                }
            }
        }
        .navigationTitle("Market")
    }
}
```

---

## API Integration Examples

### Complete API Service Layer

```swift
import Foundation

// MARK: - API Service
class TradersGuildAPI {
    static let shared = TradersGuildAPI()
    private let baseURL = "https://api.tradersguild.co/api/v1"
    private let decoder: JSONDecoder
    
    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Authentication
    
    func login(email: String, password: String) async throws -> (CurrentUserDTO, String) {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
        return (loginResponse.user, loginResponse.token)
    }
    
    func register(email: String, password: String, name: String, username: String) async throws -> (CurrentUserDTO, String) {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name,
            "username": username
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(LoginResponse.self, from: data)
        return (response.user, response.token)
    }
    
    // MARK: - User
    
    func getCurrentUser(token: String) async throws -> CurrentUserDTO {
        let url = URL(string: "\(baseURL)/users/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(CurrentUserDTO.self, from: data)
    }
    
    func updateProfile(token: String, name: String?, avatarURL: String?) async throws -> CurrentUserDTO {
        let url = URL(string: "\(baseURL)/users/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let avatarURL = avatarURL { body["avatarURL"] = avatarURL }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(CurrentUserDTO.self, from: data)
    }
    
    // MARK: - Guilds
    
    func getGuilds(token: String, page: Int = 1, limit: Int = 20) async throws -> [GuildDTO] {
        let url = URL(string: "\(baseURL)/guilds?page=\(page)&limit=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildDTO].self, from: data)
    }
    
    func getGuild(id: UUID, token: String) async throws -> GuildDTO {
        let url = URL(string: "\(baseURL)/guilds/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(GuildDTO.self, from: data)
    }
    
    func joinGuild(id: UUID, token: String) async throws {
        let url = URL(string: "\(baseURL)/guilds/\(id)/join")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }
    
    func leaveGuild(id: UUID, token: String) async throws {
        let url = URL(string: "\(baseURL)/guilds/\(id)/leave")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }
    
    func getGuildMembers(guildId: UUID, token: String, page: Int = 1) async throws -> [GuildMembershipDTO] {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/members?page=\(page)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildMembershipDTO].self, from: data)
    }
    
    // MARK: - Announcements
    
    func getAnnouncements(guildId: UUID, token: String) async throws -> [GuildAnnouncementDTO] {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/announcements")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildAnnouncementDTO].self, from: data)
    }
    
    func createAnnouncement(guildId: UUID, title: String, content: String, isImportant: Bool, token: String) async throws -> GuildAnnouncementDTO {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/announcements")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "title": title,
            "content": content,
            "isImportant": isImportant
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(GuildAnnouncementDTO.self, from: data)
    }
    
    func markAnnouncementAsRead(announcementId: UUID, token: String) async throws {
        let url = URL(string: "\(baseURL)/announcements/\(announcementId)/read")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Events
    
    func getEvents(guildId: UUID, token: String, includeParticipants: Bool = false) async throws -> [GuildEventDTO] {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/events?include_past=false")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildEventDTO].self, from: data)
    }
    
    func rsvpEvent(eventId: UUID, attending: Bool, token: String) async throws {
        let endpoint = attending ? "join" : "leave"
        let url = URL(string: "\(baseURL)/events/\(eventId)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Chatrooms
    
    func getChatrooms(guildId: UUID, token: String) async throws -> [GuildChatroomDTO] {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/chatrooms")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildChatroomDTO].self, from: data)
    }
    
    func getMessages(chatroomId: UUID, token: String, before: Date? = nil, limit: Int = 50) async throws -> [ChatroomMessageDTO] {
        var urlString = "\(baseURL)/chatrooms/\(chatroomId)/messages?limit=\(limit)"
        if let before = before {
            let formatter = ISO8601DateFormatter()
            urlString += "&before=\(formatter.string(from: before))"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([ChatroomMessageDTO].self, from: data)
    }
    
    func sendMessage(chatroomId: UUID, content: String, token: String) async throws -> ChatroomMessageDTO {
        let url = URL(string: "\(baseURL)/chatrooms/\(chatroomId)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(ChatroomMessageDTO.self, from: data)
    }
    
    // MARK: - Direct Messages
    
    func getDirectMessages(token: String) async throws -> [DMDTO] {
        let url = URL(string: "\(baseURL)/direct-messages")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([DMDTO].self, from: data)
    }
    
    func getDMMessages(dmId: UUID, token: String, before: Date? = nil) async throws -> [DMMessageDTO] {
        var urlString = "\(baseURL)/direct-messages/\(dmId)/messages"
        if let before = before {
            let formatter = ISO8601DateFormatter()
            urlString += "?before=\(formatter.string(from: before))"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([DMMessageDTO].self, from: data)
    }
    
    func sendDM(recipientId: UUID, content: String, token: String) async throws -> DMMessageDTO {
        let url = URL(string: "\(baseURL)/direct-messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "recipientId": recipientId.uuidString,
            "content": content
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(DMMessageDTO.self, from: data)
    }
    
    // MARK: - Symbols
    
    func getSymbols(token: String, type: SymbolDTOType? = nil) async throws -> [SymbolDTO] {
        var urlString = "\(baseURL)/symbols"
        if let type = type {
            urlString += "?type=\(type.rawValue)"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([SymbolDTO].self, from: data)
    }
    
    func searchSymbols(query: String, token: String) async throws -> [SymbolDTO] {
        let url = URL(string: "\(baseURL)/symbols/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([SymbolDTO].self, from: data)
    }
    
    // MARK: - Watchlists
    
    func getWatchlists(guildId: UUID, token: String) async throws -> [GuildWatchlistDTO] {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/watchlists")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildWatchlistDTO].self, from: data)
    }
    
    func createWatchlist(guildId: UUID, name: String, symbolIds: [UUID], token: String) async throws -> GuildWatchlistDTO {
        let url = URL(string: "\(baseURL)/guilds/\(guildId)/watchlists")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "symbolIds": symbolIds.map { $0.uuidString }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(GuildWatchlistDTO.self, from: data)
    }
    
    // MARK: - Friends
    
    func getFriends(token: String) async throws -> [GuildFriendDTO] {
        let url = URL(string: "\(baseURL)/friends")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([GuildFriendDTO].self, from: data)
    }
    
    func addFriend(userId: UUID, token: String) async throws {
        let url = URL(string: "\(baseURL)/friends/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    func removeFriend(userId: UUID, token: String) async throws {
        let url = URL(string: "\(baseURL)/friends/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Supporting Types

struct LoginResponse: Codable {
    let user: CurrentUserDTO
    let token: String
}

enum APIError: Error {
    case invalidResponse
    case httpError(Int)
    case requestFailed
    case decodingError
    case networkError
}
```

---

## Error Handling & Edge Cases

### Comprehensive Error Handling Example

```swift
// MARK: - Error Types
enum TradersGuildError: LocalizedError {
    case networkError
    case unauthorized
    case notFound
    case serverError
    case invalidData
    case rateLimited
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .notFound:
            return "The requested resource was not found."
        case .serverError:
            return "Server error. Please try again later."
        case .invalidData:
            return "Invalid data received from server."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Error Handler View Modifier
struct ErrorAlert: ViewModifier {
    @Binding var error: TradersGuildError?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<TradersGuildError?>) -> some View {
        modifier(ErrorAlert(error: error))
    }
}

// MARK: - Loading State Handler
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(TradersGuildError)
    
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var error: TradersGuildError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Example ViewModel with Error Handling
@MainActor
class GuildListViewModel: ObservableObject {
    @Published var loadingState: LoadingState<[GuildDTO]> = .idle
    @Published var error: TradersGuildError?
    
    private let api = TradersGuildAPI.shared
    private var token: String?
    
    init(token: String) {
        self.token = token
    }
    
    func loadGuilds() async {
        loadingState = .loading
        
        do {
            guard let token = token else {
                throw TradersGuildError.unauthorized
            }
            
            let guilds = try await api.getGuilds(token: token)
            loadingState = .loaded(guilds)
        } catch {
            let tradersGuildError = mapError(error)
            loadingState = .error(tradersGuildError)
            self.error = tradersGuildError
        }
    }
    
    private func mapError(_ error: Error) -> TradersGuildError {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse:
                return .invalidData
            case .httpError(let code):
                switch code {
                case 401:
                    return .unauthorized
                case 404:
                    return .notFound
                case 429:
                    return .rateLimited
                case 500...599:
                    return .serverError
                default:
                    return .custom("HTTP Error: \(code)")
                }
            case .requestFailed:
                return .networkError
            case .decodingError:
                return .invalidData
            case .networkError:
                return .networkError
            }
        }
        return .custom(error.localizedDescription)
    }
}

// MARK: - Example View with Error Handling
struct GuildListViewWithErrorHandling: View {
    @StateObject private var viewModel: GuildListViewModel
    
    init(token: String) {
        _viewModel = StateObject(wrappedValue: GuildListViewModel(token: token))
    }
    
    var body: some View {
        Group {
            switch viewModel.loadingState {
            case .idle:
                Color.clear
                    .onAppear {
                        Task {
                            await viewModel.loadGuilds()
                        }
                    }
                
            case .loading:
                ProgressView("Loading guilds...")
                
            case .loaded(let guilds):
                if guilds.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Guilds Yet",
                        message: "Join or create a guild to get started!"
                    )
                } else {
                    List(guilds) { guild in
                        NavigationLink {
                            GuildDetailView(guild: guild)
                        } label: {
                            GuildRowView(guild: guild)
                        }
                    }
                }
                
            case .error(let error):
                ErrorStateView(error: error) {
                    Task {
                        await viewModel.loadGuilds()
                    }
                }
            }
        }
        .navigationTitle("Guilds")
        .errorAlert($viewModel.error)
    }
}

// MARK: - Reusable Error State View
struct ErrorStateView: View {
    let error: TradersGuildError
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .bold()
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Reusable Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .bold()
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
```

---

## Complete Example: Guild Discovery Flow

Here's a complete end-to-end example showing guild discovery, joining, and viewing:

```swift
// MARK: - Guild Discovery View
struct GuildDiscoveryView: View {
    @StateObject private var viewModel: GuildDiscoveryViewModel
    @State private var searchText = ""
    
    init(token: String) {
        _viewModel = StateObject(wrappedValue: GuildDiscoveryViewModel(token: token))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadingState {
                case .loading:
                    ProgressView()
                    
                case .loaded(let guilds):
                    guildList(guilds: guilds)
                    
                case .error(let error):
                    ErrorStateView(error: error) {
                        Task {
                            await viewModel.loadGuilds()
                        }
                    }
                    
                case .idle:
                    Color.clear
                }
            }
            .navigationTitle("Discover Guilds")
            .searchable(text: $searchText, prompt: "Search guilds")
            .task {
                await viewModel.loadGuilds()
            }
            .refreshable {
                await viewModel.loadGuilds()
            }
        }
    }
    
    @ViewBuilder
    private func guildList(guilds: [GuildDTO]) -> some View {
        let filteredGuilds = searchText.isEmpty ? guilds : guilds.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        
        if filteredGuilds.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Guilds Found",
                message: searchText.isEmpty ? "No guilds available" : "Try a different search term"
            )
        } else {
            List {
                Section("Open Guilds") {
                    ForEach(filteredGuilds.filter { $0.isOpen && !$0.isJoined }) { guild in
                        NavigationLink {
                            GuildDetailView(guild: guild)
                        } label: {
                            DiscoveryGuildRow(guild: guild, viewModel: viewModel)
                        }
                    }
                }
                
                if filteredGuilds.contains(where: { $0.isJoined }) {
                    Section("Your Guilds") {
                        ForEach(filteredGuilds.filter { $0.isJoined }) { guild in
                            NavigationLink {
                                GuildDetailView(guild: guild)
                            } label: {
                                DiscoveryGuildRow(guild: guild, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DiscoveryGuildRow: View {
    let guild: GuildDTO
    @ObservedObject var viewModel: GuildDiscoveryViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(guild.name)
                            .font(.headline)
                        
                        if guild.isJoined {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(guild.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Label("\(guild.memberCount)", systemImage: "person.2")
                        Label(guild.reputationDisplay, systemImage: "star")
                        Label(guild.statusText, systemImage: guild.isOpen ? "lock.open" : "lock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            if !guild.isJoined && guild.isOpen {
                Button {
                    Task {
                        await viewModel.joinGuild(guild.id)
                    }
                } label: {
                    Text("Join Guild")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.joiningGuildId == guild.id)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class GuildDiscoveryViewModel: ObservableObject {
    @Published var loadingState: LoadingState<[GuildDTO]> = .idle
    @Published var joiningGuildId: UUID?
    
    private let api = TradersGuildAPI.shared
    private let token: String
    
    init(token: String) {
        self.token = token
    }
    
    func loadGuilds() async {
        loadingState = .loading
        
        do {
            let guilds = try await api.getGuilds(token: token)
            loadingState = .loaded(guilds)
        } catch {
            loadingState = .error(.networkError)
        }
    }
    
    func joinGuild(_ guildId: UUID) async {
        joiningGuildId = guildId
        
        do {
            try await api.joinGuild(id: guildId, token: token)
            await loadGuilds() // Refresh to show updated status
        } catch {
            // Handle error
        }
        
        joiningGuildId = nil
    }
}
```

---

This comprehensive guide covers all your DTOs with:
- ✅ JSON response examples
- ✅ Swift decoding examples
- ✅ Complete SwiftUI views
- ✅ API integration
- ✅ Error handling
- ✅ Edge cases
- ✅ Real-world usage patterns

Let me know if you need more examples for specific scenarios!
