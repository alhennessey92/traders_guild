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
    case notifications
    case topMarkers
    case leaderboard
    case guildWatchlist
    case events
    case userList
    case statistics
    case adminPanel
}

/// Identifies which bottom sheet content to present from the left drawer.
/// Conforms to `Identifiable` for `.sheet(item:)` and `Equatable` to support `.onChange`.
/// Each case carries the minimal data needed to render its detail view.
enum BottomSheetContent: Identifiable, Equatable {
    case announcement(RLGuildAnnouncementWithAuthorDTO)  // Uses combined DTO from backend
    case event(RLGuildEventWithAuthorDTO)  // Uses combined DTO from backend
    case profile
    case guildMember(GuildMembershipDTO)
    case createAnnouncement  // <-- ADD THIS LINE
    case createEvent
    
    var id: String {
        switch self {
        case .announcement(let announcement): return "announcement-\(announcement.id)"
        case .event(let event): return "event-\(event.id)"
        case .profile: return "profile"
        case .guildMember(let user): return "profile-\(user.id)"
        case .createAnnouncement: return "create-announcement"  // <-- ADD THIS
        case .createEvent: return "create-event"
        }
    }
    
    // Equatable conformance for RLGuildAnnouncementWithAuthorDTO
    static func == (lhs: BottomSheetContent, rhs: BottomSheetContent) -> Bool {
        switch (lhs, rhs) {
        case (.announcement(let a1), .announcement(let a2)):
            return a1.id == a2.id
        case (.event(let e1), .event(let e2)):
            return e1.id == e2.id
        case (.profile, .profile):
            return true
        case (.guildMember(let m1), .guildMember(let m2)):
            return m1.id == m2.id
        case (.createAnnouncement, .createAnnouncement):  // <-- ADD THIS
            return true
        case (.createEvent, .createEvent):                // <-- ADD THIS
            return true
        default:
            return false
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
    

    @Binding var sheetOverlayVisible: Bool
    @Binding var dismissSheetsSignal: Bool
    let onClose: () -> Void
    
    
    
    @State private var dragTranslation: CGFloat = 0
    @State private var navigationState: DrawerNavigationState = .main
    @State private var bottomSheetContent: BottomSheetContent? = nil
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
    
    var currentSymbolId: UUID? = nil
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    /// Dismisses any currently presented sheet from the left drawer.
    /// Used when the global overlay is tapped/dragged or the drawer closes.
    private func dismissAllSheets() {
        bottomSheetContent = nil
    }
    
    var body: some View {
        if let user = rlAppState.currentUser,
           let guild = rlAppState.currentGuild {
            ZStack {
                // Main content that changes based on navigation state
                if navigationState == .main {
                    MainDrawerView(
                        //currentGuild: currentGuild,
                        navigationState: $navigationState,
                        onClose: onClose,
                        dragTranslation: $dragTranslation,
                        presentProfile: { bottomSheetContent = .profile }
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
                        dragTranslation: $dragTranslation,
                        currentSymbolId: currentSymbolId
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
                BottomSheetView(content: content, selectedDetent: $selectedDetent)  // PASS BINDING
                    
                    .presentationDetents(detentsForContent(content), selection: $selectedDetent)  // ADD selection
    //                .presentationBackground { AppColors.drawerBackground.opacity(0.9) }
                    .presentationBackground {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            AppColors.sheetBackground
                        }
                    }
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationCornerRadius(33)
            }
            .onChange(of: bottomSheetContent) { oldValue, newValue in
                sheetOverlayVisible = newValue != nil
                // Reset detent when opening new sheet
                if newValue != nil {
                    selectedDetent = .fraction(0.6)
                }
            }
            .onChange(of: dismissSheetsSignal) { oldValue, newValue in
                if newValue {
                    dismissAllSheets()
                    dismissSheetsSignal = false
                }
            }
        } else {
            // Optional: Show error state if user/guild missing
            EmptyView()
        }
    }

    private func detentsForContent(_ content: BottomSheetContent) -> Set<PresentationDetent> {
        switch content {
        case .announcement:
            return [.fraction(0.6), .large]
        case .profile:
            return [.fraction(0.6), .large]  // ADD .large
        case .event:
            return [.fraction(0.6), .large]
        case .guildMember:
            return [.fraction(0.6), .large]
        case .createAnnouncement:           // <-- ADD THIS
            return [.large]
        case .createEvent:                  // <-- ADD THIS
            return [.large]
        }
    }
}

/// Drawer home screen showing guild header and navigation menu for sections.
/// Selecting a menu item updates `navigationState` to replace the content area.
struct MainDrawerView: View {
    
    //let currentGuild: Guild
    @Binding var navigationState: DrawerNavigationState
    let onClose: () -> Void
    @Binding var dragTranslation: CGFloat
    let presentProfile: () -> Void
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: Remove
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    /// Menu configuration for the left drawer home screen.
    /// Each entry maps to a destination `DrawerNavigationState`.
    var menuItems: [(icon: String, title: String, state: DrawerNavigationState)] {
        var items: [(icon: String, title: String, state: DrawerNavigationState)] = [
            ("megaphone.fill", "Announcements", .announcements),
            ("bell.fill", "Notifications", .notifications),
            ("chart.line.uptrend.xyaxis", "Today's Top Markers", .topMarkers),
            ("trophy.fill", "Leaderboard", .leaderboard),
            ("star.fill", "Watchlists", .guildWatchlist),
            ("calendar.badge.clock", "Events", .events),
            ("person.2.fill", "User List", .userList),
            ("chart.bar.fill", "Statistics", .statistics)
        ]
        
        // Add Admin Panel for moderators and admins
        if rlAppState.canModerate {
            items.append(("shield.checkered", "Admin Panel", .adminPanel))
        }
        
        return items
    }
//    let menuItems: [(icon: String, title: String, state: DrawerNavigationState)] = [
//        ("megaphone.fill", "Announcements", .announcements),
//        ("bell.fill", "Notifications", .notifications),
//        ("chart.line.uptrend.xyaxis", "Today's Top Markers", .topMarkers),
//        ("trophy.fill", "Leaderboard", .leaderboard),
//        ("star.fill", "Watchlists", .guildWatchlist),
//        ("calendar.badge.clock", "Events", .events),
//        ("person.2.fill", "User List", .userList),
//        ("chart.bar.fill", "Statistics", .statistics)
//    ]
    
    
    var body: some View {
        if let guild = appState.currentGuild,
           let rlUser = rlAppState.currentUser,
           let rlGuild = rlAppState.currentGuild,
           let rlMembership = rlAppState.currentMembership{
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
                    
                    Text(rlGuild.name)
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
                    Text("\(rlGuild.memberCount)")
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
                    Text("\(rlGuild.membersOnline)")
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
                    Text("\(rlGuild.reputation)")
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
                    Text("99%") // TODO: Get Guild Accuracy
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    + Text(" Guild Accuracy")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 6)
                
                Text("\(rlGuild.description ?? "No Description Provided")")
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
            .refreshable {
                // ✅ Pull to refresh - only refresh announcements on main view
                // Other data refreshes when navigating to specific sections
                await leftDrawerViewModel.refreshAnnouncements(guildId: guild.id, rlAppState: rlAppState)
            }
            .overlay {
                // ✅ Show loading only on first load
                if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColors.whiteText)
                        Text("Loading...")
                            .foregroundColor(AppColors.whiteText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.gradientBackgroundDark.opacity(0.9))
                }
            }
            
            // Footer
            VStack(spacing: 16) {
                
                
                
                
                
                Divider()
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                
                
                UserRowView(user: rlUser, membership: rlMembership, onTap: {  // ✅ No unwrapping!
                    presentProfile()
                })
                
                
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            .padding(.leading, 25)
            .padding(.trailing, 25)
        }
        } else {
            // Optional: Show error state if user/guild missing
            EmptyView()
        }
            
    }
        
    
}

