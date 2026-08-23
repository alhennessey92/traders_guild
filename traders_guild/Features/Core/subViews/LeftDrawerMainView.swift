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

enum DrawerMenuBadge: Equatable {
    case unreadDot
    case count(Int)
}

enum DrawerMenuAction {
    case navigate(DrawerNavigationState)
    case betaFeedback
}

enum DrawerRestrictedAccessLevel {
    case moderator
    case admin

    func isAllowed(for role: RLMemberRole?) -> Bool {
        switch self {
        case .moderator:
            return role?.canModerate ?? false
        case .admin:
            return role?.canAdmin ?? false
        }
    }

    var deniedMessage: String {
        switch self {
        case .moderator:
            return "Moderator access is required to open this panel"
        case .admin:
            return "Admin access is required to open this panel"
        }
    }
}

/// Identifies which bottom sheet content to present from the left drawer.
/// Conforms to `Identifiable` for `.sheet(item:)` and `Equatable` to support `.onChange`.
/// Each case carries the minimal data needed to render its detail view.
enum BottomSheetContent: Identifiable, Equatable {
    case announcement(RLGuildAnnouncementWithAuthorDTO)  // Uses combined DTO from backend
    case event(RLGuildEventWithAuthorDTO)  // Uses combined DTO from backend
    case reportResolution(RLReportResolutionSummary)
    case profile
    case guildMemberRL(RLGuildMemberDTO)
    case betaFeedback
    case createAnnouncement
    case createEvent
    case guildSettings
    case manageChatrooms
    case inviteMembers
    case manageMembers
    case manageRoles
    case manageReports
    case manageGuildWatchlist

    var id: String {
        switch self {
        case .announcement(let announcement): return "announcement-\(announcement.id)"
        case .event(let event): return "event-\(event.id)"
        case .reportResolution(let summary): return "report-resolution-\(summary.id)"
        case .profile: return "profile"
        case .guildMemberRL(let user): return "profile-rl-\(user.id)"
        case .betaFeedback: return "beta-feedback"
        case .createAnnouncement: return "create-announcement"
        case .createEvent: return "create-event"
        case .guildSettings: return "guild-settings"
        case .manageChatrooms: return "manage-chatrooms"
        case .inviteMembers: return "invite-members"
        case .manageMembers: return "manage-members"
        case .manageRoles: return "manage-roles"
        case .manageReports: return "manage-reports"
        case .manageGuildWatchlist: return "manage-guild-watchlist"
        }
    }

    // Equatable conformance for RLGuildAnnouncementWithAuthorDTO
    static func == (lhs: BottomSheetContent, rhs: BottomSheetContent) -> Bool {
        switch (lhs, rhs) {
        case (.announcement(let a1), .announcement(let a2)):
            return a1.id == a2.id
        case (.event(let e1), .event(let e2)):
            return e1.id == e2.id
        case (.reportResolution(let s1), .reportResolution(let s2)):
            return s1 == s2
        case (.profile, .profile):
            return true
        case (.guildMemberRL(let m1), .guildMemberRL(let m2)):
            return m1.id == m2.id
        case (.betaFeedback, .betaFeedback):
            return true
        case (.createAnnouncement, .createAnnouncement):
            return true
        case (.createEvent, .createEvent):
            return true
        case (.guildSettings, .guildSettings):
            return true
        case (.manageChatrooms, .manageChatrooms):
            return true
        case (.inviteMembers, .inviteMembers):
            return true
        case (.manageMembers, .manageMembers):
            return true
        case (.manageRoles, .manageRoles):
            return true
        case (.manageReports, .manageReports):
            return true
        case (.manageGuildWatchlist, .manageGuildWatchlist):
            return true
        default:
            return false
        }
    }

    var requiredAccessLevel: DrawerRestrictedAccessLevel? {
        switch self {
        case .createAnnouncement, .createEvent, .inviteMembers, .manageMembers, .manageReports:
            return .moderator
        case .guildSettings, .manageChatrooms, .manageRoles, .manageGuildWatchlist:
            return .admin
        default:
            return nil
        }
    }

