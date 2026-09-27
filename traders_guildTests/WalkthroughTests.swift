import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// The first-run walkthrough: page model, bundled media, and the biometric
/// deferral that keeps the enrollment offer from landing on top of it.
struct WalkthroughTests {
    @Test
    func pagesAreTheFiveDifferentiatorsInOrder() {
        #expect(WalkthroughPage.allCases == [.hero, .placeMarker, .trackedSetup, .respondChat, .guild])
        #expect(Set(WalkthroughPage.allCases.map(\.slot)).count == 5)
        #expect(WalkthroughPage.hero.next == .placeMarker)
        #expect(WalkthroughPage.guild.next == nil)
    }

    @Test
    func onlyTheLastPageCarriesTheCallToAction() {
        for page in WalkthroughPage.allCases where !page.isLast {
            #expect(page.primaryButtonTitle == "Continue")
            #expect(page.secondaryButtonTitle == nil)
            #expect(page.footnote == nil)
        }
        #expect(WalkthroughPage.guild.isLast)
        #expect(WalkthroughPage.guild.primaryButtonTitle == "Place your first marker")
        #expect(WalkthroughPage.guild.secondaryButtonTitle == "Explore first")
        #expect(WalkthroughPage.guild.footnote?.contains("Binance") == true)
    }

    /// Every slot ships a poster and a clip.
    @Test
    func bundledMediaResolves() {
        let bundle = Bundle(for: RLAppState.self)
        for page in WalkthroughPage.allCases {
            #expect(page.posterURL(in: bundle) != nil, "missing poster for \(page.slot)")
            #expect(page.clipURL(in: bundle) != nil, "missing clip for \(page.slot)")
        }
    }

    @MainActor
    @Test
    func presenterAdvancesAndStopsOnTheLastPage() {
        let presenter = WalkthroughPresenter()
        #expect(presenter.currentPage == .hero)
        #expect(presenter.isOnLastPage == false)
        for _ in 0..<10 { presenter.advance() }
        #expect(presenter.currentPage == .guild)
        #expect(presenter.isOnLastPage)
        #expect(presenter.pageIndex == 4)
    }

    /// A phone has only a few hardware decoders; a player per nearby page starved the
    /// visible one on device. Only the page being shown may ever hold a player.
    @MainActor
    @Test
    func onlyTheVisiblePageHoldsAPlayer() {
        let presenter = WalkthroughPresenter()
        defer { presenter.tearDown() }
        for page in WalkthroughPage.allCases + WalkthroughPage.allCases.reversed() {
            presenter.showClip(for: page)
            #expect(presenter.activeClip?.page == page)
            #expect(presenter.player(for: page) != nil, "no player for \(page.slot)")
            for other in WalkthroughPage.allCases where other != page {
                #expect(presenter.player(for: other) == nil)
            }
        }
        presenter.tearDown()
        #expect(presenter.activeClip == nil)
    }

    /// The camera edit already frames each action. Small phones and larger copy must fit
    /// the whole frame rather than cropping away the header or bottom-bar taps again.
    @Test
    func editedCameraFrameAlwaysFitsTheWindow() {
        for window in [CGSize(width: 350, height: 430), CGSize(width: 290, height: 280),
                       CGSize(width: 350, height: 900)] {
            for page in WalkthroughPage.allCases {
                let placement = page.clipPlacement(in: window)
                #expect(placement.size.width <= window.width + 0.001)
                #expect(placement.size.height <= window.height + 0.001)
                #expect(abs(placement.size.width / placement.size.height - 0.72) < 0.001)
                #expect(placement.offsetY == 0)
            }
        }
    }

    @MainActor
    @Test
    func walkthroughDismissalMarksCompletionAndDefersBiometricsBehindTheCTA() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let now = Date()
        let user = RLUserDTO(
            id: UUID(),
            email: "walkthrough@example.com",
            username: "walkthrough_user",
            displayName: "Walkthrough User",
            avatarUrl: nil,
            globalReputation: 0,
            isOnline: true,
            isVerified: true,
            isSuperuser: false,
            lastSeenAt: nil,
            createdAt: now,
            updatedAt: now,
            dateOfBirth: nil,
            status: "active",
            authProvider: "email"
        )
        appState.currentUser = user
        defer { appState.resetTutorial(for: user.id) }

        appState.walkthroughWillPresent()
        #expect(appState.isWalkthroughPresented)

        // An offer made while the walkthrough is up never presents.
        #expect(appState.offerBiometricEnrollmentIfNeeded() == false)
        #expect(appState.showBiometricEnrollment == false)

        // "Place your first marker" leaves the offer for the next session so a
        // second sheet cannot interrupt the placement it just set up.
        #expect(appState.walkthroughDidDismiss(outcome: .placeFirstMarker) == false)
        #expect(appState.isWalkthroughPresented == false)
        #expect(appState.showBiometricEnrollment == false)

        appState.markTutorialCompleted(for: user.id)
        #expect(appState.hasTutorialCompleted(for: user.id))
        #expect(appState.shouldAutoStartInitialTutorial(for: user.id) == false)
    }
}
