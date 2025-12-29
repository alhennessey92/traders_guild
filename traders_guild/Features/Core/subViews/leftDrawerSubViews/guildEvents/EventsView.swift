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

// MARK: - ================================================================================================
// MARK: - EVENTS LIST VIEW
// MARK: - ================================================================================================

struct EventsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.upcomingEvents.isEmpty {
                UnifiedLoadingState(message: "Loading events...")
                    .padding(.top, 40)
            }
            // Empty state
            else if leftDrawerViewModel.upcomingEvents.isEmpty {
                UnifiedEmptyState(
                    icon: "calendar",
                    title: "No events yet",
                    subtitle: "Check back later for guild updates"
                )
                .padding(.top, 40)
            } else {
                ForEach(leftDrawerViewModel.upcomingEvents) { event in
                    EventRowView(
                        event: event,
                        onTap: {
                            bottomSheetContent = .event(event)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - ================================================================================================
// MARK: - EVENT ROW VIEW
// MARK: - ================================================================================================

struct EventRowView: View {
    let event: GuildEventDTO
    let onTap: () -> Void
    
    var body: some View {
        UnifiedContentCard(
            onTap: onTap,
            showUnreadBorder: !event.isRead,
            cornerRadius: 14
        ) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 12) {
                    // Date pill
                    UnifiedDatePill(date: event.eventDate)
                    
                    // Event content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(2)
                        
                        Text(event.content)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(2)
                        
                        // Time and attendance
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text("\(eventTimeFormatter.string(from: event.eventDate)) • \(event.attendanceDisplay)")
                        }
                        .font(.caption2)
                        .foregroundColor(AppColors.accentColor)
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12) // More padding before footer
                
                // MARK: - Author Footer Bar (Hosted by)
                UnifiedAuthorFooterFromMembership(
                    author: event.author,
                    cornerRadius: 14
                )
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EVENT DETAIL VIEW
// MARK: - ================================================================================================

struct EventDetailView: View {
    let event: GuildEventDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var hasRecordedView = false
    @State private var showAttendConfirmation = false
    @State private var showUnAttendConfirmation = false
    @State private var showShareConfirmation = false
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .full
        df.timeStyle = .short
        return df
    }()
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and title
                HStack(alignment: .top, spacing: 12) {
                    UnifiedDatePill(date: event.eventDate, width: 56)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(dateFormatter.string(from: event.eventDate))
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
                    
                    UnifiedAuthorRowFromMembership(author: event.author)
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
                                Text(event.attendanceDisplay)
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
                            
                            Text(event.content)
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
                        title: event.isAttending ? "Attending" : "Attend",
                        imageName: event.isAttending ? "calendar.badge.checkmark" : "calendar.badge.plus",
                        backgroundColor: event.isAttending ? AppColors.whiteText.opacity(0.8) : AppColors.gradientBackgroundDark.opacity(0.2),
                        foregroundColor: event.isAttending ? Color.black : AppColors.whiteText.opacity(0.8),
                        strokeColor: event.isAttending ? Color.black : AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: {
                            if event.isAttending {
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
        Task {
            do {
                try await appState.attendEvent(eventId: event.id)
                leftDrawerViewModel.updateEventAttendance(
                    eventId: event.id,
                    isAttending: true,
                    attendanceCount: event.attendeeCount + 1
                )
                appState.showSuccess("Attending Event")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to attend Event")
            }
        }
    }
    
    private func unAttendEvent() {
        Task {
            do {
                try await appState.unAttendEvent(eventId: event.id)
                leftDrawerViewModel.updateEventAttendance(
                    eventId: event.id,
                    isAttending: false,
                    attendanceCount: max(0, event.attendeeCount - 1)
                )
                appState.showSuccess("Attendance cancelled")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to cancel attendance")
            }
        }
    }
    
    private func shareEvent() {
        Task {
            do {
                try await appState.shareEvent(eventId: event.id, friendId: UUID().uuidString)
                appState.showSuccess("Event Shared")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to share event")
            }
        }
    }
    
    private func recordEventView() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await appState.recordEventView(eventId: event.id)
                leftDrawerViewModel.markEventAsRead(eventId: event.id)
            } catch {
                print("Failed to record event view: \(error)")
            }
        }
    }
}

