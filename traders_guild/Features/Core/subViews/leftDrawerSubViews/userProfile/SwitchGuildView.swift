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

struct LocalePreferenceChips: View {
    let language: String?
    let location: String?
    var preferredLanguage: String = ""
    var preferredLocation: String = ""
    var compact: Bool = false

    private var normalizedLanguage: String {
        LocaleOptionCatalog.languageCode(from: language)
    }

    private var normalizedLocation: String {
        LocaleOptionCatalog.countryCode(from: location)
    }

    private var matchScore: Int {
        LocaleOptionCatalog.matchScore(
            language: language,
            location: location,
            preferredLanguage: preferredLanguage,
            preferredLocation: preferredLocation
        )
    }

    var body: some View {
        // Language and location are always shown so the row layout stays
        // consistent across guilds; a guild with no preference set reads as
        // "All languages" / "All locations" rather than disappearing.
        HStack(spacing: 6) {
            LocalePreferenceChip(
                icon: languageIconName,
                text: LocaleOptionCatalog.languageLabel(for: normalizedLanguage),
                isMatched: LocaleOptionCatalog.languageMatches(normalizedLanguage, preferred: preferredLanguage),
                compact: compact
            )

            LocalePreferenceChip(
                icon: locationIconName,
                text: LocaleOptionCatalog.countryDisplay(for: normalizedLocation),
                isMatched: LocaleOptionCatalog.countryMatches(normalizedLocation, preferred: preferredLocation),
                compact: compact
            )

            if matchScore > 0 {
                LocalePreferenceChip(
                    icon: "checkmark.seal.fill",
                    text: "Matches you",
                    isMatched: true,
                    compact: compact
                )
            }
        }
    }

    private var languageIconName: String {
        normalizedLanguage == LocaleOptionCatalog.allPreferenceCode ? "globe" : "character.book.closed"
    }

    private var locationIconName: String? {
        // For "all" the 🌐 emoji is already in `countryDisplay`'s text; for a
        // specific country the flag emoji is in the text. Only legacy empty
        // location falls back to a globe SF Symbol.
        normalizedLocation.isEmpty ? "globe" : nil
    }
}

private struct LocalePreferenceChip: View {
    let icon: String?
    let text: String
    let isMatched: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(compact ? .caption2 : .caption)
            }
            Text(text)
                .font(compact ? .caption2 : .caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundColor(isMatched ? AppColors.guildReputationAccent : AppColors.whiteText.opacity(0.78))
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(isMatched ? AppColors.guildReputationAccent.opacity(0.18) : AppColors.whiteText.opacity(0.08))
        )
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

    /// User's guilds with their System Guild(s) pinned to the top.
    private var sortedUserGuilds: [RLGuildWithMembership] {
        let system = rlAppState.userGuilds.filter { $0.guild.isSystemGuild }
        let others = rlAppState.userGuilds.filter { !$0.guild.isSystemGuild }
        return system + others
    }

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
                        .foregroundColor(AppColors.guildReputationAccent)
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
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.06))
                            .frame(width: 72, height: 72)
                        Image(systemName: "shield.slash")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.greyText)
                    }

                    Text("No guilds yet")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)

                    Text("Join or create a guild to get started.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedUserGuilds) { item in
                            let isCurrent = item.guild.id == rlAppState.currentGuild?.id
                            GuildCardView(
                                guild: item.guild,
                                style: .switchRow,
                                role: item.role,
                                isCurrent: isCurrent,
                                onTap: isCurrent ? nil : { selectGuild(item) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 20)
            }
            
            Divider()

            if !rlAppState.pendingJoinRequests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Awaiting approval")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                    // Not tappable: there is nothing to do but wait, and styling
                    // these like the joined rows would invite a dead tap.
                    ForEach(rlAppState.pendingJoinRequests) { request in
                        // `onTap: nil` is what makes this non-interactive.
                        GuildCardView(guild: request.guild, style: .pending)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
            }

            HStack(spacing: 8) {
                DrawerActionButton(
                    title: "Join a Guild",
                    backgroundColor: AppColors.drawerNeutralActionButtonFill,
                    foregroundColor: AppColors.drawerNeutralActionButtonForeground,
                    strokeColor: AppColors.drawerNeutralActionButtonStroke,
                    strokeWidth: 0.5,
                    action: {
                        showJoinGuild = true
                    }
                )

                Spacer()

                DrawerActionButton(
                    title: "Create a Guild",
                    backgroundColor: AppColors.drawerNeutralActionButtonFill,
                    foregroundColor: AppColors.drawerNeutralActionButtonForeground,
                    strokeColor: AppColors.drawerNeutralActionButtonStroke,
                    strokeWidth: 0.5,
                    action: {
                        showCreateGuild = true
                    }
                )
            }
            .padding(.horizontal, 25)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background(AppColors.sheetBackground)
        }
        .task {
            await rlAppState.refreshMyJoinRequests()
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
    }
}

