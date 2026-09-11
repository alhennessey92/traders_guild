import Foundation
import Testing
@testable import traders_guild

struct GuildTransitionContextTests {

    @Test func launchIsTheBrandNotAWelcomeLine() {
        let request = GuildTransitionRequest.launch()
        #expect(request.action == .launch)
        #expect(request.guild == nil)
        #expect(request.headline == "Traders Guild")
        #expect(request.subject == "Traders Guild")
        #expect(!request.headline.contains("Welcome"))
    }

    // MARK: - What the overlay draws

    /// Launch, session restore, and the end of signup or onboarding all use
    /// the launch request, so this is every place the old pulsing text lived.
    @Test func launchShowsTheIconAloneWithTheWordmarkAtTheBottom() {
        let presentation = GuildTransitionPresentation(
            request: .launch(), reduceMotion: false
        )
        #expect(presentation.badge == .appLogo)
        #expect(presentation.layout == .standaloneMark, "icon alone, name at the bottom")
        #expect(presentation.title == "Traders Guild")
        #expect(presentation.subtitle == nil, "the title already is the name")
        #expect(!presentation.showsRing, "nothing competes with the mark")
        #expect(!presentation.animatesRing)
        #expect(presentation.accessibilityLabel == "Traders Guild, loading")
    }

    /// The guild operations are the treatment the user liked; they keep the
    /// crest, the verb and the guild's name exactly.
    @Test func guildOperationsKeepTheCrestVerbAndName() {
        let entry = makeGuildEntry(name: "Night Owls")
        for action in [GuildTransitionAction.creating, .joining, .deleting, .switching] {
            let presentation = GuildTransitionPresentation(
                request: .guild(action, guild: entry.guild), reduceMotion: false
            )
            #expect(presentation.badge == .guildCrest)
            #expect(presentation.layout == .badgeWithCaption)
            #expect(presentation.showsRing)
            #expect(presentation.animatesRing)
            #expect(presentation.title == action.headline)
            #expect(presentation.subtitle == "Night Owls")
            #expect(presentation.accessibilityLabel == "\(action.headline) Night Owls")
        }
    }

    /// Reduce Motion stops a guild operation's ring turning and nothing else:
    /// the badge, the words and the spoken label are identical, so the state
    /// is still communicated. Launch has no ring, so it has nothing to hold.
    @Test func reduceMotionHoldsTheRingAndChangesNothingElse() {
        let entry = makeGuildEntry(name: "Night Owls")
        let request = GuildTransitionRequest.guild(.switching, guild: entry.guild)
        let moving = GuildTransitionPresentation(request: request, reduceMotion: false)
        let still = GuildTransitionPresentation(request: request, reduceMotion: true)
        #expect(moving.animatesRing)
        #expect(!still.animatesRing)
        #expect(still.showsRing == moving.showsRing)
        #expect(still.badge == moving.badge)
        #expect(still.layout == moving.layout)
        #expect(still.title == moving.title)
        #expect(still.subtitle == moving.subtitle)
        #expect(still.accessibilityLabel == moving.accessibilityLabel)

        let launch = GuildTransitionPresentation(request: .launch(), reduceMotion: true)
        #expect(launch == GuildTransitionPresentation(request: .launch(), reduceMotion: false))
    }

    /// The overlay's copy must never say "Welcome to" again, on any action.
    @Test func noTransitionSaysWelcomeTo() {
        let entry = makeGuildEntry(name: "Any")
        var requests = [GuildTransitionRequest.launch()]
        for action in [GuildTransitionAction.creating, .joining, .deleting, .switching] {
            requests.append(.guild(action, guild: entry.guild))
        }
        for request in requests {
            let presentation = GuildTransitionPresentation(request: request, reduceMotion: false)
            #expect(!presentation.title.contains("Welcome to"))
            #expect(!(presentation.subtitle ?? "").contains("Welcome to"))
            #expect(!presentation.accessibilityLabel.contains("Welcome to"))
        }
    }

