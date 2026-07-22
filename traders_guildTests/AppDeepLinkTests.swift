import Foundation
import Testing
@testable import traders_guild

struct AppDeepLinkTests {
    private let markerId = UUID(uuidString: "6A235097-76B1-43E4-9F4E-2AE9A81608FF")!

    @Test
    func parsesMarkerAcrossCustomAndTrustedWebHosts() {
        let expected = AppDeepLink.marker(markerId)
        let links = [
            "tradersguild://marker/\(markerId.uuidString)",
            "https://tradersguild.co/marker/\(markerId.uuidString)",
            "https://tradersguild.co/marker/\(markerId.uuidString)?share_token=\(String(repeating: "s", count: 43))",
            "https://open.tradersguild.co/marker/\(markerId.uuidString)",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == expected)
        }
    }

    @Test
    func parsesInviteAcrossCustomAndTrustedWebHosts() {
        let links = [
            "tradersguild://invite?code=ABC123",
            "https://tradersguild.co/invite/ABC123",
            "https://open.tradersguild.co/invite/ABC123",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == .referralInvite("ABC123"))
        }
    }

    @Test
    func parsesGuildAcrossCustomAndTrustedWebHosts() {
        let links = [
            "tradersguild://g/macro-traders",
            "https://tradersguild.co/g/macro-traders",
            "https://open.tradersguild.co/g/macro-traders",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == .guildSlug("macro-traders"))
        }
    }

    @Test
    func retainsAuthenticationLinkParsing() {
        #expect(
            AppDeepLink(url: URL(string: "tradersguild://reset-password?token=RESET1")!)
                == .passwordReset("RESET1")
        )
        #expect(
            AppDeepLink(url: URL(string: "https://tradersguild.co/verify-email?token=VERIFY1")!)
                == .emailVerification("VERIFY1")
        )
    }

    @Test
    func rejectsForeignAndInsecureWebLinks() {
        let links = [
            "https://example.com/marker/\(markerId.uuidString)",
            "http://tradersguild.co/marker/\(markerId.uuidString)",
            "https://nottradersguild.co/invite/ABC123",
        ]

        for raw in links {
            #expect(AppDeepLink(url: URL(string: raw)!) == nil)
        }
    }

    @Test @MainActor
    func routesColdAndWarmMarkerLinksToTheExactPendingDestination() {
        let destination = DeepLinkDestinationSpy()
        let coldMarkerId = markerId
        let warmMarkerId = UUID(uuidString: "0CFA0D46-5773-42E3-9099-CBB4D3E0519E")!

        #expect(
            AppDeepLinkRouter.route(
                URL(string: "https://open.tradersguild.co/marker/\(coldMarkerId.uuidString)")!,
                to: destination
            )
        )
        #expect(destination.markerId == coldMarkerId)

        #expect(
            AppDeepLinkRouter.route(
                URL(string: "tradersguild://marker/\(warmMarkerId.uuidString)")!,
                to: destination
            )
        )
        #expect(destination.markerId == warmMarkerId)
    }

    @Test @MainActor
    func routesInviteGuildAndAuthenticationDestinations() {
        let destination = DeepLinkDestinationSpy()

        #expect(AppDeepLinkRouter.route(URL(string: "https://tradersguild.co/invite/ABC123")!, to: destination))
        #expect(destination.inviteCode == "ABC123")

        #expect(AppDeepLinkRouter.route(URL(string: "https://open.tradersguild.co/g/macro-traders")!, to: destination))
        #expect(destination.guildSlug == "macro-traders")

        #expect(AppDeepLinkRouter.route(URL(string: "tradersguild://reset-password?token=RESET1")!, to: destination))
        #expect(destination.passwordResetToken == "RESET1")

        #expect(AppDeepLinkRouter.route(URL(string: "tradersguild://verify-email?token=VERIFY1")!, to: destination))
        #expect(destination.emailVerificationToken == "VERIFY1")
    }

    @Test
    func coldLaunchMarkerWaitsForSessionGuildAndReadyChart() {
        let targetGuildId = UUID(uuidString: "65EF05B7-ADAE-4BCC-A193-86C89C179E21")!
        let otherGuildId = UUID(uuidString: "7FAAB798-A06E-4A60-8965-6AA931F1287D")!

        #expect(!MarkerDeepLinkRoutingPolicy.canResolve(
            isSessionRestored: false,
            isAuthenticated: true,
            isCurrentUserVerified: true,
            hasCurrentGuild: false
        ))
        #expect(!MarkerDeepLinkRoutingPolicy.canResolve(
            isSessionRestored: true,
            isAuthenticated: true,
            isCurrentUserVerified: false,
            hasCurrentGuild: true
        ))
        #expect(MarkerDeepLinkRoutingPolicy.canResolve(
            isSessionRestored: true,
            isAuthenticated: true,
            isCurrentUserVerified: true,
            hasCurrentGuild: true
        ))

        #expect(!MarkerDeepLinkRoutingPolicy.canNavigate(
            requestGuildId: targetGuildId,
            currentGuildId: targetGuildId,
            isChartReady: false,
            isTransitionVisible: false,
            isInteractionUnlocked: true
        ))
        #expect(!MarkerDeepLinkRoutingPolicy.canNavigate(
            requestGuildId: targetGuildId,
            currentGuildId: otherGuildId,
            isChartReady: true,
            isTransitionVisible: false,
            isInteractionUnlocked: true
        ))
        #expect(!MarkerDeepLinkRoutingPolicy.canNavigate(
            requestGuildId: targetGuildId,
            currentGuildId: targetGuildId,
            isChartReady: true,
            isTransitionVisible: true,
            isInteractionUnlocked: true
        ))
        #expect(!MarkerDeepLinkRoutingPolicy.canNavigate(
            requestGuildId: targetGuildId,
            currentGuildId: targetGuildId,
            isChartReady: true,
            isTransitionVisible: false,
            isInteractionUnlocked: false
        ))
        #expect(MarkerDeepLinkRoutingPolicy.canNavigate(
            requestGuildId: targetGuildId,
            currentGuildId: targetGuildId,
            isChartReady: true,
            isTransitionVisible: false,
            isInteractionUnlocked: true
        ))
    }

    @Test @MainActor
    func resolvedMarkerHandoffSurvivesUntilMatchingChartAcknowledgement() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let guildId = UUID(uuidString: "65EF05B7-ADAE-4BCC-A193-86C89C179E21")!
        let payload = markerPayload(markerId: markerId)

        appState.setPendingMarkerLinkId(markerId)
        let relaunchedState = RLAppState(restoreSessionOnInit: false)
        #expect(relaunchedState.pendingMarkerLinkId == markerId)

        let request = appState.stagePendingMarkerNavigation(
            markerId: markerId,
            guildId: guildId,
            payload: payload
        )

        #expect(request != nil)
        #expect(appState.pendingMarkerLinkId == markerId)
        #expect(appState.pendingMarkerNavigationRequest == request)

        appState.acknowledgePendingMarkerNavigation(requestId: UUID())
        #expect(appState.pendingMarkerLinkId == markerId)
        #expect(appState.pendingMarkerNavigationRequest == request)

        appState.acknowledgePendingMarkerNavigation(requestId: request!.id)
        #expect(appState.pendingMarkerLinkId == nil)
        #expect(appState.pendingMarkerNavigationRequest == nil)
    }

    @Test @MainActor
    func markerNavigationWatchdogTerminatesTheMatchingLoadingSession() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let chartViewModel = ChartViewModel(
            appState: appState,
            dataManager: ChartDataManager(),
            api: RealAPIService()
        )
        let target = MarkerNavigationTarget(sharedPayload: markerPayload(markerId: markerId))
        let obsoleteSessionId = chartViewModel.beginMarkerNavigation(target)
        let sessionId = chartViewModel.beginMarkerNavigation(target)

        #expect(chartViewModel.isMarkerNavigationSessionActive(sessionId))
        chartViewModel.expireMarkerNavigationIfActive(sessionId: obsoleteSessionId)
        #expect(chartViewModel.isMarkerNavigationSessionActive(sessionId))

        chartViewModel.expireMarkerNavigationIfActive(sessionId: sessionId)
        #expect(!chartViewModel.isNavigatingToMarker)
        #expect(
            chartViewModel.markerNavigationSession?.phase
                == .failed("Marker loading timed out")
        )
    }

    private func markerPayload(markerId: UUID) -> MarkerSharePayloadV1 {
        MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: UUID(uuidString: "E4A01BF5-1B18-43A8-904E-2776F239F373")!,
            symbolTicker: "BTCUSDT",
            timeframe: "1m",
            candleTimestamp: Date(timeIntervalSince1970: 1_753_200_000),
            intent: "analysis"
        )
    }
}

@MainActor
private final class DeepLinkDestinationSpy: AppDeepLinkDestinationHandling {
    private(set) var inviteCode: String?
    private(set) var guildSlug: String?
    private(set) var markerId: UUID?
    private(set) var passwordResetToken: String?
    private(set) var emailVerificationToken: String?

    func setPendingReferralInviteCode(_ code: String?) { inviteCode = code }
    func setPendingGuildSlug(_ slug: String?) { guildSlug = slug }
    func setPendingMarkerLinkId(_ markerId: UUID) { self.markerId = markerId }
    func setPendingPasswordResetToken(_ token: String?) { passwordResetToken = token }
    func setPendingEmailVerificationToken(_ token: String?) { emailVerificationToken = token }
}
