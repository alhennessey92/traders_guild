//
//  RightDrawerMainView.swift
//  traders_guild
//
//  UPDATED: Now uses UnifiedComponents for consistent styling
//

import SwiftUI

/// The main container for the right-side drawer.
/// Hosts search/filter UI, lists for chatrooms and users, and opens chats via MessagingManager.
struct RightDrawerMainView: View {
    // MARK: - Bindings & State
    let onClose: () -> Void
    
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var rightDrawerViewModel: RightDrawerViewModel
    
    @State private var dragTranslation: CGFloat = 0
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Computed Filtered Lists
    private var filteredChatrooms: [GuildChatroomDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildChatrooms }
        return rightDrawerViewModel.guildChatrooms.filter { chatroom in
            chatroom.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredFriends: [DMDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildFriends }
        return rightDrawerViewModel.guildFriends.filter { dm in
            dm.participant.globalMember.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredOnlineNonFriends: [DMDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildOnlineNonFriends }
        return rightDrawerViewModel.guildOnlineNonFriends.filter { dm in
            dm.participant.globalMember.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredOfflineNonFriends: [DMDTO] {
        guard !searchText.isEmpty else { return rightDrawerViewModel.guildOfflineNonFriends }
        return rightDrawerViewModel.guildOfflineNonFriends.filter { dm in
            dm.participant.globalMember.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var hasNoResults: Bool {
        !searchText.isEmpty &&
        filteredChatrooms.isEmpty &&
        filteredFriends.isEmpty &&
        filteredOnlineNonFriends.isEmpty &&
        filteredOfflineNonFriends.isEmpty
    }
    
    var body: some View {
        if let user = appState.currentUser,
           let guild = appState.currentGuild {
            VStack(alignment: .leading, spacing: 0) {
                // Header section
                VStack {
                    HStack (spacing: 10){
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
                    }
                    
                    // Guild Name and icon
                    HStack (spacing: 4) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(guild.guild.name)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        + Text(" Guild")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentColor)
                        Spacer()
                    }
                    .padding(.leading, 35)
                    
                    // Search bar using UnifiedSearchBar
                    UnifiedSearchBar(
                        text: $searchText,
                        placeholder: "Search chatrooms & users...",
                        onClear: {
                            isSearchFocused = false
                        }
                    )
                    .padding(.top, 12)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: 0.5)
                        .padding(.top, 12)
                }
                .padding(.leading, 25)
                .padding(.trailing, 25)
                .padding(.bottom, 4)
                .padding(.top, 60)
                
                // User lists and chatrooms with disclosure groups
                ScrollView {
                    VStack(spacing: 12) {
                        // No results state
                        if hasNoResults {
                            UnifiedNoResultsState(
                                searchText: searchText,
                                message: "No results found",
                                suggestion: "Try searching for a different chatroom or user"
                            )
                        } else {
                            // Chatrooms Section
                            if !filteredChatrooms.isEmpty {
                                ChatroomDisclosureGroup(
                                    chatrooms: filteredChatrooms,
                                    onChatroomTap: { chatroom in
                                        messagingManager.openChatroom(chatroom)
                                    }
                                )
                            }
                            
                            // Friends Section
                            if !filteredFriends.isEmpty {
                                DMDisclosureGroup(
                                    title: "Friends",
                                    count: filteredFriends.count,
                                    icon: "person.crop.circle",
                                    iconColor: AppColors.friendAccent,
                                    userDMs: filteredFriends,
                                    onUserTap: { userDM in
                                        messagingManager.openUserDM(userDM)
                                    }
                                )
                            }
                            
                            // Online Section
                            if !filteredOnlineNonFriends.isEmpty {
                                DMDisclosureGroup(
                                    title: "Online",
                                    count: filteredOnlineNonFriends.count,
                                    icon: "circle.fill",
                                    iconColor: Color.green,
                                    userDMs: filteredOnlineNonFriends,
                                    onUserTap: { userDM in
                                        messagingManager.openUserDM(userDM)
                                    }
                                )
                            }
                            
                            // Offline Section
                            if !filteredOfflineNonFriends.isEmpty {
                                DMDisclosureGroup(
                                    title: "Offline",
                                    count: filteredOfflineNonFriends.count,
                                    icon: "circle.fill",
                                    iconColor: Color.gray,
                                    userDMs: filteredOfflineNonFriends,
                                    onUserTap: { userDM in
                                        messagingManager.openUserDM(userDM)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isSearchFocused = false
                    hideKeyboard()
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if (value.translation.width > 0) {
                                dragTranslation = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let threshold = LayoutConstants.drawerDismissThreshold
                            if (dragTranslation > threshold) {
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
                    AppColors.drawerBackground.opacity(0.6)
                }
            )
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.1))
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
        } else {
            EmptyView()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Chatroom Disclosure Group (Using UnifiedDisclosureGroup)

/// Collapsible section listing chatrooms; tapping opens a chatroom sheet.
struct ChatroomDisclosureGroup: View {
    let chatrooms: [GuildChatroomDTO]
    let onChatroomTap: (GuildChatroomDTO) -> Void
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: "Guild Chatrooms",
            count: chatrooms.count,
            icon: "shield.pattern.checkered",
            iconColor: AppColors.accentColor,
            isExpandedByDefault: true
        ) {
            VStack(spacing: 6) {
                ForEach(chatrooms) { chatroom in
                    ChatroomRowView(chatroom: chatroom, onTap: { onChatroomTap(chatroom) })
                }
            }
        }
    }
}

// MARK: - DM Disclosure Group (Using UnifiedDisclosureGroup)

/// Collapsible section listing users; tapping opens a user chat sheet.
struct DMDisclosureGroup: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let userDMs: [DMDTO]
    let onUserTap: (DMDTO) -> Void
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: title,
            count: count,
            icon: icon,
            iconColor: iconColor,
            isExpandedByDefault: true
        ) {
            VStack(spacing: 6) {
                ForEach(userDMs) { userDM in
                    UserDMRowView(userDM: userDM, onTap: { onUserTap(userDM) })
                }
            }
        }
    }
}


