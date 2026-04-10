import Foundation

enum ReportedContentNamespace: String {
    case marker = "marker"
    case chatroomMessage = "chatroom_message"
    case dmMessage = "dm_message"
    case chartChatMessage = "chart_chat_message"
}

enum ReportSubmissionOutcome: Equatable {
    case submitted
    case alreadyReported
}

enum ReportReactionSemantic {
    static let storedEmoji = "🚩"
    static let iconName = "exclamationmark.triangle.fill"
}

struct ReportedUserStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isReported(
        reporterUserId: UUID,
        guildId: UUID,
        reportedUserId: UUID,
        namespace: String
    ) -> Bool {
        defaults.bool(forKey: reportedUserKey(
            reporterUserId: reporterUserId,
            guildId: guildId,
            reportedUserId: reportedUserId,
            namespace: namespace
        ))
    }

    func markReported(
        reporterUserId: UUID,
        guildId: UUID,
        reportedUserId: UUID,
        namespace: String
    ) {
        defaults.set(
            true,
            forKey: reportedUserKey(
                reporterUserId: reporterUserId,
                guildId: guildId,
                reportedUserId: reportedUserId,
                namespace: namespace
            )
        )
    }

    func reportedUserKey(
        reporterUserId: UUID,
        guildId: UUID,
        reportedUserId: UUID,
        namespace: String
    ) -> String {
        "traders_guild_\(namespace)_reported_user_\(reporterUserId.uuidString)_\(guildId.uuidString)_\(reportedUserId.uuidString)"
    }
}

struct ReportedContentStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isReported(
        reporterUserId: UUID,
        guildId: UUID,
        contentId: UUID,
        namespace: String,
        contentNamespace: ReportedContentNamespace
    ) -> Bool {
        defaults.bool(
            forKey: reportedContentKey(
                reporterUserId: reporterUserId,
                guildId: guildId,
                contentId: contentId,
                namespace: namespace,
                contentNamespace: contentNamespace
            )
        )
    }

    func markReported(
        reporterUserId: UUID,
        guildId: UUID,
        contentId: UUID,
        namespace: String,
        contentNamespace: ReportedContentNamespace
    ) {
        defaults.set(
            true,
            forKey: reportedContentKey(
                reporterUserId: reporterUserId,
                guildId: guildId,
                contentId: contentId,
                namespace: namespace,
                contentNamespace: contentNamespace
            )
        )
    }

    func reportedContentKey(
        reporterUserId: UUID,
        guildId: UUID,
        contentId: UUID,
        namespace: String,
        contentNamespace: ReportedContentNamespace
    ) -> String {
        "traders_guild_\(namespace)_reported_content_\(contentNamespace.rawValue)_\(reporterUserId.uuidString)_\(guildId.uuidString)_\(contentId.uuidString)"
    }
}

extension RLMessageReactionDTO {
    var isReportReaction: Bool {
        emoji == ReportReactionSemantic.storedEmoji
    }
}

extension Array where Element == RLMessageReactionDTO {
    func applyingReportReaction(outcome: ReportSubmissionOutcome) -> [RLMessageReactionDTO] {
        var updated = self
        if let index = updated.firstIndex(where: \.isReportReaction) {
            let current = updated[index]
            let nextCount: Int
            switch outcome {
            case .submitted where !current.reactedByCurrentUser:
                nextCount = Swift.max(1, current.count + 1)
            case .submitted, .alreadyReported:
                nextCount = Swift.max(1, current.count)
            }
            updated[index] = RLMessageReactionDTO(
                emoji: current.emoji,
                count: nextCount,
                reactedByCurrentUser: true
            )
            return updated
        }

        updated.append(
            RLMessageReactionDTO(
                emoji: ReportReactionSemantic.storedEmoji,
                count: 1,
                reactedByCurrentUser: true
            )
        )
        return updated
    }
}
