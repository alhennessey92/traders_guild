//
//  LeftDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI

// MARK: - Navigation State
enum DrawerNavigationState: Equatable {
    case main
    case announcements
    case chatrooms
    case topMarkers
    case leaderboard
    case guildWatchlist
    case events
    case userList
    case statistics
}

// MARK: - Bottom Sheet Content
enum BottomSheetContent: Identifiable {
    case chatroom(name: String)
    case announcement(id: Int, title: String)
    case userProfile(name: String)
    case event(id: Int)
    
    var id: String {
        switch self {
        case .chatroom(let name): return "chatroom-\(name)"
        case .announcement(let id, _): return "announcement-\(id)"
        case .userProfile(let name): return "profile-\(name)"
        case .event(let id): return "event-\(id)"
        }
    }
}

// MARK: - Main Drawer View
struct LeftDrawerMainView: View {
    let onClose: () -> Void
    
    @State private var dragTranslation: CGFloat = 0
    @State private var navigationState: DrawerNavigationState = .main
    @State private var bottomSheetContent: BottomSheetContent? = nil
    
    var body: some View {
        ZStack {
            // Main content that changes based on navigation state
            if navigationState == .main {
                MainDrawerView(
                    navigationState: $navigationState,
                    onClose: onClose,
                    dragTranslation: $dragTranslation
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            } else {
                SectionDrawerView(
                    navigationState: $navigationState,
                    currentSection: navigationState,
                    bottomSheetContent: $bottomSheetContent,
                    onClose: onClose,
                    dragTranslation: $dragTranslation
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }
        }
        .offset(x: dragTranslation)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                AppColors.drawerBackground.opacity(0.6)
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .frame(maxHeight: .infinity),
            alignment: .trailing
        )
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: 0,
                    bottomTrailing: LayoutConstants.cornerRadius,
                    topTrailing: LayoutConstants.cornerRadius
                )
            )
        )
        .shadow(radius: LayoutConstants.shadowRadius)
        .ignoresSafeArea()
        .sheet(item: $bottomSheetContent) { content in
            BottomSheetView(content: content)
        }
    }
}

// MARK: - Main Drawer View (Home Screen)
struct MainDrawerView: View {
    @Binding var navigationState: DrawerNavigationState
    let onClose: () -> Void
    @Binding var dragTranslation: CGFloat
    
    let menuItems: [(icon: String, title: String, state: DrawerNavigationState)] = [
        ("megaphone.fill", "Announcements", .announcements),
        ("bubble.left.and.bubble.right.fill", "Chatrooms", .chatrooms),
        ("chart.line.uptrend.xyaxis", "Today's Top Markers", .topMarkers),
        ("trophy.fill", "Leaderboard", .leaderboard),
        ("star.fill", "Guild Watchlist", .guildWatchlist),
        ("calendar.badge.clock", "Events", .events),
        ("person.3.fill", "User List", .userList),
        ("chart.bar.fill", "Statistics", .statistics)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section
            VStack {
                HStack {
                    Text("Guild")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        withAnimation(AnimationConstants.standard) { onClose() }
                    }) {
                        Image(systemName: "chevron.left.chevron.left.dotted")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("KAOS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    + Text(" Guild")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentColor)
                    Spacer()
                }
                
                HStack(spacing: 2) {
                    Text("12")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Members")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Text("52")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Online")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 7, height: 7)
                        .padding(.top, 0)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Spacer()
                }
                .padding(.top, 6)
                
                HStack(spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("3456")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    + Text(" Guild Reputation")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Text("78%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Guild Accuracy")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 6)
                
                Text("Tagline describing the main content and premis of the guild, or a short description of the guild")
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .multilineTextAlignment(.leading)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.top, 6)
            }
            .padding(.leading, 25)
            .padding(.trailing, 25)
            .padding(.bottom, 4)
            .padding(.top, 60)
            
            // Menu Items
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(menuItems, id: \.title) { item in
                        DrawerMenuButton(
                            icon: item.icon,
                            title: item.title,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    navigationState = item.state
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Footer
            VStack(spacing: 16) {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.top, 0)
                    .padding(.bottom, 6)
                HStack {
                    Button(action: {}) {
                        HStack{
                            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText.opacity(0.7))
                            Text("Switch Guild")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)
                        }
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                    }
                    .padding(.trailing, 6)
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                    }
                    .padding(.bottom, 3)
                }
            }
            .padding(.bottom, 40)
            .padding(.leading, 25)
            .padding(.trailing, 25)
        }
    }
}