/// Full-screen replacement content inside the left drawer for a specific section.
/// Includes its own header with back/close controls and hosts the section content.
struct SectionDrawerView: View {
    @Binding var navigationState: DrawerNavigationState
    let currentSection: DrawerNavigationState
    @Binding var bottomSheetContent: BottomSheetContent?

    let onClose: () -> Void
    @Binding var dragTranslation: CGFloat
    
    var currentSymbolId: UUID? = nil
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        if let guild = rlAppState.currentGuild {
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
                // Some sections handle their own scrolling (with sticky tab bars)
                if sectionHandlesOwnScrolling {
                    sectionContent
                        .padding(.top, 12)
                } else {
                    ScrollView {
                        sectionContent
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable {
                        // ✅ Component-specific refresh based on current section
                        await refreshCurrentSection(guildId: guild.id, appState: appState, rlAppState: rlAppState)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
    
    /// Whether the current section handles its own scrolling (has sticky tab bars)
    private var sectionHandlesOwnScrolling: Bool {
        switch currentSection {
        case .topMarkers, .leaderboard, .userList, .guildWatchlist, .notifications:
            return true
        default:
            return false
        }
    }

    
    /// Human-readable title for the current section header.
    private var sectionTitle: String {
        switch currentSection {
        case .main: return ""
        case .announcements: return "Announcements"
        case .notifications: return "Notifications"
        case .topMarkers: return "Top Markers"
        case .leaderboard: return "Leaderboard"
        case .guildWatchlist: return "Watchlist"
        case .events: return "Events"
        case .userList: return "Members"
        case .statistics: return "Statistics"
        case .adminPanel: return "Admin Panel"
        
        }
    }
    
    /// Section content switcher that renders the appropriate view for the current section.
    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .announcements:
            AnnouncementsListView(bottomSheetContent: $bottomSheetContent)
        case .notifications:
            NotificationsListView()
        case .topMarkers:
            TopMarkersView()
        case .leaderboard:
            LeaderboardListView(bottomSheetContent: $bottomSheetContent)
        case .guildWatchlist:
            WatchlistView(currentSymbolId: currentSymbolId)
        case .events:
            EventsListView(bottomSheetContent: $bottomSheetContent)
        case .userList:
            UserListView(bottomSheetContent: $bottomSheetContent)
        case .statistics:
            StatisticsView()
        case .adminPanel:                                            // <-- ADD THIS CASE
            AdminPanelListView(bottomSheetContent: $bottomSheetContent)
        default:
            EmptyView()
        }
    }
    
    /// Refresh only the data needed for the current section
    private func refreshCurrentSection(guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
        switch currentSection {
        case .announcements:
            await leftDrawerViewModel.refreshAnnouncements(guildId: guildId, rlAppState: rlAppState)
        case .events:
            await leftDrawerViewModel.refreshEvents(guildId: guildId, rlAppState: rlAppState)
        case .userList:
            await leftDrawerViewModel.refreshMembers(guildId: guildId, appState: appState)
        case .notifications:
            await leftDrawerViewModel.refreshNotifications(guildId: guildId, appState: appState)
        case .statistics:
            await leftDrawerViewModel.refreshStatistics(guildId: guildId, appState: appState)
        case .topMarkers:
            await leftDrawerViewModel.refreshTopMarkers(for: guildId, appState: appState)
        default:
            // For sections without specific refresh, do nothing or refresh all
            break
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



/// Container for detail content presented as a sheet from the left drawer.
///

struct BottomSheetView: View {
    let content: BottomSheetContent
    @Binding var selectedDetent: PresentationDetent
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var appState: AppState // TODO: remove
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .announcement(let announcement):
                AnnouncementDetailView(announcement: announcement)
            case .event(let event):
                EventDetailView(event: event)
            case .profile:  // Changed from 'user' to 'membership'
                UserProfileDetailView(selectedDetent: $selectedDetent)
                    .environmentObject(leftDrawerViewModel)
            case .guildMember(let user):
                GuildUserDetailView(user: user)
            case .createAnnouncement:           // <-- ADD THIS
                CreateAnnouncementView()
            case .createEvent:                  // <-- ADD THIS
                CreateEventView()
            
                
            }

        }
        
        
        .overlay(
            RoundedRectangle(cornerRadius: 33)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 0)
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







////
////  LeftDrawerMainView.swift
////  traders_guild
////
////  Created by Al Hennessey on 30/09/2025.
////
//
//import SwiftUI
//
///// High-level navigation state for the left drawer.
///// Determines which full-screen section the drawer is showing.
///// - main: Home menu for the drawer
///// - announcements: Guild announcements list
///// - topMarkers: Daily highlights/markers
///// - leaderboard: Guild leaderboard section
///// - guildWatchlist: Guild watchlist
///// - events: Upcoming events
///// - userList: Members list
///// - statistics: Guild statistics
//enum DrawerNavigationState: Equatable {
//    case main
//    case announcements
//    case notifications
//    case topMarkers
//    case leaderboard
//    case guildWatchlist
//    case events
//    case userList
//    case statistics
//}
//
///// Identifies which bottom sheet content to present from the left drawer.
///// Conforms to `Identifiable` for `.sheet(item:)` and `Equatable` to support `.onChange`.
///// Each case carries the minimal data needed to render its detail view.
//enum BottomSheetContent: Identifiable, Equatable {
//    case announcement(RLGuildAnnouncementWithAuthorDTO)  // Uses combined DTO from backend
//    case event(GuildEventDTO)
//    case profile
//    case guildMember(GuildMembershipDTO)
//    
//    var id: String {
//        switch self {
//        case .announcement(let announcement): return "announcement-\(announcement.id)"
//        case .event(let event): return "event-\(event.id)"
//        case .profile: return "profile"
//        case .guildMember(let user): return "profile-\(user.id)"
//        }
//    }
//    
//    // Equatable conformance for RLGuildAnnouncementWithAuthorDTO
//    static func == (lhs: BottomSheetContent, rhs: BottomSheetContent) -> Bool {
//        switch (lhs, rhs) {
//        case (.announcement(let a1), .announcement(let a2)):
//            return a1.id == a2.id
//        case (.event(let e1), .event(let e2)):
//            return e1.id == e2.id
//        case (.profile, .profile):
//            return true
//        case (.guildMember(let m1), .guildMember(let m2)):
//            return m1.id == m2.id
//        default:
//            return false
//        }
//    }
//}
//
///// The main container for the left-side drawer.
///// Handles navigation between drawer sections and presents bottom sheets for detail views.
///// This view mirrors sheet presentation behavior with the right drawer (clear background, overlay, and dismissal).
//struct LeftDrawerMainView: View {
//    // MARK: - Bindings & State
//    // announcements: Data source for the Announcements section
//    // sheetOverlayVisible: Controls the global dimming overlay shown behind sheets
//    // dismissSheetsSignal: External signal used to programmatically dismiss any presented sheet
//    // onClose: Callback to close the drawer
//    // dragTranslation: Current drag offset for swipe-to-dismiss
//    // navigationState: Which section is currently shown inside the drawer
//    // bottomSheetContent: Which detail sheet is currently presented (if any)
//    
//
//    @Binding var sheetOverlayVisible: Bool
//    @Binding var dismissSheetsSignal: Bool
//    let onClose: () -> Void
//    
//    
//    
//    @State private var dragTranslation: CGFloat = 0
//    @State private var navigationState: DrawerNavigationState = .main
//    @State private var bottomSheetContent: BottomSheetContent? = nil
//    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
//    
//    var currentSymbolId: UUID? = nil
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: remove
//    
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    /// Dismisses any currently presented sheet from the left drawer.
//    /// Used when the global overlay is tapped/dragged or the drawer closes.
//    private func dismissAllSheets() {
//        bottomSheetContent = nil
//    }
//    
//    var body: some View {
//        if let user = rlAppState.currentUser,
//           let guild = rlAppState.currentGuild {
//            ZStack {
//                // Main content that changes based on navigation state
//                if navigationState == .main {
//                    MainDrawerView(
//                        //currentGuild: currentGuild,
//                        navigationState: $navigationState,
//                        onClose: onClose,
//                        dragTranslation: $dragTranslation,
//                        presentProfile: { bottomSheetContent = .profile }
//                    )
//                    .transition(.asymmetric(
//                        insertion: .move(edge: .leading),
//                        removal: .move(edge: .leading)
//                    ))
//                } else {
//                    SectionDrawerView(
//                        navigationState: $navigationState,
//                        currentSection: navigationState,
//                        bottomSheetContent: $bottomSheetContent,
//                        onClose: onClose,
//                        dragTranslation: $dragTranslation,
//                        currentSymbolId: currentSymbolId
//                    )
//                    .transition(.asymmetric(
//                        insertion: .move(edge: .trailing),
//                        removal: .move(edge: .trailing)
//                    ))
//                }
//            }
//            .offset(x: dragTranslation)
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(
//                ZStack {
//                    Rectangle()
//                        .fill(.ultraThinMaterial)
//                        .ignoresSafeArea()
//                    AppColors.drawerBackground.opacity(0.6)
//                }
//            )
//            .overlay(
//                Rectangle()
//                    .fill(Color.white.opacity(0.1))
//                    .frame(width: 1)
//                    .frame(maxHeight: .infinity),
//                alignment: .trailing
//            )
//            .clipShape(
//                UnevenRoundedRectangle(
//                    cornerRadii: .init(
//                        topLeading: 0,
//                        bottomLeading: 0,
//                        bottomTrailing: LayoutConstants.cornerRadius,
//                        topTrailing: LayoutConstants.cornerRadius
//                    )
//                )
//            )
//            .shadow(radius: LayoutConstants.shadowRadius)
//            .ignoresSafeArea()
//            // Present detail sheets with a clear background and consistent detents (matches right drawer)
//            .sheet(item: $bottomSheetContent) { content in
//                BottomSheetView(content: content, selectedDetent: $selectedDetent)  // PASS BINDING
//                    
//                    .presentationDetents(detentsForContent(content), selection: $selectedDetent)  // ADD selection
//    //                .presentationBackground { AppColors.drawerBackground.opacity(0.9) }
//                    .presentationBackground {
//                        ZStack {
//                            Color.clear
//                                .background(.ultraThinMaterial)
//                            AppColors.sheetBackground
//                        }
//                    }
//                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
//                    .presentationCornerRadius(33)
//            }
//            .onChange(of: bottomSheetContent) { oldValue, newValue in
//                sheetOverlayVisible = newValue != nil
//                // Reset detent when opening new sheet
//                if newValue != nil {
//                    selectedDetent = .fraction(0.6)
//                }
//            }
//            .onChange(of: dismissSheetsSignal) { oldValue, newValue in
//                if newValue {
//                    dismissAllSheets()
//                    dismissSheetsSignal = false
//                }
//            }
//        } else {
//            // Optional: Show error state if user/guild missing
//            EmptyView()
//        }
//    }
//
//    private func detentsForContent(_ content: BottomSheetContent) -> Set<PresentationDetent> {
//        switch content {
//        case .announcement:
//            return [.fraction(0.6), .large]
//        case .profile:
//            return [.fraction(0.6), .large]  // ADD .large
//        case .event:
//            return [.fraction(0.6), .large]
//        case .guildMember:
//            return [.fraction(0.6), .large]
//        }
//    }
//}
//
///// Drawer home screen showing guild header and navigation menu for sections.
///// Selecting a menu item updates `navigationState` to replace the content area.
//struct MainDrawerView: View {
//    
//    //let currentGuild: Guild
//    @Binding var navigationState: DrawerNavigationState
//    let onClose: () -> Void
//    @Binding var dragTranslation: CGFloat
//    let presentProfile: () -> Void
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: Remove
//    
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    /// Menu configuration for the left drawer home screen.
//    /// Each entry maps to a destination `DrawerNavigationState`.
//    let menuItems: [(icon: String, title: String, state: DrawerNavigationState)] = [
//        ("megaphone.fill", "Announcements", .announcements),
//        ("bell.fill", "Notifications", .notifications),
//        ("chart.line.uptrend.xyaxis", "Today's Top Markers", .topMarkers),
//        ("trophy.fill", "Leaderboard", .leaderboard),
//        ("star.fill", "Watchlists", .guildWatchlist),
//        ("calendar.badge.clock", "Events", .events),
//        ("person.2.fill", "User List", .userList),
//        ("chart.bar.fill", "Statistics", .statistics)
//    ]
//    
//    
//    var body: some View {
//        if let guild = appState.currentGuild,
//           let rlUser = rlAppState.currentUser,
//           let rlGuild = rlAppState.currentGuild,
//           let rlMembership = rlAppState.currentMembership{
//            VStack(alignment: .leading, spacing: 0) {
//            // Header section
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
//                HStack {
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    
//                    Text(rlGuild.name)
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    + Text(" Guild")
//                        .font(.title2)
//                        .fontWeight(.medium)
//                        .foregroundColor(AppColors.accentColor)
//                    
//                    
//                    Spacer()
//                }
//                
//                HStack(spacing: 2) {
//                    Text("\(rlGuild.memberCount)")
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
//                    Text("\(rlGuild.membersOnline)")
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
//                    Spacer()
//                }
//                .padding(.top, 6)
//                
//                HStack(spacing: 2) {
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.footnote)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("\(rlGuild.reputation)")
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
//                    Text("99%") // TODO: Get Guild Accuracy
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    + Text(" Guild Accuracy")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    Spacer()
//                }
//                .padding(.top, 6)
//                
//                Text("\(rlGuild.description ?? "No Description Provided")")
//                    .font(.caption)
//                    .foregroundColor(AppColors.whiteText.opacity(0.7))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 4)
//                    .multilineTextAlignment(.leading)
//                
//                Rectangle()
//                    .fill(Color.gray.opacity(0.4))
//                    .frame(height: 0.5)
//                    .padding(.top, 6)
//            }
//            .padding(.leading, 25)
//            .padding(.trailing, 25)
//            .padding(.bottom, 4)
//            .padding(.top, 60)
//            
//            // Menu Items
//            ScrollView {
//                VStack(spacing: 8) {
//                    ForEach(menuItems, id: \.title) { item in
//                        DrawerMenuButton(
//                            icon: item.icon,
//                            title: item.title,
//                            action: {
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                    navigationState = item.state
//                                }
//                            }
//                        )
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, 8)
//                .padding(.bottom, 20)
//            }
//            .scrollDismissesKeyboard(.interactively)
//            .refreshable {
//                // ✅ Pull to refresh - only refresh announcements on main view
//                // Other data refreshes when navigating to specific sections
//                await leftDrawerViewModel.refreshAnnouncements(guildId: guild.id, rlAppState: rlAppState)
//            }
//            .overlay {
//                // ✅ Show loading only on first load
//                if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
//                    VStack(spacing: 16) {
//                        ProgressView()
//                            .scaleEffect(1.5)
//                            .tint(AppColors.whiteText)
//                        Text("Loading...")
//                            .foregroundColor(AppColors.whiteText)
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .background(AppColors.gradientBackgroundDark.opacity(0.9))
//                }
//            }
//            
//            // Footer
//            VStack(spacing: 16) {
//                
//                
//                
//                
//                
//                Divider()
//                    .padding(.top, 2)
//                    .padding(.bottom, 2)
//                
//                
//                UserRowView(user: rlUser, membership: rlMembership, onTap: {  // ✅ No unwrapping!
//                    presentProfile()
//                })
//                
//                
//            }
//            .padding(.top, 20)
//            .padding(.bottom, 40)
//            .padding(.leading, 25)
//            .padding(.trailing, 25)
//        }
//        } else {
//            // Optional: Show error state if user/guild missing
//            EmptyView()
//        }
//            
//    }
//        
//    
//}
//
///// Full-screen replacement content inside the left drawer for a specific section.
///// Includes its own header with back/close controls and hosts the section content.
//struct SectionDrawerView: View {
//    @Binding var navigationState: DrawerNavigationState
//    let currentSection: DrawerNavigationState
//    @Binding var bottomSheetContent: BottomSheetContent?
//
//    let onClose: () -> Void
//    @Binding var dragTranslation: CGFloat
//    
//    var currentSymbolId: UUID? = nil
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: remove
//    
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    var body: some View {
//        if let guild = rlAppState.currentGuild {
//            VStack(spacing: 0) {
//                // Header with back button and title
//                HStack {
//                    Button(action: {
//                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                            navigationState = .main
//                        }
//                    }) {
//                        HStack(spacing: 6) {
//                            Image(systemName: "chevron.left")
//                                .font(.title3)
//                                .fontWeight(.semibold)
//                            Text("KAOS")
//                                .font(.headline)
//                                .fontWeight(.bold)
//                            + Text(" Guild")
//                                .font(.headline)
//                                .fontWeight(.medium)
//                        }
//                        .foregroundColor(AppColors.whiteText.opacity(0.95))
//                    }
//                    
//                    Spacer()
//                    
//                    Button(action: {
//                        withAnimation(AnimationConstants.standard) { onClose() }
//                    }) {
//                        Image(systemName: "xmark")
//                            .font(.title3)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.whiteText.opacity(0.8))
//                            
//                    }
//                }
//                .padding(.horizontal, 20)
//                .padding(.top, 60)
//                .padding(.bottom, 16)
//                
//                Text(sectionTitle)
//                    .font(.title)
//                    .fontWeight(.bold)
//                    .foregroundColor(AppColors.whiteText)
//    //                .frame(width: .infinity, alignment: .leading)
//                    .padding(.horizontal, 20)
//                    .padding(.bottom, 18)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                Rectangle()
//                    .fill(Color.gray.opacity(0.4))
//                    .frame(height: 0.5)
//                
//                // Content for the specific section
//                // Some sections handle their own scrolling (with sticky tab bars)
//                if sectionHandlesOwnScrolling {
//                    sectionContent
//                        .padding(.top, 12)
//                } else {
//                    ScrollView {
//                        sectionContent
//                            .padding(.top, 12)
//                            .padding(.bottom, 20)
//                    }
//                    .scrollDismissesKeyboard(.interactively)
//                    .refreshable {
//                        // ✅ Component-specific refresh based on current section
//                        await refreshCurrentSection(guildId: guild.id, appState: appState, rlAppState: rlAppState)
//                    }
//                }
//            }
//        } else {
//            EmptyView()
//        }
//    }
//    
//    /// Whether the current section handles its own scrolling (has sticky tab bars)
//    private var sectionHandlesOwnScrolling: Bool {
//        switch currentSection {
//        case .topMarkers, .leaderboard, .userList, .guildWatchlist, .notifications:
//            return true
//        default:
//            return false
//        }
//    }
//
//    
//    /// Human-readable title for the current section header.
//    private var sectionTitle: String {
//        switch currentSection {
//        case .main: return ""
//        case .announcements: return "Announcements"
//        case .notifications: return "Notifications"
//        case .topMarkers: return "Top Markers"
//        case .leaderboard: return "Leaderboard"
//        case .guildWatchlist: return "Watchlist"
//        case .events: return "Events"
//        case .userList: return "Members"
//        case .statistics: return "Statistics"
//        
//        }
//    }
//    
//    /// Section content switcher that renders the appropriate view for the current section.
//    @ViewBuilder
//    private var sectionContent: some View {
//        switch currentSection {
//        case .announcements:
//            AnnouncementsListView(bottomSheetContent: $bottomSheetContent)
//        case .notifications:
//            NotificationsListView()
//        case .topMarkers:
//            TopMarkersView()
//        case .leaderboard:
//            LeaderboardListView(bottomSheetContent: $bottomSheetContent)
//        case .guildWatchlist:
//            WatchlistView(currentSymbolId: currentSymbolId)
//        case .events:
//            EventsListView(bottomSheetContent: $bottomSheetContent)
//        case .userList:
//            UserListView(bottomSheetContent: $bottomSheetContent)
//        case .statistics:
//            StatisticsView()
//        default:
//            EmptyView()
//        }
//    }
//    
//    /// Refresh only the data needed for the current section
//    private func refreshCurrentSection(guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
//        switch currentSection {
//        case .announcements:
//            await leftDrawerViewModel.refreshAnnouncements(guildId: guildId, rlAppState: rlAppState)
//        case .events:
//            await leftDrawerViewModel.refreshEvents(guildId: guildId, appState: appState)
//        case .userList:
//            await leftDrawerViewModel.refreshMembers(guildId: guildId, appState: appState)
//        case .notifications:
//            await leftDrawerViewModel.refreshNotifications(guildId: guildId, appState: appState)
//        case .statistics:
//            await leftDrawerViewModel.refreshStatistics(guildId: guildId, appState: appState)
//        case .topMarkers:
//            await leftDrawerViewModel.refreshTopMarkers(for: guildId, appState: appState)
//        default:
//            // For sections without specific refresh, do nothing or refresh all
//            break
//        }
//    }
//}
//
///// Reusable row-styled button used in the drawer's main menu.
//struct DrawerMenuButton: View {
//    let icon: String
//    let title: String
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 12) {
//                Image(systemName: icon)
//                    .font(.headline)
//                    .fontWeight(.medium)
//                    .foregroundColor(AppColors.whiteText)
//                    .frame(width: 38, alignment: .leading)
//                
//                Text(title)
//                    .font(.title3)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
////                Image(systemName: "chevron.right")
////                    .font(.caption)
////                    .fontWeight(.semibold)
////                    .foregroundColor(AppColors.whiteText.opacity(0.4))
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
////            .background(
////                RoundedRectangle(cornerRadius: 10)
////                    .fill(Color.white.opacity(0.08))
////            )
//        }
//        .buttonStyle(PlainButtonStyle())
//    }
//}
//
//
//
///// Container for detail content presented as a sheet from the left drawer.
/////
//
//struct BottomSheetView: View {
//    let content: BottomSheetContent
//    @Binding var selectedDetent: PresentationDetent
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    @EnvironmentObject var appState: AppState // TODO: remove
//    
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            switch content {
//            case .announcement(let announcement):
//                AnnouncementDetailView(announcement: announcement)
//            case .event(let event):
//                EventDetailView(event: event)
//            case .profile:  // Changed from 'user' to 'membership'
//                UserProfileDetailView(selectedDetent: $selectedDetent)
//                    .environmentObject(leftDrawerViewModel)
//            case .guildMember(let user):
//                GuildUserDetailView(user: user)
//                
//            }
//
//        }
//        
//        
//        .overlay(
//            RoundedRectangle(cornerRadius: 33)
//                .strokeBorder(
//                    LinearGradient(
//                        colors: [
//                            Color.white.opacity(0.15),
//                            Color.white.opacity(0.0)
//                        ],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    ),
//                    lineWidth: 1
//                )
//                .allowsHitTesting(false)
//        )
//        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 0)
//    }
//}
//
//
//
//
//
///// Gesture helper to detect press-and-release interactions.
///// Useful for custom button press states.
//extension View {
//    func pressEvents(onPress: @escaping (() -> Void), onRelease: @escaping (() -> Void)) -> some View {
//        self.simultaneousGesture(
//            DragGesture(minimumDistance: 0)
//                .onChanged { _ in onPress() }
//                .onEnded { _ in onRelease() }
//        )
//    }
//}
