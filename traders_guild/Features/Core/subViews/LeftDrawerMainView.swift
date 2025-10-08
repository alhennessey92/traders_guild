//
//  LeftDrawerMainView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//

import SwiftUI

/// High-level navigation state for the left drawer.
/// Determines which full-screen section the drawer is showing.
/// - main: Home menu for the drawer
/// - announcements: Guild announcements list
/// - topMarkers: Daily highlights/markers
/// - leaderboard: Guild leaderboard section
/// - guildWatchlist: Guild watchlist
/// - events: Upcoming events
/// - userList: Members list
/// - statistics: Guild statistics
enum DrawerNavigationState: Equatable {
    case main
    case announcements
    case topMarkers
    case leaderboard
    case guildWatchlist
    case events
    case userList
    case statistics
}

/// Identifies which bottom sheet content to present from the left drawer.
/// Conforms to `Identifiable` for `.sheet(item:)` and `Equatable` to support `.onChange`.
/// Each case carries the minimal data needed to render its detail view.
enum BottomSheetContent: Identifiable, Equatable {
    case announcement(GuildAnnouncement)
    case userProfile(name: String)
    case event(GuildEvent)
    
    var id: String {
        switch self {
        case .announcement(let announcement): return "announcement-\(announcement.id)"
        case .userProfile(let name): return "profile-\(name)"
        case .event(let event): return "event-\(event.id)"
        }
    }
}

/// The main container for the left-side drawer.
/// Handles navigation between drawer sections and presents bottom sheets for detail views.
/// This view mirrors sheet presentation behavior with the right drawer (clear background, overlay, and dismissal).
struct LeftDrawerMainView: View {
    // MARK: - Bindings & State
    // announcements: Data source for the Announcements section
    // sheetOverlayVisible: Controls the global dimming overlay shown behind sheets
    // dismissSheetsSignal: External signal used to programmatically dismiss any presented sheet
    // onClose: Callback to close the drawer
    // dragTranslation: Current drag offset for swipe-to-dismiss
    // navigationState: Which section is currently shown inside the drawer
    // bottomSheetContent: Which detail sheet is currently presented (if any)
    let announcements: [GuildAnnouncement]
    let events: [GuildEvent]
    @Binding var sheetOverlayVisible: Bool
    @Binding var dismissSheetsSignal: Bool
    let onClose: () -> Void
    
    @State private var dragTranslation: CGFloat = 0
    @State private var navigationState: DrawerNavigationState = .main
    @State private var bottomSheetContent: BottomSheetContent? = nil
    
    /// Dismisses any currently presented sheet from the left drawer.
    /// Used when the global overlay is tapped/dragged or the drawer closes.
    private func dismissAllSheets() {
        bottomSheetContent = nil
    }
    
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
                    announcements: announcements,
                    events: events,
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
        // Present detail sheets with a clear background and consistent detents (matches right drawer)
        .sheet(item: $bottomSheetContent) { content in
            BottomSheetView(content: content)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.clear)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(20)
        }
        // Keep the global overlay in sync with whether a sheet is presented
        .onChange(of: bottomSheetContent) { oldValue, newValue in
            sheetOverlayVisible = newValue != nil
        }
        // Respond to external dismissal requests (e.g., tapping the overlay)
        .onChange(of: dismissSheetsSignal) { oldValue, newValue in
            if newValue {
                dismissAllSheets()
                dismissSheetsSignal = false
            }
        }
    }
}

/// Drawer home screen showing guild header and navigation menu for sections.
/// Selecting a menu item updates `navigationState` to replace the content area.
struct MainDrawerView: View {
    @Binding var navigationState: DrawerNavigationState
    let onClose: () -> Void
    @Binding var dragTranslation: CGFloat
    
    /// Menu configuration for the left drawer home screen.
    /// Each entry maps to a destination `DrawerNavigationState`.
    let menuItems: [(icon: String, title: String, state: DrawerNavigationState)] = [
        ("megaphone.fill", "Announcements", .announcements),
        ("chart.line.uptrend.xyaxis", "Today's Top Markers", .topMarkers),
        ("trophy.fill", "Leaderboard", .leaderboard),
        ("star.fill", "Guild Watchlist", .guildWatchlist),
        ("calendar.badge.clock", "Events", .events),
        ("person.2.fill", "User List", .userList),
        ("chart.bar.fill", "Statistics", .statistics)
    ]
    