// MARK: - Section Drawer View (Full Drawer Replacement)
struct SectionDrawerView: View {
    @Binding var navigationState: DrawerNavigationState
    let currentSection: DrawerNavigationState
    @Binding var bottomSheetContent: BottomSheetContent?
    let onClose: () -> Void
    @Binding var dragTranslation: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and title
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        navigationState = .main
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Guild")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.accentColor)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(AnimationConstants.standard) { onClose() }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
            
            // Section title
            HStack {
                Image(systemName: sectionIcon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
                Text(sectionTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(height: 0.5)
            
            // Content for the specific section
            ScrollView {
                sectionContent
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private var sectionIcon: String {
        switch currentSection {
        case .main: return ""
        case .announcements: return "megaphone.fill"
        case .chatrooms: return "bubble.left.and.bubble.right.fill"
        case .topMarkers: return "chart.line.uptrend.xyaxis"
        case .leaderboard: return "trophy.fill"
        case .guildWatchlist: return "star.fill"
        case .events: return "calendar.badge.clock"
        case .userList: return "person.3.fill"
        case .statistics: return "chart.bar.fill"
        }
    }
    
    private var sectionTitle: String {
        switch currentSection {
        case .main: return ""
        case .announcements: return "Announcements"
        case .chatrooms: return "Chatrooms"
        case .topMarkers: return "Top Markers"
        case .leaderboard: return "Leaderboard"
        case .guildWatchlist: return "Watchlist"
        case .events: return "Events"
        case .userList: return "Members"
        case .statistics: return "Statistics"
        }
    }
    
    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .announcements:
            AnnouncementsListView(bottomSheetContent: $bottomSheetContent)
        case .chatrooms:
            ChatroomsListView(bottomSheetContent: $bottomSheetContent)
        case .topMarkers:
            TopMarkersView()
        case .leaderboard:
            LeaderboardView()
        case .guildWatchlist:
            WatchlistView()
        case .events:
            EventsListView(bottomSheetContent: $bottomSheetContent)
        case .userList:
            UserListView(bottomSheetContent: $bottomSheetContent)
        case .statistics:
            StatisticsView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Menu Button Component
struct DrawerMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentColor)
                    .frame(width: 28)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section List Views with Bottom Sheet Triggers
struct AnnouncementsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(1...8, id: \.self) { index in
                Button(action: {
                    bottomSheetContent = .announcement(id: index, title: "Important Guild Update \(index)")
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "megaphone.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Important Guild Update \(index)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                                .multilineTextAlignment(.leading)
                            
                            Text("Tap to read the full announcement and details...")
                                .font(.caption)
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            HStack {
                                Text("Posted by Admin")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.5))
                                Circle()
                                    .fill(AppColors.whiteText.opacity(0.5))
                                    .frame(width: 3, height: 3)
                                Text("\(index)h ago")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.whiteText.opacity(0.5))
                            }
                            .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ChatroomsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    
    let chatrooms = [
        ("general", "General Discussion", 42, true),
        ("trading", "Trading Talk", 28, true),
        ("analysis", "Market Analysis", 15, false),
        ("off-topic", "Off Topic", 8, false),
        ("announcements", "Announcements Only", 3, false),
        ("resources", "Learning Resources", 12, false)
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(chatrooms, id: \.0) { room in
                Button(action: {
                    bottomSheetContent = .chatroom(name: room.1)
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.accentColor.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "number")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.1)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(room.3 ? AppColors.bullCandleGreen : Color.gray.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                Text("\(room.2) members")
                                    .font(.caption)
                                    .foregroundColor(AppColors.whiteText.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
}

struct EventsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(1...6, id: \.self) { index in
                Button(action: {
                    bottomSheetContent = .event(id: index)
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 4) {
                            Text("OCT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                            Text("\(index + 5)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.whiteText)
                        }
                        .frame(width: 50)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Guild Tournament \(index)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text("Join us for an exciting competition!")
                                .font(.caption)
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                                .lineLimit(2)
                            
                            Text("7:00 PM EST • 34 attending")
                                .font(.caption2)
                                .foregroundColor(AppColors.accentColor)
                                .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
}

struct UserListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(1...20, id: \.self) { index in
                Button(action: {
                    bottomSheetContent = .userProfile(name: "User \(index)")
                }) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(AppColors.accentColor)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("U\(index)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            Circle()
                                .fill(index % 2 == 0 ? AppColors.bullCandleGreen : Color.gray)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User \(index)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                            
                            HStack(spacing: 6) {
                                Text("Level \(index * 5)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accentColor)
                                Circle()
                                    .fill(AppColors.whiteText.opacity(0.5))
                                    .frame(width: 3, height: 3)
                                Text("\(1000 + index * 50) Rep")
                                    .font(.caption)
                                    .foregroundColor(AppColors.whiteText.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Simple List Views (No Bottom Sheets Needed)
struct TopMarkersView: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(1...10, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(index <= 3 ? AppColors.accentColor : AppColors.whiteText.opacity(0.6))
                        .frame(width: 30)
                    
                    Circle()
                        .fill(AppColors.accentColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("U\(index)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TopTrader\(index)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        Text("Accuracy: \(95 - index)%")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("+\(150 - index * 10)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.bullCandleGreen)
                }
                .padding()
                .background(Color.white.opacity(index <= 3 ? 0.12 : 0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct LeaderboardView: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(1...15, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(index <= 3 ? AppColors.accentColor : AppColors.whiteText.opacity(0.6))
                        .frame(width: 30)
                    
                    if index <= 3 {
                        Image(systemName: index == 1 ? "crown.fill" : "medal.fill")
                            .foregroundColor(index == 1 ? .yellow : (index == 2 ? .gray : Color.orange))
                            .font(.title3)
                    }
                    
                    Text("Player \(index)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Spacer()
                    
                    Text("\(5000 - index * 200)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                }
                .padding()
                .background(Color.white.opacity(index <= 3 ? 0.12 : 0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct WatchlistView: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN", "NVDA", "META", "NFLX"], id: \.self) { ticker in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accentColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Text(String(ticker.prefix(2)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticker)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        Text("Technology")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(Int.random(in: 100...500))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        Text("+\(String(format: "%.2f", Double.random(in: 0.5...5.0)))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.bullCandleGreen)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct StatisticsView: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Guild Performance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.bottom, 4)
                
                StatRow(label: "Total Predictions", value: "1,234")
                StatRow(label: "Correct Predictions", value: "967")
                StatRow(label: "Average Accuracy", value: "78.3%")
                StatRow(label: "Guild Rank", value: "#42")
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.bottom, 4)
                
                StatRow(label: "New Members", value: "+12")
                StatRow(label: "Active Users", value: "52")
                StatRow(label: "Predictions Made", value: "234")
                StatRow(label: "Reputation Earned", value: "+567")
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Contributors")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.bottom, 4)
                
                ForEach(1...5, id: \.self) { index in
                    HStack {
                        Text("\(index).")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                            .frame(width: 20)
                        Text("User\(index)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        Spacer()
                        Text("+\(200 - index * 30)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.accentColor)
        }
    }
}

// MARK: - Bottom Sheet View
struct BottomSheetView: View {
    let content: BottomSheetContent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch content {
                    case .chatroom(let name):
                        ChatroomDetailView(name: name)
                    case .announcement(let id, let title):
                        AnnouncementDetailView(id: id, title: title)
                    case .userProfile(let name):
                        UserProfileView(name: name)
                    case .event(let id):
                        EventDetailView(id: id)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Bottom Sheet Detail Views
struct ChatroomDetailView: View {
    let name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "number")
                    .font(.title)
                    .foregroundColor(AppColors.accentColor)
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("This is where the full chat interface would go. You'd have message history, input field, user avatars, timestamps, etc.")
                .foregroundColor(.secondary)
            
            // Placeholder for chat messages
            VStack(alignment: .leading, spacing: 12) {
                ForEach(1...10, id: \.self) { index in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(AppColors.accentColor)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("User \(index)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("2:3\(index) PM")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("This is a sample chat message in the \(name) room.")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
    }
}

struct AnnouncementDetailView: View {
    let id: Int
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.title)
                    .foregroundColor(AppColors.accentColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("Posted by Guild Admin")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(id) hours ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text("This is the full announcement content. You can include rich text, images, links, and more here. This view has all the space it needs to display detailed information.")
                .font(.body)
            
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.")
                .font(.body)
                .padding(.top, 8)
        }
    }
}

struct UserProfileView: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(AppColors.accentColor)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(name.prefix(2)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text(name)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 30) {
                VStack {
                    Text("Level 45")
                        .font(.headline)
                        .foregroundColor(AppColors.accentColor)
                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("2,450")
                        .font(.headline)
                        .foregroundColor(AppColors.accentColor)
                    Text("Reputation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("87%")
                        .font(.headline)
                        .foregroundColor(AppColors.accentColor)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                ForEach(1...5, id: \.self) { index in
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(AppColors.accentColor)
                        Text("Made a prediction on AAPL")
                            .font(.subheadline)
                        Spacer()
                        Text("\(index)d ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EventDetailView: View {
    let id: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(spacing: 4) {
                    Text("OCT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(id + 5)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .frame(width: 80)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Guild Tournament \(id)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("7:00 PM EST")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Label("34 members attending", systemImage: "person.3.fill")
                    .foregroundColor(AppColors.accentColor)
                Label("Guild Hall", systemImage: "location.fill")
                    .foregroundColor(.secondary)
            }
            
            Text("Event Description")
                .font(.headline)
                .padding(.top, 8)
            
            Text("Join us for an exciting guild tournament! Compete against other members, earn reputation points, and climb the leaderboard. Prizes for top performers!")
                .font(.body)
            
            Button(action: {}) {
                Text("RSVP to Event")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Press Events Helper
extension View {
    func pressEvents(onPress: @escaping (() -> Void), onRelease: @escaping (() -> Void)) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}





















//import SwiftUI
//
//
//struct LeftDrawerMainView: View {
//    let onClose: () -> Void
//    
//    @State private var dragTranslation: CGFloat = 0
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            // Header section with title and close button
//            VStack {
//                HStack {
//                    Text("Guild")
//                        .font(.title)
//                        .fontWeight(.bold)
//                        .foregroundColor(.primary)
//                    Spacer()
//                    Button(action: {
//                        withAnimation(AnimationConstants.standard) { onClose() }
//                    }) {
//                        Image(systemName: "chevron.left.chevron.left.dotted")
//                            .font(.title2)
//                            .fontWeight(.bold)
//                            .foregroundColor(.primary)
//                    }
//                }
//                
//                // Guild Name and icon
//                HStack {
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("KAOS")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    + Text(" Guild")
//                        .font(.title2)
//                        .fontWeight(.medium)
//                        .foregroundColor(AppColors.accentColor)
//                    Spacer()
//                    
//                }
//                
//                
//                //Member counts
//                HStack(spacing: 2) {
//                    
//                    Text("12")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    + Text(" Members")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    Circle()
//                        .fill(AppColors.whiteText.opacity(0.7))
//                        .frame(width: 5, height: 5)
//                        .padding(.top, 1)
//                        .padding(.leading, 3)
//                        .padding(.trailing, 3)
//                    Text("52")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    + Text(" Online")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    Circle()
//                        .fill(AppColors.bullCandleGreen)
//                        .frame(width: 7, height: 7)
//                        .padding(.top, 0)
//                        .padding(.leading, 3)
//                        .padding(.trailing, 3)
//                    
//                    Spacer()
//                }
//                .padding(.top, 6)
//                
//                //Guild Stats
//                HStack(spacing: 2) {
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.footnote)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("3456")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    + Text(" Guild Reputation")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    Circle()
//                        .fill(AppColors.whiteText.opacity(0.7))
//                        .frame(width: 5, height: 5)
//                        .padding(.top, 1)
//                        .padding(.leading, 3)
//                        .padding(.trailing, 3)
//                    Text("78%")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    + Text(" Guild Accuracy")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    
//                    
//                    Spacer()
//                }
//                .padding(.top, 6)
//                
//                    
//                Text("Tagline describing the main content and premis of the guild, or a short description of the guild")
//                    .font(.caption)
//                    .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 4)
//                    .multilineTextAlignment(.leading)
//                        //.animation(nil, value: UUID())
//                
//                
//                
//               
//                
//                Rectangle()
//                    .fill(Color.gray.opacity(0.4))
//                    .frame(height: 0.5)
//                    .padding(.top, 6)
//                
//                
//            }
//            .padding(.leading, 25)
//            .padding(.trailing, 25)
//            .padding(.bottom, 4)
//            .padding(.top, 60)
//            
//            
//            
//            // Placeholder content area with gesture support
//            ScrollView {
//                VStack(spacing: 16) {
//                    Text("Drawer content goes here")
//                        .foregroundColor(.secondary)
//                        .padding()
//                    
//                    // Add your drawer-specific content here
////                    ForEach(1...10, id: \.self) { index in
////                        HStack {
////                            Text("Item \(index)")
////                                .foregroundColor(.primary)
////                            Spacer()
////                            Image(systemName: "chevron.right")
////                                .foregroundColor(.secondary)
////                        }
////                        .padding()
////                        .background(Color.gray.opacity(0.1))
////                        .cornerRadius(8)
////                        .padding(.horizontal)
////                    }
//                }
//            }
//            .simultaneousGesture(
//                // Add drag gesture to ScrollView so it works inside drawer content
//                DragGesture()
//                    .onChanged { value in
//                        // Only allow dismissal drags (left for left drawer, right for right drawer)
//                        if (value.translation.width < 0) {
//                            dragTranslation = value.translation.width
//                        }
//                    }
//                    .onEnded { value in
//                        // Check if dragged far enough to dismiss
//                        let threshold = LayoutConstants.drawerDismissThreshold
//                        if (dragTranslation < -threshold) {
//                            onClose()
//                        }
//                        dragTranslation = 0
//                    }
//            )
//            
//            Spacer()
//            
//            VStack(spacing: 16) {
//                Rectangle()
//                    .fill(Color.gray.opacity(0.4))
//                    .frame(height: 0.5)
//                    .padding(.top, 0)
//                    .padding(.bottom, 6)
//                HStack {
//                    Button(action: {
//                        
//                    }) {
//                        HStack{
//                            Image(systemName: "arrow.trianglehead.2.counterclockwise")
//                                .font(.callout)
//                                .fontWeight(.medium)
//                                .foregroundColor(AppColors.whiteText.opacity(0.7))
//                            Text("Switch Guild")
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                                .foregroundColor(AppColors.whiteText)
//                            
//                        }
//                        
//                    }
//                    Spacer()
//                    Button(action: {
//                        
//                    }) {
//                        Image(systemName: "gearshape.fill")
//                            .font(.callout)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    }
//                    .padding(.trailing, 6)
//                    Button(action: {
//                        
//                    }) {
//                        Image(systemName: "square.and.arrow.up.fill")
//                            .font(.callout)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    }
//                    .padding(.bottom, 3)
//                    
//                }
//            }
//            .padding(.bottom, 40)
//            .padding(.leading, 25)
//            .padding(.trailing, 25)
//        
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            ZStack {
//                // the frosted glass base
//                Rectangle()
//                    .fill(.ultraThinMaterial)
//                    .ignoresSafeArea()
//
//                // darken/tint the material
//                AppColors.drawerBackground.opacity(0.6)               // tweak opacity
//            }
//        )
//        .overlay(
//            // Subtle border on the side facing the content
//            Rectangle()
//                .fill(Color.white.opacity(0.1))
//                .frame(width: 1)
//                .frame(maxHeight: .infinity),
//            alignment: .trailing        )
//        .clipShape(
//            // Custom corner rounding - only round corners opposite to the edge
//            UnevenRoundedRectangle(
//                cornerRadii: .init(
//                    topLeading: 0,
//                    bottomLeading: 0,
//                    bottomTrailing: LayoutConstants.cornerRadius,
//                    topTrailing: LayoutConstants.cornerRadius
//                )
//            )
//        )
//        .shadow(radius: LayoutConstants.shadowRadius)
//        .ignoresSafeArea()
//    }
//}
