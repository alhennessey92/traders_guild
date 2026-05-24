import Foundation
import Testing
@testable import traders_guild

struct BetaRuntimeAndReportingTests {
    @Test
    func reportedUserStorePersistsPerReporterGuildAndTarget() throws {
        let suiteName = "ReportedUserStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ReportedUserStore(defaults: defaults)
        let reporterId = UUID()
        let guildId = UUID()
        let targetId = UUID()
        let otherTargetId = UUID()

        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                reportedUserId: targetId,
                namespace: "tests"
            ) == false
        )

        store.markReported(
            reporterUserId: reporterId,
            guildId: guildId,
            reportedUserId: targetId,
            namespace: "tests"
        )

        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                reportedUserId: targetId,
                namespace: "tests"
            )
        )
        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                reportedUserId: otherTargetId,
                namespace: "tests"
            ) == false
        )
    }

    @Test
    func reportedContentStorePersistsPerReporterGuildTypeAndTarget() throws {
        let suiteName = "ReportedContentStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ReportedContentStore(defaults: defaults)
        let reporterId = UUID()
        let guildId = UUID()
        let markerId = UUID()
        let messageId = UUID()

        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                contentId: markerId,
                namespace: "tests",
                contentNamespace: .marker
            ) == false
        )

        store.markReported(
            reporterUserId: reporterId,
            guildId: guildId,
            contentId: markerId,
            namespace: "tests",
            contentNamespace: .marker
        )

        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                contentId: markerId,
                namespace: "tests",
                contentNamespace: .marker
            )
        )
        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                contentId: markerId,
                namespace: "tests",
                contentNamespace: .chatroomMessage
            ) == false
        )
        #expect(
            store.isReported(
                reporterUserId: reporterId,
                guildId: guildId,
                contentId: messageId,
                namespace: "tests",
                contentNamespace: .marker
            ) == false
        )
    }

    @Test
    func applyingReportReactionPatchesCurrentUserStateWithoutDuplicateBubbles() {
        let newlyReported = [RLMessageReactionDTO(emoji: "🔥", count: 2, reactedByCurrentUser: false)]
            .applyingReportReaction(outcome: .submitted)
        #expect(newlyReported.contains(where: { $0.isReportReaction && $0.count == 1 && $0.reactedByCurrentUser }))

        let duplicateReport = [RLMessageReactionDTO(emoji: ReportReactionSemantic.storedEmoji, count: 3, reactedByCurrentUser: false)]
            .applyingReportReaction(outcome: .alreadyReported)
        #expect(duplicateReport == [RLMessageReactionDTO(emoji: ReportReactionSemantic.storedEmoji, count: 3, reactedByCurrentUser: true)])

        let submittedExisting = [RLMessageReactionDTO(emoji: ReportReactionSemantic.storedEmoji, count: 3, reactedByCurrentUser: false)]
            .applyingReportReaction(outcome: .submitted)
        #expect(submittedExisting == [RLMessageReactionDTO(emoji: ReportReactionSemantic.storedEmoji, count: 4, reactedByCurrentUser: true)])
    }

    @Test
    func runtimeFlagsDecodeBetaSettings() throws {
        let json = """
        {
          "beta_welcome_enabled": true,
          "beta_feedback_enabled": false
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let flags = try decoder.decode(RLRuntimeFlagsDTO.self, from: Data(json.utf8))

        #expect(flags == RLRuntimeFlagsDTO(betaWelcomeEnabled: true, betaFeedbackEnabled: false))
    }

    @MainActor
    @Test
    func finishTransitionPresentsQueuedBetaWelcomeSheet() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let now = Date()
        let user = RLUserDTO(
            id: UUID(),
            email: "beta@example.com",
            username: "beta_user",
            displayName: "Beta User",
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
        appState.currentGuild = makeGuild(ownerId: user.id, now: now)
        appState.showingTransition = true

        appState.queueBetaWelcomeIfNeeded()
        appState.finishTransition()

        #expect(appState.showBetaWelcomeSheet)
    }

    @MainActor
    @Test
    func queuedBetaWelcomeWaitsForGuildSelectorToDismiss() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let now = Date()
        let user = RLUserDTO(
            id: UUID(),
            email: "selector-beta@example.com",
            username: "selector_beta_user",
            displayName: "Selector Beta User",
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
        appState.currentGuild = makeGuild(ownerId: user.id, now: now)
        appState.showingTransition = false
        appState.showGuildSelectionSheet = true

        appState.queueBetaWelcomeIfNeeded()
        appState.presentPendingBetaWelcomeIfNeeded()

        #expect(appState.showBetaWelcomeSheet == false)

        appState.showGuildSelectionSheet = false
        appState.presentPendingBetaWelcomeIfNeeded()

        #expect(appState.showBetaWelcomeSheet)
    }

    @MainActor
    @Test
    func betaWelcomeDoesNotQueueAgainAfterBeingShown() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let now = Date()
        let user = RLUserDTO(
            id: UUID(),
            email: "once-beta@example.com",
            username: "once_beta_user",
            displayName: "Once Beta User",
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
        appState.currentGuild = makeGuild(ownerId: user.id, now: now)
        appState.showingTransition = false

        appState.queueBetaWelcomeIfNeeded()
        appState.presentPendingBetaWelcomeIfNeeded()
        #expect(appState.showBetaWelcomeSheet)

        appState.showBetaWelcomeSheet = false
        appState.queueBetaWelcomeIfNeeded()
        appState.presentPendingBetaWelcomeIfNeeded()

        #expect(appState.showBetaWelcomeSheet == false)
    }

    @MainActor
    @Test
    func initialTutorialAutoStartIsOneShot() {
        let appState = RLAppState(restoreSessionOnInit: false)
        let now = Date()
        let user = RLUserDTO(
            id: UUID(),
            email: "tutorial-once@example.com",
            username: "tutorial_once_user",
            displayName: "Tutorial Once User",
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

        #expect(appState.shouldAutoStartInitialTutorial(for: user.id) == false)

        appState.queueInitialTutorialAutoStartIfNeeded()
        #expect(appState.shouldAutoStartInitialTutorial(for: user.id))

        appState.markInitialTutorialAutoStartShown(for: user.id)
        #expect(appState.shouldAutoStartInitialTutorial(for: user.id) == false)
    }

    private func makeGuild(ownerId: UUID, now: Date) -> RLGuildDTO {
        RLGuildDTO(
            id: UUID(),
            name: "Beta",
            description: nil,
            imageUrl: nil,
            ownerId: ownerId,
            isOpen: true,
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
            crestSymbol: nil,
            crestColor: nil
        )
    }
}
