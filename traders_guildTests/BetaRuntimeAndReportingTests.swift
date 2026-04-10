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
}
