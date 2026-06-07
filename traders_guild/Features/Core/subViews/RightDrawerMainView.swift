//
//  RLRightDrawerMainView.swift
//  traders_guild
//
//  UPDATED: Uses RLAppState and new RL messaging DTOs.
//  Replaces old RightDrawerMainView that used AppState.
//

import SwiftUI
import UIKit

/// The main container for the right-side drawer.
/// Hosts search/filter UI, lists for chatrooms and users, and opens chats via RLMessagingManager.
struct RLRightDrawerMainView: View {
    // MARK: - Bindings & State
    let onClose: () -> Void
    var onSearchFocusChanged: ((Bool) -> Void)? = nil
    
    @EnvironmentObject var messagingManager: RLMessagingManager
    @EnvironmentObject var appState: RLAppState
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    
    @State private var dragTranslation: CGFloat = 0
    @State private var searchText: String = ""
    @State private var keyboardInset: CGFloat = 0
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Computed Filtered Lists
    private var filteredChatrooms: [RLGuildChatroomDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildChatrooms }
        return rightDrawerViewModel.guildChatrooms.filter { chatroom in
            chatroom.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredFriends: [RLDMThreadDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildFriends }
        return rightDrawerViewModel.guildFriends.filter { thread in
            thread.participant.username.localizedCaseInsensitiveContains(searchText) ||
            thread.participant.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredOnlineNonFriends: [RLDMThreadDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildOnlineNonFriends }
        return rightDrawerViewModel.guildOnlineNonFriends.filter { thread in
            thread.participant.username.localizedCaseInsensitiveContains(searchText) ||
            thread.participant.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredOfflineNonFriends: [RLDMThreadDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildOfflineNonFriends }
        return rightDrawerViewModel.guildOfflineNonFriends.filter { thread in
            thread.participant.username.localizedCaseInsensitiveContains(searchText) ||
            thread.participant.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredMemberFriends: [RLGuildMemberDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.memberFriends }
        return rightDrawerViewModel.memberFriends.filter { member in
            member.username.localizedCaseInsensitiveContains(searchText) ||
            member.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredMemberOnlineNonFriends: [RLGuildMemberDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.memberOnlineNonFriends }
        return rightDrawerViewModel.memberOnlineNonFriends.filter { member in
            member.username.localizedCaseInsensitiveContains(searchText) ||
            member.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredMemberOfflineNonFriends: [RLGuildMemberDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.memberOfflineNonFriends }
        return rightDrawerViewModel.memberOfflineNonFriends.filter { member in
            member.username.localizedCaseInsensitiveContains(searchText) ||
            member.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredMemberFriendsWithoutThread: [RLGuildMemberDTO] {
        let threadedUserIds = Set(filteredFriends.map { $0.participant.userId })
        return filteredMemberFriends.filter { !threadedUserIds.contains($0.userId) }
    }

    private var filteredMemberOnlineWithoutThread: [RLGuildMemberDTO] {
        let threadedUserIds = Set(filteredOnlineNonFriends.map { $0.participant.userId })
        return filteredMemberOnlineNonFriends.filter { !threadedUserIds.contains($0.userId) }
    }

    private var filteredMemberOfflineWithoutThread: [RLGuildMemberDTO] {
        let threadedUserIds = Set(filteredOfflineNonFriends.map { $0.participant.userId })
        return filteredMemberOfflineNonFriends.filter { !threadedUserIds.contains($0.userId) }
    }

    private var friendsCount: Int {
        filteredFriends.count + filteredMemberFriendsWithoutThread.count
    }

    private var onlineCount: Int {
        filteredOnlineNonFriends.count + filteredMemberOnlineWithoutThread.count
    }

    private var offlineCount: Int {
        filteredOfflineNonFriends.count + filteredMemberOfflineWithoutThread.count
    }
    
    private var hasNoResults: Bool {
        !searchText.isEmpty &&
        filteredChatrooms.isEmpty &&
        friendsCount == 0 &&
        onlineCount == 0 &&
        offlineCount == 0
    }
    
    var body: some View {
        if let guild = appState.currentGuild,
           appState.currentUser != nil {
            VStack(alignment: .leading, spacing: 0) {
                // Header section
                VStack {
                    HStack(spacing: 10) {
                        Button(action: {
                            withAnimation(AnimationConstants.standard) { onClose() }
                        }) {
                            Image(systemName: "chevron.right.dotted.chevron.right")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Messages")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        
                        // Unread badge
                        if rightDrawerViewModel.totalUnreadCount > 0 {
                            Text("\(rightDrawerViewModel.totalUnreadCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.onAccentForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.guildReputationAccent)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Guild Name and icon
                    HStack(spacing: 8) {
                        GuildCrestView(guild: guild, size: 32)
                        Text("\(guild.name)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.guildReputationAccent)
                        + Text(" Guild")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.guildReputationAccent)
                        Spacer()
                    }
                    .padding(.leading, 2)
                    
                    // Search bar using UnifiedSearchBar
                    UnifiedSearchBar(
                        text: $searchText,
                        placeholder: "Search chatrooms & users...",
                        onClear: {
                            isSearchFocused = false
                        },
                        onFocusChange: { focused in
                            isSearchFocused = focused
                            onSearchFocusChanged?(focused)
                            if !focused {
                                keyboardInset = 0
                            }
                        }
                    )
                    .padding(.top, 12)
                    
                    Rectangle()
                        .fill(AppColors.surfaceGray40)
                        .frame(height: 0.5)
                        .padding(.top, 12)
                }
                .padding(.leading, 25)
                .padding(.trailing, 25)
                .padding(.bottom, 4)
                .padding(.top, 60)
                .spotlightTarget("chat-header")

                // User lists and chatrooms with disclosure groups
                ScrollView {
                    VStack(spacing: 12) {
                        // Loading state
                        if rightDrawerViewModel.isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        }
                        // No results state
                        else if hasNoResults {
                            UnifiedNoResultsState(
                                searchText: searchText,
                                message: "No results found",
                                suggestion: "Try searching for a different chatroom or user"
                            )
                        } else {
                            // Chatrooms Section
                            if !filteredChatrooms.isEmpty {
                                RLChatroomDisclosureGroup(
                                    chatrooms: filteredChatrooms,
                                    isExpanded: rightDrawerViewModel.disclosureBinding(for: .chatrooms),
                                    onChatroomTap: { chatroom in
                                        messagingManager.openChatroom(chatroom)
                                    }
                                )
                            }
                            
                            RLDMDisclosureGroup(
                                title: "Friends",
                                count: friendsCount,
                                icon: "person.crop.circle",
                                iconColor: AppColors.friendAccent,
                                isExpanded: rightDrawerViewModel.disclosureBinding(for: .friends),
                                threads: filteredFriends,
                                members: filteredMemberFriendsWithoutThread,
                                onThreadTap: { thread in
                                    messagingManager.openDMThread(thread)
                                },
                                onMemberTap: { member in
                                    openOrCreateDM(with: member, guildId: guild.id)
                                }
                            )

                            RLDMDisclosureGroup(
                                title: "Online",
                                count: onlineCount,
                                icon: "circle.fill",
                                iconColor: AppColors.statusPositive,
                                isExpanded: rightDrawerViewModel.disclosureBinding(for: .online),
                                threads: filteredOnlineNonFriends,
                                members: filteredMemberOnlineWithoutThread,
                                onThreadTap: { thread in
                                    messagingManager.openDMThread(thread)
                                },
                                onMemberTap: { member in
                                    openOrCreateDM(with: member, guildId: guild.id)
                                }
                            )

                            RLDMDisclosureGroup(
                                title: "Offline",
                                count: offlineCount,
                                icon: "circle.fill",
                                iconColor: AppColors.systemGray,
                                isExpanded: rightDrawerViewModel.disclosureBinding(for: .offline),
                                threads: filteredOfflineNonFriends,
                                members: filteredMemberOfflineWithoutThread,
                                onThreadTap: { thread in
                                    messagingManager.openDMThread(thread)
                                },
                                onMemberTap: { member in
                                    openOrCreateDM(with: member, guildId: guild.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await rightDrawerViewModel.refresh(for: guild.id, appState: appState)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: keyboardInset > 0 ? keyboardInset + 12 : 0)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isSearchFocused = false
                    onSearchFocusChanged?(false)
                    hideKeyboard()
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                dragTranslation = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let threshold = LayoutConstants.drawerDismissThreshold
                            if dragTranslation > threshold {
                                onClose()
                            }
                            dragTranslation = 0
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    LinearGradient(
                        colors: [
                            AppColors.drawerBackground,
                            AppColors.sheetBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .overlay(
                Rectangle()
                    .fill(AppColors.panelFillEmphasis)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity),
                alignment: .leading
            )
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: LayoutConstants.cornerRadius,
                        bottomLeading: LayoutConstants.cornerRadius,
                        bottomTrailing: 0,
                        topTrailing: 0
                    )
                )
            )
            .shadow(radius: LayoutConstants.shadowRadius)
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardInset(from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardInset = 0
                }
            }
            .onDisappear {
                onSearchFocusChanged?(false)
                keyboardInset = 0
            }
            .task {
                // Preload data when drawer appears
                await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
            }
        } else {
            EmptyView()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func updateKeyboardInset(from notification: Notification) {
        guard isSearchFocused,
              let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - endFrame.minY - bottomSafeAreaInset)
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardInset = overlap
        }
    }

    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { scene in
                (scene as? UIWindowScene)?.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom
            }
            .first ?? 0
    }

    private func openOrCreateDM(with member: RLGuildMemberDTO, guildId: UUID) {
        Task {
            if let thread = rightDrawerViewModel.findDMThread(for: member.userId) {
                messagingManager.openDMThread(thread)
            } else {
                await messagingManager.openDMChat(with: member)
                await rightDrawerViewModel.refresh(for: guildId, appState: appState)
            }
        }
    }
}

// MARK: - Chatroom Disclosure Group (Using UnifiedDisclosureGroup)

/// Collapsible section listing chatrooms; tapping opens a chatroom sheet.
struct RLChatroomDisclosureGroup: View {
    let chatrooms: [RLGuildChatroomDTO]
    let isExpanded: Binding<Bool>
    let onChatroomTap: (RLGuildChatroomDTO) -> Void
    
    private var unreadCount: Int {
        chatrooms.reduce(0) { $0 + $1.unreadCount }
    }
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: "Guild Chatrooms",
            count: chatrooms.count,
            icon: "shield.pattern.checkered",
            iconColor: AppColors.guildReputationAccent,
            isExpanded: isExpanded
        ) {
            VStack(spacing: 6) {
                ForEach(chatrooms) { chatroom in
                    RLChatroomRowView(chatroom: chatroom, onTap: { onChatroomTap(chatroom) })
                }
            }
        }
    }
}

// MARK: - DM Disclosure Group (Using UnifiedDisclosureGroup)

/// Collapsible section listing DM threads; tapping opens a chat sheet.
struct RLDMDisclosureGroup: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let isExpanded: Binding<Bool>
    let threads: [RLDMThreadDTO]
    let members: [RLGuildMemberDTO]
    let onThreadTap: (RLDMThreadDTO) -> Void
    let onMemberTap: (RLGuildMemberDTO) -> Void
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: title,
            count: count,
            icon: icon,
            iconColor: iconColor,
            isExpanded: isExpanded
        ) {
            VStack(spacing: 6) {
                ForEach(threads) { thread in
                    RLUserDMRowView(thread: thread, onTap: { onThreadTap(thread) })
                }
                ForEach(members) { member in
                    RLMemberRowView(member: member, onTap: { onMemberTap(member) })
                }
            }
        }
    }
}

// MARK: - Member Disclosure Group (Fallback when no threads exist yet)

struct RLMemberDisclosureGroup: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let members: [RLGuildMemberDTO]
    let onMemberTap: (RLGuildMemberDTO) -> Void

    var body: some View {
        UnifiedDisclosureGroup(
            title: title,
            count: count,
            icon: icon,
            iconColor: iconColor,
            isExpandedByDefault: true
        ) {
            VStack(spacing: 6) {
                ForEach(members) { member in
                    RLMemberRowView(member: member, onTap: { onMemberTap(member) })
                }
            }
        }
    }
}

// MARK: - Member Row View (Fallback)

struct RLMemberRowView: View {
    let member: RLGuildMemberDTO
    let onTap: () -> Void

    @State private var isPressed = false
    @EnvironmentObject var appState: RLAppState

    private var isEffectivelyOnline: Bool {
        appState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarUrl = member.avatarUrl, !avatarUrl.isEmpty {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            avatarPlaceholder
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    Circle()
                        .fill(isEffectivelyOnline ? AppColors.onlineStatusGreen : AppColors.greyText)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 1)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 2) {
                        if member.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }

                        Text(member.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(member.isBlocked ? AppColors.greyText : AppColors.listRowPrimaryForeground)

                        if member.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(member.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                    }

                    UnifiedRoleBadge(
                        member: member,
                        showReputation: true,
                        fontSize: .caption,
                        iconSize: .caption2
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.guildReputationAccent.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Text(member.username.prefix(2))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.guildReputationAccent)
            )
    }
}