// MARK: - Join Guild Full Screen Flow

struct JoinGuildFlowView: View {
    /// Skip the search list and open straight onto this guild's detail — used
    /// when a `/g/{slug}` link resolved to an invite-only guild, so the user
    /// lands on the application form rather than having to find it.
    var initialGuild: RLGuildDTO? = nil

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
        .onAppear {
            guard let initialGuild, selectedGuild == nil else { return }
            selectedGuild = initialGuild
            showGuildDetail = true
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
    @State private var hasLoadedLocalePreferences: Bool = false
    @State private var preferredLanguage: String = ""
    @State private var preferredLocation: String = ""

    var filteredGuilds: [DiscoverGuildItem] {
        discoverGuilds
    }

    private var activeFilterBadges: [String] {
        var badges: [String] = []
        if selectedAccess != .all {
            badges.append(selectedAccess.rawValue)
        }
        if !languageFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            badges.append(LocaleOptionCatalog.languageLabel(for: languageFilter))
        }
        if !locationFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            badges.append(LocaleOptionCatalog.countryDisplay(for: locationFilter))
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
                        UnifiedSearchBar(
                            text: $searchText,
                            placeholder: "Search guilds...",
                            onClear: {
                                Task { await loadOpenGuilds() }
                            }
                        )
                        .onSubmit {
                            Task { await loadOpenGuilds() }
                        }

                        Button(action: { showFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(AppColors.whiteText.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .background(
                                    AppColors.adaptiveChromeSearchFieldFill
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            AppColors.adaptiveChromeSearchFieldStroke,
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
                                .foregroundColor(AppColors.guildReputationAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(AppColors.guildReputationAccent.opacity(0.17))
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
                        LazyVStack(spacing: 14) {
                            ForEach(filteredGuilds) { guild in
                                GuildCardView(
                                    guild: guild.guild,
                                    style: .discover,
                                    isJoined: guild.isJoined,
                                    preferredLanguage: preferredLanguage,
                                    preferredLocation: preferredLocation,
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
            await loadLocalePreferencesIfNeeded()

            let guilds = try await rlAppState.fetchJoinableGuilds(
                search: searchText.isEmpty ? nil : searchText,
                isOpen: selectedAccess.isOpenValue,
                language: languageFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : languageFilter,
                location: locationFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationFilter,
                preferredLanguage: preferredLanguage.isEmpty ? nil : preferredLanguage,
                preferredLocation: preferredLocation.isEmpty ? nil : preferredLocation,
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
            if !LocaleOptionCatalog.languageMatches(guild.language, preferred: language) {
                return false
            }
        }

        let location = locationFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty {
            if !LocaleOptionCatalog.countryMatches(guild.location, preferred: location) {
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

    private func loadLocalePreferencesIfNeeded() async {
        guard !hasLoadedLocalePreferences else { return }
        hasLoadedLocalePreferences = true
        guard let profile = try? await rlAppState.realApi.getCurrentUserExtendedProfile() else { return }
        preferredLanguage = LocaleOptionCatalog.languageCode(from: profile.language)
        preferredLocation = LocaleOptionCatalog.countryCode(from: profile.location)
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

                    // Language
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Language")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Menu {
                            Button("Any") { languageFilter = "" }
                            Divider()
                            ForEach(LocaleOptionCatalog.languages) { option in
                                Button(option.label) { languageFilter = option.code }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(languageFilter.isEmpty ? "Any" : LocaleOptionCatalog.languageLabel(for: languageFilter))
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
                                    .fill(AppColors.standardSearchFieldFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)

                        Menu {
                            Button("Any") { locationFilter = "" }
                            Divider()
                            ForEach(LocaleOptionCatalog.countries) { option in
                                Button(LocaleOptionCatalog.countryDisplay(for: option.code)) { locationFilter = option.code }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(locationFilter.isEmpty ? "Any" : LocaleOptionCatalog.countryDisplay(for: locationFilter))
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
                                    .fill(AppColors.standardSearchFieldFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                                    )
                            )
                        }
                    }
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
                    .foregroundColor(AppColors.guildReputationAccent)
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

    private var ctaTitle: String {
        if isAlreadyJoined {
            return isCurrentGuild ? "Current Guild" : "Switch to Guild"
        }
        return guild.isOpen ? "Join Guild" : "Request to Join"
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
                    // Identity, then the guild's own numbers in the same
                    // footer strip the cards use. This absorbs what used to be a
                    // separate "Guild Snapshot" card holding four StatBoxes —
                    // a card nested inside a card, with different constants.
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                GuildCrestView(guild: guild, size: 48)

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
                                            .background(AppColors.guildReputationAccent.opacity(0.18))
                                            .foregroundColor(AppColors.guildReputationAccent)
                                            .clipShape(Capsule())

                                        Text("Created \(createdDateText)")
                                            .font(.caption)
                                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                                    }

                                    // Full chips here, unlike the cards: detail
                                    // has the width for them.
                                    LocalePreferenceChips(
                                        language: guild.language,
                                        location: guild.location,
                                        compact: true
                                    )
                                }
                            }

                            if let description = guild.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.whiteText.opacity(0.85))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GuildMetaFooter(
                            memberCount: guild.memberCount,
                            membersOnline: guild.membersOnline,
                            reputationDisplay: guild.reputationDisplay
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.contentCardFill(isUnread: false, isPressed: false))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(AppColors.markerListCapsuleStroke, lineWidth: 1)
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.guildCardBase)
                            .shadow(color: AppColors.guildCardShadow, radius: 10, x: 0, y: 3)
                    )
                    .opacity(visibleSections.contains(0) ? 1 : 0)
                    .offset(y: visibleSections.contains(0) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.0), value: visibleSections.contains(0))

                    // Facts, then entry requirements. Previously two cards, the
                    // second of which used an accent stroke its siblings didn't.
                    GuildSectionCard(title: "Guild Information") {
                        GuildInfoRow(icon: "person.crop.circle", title: "Owner", value: ownerName)
                        GuildInfoRow(icon: "globe", title: "Language", value: LocaleOptionCatalog.languageLabel(for: guild.language))
                        GuildInfoRow(icon: "mappin.and.ellipse", title: "Location", value: LocaleOptionCatalog.countryDisplay(for: guild.location))

                        Divider()
                            .background(AppColors.whiteText.opacity(0.1))
                            .padding(.vertical, 2)

                        Text("Join Requirements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)

                        Text(joinRequirementText)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.82))
                    }
                    .opacity(visibleSections.contains(1) ? 1 : 0)
                    .offset(y: visibleSections.contains(1) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: visibleSections.contains(1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 140)
                .onAppear {
                    for i in 0...1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.08) {
                            visibleSections.insert(i)
                        }
                    }
                }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .keyboardPinnedBottomInset {
            VStack(spacing: 0) {
                Divider()
                // One button for every state. The joining state used to drop
                // the button entirely for a bare centred ProgressView, so the
                // footer changed shape and height mid-tap.
                StandardActionButtonFullWidth(
                    title: ctaTitle,
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.systemBlack,
                    isLoading: isJoining,
                    action: {
                        guard !isJoining else { return }
                        if isAlreadyJoined {
                            switchToGuild()
                        } else if guild.isOpen {
                            Task { await joinGuild() }
                        } else {
                            showJoinForm = true
                        }
                    }
                )
                .disabled(isJoining || (isAlreadyJoined && isCurrentGuild))
                .opacity((isAlreadyJoined && isCurrentGuild) ? 0.55 : 1.0)
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

struct GuildInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.guildReputationAccent.opacity(0.85))
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
                                                    .foregroundColor(AppColors.guildReputationAccent)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule().fill(AppColors.guildReputationAccent.opacity(0.15))
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
                        .padding(.bottom, 140)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toolbarColorScheme(ThemeManager.shared.currentTheme.colorScheme, for: .navigationBar)
        .keyboardPinnedBottomInset {
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
            // Submitting used to dismiss silently, so it read as though nothing
            // had happened. Refresh first, so the pending row is already there
            // when the sheet closes.
            await rlAppState.refreshMyJoinRequests()
            rlAppState.showSuccess("Request sent to \(guild.name) — an admin will review it.")
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
    @State private var isOpen: Bool = true
    @State private var isCreating: Bool = false
    @State private var joinQuestions: [String] = [""]
    @State private var visibleSections: Set<Int> = []
    @State private var selectedCrestSymbol: String = GuildCrestCatalog.defaultSymbolKey
    @State private var selectedCrestColor: String = GuildCrestCatalog.defaultColorKey
    @State private var pickedCrestImage: UIImage?
    @State private var showCrestImagePicker = false
    @State private var showInviteHubAfterCreate = false

    private var normalizedJoinQuestions: [RLGuildJoinQuestionInputDTO] {
        joinQuestions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, prompt in
                RLGuildJoinQuestionInputDTO(prompt: prompt, isRequired: true, displayOrder: index)
            }
    }

    /// The name the server will actually see. The UI renders a trailing
    /// " Guild" itself, so a typed one is stripped before submit — which means
    /// validating the raw text would let "A Guild" through to a server
    /// rejection it can't explain.
    private var normalizedGuildName: String {
        var trimmed = guildName.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.lowercased().hasSuffix(" guild") {
            trimmed = String(trimmed.dropLast(" guild".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    /// Creation asks for a name and an access choice. Description, locale and
    /// the welcome post are offered afterwards by the invite hub's checklist.
    private var canCreateGuild: Bool {
        // 3 is the backend's `GuildCreateRequest.name` minimum.
        normalizedGuildName.count >= 3
            && normalizedGuildName.count <= 50
            && (isOpen || !normalizedJoinQuestions.isEmpty)
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
                    AppColors.adaptiveFormControlFill
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            AppColors.adaptiveFormControlStroke,
                            lineWidth: 1
                        )
                )
        )
    }

    /// The guild preview emblem — the picked image, else the symbol + colour.
    @ViewBuilder
    private func crestPreview(size: CGFloat) -> some View {
        if let image = pickedCrestImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            GuildCrestView(
                crestSymbol: selectedCrestSymbol,
                crestColor: selectedCrestColor,
                fallbackInitial: guildName.first ?? "G",
                size: size
            )
        }
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
                    GuildSectionCard(title: "Guild Identity") {

                        // Guild preview
                        VStack(spacing: 10) {
                            crestPreview(size: 64)

                            Text(guildName.isEmpty ? "Your Guild" : "\(guildName) Guild")
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

                            HStack(spacing: 0) {
                                TextField("Guild name", text: $guildName)
                                    .font(.body)
                                    .foregroundColor(AppColors.whiteText)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.words)

                                if !guildName.isEmpty {
                                    Text(" Guild")
                                        .font(.body)
                                        .foregroundColor(AppColors.greyText.opacity(0.7))
                                        .fixedSize()
                                        .accessibilityHidden(true)
                                }
                            }
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

                        // Guild crest — pick a symbol + colour, or upload an image
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Guild Crest")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text("Your guild's emblem — shown everywhere your guild appears.")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText.opacity(0.85))

                            if let image = pickedCrestImage {
                                HStack(spacing: 12) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                    Button {
                                        pickedCrestImage = nil
                                    } label: {
                                        Label("Remove image", systemImage: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.statusNegative80)
                                    }
                                    Spacer(minLength: 0)
                                }
                            } else {
                                // Symbol options
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(GuildCrestCatalog.symbolKeys, id: \.self) { key in
                                            Button {
                                                selectedCrestSymbol = key
                                            } label: {
                                                Image(systemName: GuildCrestCatalog.sfSymbol(for: key))
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundColor(GuildCrestCatalog.color(for: selectedCrestColor))
                                                    .frame(width: 44, height: 44)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(key == selectedCrestSymbol ? AppColors.guildReputationAccent.opacity(0.18) : Color.clear)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 10)
                                                                    .stroke(
                                                                        key == selectedCrestSymbol ? AppColors.guildReputationAccent : AppColors.whiteText.opacity(0.12),
                                                                        lineWidth: key == selectedCrestSymbol ? 1.5 : 1
                                                                    )
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }

                                // Colour options
                                HStack(spacing: 12) {
                                    ForEach(GuildCrestCatalog.colorKeys, id: \.self) { key in
                                        Button {
                                            selectedCrestColor = key
                                        } label: {
                                            Circle()
                                                .fill(GuildCrestCatalog.color(for: key))
                                                .frame(width: 26, height: 26)
                                                .overlay(
                                                    Circle().stroke(AppColors.whiteText, lineWidth: key == selectedCrestColor ? 2 : 0)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }

                            Button {
                                showCrestImagePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text(pickedCrestImage == nil ? "Upload an image" : "Choose a different image")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(AppColors.guildReputationAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.guildReputationAccent.opacity(0.14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.guildReputationAccent.opacity(0.5), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(visibleSections.contains(1) ? 1 : 0)
                    .offset(y: visibleSections.contains(1) ? 0 : 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05), value: visibleSections.contains(1))

                    // Access & Moderation card
                    GuildSectionCard(title: "Access & Moderation") {

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
                                .tint(AppColors.guildReputationAccent)
                        }

                        if isOpen {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.statusWarning90)
                                Text("Heads up: anyone can find and join an open guild instantly — no approval needed. Choose Private if you want to approve members or run an invite-only community.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.statusWarning90)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.statusWarning14)
                            )
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

                                Text("Add at least one question for private guild applications.")
                                    .font(.caption)
                                    .foregroundColor(normalizedJoinQuestions.isEmpty ? AppColors.statusNegative80 : AppColors.greyText)

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
                                            .foregroundColor(AppColors.guildReputationAccent)
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

                    // Sets expectations for the checklist that appears straight
                    // after, so dropping the old required fields doesn't read as
                    // losing them.
                    Text("You can add a crest, description and welcome message right after — we'll walk you through it.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 4)
                        .opacity(visibleSections.contains(3) ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.15), value: visibleSections.contains(3))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 200)
                    .onAppear {
                        for i in 0...1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.08) {
                                visibleSections.insert(i)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissKeyboardOnTapAndDragBackground()
            }
        }
        .sheet(isPresented: $showCrestImagePicker) {
            SharedImagePicker(sourceType: .photoLibrary) { image in
                pickedCrestImage = image
            }
        }
        .fullScreenCover(isPresented: $showInviteHubAfterCreate) {
            GuildInviteHubView(
                headline: "Your guild is live 🎉",
                subheadline: "Now bring your community in. Share your guild on X, Discord, or with your contacts to get your first members.",
                primaryButtonTitle: "Done",
                onPrimaryAction: {
                    showInviteHubAfterCreate = false
                    onComplete()
                },
                shareMode: .guildVanity
            )
            .environmentObject(rlAppState)
        }
        .toolbar(.hidden, for: .navigationBar)
        .keyboardPinnedBottomInset {
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
        guard isOpen || !normalizedJoinQuestions.isEmpty else {
            rlAppState.showError(
                title: "Join Question Required",
                message: "Add at least one join question before creating a private guild.",
                style: .toast
            )
            return
        }

        isCreating = true
        defer { isCreating = false }

        let trimmedName = normalizedGuildName
        guard !trimmedName.isEmpty else {
            rlAppState.showError(
                title: "Guild Name Required",
                message: "Enter a name for your guild before continuing.",
                style: .toast
            )
            return
        }

        do {
            let _ = try await rlAppState.createGuild(
                name: trimmedName,
                // Everything below comes later, via the checklist. Locale is
                // omitted entirely: the backend falls back to the owner's
                // profile, then to defaults.
                description: nil,
                isOpen: isOpen,
                language: nil,
                location: nil,
                joinQuestions: isOpen ? [] : normalizedJoinQuestions,
                crestSymbol: selectedCrestSymbol,
                crestColor: selectedCrestColor
            )
            // If the user picked a custom image, upload it to the new guild
            // (now the current guild). A failure here is non-fatal — the guild
            // still has its symbol crest.
            if let image = pickedCrestImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                _ = try? await rlAppState.uploadGuildAvatar(imageData: data)
            }
            // Present the invite hub so the owner can immediately bring their
            // community in. "Done" then completes (dismisses) the create flow.
            showInviteHubAfterCreate = true
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
