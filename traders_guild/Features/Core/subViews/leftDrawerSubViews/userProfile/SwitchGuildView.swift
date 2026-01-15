//
//  SwitchGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
//  UPDATED for flat DTOs - uses RLGuildWithMembership
//

import SwiftUI

// MARK: - Switch Guild Main View
struct SwitchGuildView: View {
    let onBack: () -> Void
    @Binding var selectedDetent: PresentationDetent
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var isLoading: Bool = false
    @State private var showJoinGuild = false
    @State private var showCreateGuild = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(AppColors.whiteText)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Switch Guild")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                }
                .padding(.top, 5)
                .padding(.horizontal)
                
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
            
            // Guild list
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading guilds...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rlAppState.userGuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No guilds found")
                        .foregroundColor(.secondary)
                    Text("Join or create a guild to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(rlAppState.userGuilds) { item in
                            GuildSwitchRow(
                                item: item,
                                isCurrentGuild: item.guild.id == rlAppState.currentGuild?.id,
                                onSelect: {
                                    selectGuild(item)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 20)
            }
            
            Divider()

            HStack(spacing: 8) {
                DrawerActionButton(
                    title: "Join a Guild",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        showJoinGuild = true
                    }
                )
                
                Spacer()
                
                DrawerActionButton(
                    title: "Create a Guild",
                    backgroundColor: AppColors.whiteText.opacity(0.8),
                    foregroundColor: Color.black,
                    strokeColor: Color.black,
                    strokeWidth: 0.5,
                    action: {
                        showCreateGuild = true
                    }
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .background(AppColors.sheetBackground)
        }
        .task {
            await loadUserGuilds()
        }
        .fullScreenCover(isPresented: $showJoinGuild) {
            JoinGuildFlowView()
                .environmentObject(rlAppState)
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showCreateGuild) {
            CreateGuildFlowView()
                .environmentObject(rlAppState)
                .environmentObject(appState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
    }
    
    // Load user's guilds
    private func loadUserGuilds() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await rlAppState.fetchUserGuilds()
        } catch is CancellationError {
            return
        } catch {
            print(error)
            rlAppState.showError(error, title: "Failed to Load Guilds", style: .toast)
        }
    }
    
    // Select and switch to guild
    private func selectGuild(_ item: RLGuildWithMembership) {
        // Update current guild in RLAppState
        rlAppState.selectGuild(item)
        
        // Clear drawer cache to force refresh for new guild
        leftDrawerViewModel.clearCache()
        
        // Show success message
        rlAppState.showSuccess("Switched to \(item.guild.name)")
    }
}

// MARK: - Guild Switch Row (Updated for RLGuildWithMembership)

struct GuildSwitchRow: View {
    let item: RLGuildWithMembership
    let isCurrentGuild: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            // Only execute action if not current guild
            if !isCurrentGuild {
                onSelect()
            }
        }) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    // Guild name
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.title2)
                            .foregroundColor(AppColors.accentColor.opacity(0.6))
                        
                        Text(item.guild.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        + Text(" Guild")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    // Member count and status
                    Text("\(item.guild.memberCount) Members - \(item.guild.statusText)")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.leading, 15)
                    
                    // Owner info (TODO: backend will return embedded owner)
                    HStack(spacing: 3) {
                        Text("Owner Name")  // TODO: item.guild.owner.displayName
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text("Admin")  // TODO: item.guild.ownerRole.displayName
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                    
                    // Members online
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(item.guild.membersOnline) online")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                    }
                    .padding(.leading, 15)
                    
                    // Guild reputation
                    HStack(spacing: 2) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text(item.guild.reputationDisplay)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        Text(" Guild Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                    
                    Divider()
                    
                    // User's role and reputation in this guild
                    HStack(spacing: 2) {
                        Text("You are a ")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                       
                        Text(item.role.displayName)
                            .font(.caption)
                            .foregroundColor(item.role.color)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.top, 1)
                            .padding(.leading, 3)
                            .padding(.trailing, 3)
                        
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(item.membership.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                    .padding(.leading, 15)
                }
                
                Spacer()
                
                // Selection indicator
                VStack {
                    if isCurrentGuild {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.accentColor)
                            .font(.system(size: 20))
                        
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(AppColors.accentColor)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.greyText.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentGuild ? AppColors.accentColor.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrentGuild ? AppColors.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isCurrentGuild ? 0.8 : 1.0)
    }
}