    func isAllowed(for role: RLMemberRole?) -> Bool {
        requiredAccessLevel?.isAllowed(for: role) ?? true
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
    @Binding var notificationRoute: NotificationDrawerRoute?
    let onClose: () -> Void
    
    
    
    @State private var dragTranslation: CGFloat = 0
    @State private var navigationState: DrawerNavigationState = .main
    @State private var bottomSheetContent: BottomSheetContent? = nil
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
    
    var currentSymbolId: UUID? = nil
    
    @EnvironmentObject var rlAppState: RLAppState
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    /// Dismisses any currently presented sheet from the left drawer.
    /// Used when the global overlay is tapped/dragged or the drawer closes.
    private func dismissAllSheets() {
        bottomSheetContent = nil
    }

    @discardableResult
    private func enforceNavigationAccess(for state: DrawerNavigationState) -> Bool {
        guard state == .adminPanel, rlAppState.canModerate == false else {
            return true
        }

        if navigationState != .main {
            navigationState = .main
        }
        rlAppState.showInfo(DrawerRestrictedAccessLevel.moderator.deniedMessage)
        return false
    }

    @discardableResult
    private func enforceSheetAccess(for content: BottomSheetContent?) -> Bool {
        guard let content,
              let requiredAccessLevel = content.requiredAccessLevel,
              requiredAccessLevel.isAllowed(for: rlAppState.currentRole) == false else {
            return true
        }

        if bottomSheetContent != nil {
            bottomSheetContent = nil
        }
        rlAppState.showInfo(requiredAccessLevel.deniedMessage)
        return false
    }
    
    var body: some View {
        if rlAppState.currentUser != nil,
           rlAppState.currentGuild != nil {
            ZStack {
                // Main content that changes based on navigation state
                if navigationState == .main {
                    MainDrawerView(
                        //currentGuild: currentGuild,
                        navigationState: $navigationState,
                        onClose: onClose,
                        dragTranslation: $dragTranslation,
                        presentProfile: { bottomSheetContent = .profile },
                        presentBetaFeedback: { bottomSheetContent = .betaFeedback }
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
                    LinearGradient(
                        colors: [
                            AppColors.drawerBackground,
                            AppColors.sheetBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .overlay(
                Rectangle()
                    .fill(AppColors.panelFillEmphasis)
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
                BottomSheetView(content: content, selectedDetent: $selectedDetent, bottomSheetContent: $bottomSheetContent)
                    
                    .presentationDetents(detentsForContent(content), selection: $selectedDetent)  // ADD selection
                    .presentationContentInteraction(.scrolls)
    //                .presentationBackground { AppColors.drawerBackground.opacity(0.9) }
                    .presentationBackground {
                        LinearGradient(
                            colors: [AppColors.sheetBackground, AppColors.drawerBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    // Background interaction stays disabled so taps during the dismiss
                    // animation can't fall through to the drawer (e.g. tapping outside the
                    // profile sheet at .fraction(0.6) was landing on TopMarkersView's
                    // marker rows mid-animation, triggering an unwanted navigation).
                    .presentationBackgroundInteraction(.disabled)
                    .presentationCornerRadius(33)
            }
            .onChange(of: bottomSheetContent) { oldValue, newValue in
                guard enforceSheetAccess(for: newValue) else {
                    sheetOverlayVisible = false
                    return
                }
                sheetOverlayVisible = newValue != nil
                // Reset detent when opening new sheet
                if newValue != nil {
                    selectedDetent = .fraction(0.6)
                }
            }
            .onChange(of: navigationState) { _, newValue in
                _ = enforceNavigationAccess(for: newValue)
            }
            .onChange(of: dismissSheetsSignal) { oldValue, newValue in
                if newValue {
                    dismissAllSheets()
                    dismissSheetsSignal = false
                }
            }
            .onChange(of: notificationRoute) { _, newValue in
                guard let route = newValue else { return }
                Task {
                    await handleNotificationRoute(route)
                    notificationRoute = nil
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
        case .reportResolution:
            return [.fraction(0.55), .large]
        case .guildMemberRL:
            return [.fraction(0.6), .large]
        case .betaFeedback:
            return [.large]
        case .createAnnouncement:
            return [.large]
        case .createEvent:
            return [.large]
        case .guildSettings:
            return [.large]
        case .manageChatrooms:
            return [.large]
        case .inviteMembers:
            return [.large]
        case .manageMembers:
            return [.large]
        case .manageRoles:
            return [.large]
        case .manageReports:
            return [.large]
        case .manageGuildWatchlist:
            return [.large]
        }
    }

    @MainActor
    private func handleNotificationRoute(_ route: NotificationDrawerRoute) async {
        do {
            switch route {
            case .announcement(let announcementId):
                let announcement: RLGuildAnnouncementWithAuthorDTO
                if let cached = leftDrawerViewModel.announcements.first(where: { $0.id == announcementId }) {
                    announcement = cached
                } else {
                    announcement = try await rlAppState.realApi.getAnnouncement(announcementId: announcementId)
                    if let guildId = rlAppState.currentGuild?.id, guildId == announcement.guildId {
                        if let index = leftDrawerViewModel.announcements.firstIndex(where: { $0.id == announcementId }) {
                            leftDrawerViewModel.announcements[index] = announcement
                        } else {
                            leftDrawerViewModel.announcements.insert(announcement, at: 0)
                        }
                    }
                }
                navigationState = .announcements
                bottomSheetContent = .announcement(announcement)

            case .event(let eventId):
                guard let guildId = rlAppState.currentGuild?.id else {
                    rlAppState.showInfo(RLUserFacingCopy.text(.errorSelectGuildFirst))
                    return
                }
                let event: RLGuildEventWithAuthorDTO?
                if let cached = leftDrawerViewModel.upcomingEvents.first(where: { $0.id == eventId }) {
                    event = cached
                } else {
                    let fetchedEvents = try await rlAppState.fetchGuildEvents(guildId: guildId)
                    event = fetchedEvents.first(where: { $0.id == eventId })
                }
                guard let event else {
                    rlAppState.showInfo("Event details are no longer available")
                    return
                }
                if leftDrawerViewModel.upcomingEvents.contains(where: { $0.id == event.id }) == false {
                    leftDrawerViewModel.upcomingEvents.insert(event, at: 0)
                }
                navigationState = .events
                bottomSheetContent = .event(event)

            case .currentUserProfile:
                navigationState = .main
                bottomSheetContent = .profile

            case .guildMemberProfile(let userId):
                guard let guildId = rlAppState.currentGuild?.id else {
                    rlAppState.showInfo(RLUserFacingCopy.text(.errorSelectGuildFirst))
                    return
                }
                let member: RLGuildMemberDTO
                if let cached = leftDrawerViewModel.guildMembers.first(where: { $0.userId == userId }) {
                    member = cached
                } else {
                    member = try await rlAppState.fetchGuildMember(guildId: guildId, userId: userId)
                }
                navigationState = .userList
                bottomSheetContent = .guildMemberRL(member)

            case .adminReports:
                guard enforceNavigationAccess(for: .adminPanel) else {
                    return
                }
                navigationState = .adminPanel
                bottomSheetContent = .manageReports

            case .reportResolution(let summary):
                navigationState = .notifications
                bottomSheetContent = .reportResolution(summary)
            }
        } catch {
            rlAppState.showError(error, title: "Unable to Open Notification", style: .toast)
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
    let presentBetaFeedback: () -> Void
    
    @EnvironmentObject var rlAppState: RLAppState

    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    @State private var showInviteHub = false

    /// Member count: from loaded guild members when available, else guild DTO.
    private var memberCount: Int {
        if leftDrawerViewModel.guildMembersTotalCount > 0 { return leftDrawerViewModel.guildMembersTotalCount }
        return rlAppState.currentGuild?.memberCount ?? 0
    }
    
    /// Online count: from loaded guild members when available, else guild DTO.
    private var onlineCount: Int {
        if !leftDrawerViewModel.guildMembers.isEmpty {
            return leftDrawerViewModel.guildMembers.reduce(into: 0) { total, member in
                if rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline) {
                    total += 1
                }
            }
        }
        return rlAppState.currentGuild?.membersOnline ?? 0
    }
    
    /// Guild reputation: sum of member reputations when members loaded, else guild DTO.
    private var guildReputation: Int {
        if !leftDrawerViewModel.guildMembers.isEmpty {
            return leftDrawerViewModel.guildMembers.reduce(0) { $0 + $1.reputation }
        }
        return rlAppState.currentGuild?.reputation ?? 0
    }
    
    /// Guild accuracy: from statistics when loaded, else placeholder.
    private var guildAccuracyDisplay: String {
        leftDrawerViewModel.statistics?.averageAccuracyDisplay ?? "--"
    }
    
    /// Menu configuration for the left drawer home screen.
    /// Each entry maps to a destination `DrawerNavigationState`.
    var menuItems: [(icon: String, title: String, badge: DrawerMenuBadge?, action: DrawerMenuAction)] {
        var items: [(icon: String, title: String, badge: DrawerMenuBadge?, action: DrawerMenuAction)] = [
            ("megaphone.fill", "Announcements", leftDrawerViewModel.hasUnreadAnnouncements ? .unreadDot : nil, .navigate(.announcements)),
            ("bell.fill", "Notifications", leftDrawerViewModel.hasUnreadNotifications ? .unreadDot : nil, .navigate(.notifications)),
            ("target", "Markers", nil, .navigate(.topMarkers)),
            ("trophy.fill", "Leaderboard", nil, .navigate(.leaderboard)),
            ("star.fill", "Watchlists", nil, .navigate(.guildWatchlist)),
            ("calendar.badge.clock", "Events", leftDrawerViewModel.hasUnreadEvents ? .unreadDot : nil, .navigate(.events)),
            ("person.2.fill", "User List", nil, .navigate(.userList)),
            ("chart.bar.fill", "Statistics", nil, .navigate(.statistics)),
            ("flask.fill", "Beta Feedback", nil, .betaFeedback)
        ]
        
        // Add Admin/Mod Panel for moderators and admins
        if rlAppState.canModerate {
            let panelTitle = rlAppState.isGuildOwner ? "Owner Panel" : (rlAppState.canAdmin ? "Admin Panel" : "Mod Panel")
            items.append(("shield.checkered", panelTitle, nil, .navigate(.adminPanel)))
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

    /// Owner/admin promo encouraging guild growth. Opens the invite hub.
    /// Styled to match the "Refer Friends" button in the user list.
    private var inviteGuildPromoButton: some View {
        Button {
            showInviteHub = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.onAccentForeground.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.onAccentForeground)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Invite to your guild")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.onAccentForeground)
                    Text("Grow your community — share on X, Discord & more.")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.onAccentForeground.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.onAccentForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.friendAccent.opacity(0.96),
                                AppColors.statusPositive70.opacity(0.82),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.onAccentForeground.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }


    var body: some View {
        if let rlUser = rlAppState.currentUser,
           let rlGuild = rlAppState.currentGuild,
           let rlMembership = rlAppState.currentMembership {
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
                    GuildCrestView(guild: rlGuild, size: 38)

                    Text(rlGuild.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.guildReputationAccent)
                    + Text(" Guild")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.guildReputationAccent)
                    
                    
                    Spacer()
                }
                
                HStack(spacing: 2) {
                    Text("\(memberCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    + Text(" Members")
                        .font(.caption)
                        .foregroundColor(AppColors.drawerHeaderSecondaryForeground)
                    Circle()
                        .fill(AppColors.drawerHeaderSecondaryForeground)
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Text("\(onlineCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    + Text(" Online")
                        .font(.caption)
                        .foregroundColor(AppColors.drawerHeaderSecondaryForeground)
                    Circle()
                        .fill(AppColors.onlineStatusGreen)
                        .frame(width: 7, height: 7)
                        .padding(.top, 0)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Spacer()
                }
                .padding(.top, 6)
                
                HStack(spacing: 2) {
                    ReputationGlyph(size: 13)
                        .foregroundColor(AppColors.guildReputationAccent)
                    Text("\(guildReputation)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.guildReputationAccent)
                    + Text(" Guild Reputation")
                        .font(.caption)
                        .foregroundColor(AppColors.drawerHeaderSecondaryForeground)
                    Circle()
                        .fill(AppColors.drawerHeaderSecondaryForeground)
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Image(systemName: "target")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    Text(guildAccuracyDisplay)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    + Text(" Guild Accuracy")
                        .font(.caption)
                        .foregroundColor(AppColors.drawerHeaderSecondaryForeground)
                    Spacer()
                }
                .padding(.top, 6)
                
                Text("\(rlGuild.description ?? "No Description Provided")")
                    .font(.caption)
                    .foregroundColor(AppColors.drawerHeaderSecondaryForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .multilineTextAlignment(.leading)
                
                Rectangle()
                    .fill(AppColors.surfaceGray40)
                    .frame(height: 0.5)
                    .padding(.top, 6)
            }
            .padding(.leading, 25)
            .padding(.trailing, 25)
            .padding(.bottom, 4)
            .padding(.top, 60)
            .spotlightTarget("guild-header")

            // Menu Items
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(menuItems, id: \.title) { item in
                        DrawerMenuButton(
                            icon: item.icon,
                            title: item.title,
                            badge: item.badge,
                            action: {
                                switch item.action {
                                case .navigate(let state):
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        navigationState = state
                                    }
                                case .betaFeedback:
                                    presentBetaFeedback()
                                }
                            }
                        )
                        .spotlightTarget("menu-\(item.title)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .spotlightTarget("guild-menu-area")
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                // ✅ Pull to refresh - only refresh announcements on main view
                // Other data refreshes when navigating to specific sections
                await leftDrawerViewModel.refreshAnnouncements(guildId: rlGuild.id, rlAppState: rlAppState)
            }
            .overlay {
                // ✅ Show loading only on first load
                if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColors.drawerHeaderPrimaryForeground)
                        Text("Loading...")
                            .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.gradientBackgroundDark.opacity(0.9))
                }
            }
            
            // Footer
            VStack(spacing: 16) {

                // Owner/admin invite promo — sits below the Admin Panel menu
                // item and above the user profile row.
                if rlAppState.canModerate {
                    inviteGuildPromoButton
                }

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
        .sheet(isPresented: $showInviteHub) {
            GuildInviteHubView(
                headline: "Grow \(rlAppState.currentGuild?.name ?? "your guild")",
                subheadline: "Invite traders from X, Discord, and your contacts to join your guild.",
                primaryButtonTitle: "Done",
                shareMode: .guildVanity
            )
            .environmentObject(rlAppState)
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
                            Text(guild.name)
                                .font(.headline)
                                .fontWeight(.bold)
                            + Text(" Guild")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.drawerSectionTitleForeground)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(AnimationConstants.standard) { onClose() }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.drawerSectionDismissForeground)
                            
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)
                
                HStack(alignment: .center, spacing: 12) {
                    Text(sectionTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.drawerSectionTitleForeground)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(AppColors.surfaceGray40)
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
                        await refreshCurrentSection(guildId: guild.id, rlAppState: rlAppState)
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
        case .topMarkers: return "Markers"
        case .leaderboard: return "Leaderboard"
        case .guildWatchlist: return "Watchlist"
        case .events: return "Events"
        case .userList: return "Members"
        case .statistics: return "Statistics"
        case .adminPanel: return rlAppState.canAdmin ? "Admin Panel" : "Mod Panel"
        
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
    private func refreshCurrentSection(guildId: UUID, rlAppState: RLAppState) async {
        switch currentSection {
        case .announcements:
            await leftDrawerViewModel.refreshAnnouncements(guildId: guildId, rlAppState: rlAppState)
        case .events:
            await leftDrawerViewModel.refreshEvents(guildId: guildId, rlAppState: rlAppState)
        case .userList:
            await leftDrawerViewModel.refreshGuildMembers(guildId: guildId, rlAppState: rlAppState)
        case .notifications:
            await leftDrawerViewModel.refreshNotifications(rlAppState: rlAppState)
        case .statistics:
             await leftDrawerViewModel.refreshStatistics(guildId: guildId, rlAppState: rlAppState)
        case .topMarkers:
            await leftDrawerViewModel.refreshTopMarkers(for: guildId, rlAppState: rlAppState)
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
    let badge: DrawerMenuBadge?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    .frame(width: 38, alignment: .leading)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.drawerHeaderPrimaryForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let badge {
                    switch badge {
                    case .unreadDot:
                        Circle()
                            .fill(AppColors.accentColor)
                            .frame(width: 10, height: 10)
                    case .count(let count) where count > 0:
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(AppColors.onAccentForeground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accentColor)
                            .clipShape(Capsule())
                    default:
                        EmptyView()
                    }
                }
                
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
//            .background(
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(AppColors.surfaceWhite08)
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
    @Binding var bottomSheetContent: BottomSheetContent?
    
    @EnvironmentObject var rlAppState: RLAppState
    
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .announcement(let announcement):
                AnnouncementDetailView(announcement: announcement)
            case .event(let event):
                EventDetailView(event: event)
            case .reportResolution(let summary):
                ReportResolutionSummaryView(summary: summary)
            case .profile:  // Changed from 'user' to 'membership'
                UserProfileDetailView(selectedDetent: $selectedDetent)
                    .environmentObject(leftDrawerViewModel)
            case .guildMemberRL(let member):
                GuildUserDetailViewRL(member: member)
            case .betaFeedback:
                BetaFeedbackView()
            case .createAnnouncement:
                CreateAnnouncementView()
            case .createEvent:
                CreateEventView()
            case .guildSettings:
                GuildSettingsView()
            case .manageChatrooms:
                ManageChatroomsView()
            case .inviteMembers:
                InviteMembersView()
            case .manageMembers:
                ManageMembersView()
            case .manageRoles:
                ManageRolesView()
            case .manageReports:
                ManageReportsView(bottomSheetContent: $bottomSheetContent)
            case .manageGuildWatchlist:
                ManageGuildWatchlistView()
            }

        }
        
        
        .overlay(
            RoundedRectangle(cornerRadius: 33)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppColors.surfaceWhite15,
                            AppColors.surfaceWhite00
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .shadow(color: AppColors.surfaceBlack20, radius: 15, x: 0, y: 0)
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
