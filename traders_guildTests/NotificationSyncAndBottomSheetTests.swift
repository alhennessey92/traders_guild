import Foundation
import Testing
@testable import traders_guild

@MainActor
struct NotificationSyncAndBottomSheetTests {
    @Test
    func statsIncreaseWithoutRealtimeInsertSchedulesCatchUpRefresh() async {
        let viewModel = LeftDrawerViewModel()
        let initialStats = RLNotificationStatsDTO(totalCount: 2, unreadCount: 0, personalCount: 0, guildCount: 0)
        let updatedStats = RLNotificationStatsDTO(totalCount: 3, unreadCount: 1, personalCount: 1, guildCount: 0)
        var refreshCount = 0

        viewModel.notificationResyncDebounceNanoseconds = 0
        viewModel.notificationRefreshActionOverride = {
            refreshCount += 1
        }
        viewModel.applyNotificationStats(initialStats)

        viewModel.handleNotificationStatsUpdate(updatedStats)
        let deadline = Date().addingTimeInterval(1)
        while viewModel.pendingNotificationCatchUpRefresh, Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        #expect(refreshCount == 1)
        #expect(viewModel.notificationStats == updatedStats)
        #expect(viewModel.pendingNotificationCatchUpRefresh == false)
    }

    @Test
    func statsIncreaseAfterRealtimeInsertDoesNotScheduleCatchUpRefresh() async {
        let viewModel = LeftDrawerViewModel()
        let initialStats = RLNotificationStatsDTO(totalCount: 2, unreadCount: 0, personalCount: 0, guildCount: 0)
        let updatedStats = RLNotificationStatsDTO(totalCount: 3, unreadCount: 1, personalCount: 1, guildCount: 0)
        var refreshCount = 0

        viewModel.notificationResyncDebounceNanoseconds = 0
        viewModel.notificationRefreshActionOverride = {
            refreshCount += 1
        }
        viewModel.applyNotificationStats(initialStats)
        viewModel.handleRealtimeNotificationInsert(makeNotification())

        viewModel.handleNotificationStatsUpdate(updatedStats)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(refreshCount == 0)
        #expect(viewModel.pendingNotificationCatchUpRefresh == false)
    }

    @Test
    func notificationsOpenRefreshesWhenStatsAreNewerThanCachedList() async {
        let viewModel = LeftDrawerViewModel()
        let appState = RLAppState()
        var refreshCount = 0

        viewModel.notificationRefreshActionOverride = {
            refreshCount += 1
        }
        viewModel.applyNotificationStats(
            RLNotificationStatsDTO(totalCount: 2, unreadCount: 1, personalCount: 1, guildCount: 0),
            updatedAt: Date()
        )

        await viewModel.refreshNotificationsIfNeeded(rlAppState: appState)

        #expect(refreshCount == 1)
    }

    @Test
    func friendRequestNotificationResolvesPendingRequestBySenderUserId() {
        let viewModel = LeftDrawerViewModel()
        let requestId = UUID()
        let fromMembershipId = UUID()
        let fromUserId = UUID()
        let now = Date()

        viewModel.pendingFriendRequestsIncoming = [
            RLFriendRequestIncomingDTO(
                id: requestId,
                fromMembershipId: fromMembershipId,
                fromUserId: fromUserId,
                fromUsername: "alice",
                fromDisplayName: "Alice",
                fromAvatarUrl: nil,
                message: "Let's connect",
                createdAt: now
            )
        ]

        let notification = RLNotificationDTO(
            id: UUID(),
            recipientId: UUID(),
            notificationType: RLNotificationType.friendRequest.rawValue,
            title: "Alice sent you a friend request",
            body: "Let's connect",
            data: [
                "from_user_id": .string(fromUserId.uuidString),
                "from_username": .string("alice"),
                "from_display_name": .string("Alice")
            ],
            destination: nil,
            isRead: false,
            readAt: nil,
            viewCount: 0,
            firstViewedAt: nil,
            lastViewedAt: nil,
            createdAt: now,
            updatedAt: now
        )

        #expect(viewModel.incomingFriendRequest(for: notification)?.id == requestId)
    }

