import Foundation

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
