//
//  MessagingSettings.swift
//  traders_guild
//
//  Created by Al Hennessey on 02/11/2025.
//

import SwiftUI

// MARK: - Chatroom Settings View
struct ChatroomSettingsView: View {
    let chatroom: GuildChatroomDTO
    @EnvironmentObject var appState: AppState
    
    @State private var notificationsEnabled = true
    @State private var showMuteOptions = false
    @State private var showLeaveConfirmation = false
    @State private var showReportOptions = false
    
    var body: some View {
        ZStack {
            // ✅ Background that extends to safe area
            
            StaticMessagingBackgroundView()
                
            
            ScrollView {
                VStack(spacing: 0) {
                    // Chatroom Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.4))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "number")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.whiteText.opacity(0.4))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chatroom.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.whiteText)
                                
                                if let description = chatroom.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(AppColors.greyText)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Push Notifications",
                            subtitle: "Get notified about new messages",
                            isOn: $notificationsEnabled,
                            iconColor: AppColors.accentColor
                        )
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Chatroom",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report Chatroom",
                            subtitle: "Report inappropriate content",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Chatroom Actions Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Chatroom")
                        
                        SettingsButtonRow(
                            icon: "arrow.right.square.fill",
                            title: "Leave Chatroom",
                            subtitle: "You can rejoin anytime",
                            iconColor: .red
                        ) {
                            showLeaveConfirmation = true
                        }
                    }
                    
                    Spacer(minLength: 50)  // ✅ Add some bottom padding
                }
            }
        }
        .alert("Mute Chatroom", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteChatroom(duration: .minutes15) }
            Button("1 Hour") { muteChatroom(duration: .hour1) }
            Button("8 Hours") { muteChatroom(duration: .hours8) }
            Button("24 Hours") { muteChatroom(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this chatroom?")
        }
        .alert("Leave Chatroom", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                leaveChatroom()
            }
        } message: {
            Text("Are you sure you want to leave #\(chatroom.name)? You can rejoin at any time.")
        }
        .confirmationDialog("Report Chatroom", isPresented: $showReportOptions, titleVisibility: .visible) {
            Button("Spam or Scam") { reportChatroom(reason: "spam") }
            Button("Harassment") { reportChatroom(reason: "harassment") }
            Button("Inappropriate Content") { reportChatroom(reason: "inappropriate") }
            Button("Other") { reportChatroom(reason: "other") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this chatroom?")
        }
    }
    
    private func muteChatroom(duration: MuteDuration) {
        Task {
            do {
                // TODO: Implement mute API call
                appState.showSuccess("Chatroom muted for \(duration.displayName)")
            } catch {
                appState.showError(error, title: "Failed to Mute Chatroom")
            }
        }
    }
    
    private func leaveChatroom() {
        Task {
            do {
                // TODO: Implement leave chatroom API call
                appState.showSuccess("Left chatroom")
            } catch {
                appState.showError(error, title: "Failed to Leave Chatroom")
            }
        }
    }
    
    private func reportChatroom(reason: String) {
        Task {
            do {
                // TODO: Implement report API call
                appState.showInfo("Report submitted for review")
            } catch {
                appState.showError(error, title: "Failed to Report Chatroom")
            }
        }
    }
}

// MARK: - DM Settings View
struct DMSettingsView: View {
    let userDM: DMDTO
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messagingManager: MessagingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var notificationsEnabled = true
    @State private var showMuteOptions = false
    @State private var showBlockConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showReportOptions = false
    
    var body: some View {
        ZStack {
            // ✅ Background that extends to safe area
            StaticMessagingBackgroundView()
            
            ScrollView {
                VStack(spacing: 0) {
                    // User Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppColors.accentColor.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(userDM.participant.globalMember.username.prefix(2)))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentColor)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(userDM.participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(AppColors.sheetBackground, lineWidth: 2)
                                        )
                                        .padding(.trailing, 2)
                                        .padding(.bottom, 2)
                                }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userDM.participant.globalMember.username)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.whiteText)
                                
