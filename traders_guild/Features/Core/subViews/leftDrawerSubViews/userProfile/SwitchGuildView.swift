//
//  SwitchGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
//  UPDATED for flat DTOs - uses RLGuildWithMembership
//

import SwiftUI

// MARK: - Shared Guild Background
private struct GuildFlowBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            StaticPatternView()
                .opacity(AppColors.guildFlowPatternOpacityScale)
        }
        .ignoresSafeArea()
    }
}

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
            VStack(alignment: .leading, spacing: 10) {
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

                HStack(spacing: 10) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch Guild")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.whiteText)
                        Text("Choose your active community")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                Divider().opacity(0.8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
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

            Text("Guild actions")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)
                .padding(.top, 10)

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
                    backgroundColor: ThemeManager.shared.currentTheme == .lightGrey
                        ? AppColors.standardSearchFieldFill
                        : AppColors.whiteText.opacity(0.8),
                    foregroundColor: ThemeManager.shared.currentTheme == .lightGrey
                        ? AppColors.primaryForeground
                        : AppColors.systemBlack,
                    strokeColor: ThemeManager.shared.currentTheme == .lightGrey
                        ? AppColors.standardSearchFieldStroke
                        : AppColors.systemBlack,
                    strokeWidth: 0.5,
                    action: {
                        showCreateGuild = true
                    }
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 6)
            .padding(.bottom, 14)
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
                    .opacity(AppColors.guildFlowPatternOpacityScale)
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
                            .fill(AppColors.statusPositive)
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
                    .fill(
                        isCurrentGuild
                            ? AppColors.accentColor.opacity(CGFloat(AppColors.guildSwitchRowSelectedFillOpacity))
                            : AppColors.gradientBackgroundDark.opacity(0.42)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrentGuild
                                    ? AppColors.accentColor.opacity(CGFloat(AppColors.guildSwitchRowSelectedStrokeOpacity))
                                    : AppColors.whiteText.opacity(0.16),
                                lineWidth: 1
                            )
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
                onCancel: { dismiss() },
                onSelectGuild: { guild in
                    selectedGuild = guild
                    showGuildDetail = true
                }
            )
            .environmentObject(rlAppState)
            .navigationDestination(isPresented: $showGuildDetail) {
                if let guild = selectedGuild {
                    GuildDetailView(guild: guild, onJoin: {
                        dismiss()
                    })
                    .environmentObject(rlAppState)
                }
            }
        }
    }
}

// MARK: - Main Join Guild View (Search/List)

struct JoinGuildView: View {
    let onCancel: () -> Void
    let onSelectGuild: (RLGuildDTO) -> Void

    struct DiscoverGuildItem: Identifiable {
        let guild: RLGuildDTO
        let isJoined: Bool

        var id: UUID { guild.id }
    }

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
    @State private var discoverGuilds: [DiscoverGuildItem] = []
    @State private var isLoading: Bool = false
    @State private var showFilters: Bool = false
    @State private var selectedAccess: AccessFilter = .all
    @State private var selectedSort: SortOption = .popular
    @State private var languageFilter: String = ""
    @State private var locationFilter: String = ""
    @State private var hasLoadedMemberships: Bool = false

    var filteredGuilds: [DiscoverGuildItem] {
        discoverGuilds
    }

