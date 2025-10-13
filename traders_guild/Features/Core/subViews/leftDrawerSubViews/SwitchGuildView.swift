//
//  SwitchGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//
import SwiftUI

// MARK: - Handle the sheet content for Guild-related views
// 🆕 NEW: Enum for managing hierarchical navigation between guild views
enum GuildSheetContent {
    case switchGuild    // Main switch guild view
    case createGuild    // Create new guild form
    case joinGuild      // Search and join existing guilds
}

struct SwitchGuildView: View {
    let onBack: () -> Void
    // 🆕 NEW: State management for hierarchical navigation
    @State private var currentContent: GuildSheetContent = .switchGuild
    @Binding var selectedDetent: PresentationDetent  // For managing sheet size
    
    var body: some View {
        Group {
            // 🆕 NEW: Switch between different guild-related views
            switch currentContent {
            case .switchGuild:
                switchGuildMainView
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .identity
                    ))
            case .createGuild:
                // 🆕 NEW: Navigate to Create Guild view
                CreateGuildView(onBack: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentContent = .switchGuild
                        // Keep current detent
                    }
                })
                .transition(.opacity)
            case .joinGuild:
                // 🆕 NEW: Navigate to Join Guild view
                JoinGuildView(onBack: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentContent = .switchGuild
                        // Keep current detent
                    }
                })
                .transition(.opacity)
            }
        }
    }
    
    private var switchGuildMainView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 20)
            .padding(.horizontal)
           
            HStack (spacing: 8){
                Image(systemName: "arrow.trianglehead.2.counterclockwise")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Switch Guild")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                    
                
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            
            
            // Guild list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        GuildSwitchRow(guildName: "Guild \(index + 1)")
                    }
                }
               
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            Spacer()
            
            Divider()

            HStack(spacing: 8) {
                // 🆕 NEW: Updated to navigate to Join Guild view
                DrawerActionButton(
                    title: "Join a Guild",
                    imageName: "person.2.shield",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .joinGuild
                            selectedDetent = .large  // Expand for join guild
                        }
                    }
                )
                
//                DrawerActionButton(
//                    title: "Join a Guild",
//                    imageName: "person.2.shield",
//                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
//                    foregroundColor: AppColors.whiteText.opacity(0.8),
//                    strokeColor: AppColors.whiteText.opacity(0.3),
//                    strokeWidth: 0.5,
//                    action: {
////                        withAnimation(.easeInOut(duration: 0.3)) {
////                            currentContent = .settings
////                            selectedDetent = .large  // EXPAND TO LARGE FOR SETTINGS
//                       // }
//                    }
//                )
                
                
                Spacer()
                
                // 🆕 NEW: Updated to navigate to Create Guild view with new icon
                DrawerActionButton(
                    title: "Create a Guild",
                    imageName: "xmark.shield",
                    backgroundColor: AppColors.whiteText.opacity(0.6),
                    foregroundColor: Color.black,
                    strokeColor: Color.black,
                    strokeWidth: 0.5,
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentContent = .createGuild
                            selectedDetent = .large  // Expand for create guild
                        }
                    }
                )
                
                
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding(.horizontal)
    }
}




// Handle individual guild switch
struct GuildSwitchRow: View {
    let guildName: String
    
    var body: some View {
        Button(action: {
            // Handle guild selection
        }) {
            HStack(spacing: 6) {
                Image(systemName: "shield.pattern.checkered")
                    .font(.headline)
                    .foregroundColor(AppColors.accentColor.opacity(0.6))
                
                Text("KAOS")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
                + Text(" Guild")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentColor)
                
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(AppColors.accentColor)
                
            }
            .padding(.vertical, 4)
            
        }
    }
}


//MARK: - Join a guild main view + search for guild
// 🆕 NEW: Complete Join Guild view with search and guild discovery

struct JoinGuildView: View {
    let onBack: () -> Void
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 20)
            .padding(.horizontal)
           
            HStack (spacing: 8){
                Image(systemName: "person.2.shield")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Join a Guild")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.greyText)
                TextField("Search for guilds...", text: $searchText)
                    .foregroundColor(AppColors.whiteText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                    .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
            )
            .padding(.top, 10)
            .padding(.horizontal)
            
            // Guild search results
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<8) { index in
                        JoinGuildRow(guildName: "Guild \(index + 1)", memberCount: Int.random(in: 10...500))
                    }
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// 🆕 NEW: Individual guild row for join guild list
struct JoinGuildRow: View {
    let guildName: String
    let memberCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Guild icon
            Image(systemName: "shield.pattern.checkered")
                .font(.title2)
                .foregroundColor(AppColors.accentColor.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(guildName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Text("\(memberCount) members")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Handle join request
            }) {
                Text("Join")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accentColor)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.gradientBackgroundDark.opacity(0.1))
                .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
        )
      
    }
}


// MARK: - Join a guild - Expanded Row


// MARK: - Join a guild - sign up sheet


// MARK: - Create a guild main view
// 🆕 NEW: Complete Create Guild form with validation

struct CreateGuildView: View {
    let onBack: () -> Void
    @State private var guildName: String = ""
    @State private var guildDescription: String = ""
    @State private var isPrivate: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 20)
            .padding(.horizontal)
           
            HStack (spacing: 8){
                Image(systemName: "plus.shield")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Text("Create a Guild")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Guild name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Guild Name")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        
                        TextField("Enter guild name", text: $guildName)
                            .foregroundColor(AppColors.whiteText)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                    .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Guild description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        
                        TextField("Describe your guild...", text: $guildDescription, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(AppColors.whiteText)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                                    .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Privacy toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private Guild")
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)
                            Text("Require approval to join")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isPrivate)
                            .tint(AppColors.accentColor)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            Divider()
            
            // Create button
            Button(action: {
                // Handle guild creation
            }) {
                Text("Create Guild")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.whiteText.opacity(0.9))
                    .cornerRadius(10)
            }
            .disabled(guildName.isEmpty)
            .opacity(guildName.isEmpty ? 0.5 : 1.0)
            .padding(.top, 10)
        }
        .padding(.horizontal)
    }
}


// MARK: - Create a guild add watchlist


// MARK: - Create a guild Invite Users