                                HStack(spacing: 4) {
                                    Text(userDM.participant.roleInGuild.rawValue)
                                        .font(.caption)
                                        .foregroundColor(userDM.participant.roleInGuild.roleForegroundColor)
                                        .fontWeight(userDM.participant.roleInGuild.roleFontWeight)
                                    
                                    Circle()
                                        .fill(AppColors.whiteText.opacity(0.7))
                                        .frame(width: 3, height: 3)
                                        .padding(.horizontal, 3)
                                    
                                    Image(systemName: "shield.pattern.checkered")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.accentColor)
                                    
                                    Text("\(userDM.participant.reputation)")
                                        .font(.caption)
                                        .foregroundColor(AppColors.accentColor)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Push Notifications",
                            subtitle: "Get notified about new messages",
                            isOn: $notificationsEnabled,
                            iconColor: AppColors.accentColor
                        )
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Conversation",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        if !userDM.participant.isBlocked {
                            SettingsButtonRow(
                                icon: "nosign",
                                title: "Block User",
                                subtitle: "Stop receiving messages from this user",
                                iconColor: .red
                            ) {
                                showBlockConfirmation = true
                            }
                        } else {
                            SettingsButtonRow(
                                icon: "checkmark.circle.fill",
                                title: "Unblock User",
                                subtitle: "Allow messages from this user",
                                iconColor: AppColors.bullCandleGreen
                            ) {
                                unblockUser()
                            }
                        }
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report User",
                            subtitle: "Report inappropriate behavior",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Conversation Actions Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Conversation")
                        
                        SettingsButtonRow(
                            icon: "trash.fill",
                            title: "Delete Conversation",
                            subtitle: "Remove all messages permanently",
                            iconColor: .red
                        ) {
                            showDeleteConfirmation = true
                        }
                    }
                    
                    Spacer(minLength: 50)  // ✅ Add some bottom padding
                }
            }
        }
        .alert("Mute Conversation", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteConversation(duration: .minutes15) }
            Button("1 Hour") { muteConversation(duration: .hour1) }
            Button("8 Hours") { muteConversation(duration: .hours8) }
            Button("24 Hours") { muteConversation(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this conversation?")
        }
        .alert("Block User", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(userDM.participant.globalMember.username)? You won't see their messages or activity.")
        }
        .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }
        .confirmationDialog("Report User", isPresented: $showReportOptions, titleVisibility: .visible) {
            Button("Spam") { reportUser(reason: "spam") }
            Button("Harassment") { reportUser(reason: "harassment") }
            Button("Inappropriate Content") { reportUser(reason: "inappropriate") }
            Button("Scam or Fraud") { reportUser(reason: "scam") }
            Button("Other") { reportUser(reason: "other") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this user?")
        }
    }
    
    private func muteConversation(duration: MuteDuration) {
        Task {
            do {
                appState.showSuccess("Conversation muted for \(duration.displayName)")
            } catch {
                appState.showError(error, title: "Failed to Mute Conversation")
            }
        }
    }
    
    private func blockUser() {
        Task {
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.blockUser(guildId: guildId, userId: userDM.participant.globalMember.id)
                appState.showSuccess("User blocked successfully")
                messagingManager.closeMessage()
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Block User")
            }
        }
    }
    
    private func unblockUser() {
        Task {
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.unBlockUser(guildId: guildId, userId: userDM.participant.globalMember.id)
                appState.showSuccess("User unblocked")
            } catch {
                appState.showError(error, title: "Failed to Unblock User")
            }
        }
    }
    
    private func deleteConversation() {
        Task {
            do {
                appState.showSuccess("Conversation deleted")
                messagingManager.closeMessage()
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Delete Conversation")
            }
        }
    }
    
    private func reportUser(reason: String) {
        Task {
            do {
                appState.showInfo("Report submitted for review")
            } catch {
                appState.showError(error, title: "Failed to Report User")
            }
        }
    }
}

// MARK: - Settings Components
struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.greyText)
            Spacer()
        }
        .padding(.horizontal, 25)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let iconColor: Color
    
    init(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>, iconColor: Color) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accentColor)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 12)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, iconColor: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mute Duration Helper
enum MuteDuration {
    case minutes15
    case hour1
    case hours8
    case hours24
    
    var displayName: String {
        switch self {
        case .minutes15: return "15 minutes"
        case .hour1: return "1 hour"
        case .hours8: return "8 hours"
        case .hours24: return "24 hours"
        }
    }
}