    private var activeFilterBadges: [String] {
        var badges: [String] = []
        if selectedAccess != .all {
            badges.append(selectedAccess.rawValue)
        }
        if !languageFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            badges.append("Language")
        }
        if !locationFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            badges.append("Location")
        }
        return badges
    }

    var body: some View {
        ZStack {
            GuildFlowBackground()

            VStack(alignment: .leading, spacing: 0) {
                GuildFlowTitleHeader(
                    title: "Discover Guilds",
                    subtitle: "Find your trading community",
                    icon: "safari.fill",
                    onBack: onCancel
                )

                // Search bar with filter
                VStack(alignment: .leading, spacing: 10) {
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
                        .background(
                            ThemeManager.shared.currentTheme == .lightGrey
                                ? AppColors.standardSearchFieldFill
                                : AppColors.unhighlightedTextBoxBackground.opacity(0.92)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    ThemeManager.shared.currentTheme == .lightGrey
                                        ? AppColors.standardSearchFieldStroke
                                        : AppColors.whiteText.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(Capsule())

                        Button(action: { showFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(AppColors.whiteText.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .background(
                                    ThemeManager.shared.currentTheme == .lightGrey
                                        ? AppColors.standardSearchFieldFill
                                        : AppColors.unhighlightedTextBoxBackground.opacity(0.92)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            ThemeManager.shared.currentTheme == .lightGrey
                                                ? AppColors.standardSearchFieldStroke
                                                : AppColors.whiteText.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(Circle())
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(filteredGuilds.count) results", systemImage: "person.3.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.whiteText.opacity(0.78))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(AppColors.whiteText.opacity(0.12))
                            )

                        ForEach(activeFilterBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2)
                                .foregroundColor(AppColors.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(AppColors.accentColor.opacity(0.17))
                                )
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

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
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.06))
                                .frame(width: 72, height: 72)
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.greyText)
                        }

                        Text(searchText.isEmpty ? "No guilds available" : "No guilds found")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Text(searchText.isEmpty
                            ? "Check back later or try adjusting your filters."
                            : "Try a different search term or adjust your filters.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(filteredGuilds) { guild in
                                JoinGuildRow(
                                    guild: guild.guild,
                                    isJoined: guild.isJoined,
                                    onTap: {
                                        onSelectGuild(guild.guild)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        isSearchFocused = false
                        hideKeyboard()
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
            if !hasLoadedMemberships {
                try? await rlAppState.fetchUserGuilds()
                hasLoadedMemberships = true
            }

            let guilds = try await rlAppState.fetchJoinableGuilds(
                search: searchText.isEmpty ? nil : searchText,
                isOpen: selectedAccess.isOpenValue,
                language: languageFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : languageFilter,
                location: locationFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationFilter,
                sort: selectedSort.backendValue
            )

            let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let joinedGuilds = rlAppState.userGuilds
                .map(\.guild)
                .filter { guild in
                    guildMatchesFilters(guild, normalizedSearch: normalizedSearch)
                }

            var merged: [UUID: DiscoverGuildItem] = [:]
            for guild in guilds {
                merged[guild.id] = DiscoverGuildItem(guild: guild, isJoined: false)
            }
            for guild in joinedGuilds {
                merged[guild.id] = DiscoverGuildItem(guild: guild, isJoined: true)
            }

            discoverGuilds = sortGuilds(Array(merged.values))
        } catch is CancellationError {
            return
        } catch {
            rlAppState.showError(error, title: "Failed to Load Guilds", style: .toast)
        }
    }

    private func guildMatchesFilters(_ guild: RLGuildDTO, normalizedSearch: String) -> Bool {
        if let isOpen = selectedAccess.isOpenValue, guild.isOpen != isOpen {
            return false
        }

        let language = languageFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty {
            let guildLanguage = guild.language ?? ""
            if !guildLanguage.localizedCaseInsensitiveContains(language) {
                return false
            }
        }

        let location = locationFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty {
            let guildLocation = guild.location ?? ""
            if !guildLocation.localizedCaseInsensitiveContains(location) {
                return false
            }
        }

        if !normalizedSearch.isEmpty {
            let nameMatches = guild.name.localizedCaseInsensitiveContains(normalizedSearch)
            let descriptionMatches = (guild.description ?? "").localizedCaseInsensitiveContains(normalizedSearch)
            if !nameMatches && !descriptionMatches {
                return false
            }
        }

        return guild.isActive
    }

    private func sortGuilds(_ guilds: [DiscoverGuildItem]) -> [DiscoverGuildItem] {
        switch selectedSort {
        case .name:
            return guilds.sorted {
                $0.guild.name.localizedCaseInsensitiveCompare($1.guild.name) == .orderedAscending
            }
        case .newest:
            return guilds.sorted {
                $0.guild.dateCreated > $1.guild.dateCreated
            }
        case .popular:
            return guilds.sorted {
                if $0.guild.memberCount != $1.guild.memberCount {
                    return $0.guild.memberCount > $1.guild.memberCount
                }
                if $0.guild.reputation != $1.guild.reputation {
                    return $0.guild.reputation > $1.guild.reputation
                }
                return $0.guild.dateCreated > $1.guild.dateCreated
            }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Access filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Access")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        HStack(spacing: 8) {
                            ForEach(JoinGuildView.AccessFilter.allCases) { option in
                                Button {
                                    selectedAccess = option
                                } label: {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(selectedAccess == option ? AppColors.gradientBackgroundDark : AppColors.whiteText)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(selectedAccess == option ? AppColors.whiteText : AppColors.whiteText.opacity(0.08))
                                        )
                                }
                            }
                        }
                    }

                    // Sort option
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sort By")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        HStack(spacing: 8) {
                            ForEach(JoinGuildView.SortOption.allCases) { option in
                                Button {
                                    selectedSort = option
                                } label: {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(selectedSort == option ? AppColors.gradientBackgroundDark : AppColors.whiteText)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(selectedSort == option ? AppColors.whiteText : AppColors.whiteText.opacity(0.08))
                                        )
                                }
                            }
                        }
                    }

                    // Language & Location
                    StandardTextFieldView(title: "Language", text: $languageFilter)
                    StandardTextFieldView(title: "Location", text: $locationFilter)
                }
                .padding()
            }
            .background(AppColors.sheetBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
            .toolbarColorScheme(ThemeManager.shared.currentTheme.colorScheme, for: .navigationBar)
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
                    .foregroundColor(AppColors.greyText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(AppColors.whiteText)
                }
            }
        }
    }
}

