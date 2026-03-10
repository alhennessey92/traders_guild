//
//  ChooseGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 26/10/2025.
//
//  UPDATED for flat DTOs - uses RLGuildWithMembership view model
//

import SwiftUI

struct GuildSelectionFullView: View {
    @EnvironmentObject var appState: RLAppState
    @State private var selectedGuild: RLGuildWithMembership?
    @Environment(\.dismiss) var dismiss
    
    // Check if this is first login (required) or switching (optional)
    private var isRequired: Bool {
        appState.currentGuild == nil
    }
    
    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Header with back button (only if not required)
                    HStack {
                        if !isRequired {
                            Button {
                                appState.showGuildSelectionSheet = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title3)
                                    .foregroundColor(AppColors.whiteText)
                                    .padding()
                            }
                        } else {
                            Spacer()
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        Text("TG")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(AppColors.fadedBackground)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Spacer()
                            .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Title Section
                    VStack(spacing: 8) {
                        Text(isRequired ? "Select Your Guild" : "Switch Guild")
                            .font(.title.bold())
                            .foregroundColor(AppColors.whiteText)
                        
                        Text(isRequired ? "Choose which guild you'd like to view" : "Select a different guild to switch to")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal)
                    
                    Divider()
                        .background(AppColors.surfaceGray30)
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
                
                // Guild List
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.userGuilds) { item in
                            GuildSelectionRowFull(
                                item: item,
                                isSelected: selectedGuild?.id == item.id,
                                isCurrent: appState.currentGuild?.id == item.guild.id
                            ) {
                                selectedGuild = item
                            }
                        }
                    }
                    .padding()
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.surfaceGray30)
                
                HStack {
                    Spacer()
                    StandardActionButton(
                        title: selectedGuild != nil ? "Enter \(selectedGuild!.guild.name)" : "Select a Guild",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        handleContinue()
                    }
                    .disabled(selectedGuild == nil)
                    .opacity(selectedGuild == nil ? 0.5 : 1.0)
                    .padding(.top)
                    .padding(.trailing)
                }
            }
            .background(AppColors.sheetBackground)
        }
        .onAppear {
            // Pre-select current guild if switching
            if !isRequired, let currentGuild = appState.currentGuild {
                selectedGuild = appState.userGuilds.first(where: { $0.guild.id == currentGuild.id })
            } else if isRequired, appState.userGuilds.count == 1 {
                // Login flow still requires selection screen even for one guild.
                selectedGuild = appState.userGuilds.first
            }
        }
    }
    
    private func handleContinue() {
        guard let selected = selectedGuild else { return }
        
        // Set as current guild. First-login path keeps transition visible slightly longer.
        let minimumDuration = isRequired ? 2.5 : 0.0
        appState.selectGuild(
            selected,
            showTransition: true,
            minimumTransitionDuration: minimumDuration
        )
        
        // Close the view
        appState.showGuildSelectionSheet = false
    }
}

// MARK: - Guild Selection Row (Full View Version)

struct GuildSelectionRowFull: View {
    let item: RLGuildWithMembership
    let isSelected: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    // Guild Name
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.title2)
                            .foregroundColor(AppColors.accentColor.opacity(0.6))
                        
                        Text("\(item.guild.name)")
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
                        
                        Text("@\(item.guild.ownerUsername ?? "owner")")
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
                        Text("\(item.guild.reputationDisplay)")
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
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.6))
                        .font(.system(size: 20))
                    
                    if isCurrent {
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(AppColors.accentColor)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? AppColors.whiteText.opacity(0.36) : AppColors.whiteText.opacity(0.28),
                                lineWidth: isSelected ? 1.2 : 1.15
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GuildSelectionFullView()
        .environmentObject(RLAppState())
}
