//
//  EventsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 08/10/2025.
//

import SwiftUI


private let monthFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("MMM")
    return df
}()

private let dayFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("d")
    return df
}()

private let timeFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("h:mm a")
    return df
}()


// MARK: - Announcements List View
struct EventsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.upcomingEvents.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading events...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            else if leftDrawerViewModel.upcomingEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No events yet")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    Text("Check back later for guild updates")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
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

struct EventRowView: View {
    let event: GuildEventDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // ✅ Top section: Date, content, and chevron
                HStack(alignment: .top, spacing: 12) {
                    // Date pill
                    VStack(spacing: 4) {
                        Text(monthFormatter.string(from: event.eventDate))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text(dayFormatter.string(from: event.eventDate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.whiteText)
                    }
                    .frame(width: 50)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)

                    // Event content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)

                        Text(event.content)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text("\(timeFormatter.string(from: event.eventDate)) • \(event.attendanceDisplay)")
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
                
                // ✅ Bottom section: Hosted by (full width)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hosted by")
                        .font(.caption2)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                    
                    HStack(spacing: 4) {
                        let author = event.author
                        
                        if author.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(author.globalMember.username)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                        
                        if author.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                
                        }
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.horizontal, 3)
                        
                        Text(author.roleInGuild.rawValue)
                            .font(.caption)
                            .foregroundColor(author.roleInGuild.roleForegroundColor)
                            .fontWeight(author.roleInGuild.roleFontWeight)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.horizontal, 3)
                        
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        
                        Text("\(author.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(event.isRead ? Color.clear : AppColors.accentColor.opacity(0.3), lineWidth: 1)
                    )
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




/// Detail content for an event presented in a sheet.
struct EventDetailView: View {
    let event: GuildEventDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var showUnAttendConfirmation = false
    @State private var showAttendConfirmation = false
    @State private var showShareConfirmation = false
    
    @State private var hasRecordedView = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                
                // START OF CONTENT
                
                // Header with date pill and title
                HStack(alignment: .top, spacing: 12) {
                    // Date pill
                    VStack(spacing: 4) {
                        Text(monthFormatter.string(from: event.eventDate))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text(dayFormatter.string(from: event.eventDate))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Title and time
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)  // ✅ Allow vertical wrapping
                            .frame(maxWidth: .infinity, alignment: .leading)  // ✅ Take full width
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text(timeFormatter.string(from: event.eventDate))
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                
                // Author and details info (similar to announcement)
                let author = event.author
                HStack(spacing: 3) {
                    if author.isBlocked {
                        Image(systemName: "nosign")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.bearCandleRed)
                    }
                    
                    Text("Hosted by \(author.globalMember.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if author.isFriend {
                        Image(systemName: "person.crop.circle")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                    }
                    
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    
                    Text(author.roleInGuild.rawValue)
                        .font(.caption)
                        .foregroundColor(author.roleInGuild.roleForegroundColor)
                        .fontWeight(author.roleInGuild.roleFontWeight)
                        .lineLimit(1)
                    
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    
                    Text("\(author.reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
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
                
                // END OF CONTENT
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 30)
            .padding(.horizontal)
            
            // Floating dismiss button overlaid on top
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
            // TODO: - List of friends to share to
            Button("Cancel", role: .cancel) { }
            Button("Share Event") {
                shareEvent()
            }
            
        } message: {
            Text("Share the event with Friends")
        }
        .onAppear {  // ✅ Record view when the view appears
            recordEventView()
        }
    }
    // MARK: - Action Methods
    private func attendEvent() {
        Task {
           
            do {
                try await appState.attendEvent(eventId: event.id)
                // ✅ Update cache - increment attendance
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
                // ✅ Update cache - decrement attendance
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
    
    // ✅ Function to record the view
    private func recordEventView() {
        // Prevent duplicate calls if view appears multiple times
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await appState.recordEventView(eventId: event.id)
                
                // 2. Update cache to mark as read
                leftDrawerViewModel.markEventAsRead(eventId: event.id)
                // Optionally: silently succeed, no need to show success message
            } catch {
                // Silently fail - viewing tracking is not critical
                // Or optionally log the error for debugging
                print("Failed to record event view: \(error)")
            }
        }
    }
}