private struct GuildFlowTitleHeader: View {
    let title: String
    let subtitle: String
    var icon: String = "shield.lefthalf.filled"
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }

            Divider().opacity(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
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
}

// MARK: - Join Guild Row

struct JoinGuildRow: View {
    let guild: RLGuildDTO
    let isJoined: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shield.pattern.checkered")
                        .font(.title3)
                        .foregroundColor(AppColors.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Guild name + access badge
                    HStack(spacing: 8) {
                        Text(guild.name)
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)

                        Text(guild.isOpen ? "Open" : "Private")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(guild.isOpen ? AppColors.accentColor : AppColors.whiteText.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(guild.isOpen ? AppColors.accentColor.opacity(0.18) : AppColors.whiteText.opacity(0.08))
                            )

                        if isJoined {
                            Text("Joined")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.bullCandleGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(AppColors.bullCandleGreen.opacity(0.16))
                                )
                        }
                    }

                    // Description
                    if let description = guild.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .lineLimit(2)
                    }

                    // Compact stat row
                    HStack(spacing: 6) {
                        Text("\(guild.memberCount) members")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.7))

                        Circle()
                            .fill(AppColors.whiteText.opacity(0.3))
                            .frame(width: 3, height: 3)

                        HStack(spacing: 3) {
                            Circle()
                                .fill(AppColors.statusPositive)
                                .frame(width: 6, height: 6)
                            Text("\(guild.membersOnline) online")
                                .font(.caption)
                                .foregroundColor(AppColors.whiteText.opacity(0.7))
                        }

                        Circle()
                            .fill(AppColors.whiteText.opacity(0.3))
                            .frame(width: 3, height: 3)

                        HStack(spacing: 2) {
                            Image(systemName: "shield.pattern.checkered")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentColor)
                            Text(guild.reputationDisplay)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Guild Detail View (for joining)

struct GuildDetailView: View {
    let guild: RLGuildDTO
    let onJoin: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @Environment(\.dismiss) private var dismiss
    @State private var showJoinForm = false
    @State private var isJoining = false
    @State private var joinQuestions: [RLGuildJoinQuestionDTO] = []
    @State private var visibleSections: Set<Int> = []

    private var joinedGuildEntry: RLGuildWithMembership? {
        rlAppState.userGuilds.first(where: { $0.guild.id == guild.id })
    }

    private var isAlreadyJoined: Bool {
        joinedGuildEntry != nil
    }

    private var isCurrentGuild: Bool {
        rlAppState.currentGuild?.id == guild.id
    }

    private var ownerName: String {
        guild.ownerDisplayName ?? guild.ownerUsername ?? "Owner unavailable"
    }

    private var accessLabel: String {
        guild.isOpen ? "Open Access" : "Private Approval"
    }

    private var joinRequirementText: String {
        if isAlreadyJoined {
            return isCurrentGuild ? "You are currently active in this guild." : "You are already a member of this guild."
        }
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

    // Section card helper
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
    }

