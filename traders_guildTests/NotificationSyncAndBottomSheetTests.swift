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
        try? await Task.sleep(nanoseconds: 10_000_000)

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
}
