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
                            GuildCardView(
                                guild: item.guild,
                                style: .selection,
                                role: item.role,
                                isCurrent: appState.currentGuild?.id == item.guild.id,
                                isSelected: selectedGuild?.id == item.id,
                                onTap: { selectedGuild = item }
                            )
                        }
                    }
                    .padding()
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .keyboardPinnedBottomInset {
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


#Preview {
    GuildSelectionFullView()
        .environmentObject(RLAppState())
}