    @Test func eachActNamesItselfAndKeepsTheCapturedIdentity() {
        let entry = makeGuildEntry(name: "New Test")
        let cases: [(GuildTransitionAction, String)] = [
            (.creating, "Creating"),
            (.joining, "Joining"),
            (.deleting, "Deleting"),
            (.switching, "Switching"),
        ]
        for (action, headline) in cases {
            let request = GuildTransitionRequest.guild(action, guild: entry.guild)
            #expect(request.headline == headline)
            #expect(request.subject == "New Test")
            #expect(request.guild?.id == entry.guild.id)
            #expect(request.guild?.name == "New Test")
            #expect(request.guild?.imageURL == entry.guild.imageUrl)
            #expect(request.guild?.crestSymbol == "bolt")
            #expect(request.guild?.crestColor == "blue")
        }
    }

    @Test func aBlankGuildNameFallsBackRatherThanShowingNothing() {
        let identity = GuildTransitionIdentity(
            id: UUID(),
            name: "   ",
            imageURL: nil,
            crestSymbol: nil,
            crestColor: nil
        )
        let request = GuildTransitionRequest(action: .joining, guild: identity)
        #expect(request.subject == "your guild")
        #expect(identity.fallbackInitial == "Y")
        #expect(identity.usesInitialFallback)
    }

    @Test func unicodeCaseExpansionCannotCrashTheFallbackCrest() {
        let identity = GuildTransitionIdentity(
            id: UUID(),
            name: "ßeta",
            imageURL: nil,
            crestSymbol: nil,
            crestColor: nil
        )
        #expect(identity.fallbackInitial == "S")
    }

    @Test func symbolOrImageSuppressesTheInitialFallback() {
        let imageIdentity = GuildTransitionIdentity(
            id: UUID(),
            name: "Image",
            imageURL: "https://cdn.example/crest.png",
            crestSymbol: nil,
            crestColor: nil
        )
        let symbolIdentity = GuildTransitionIdentity(
            id: UUID(),
            name: "Symbol",
            imageURL: nil,
            crestSymbol: "bolt",
            crestColor: "gold"
        )

        #expect(!imageIdentity.usesInitialFallback)
        #expect(!symbolIdentity.usesInitialFallback)
    }

    @Test func everyAppearanceGetsAUniqueRequestToken() {
        #expect(GuildTransitionRequest.launch().id != GuildTransitionRequest.launch().id)
    }

    @MainActor
    @Test func staleCompletionCannotFinishANewerTransition() {
        let state = RLAppState(restoreSessionOnInit: false)
        let first = GuildTransitionRequest(id: UUID(), action: .switching)
        let second = GuildTransitionRequest(id: UUID(), action: .joining)

        state.showTransitionForChartLoad(
            minimumDuration: RLAppState.guildTransitionMinimum,
            request: first
        )
        state.showTransitionForChartLoad(
            minimumDuration: RLAppState.guildTransitionMinimum,
            request: second
        )

        #expect(!state.finishTransition(requestID: first.id))
        #expect(state.showingTransition)
        #expect(state.transitionRequest == second)
        #expect(state.finishTransition(requestID: second.id))
        #expect(!state.showingTransition)
        // The finished request is retained through the view's fade-out.
        #expect(state.transitionRequest == second)
    }

