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
        }
        .fullScreenCover(isPresented: $showCreateGuild) {
            CreateGuildFlowView()
                .environmentObject(rlAppState)
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
                    
                    // Owner info
                    HStack(spacing: 3) {
                        Text(item.guild.ownerDisplayName ?? item.guild.ownerUsername ?? "Unknown Owner")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text("Owner")
                            .font(.caption)
                            .foregroundColor(AppColors.accentColor)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)

                    if item.guild.language != nil || item.guild.location != nil {
                        HStack(spacing: 6) {
                            if let language = item.guild.language, !language.isEmpty {
                                Text(language)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.75))
                            }
                            if let location = item.guild.location, !location.isEmpty {
                                Text("• \(location)")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.75))
                            }
                        }
                        .padding(.leading, 15)
                    }
                    
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
                    
                    // User's role · reputation · accuracy in this guild
                    HStack(spacing: 4) {
                        Text("You are a ")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        UnifiedRoleBadge(
                            roleName: item.role.displayName,
                            roleColor: item.role.color,
                            reputation: item.membership.reputation,
                            accuracy: item.membership.accuracyFormatted,
                            showReputation: true,
                            fontSize: .caption,
                            iconSize: .caption2
                        )
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

    enum AccessFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case closed = "Closed"

        var id: String { rawValue }

        var isOpenValue: Bool? {
            switch self {
            case .all: return nil
            case .open: return true
            case .closed: return false
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case popular = "Popular"
        case newest = "Newest"
        case name = "Name"

        var id: String { rawValue }
        var backendValue: String {
            switch self {
            case .popular: return "popular"
            case .newest: return "newest"
            case .name: return "name"
            }
        }
    }

    @EnvironmentObject var rlAppState: RLAppState
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var openGuilds: [RLGuildDTO] = []
    @State private var isLoading: Bool = false
    @State private var showFilters: Bool = false
    @State private var selectedAccess: AccessFilter = .all
    @State private var selectedSort: SortOption = .popular
    @State private var languageFilter: String = ""
    @State private var locationFilter: String = ""

    var filteredGuilds: [RLGuildDTO] {
        openGuilds
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
                        .onSubmit {
                            Task { await loadOpenGuilds() }
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            Task { await loadOpenGuilds() }
                        }) {
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

                Button(action: { showFilters = true }) {
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
        .sheet(isPresented: $showFilters) {
            JoinGuildFilterSheet(
                selectedAccess: $selectedAccess,
                selectedSort: $selectedSort,
                languageFilter: $languageFilter,
                locationFilter: $locationFilter,
                onApply: {
                    Task { await loadOpenGuilds() }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // Load open guilds
    private func loadOpenGuilds() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let guilds = try await rlAppState.fetchJoinableGuilds(
                search: searchText.isEmpty ? nil : searchText,
                isOpen: selectedAccess.isOpenValue,
                language: languageFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : languageFilter,
                location: locationFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationFilter,
                sort: selectedSort.backendValue
            )
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

struct JoinGuildFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccess: JoinGuildView.AccessFilter
    @Binding var selectedSort: JoinGuildView.SortOption
    @Binding var languageFilter: String
    @Binding var locationFilter: String
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Access", selection: $selectedAccess) {
                    ForEach(JoinGuildView.AccessFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }

                Picker("Sort", selection: $selectedSort) {
                    ForEach(JoinGuildView.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }

                TextField("Language", text: $languageFilter)
                TextField("Location", text: $locationFilter)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        selectedAccess = .all
                        selectedSort = .popular
                        languageFilter = ""
                        locationFilter = ""
                        onApply()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
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

                    // Owner info
                    HStack(spacing: 3) {
                        Text(guild.ownerDisplayName ?? guild.ownerUsername ?? "Unknown Owner")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)

                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)

                        Text("Owner")
                            .font(.caption)
                            .foregroundColor(AppColors.accentColor)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)

                    if guild.language != nil || guild.location != nil {
                        HStack(spacing: 6) {
                            if let language = guild.language, !language.isEmpty {
                                Text(language)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.75))
                            }
                            if let location = guild.location, !location.isEmpty {
                                Text("• \(location)")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.75))
                            }
                        }
                        .padding(.leading, 15)
                    }

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
    @State private var joinQuestions: [RLGuildJoinQuestionDTO] = []

    private var ownerName: String {
        guild.ownerDisplayName ?? guild.ownerUsername ?? "Owner unavailable"
    }

    private var accessLabel: String {
        guild.isOpen ? "Open Access" : "Private Approval"
    }

    private var joinRequirementText: String {
        if guild.isOpen {
            return "Anyone can join immediately."
        }
        if joinQuestions.isEmpty {
            return "Approval is required to join."
        }
        return "Approval is required and \(joinQuestions.count) application question\(joinQuestions.count == 1 ? "" : "s") must be completed."
    }

    private var createdDateText: String {
        guild.dateCreated.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.title3)
                                .foregroundColor(AppColors.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(guild.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)

                            HStack(spacing: 8) {
                                Text(accessLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppColors.accentColor.opacity(0.18))
                                    .foregroundColor(AppColors.accentColor)
                                    .clipShape(Capsule())

                                Text("Created \(createdDateText)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                            }
                        }
                    }

                    if let description = guild.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.85))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.whiteText.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Guild Snapshot")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    HStack(spacing: 10) {
                        StatBox(label: "Members", value: "\(guild.memberCount)")
                        StatBox(label: "Online", value: "\(guild.membersOnline)")
                    }
                    HStack(spacing: 10) {
                        StatBox(label: "Reputation", value: guild.reputationDisplay)
                        StatBox(label: "Type", value: guild.isOpen ? "Open" : "Private")
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.whiteText.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Guild Information")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    GuildInfoRow(icon: "person.crop.circle", title: "Owner", value: ownerName)
                    GuildInfoRow(icon: "globe", title: "Language", value: displayValue(guild.language))
                    GuildInfoRow(icon: "mappin.and.ellipse", title: "Location", value: displayValue(guild.location))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.whiteText.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Join Requirements")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    Text(joinRequirementText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.82))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.gradientBackgroundDark.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.accentColor.opacity(0.25), lineWidth: 1)
                        )
                )

                if isJoining {
                    ProgressView()
                        .scaleEffect(1.1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                } else {
                    StandardActionButtonFullWidth(
                        title: guild.isOpen ? "Join Guild" : "Request to Join",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: Color.black,
                        action: {
                            if guild.isOpen {
                                Task { await joinGuild() }
                            } else {
                                showJoinForm = true
                            }
                        }
                    )
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Guild Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showJoinForm) {
            JoinGuildFormView(guild: guild, questions: joinQuestions, onComplete: {
                onJoin()
            })
            .environmentObject(rlAppState)
        }
        .task {
            if !guild.isOpen {
                await loadJoinQuestions()
            }
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

    private func loadJoinQuestions() async {
        do {
            joinQuestions = try await rlAppState.getGuildJoinQuestions(guildId: guild.id)
        } catch is CancellationError {
            return
        } catch {
            joinQuestions = []
        }
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Not specified"
        }
        return value
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

struct GuildInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.accentColor.opacity(0.85))
                .frame(width: 18)
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.75))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Join Guild Form (for private guilds)