    var body: some View {
        ZStack {
            GuildFlowBackground()

            VStack(spacing: 0) {
                GuildFlowTitleHeader(
                    title: guild.name,
                    subtitle: "Guild details and entry requirements",
                    icon: "shield.pattern.checkered",
                    onBack: { dismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                        GuildMetaChip(label: "Members", value: "\(guild.memberCount)")
                        GuildMetaChip(label: "Online", value: "\(guild.membersOnline)")
                        GuildMetaChip(label: "Rep", value: guild.reputationDisplay)
                    }
                    .opacity(visibleSections.contains(0) ? 1 : 0)
                    .offset(y: visibleSections.contains(0) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.0), value: visibleSections.contains(0))

                    // Guild header card
                    sectionCard {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accentColor.opacity(0.12))
                                    .frame(width: 48, height: 48)
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
                    .opacity(visibleSections.contains(1) ? 1 : 0)
                    .offset(y: visibleSections.contains(1) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: visibleSections.contains(1))

                    // Guild Snapshot card
                    sectionCard {
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
                    .opacity(visibleSections.contains(2) ? 1 : 0)
                    .offset(y: visibleSections.contains(2) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: visibleSections.contains(2))

                    // Guild Information card
                    sectionCard {
                        Text("Guild Information")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        GuildInfoRow(icon: "person.crop.circle", title: "Owner", value: ownerName)
                        GuildInfoRow(icon: "globe", title: "Language", value: displayValue(guild.language))
                        GuildInfoRow(icon: "mappin.and.ellipse", title: "Location", value: displayValue(guild.location))
                    }
                    .opacity(visibleSections.contains(3) ? 1 : 0)
                    .offset(y: visibleSections.contains(3) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15), value: visibleSections.contains(3))

                    // Join Requirements card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join Requirements")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Text(joinRequirementText)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.82))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.accentColor.opacity(0.32), lineWidth: 1)
                            )
                    )
                    .opacity(visibleSections.contains(4) ? 1 : 0)
                    .offset(y: visibleSections.contains(4) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2), value: visibleSections.contains(4))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
                .onAppear {
                    for i in 0...4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.08) {
                            visibleSections.insert(i)
                        }
                    }
                }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                if isJoining {
                    ProgressView()
                        .scaleEffect(1.1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if isAlreadyJoined {
                    StandardActionButtonFullWidth(
                        title: isCurrentGuild ? "Current Guild" : "Switch to Guild",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.systemBlack,
                        action: switchToGuild
                    )
                    .disabled(isCurrentGuild)
                    .opacity(isCurrentGuild ? 0.55 : 1.0)
                } else {
                    StandardActionButtonFullWidth(
                        title: guild.isOpen ? "Join Guild" : "Request to Join",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.systemBlack,
                        action: {
                            if guild.isOpen {
                                Task { await joinGuild() }
                            } else {
                                showJoinForm = true
                            }
                        }
                    )
                }
            }
            .background(AppColors.sheetBackground)
        }
        .sheet(isPresented: $showJoinForm) {
            JoinGuildFormView(guild: guild, questions: joinQuestions, onComplete: {
                onJoin()
            })
            .environmentObject(rlAppState)
        }
        .task {
            if !guild.isOpen && !isAlreadyJoined {
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

    private func switchToGuild() {
        guard let entry = joinedGuildEntry, !isCurrentGuild else {
            return
        }
        rlAppState.selectGuild(entry)
        onJoin()
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

private struct GuildMetaChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.whiteText)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.gradientBackgroundDark.opacity(0.34))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.gradientBackgroundDark.opacity(0.34))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
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
            ZStack {
                GuildFlowBackground()

                VStack(spacing: 0) {
                    GuildFlowTitleHeader(
                        title: "Join Request",
                        subtitle: "Application for \(guild.name)",
                        onBack: { dismiss() }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Application Questions card
                        if !questions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Application Questions")
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)

                                ForEach(questions) { question in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Text(question.prompt)
                                                .font(.subheadline)
                                                .foregroundColor(AppColors.whiteText)

                                            if question.isRequired {
                                                Text("Required")
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(AppColors.accentColor)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule().fill(AppColors.accentColor.opacity(0.15))
                                                    )
                                            }
                                        }

                                        TextField("Your answer...", text: Binding(
                                            get: { answers[question.id] ?? "" },
                                            set: { answers[question.id] = $0 }
                                        ), axis: .vertical)
                                        .lineLimit(3...6)
                                        .foregroundColor(AppColors.whiteText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                                    )
                            )
                        }

                        // Additional Note card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Additional Note")
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)

                            Text("Optional - add anything else you'd like the guild owner to know.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            TextEditor(text: $message)
                                .frame(minHeight: 80)
                                .padding(8)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                                )
                        )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toolbarColorScheme(ThemeManager.shared.currentTheme.colorScheme, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(1.1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.sheetBackground)
                } else {
                    StandardActionButtonFullWidth(
                        title: "Send Request",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.systemBlack,
                        action: {
                            Task { await submitRequest() }
                        }
                    )
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1.0 : 0.5)
                    .background(AppColors.sheetBackground)
                }
            }
        }
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
            CreateGuildView(
                onCancel: { dismiss() },
                onComplete: { dismiss() }
            )
            .environmentObject(rlAppState)
        }
    }
}

