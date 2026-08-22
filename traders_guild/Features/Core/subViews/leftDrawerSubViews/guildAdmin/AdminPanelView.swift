//
//  AdminPanelView.swift
//  traders_guild
//
//  Created by Al Hennessey on 22/01/2026.
//

//
//  AdminPanelView.swift
//  traders_guild
//
//  Admin Panel for Left Drawer - Moderator/Admin Only Features
//  Includes: Create Announcements, Create Events, Guild Details, Reports, Invite Members, Manage Members, Manage Roles
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - ADMIN PANEL LIST VIEW
// MARK: - ================================================================================================

struct AdminPanelListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                if let guild = rlAppState.currentGuild {
                    GuildCrestView(guild: guild, size: 26)
                } else {
                    Image(systemName: "shield.checkered")
                        .font(.title3)
                        .foregroundColor(AppColors.accentColor)
                }
                Text("Guild Management")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Role Badge
            if let membership = rlAppState.currentMembership {
                HStack {
                    Text("Your Role:")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                    if rlAppState.isGuildOwner {
                        Text("Owner")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    } else {
                        Text(membership.memberRole.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(membership.memberRole.color)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            
            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
            
            // Content Creation Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Content Creation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                    .padding(.horizontal, 16)
                
                // Create Announcement Button
                AdminActionButton(
                    icon: "megaphone.fill",
                    title: "Create Announcement",
                    subtitle: "Post an announcement to the guild",
                    iconColor: AppColors.accentColor
                ) {
                    bottomSheetContent = .createAnnouncement
                }
                
                // Create Event Button
                AdminActionButton(
                    icon: "calendar.badge.plus",
                    title: "Create Event",
                    subtitle: "Schedule a new guild event",
                    iconColor: AppColors.statusPositive
                ) {
                    bottomSheetContent = .createEvent
                }
            }
            
            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Guild Details Section - Admin/Owner only
            if rlAppState.canAdmin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guild Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                        .padding(.horizontal, 16)

                    AdminActionButton(
                        icon: "gearshape.fill",
                        title: "Guild Details",
                        subtitle: "Update name, description & visibility",
                        iconColor: .gray
                    ) {
                        bottomSheetContent = .guildSettings
                    }

                    AdminActionButton(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Manage Chatrooms",
                        subtitle: "Create, edit, and archive guild chatrooms",
                        iconColor: .cyan
                    ) {
                        bottomSheetContent = .manageChatrooms
                    }

                    AdminActionButton(
                        icon: "list.bullet.rectangle",
                        title: "Guild Watchlist",
                        subtitle: "Review requests and manage symbols",
                        iconColor: AppColors.statusInfo
                    ) {
                        bottomSheetContent = .manageGuildWatchlist
                    }
                }

                Divider()
                    .background(AppColors.whiteText.opacity(0.2))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            // Reports Section - Moderator+ visible
            VStack(alignment: .leading, spacing: 8) {
                Text("Reports")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                    .padding(.horizontal, 16)

                AdminActionButton(
                    icon: "flag.fill",
                    title: "Manage Reports",
                    subtitle: rlAppState.canAdmin ? "Review & resolve reports" : "View reported content",
                    iconColor: .red
                ) {
                    bottomSheetContent = .manageReports
                }
            }

            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Member Management Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Member Management")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                    .padding(.horizontal, 16)

                // Invite Members
                AdminActionButton(
                    icon: "person.badge.plus",
                    title: "Invite Members",
                    subtitle: "Search and invite users to your guild",
                    iconColor: AppColors.statusInfo
                ) {
                    bottomSheetContent = .inviteMembers
                }

                // Manage Members - Moderator+ (actions gated by role inside)
                AdminActionButton(
                    icon: "person.2.fill",
                    title: "Manage Members",
                    subtitle: rlAppState.canAdmin ? "Mute, suspend, kick & ban members" : "Mute & suspend members",
                    iconColor: .purple
                ) {
                    bottomSheetContent = .manageMembers
                }

                // Manage Roles - Admin only
                if rlAppState.canAdmin {
                    AdminActionButton(
                        icon: "person.badge.shield.checkmark",
                        title: "Manage Roles",
                        subtitle: "Change member roles, kick or ban",
                        iconColor: AppColors.moderationOrange
                    ) {
                        bottomSheetContent = .manageRoles
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - ================================================================================================
// MARK: - ADMIN ACTION BUTTON
// MARK: - ================================================================================================

struct AdminActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                action()
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDisabled ? AppColors.whiteText.opacity(0.3) : iconColor)
                    .frame(width: 32)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? AppColors.whiteText.opacity(0.4) : AppColors.whiteText)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.whiteText.opacity(isDisabled ? 0.3 : 0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(isDisabled ? 0.2 : 0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.whiteText.opacity(isDisabled ? 0.02 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColors.whiteText.opacity(isDisabled ? 0.05 : 0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .padding(.horizontal, 16)
    }
}

// MARK: - ================================================================================================
// MARK: - CREATE ANNOUNCEMENT VIEW
// MARK: - ================================================================================================

struct CreateAnnouncementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    private let availableAnnouncementIcons = GuildPostIconKey.allCases.filter { $0 != .star }

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var preview: String = ""
    @State private var isImportant: Bool = false
    @State private var selectedIconKey: GuildPostIconKey = .announcementDefault
    @State private var isSubmitting: Bool = false
    @State private var broadcastToAllGuilds: Bool = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count >= 3 &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count >= 3
    }

    private var canBroadcastToAllGuilds: Bool {
        rlAppState.currentUser?.isSuperuser == true
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "megaphone.fill",
                    iconColor: AppColors.accentColor,
                    title: "Create Announcement",
                    subtitle: broadcastToAllGuilds
                        ? "Post a system announcement into every active guild"
                        : "Post to your guild members"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                ScrollView {
                    VStack(spacing: 12) {
                        AdminSectionCard {
                            AdminInputField(
                                title: "Title (Required, min 3 chars)",
                                placeholder: "Announcement title...",
                                text: $title
                            )
                            AdminInputField(
                                title: "Preview (Optional)",
                                placeholder: "Short preview text...",
                                text: $preview
                            )
                            AdminInputTextEditor(
                                title: "Content (Required, min 3 chars)",
                                placeholder: "Announcement content...",
                                text: $content
                            )
                            GuildPostIconPickerSection(
                                title: "Announcement Icon",
                                subtitle: "Choose the icon members will see in the feed and notifications.",
                                availableIcons: availableAnnouncementIcons,
                                selectedIconKey: $selectedIconKey
                            )
                            AdminToggleRow(
                                title: "Mark as Important",
                                subtitle: "Highlights this announcement for members",
                                icon: "exclamationmark.circle.fill",
                                iconColor: AppColors.bearCandleRed,
                                isOn: $isImportant
                            )
                            if canBroadcastToAllGuilds {
                                AdminToggleRow(
                                    title: "Broadcast to All Guilds",
                                    subtitle: "Uses the hidden Traders Guild system account so every guild gets the same announcement",
                                    icon: "globe.europe.africa.fill",
                                    iconColor: AppColors.accentColor,
                                    isOn: $broadcastToAllGuilds
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // Generous trailing scroll room so the final field clears the
                    // footer and keyboard with space to spare, regardless of state.
                    .padding(.bottom, 140)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdminBottomActionBar(
                    primaryTitle: "Post Announcement",
                    primaryDisabled: !isValid,
                    isSubmitting: isSubmitting,
                    showsCancel: false,
                    onPrimary: { Task { await createAnnouncement() } }
                )
            }

            SheetCloseButton(action: { dismiss() })
                .padding(.top, 20)
                .padding(.trailing, 20)
        }
        .dismissKeyboardOnTapAndDragBackground()
        .background(AdminSheetBackground())
        // Keyboard covers the pinned footer (matches the rest of the app —
        // users dismiss via tap/drag on background or swipe-down on the list).
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func createAnnouncement() async {
        guard isValid && !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if broadcastToAllGuilds {
                _ = try await rlAppState.createGlobalAnnouncement(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    preview: preview.isEmpty ? nil : preview.trimmingCharacters(in: .whitespacesAndNewlines),
                    isImportant: isImportant,
                    iconKey: selectedIconKey
                )
                if let guildId = rlAppState.currentGuild?.id {
                    await leftDrawerViewModel.refreshAnnouncements(guildId: guildId, rlAppState: rlAppState)
                }
            } else {
                let newAnnouncement = try await rlAppState.createAnnouncement(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    preview: preview.isEmpty ? nil : preview.trimmingCharacters(in: .whitespacesAndNewlines),
                    isImportant: isImportant,
                    iconKey: selectedIconKey
                )
                leftDrawerViewModel.announcements.insert(newAnnouncement, at: 0)
            }
            dismiss()
        } catch {
            // Error is already shown by rlAppState
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CREATE EVENT VIEW
// MARK: - ================================================================================================

struct CreateEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var preview: String = ""
    @State private var eventDate: Date = Date().addingTimeInterval(86400)
    @State private var isImportant: Bool = false
    @State private var selectedIconKey: GuildPostIconKey = .eventDefault
    @State private var isSubmitting: Bool = false

    // Location selection — optional. When set, shown in the event detail view
    // with a "Go to Event" button that navigates to the selected chatroom/symbol.
    @State private var selectedLocationType: RLEventLocationType? = nil
    @State private var selectedLocationId: UUID? = nil
    @State private var selectedLocationLabel: String? = nil
    @State private var showLocationPicker: Bool = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count >= 3 &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count >= 3 &&
        !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        preview.count >= 3 &&
        eventDate > Date()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "calendar.badge.plus",
                    iconColor: AppColors.statusPositive,
                    title: "Create Event",
                    subtitle: "Schedule a guild event"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                ScrollView {
                    VStack(spacing: 12) {
                        AdminSectionCard {
                            AdminInputField(
                                title: "Event Title (Required, min 3 chars)",
                                placeholder: "What's the event?",
                                text: $title
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.greyText)
                                    Text("Date & Time (Required, must be future)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                }
                                DatePicker(
                                    "Event Date",
                                    selection: $eventDate,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(ThemeManager.shared.currentTheme.colorScheme)
                            }

                            AdminInputField(
                                title: "Preview Text (Required, min 3 chars)",
                                placeholder: "Short description for the list view...",
                                text: $preview
                            )
                            AdminInputTextEditor(
                                title: "Full Description (Required, min 3 chars)",
                                placeholder: "Describe the event in detail...",
                                text: $content
                            )
                            GuildPostIconPickerSection(
                                title: "Event Icon",
                                subtitle: "Choose the icon members will see in the feed and notifications.",
                                selectedIconKey: $selectedIconKey
                            )
                            locationPickerRow
                            AdminToggleRow(
                                title: "Featured Event",
                                subtitle: "Pin to the top and highlight in the feed",
                                icon: "star.circle.fill",
                                iconColor: AppColors.statusInfo,
                                isOn: $isImportant
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // Generous trailing scroll room so the Featured toggle clears
                    // the footer and keyboard with space to spare.
                    .padding(.bottom, 140)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdminBottomActionBar(
                    primaryTitle: "Create Event",
                    primaryDisabled: !isValid,
                    isSubmitting: isSubmitting,
                    showsCancel: false,
                    onPrimary: { Task { await createEvent() } }
                )
            }

            SheetCloseButton(action: { dismiss() })
                .padding(.top, 20)
                .padding(.trailing, 20)
        }
        .dismissKeyboardOnTapAndDragBackground()
        .background(AdminSheetBackground())
        // Keyboard covers the pinned footer (matches the rest of the app —
        // users dismiss via tap/drag on background or swipe-down on the list).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showLocationPicker) {
            EventLocationPickerSheet(
                selectedType: selectedLocationType,
                selectedId: selectedLocationId,
                onSelect: { type, id, label in
                    selectedLocationType = type
                    selectedLocationId = id
                    selectedLocationLabel = label
                    showLocationPicker = false
                },
                onClear: {
                    selectedLocationType = nil
                    selectedLocationId = nil
                    selectedLocationLabel = nil
                    showLocationPicker = false
                }
            )
        }
    }

    private var locationPickerRow: some View {
        Button(action: {
            dismissKeyboard()
            showLocationPicker = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.accentColor.opacity(selectedLocationType == nil ? 0.12 : 0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: locationIconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Event Location (Optional)")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Text(selectedLocationLabel ?? "None — tap to choose a chatroom or symbol")
                        .font(.subheadline)
                        .foregroundColor(selectedLocationLabel == nil ? AppColors.greyText : AppColors.whiteText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText.opacity(0.8))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var locationIconName: String {
        switch selectedLocationType {
        case .chatroom: return "bubble.left.and.bubble.right.fill"
        case .symbol: return "chart.line.uptrend.xyaxis"
        case nil: return "mappin.and.ellipse"
        }
    }

    private func createEvent() async {
        guard isValid && !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let newEvent = try await rlAppState.createEvent(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                preview: preview.trimmingCharacters(in: .whitespacesAndNewlines),
                eventDate: eventDate,
                isImportant: isImportant,
                iconKey: selectedIconKey,
                locationType: selectedLocationType,
                locationId: selectedLocationId
            )

            leftDrawerViewModel.upcomingEvents.insert(newEvent, at: 0)
            dismiss()
        } catch {
            // Error is already shown by rlAppState
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EVENT LOCATION PICKER SHEET
// MARK: - ================================================================================================

/// Picker sheet that lets the event creator select a chatroom or a symbol from
/// the current guild as the event's location. Selecting "None" clears it.
private struct EventLocationPickerSheet: View {
    let selectedType: RLEventLocationType?
    let selectedId: UUID?
    let onSelect: (RLEventLocationType, UUID, String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var tab: RLEventLocationType = .chatroom
    @State private var chatrooms: [RLGuildChatroomDTO] = []
    @State private var symbols: [RLWatchlistSymbolDTO] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Chatroom").tag(RLEventLocationType.chatroom)
                    Text("Symbol").tag(RLEventLocationType.symbol)
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    ProgressView("Loading…").padding()
                    Spacer()
                } else if let err = loadError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    List {
                        switch tab {
                        case .chatroom:
                            if chatrooms.isEmpty {
                                Text("No chatrooms in this guild.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(chatrooms, id: \.id) { room in
                                    Button {
                                        onSelect(.chatroom, room.id, "#\(room.name)")
                                    } label: {
                                        HStack {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                            Text(room.name)
                                            Spacer()
                                            if selectedType == .chatroom && selectedId == room.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(AppColors.accentColor)
                                            }
                                        }
                                    }
                                }
                            }
                        case .symbol:
                            if symbols.isEmpty {
                                Text("No symbols on the guild watchlist.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(symbols, id: \.symbol.id) { item in
                                    Button {
                                        onSelect(.symbol, item.symbol.id, item.symbol.ticker)
                                    } label: {
                                        HStack {
                                            Image(systemName: "chart.line.uptrend.xyaxis")
                                            VStack(alignment: .leading) {
                                                Text(item.symbol.ticker).fontWeight(.semibold)
                                                Text(item.symbol.displayName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if selectedType == .symbol && selectedId == item.symbol.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(AppColors.accentColor)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Event Location")
            .platformNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("None", action: onClear)
                        .disabled(selectedType == nil)
                }
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        guard let guildId = rlAppState.currentGuild?.id else {
            loadError = "No guild selected."
            return
        }

        async let chatroomTask = rlAppState.fetchGuildChatrooms(guildId: guildId)
        async let watchlistTask = rlAppState.fetchGuildWatchlist(guildId: guildId)

        do {
            let (rooms, wl) = try await (chatroomTask, watchlistTask)
            chatrooms = rooms
            symbols = wl.symbols
        } catch {
            loadError = "Failed to load locations."
        }
    }
}

private struct GuildPostIconPickerSection: View {
    let title: String
    let subtitle: String
    var availableIcons: [GuildPostIconKey] = GuildPostIconKey.allCases
    @Binding var selectedIconKey: GuildPostIconKey

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText.opacity(0.8))
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(availableIcons) { iconKey in
                    Button {
                        selectedIconKey = iconKey
                    } label: {
                        VStack(spacing: 6) {
                            GuildPostIconBadge(
                                iconKey: iconKey,
                                isFeatured: selectedIconKey == iconKey,
                                showsFeaturedMarker: false,
                                size: 38,
                                iconSize: 16,
                                isRead: false
                            )
                            Text(iconKey.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(
                                    selectedIconKey == iconKey
                                        ? AppColors.whiteText
                                        : AppColors.greyText
                                )
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    selectedIconKey == iconKey
                                        ? iconKey.accentColor.opacity(0.18)
                                        : AppColors.insetPanelBackground
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selectedIconKey == iconKey
                                                ? iconKey.accentColor.opacity(0.7)
                                                : AppColors.surfaceWhite12,
                                            lineWidth: selectedIconKey == iconKey ? 1.4 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
