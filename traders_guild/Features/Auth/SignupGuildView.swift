//
//  SignupGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//

//
//  SignupGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//

import SwiftUI

// Step 3: Guild Selection
struct SignupGuildView: View {
    @Binding var data: SignupData
    @Binding var path: [SignupStep]
    @EnvironmentObject var appState: AppState
    
    // MARK: - Local State
    @State private var availableGuilds: [GuildDTO] = []
    @State private var isLoadingGuilds: Bool = false
    @State private var selectedGuild: GuildDTO?

    var body: some View {
        ZStack {
            StaticAuthBackgroundView()
            
            VStack(spacing: 0) {
                // Fixed header text
                Text("Now you got the info, let's join a Guild!")
                    .font(.title.bold())
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                
                // Fixed divider
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 0.5)
                
                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if isLoadingGuilds {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.whiteText))
                                    .scaleEffect(1.2)
                                
                                Text("Finding available guilds...")
                                    .foregroundColor(AppColors.greyText)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            
                        } else if availableGuilds.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppColors.greyText.opacity(0.6))
                                
                                Text("No available guilds")
                                    .font(.headline)
                                    .foregroundColor(AppColors.whiteText)
                                
                                Text("All guilds are currently full or closed. You can still create your account and join a guild later.")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.greyText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            
                        } else {
                            // Guild list
                            LazyVStack(spacing: 12) {
                                ForEach(availableGuilds) { guild in
                                    GuildSelectionRow(
                                        guild: guild,
                                        isSelected: selectedGuild?.id == guild.id
                                    ) {
                                        selectGuild(guild)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 100) // Space for bottom button
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if !path.isEmpty { path.removeLast() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(AppColors.unhighlightedButtonBackground)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("TG")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.fadedBackground)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // ✅ Helper text when nothing selected
                if selectedGuild == nil {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.greyText)
                        Text("Please select a guild to continue")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Divider()
                    .frame(height: 1)
                    .background(Color.gray.opacity(0.3))
                
                HStack {
                    Spacer()
                    StandardActionButton(
                        title: selectedGuild != nil ? "Join \(selectedGuild!.name)" : "Select a Guild",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ) {
                        Task {
                            await handleSignup()
                        }
                    }
                    .disabled(selectedGuild == nil)
                    .opacity(selectedGuild == nil ? 0.5 : 1.0)
                    .padding(.top)
                    .padding(.trailing)
                }
            }
        }
        .task {
            await loadGuilds()
        }
        .refreshable {
            await loadGuilds()
        }
    }
    
    // MARK: - Actions
    
    private func loadGuilds() async {
        isLoadingGuilds = true
        defer { isLoadingGuilds = false }
        
        do {
            availableGuilds = try await appState.fetchOpenGuilds()
        } catch {
            // Error automatically shown by global alert
        }
    }
    
    private func selectGuild(_ guild: GuildDTO) {
        selectedGuild = guild
        data.selectedGuildId = guild.id
    }
    
    private func handleSignup() async {
        do {
            try await appState.signUp(data: data)
            
            // TODO: Add guild joining functionality when backend is ready
            // If a guild was selected, join it after signup
            // if let guildId = data.selectedGuildId {
            //     try await appState.joinGuild(guildId: guildId)  
            // }
        } catch {
            // Error automatically shown by global alert
        }
    }
}

// MARK: - Guild Selection Row Component
struct GuildSelectionRow: View {
    let guild: GuildDTO
    let isSelected: Bool
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
                            .foregroundColor(roleForegroundColor(for: .admin))
                            .fontWeight(roleWeight(for: .admin))
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
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.whiteText.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    private func roleForegroundColor(for role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    private func roleWeight(for role: UserRole) -> Font.Weight {
        switch role {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 12) {
//                // Guild Image
//                AsyncImage(url: URL(string: guild.imageURL ?? "")) { image in
//                    image
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                } placeholder: {
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(AppColors.greyText.opacity(0.3))
//                        .overlay(
//                            Image(systemName: "building.2")
//                                .foregroundColor(AppColors.greyText.opacity(0.6))
//                                .font(.system(size: 20))
//                        )
//                }
//                .frame(width: 50, height: 50)
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//                
//                // Guild Info
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Text(guild.name)
//                            .font(.headline)
//                            .foregroundColor(AppColors.whiteText)
//                            .lineLimit(1)
//                        
//                        Spacer()
//                        
//                        // Selection indicator
//                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
//                            .foregroundColor(isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.6))
//                            .font(.system(size: 20))
//                    }
//                    
//                    // Show description only if not empty
//                    if !guild.description.isEmpty {
//                        Text(guild.description)
//                            .font(.subheadline)
//                            .foregroundColor(AppColors.greyText)
//                            .lineLimit(2)
//                    }
//                    
//                    HStack {
//                        HStack(spacing: 4) {
//                            Image(systemName: "person.2")
//                                .font(.caption)
//                                .foregroundColor(AppColors.greyText.opacity(0.8))
//                            Text("\(guild.memberCount) members")
//                                .font(.caption)
//                                .foregroundColor(AppColors.greyText.opacity(0.8))
//                        }
//                        
//                        Spacer()
//                        
//                        
//                        HStack(spacing: 4) {
//                            Image(systemName: "star.fill")
//                                .font(.caption)
//                                .foregroundColor(AppColors.greyText.opacity(0.8))
//                            
//                            Text("\(guild.reputation)")
//                                .font(.caption)
//                                .foregroundColor(AppColors.greyText.opacity(0.8))
//                            
//                        }
//                        
//                    }
//                }
//                
//                Spacer()
//            }
//            .padding(16)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(isSelected ? AppColors.whiteText.opacity(0.3) : Color.clear, lineWidth: 1)
//                    )
//            )
//        }
//        .buttonStyle(.plain)
//    }
}

#Preview {
    NavigationStack {
        SignupGuildView(
            data: .constant(SignupData()),
            path: .constant([])
        )
        .environmentObject(AppState())
    }
}