// MARK: - Create Guild View

struct CreateGuildView: View {
    let onCancel: () -> Void
    let onComplete: () -> Void

    @EnvironmentObject var rlAppState: RLAppState
    @State private var guildName: String = ""
    @State private var guildDescription: String = ""
    @State private var isOpen: Bool = true
    @State private var isCreating: Bool = false
    @State private var selectedLanguageCode: String = ""
    @State private var selectedCountryCode: String = ""
    @State private var initialAnnouncementTitle: String = ""
    @State private var initialAnnouncementContent: String = ""
    @State private var initialAnnouncementImportant: Bool = true
    @State private var joinQuestions: [String] = [""]
    @State private var visibleSections: Set<Int> = []

    private var canCreateGuild: Bool {
        let name = guildName.trimmingCharacters(in: .whitespacesAndNewlines)
        let announcementTitle = initialAnnouncementTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let announcementContent = initialAnnouncementContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !announcementTitle.isEmpty && !announcementContent.isEmpty
    }

    private var selectedLanguageLabel: String {
        LocaleOptionCatalog.languages.first(where: { $0.code == selectedLanguageCode })?.label ?? "Select language"
    }

    private var selectedCountryLabel: String {
        LocaleOptionCatalog.countries.first(where: { $0.code == selectedCountryCode })?.label ?? "Select country"
    }

    private var selectedLanguageValue: String? {
        LocaleOptionCatalog.languages.first(where: { $0.code == selectedLanguageCode })?.label
    }

    private var selectedCountryValue: String? {
        LocaleOptionCatalog.countries.first(where: { $0.code == selectedCountryCode })?.label
    }