    @EnvironmentObject var currentUser: UserStore 
    
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
                if let user = currentUser.user {
                    UserRowView(user: user, onTap: {})
                    
                }
                
                
                
                
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
            .padding(.top, 20)
            .padding(.bottom, 40)
            .padding(.leading, 25)
            .padding(.trailing, 25)
        }
    }
}

/// Full-screen replacement content inside the left drawer for a specific section.
/// Includes its own header with back/close controls and hosts the section content.
struct SectionDrawerView: View {
    @Binding var navigationState: DrawerNavigationState
    let currentSection: DrawerNavigationState
    @Binding var bottomSheetContent: BottomSheetContent?
    let announcements: [GuildAnnouncement]
    let events: [GuildEvent]
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
                        Text("KAOS")
                            .font(.headline)
                            .fontWeight(.bold)
                        + Text(" Guild")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.whiteText.opacity(0.95))
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(AnimationConstants.standard) { onClose() }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.8))
                        
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
            
            // Section title
//            HStack {
////                Image(systemName: sectionIcon)
////                    .font(.title2)
////                    .fontWeight(.bold)
////                    .foregroundColor(AppColors.accentColor)
//                Text(sectionTitle)
//                    .font(.title)
//                    .fontWeight(.bold)
//                    .foregroundColor(AppColors.whiteText)
//                Spacer()
//            }
            Text(sectionTitle)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.whiteText)
//                .frame(width: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
    
//    private var sectionIcon: String {
//        switch currentSection {
//        case .main: return ""
//        case .announcements: return "megaphone.fill"
//        case .topMarkers: return "chart.line.uptrend.xyaxis"
//        case .leaderboard: return "trophy.fill"
//        case .guildWatchlist: return "star.fill"
//        case .events: return "calendar.badge.clock"
//        case .userList: return "person.2.fill"
//        case .statistics: return "chart.bar.fill"
//        }
//    }
    
    /// Human-readable title for the current section header.
    private var sectionTitle: String {
        switch currentSection {
        case .main: return ""
        case .announcements: return "Announcements"
        case .topMarkers: return "Top Markers"
        case .leaderboard: return "Leaderboard"
        case .guildWatchlist: return "Watchlist"
        case .events: return "Events"
        case .userList: return "Members"
        case .statistics: return "Statistics"
        }
    }
    
    /// Section content switcher that renders the appropriate view for the current section.
    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .announcements:
            AnnouncementsListView(bottomSheetContent: $bottomSheetContent, announcements: announcements)
        case .topMarkers:
            TopMarkersView()
        case .leaderboard:
            LeaderboardView()
        case .guildWatchlist:
            WatchlistView()
        case .events:
            EventsListView(bottomSheetContent: $bottomSheetContent, events: events)
        case .userList:
            UserListView(bottomSheetContent: $bottomSheetContent)
        case .statistics:
            StatisticsView()
        default:
            EmptyView()
        }
    }
}

/// Reusable row-styled button used in the drawer's main menu.
struct DrawerMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                    .frame(width: 38, alignment: .leading)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
//            .background(
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(Color.white.opacity(0.08))
//            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



/// Members list that triggers a bottom sheet for a user profile.
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

/// Simple list showcasing top markers/performers.
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

/// Leaderboard summary for the guild.
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

/// Guild watchlist preview.
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

/// Statistics overview cards for the guild.
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

/// One-line label/value row used in statistics cards.
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

/// Container for detail content presented as a sheet from the left drawer.
struct BottomSheetView: View {
    let content: BottomSheetContent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch content {
                    case .announcement(let announcement):
                        AnnouncementDetailView(announcement: announcement)
                    case .userProfile(let name):
                        UserProfileView(name: name)
                    case .event(let event):
                        EventDetailView(event: event)
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

/// Detail content for a user profile presented in a sheet.
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



/// Gesture helper to detect press-and-release interactions.
/// Useful for custom button press states.
extension View {
    func pressEvents(onPress: @escaping (() -> Void), onRelease: @escaping (() -> Void)) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

