//
//  RightDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI


/// Identifies which sheet content to present from the right drawer (user or chatroom).
/// Conforms to `Identifiable` and `Equatable` for use with `.sheet(item:)` and `.onChange`.
enum RightDrawerSheetContent: Identifiable, Equatable {
    case user(GuildUser)
    case chatroom(Chatroom)
    
    var id: String {
        switch self {
        case .user(let user): return "user-\(user.id)"
        case .chatroom(let chatroom): return "chatroom-\(chatroom.id)"
        }
    }
    
    static func == (lhs: RightDrawerSheetContent, rhs: RightDrawerSheetContent) -> Bool {
        lhs.id == rhs.id
    }
}

/// The main container for the right-side drawer.
/// Hosts search/filter UI, lists for chatrooms and users, and presents detail sheets.
struct RightDrawerMainView: View {
    // MARK: - Bindings & State
    // onClose: Callback to close the drawer
    // chatrooms / onlineUsers / offlineUsers / friends: Data sources for lists
    // sheetOverlayVisible: Controls the global overlay when a sheet is presented
    // dismissSheetsSignal: External signal to programmatically dismiss any sheet
    // dragTranslation: Current drag offset for swipe-to-dismiss
    // searchText: Current text in the search field
    // showFilterSheet: Controls filter options sheet presentation
    // sheetContent: Which detail sheet is currently shown (user or chatroom)
    // isSearchFocused: Tracks keyboard focus for search

    let onClose: () -> Void
    let chatrooms: [Chatroom]
    let onlineUsers: [GuildUser]
    let offlineUsers: [GuildUser]
    let friends: [GuildUser]
    @Binding var sheetOverlayVisible: Bool
    @Binding var dismissSheetsSignal: Bool
    
    @State private var dragTranslation: CGFloat = 0
    @State private var searchText: String = ""
    @State private var showFilterSheet: Bool = false
    @State private var sheetContent: RightDrawerSheetContent? = nil
    @FocusState private var isSearchFocused: Bool
    
    // Add a function to dismiss all sheets
    private func dismissAllSheets() {
        sheetContent = nil
        showFilterSheet = false
    }
    
    
    
    
    
    /// Filters the respective lists by `searchText` (case-insensitive).
    var filteredChatrooms: [Chatroom] {
        if searchText.isEmpty {
            return chatrooms
        }
        return chatrooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// Filters the respective lists by `searchText` (case-insensitive).
    var filteredOnlineUsers: [GuildUser] {
        if searchText.isEmpty {
            return onlineUsers
        }
        return onlineUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// Filters the respective lists by `searchText` (case-insensitive).
    var filteredOfflineUsers: [GuildUser] {
        if searchText.isEmpty {
            return offlineUsers
        }
        return offlineUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// Filters the respective lists by `searchText` (case-insensitive).
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
                HStack (spacing: 10){
                    Button(action: {
                        dismissAllSheets()
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
                    if !filteredChatrooms.isEmpty {
                        ChatroomDisclosureGroup(
                            chatrooms: filteredChatrooms,
                            onChatroomTap: { chatroom in
                                sheetContent = .chatroom(chatroom)
                            }
                        )
                    }
                    
                    // Online Users
                    if !filteredOnlineUsers.isEmpty {
                        UserDisclosureGroup(
                            title: "Online",
                            count: filteredOnlineUsers.count,
                            icon: "circle.fill",
                            iconColor: AppColors.bullCandleGreen,
                            users: filteredOnlineUsers,
                            onUserTap: { user in
                                sheetContent = .user(user)
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
                                sheetContent = .user(user)
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
                                sheetContent = .user(user)
                            }
                        )
                    }
                    
                    if filteredChatrooms.isEmpty && filteredOnlineUsers.isEmpty && filteredOfflineUsers.isEmpty && filteredFriends.isEmpty {
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
                            dismissAllSheets()
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
        
        // Present detail sheets with clear background and consistent detents (matches left drawer)
        .sheet(item: $sheetContent) { content in
            switch content {
            case .user(let user):
                UserChatSheet(user: user)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.clear)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationCornerRadius(20)
            case .chatroom(let chatroom):
                ChatroomSheet(chatroom: chatroom)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.clear)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationCornerRadius(20)
            }
        }
        
        // Keep the global overlay in sync with whether a sheet is presented
        .onChange(of: sheetContent) { oldValue, newValue in
            sheetOverlayVisible = newValue != nil
        }
        
        // Respond to external dismissal requests (e.g., tapping the overlay)
        .onChange(of: dismissSheetsSignal) { oldValue, newValue in
            if newValue {
                dismissAllSheets()
                dismissSheetsSignal = false
            }
        }
        
        .sheet(isPresented: $showFilterSheet) {
            FilterOptionsView()
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(Color.clear)
                .presentationCornerRadius(25)
                .presentationContentInteraction(.scrolls)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Collapsible section listing chatrooms; tapping opens a chatroom sheet.
struct ChatroomDisclosureGroup: View {
    let chatrooms: [Chatroom]
    let onChatroomTap: (Chatroom) -> Void
    
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
                .background(Color.white.opacity(0.06))
                .cornerRadius(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // User list
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(users) { user in
                        GuildUserRowView(user: user, onTap: { onUserTap(user) })
                    }
                }
            }
        }
    }
}


/// Sheet container for chatroom content with a compact header and dismiss action.
struct ChatroomSheet: View {
    let chatroom: Chatroom
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ChatroomContentView(chatroom: chatroom)
                .navigationBarTitleDisplayMode(.inline)
//                .background(AppColors.gradientBackgroundMid)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.accentColor.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "number")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chatroom.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(chatroom.isActive ? AppColors.bullCandleGreen : Color.gray)
                                        .frame(width: 6, height: 6)
                                    Text("\(chatroom.memberCount) members")
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
        .background(AppColors.drawerBackground.opacity(0.2))
        
    }
}

/// Mocked chatroom content: messages list and input field.
struct ChatroomContentView: View {
    let chatroom: Chatroom
    @State private var messageText = ""
    
    // Sample messages
    let messages = [
        ("Hey everyone! What's the market looking like today?", "User1", false, "9:15 AM"),
        ("BTC broke resistance, looking bullish!", "User2", false, "9:18 AM"),
        ("I caught that move! Entry at 45.2k", "You", true, "9:20 AM"),
        ("Nice entry! What's your target?", "User3", false, "9:21 AM"),
        ("Aiming for 47k, stop at 44.5k", "You", true, "9:22 AM"),
        ("Smart play. I'm watching ETH right now", "User1", false, "9:25 AM"),
        ("ETH looks good too, check the 4h chart", "User4", false, "9:27 AM"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        HStack(alignment: .top, spacing: 8) {
                            if message.2 {
                                Spacer()
                            } else {
                                // Avatar for other users
                                Circle()
                                    .fill(AppColors.accentColor.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(message.1.prefix(2)))
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.accentColor)
                                    )
                            }
                            
                            VStack(alignment: message.2 ? .trailing : .leading, spacing: 4) {
                                if !message.2 {
                                    Text(message.1)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(message.0)
                                    .font(.subheadline)
                                    .foregroundColor(message.2 ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        message.2 ?
                                        AppColors.accentColor :
                                        Color.gray.opacity(0.2)
                                    )
                                    .cornerRadius(16)
                                
                                Text(message.3)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !message.2 {
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
                TextField("Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
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

/// Sheet container for 1:1 user chat content with a compact header and dismiss action.
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
//        .background(Color.black.opacity(0.3))
    }
}

/// Mocked 1:1 chat content: messages list and input field.
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

