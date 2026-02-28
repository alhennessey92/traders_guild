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
//  Includes: Create Announcements, Create Events, Guild Settings, Reports, Invite Members, Manage Members, Manage Roles
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
                Image(systemName: "shield.checkered")
                    .font(.title3)
                    .foregroundColor(AppColors.accentColor)
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
                    iconColor: .green
                ) {
                    bottomSheetContent = .createEvent
                }
            }
            
            Divider()
                .background(AppColors.whiteText.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Guild Settings Section - Admin/Owner only
            if rlAppState.canAdmin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guild Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                        .padding(.horizontal, 16)

                    AdminActionButton(
                        icon: "gearshape.fill",
                        title: "Guild Settings",
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
                        iconColor: .blue
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
                    iconColor: .blue
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
                        iconColor: .orange
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
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var preview: String = ""
    @State private var isImportant: Bool = false
    @State private var isSubmitting: Bool = false
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count >= 3 &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count >= 3
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    UnifiedIconBadge(
                        icon: "megaphone.fill",
                        color: AppColors.accentColor,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Announcement")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Post to your guild members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Form
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("Announcement title...", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Preview Field (Optional)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Preview")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            TextField("Short preview text...", text: $preview)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Content Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Content")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $content)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }
                        
                        // Important Toggle
                        Toggle(isOn: $isImportant) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mark as Important")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Highlights this announcement")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
                
                Divider()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: createAnnouncement) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Posting..." : "Post Announcement")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isSubmitting)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // Dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
    }
    
    private func createAnnouncement() {
        guard isValid else { return }
        isSubmitting = true
        
        Task {
            do {
                let newAnnouncement = try await rlAppState.createAnnouncement(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    preview: preview.isEmpty ? nil : preview.trimmingCharacters(in: .whitespacesAndNewlines),
                    isImportant: isImportant
                )
                
                // Add to local cache at the beginning
                leftDrawerViewModel.announcements.insert(newAnnouncement, at: 0)
                
                dismiss()
            } catch {
                isSubmitting = false
                // Error is already shown by rlAppState
            }
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
    @State private var eventDate: Date = Date().addingTimeInterval(86400) // Tomorrow
    @State private var isImportant: Bool = false
    @State private var isSubmitting: Bool = false
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count >= 3 &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count >= 3 &&
        !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        preview.count >= 3 &&
        eventDate > Date() // Must be in the future
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    UnifiedIconBadge(
                        icon: "calendar.badge.plus",
                        color: .green,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Event")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Schedule a guild event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Form
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Event Title")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("What's the event?", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Date & Time Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date & Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            DatePicker(
                                "Event Date",
                                selection: $eventDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        
                        // Preview Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preview Text")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("Short description for the list view...", text: $preview)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Content Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Full Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $content)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }
                        
                        // Important Toggle
                        Toggle(isOn: $isImportant) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Featured Event")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Highlight this event")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
                
                Divider()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: createEvent) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Creating..." : "Create Event")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isSubmitting)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // Dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
    }
    
    private func createEvent() {
        guard isValid else { return }
        isSubmitting = true
        
        Task {
            do {
                let newEvent = try await rlAppState.createEvent(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    preview: preview.trimmingCharacters(in: .whitespacesAndNewlines),
                    eventDate: eventDate,
                    isImportant: isImportant
                )
                
                // Add to local cache at the beginning
                leftDrawerViewModel.upcomingEvents.insert(newEvent, at: 0)
                
                dismiss()
            } catch {
                isSubmitting = false
                // Error is already shown by rlAppState
            }
        }
    }
}
