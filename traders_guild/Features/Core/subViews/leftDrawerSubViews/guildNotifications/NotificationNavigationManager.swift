//
//  NotificationNavigationManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 03/11/2025.
//
import SwiftUI

enum NotificationDrawerRoute: Equatable, Identifiable {
    case announcement(announcementId: UUID)
    case event(eventId: UUID)
    case currentUserProfile
    case guildMemberProfile(userId: UUID)
    case adminReports(guildId: UUID?, reportId: UUID?)
    case reportResolution(summary: RLReportResolutionSummary)

    var id: String {
        switch self {
        case .announcement(let announcementId):
            return "announcement-\(announcementId.uuidString)"
        case .event(let eventId):
            return "event-\(eventId.uuidString)"
        case .currentUserProfile:
            return "current-user-profile"
        case .guildMemberProfile(let userId):
            return "guild-member-\(userId.uuidString)"
        case .adminReports(let guildId, let reportId):
            return "admin-reports-\(guildId?.uuidString ?? "none")-\(reportId?.uuidString ?? "none")"
        case .reportResolution(let summary):
            return "report-resolution-\(summary.reportId.uuidString)"
        }
    }
}


@MainActor
class NotificationNavigationManager: ObservableObject {
    /// Loading state while navigating
    @Published var isNavigating: Bool = false
    
    // Dependencies
    private weak var rlAppState: RLAppState?
    private weak var messagingManager: RLMessagingManager?
    private weak var rightDrawerViewModel: RLRightDrawerViewModel?
    private var dismissOverlays: (() -> Void)?
    private var presentLeftDrawerRoute: ((NotificationDrawerRoute) -> Void)?
    
    // ============================================================================
    // Initialization
    // ============================================================================
    
