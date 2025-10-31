//
//  RightDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI




/// The main container for the right-side drawer.
/// Hosts search/filter UI, lists for chatrooms and users, and opens chats via MessagingManager.
struct RightDrawerMainView: View {
    // MARK: - Bindings & State
    // onClose: Callback to close the drawer
    // chatrooms / onlineUsers / offlineUsers / friends: Data sources for lists
    // dragTranslation: Current drag offset for swipe-to-dismiss
    // searchText: Current text in the search field
    // showFilterSheet: Controls filter options sheet presentation
    // isSearchFocused: Tracks keyboard focus for search

    let onClose: () -> Void
//    let chatrooms: [Chatroom]
//    let onlineUsers: [UserDM]
//    let offlineUsers: [UserDM]
//    let friends: [UserDM]
    
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var rightDrawerViewModel: RightDrawerViewModel
    
    @State private var dragTranslation: CGFloat = 0
    @State private var searchText: String = ""
    @State private var showFilterSheet: Bool = false
    @FocusState private var isSearchFocused: Bool


    
    
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
                        Text("\(guild.name)")
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
                    
                    
                    
                    // Search bar with filter
                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.whiteText.opacity(0.5))
                                .font(.subheadline)
                            
                            TextField("Search...", text: $searchText)
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.done)
                                .focused($isSearchFocused)
                                .onTapGesture {
                                    isSearchFocused = true
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.unhighlightedTextBoxBackground)
                        .clipShape(Capsule())
                        .onTapGesture {
                            isSearchFocused = true
                        }
                        
                        Button(action: { showFilterSheet = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(AppColors.whiteText)
                                .frame(width: 40, height: 40)
                                .background(AppColors.unhighlightedTextBoxBackground)
                                .clipShape(Circle())
                        }
                    }
    //                .padding(.leading, 35)
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
                        // Chatrooms Section
                        
                        ChatroomDisclosureGroup(
                            chatrooms: rightDrawerViewModel.guildChatrooms,
                            onChatroomTap: { chatroom in
                                messagingManager.openChatroom(chatroom)
                            }
                        )
                        
                        
                        // Friends Section (now properly filtered)
                        DMDisclosureGroup(
                            title: "Friends",
                            count: rightDrawerViewModel.guildFriends.count,
                            icon: "star.fill",
                            iconColor: AppColors.accentColor,
                            userDMs: rightDrawerViewModel.guildFriends,
                            onUserTap: { userDM in
                                messagingManager.openUserDM(userDM)
                            }
                        )
    //                    if !filteredFriends.isEmpty {
    //                        UserDisclosureGroup(
    //                            title: "Friends",
    //                            count: filteredFriends.count,
    //                            icon: "star.fill",
    //                            iconColor: AppColors.accentColor,
    //                            users: filteredFriends,
    //                            onUserTap: { user in
    //                                messagingManager.openUserChat(user)
    //                            }
    //                        )
    //                    }
                        
                        // Online Users (excludes friends)
                        DMDisclosureGroup(
                            title: "Online",
                            count: rightDrawerViewModel.guildOnlineNonFriends.count,
                            icon: "circle.fill",
                            iconColor: AppColors.bullCandleGreen,
                            userDMs: rightDrawerViewModel.guildOnlineNonFriends,
                            onUserTap: { userDM in
                                messagingManager.openUserDM(userDM)
                            }
                        )
    //                    if !filteredOnlineUsers.isEmpty {
    //                        UserDisclosureGroup(
    //                            title: "Online",
    //                            count: filteredOnlineUsers.count,
    //                            icon: "circle.fill",
    //                            iconColor: AppColors.bullCandleGreen,
    //                            users: filteredOnlineUsers,
    //                            onUserTap: { user in
    //                                messagingManager.openUserChat(user)
    //                            }
    //                        )
    //                    }
                        
                        // Offline Users (excludes friends)
                        DMDisclosureGroup(
                            title: "Offline",
                            count: rightDrawerViewModel.guildOfflineNonFriends.count,
                            icon: "circle.fill",
                            iconColor: Color.gray,
                            userDMs: rightDrawerViewModel.guildOfflineNonFriends,
                            onUserTap: { userDM in
                                messagingManager.openUserDM(userDM)
                            }
                        )
    //                    if !filteredOfflineUsers.isEmpty {
    //                        UserDisclosureGroup(
    //                            title: "Offline",
    //                            count: filteredOfflineUsers.count,
    //                            icon: "circle.fill",
    //                            iconColor: Color.gray,
    //                            users: filteredOfflineUsers,
    //                            onUserTap: { user in
    //                                messagingManager.openUserChat(user)
    //                            }
    //                        )
    //                    }
                        
                        // No results state
                        if rightDrawerViewModel.guildChatrooms.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(AppColors.whiteText.opacity(0.3))
                                Text("No results found")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.whiteText.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
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
            
            // Filter options sheet
            .sheet(isPresented: $showFilterSheet) {
                FilterOptionsView()
                    .withGlobalAlerts()
                    .presentationDetents([.fraction(0.8)])
                    .presentationBackground(Color.clear)
                    .presentationCornerRadius(25)
                    .presentationContentInteraction(.scrolls)
            }
        } else {
            // Optional: Show error state if user/guild missing
            EmptyView()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Collapsible section listing chatrooms; tapping opens a chatroom sheet.
struct ChatroomDisclosureGroup: View {
    let chatrooms: [GuildChatroomDTO]
    let onChatroomTap: (GuildChatroomDTO) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                        .frame(width: 16)
                    
                    Text(" Guild Chatrooms")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("(\(chatrooms.count))")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Chatroom list
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(chatrooms) { chatroom in
                        ChatroomRowView(chatroom: chatroom, onTap: { onChatroomTap(chatroom) })
                    }
                }
            }
        }
    }
}


/// Collapsible section listing users; tapping opens a user chat sheet.
struct DMDisclosureGroup: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let userDMs: [DMDTO]
    let onUserTap: (DMDTO) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(iconColor)
                        .frame(width: 16)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // User list
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(userDMs) { userDM in
                        UserDMRowView(userDM: userDM, onTap: { onUserTap(userDM) })
                    }
                }
            }
        }
    }
}


/// Filter options presented as a sheet from the right drawer.
struct FilterOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOnlineOnly = false
    @State private var showFriendsOnly = false
    @State private var sortBy = "Name"
    
    var body: some View {
        NavigationView {
            List {
                Section("Display") {
                    Toggle("Online Users Only", isOn: $showOnlineOnly)
                    Toggle("Friends Only", isOn: $showFriendsOnly)
                }
                
                Section("Sort By") {
                    ForEach(["Name", "Level", "Status"], id: \.self) { option in
                        HStack {
                            Text(option)
                            Spacer()
                            if sortBy == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sortBy = option
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.3))
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