    @Test
    func realtimeFriendNotificationRefreshesFriendCaches() async {
        let viewModel = LeftDrawerViewModel()
        var refreshCount = 0

        viewModel.friendRelationshipRefreshActionOverride = {
            refreshCount += 1
        }

        viewModel.handleRealtimeNotificationInsert(makeFriendRequestNotification())
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(refreshCount == 1)
    }

    @Test
    func privateGuildCreationRequiresAtLeastOneJoinQuestion() async {
        let appState = RLAppState()

        do {
            _ = try await appState.createGuild(
                name: "Invite Only Guild",
                description: nil,
                isOpen: false,
                language: "English",
                location: "United Kingdom",
                joinQuestions: [],
                initialAnnouncementTitle: "Welcome",
                initialAnnouncementContent: "Introduce yourself."
            )
            Issue.record("Expected private guild creation to fail without a join question")
        } catch let APIError.badRequest(detail) {
            #expect(detail == "private_guild_question_required")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(appState.currentAlert?.title == "Join Question Required")
    }

    @Test
    func privilegedDrawerSheetsRejectMemberRole() {
        #expect(BottomSheetContent.manageReports.isAllowed(for: .member) == false)
        #expect(BottomSheetContent.manageMembers.isAllowed(for: .member) == false)
        #expect(BottomSheetContent.manageRoles.isAllowed(for: .member) == false)
        #expect(BottomSheetContent.reportResolution(
            RLReportResolutionSummary(
                reportId: UUID(),
                guildId: UUID(),
                guildName: "Guild",
                contentType: "chatroom_message",
                resolutionStatus: "resolved",
                reviewerDisplayName: "Moderator Mia",
                resolutionNote: "Removed for spam.",
                notifiedAt: Date()
            )
        ).isAllowed(for: .member))
        #expect(BottomSheetContent.manageReports.isAllowed(for: .moderator))
        #expect(BottomSheetContent.manageRoles.isAllowed(for: .moderator) == false)
        #expect(BottomSheetContent.manageRoles.isAllowed(for: .admin))
    }

    @Test
    func collapsingMarkerChatResetsBottomBarToGeneralTab() {
        let resolvedTab = ChartBottomSheetStateReducer.markerDetailTabAfterDetentChange(
            oldDetent: .fraction(0.35),
            newDetent: .fraction(0.11),
            isMarkerDetailActive: true,
            currentTab: .chat
        )

        #expect(resolvedTab == .general)
    }

    @Test
    func expandedMarkerChatKeepsCurrentTab() {
        let resolvedTab = ChartBottomSheetStateReducer.markerDetailTabAfterDetentChange(
            oldDetent: .fraction(0.35),
            newDetent: .fraction(0.5),
            isMarkerDetailActive: true,
            currentTab: .chat
        )

        #expect(resolvedTab == .chat)
    }

    private func makeNotification() -> RLNotificationDTO {
        let now = Date()
        return RLNotificationDTO(
            id: UUID(),
            recipientId: UUID(),
            notificationType: RLNotificationType.dm.rawValue,
            title: "New message",
            body: "Test",
            data: [:],
            destination: nil,
            isRead: false,
            readAt: nil,
            viewCount: 0,
            firstViewedAt: nil,
            lastViewedAt: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeFriendRequestNotification() -> RLNotificationDTO {
        let now = Date()
        return RLNotificationDTO(
            id: UUID(),
            recipientId: UUID(),
            notificationType: RLNotificationType.friendRequest.rawValue,
            title: "Friend request",
            body: "Test",
            data: ["from_user_id": .string(UUID().uuidString)],
            destination: nil,
            isRead: false,
            readAt: nil,
            viewCount: 0,
            firstViewedAt: nil,
            lastViewedAt: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
