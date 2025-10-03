//
//  RightDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI

// MARK: - User Model
struct GuildUser: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let level: Int
    let isOnline: Bool
    let isFriend: Bool
    let status: String?
}

// MARK: - Right Drawer Main View
struct RightDrawerMainView: View {
    let onClose: () -> Void
    
    @State private var dragTranslation: CGFloat = 0
    @State private var searchText: String = ""
    @State private var showFilterSheet: Bool = false
    @State private var selectedUser: GuildUser? = nil
    
    // Sample data
    @State private var onlineUsers: [GuildUser] = [
        GuildUser(name: "TradeMaster", level: 45, isOnline: true, isFriend: true, status: "Trading AAPL"),
        GuildUser(name: "ChartWizard", level: 38, isOnline: true, isFriend: false, status: "Analyzing markets"),
        GuildUser(name: "BullRunner", level: 52, isOnline: true, isFriend: true, status: nil),
        GuildUser(name: "MarketGuru", level: 41, isOnline: true, isFriend: false, status: "In a meeting"),
        GuildUser(name: "StockHawk", level: 33, isOnline: true, isFriend: true, status: nil)
    ]
    
    @State private var offlineUsers: [GuildUser] = [
        GuildUser(name: "SleepyTrader", level: 29, isOnline: false, isFriend: false, status: nil),
        GuildUser(name: "NightOwl", level: 47, isOnline: false, isFriend: true, status: "Away"),
        GuildUser(name: "QuietInvestor", level: 36, isOnline: false, isFriend: false, status: nil)
    ]
    
    @State private var friends: [GuildUser] = [
        GuildUser(name: "BestBuddy", level: 50, isOnline: true, isFriend: true, status: "Always online"),
        GuildUser(name: "OldFriend", level: 44, isOnline: false, isFriend: true, status: "Busy IRL")
    ]
    
    var filteredOnlineUsers: [GuildUser] {
        if searchText.isEmpty {
            return onlineUsers
        }
        return onlineUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredOfflineUsers: [GuildUser] {
        if searchText.isEmpty {
            return offlineUsers
        }
        return offlineUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredFriends: [GuildUser] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(AnimationConstants.standard) { onClose() }
                    }) {
                        Image(systemName: "chevron.right.dotted.chevron.right")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Users")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Guild Name and icon
                HStack {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("KAOS")
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
                
                // Member counts
                HStack(spacing: 2) {
                    Text("\(onlineUsers.count + offlineUsers.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Members")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Text("\(onlineUsers.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Online")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 7, height: 7)
                        .padding(.top, 0)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Spacer()
                }
                .padding(.leading, 35)
                
                // Search bar with filter
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                            .font(.subheadline)
                        
                        TextField("Search users...", text: $searchText)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.whiteText.opacity(0.5))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.accentColor)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding(.leading, 35)
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
            
            // User lists with disclosure groups
            ScrollView {
                VStack(spacing: 12) {
                    // Online Users
                    if !filteredOnlineUsers.isEmpty {
                        UserDisclosureGroup(
                            title: "Online",
                            count: filteredOnlineUsers.count,
                            icon: "circle.fill",
                            iconColor: AppColors.bullCandleGreen,
                            users: filteredOnlineUsers,
                            onUserTap: { user in
                                selectedUser = user
                            }
                        )
                    }
                    
                    // Friends
                    if !filteredFriends.isEmpty {
                        UserDisclosureGroup(
                            title: "Friends",
                            count: filteredFriends.count,
                            icon: "star.fill",
                            iconColor: AppColors.accentColor,
                            users: filteredFriends,
                            onUserTap: { user in
                                selectedUser = user
                            }
                        )
                    }
                    
                    // Offline Users
                    if !filteredOfflineUsers.isEmpty {
                        UserDisclosureGroup(
                            title: "Offline",
                            count: filteredOfflineUsers.count,
                            icon: "circle.fill",
                            iconColor: Color.gray,
                            users: filteredOfflineUsers,
                            onUserTap: { user in
                                selectedUser = user
                            }
                        )
                    }
                    
                    if filteredOnlineUsers.isEmpty && filteredOfflineUsers.isEmpty && filteredFriends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.whiteText.opacity(0.3))
                            Text("No users found")
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
        .sheet(item: $selectedUser) { user in
            UserChatSheet(user: user)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterOptionsView()
        }
    }
}

// MARK: - User Disclosure Group
struct UserDisclosureGroup: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let users: [GuildUser]
    let onUserTap: (GuildUser) -> Void
    
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
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // User list
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(users) { user in
                        UserRowView(user: user, onTap: { onUserTap(user) })
                    }
                }
            }
        }
    }
}

// MARK: - User Row View
struct UserRowView: View {
    let user: GuildUser
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(user.name.prefix(2)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    if user.isOnline {
                        Circle()
                            .fill(AppColors.bullCandleGreen)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.drawerBackground, lineWidth: 2)
                            )
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    if let status = user.status {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        Text("Level \(user.level)")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Friend indicator & chevron
                HStack(spacing: 6) {
                    if user.isFriend {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isPressed ? 0.15 : 0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - User Chat Sheet
struct UserChatSheet: View {
    let user: GuildUser
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ChatContentView(user: user)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppColors.accentColor.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(String(user.name.prefix(2)))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(user.isOnline ? AppColors.bullCandleGreen : Color.gray)
                                        .frame(width: 6, height: 6)
                                    Text(user.isOnline ? "Online" : "Offline")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
        }
    }
}

// MARK: - Chat Content View
struct ChatContentView: View {
    let user: GuildUser
    @State private var messageText = ""
    
    // Sample messages
    let messages = [
        ("Hi! How's the trading going today?", false, "10:23 AM"),
        ("Pretty good! Just caught a nice move on AAPL", true, "10:24 AM"),
        ("Nice! What was your entry?", false, "10:25 AM"),
        ("Got in at 175.20, targeting 178", true, "10:26 AM"),
        ("Solid trade! I'm watching TSLA right now", false, "10:28 AM"),
        ("Yeah TSLA looks interesting. Check the 4h chart", true, "10:29 AM")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        HStack {
                            if message.1 {
                                Spacer()
                            }
                            
                            VStack(alignment: message.1 ? .trailing : .leading, spacing: 4) {
                                Text(message.0)
                                    .font(.subheadline)
                                    .foregroundColor(message.1 ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        message.1 ?
                                        AppColors.accentColor :
                                        Color.gray.opacity(0.2)
                                    )
                                    .cornerRadius(16)
                                
                                Text(message.2)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !message.1 {
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                hideKeyboard()
            }
            
            Divider()
            
            // Message input
            HStack(spacing: 12) {
                TextField("Message \(user.name)...", text: $messageText)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .submitLabel(.send)
                    .onSubmit {
                        if !messageText.isEmpty {
                            messageText = ""
                        }
                    }
                
                Button(action: {
                    // Send message
                    if !messageText.isEmpty {
                        messageText = ""
                    }
                }) {
                    Image(systemName: messageText.isEmpty ? "paperplane" : "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(messageText.isEmpty ? .secondary : AppColors.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Filter Options View
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
