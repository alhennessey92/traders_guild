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
            }
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
            HStack(spacing: 12) {
                // Guild Image
                AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppColors.greyText.opacity(0.3))
                        .overlay(
                            Text(guild.name.prefix(1).uppercased())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                // Guild Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(guild.name)
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        if isCurrent {
                            Text("CURRENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.gradientBackgroundDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.whiteText)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        
                        Text("\(guild.memberCount) members")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                        
                        // Online indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .padding(.leading, 4)
                        
                        Text("\(mockOnlineCount(for: guild)) online")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                Circle()
                    .strokeBorder(
                        isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.4),
                        lineWidth: 2
                    )
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.whiteText : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(AppColors.gradientBackgroundDark)
                        }
                    }
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
    
    private func mockOnlineCount(for guild: GuildDTO) -> Int {
        Int(Double(guild.memberCount) * 0.3)
    }
}

#Preview {
    GuildSelectionFullView()
        .environmentObject(AppState())
}
