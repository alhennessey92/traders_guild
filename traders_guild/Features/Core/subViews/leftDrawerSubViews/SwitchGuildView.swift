//
//  SwitchGuildView.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//


import SwiftUI

// MARK: - Switch Guild Main View
struct SwitchGuildView: View {
    let onBack: () -> Void
    @Binding var selectedDetent: PresentationDetent
    
    // State for full screen covers
    @State private var showJoinGuild = false
    @State private var showCreateGuild = false
    
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
           
            HStack(spacing: 8) {
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

            HStack(spacing: 20) {
                Spacer()
                DrawerActionButton(
                    title: "Join a Guild",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: {
                        showJoinGuild = true
                    }
                )
                
                Spacer()
                
                DrawerActionButton(
                    title: "Create a Guild",
                    backgroundColor: AppColors.whiteText.opacity(0.8),
                    foregroundColor: Color.black,
                    strokeColor: Color.black,
                    strokeWidth: 0.5,
                    action: {
                        showCreateGuild = true
                    }
                )
                Spacer()
            }
//            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showJoinGuild) {
            JoinGuildFlowView()
        }
        .fullScreenCover(isPresented: $showCreateGuild) {
            CreateGuildFlowView()
        }
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

// MARK: - Join Guild Full Screen Flow
struct JoinGuildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGuild: Guild?
    @State private var showGuildDetail = false
    
    var body: some View {
        NavigationStack {
            JoinGuildView(
                onSelectGuild: { guild in
                    selectedGuild = guild
                    showGuildDetail = true
                }
            )
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.gradientBackgroundDark,
                        AppColors.gradientBackgroundDark,
                        AppColors.fadedBackground.opacity(0.6),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Join a Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppColors.whiteText)
                        
//                    BackButton(title: "Cancel", foregroundColor: AppColors.whiteText, action: {
//                        dismiss()
//                    })
                }
            }
            .navigationDestination(isPresented: $showGuildDetail) {
                if let guild = selectedGuild {
                    GuildDetailView(guild: guild, onJoin: {
                        // Handle successful join
                        dismiss()
                    })
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppColors.gradientBackgroundDark,
                                AppColors.gradientBackgroundDark,
                                AppColors.fadedBackground.opacity(0.6)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}


// MARK: - Main join a guild view
struct JoinGuildView: View {
    let onSelectGuild: (Guild) -> Void
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var allGuilds: [Guild] = Guild.sampleGuild
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Search bar with filter
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .font(.subheadline)
                    
                    TextField("Search...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.whiteText.opacity(0.06))
                .clipShape(Capsule())
                
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(AppColors.whiteText.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(AppColors.whiteText.opacity(0.04))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            // Guild search results
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(allGuilds) { guild in
                        JoinGuildRow(
                            guild: guild,
                            onTap: {
                                onSelectGuild(guild)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isSearchFocused = false
                hideKeyboard()
            }
            
        }
        .padding(.top, 10)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - View for guild row in searching for guild
struct JoinGuildRow: View {
    let guild: Guild
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            let role = guild.authorRole ?? .member
            let authorName = guild.authorName ?? "Unknown"
            
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
                    
                    Text("48 Members - Open")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText)
                        .padding(.leading, 15)
                    
                    HStack(spacing: 3) {
                        Text("\(authorName)")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(1)
                        
                        Text("-")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)
                        
                        Text(role.rawValue)
                            .font(.caption)
                            .foregroundColor(roleForegroundColor(for: role))
                            .fontWeight(roleWeight(for: role))
                            .lineLimit(1)
                    }
                    .padding(.leading, 15)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(guild.reputation)")
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
                
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText.opacity(0.5))
            }
            .padding(.top, 10)
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
}

// MARK: - Guild Detail View (for joining)
struct GuildDetailView: View {
    let guild: Guild
    let onJoin: () -> Void
    @State private var showJoinForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Guild header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("\(guild.name) Guild")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("48 Members")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        }
                    }
                    
                    Text(guild.description)
                        .font(.body)
                        .foregroundColor(AppColors.whiteText.opacity(0.8))
                        .padding(.top, 8)
                }
                .padding()
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(10)
                
                // Guild stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guild Stats")
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    
                    HStack {
                        StatBox(label: "Reputation", value: "\(guild.reputation)")
                        StatBox(label: "Accuracy", value: "\(guild.accuracy)%")
                        StatBox(label: "Members", value: "48")
                    }
                }
                .padding()
                .background(AppColors.whiteText.opacity(0.05))
                .cornerRadius(10)
                
                Spacer(minLength: 20)
                
                // Join button
                StandardActionButtonFullWidth(
                    title: "Request to Join",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: Color.black,
                    action: {
                        showJoinForm = true
                    }
                )
            }
            .padding()
        }
        .navigationTitle("Guild Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showJoinForm) {
            JoinGuildFormView(guild: guild, onComplete: onJoin)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.accentColor)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.gradientBackgroundDark.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Join Guild Form
struct JoinGuildFormView: View {
    let guild: Guild
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Why do you want to join \(guild.name) Guild?")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                
                TextField("Write your message...", text: $message, axis: .vertical)
                    .lineLimit(5...10)
                    .foregroundColor(AppColors.whiteText)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.gradientBackgroundDark.opacity(0.3))
                            .stroke(AppColors.whiteText.opacity(0.2), lineWidth: 1)
                    )
                
                Spacer()
                
                Button(action: {
                    // Handle join request
                    onComplete()
                }) {
                    Text("Send Request")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accentColor)
                        .cornerRadius(10)
                }
                .disabled(message.isEmpty)
                .opacity(message.isEmpty ? 0.5 : 1.0)
            }
            .padding()
            .navigationTitle("Join Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Create Guild Full Screen Flow
struct CreateGuildFlowView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            CreateGuildView(onComplete: {
                // Handle successful creation
                dismiss()
            })
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.gradientBackgroundDark,
                        AppColors.gradientBackgroundDark,
                        AppColors.fadedBackground.opacity(0.6)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Create a Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .toolbarBackground(AppColors.gradientBackgroundDark, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct CreateGuildView: View {
    let onComplete: () -> Void
    @State private var guildName: String = ""
    @State private var guildDescription: String = ""
    @State private var isPrivate: Bool = false
    
    var body: some View {
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
                
                Spacer(minLength: 100)
                
                // Create button
                Button(action: {
                    // Handle guild creation
                    onComplete()
                }) {
                    Text("Create Guild")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accentColor)
                        .cornerRadius(10)
                }
                .disabled(guildName.isEmpty)
                .opacity(guildName.isEmpty ? 0.5 : 1.0)
            }
            .padding()
        }
    }
}