    // Section card helper
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.gradientBackgroundDark.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func requiredFieldLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            Text("*")
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.statusNegative80)
        }
    }

    private func dropdownFieldLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundColor(AppColors.whiteText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.greyText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    ThemeManager.shared.currentTheme == .lightGrey
                        ? AppColors.standardSearchFieldFill
                        : AppColors.unhighlightedTextBoxBackground.opacity(0.88)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            ThemeManager.shared.currentTheme == .lightGrey
                                ? AppColors.standardSearchFieldStroke
                                : AppColors.whiteText.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }

    var body: some View {
        ZStack {
            GuildFlowBackground()

            VStack(spacing: 0) {
                GuildFlowTitleHeader(
                    title: "Create a Guild",
                    subtitle: "Build your trading community",
                    icon: "plus.circle.fill",
                    onBack: onCancel
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 8) {
                            GuildMetaChip(label: "Access", value: isOpen ? "Open" : "Private")
                            GuildMetaChip(label: "Questions", value: isOpen ? "0" : "\(joinQuestions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)")
                            GuildMetaChip(label: "Name", value: guildName.isEmpty ? "Draft" : "\(min(guildName.count, 50))/50")
                        }
                        .opacity(visibleSections.contains(0) ? 1 : 0)
                        .offset(y: visibleSections.contains(0) ? 0 : 12)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.0), value: visibleSections.contains(0))

                    // Guild Identity card
                    sectionCard {
                        Text("Guild Identity")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        // Guild preview
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accentColor.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.title)
                                    .foregroundColor(AppColors.accentColor)
                            }

                            Text(guildName.isEmpty ? "Your Guild" : guildName)
                                .font(.title3.bold())
                                .foregroundColor(guildName.isEmpty ? AppColors.greyText : AppColors.whiteText)
                                .lineLimit(1)
                                .animation(.easeInOut(duration: 0.2), value: guildName)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

                        // Guild name field (inline, no extra horizontal padding)
                        VStack(alignment: .leading, spacing: 4) {
                            requiredFieldLabel("Guild Name")

                            TextField("Guild name", text: $guildName)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )

                            Text("\(guildName.count)/50")
                                .font(.caption2)
                                .foregroundColor(guildName.count > 50 ? .red : AppColors.greyText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .opacity(visibleSections.contains(1) ? 1 : 0)
                    .offset(y: visibleSections.contains(1) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: visibleSections.contains(1))

                    // Details card
                    sectionCard {
                        Text("Details")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description (optional)")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            TextEditor(text: $guildDescription)
                                .frame(minHeight: 80)
                                .padding(8)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Language")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            Menu {
                                Button("Not specified") {
                                    selectedLanguageCode = ""
                                }
                                Divider()
                                ForEach(LocaleOptionCatalog.languages) { option in
                                    Button(option.label) {
                                        selectedLanguageCode = option.code
                                    }
                                }
                            } label: {
                                dropdownFieldLabel(selectedLanguageLabel)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Location")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            Menu {
                                Button("Not specified") {
                                    selectedCountryCode = ""
                                }
                                Divider()
                                ForEach(LocaleOptionCatalog.countries) { option in
                                    Button(option.label) {
                                        selectedCountryCode = option.code
                                    }
                                }
                            } label: {
                                dropdownFieldLabel(selectedCountryLabel)
                            }
                        }
                    }
                    .opacity(visibleSections.contains(2) ? 1 : 0)
                    .offset(y: visibleSections.contains(2) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1), value: visibleSections.contains(2))

                    // Access & Moderation card
                    sectionCard {
                        Text("Access & Moderation")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open Guild")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
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
                                        .font(.subheadline)
                                        .fontWeight(.medium)
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
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                                    )
                                            )

                                        if joinQuestions.count > 1 {
                                            Button {
                                                joinQuestions.remove(at: index)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(AppColors.statusNegative80)
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOpen)
                    .opacity(visibleSections.contains(3) ? 1 : 0)
                    .offset(y: visibleSections.contains(3) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15), value: visibleSections.contains(3))

                    // Initial announcement card
                    sectionCard {
                        Text("Initial Announcement")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Text("This announcement is required and will be posted immediately after guild creation.")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)

                        VStack(alignment: .leading, spacing: 6) {
                            requiredFieldLabel("Title")

                            TextField("Welcome to the guild", text: $initialAnnouncementTitle)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.sentences)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            requiredFieldLabel("Content")

                            TextEditor(text: $initialAnnouncementContent)
                                .frame(minHeight: 90)
                                .padding(8)
                                .font(.body)
                                .foregroundColor(AppColors.whiteText)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.88))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.whiteText.opacity(0.15), lineWidth: 1)
                                        )
                                )
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mark as important")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.whiteText)
                                Text("Highlights this post for new members.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                            }
                            Spacer()
                            Toggle("", isOn: $initialAnnouncementImportant)
                                .tint(AppColors.accentColor)
                        }
                    }
                    .opacity(visibleSections.contains(4) ? 1 : 0)
                    .offset(y: visibleSections.contains(4) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2), value: visibleSections.contains(4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                    .onAppear {
                        for i in 0...4 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.08) {
                                visibleSections.insert(i)
                            }
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                if isCreating {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.sheetBackground)
                } else {
                    StandardActionButtonFullWidth(
                        title: "Create Guild",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task { await createGuild() }
                    }
                    .disabled(!canCreateGuild)
                    .opacity(canCreateGuild ? 1.0 : 0.5)
                    .background(AppColors.sheetBackground)
                }
            }
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
                language: selectedLanguageValue,
                location: selectedCountryValue,
                joinQuestions: isOpen ? [] : joinQuestions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .enumerated()
                    .map { index, prompt in
                        RLGuildJoinQuestionInputDTO(prompt: prompt, isRequired: true, displayOrder: index)
                    },
                initialAnnouncementTitle: initialAnnouncementTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                initialAnnouncementContent: initialAnnouncementContent.trimmingCharacters(in: .whitespacesAndNewlines),
                initialAnnouncementPreview: String(initialAnnouncementContent.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)),
                initialAnnouncementIsImportant: initialAnnouncementImportant
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