struct JoinGuildFormView: View {
    let guild: RLGuildDTO
    let questions: [RLGuildJoinQuestionDTO]
    let onComplete: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var answers: [UUID: String] = [:]
    @State private var isSubmitting: Bool = false

    private var canSubmit: Bool {
        !questions.contains { question in
            if !question.isRequired {
                return false
            }
            return (answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Application for \(guild.name)")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    ForEach(questions) { question in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(question.prompt)
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                            if question.isRequired {
                                Text("Required")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.accentColor)
                            }

                            TextField("Your answer...", text: Binding(
                                get: { answers[question.id] ?? "" },
                                set: { answers[question.id] = $0 }
                            ), axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(AppColors.whiteText)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                    .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Optional note")
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        TextField("Anything else you'd like to add?", text: $message, axis: .vertical)
                            .lineLimit(3...8)
                            .foregroundColor(AppColors.whiteText)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                    .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                            )
                    }

                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    } else {
                        Button(action: {
                            Task { await submitRequest() }
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
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1.0 : 0.5)
                    }
                }
                .padding()
            }
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

    private func submitRequest() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let answerPayload: [RLGuildJoinRequestAnswerInputDTO] = questions.compactMap { question in
            let value = (answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { return nil }
            return RLGuildJoinRequestAnswerInputDTO(questionId: question.id, answerText: value)
        }

        do {
            _ = try await rlAppState.submitGuildJoinRequest(
                guildId: guild.id,
                note: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message,
                answers: answerPayload
            )
            onComplete()
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }
}

// MARK: - Create Guild Full Screen Flow

struct CreateGuildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    
    var body: some View {
        NavigationStack {
            CreateGuildView(onComplete: {
                dismiss()
            })
            .environmentObject(rlAppState)
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
    @State private var language: String = ""
    @State private var location: String = ""
    @State private var joinQuestions: [String] = [""]
    
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Language")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    TextField("e.g. English", text: $language)
                        .foregroundColor(AppColors.whiteText)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    TextField("e.g. London", text: $location)
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

                if !isOpen {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Join Questions")
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)
                            Spacer()
                            Text("Max 3")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }

                        ForEach(joinQuestions.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("Question \(index + 1)", text: $joinQuestions[index], axis: .vertical)
                                    .lineLimit(2...4)
                                    .foregroundColor(AppColors.whiteText)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                            .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                                    )

                                if joinQuestions.count > 1 {
                                    Button {
                                        joinQuestions.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                }
                            }
                        }

                        if joinQuestions.count < 3 {
                            Button {
                                joinQuestions.append("")
                            } label: {
                                Label("Add Question", systemImage: "plus.circle")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.accentColor)
                            }
                        }
                    }
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
                isOpen: isOpen,
                language: language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : language,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
                joinQuestions: isOpen ? [] : joinQuestions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .enumerated()
                    .map { index, prompt in
                        RLGuildJoinQuestionInputDTO(prompt: prompt, isRequired: true, displayOrder: index)
                    }
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
}



