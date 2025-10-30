//
//  ChooseGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 26/10/2025.
//


import SwiftUI

struct GuildSelectionFullView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedGuild: GuildDTO?
    @Environment(\.dismiss) var dismiss
    
    // Check if this is first login (required) or switching (optional)
    private var isRequired: Bool {
        appState.currentGuild == nil
    }
    
    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            
            VStack(spacing: 0) {
                VStack(spacing:0){
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
                        .background(Color.gray.opacity(0.3))
                }
                .background(AppColors.gradientBackgroundDark.opacity(0.6))
                
                // Guild List
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.availableGuildsForSelection) { guild in
                            GuildSelectionRowFull(
                                guild: guild,
                                isSelected: selectedGuild?.id == guild.id,
                                isCurrent: appState.currentGuild?.id == guild.id
                            ) {
                                selectedGuild = guild
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
                    .background(Color.gray.opacity(0.3))
                
                HStack {
                    Spacer()
                    StandardActionButton(
                        title: selectedGuild != nil ? "Enter \(selectedGuild!.name)" : "Select a Guild",
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
            }.background(AppColors.gradientBackgroundDark.opacity(0.6))
        }
        .onAppear {
            // Pre-select current guild if switching
            if !isRequired, let currentGuild = appState.currentGuild {
                selectedGuild = currentGuild
            }
        }
    }
    
    private func handleContinue() {
        guard let guild = selectedGuild else { return }
        
        // Set as current guild
        appState.selectGuild(guild)
        
        // Close the view
        appState.showGuildSelectionSheet = false
    }
}

// MARK: - Guild Selection Row (Full View Version)

struct GuildSelectionRowFull: View {
    let guild: GuildDTO
    let isSelected: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.title2)
                            .foregroundColor(AppColors.accentColor.opacity(0.6))
                        
                        Text("\(guild.name)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        + Text(" Guild")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    Text("\(guild.memberCount) Members - \(guild.statusText)")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.leading, 15)
                    
                    HStack(spacing: 3) {
                        Text("\(guild.owner.name)")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text("Admin")
                            .font(.caption)
                            .foregroundColor(guild.ownerRole.roleForegroundColor)
                            .fontWeight(guild.ownerRole.roleFontWeight)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(guild.reputationDisplay)")
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
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.6))
                    .font(.system(size: 20))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.whiteText.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
//    private func mockOnlineCount(for guild: GuildDTO) -> Int {
//        Int(Double(guild.memberCount) * 0.3)
//    }
}

#Preview {
    GuildSelectionFullView()
        .environmentObject(AppState())
}