    @MainActor
    @Test func staleChartReadinessCannotReleaseANewerGuildTransition() {
        let state = RLAppState(restoreSessionOnInit: false)
        let firstGuild = makeGuildEntry(name: "First")
        let secondGuild = makeGuildEntry(name: "Second")
        let firstRequest = GuildTransitionRequest.guild(
            .switching,
            guild: firstGuild.guild
        )
        let secondRequest = GuildTransitionRequest.guild(
            .switching,
            guild: secondGuild.guild
        )

        state.currentGuild = firstGuild.guild
        state.showTransitionForChartLoad(request: firstRequest)
        state.currentGuild = secondGuild.guild
        state.showTransitionForChartLoad(request: secondRequest)

        #expect(!state.chartDidBecomeReady(
            requestID: firstRequest.id,
            guildID: firstGuild.guild.id
        ))
        #expect(!state.isChartReady)
        #expect(state.chartDidBecomeReady(
            requestID: secondRequest.id,
            guildID: secondGuild.guild.id
        ))
        #expect(state.isChartReady)
    }

    @MainActor
    @Test func failsafeReleasesAnEligibleTransitionWithoutChartReadiness() {
        let state = RLAppState(restoreSessionOnInit: false)
        let entry = makeGuildEntry(name: "Failsafe Landing")
        let request = GuildTransitionRequest.guild(.deleting, guild: entry.guild)

        state.isSessionRestored = true
        state.isAuthenticated = true
        state.currentGuild = entry.guild
        state.showTransitionForChartLoad(
            minimumDuration: .leastNonzeroMagnitude,
            request: request
        )

        #expect(!state.isChartReady)
        #expect(state.canFinishTransitionAfterFailsafe(requestID: request.id))
        #expect(state.showingTransition)
    }

    @MainActor
    @Test func failsafeCannotReleaseAStaleOrIneligibleTransition() {
        let state = RLAppState(restoreSessionOnInit: false)
        let entry = makeGuildEntry(name: "Guarded Landing")
        let request = GuildTransitionRequest.guild(.deleting, guild: entry.guild)

        state.showTransitionForChartLoad(
            minimumDuration: .leastNonzeroMagnitude,
            request: request
        )
        #expect(!state.canFinishTransitionAfterFailsafe(requestID: request.id))

        state.isSessionRestored = true
        state.isAuthenticated = true
        state.currentGuild = entry.guild
        #expect(!state.canFinishTransitionAfterFailsafe(requestID: UUID()))
        #expect(state.showingTransition)
    }

    @MainActor
    @Test func everyGuildOperationDefaultsToTheReleaseMinimum() {
        #expect(RLAppState.guildTransitionMinimum == 2.2)

        for action in [
            GuildTransitionAction.creating,
            .joining,
            .deleting,
            .switching,
        ] {
            let state = RLAppState(restoreSessionOnInit: false)
            state.showTransitionForChartLoad(
                request: GuildTransitionRequest(action: action)
            )
            #expect(state.transitionMinimumRemaining() > 2.0)
            #expect(state.transitionMinimumRemaining() <= 2.2)
        }
    }

    @MainActor
    @Test func duplicateDeletionRelocationKeepsTheFirstTransitionRequest() async {
        let state = RLAppState(restoreSessionOnInit: false)
        let deleted = makeGuildEntry(name: "Deleted")
        let landing = makeGuildEntry(name: "Landing")
        state.currentGuild = deleted.guild
        state.currentMembership = deleted.membership
        state.userGuilds = [landing]

        await state.moveOffDeletedGuild(deletedGuild: deleted.guild)
        let firstRequest = state.transitionRequest

        await state.moveOffDeletedGuild(deletedGuild: deleted.guild)

        #expect(state.currentGuild?.id == landing.guild.id)
        #expect(state.transitionRequest == firstRequest)
        #expect(state.transitionRequest.action == .deleting)
        #expect(state.transitionRequest.guild?.id == deleted.guild.id)
    }

    @MainActor
    @Test func launchTimingRemainsUnchanged() {
        let state = RLAppState(restoreSessionOnInit: false)
        state.showTransitionForChartLoad(request: .launch())
        #expect(state.transitionMinimumRemaining() == 0)

        state.showTransitionForChartLoad(minimumDuration: 0.6, request: .launch())
        #expect(state.transitionMinimumRemaining() > 0.4)
        #expect(state.transitionMinimumRemaining() <= 0.6)
    }

    @MainActor
    @Test func manualSwitchEntryPointAlwaysStartsAnIdentifiedTransition() {
        let state = RLAppState(restoreSessionOnInit: false)
        let entry = makeGuildEntry(name: "Manual Target")

        state.selectGuildManually(entry)

        #expect(state.currentGuild?.id == entry.guild.id)
        #expect(state.showingTransition)
        #expect(state.transitionRequest.action == .switching)
        #expect(state.transitionRequest.guild == GuildTransitionIdentity(guild: entry.guild))
        #expect(state.transitionMinimumRemaining() > 2.0)
    }

    @MainActor
    @Test func bothVisibleManualSwitchRoutesStartTheReleaseTransition() {
        for route in ManualGuildSwitchRoute.allCases {
            let state = RLAppState(restoreSessionOnInit: false)
            let entry = makeGuildEntry(name: "\(route)")

            route.select(entry, in: state)

            #expect(state.currentGuild?.id == entry.guild.id)
            #expect(state.transitionRequest.action == .switching)
            #expect(state.transitionRequest.guild?.id == entry.guild.id)
            #expect(state.transitionMinimumRemaining() > 2.0)
        }
    }

    @MainActor
    @Test func aNewTransitionDiscardsArrivalAndProfileWorkFromTheOldGuild() {
        let state = RLAppState(restoreSessionOnInit: false)
        let oldEntry = makeGuildEntry(name: "Old")
        let nextEntry = makeGuildEntry(name: "Next")
        let oldRequest = GuildTransitionRequest.guild(.joining, guild: oldEntry.guild)

        state.currentGuild = oldEntry.guild
        state.showTransitionForChartLoad(request: oldRequest)
        state.pendingGuildWelcome = GuildArrivalRequest(
            transitionRequestID: oldRequest.id,
            guild: oldEntry.guild
        )
        state.requestGuildProfileAfterWelcome(guildID: oldEntry.guild.id)

        let nextRequest = GuildTransitionRequest.guild(.switching, guild: nextEntry.guild)
        state.showTransitionForChartLoad(request: nextRequest)

        #expect(state.pendingGuildWelcome == nil)
        #expect(state.pendingGuildCelebration == nil)
        #expect(state.openCurrentUserProfileRequest == nil)
    }

    @Test func everyPendingAndPresentedArrivalStateReservesTheChartSheetSlot() {
        let occupiedStates = [
            (true, false, false, false, false),
            (false, true, false, false, false),
            (false, false, true, false, false),
            (false, false, false, true, false),
            (false, false, false, false, true),
        ]

        for state in occupiedStates {
            #expect(GuildArrivalPresentationPolicy.reservesSheetSlot(
                hasPendingCelebration: state.0,
                hasPresentedCelebration: state.1,
                hasPendingWelcome: state.2,
                hasPresentedWelcome: state.3,
                hasPendingProfile: state.4
            ))
        }

        #expect(!GuildArrivalPresentationPolicy.reservesSheetSlot(
            hasPendingCelebration: false,
            hasPresentedCelebration: false,
            hasPendingWelcome: false,
            hasPresentedWelcome: false,
            hasPendingProfile: false
        ))
    }

    @Test func profileWaitsUntilTheWelcomeHasFullyDismissed() {
        #expect(!GuildArrivalPresentationPolicy.canPresentProfile(
            hasPendingProfile: true,
            hasPendingWelcome: true,
            hasPresentedWelcome: true,
            hasPendingCelebration: false,
            hasPresentedCelebration: false
        ))
        #expect(GuildArrivalPresentationPolicy.canPresentProfile(
            hasPendingProfile: true,
            hasPendingWelcome: false,
            hasPresentedWelcome: false,
            hasPendingCelebration: false,
            hasPresentedCelebration: false
        ))
    }

    @MainActor
    @Test func viewGuildProfileRequestIsOneShotAndRequestScoped() {
        let state = RLAppState(restoreSessionOnInit: false)
        let guildID = UUID()
        state.requestGuildProfileAfterWelcome(guildID: guildID)
        let request = state.openCurrentUserProfileRequest!

        #expect(request.guildID == guildID)
        #expect(!state.consumeGuildProfileAfterWelcomeRequest(UUID()))
        #expect(state.openCurrentUserProfileRequest == request)
        #expect(state.consumeGuildProfileAfterWelcomeRequest(request.id))
        #expect(state.openCurrentUserProfileRequest == nil)
        #expect(!state.consumeGuildProfileAfterWelcomeRequest(request.id))
    }

    private func makeGuildEntry(name: String) -> RLGuildWithMembership {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let guildID = UUID()
        let userID = UUID()
        let guild = RLGuildDTO(
            id: guildID,
            name: name,
            slug: "manual-target",
            description: nil,
            imageUrl: "https://cdn.example/manual.png",
            ownerId: userID,
            isOpen: true,
            isOnboardingSystemGuild: false,
            reputation: 0,
            memberCount: 1,
            membersOnline: 1,
            ownerDisplayName: nil,
            ownerUsername: nil,
            ownerAvatarUrl: nil,
            language: nil,
            location: nil,
            status: "active",
            dateCreated: now,
            updatedAt: now,
            crestSymbol: "bolt",
            crestColor: "blue",
            bannerUrl: nil,
            publicLeaderboard: nil
        )
        let membership = RLGuildMembershipDTO(
            id: UUID(),
            userId: userID,
            guildId: guildID,
            role: "owner",
            reputation: 0,
            contributionScore: 0,
            status: "active",
            dateJoined: now,
            accuracyRate: nil
        )
        return RLGuildWithMembership(guild: guild, membership: membership)
    }
}