// MARK: - Join Guild Full Screen Flow

struct JoinGuildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove

    @State private var selectedGuild: RLGuildDTO?
    @State private var showGuildDetail = false

    var body: some View {
        NavigationStack {
            JoinGuildView(
                onSelectGuild: { guild in
                    selectedGuild = guild
                    showGuildDetail = true
                }
            )
            .environmentObject(rlAppState)
            .environmentObject(appState)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.gradientBackgroundDark,
                        AppColors.gradientBackgroundDark,
                        AppColors.fadedBackground.opacity(0.6),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Join a Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.whiteText)
                }
            }
            .navigationDestination(isPresented: $showGuildDetail) {
                if let guild = selectedGuild {
                    GuildDetailView(guild: guild, onJoin: {
                        dismiss()
                    })
                    .environmentObject(rlAppState)
                    .environmentObject(appState)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppColors.gradientBackgroundDark,
                                AppColors.gradientBackgroundDark,
                                AppColors.fadedBackground.opacity(0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Main Join Guild View (Search/List)

struct JoinGuildView: View {
    let onSelectGuild: (RLGuildDTO) -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var openGuilds: [RLGuildDTO] = []
    @State private var isLoading: Bool = false

    var filteredGuilds: [RLGuildDTO] {
        if searchText.isEmpty {
            return openGuilds
        }
        return openGuilds.filter { guild in
            guild.name.localizedCaseInsensitiveContains(searchText) ||
            (guild.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Search bar with filter
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .font(.subheadline)

                    TextField("Search guilds...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.whiteText.opacity(0.06))
                .clipShape(Capsule())

                Button(action: {}) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(AppColors.whiteText.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(AppColors.whiteText.opacity(0.04))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            // Guild search results
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading guilds...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredGuilds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No open guilds available" : "No guilds found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(filteredGuilds) { guild in
                            JoinGuildRow(
                                guild: guild,
                                onTap: {
                                    onSelectGuild(guild)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isSearchFocused = false
                    hideKeyboard()
                }
            }
        }
        .padding(.top, 10)
        .task {
            await loadOpenGuilds()
        }
    }

    // Load open guilds
    private func loadOpenGuilds() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let guilds = try await rlAppState.fetchOpenGuilds()
            openGuilds = guilds
        } catch is CancellationError {
            return
        } catch {
            rlAppState.showError(error, title: "Failed to Load Guilds", style: .toast)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Join Guild Row

struct JoinGuildRow: View {
    let guild: RLGuildDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.title2)
                            .foregroundColor(AppColors.accentColor.opacity(0.6))

                        Text(guild.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    }

                    Text("\(guild.memberCount) Members • \(guild.isOpen ? "Open" : "Private")")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.leading, 15)

                    // Owner info (TODO: backend will return embedded owner)
                    HStack(spacing: 3) {
                        Text("Owner Name")  // TODO: guild.owner.displayName
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)

                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)

                        Text("Admin")  // TODO: guild.ownerRole.displayName
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)

                    HStack(spacing: 2) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text(guild.reputationDisplay)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        Text(" Guild Reputation")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText.opacity(0.5))
            }
            .padding(.top, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Guild Detail View (for joining)

struct GuildDetailView: View {
    let guild: RLGuildDTO
    let onJoin: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @State private var showJoinForm = false
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Guild header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.accentColor)

                        VStack(alignment: .leading) {
                            Text(guild.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)

                            Text("\(guild.memberCount) Members")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        }
                    }

                    if let description = guild.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(10)

                // Guild stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guild Stats")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    HStack {
                        StatBox(label: "Reputation", value: guild.reputationDisplay)
                        StatBox(label: "Online", value: "\(guild.membersOnline)")
                        StatBox(label: "Members", value: "\(guild.memberCount)")
                    }
                }
                .padding()
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(10)

                Spacer(minLength: 20)

                // Join button
                if isJoining {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    StandardActionButtonFullWidth(
                        title: guild.isOpen ? "Join Guild" : "Request to Join",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: Color.black,
                        action: {
                            if guild.isOpen {
                                Task {
                                    await joinGuild()
                                }
                            } else {
                                showJoinForm = true
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Guild Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showJoinForm) {
            JoinGuildFormView(guild: guild, onComplete: {
                Task {
                    await joinGuild()
                }
            })
            .environmentObject(rlAppState)
        }
    }

    // Join guild
    private func joinGuild() async {
        isJoining = true
        defer { isJoining = false }

        do {
            let _ = try await rlAppState.joinGuild(guildId: guild.id)
            onJoin()
        } catch is CancellationError {
            return
        } catch {
            // Error already shown by rlAppState
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.accentColor)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.gradientBackgroundDark.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Join Guild Form (for private guilds)

struct JoinGuildFormView: View {
    let guild: RLGuildDTO
    let onComplete: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Why do you want to join \(guild.name)?")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)

                TextField("Write your message...", text: $message, axis: .vertical)
                    .lineLimit(5...10)
                    .foregroundColor(AppColors.whiteText)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                            .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                    )

                Spacer()

                Button(action: {
                    onComplete()
                    dismiss()
                }) {
                    Text("Send Request")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accentColor)
                        .cornerRadius(10)
                }
                .disabled(message.isEmpty)
                .opacity(message.isEmpty ? 0.5 : 1.0)
            }
            .padding()
            .background(AppColors.gradientBackgroundDark)
            .navigationTitle("Join Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.whiteText)
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Create Guild Full Screen Flow

struct CreateGuildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove
    
    var body: some View {
        NavigationStack {
            CreateGuildView(onComplete: {
                dismiss()
            })
            .environmentObject(rlAppState)
            .environmentObject(appState)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.gradientBackgroundDark,
                        AppColors.gradientBackgroundDark,
                        AppColors.fadedBackground.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Create a Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.whiteText)
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Create Guild View

struct CreateGuildView: View {
    let onComplete: () -> Void
    
    @EnvironmentObject var rlAppState: RLAppState
    @State private var guildName: String = ""
    @State private var guildDescription: String = ""
    @State private var isOpen: Bool = true
    @State private var isCreating: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Guild name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guild Name")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    
                    TextField("Enter guild name", text: $guildName)
                        .foregroundColor(AppColors.whiteText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Guild description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    
                    TextField("Describe your guild...", text: $guildDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(AppColors.whiteText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Privacy toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open Guild")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        Text(isOpen ? "Anyone can join" : "Require approval to join")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isOpen)
                        .tint(AppColors.accentColor)
                }
                
                Spacer(minLength: 100)
                
                // Create button
                if isCreating {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Button(action: {
                        Task {
                            await createGuild()
                        }
                    }) {
                        Text("Create Guild")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.accentColor)
                            .cornerRadius(10)
                    }
                    .disabled(guildName.isEmpty)
                    .opacity(guildName.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding()
        }
    }
    
    // Create guild
    private func createGuild() async {
        isCreating = true
        defer { isCreating = false }
        
        do {
            let _ = try await rlAppState.createGuild(
                name: guildName,
                description: guildDescription.isEmpty ? nil : guildDescription,
                isOpen: isOpen
            )
            onComplete()
        } catch is CancellationError {
            return
        } catch {
            // Error already shown by rlAppState
        }
    }
}

#Preview {
    SwitchGuildView(onBack: {}, selectedDetent: .constant(.large))
        .environmentObject(RLAppState())
        .environmentObject(AppState())
}















////
////  SwitchGuildView.swift
////  traders_guild
////
////  Created by Al Hennessey on 12/10/2025.
////
////  UPDATED for flat DTOs - uses RLGuildWithMembership
////
//
//import SwiftUI
//
//// MARK: - Switch Guild Main View
//struct SwitchGuildView: View {
//    let onBack: () -> Void
//    @Binding var selectedDetent: PresentationDetent
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: remove
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    @State private var isLoading: Bool = false
//    @State private var showJoinGuild = false
//    @State private var showCreateGuild = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            VStack(alignment: .leading, spacing: 20) {
//                // Back button
//                Button(action: onBack) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                            .font(.headline)
//                        Text("Back")
//                            .font(.headline)
//                    }
//                    .foregroundColor(AppColors.whiteText)
//                }
//                .padding(.top, 20)
//                .padding(.horizontal)
//                
//                HStack(spacing: 8) {
//                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
//                        .font(.headline)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    Text("Switch Guild")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                }
//                .padding(.top, 5)
//                .padding(.horizontal)
//                
//                Divider()
//            }
//            .background(
//                LinearGradient(
//                    colors: [
//                        AppColors.gradientBackgroundDark.opacity(0.3),
//                        AppColors.sheetBackground
//                    ],
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//            )
//            
//            // Guild list
//            if isLoading {
//                VStack {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                    Text("Loading guilds...")
//                        .foregroundColor(.secondary)
//                        .padding(.top, 8)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if rlAppState.userGuilds.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "shield.slash")
//                        .font(.largeTitle)
//                        .foregroundColor(.secondary)
//                    Text("No guilds found")
//                        .foregroundColor(.secondary)
//                    Text("Join or create a guild to get started")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                ScrollView {
//                    VStack(spacing: 12) {
//                        ForEach(rlAppState.userGuilds) { item in
//                            GuildSwitchRow(
//                                item: item,
//                                isCurrentGuild: item.guild.id == rlAppState.currentGuild?.id,
//                                onSelect: {
//                                    selectGuild(item)
//                                }
//                            )
//                        }
//                    }
//                }
//                .padding(.horizontal, 25)
//                .padding(.vertical, 20)
//            }
//            
//            Divider()
//
//            HStack(spacing: 8) {
//                DrawerActionButton(
//                    title: "Join a Guild",
//                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
//                    foregroundColor: AppColors.whiteText.opacity(0.9),
//                    strokeColor: AppColors.whiteText.opacity(0.3),
//                    strokeWidth: 0.5,
//                    action: {
//                        showJoinGuild = true
//                    }
//                )
//                
//                Spacer()
//                
//                DrawerActionButton(
//                    title: "Create a Guild",
//                    backgroundColor: AppColors.whiteText.opacity(0.8),
//                    foregroundColor: Color.black,
//                    strokeColor: Color.black,
//                    strokeWidth: 0.5,
//                    action: {
//                        showCreateGuild = true
//                    }
//                )
//            }
//            .padding(.horizontal, 25)
//            .padding(.top, 20)
//            .background(AppColors.sheetBackground)
//        }
//        .task {
//            await loadUserGuilds()
//        }
//        .fullScreenCover(isPresented: $showJoinGuild) {
//            JoinGuildFlowView()
//                .environmentObject(rlAppState)
//                .environmentObject(appState)
//        }
//        .fullScreenCover(isPresented: $showCreateGuild) {
//            CreateGuildFlowView()
//                .environmentObject(rlAppState)
//                .environmentObject(appState)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .background(
//            ZStack {
//                Color.clear
//                    .background(.ultraThinMaterial)
//                AppColors.sheetBackground
//                StaticPatternView()
//            }
//        )
//    }
//    
//    // Load user's guilds
//    private func loadUserGuilds() async {
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            try await rlAppState.fetchUserGuilds()
//        } catch is CancellationError {
//            return
//        } catch {
//            print(error)
//            rlAppState.showError(error, title: "Failed to Load Guilds", style: .toast)
//        }
//    }
//    
//    // Select and switch to guild
//    private func selectGuild(_ item: RLGuildWithMembership) {
//        // Update current guild in RLAppState
//        rlAppState.selectGuild(item)
//        
//        // Clear drawer cache to force refresh for new guild
//        leftDrawerViewModel.clearCache()
//        
//        // Show success message
//        rlAppState.showSuccess("Switched to \(item.guild.name)")
//    }
//}
//
//// MARK: - Guild Switch Row (Updated for RLGuildWithMembership)
//
//struct GuildSwitchRow: View {
//    let item: RLGuildWithMembership
//    let isCurrentGuild: Bool
//    let onSelect: () -> Void
//    
//    var body: some View {
//        Button(action: {
//            // Only execute action if not current guild
//            if !isCurrentGuild {
//                onSelect()
//            }
//        }) {
//            HStack(spacing: 20) {
//                VStack(alignment: .leading, spacing: 6) {
//                    // Guild name
//                    HStack {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.title2)
//                            .foregroundColor(AppColors.accentColor.opacity(0.6))
//                        
//                        Text(item.guild.name)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        + Text(" Guild")
//                            .font(.title2)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//                    
//                    // Member count and status
//                    Text("\(item.guild.memberCount) Members - \(item.guild.statusText)")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding(.leading, 15)
//                    
//                    // Owner info (TODO: backend will return embedded owner)
//                    HStack(spacing: 3) {
//                        Text("Owner Name")  // TODO: item.guild.owner.displayName
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                            .lineLimit(1)
//                        
//                        Text("-")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        Text("Admin")  // TODO: item.guild.ownerRole.displayName
//                            .font(.caption)
//                            .foregroundColor(.red)
//                            .fontWeight(.semibold)
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//                    
//                    // Members online
//                    HStack(spacing: 3) {
//                        Circle()
//                            .fill(Color.green)
//                            .frame(width: 6, height: 6)
//                        Text("\(item.guild.membersOnline) online")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.8))
//                    }
//                    .padding(.leading, 15)
//                    
//                    // Guild reputation
//                    HStack(spacing: 2) {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text(item.guild.reputationDisplay)
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text(" Guild Reputation")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.6))
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//                    
//                    Divider()
//                    
//                    // User's role and reputation in this guild
//                    HStack(spacing: 2) {
//                        Text("You are a ")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                       
//                        Text(item.role.displayName)
//                            .font(.caption)
//                            .foregroundColor(item.role.color)
//                            .fontWeight(.semibold)
//                            .lineLimit(1)
//                        
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 3, height: 3)
//                            .padding(.top, 1)
//                            .padding(.leading, 3)
//                            .padding(.trailing, 3)
//                        
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(item.membership.reputation)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//                    .padding(.leading, 15)
//                }
//                
//                Spacer()
//                
//                // Selection indicator
//                VStack {
//                    if isCurrentGuild {
//                        Image(systemName: "checkmark.circle.fill")
//                            .foregroundColor(AppColors.accentColor)
//                            .font(.system(size: 20))
//                        
//                        Text("Current")
//                            .font(.caption2)
//                            .foregroundColor(AppColors.accentColor)
//                    } else {
//                        Image(systemName: "chevron.right")
//                            .foregroundColor(AppColors.greyText.opacity(0.6))
//                            .font(.system(size: 16))
//                    }
//                }
//            }
//            .padding(16)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(isCurrentGuild ? AppColors.accentColor.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(isCurrentGuild ? AppColors.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
//                    )
//            )
//        }
//        .buttonStyle(.plain)
//        .opacity(isCurrentGuild ? 0.8 : 1.0)
//    }
//}
//
//
//
//
//
//
//// MARK: - Join Guild Full Screen Flow
//struct JoinGuildFlowView: View {
//    @Environment(\.dismiss) private var dismiss
//    
//    @EnvironmentObject var rlAppstate: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: remove
//
//    @State private var selectedGuild: GuildDTO?
//    @State private var showGuildDetail = false
//
//    var body: some View {
//        NavigationStack {
//            JoinGuildView(
//                onSelectGuild: { guild in
//                    selectedGuild = guild
//                    showGuildDetail = true
//                }
//            )
//            .environmentObject(appState)
//            .background(
//                LinearGradient(
//                    gradient: Gradient(colors: [
//                        AppColors.gradientBackgroundDark,
//                        AppColors.gradientBackgroundDark,
//                        AppColors.fadedBackground.opacity(0.6),
//                    ]),
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//            )
//            .navigationTitle("Join a Guild")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(AppColors.whiteText)
//                }
//            }
//            .navigationDestination(isPresented: $showGuildDetail) {
//                if let guild = selectedGuild {
//                    GuildDetailView(guild: guild, onJoin: {
//                        dismiss()
//                    })
//                    .environmentObject(appState)
//                    .background(
//                        LinearGradient(
//                            gradient: Gradient(colors: [
//                                AppColors.gradientBackgroundDark,
//                                AppColors.gradientBackgroundDark,
//                                AppColors.fadedBackground.opacity(0.6)
//                            ]),
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                }
//            }
//        }
//        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
//        .toolbarColorScheme(.dark, for: .navigationBar)
//    }
//}
//
//// MARK: - Main join a guild view
//struct JoinGuildView: View {
//    let onSelectGuild: (GuildDTO) -> Void
//
//    @EnvironmentObject var appState: AppState
//    @State private var searchText: String = ""
//    @FocusState private var isSearchFocused: Bool
//    @State private var openGuilds: [GuildDTO] = []
//    @State private var isLoading: Bool = false
//
//    var filteredGuilds: [GuildDTO] {
//        if searchText.isEmpty {
//            return openGuilds
//        }
//        return openGuilds.filter { guild in
//            guild.name.localizedCaseInsensitiveContains(searchText) ||
//            guild.description.localizedCaseInsensitiveContains(searchText)
//        }
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            // Search bar with filter
//            HStack(spacing: 8) {
//                HStack {
//                    Image(systemName: "magnifyingglass")
//                        .foregroundColor(AppColors.whiteText.opacity(0.6))
//                        .font(.subheadline)
//
//                    TextField("Search guilds...", text: $searchText)
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.whiteText)
//                        .autocorrectionDisabled()
//                        .textInputAutocapitalization(.never)
//                        .submitLabel(.done)
//                        .focused($isSearchFocused)
//
//                    if !searchText.isEmpty {
//                        Button(action: { searchText = "" }) {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundColor(AppColors.whiteText.opacity(0.6))
//                                .font(.subheadline)
//                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(AppColors.whiteText.opacity(0.06))
//                .clipShape(Capsule())
//
//                Button(action: {}) {
//                    Image(systemName: "line.3.horizontal.decrease.circle")
//                        .font(.title3)
//                        .foregroundColor(AppColors.whiteText.opacity(0.8))
//                        .frame(width: 40, height: 40)
//                        .background(AppColors.whiteText.opacity(0.04))
//                        .clipShape(Circle())
//                }
//            }
//            .padding(.horizontal)
//
//            // Guild search results
//            if isLoading {
//                VStack {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                    Text("Loading guilds...")
//                        .foregroundColor(.secondary)
//                        .padding(.top, 8)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else if filteredGuilds.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "magnifyingglass")
//                        .font(.largeTitle)
//                        .foregroundColor(.secondary)
//                    Text(searchText.isEmpty ? "No open guilds available" : "No guilds found")
//                        .foregroundColor(.secondary)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                ScrollView {
//                    VStack(spacing: 20) {
//                        ForEach(filteredGuilds) { guild in
//                            JoinGuildRow(
//                                guild: guild,
//                                onTap: {
//                                    onSelectGuild(guild)
//                                }
//                            )
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//                .scrollDismissesKeyboard(.interactively)
//                .onTapGesture {
//                    isSearchFocused = false
//                    hideKeyboard()
//                }
//            }
//        }
//        .padding(.top, 10)
//        .task {
//            await loadOpenGuilds()
//        }
//    }
//
//    // ✅ Load open guilds
//    private func loadOpenGuilds() async {
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            let guilds = try await appState.fetchOpenGuilds()
//            openGuilds = guilds
//        } catch is CancellationError {
//            return
//        } catch {
//            appState.showError(error, title: "Failed to Load Guilds", style: .toast)
//        }
//    }
//
//    private func hideKeyboard() {
//        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//    }
//}
//
//// MARK: - View for guild row in searching for guild
//struct JoinGuildRow: View {
//    let guild: GuildDTO
//    let onTap: () -> Void
//
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 20) {
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.title2)
//                            .foregroundColor(AppColors.accentColor.opacity(0.6))
//
//                        Text(guild.name)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//
//                    Text("\(guild.memberCount) Members • \(guild.isOpen ? "Open" : "Private")")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding(.leading, 15)
//
//                    HStack(spacing: 3) {
//                        Text(guild.owner.username)
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                            .lineLimit(1)
//
//                        Text("-")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//
//                        Text(guild.ownerRole.rawValue)
//                            .font(.caption)
//                            .foregroundColor(guild.ownerRole.roleForegroundColor)
//                            .fontWeight(guild.ownerRole.roleFontWeight)
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//
//                    HStack(spacing: 2) {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(guild.reputation)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text(" Guild Reputation")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.6))
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//                }
//
//                Spacer()
//
//                Image(systemName: "chevron.right")
//                    .font(.headline)
//                    .foregroundColor(AppColors.whiteText.opacity(0.5))
//            }
//            .padding(.top, 10)
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//// MARK: - Guild Detail View (for joining)
//struct GuildDetailView: View {
//    let guild: GuildDTO
//    let onJoin: () -> Void
//
//    @EnvironmentObject var appState: AppState
//    @State private var showJoinForm = false
//    @State private var isJoining = false
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Guild header
//                VStack(alignment: .leading, spacing: 10) {
//                    HStack {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.largeTitle)
//                            .foregroundColor(AppColors.accentColor)
//
//                        VStack(alignment: .leading) {
//                            Text(guild.name)
//                                .font(.title)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.whiteText)
//
//                            Text("\(guild.memberCount) Members")
//                                .font(.subheadline)
//                                .foregroundColor(AppColors.greyText)
//                        }
//                    }
//
//                    Text(guild.description)
//                        .font(.body)
//                        .foregroundColor(AppColors.whiteText.opacity(0.8))
//                        .padding(.top, 8)
//                }
//                .padding()
//                .background(AppColors.whiteText.opacity(0.05))
//                .cornerRadius(10)
//
//                // Guild stats
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("Guild Stats")
//                        .font(.headline)
//                        .foregroundColor(AppColors.whiteText)
//
//                    HStack {
//                        StatBox(label: "Reputation", value: "\(guild.reputation)")
//                        StatBox(label: "Accuracy", value: "\(guild.accuracy)%")
//                        StatBox(label: "Members", value: "\(guild.memberCount)")
//                    }
//                }
//                .padding()
//                .background(AppColors.whiteText.opacity(0.05))
//                .cornerRadius(10)
//
//                Spacer(minLength: 20)
//
//                // Join button
//                if isJoining {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                } else {
//                    StandardActionButtonFullWidth(
//                        title: guild.isOpen ? "Join Guild" : "Request to Join",
//                        backgroundColor: AppColors.whiteText,
//                        foregroundColor: Color.black,
//                        action: {
//                            if guild.isOpen {
//                                Task {
//                                    await joinGuild()
//                                }
//                            } else {
//                                showJoinForm = true
//                            }
//                        }
//                    )
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Guild Details")
//        .navigationBarTitleDisplayMode(.inline)
//        .sheet(isPresented: $showJoinForm) {
//            JoinGuildFormView(guild: guild, onComplete: {
//                Task {
//                    await joinGuild()
//                }
//            })
//            .environmentObject(appState)
//
//        }
//    }
//
//    // ✅ Join guild
//    private func joinGuild() async {
//        isJoining = true
//        defer { isJoining = false }
//
//        do {
//            try await appState.joinGuild(guildId: guild.id)
//            appState.showSuccess("Successfully joined \(guild.name)!")
//            onJoin()
//        } catch is CancellationError {
//            return
//        } catch {
//            appState.showError(error, title: "Failed to Join Guild")
//        }
//    }
//}
//
//struct StatBox: View {
//    let label: String
//    let value: String
//
//    var body: some View {
//        VStack(spacing: 4) {
//            Text(value)
//                .font(.title3)
//                .fontWeight(.bold)
//                .foregroundColor(AppColors.accentColor)
//            Text(label)
//                .font(.caption)
//                .foregroundColor(AppColors.greyText)
//        }
//        .frame(maxWidth: .infinity)
//        .padding()
//        .background(AppColors.gradientBackgroundDark.opacity(0.3))
//        .cornerRadius(8)
//    }
//}
//
//// MARK: - Join Guild Form
//struct JoinGuildFormView: View {
//    let guild: GuildDTO
//    let onComplete: () -> Void
//
//    @EnvironmentObject var appState: AppState
//    @Environment(\.dismiss) private var dismiss
//    @State private var message: String = ""
//
//    var body: some View {
//        NavigationStack {
//            VStack(alignment: .leading, spacing: 20) {
//                Text("Why do you want to join \(guild.name)?")
//                    .font(.headline)
//                    .foregroundColor(AppColors.whiteText)
//
//                TextField("Write your message...", text: $message, axis: .vertical)
//                    .lineLimit(5...10)
//                    .foregroundColor(AppColors.whiteText)
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 10)
//                            .fill(AppColors.gradientBackgroundDark.opacity(0.3))
//                            .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
//                    )
//
//                Spacer()
//
//                Button(action: {
//                    onComplete()
//                    dismiss()
//                }) {
//                    Text("Send Request")
//                        .font(.headline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.black)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(AppColors.accentColor)
//                        .cornerRadius(10)
//                }
//                .disabled(message.isEmpty)
//                .opacity(message.isEmpty ? 0.5 : 1.0)
//            }
//            .padding()
//            .background(AppColors.gradientBackgroundDark)
//            .navigationTitle("Join Request")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(AppColors.whiteText)
//                }
//            }
//        }
//        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
//        .toolbarColorScheme(.dark, for: .navigationBar)
//    }
//}
//
//// MARK: - Create Guild Full Screen Flow
//struct CreateGuildFlowView: View {
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var appState: AppState
//
//    var body: some View {
//        NavigationStack {
//            CreateGuildView(onComplete: {
//                dismiss()
//            })
//            .environmentObject(appState)
//
//            .background(
//                LinearGradient(
//                    gradient: Gradient(colors: [
//                        AppColors.gradientBackgroundDark,
//                        AppColors.gradientBackgroundDark,
//                        AppColors.fadedBackground.opacity(0.6)
//                    ]),
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//            )
//            .navigationTitle("Create a Guild")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(AppColors.whiteText)
//                }
//            }
//        }
//        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
//        .toolbarColorScheme(.dark, for: .navigationBar)
//    }
//}
//
//struct CreateGuildView: View {
//    let onComplete: () -> Void
//
//    @EnvironmentObject var appState: AppState
//    @State private var guildName: String = ""
//    @State private var guildDescription: String = ""
//    @State private var isPrivate: Bool = false
//    @State private var isCreating: Bool = false
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Guild name
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Guild Name")
//                        .font(.headline)
//                        .foregroundColor(AppColors.whiteText)
//
//                    TextField("Enter guild name", text: $guildName)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding()
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(AppColors.gradientBackgroundDark.opacity(0.3))
//                                .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
//                        )
//                }
//
//                // Guild description
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Description")
//                        .font(.headline)
//                        .foregroundColor(AppColors.whiteText)
//
//                    TextField("Describe your guild...", text: $guildDescription, axis: .vertical)
//                        .lineLimit(3...6)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding()
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(AppColors.gradientBackgroundDark.opacity(0.3))
//                                .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
//                        )
//                }
//
//                // Privacy toggle
//                HStack {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Private Guild")
//                            .font(.headline)
//                            .foregroundColor(AppColors.whiteText)
//                        Text("Require approval to join")
//                            .font(.caption)
//                            .foregroundColor(AppColors.greyText)
//                    }
//
//                    Spacer()
//
//                    Toggle("", isOn: $isPrivate)
//                        .tint(AppColors.accentColor)
//                }
//
//                Spacer(minLength: 100)
//
//                // Create button
//                if isCreating {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                } else {
//                    Button(action: {
//                        Task {
//                            await createGuild()
//                        }
//                    }) {
//                        Text("Create Guild")
//                            .font(.headline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(.black)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(AppColors.accentColor)
//                            .cornerRadius(10)
//                    }
//                    .disabled(guildName.isEmpty)
//                    .opacity(guildName.isEmpty ? 0.5 : 1.0)
//                }
//            }
//            .padding()
//        }
//    }
//
//    // ✅ Create guild (placeholder - needs API implementation)
//    private func createGuild() async {
//        isCreating = true
//        defer { isCreating = false }
//
//        // TODO: Implement guild creation API
//        appState.showSuccess("Guild creation coming soon!")
//        onComplete()
//
//        // When API is ready:
//        // do {
//        //     try await appState.createGuild(name: guildName, description: guildDescription, isPrivate: isPrivate)
//        //     appState.showSuccess("Guild created successfully!")
//        //     onComplete()
//        // } catch {
//        //     appState.showError(error, title: "Failed to Create Guild")
//        // }
//    }
//}
//
//
//
//#Preview {
//    SwitchGuildView(onBack: {}, selectedDetent: .constant(.large))
//        .environmentObject(RLAppState())
//        .environmentObject(AppState())
//}
//


