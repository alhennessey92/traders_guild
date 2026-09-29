import Combine
import Foundation
import Testing
@testable import traders_guild

/// Which face an author's markers wear, and when the canvas symbols are
/// worked out.
///
/// A marker carries its author as a snapshot from when it was fetched. The
/// avatar directory knows better; the snapshot is only a fallback, and must
/// never be written back over what the directory knows.
@MainActor
struct MarkerAvatarIdentityTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func author(_ n: Int, username: String = "trader", avatarUrl: String?) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0), accuracyRate: nil, mutedUntil: nil,
            suspendedUntil: nil, userId: id(n), username: username, displayName: username,
            avatarUrl: avatarUrl, isOnline: false, globalReputation: 0, isFriend: false,
            friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
    }

    private func marker(
        _ n: Int,
        by author: RLGuildMemberDTO,
        intent: RLMarkerIntent = .analysis,
        createdAt: TimeInterval = 0
    ) -> ChartMarkerUI {
        let base = MarkerLinkFixtures.marker(
            n, author: author.username, intent: intent,
            candle: MarkerLinkFixtures.baseCandle, price: 64_000, title: nil
        )
        let dto = RLChartMarkerDTO(
            id: base.id, symbolId: base.symbolId, guildId: base.guildId, author: author,
            candleTimestamp: base.candleTimestamp, timeframe: base.timeframe, price: base.price,
            intent: base.intent, title: nil, note: nil, visibility: "guild", confidence: nil,
            trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: Date(timeIntervalSince1970: createdAt), createdAtFormatted: "",
            isVisible: true, likeCount: 0, isLikedByCurrentUser: false, commentCount: 0,
            comments: [], isCurrentUserMarker: false, canEdit: false, canDelete: false,
            components: [], primaryComponentId: nil, pollQuestion: nil, pollOptions: nil,
            userPollVote: nil, predictionResult: nil
        )
        return ChartMarkerUI(marker: dto, candleIndex: 0)
    }

    private final class Recorder {
        var prefetched: [[String]] = []
    }

    private func store(
        intents: Set<RLMarkerIntent> = MarkerAvatarPresentation.avatarIntents(experimentEnabled: true),
        directory: CurrentValueSubject<[UUID: String], Never>,
        recorder: Recorder = Recorder()
    ) -> MarkerAvatarSymbolStore {
        MarkerAvatarSymbolStore(
            avatarIntents: intents,
            directory: directory.eraseToAnyPublisher(),
            prefetch: { recorder.prefetched.append($0) }
        )
    }

    // MARK: Identity

    @Test
    func theSnapshotIsUsedForAnAuthorTheDirectoryHasNotSeen() {
        let identity = MarkerAvatarIdentity.forAuthor(author(1, username: "alex", avatarUrl: "https://x/old.png"), directory: [:])
        #expect(identity == MarkerAvatarIdentity(url: "https://x/old.png", initials: "AL"))
    }

    @Test
    func aNewerDirectoryPictureBeatsTheSnapshot() {
        let identity = MarkerAvatarIdentity.forAuthor(
            author(1, username: "alex", avatarUrl: "https://x/old.png"),
            directory: [id(1): "https://x/new.png"]
        )
        #expect(identity.url == "https://x/new.png")
    }

    /// Removing an avatar must stick: the snapshot's old picture is not a
    /// fallback for an explicit "no picture".
    @Test
    func anExplicitRemovalBeatsTheSnapshot() {
        let identity = MarkerAvatarIdentity.forAuthor(
            author(1, username: "alex", avatarUrl: "https://x/old.png"),
            directory: [id(1): ""]
        )
        #expect(identity == MarkerAvatarIdentity(url: nil, initials: "AL"))
    }

    @Test
    func nothingToDrawIsNone() {
        #expect(MarkerAvatarIdentity.forAuthor(author(1, username: "  ", avatarUrl: ""), directory: [:]) == .none)
    }

    // MARK: Store

    @Test
    func oneSymbolPerAuthorWhateverTheirMarkerCount() {
        let alex = author(1, username: "alex", avatarUrl: "https://x/alex.png")
        let sam = author(2, username: "sam", avatarUrl: nil)
        let store = store(directory: CurrentValueSubject([:]))
        store.update(markers: [marker(1, by: alex), marker(2, by: alex, intent: .setup), marker(3, by: sam, intent: .question)])
        #expect(store.entries.map(\.authorId) == [id(1), id(2)].sorted { $0.uuidString < $1.uuidString })
        #expect(Set(store.entries.map(\.tag)).count == 2)
    }

    @Test
    func onlyAuthorsOfAvatarIntentsAreRegistered() {
        let alex = author(1, username: "alex", avatarUrl: "https://x/alex.png")
        let store = store(
            intents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: false),
            directory: CurrentValueSubject([:])
        )
        store.update(markers: [marker(1, by: alex, intent: .analysis)])
        #expect(store.entries.isEmpty)

        store.avatarIntents = MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
        #expect(store.entries.map(\.authorId) == [id(1)])
    }

    @Test
    func theNewestMarkersSnapshotIsTheFallback() {
        let older = author(1, username: "alex", avatarUrl: "https://x/older.png")
        let newer = author(1, username: "alex", avatarUrl: "https://x/newer.png")
        let store = store(directory: CurrentValueSubject([:]))
        store.update(markers: [marker(2, by: newer, createdAt: 200), marker(1, by: older, createdAt: 100)])
        #expect(store.entries.first?.identity.url == "https://x/newer.png")
    }

    @Test
    func aDirectoryChangeRefreshesTheSymbol() {
        let directory = CurrentValueSubject<[UUID: String], Never>([:])
        let alex = author(1, username: "alex", avatarUrl: "https://x/old.png")
        let store = store(directory: directory)
        store.update(markers: [marker(1, by: alex)])
        #expect(store.entries.first?.identity.url == "https://x/old.png")

        directory.send([id(1): "https://x/new.png"])
        #expect(store.entries.first?.identity.url == "https://x/new.png")

        directory.send([id(1): ""])
        #expect(store.entries.first?.identity == MarkerAvatarIdentity(url: nil, initials: "AL"))
    }

    /// The chart reads the store on every frame; an unchanged marker set must
    /// not republish, re-register symbols or prefetch again.
    @Test
    func unchangedInputsPublishAndPrefetchNothing() {
        let alex = author(1, username: "alex", avatarUrl: "https://x/alex.png")
        let recorder = Recorder()
        let store = store(directory: CurrentValueSubject([:]), recorder: recorder)
        store.update(markers: [marker(1, by: alex)])
        #expect(recorder.prefetched == [["https://x/alex.png"]])

        var publishes = 0
        let cancellable = store.objectWillChange.sink { publishes += 1 }
        store.update(markers: [marker(1, by: alex), marker(2, by: alex)])
        store.update(markers: [marker(1, by: alex)])
        cancellable.cancel()
        #expect(publishes == 0)
        #expect(recorder.prefetched.count == 1)
    }

    /// Reading marker snapshots must never feed the directory: an old picture
    /// would overwrite a newer one, or undo a removal.
    @Test
    func historicalSnapshotsAreNeverWrittenToTheDirectory() {
        let directory = MemberAvatarDirectory.shared
        directory.clear()
        directory.note(userId: id(2), avatarURL: nil)
        let store = MarkerAvatarSymbolStore(
            avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: true),
            prefetch: { _ in }
        )
        store.update(markers: [
            marker(1, by: author(1, username: "alex", avatarUrl: "https://x/stale.png")),
            marker(2, by: author(2, username: "ivy", avatarUrl: "https://x/deleted.png")),
        ])
        #expect(directory.avatarByUserId == [id(2): ""])
        #expect(store.entries.first { $0.authorId == id(2) }?.identity.url == nil)
        directory.clear()
    }
}
