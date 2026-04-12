//
//  EventsView.swift
//  traders_guild
//
//  Guild Events View for Left Drawer
//  Uses UnifiedCardComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - DATE FORMATTERS
// MARK: - ================================================================================================

private let eventTimeFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("h:mm a")
    return df
}()

private enum EventListTab: String, CaseIterable, UnifiedTabItem {
    case active
    case past

    var title: String {
        switch self {
        case .active: return "Active"
        case .past: return "Past"
        }
    }

    var icon: String {
        switch self {
        case .active: return "calendar.badge.clock"
        case .past: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EVENTS LIST VIEW
// MARK: - ================================================================================================

struct EventsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @State private var selectedTab: EventListTab = .active

    private var activeEvents: [RLGuildEventWithAuthorDTO] {
        leftDrawerViewModel.upcomingEvents
            .filter(\.isActiveEvent)
            .sorted { $0.eventDate < $1.eventDate }
    }

    private var pastEvents: [RLGuildEventWithAuthorDTO] {
        leftDrawerViewModel.upcomingEvents
            .filter(\.isPastEvent)
            .sorted { $0.eventDate > $1.eventDate }
    }

    private var selectedEvents: [RLGuildEventWithAuthorDTO] {
        switch selectedTab {
        case .active:
            return activeEvents
        case .past:
            return pastEvents
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.upcomingEvents.isEmpty {
                UnifiedLoadingState(message: "Loading events...")
                    .padding(.top, 40)
            }
            else {
                UnifiedTabBar(
                    selectedTab: $selectedTab,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { tab in
                        switch tab {
                        case .active:
                            return activeEvents.count
                        case .past:
                            return pastEvents.count
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if selectedEvents.isEmpty {
                    UnifiedEmptyState(
                        icon: selectedTab == .active ? "calendar.badge.clock" : "clock.arrow.circlepath",
                        title: selectedTab == .active ? "No active events" : "No past events",
                        subtitle: selectedTab == .active
                            ? "Check back later for upcoming guild events"
                            : "Finished guild events will appear here"
                    )
                    .padding(.top, 32)
                } else {
                    VStack(spacing: 10) {
                        ForEach(selectedEvents) { event in
                            EventRowView(
                                event: event,
                                onTap: {
                                    bottomSheetContent = .event(event)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EVENT ROW VIEW
// MARK: - ================================================================================================

struct EventRowView: View {
    let event: RLGuildEventWithAuthorDTO
    let onTap: () -> Void

    private var styling: NotificationStyling {
        NotificationStyling(isRead: event.isRead)
    }

    var body: some View {
        UnifiedContentCard(
            onTap: onTap,
            isUnread: !event.isRead,
            semanticBorderColor: event.isImportant && !event.isRead
                ? AppColors.statusHighlight80.opacity(0.45) : nil,
            cornerRadius: 14
        ) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 12) {
                    GuildPostIconBadge(
                        iconKey: event.iconKey,
                        isFeatured: event.isImportant,
                        size: 36,
                        iconSize: 16,
                        isRead: event.isRead
                    )

                    // Event content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(styling.titleColor)
                            .lineLimit(2)

                        Text(event.content)
                            .font(.caption)
                            .foregroundColor(styling.bodyColor)
                            .lineLimit(2)

                        // Time and attendance
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text("\(eventTimeFormatter.string(from: event.eventDate)) • \(event.attendanceDisplay)")
                        }
                        .font(.caption2)
                        .foregroundColor(AppColors.accentColor)
                        .padding(.top, 2)

                        if event.isImportant {
                            UnifiedImportanceBadge(text: "FEATURED EVENT")
                        }
                    }

                    Spacer()

                    rowAccessory
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // MARK: - Author Footer Bar (Hosted by)
                UnifiedAuthorFooter(
                    username: event.authorUsername,
                    role: event.authorRole,
                    reputation: event.authorMembership.reputation,
                    accuracy: event.authorMembership.accuracyFormatted,
                    timeText: event.timeUntilEvent,
                    cornerRadius: 14
                )
            }
        }
    }

    @ViewBuilder
    private var rowAccessory: some View {
        if event.isRead {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.whiteText.opacity(0.3))
        } else {
            Circle()
                .fill(AppColors.accentColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EVENT DETAIL VIEW
// MARK: - ================================================================================================

struct EventDetailView: View {
    let event: RLGuildEventWithAuthorDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var hasRecordedView = false
    @State private var showAttendConfirmation = false
    @State private var showUnAttendConfirmation = false
    @State private var showShareConfirmation = false
    @State private var selectedFriendToShare: UUID? = nil
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .full
        df.timeStyle = .short
        return df
    }()
    
    private var displayedEvent: RLGuildEventWithAuthorDTO {
        leftDrawerViewModel.upcomingEvents.first(where: { $0.id == event.id }) ?? event
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and title
                HStack(alignment: .top, spacing: 12) {
                    GuildPostIconBadge(
                        iconKey: displayedEvent.iconKey,
                        isFeatured: displayedEvent.isImportant,
                        size: 44,
                        iconSize: 20,
                        isRead: false
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedEvent.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        if displayedEvent.isImportant {
                            UnifiedImportanceBadge(text: "FEATURED EVENT")
                        }
                        
                        Text(dateFormatter.string(from: displayedEvent.eventDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Author info
                HStack(spacing: 3) {
                    Text("Hosted by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    UnifiedAuthorRow(
                        username: displayedEvent.authorUsername,
                        role: displayedEvent.authorRole,
                        reputation: displayedEvent.authorMembership.reputation,
                        accuracy: displayedEvent.authorMembership.accuracyFormatted
                    )
                }
                
                Divider()
                
                // Event details and content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Event info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(AppColors.accentColor)
                                Text(displayedEvent.attendanceDisplay)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.accentColor)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.secondary)
                                Text("Guild Hall")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Event description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Description")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(displayedEvent.content)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                Spacer()
                
                Divider()
                
                // Action buttons
                HStack(spacing: 8) {
                    Spacer()
                    
                    DrawerActionButton(
                        imageName: "square.and.arrow.up",
                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        imageOffset: -2,
                        action: {
                            showShareConfirmation = true
                        }
                    )

                    DrawerActionButton(
                        title: displayedEvent.isAttending ? "Attending" : "Attend",
                        imageName: displayedEvent.isAttending ? "calendar.badge.checkmark" : "calendar.badge.plus",
                        backgroundColor: displayedEvent.isAttending ? AppColors.whiteText.opacity(0.8) : AppColors.gradientBackgroundDark.opacity(0.2),
                        foregroundColor: displayedEvent.isAttending ? AppColors.systemBlack : AppColors.whiteText.opacity(0.8),
                        strokeColor: displayedEvent.isAttending ? AppColors.systemBlack : AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: {
                            if displayedEvent.isAttending {
                                showUnAttendConfirmation = true
                            } else {
                                showAttendConfirmation = true
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 30)
            .padding(.horizontal)
            
            // Floating dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .alert("Attend Event", isPresented: $showAttendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Attend Event") {
                attendEvent()
            }
        } message: {
            Text("Are you sure you want to attend the Event")
        }
        .alert("Un Attend Event", isPresented: $showUnAttendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Un Attend Event", role: .destructive) {
                unAttendEvent()
            }
        } message: {
            Text("Are you sure you want to un attend the Event")
        }
        .alert("Share Event", isPresented: $showShareConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Share Event") {
                shareEvent()
            }
        } message: {
            Text("Share the event with Friends")
        }
        .onAppear {
            recordEventView()
        }
    }
    
    // MARK: - Action Methods
    
    private func attendEvent() {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        
        Task {
            do {
                _ = try await rlAppState.attendEvent(guildId: guildId, eventId: event.id)
                leftDrawerViewModel.updateEventAttendance(
                    eventId: event.id,
                    isAttending: true,
                    attendanceCount: displayedEvent.attendeeCount + 1
                )
                rlAppState.showSuccess("Attending Event")
            } catch {
                rlAppState.showError(error, title: "Failed to attend Event")
            }
        }
    }
    
    private func unAttendEvent() {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        
        Task {
            do {
                try await rlAppState.unattendEvent(guildId: guildId, eventId: event.id)
                leftDrawerViewModel.updateEventAttendance(
                    eventId: event.id,
                    isAttending: false,
                    attendanceCount: max(0, displayedEvent.attendeeCount - 1)
                )
                rlAppState.showSuccess("Attendance cancelled")
            } catch {
                rlAppState.showError(error, title: "Failed to cancel attendance")
            }
        }
    }
    
    private func shareEvent() {
        Task {
            guard let guildId = rlAppState.currentGuild?.id else {
                rlAppState.showError(
                    title: RLUserFacingCopy.text(.errorNoGuildSelected),
                    message: RLUserFacingCopy.text(.errorSelectGuildFirst),
                    style: .toast
                )
                return
            }
            guard let friendId = selectedFriendToShare else {
                rlAppState.showError(title: "No Friend Selected", message: "Select a friend to share with.", style: .toast)
                return
            }
            do {
                try await rlAppState.shareEvent(guildId: guildId, eventId: event.id, friendId: friendId)
                showShareConfirmation = false
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
    
    private func recordEventView() {
        guard !hasRecordedView else { return }
        guard let guildId = rlAppState.currentGuild?.id else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await rlAppState.recordEventView(guildId: guildId, eventId: event.id)
                leftDrawerViewModel.markEventAsRead(eventId: event.id)
            } catch {
                print("Failed to record event view: \(error)")
            }
        }
    }
}