    init(rlAppState: RLAppState? = nil,
         messagingManager: RLMessagingManager? = nil,
         rightDrawerViewModel: RLRightDrawerViewModel? = nil,
         dismissOverlays: (() -> Void)? = nil,
         presentLeftDrawerRoute: ((NotificationDrawerRoute) -> Void)? = nil) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
        self.dismissOverlays = dismissOverlays
        self.presentLeftDrawerRoute = presentLeftDrawerRoute
    }
    
    /// Configure manager with required dependencies
    func configure(
        rlAppState: RLAppState,
        messagingManager: RLMessagingManager,
        rightDrawerViewModel: RLRightDrawerViewModel,
        dismissOverlays: @escaping () -> Void,
        presentLeftDrawerRoute: @escaping (NotificationDrawerRoute) -> Void
    ) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
        self.dismissOverlays = dismissOverlays
        self.presentLeftDrawerRoute = presentLeftDrawerRoute
    }
    
    // ============================================================================
    // Navigation Methods
    // ============================================================================
    
    /// Main entry point: Handle navigation for a notification
    func navigate(to notification: RLNotificationDTO) async {
        let reportResolutionSummary = notification.contentReportResolutionSummary
        let requestedProfileTab: ProfileTab? = notification.type == .awardEarned ? .awards : nil

        let shareResultOnOpen = notification.type == .markerResult
        let markerGuildId = notification.markerGuildId
        if let payload = notification.markerNavigationPayload {
            openMarker(payload, shareOnOpen: shareResultOnOpen, guildId: markerGuildId)
            return
        }

        if let markerId = notification.markerId,
           let payload = await recoverMarkerNavigationPayload(markerId: markerId) {
            openMarker(payload, shareOnOpen: shareResultOnOpen, guildId: markerGuildId)
            return
        }

        if notification.destination?.type == .symbolChart || notification.markerId != nil {
            print("⚠️ Marker notification '\(notification.displayTitle)' is missing chart context")
            rlAppState?.showInfo("This marker notification could not be opened")
            return
        }

        guard let destination = notification.navigationDestination else {
            print("⚠️ Notification '\(notification.displayTitle)' has no valid destination")
            rlAppState?.showInfo("This notification cannot be opened")
            return
        }
        await navigate(
            to: destination,
            reportResolutionSummary: reportResolutionSummary,
            requestedProfileTab: requestedProfileTab
        )
    }

    func navigate(to pushPayload: RLPushNotificationTapPayload) async {
        let reportResolutionSummary = pushPayload.contentReportResolutionSummary
        let requestedProfileTab: ProfileTab? = pushPayload.notificationType == RLNotificationType.awardEarned.rawValue ? .awards : nil

        let shareResultOnOpen =
            pushPayload.notificationType == RLNotificationType.markerResult.rawValue
        let markerGuildId = pushPayload.markerGuildId
        if let payload = pushPayload.markerNavigationPayload {
            openMarker(payload, shareOnOpen: shareResultOnOpen, guildId: markerGuildId)
            return
        }

        if let markerId = pushPayload.markerId,
           let payload = await recoverMarkerNavigationPayload(markerId: markerId) {
            openMarker(payload, shareOnOpen: shareResultOnOpen, guildId: markerGuildId)
            return
        }

        if pushPayload.destination?.type == .symbolChart || pushPayload.markerId != nil {
            print("⚠️ Push notification '\(pushPayload.notificationType)' is missing chart context")
            rlAppState?.showInfo("This marker notification could not be opened")
            return
        }

        guard let destination = pushPayload.navigationDestination else {
            print("⚠️ Push notification '\(pushPayload.notificationType)' has no valid destination")
            rlAppState?.showInfo("This notification cannot be opened")
            return
        }
        await navigate(
            to: destination,
            reportResolutionSummary: reportResolutionSummary,
            requestedProfileTab: requestedProfileTab
        )
    }
    
    /// Navigate to a specific destination
    func navigate(
        to destination: NotificationDestination,
        reportResolutionSummary: RLReportResolutionSummary? = nil,
        requestedProfileTab: ProfileTab? = nil
    ) async {
        guard let rlAppState = rlAppState,
              let messagingManager = messagingManager else {
            print("⚠️ NotificationNavigationManager not properly configured")
            return
        }
        
        isNavigating = true
        defer { isNavigating = false }
        
        do {
            switch destination {
            // ============================================================================
            // CASE 1: Navigate to User DM
            // ============================================================================
            case .userDM(let userId):
                dismissOverlays?()
                if let thread = rightDrawerViewModel?.findDMThread(for: userId) {
                    messagingManager.openDMThread(thread)
                    return
                }
                
                guard let guildId = rlAppState.currentGuild?.id else {
                    rlAppState.showInfo("Guild not ready")
                    return
                }
                
                let member = try await rlAppState.fetchGuildMember(guildId: guildId, userId: userId)
                await messagingManager.openDMChat(with: member)
                
            // ============================================================================
            // CASE 2: Navigate to Chatroom
            // ============================================================================
            case .chatroom(let chatroomId):
                dismissOverlays?()
                if let cached = rightDrawerViewModel?.findChatroom(id: chatroomId) {
                    messagingManager.openChatroom(cached)
                    return
                }
                
                let chatroom = try await rlAppState.fetchChatroom(chatroomId: chatroomId)
                messagingManager.openChatroom(chatroom)
                
            // ============================================================================
            // CASE 3: Navigate to Symbol Chart
            // ============================================================================
            case .symbolChart(let symbolId, let ticker):
                print("🔔 Navigate to chart for \(ticker) (Symbol ID: \(symbolId))")
                rlAppState.showInfo("This chart notification is missing marker context")
                
            // ============================================================================
            // CASE 4: Navigate to User Profile
            // ============================================================================
            case .userProfile(let userId):
                if userId == rlAppState.currentUser?.id {
                    presentLeftDrawerRoute?(.currentUserProfile)
                } else {
                    presentLeftDrawerRoute?(.guildMemberProfile(userId: userId))
                }
                if let requestedProfileTab {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(
                            name: .profileTabRequested,
                            object: requestedProfileTab
                        )
                    }
                }
                
            // ============================================================================
            // CASE 5: Navigate to Announcement
            // ============================================================================
            case .announcement(let announcementId):
                presentLeftDrawerRoute?(.announcement(announcementId: announcementId))

            case .event(let eventId):
                presentLeftDrawerRoute?(.event(eventId: eventId))

            case .adminReports(let guildId, let reportId):
                if rlAppState.canModerate {
                    presentLeftDrawerRoute?(.adminReports(guildId: guildId, reportId: reportId))
                } else if let reportResolutionSummary {
                    presentLeftDrawerRoute?(.reportResolution(summary: reportResolutionSummary))
                } else {
                    rlAppState.showInfo("This report update is no longer available")
                }
            }
            
        } catch is CancellationError {
            return
        } catch {
            rlAppState.showError(error, title: "Navigation Failed", style: .toast)
        }
    }

    /// Key carried alongside the marker payload when the marker should land with its share
    /// sheet already up. See `shareOnOpen` below.
    static let shareOnOpenKey = "tg.marker.shareOnOpen"

    /// The guild the marker belongs to. A marker is guild-scoped, but a notification can
    /// arrive while its author is looking at a different guild — so the destination has to
    /// travel with it or the chart looks for the marker somewhere it was never going to be.
    static let markerGuildKey = "tg.marker.guildId"

    /// - Parameter shareOnOpen: set for `marker_result` only. A tracked setup usually
    ///   resolves while the app is closed, so the push is the only moment the author hears
    ///   about it — and "take me to the thing I can post" is why they tapped. A like or a
    ///   comment gets the marker and nothing more.
    private func openMarker(
        _ payload: MarkerSharePayloadV1,
        shareOnOpen: Bool = false,
        guildId: UUID? = nil
    ) {
        dismissOverlays?()
        var userInfo = payload.notificationUserInfo
        if shareOnOpen {
            userInfo[Self.shareOnOpenKey] = true
        }
        if let guildId {
            userInfo[Self.markerGuildKey] = guildId
        }
        NotificationCenter.default.post(
            name: .openSharedMarker,
            object: nil,
            userInfo: userInfo
        )
    }

    private func recoverMarkerNavigationPayload(markerId: UUID) async -> MarkerSharePayloadV1? {
        guard let rlAppState else { return nil }

        do {
            let marker = try await rlAppState.realApi.getMarker(markerId: markerId)
            return MarkerSharePayloadV1(
                markerId: marker.id,
                symbolId: marker.symbolId,
                symbolTicker: nil,
                timeframe: marker.timeframe,
                candleTimestamp: marker.candleTimestamp,
                intent: marker.intent,
                alertSeverity: marker.alertSeverity
            )
        } catch APIError.serverError(let statusCode, _) where statusCode == 404 {
            print("⚠️ Marker \(markerId) no longer exists for notification routing")
            return nil
        } catch {
            print("⚠️ Failed to recover marker \(markerId) for notification routing: \(error)")
            return nil
        }
    }
    
}
