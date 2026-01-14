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
                        .background(Color.gray.opacity(0.3))
                }
                .background(AppColors.gradientBackgroundDark.opacity(0.6))
                
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
                    .background(Color.gray.opacity(0.3))
                
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
            .background(AppColors.gradientBackgroundDark.opacity(0.6))
        }
        .onAppear {
            // Pre-select current guild if switching
            if !isRequired, let currentGuild = appState.currentGuild {
                selectedGuild = appState.userGuilds.first(where: { $0.guild.id == currentGuild.id })
            }
        }
    }
    
    private func handleContinue() {
        guard let selected = selectedGuild else { return }
        
        // Set as current guild
        appState.selectGuild(id: selected.guild.id)
        
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
                    
                    // Owner info (TODO: backend will return embedded owner)
                    HStack(spacing: 3) {
                        Text("Owner Name")  // TODO: item.guild.owner.displayName
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text("Admin")  // TODO: item.guild.ownerRole.displayName
                            .font(.caption)
                            .foregroundColor(.red)  // TODO: item.guild.ownerRole.color
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                    
                    // Members online
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
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
                    
                    // User's role and reputation in this guild
                    HStack(spacing: 2) {
                        Text("You are a ")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                       
                        Text(item.role.displayName)
                            .font(.caption)
                            .foregroundColor(item.role.color)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.top, 1)
                            .padding(.leading, 3)
                            .padding(.trailing, 3)
                        
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(item.membership.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
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
                    .fill(isSelected ? AppColors.whiteText.opacity(0.1) : AppColors.gradientBackgroundDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.whiteText.opacity(0.3) : Color.clear, lineWidth: 1)
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










////
////  ChooseGuildView.swift
////  traders_guild
////
////  Created by Al Hennessey on 26/10/2025.
////
//
//
//import SwiftUI
//
//struct GuildSelectionFullView: View {
//    @EnvironmentObject var appState: AppState
//    @EnvironmentObject var RLAppState: RLAppState
//    @State private var selectedGuild: RLGuildMembershipDTO?
//    @Environment(\.dismiss) var dismiss
//    
//    // Check if this is first login (required) or switching (optional)
//    private var isRequired: Bool {
//        RLAppState.currentGuild == nil
//    }
//    
//    var body: some View {
//        ZStack {
//            StaticAuthBackgroundView()
//            
//            VStack(spacing: 0) {
//                VStack(spacing:0){
//                    // Header with back button (only if not required)
//                    HStack {
//                        if !isRequired {
//                            Button {
//                                RLAppState.showGuildSelectionSheet = false
//                            } label: {
//                                Image(systemName: "xmark")
//                                    .font(.title3)
//                                    .foregroundColor(AppColors.whiteText)
//                                    .padding()
//                            }
//                        } else {
//                            Spacer()
//                                .frame(width: 44, height: 44)
//                        }
//                        
//                        Spacer()
//                        
//                        Text("TG")
//                            .font(.largeTitle)
//                            .fontWeight(.heavy)
//                            .foregroundColor(AppColors.fadedBackground)
//                        
//                        Spacer()
//                        
//                        // Placeholder for symmetry
//                        Spacer()
//                            .frame(width: 44, height: 44)
//                    }
//                    .padding(.horizontal)
//                    .padding(.top, 8)
//                    
//                    // Title Section
//                    VStack(spacing: 8) {
//                        Text(isRequired ? "Select Your Guild" : "Switch Guild")
//                            .font(.title.bold())
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        Text(isRequired ? "Choose which guild you'd like to view" : "Select a different guild to switch to")
//                            .font(.subheadline)
//                            .foregroundColor(AppColors.greyText)
//                            .multilineTextAlignment(.center)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 20)
//                    .padding(.horizontal)
//                    
//                    Divider()
//                        .background(Color.gray.opacity(0.3))
//                }
//                .background(AppColors.gradientBackgroundDark.opacity(0.6))
//                
//                // Guild List
//                ScrollView(showsIndicators: false) {
//                    LazyVStack(spacing: 12) {
//                        ForEach(appState.availableGuildsForSelection) { guild in
//                            GuildSelectionRowFull(
//                                guild: guild,
//                                isSelected: selectedGuild?.id == guild.id,
//                                isCurrent: appState.currentGuild?.id == guild.id
//                            ) {
//                                selectedGuild = guild
//                            }
//                        }
//                    }
//                    .padding()
//                    
//                    Spacer(minLength: 100)
//                }
//            }
//        }
//        .safeAreaInset(edge: .bottom) {
//            VStack(spacing: 0) {
//                Divider()
//                    .background(Color.gray.opacity(0.3))
//                
//                HStack {
//                    Spacer()
//                    StandardActionButton(
//                        title: selectedGuild != nil ? "Enter \(selectedGuild!.guild.name)" : "Select a Guild",
//                        backgroundColor: AppColors.whiteText,
//                        foregroundColor: AppColors.gradientBackgroundDark
//                    ) {
//                        handleContinue()
//                    }
//                    .disabled(selectedGuild == nil)
//                    .opacity(selectedGuild == nil ? 0.5 : 1.0)
//                    .padding(.top)
//                    .padding(.trailing)
//                }
//            }.background(AppColors.gradientBackgroundDark.opacity(0.6))
//        }
//        .onAppear {
//            // Pre-select current guild if switching
//            if !isRequired, let currentGuild = appState.currentGuild {
//                selectedGuild = currentGuild
//            }
//        }
//    }
//    
//    private func handleContinue() {
//        guard let guild = selectedGuild else { return }
//        
//        // Set as current guild
//        appState.selectGuild(guild)
//        
//        // Close the view
//        appState.showGuildSelectionSheet = false
//    }
//}
//
//// MARK: - Guild Selection Row (Full View Version)
//
//struct GuildSelectionRowFull: View {
//    let guild: GuildMembershipDTO
//    let isSelected: Bool
//    let isCurrent: Bool
//    let onTap: () -> Void
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 20) {
//                VStack(alignment: .leading, spacing: 6) {
//                    HStack {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.title2)
//                            .foregroundColor(AppColors.accentColor.opacity(0.6))
//                        
//                        Text("\(guild.guild.name)")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        + Text(" Guild")
//                            .font(.title2)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//                    
//                    Text("\(guild.guild.memberCount) Members - \(guild.guild.statusText)")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText)
//                        .padding(.leading, 15)
//                    
//                    HStack(spacing: 3) {
//                        Text("\(guild.guild.owner.name)")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                            .lineLimit(1)
//                        
//                        Text("-")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        Text("\(guild.guild.ownerRole.rawValue)")
//                            .font(.caption)
//                            .foregroundColor(guild.guild.ownerRole.roleForegroundColor)
//                            .fontWeight(guild.guild.ownerRole.roleFontWeight)
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//                    
//                    HStack(spacing: 2) {
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(guild.guild.reputationDisplay)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text(" Guild Reputation")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.6))
//                            .lineLimit(1)
//                    }
//                    .padding(.leading, 15)
//                    
//                    
//                    Divider()
//                    
//                    HStack(spacing: 2){
//                        Text("You are a ")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText)
//                       
//                        Text(guild.roleInGuild.rawValue)
//                            .font(.caption)
//                            .foregroundColor(guild.roleInGuild.roleForegroundColor)
//                            .fontWeight(guild.roleInGuild.roleFontWeight)
//                            .lineLimit(1)
//            
//                        
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 3, height: 3)
//                            .padding(.top, 1)
//                            .padding(.leading, 3)
//                            .padding(.trailing, 3)
//                        
//                        
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(guild.reputation)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                        
//                    }.padding(.leading, 15)
//                }
//                
//                Spacer()
//                
//                // Selection indicator
//                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
//                    .foregroundColor(isSelected ? AppColors.whiteText : AppColors.greyText.opacity(0.6))
//                    .font(.system(size: 20))
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
//    
////    private func mockOnlineCount(for guild: GuildDTO) -> Int {
////        Int(Double(guild.memberCount) * 0.3)
////    }
//}
//
//#Preview {
//    GuildSelectionFullView()
//        .environmentObject(AppState())
//}
