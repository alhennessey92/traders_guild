import Foundation
import Testing
@testable import traders_guild

/// The delete seam, and the structural flag that keeps a thesis reachable after
/// one.
///
/// Both halves came out of the two-member acceptance round. Deleting the only
/// response to a root left that root with an active count of zero and no thesis
/// affordance at all, while a grandchild still hung off the tombstone — the
/// branch survived and could only be reached from underneath. And the delete
/// itself was a debug-grade path: optimistic, `Void`-returning, and silent on
/// failure, which is not something a member should be able to reach.
@MainActor
struct MarkerDeleteLifecycleTests {

    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func member(_ n: Int) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0), accuracyRate: nil, mutedUntil: nil,
            suspendedUntil: nil, userId: id(n), username: "user\(n)", displayName: "User \(n)",
            avatarUrl: nil, isOnline: false, globalReputation: 0, isFriend: false,
            friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
    }

    private func dto(
        _ n: Int,
        author: Int,
        canDelete: Bool,
        parent: Int? = nil,
        relationship: String? = nil,
        responses: Int? = nil,
        hasResponses: Bool? = nil
    ) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: id(n), symbolId: symbolId, guildId: guildId, author: member(author),
            candleTimestamp: Date(timeIntervalSince1970: 1_700_000_000), timeframe: "1h",
            price: 100, intent: "question", title: "Marker \(n)", note: nil,
            visibility: "guild", confidence: nil, trackingEnabled: false, trackingState: nil,
            alertSeverity: nil, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdAtFormatted: "just now", isVisible: true, likeCount: 0,
            isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: author == 1, canEdit: author == 1, canDelete: canDelete,
            components: [], primaryComponentId: nil, pollQuestion: nil, pollOptions: nil,
            userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent.map(id), linkRelationship: relationship,
            parentPreview: nil, directResponseCount: responses, responsesRevision: nil,
            hasResponses: hasResponses
        )
    }

    private func manager(with loaded: [RLChartMarkerDTO], api: DeleteFakeAPI) -> MarkerManager {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)
        manager.markers = loaded.map { ChartMarkerUI(marker: $0, candleIndex: 0) }
        return manager
    }

    // MARK: - A failed delete must not look like a successful one

    /// The behaviour that made the old path unfit for a user-facing control: it
    /// removed the marker and cleared the selection *before* asking, so a
    /// request that then failed left a marker that still exists looking gone.
    @Test
    func aFailedDeleteLeavesTheMarkerAndSaysSo() async {
        let api = DeleteFakeAPI()
        api.failure = URLError(.notConnectedToInternet)
        let manager = manager(with: [dto(1, author: 1, canDelete: true)], api: api)
        manager.selectedMarker = manager.markers.first

        let outcome = await manager.deleteMarker(id: id(1))

        #expect(outcome == .failed)
        #expect(manager.markers.contains { $0.id == self.id(1) }, "nothing may be removed")
        #expect(manager.selectedMarker?.id == id(1), "and the selection must survive")
    }

    /// A 404/409 — the parent was deleted under the composer — is the same
    /// contract: the caller is told, and nothing is removed on a guess.
    @Test
    func aServerRejectionIsAlsoAFailureNotASilentSuccess() async {
        let api = DeleteFakeAPI()
        api.failure = APIError.serverError(409, "conflict")
        let manager = manager(with: [dto(1, author: 1, canDelete: true)], api: api)

        #expect(await manager.deleteMarker(id: id(1)) == .failed)
        #expect(manager.markers.count == 1)
    }

    /// With no API configured the old path removed the marker and returned, so
    /// the marker looked deleted and never was.
    @Test
    func anUnconfiguredManagerRefusesRatherThanRemoving() async {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.markers = [ChartMarkerUI(marker: dto(1, author: 1, canDelete: true), candleIndex: 0)]

        #expect(await manager.deleteMarker(id: id(1)) == .failed)
        #expect(manager.markers.count == 1)
    }

    /// Permission is checked before the request, so no destructive call is made
    /// on a marker the server would refuse anyway.
    @Test
    func deletingWithoutPermissionNeverReachesTheServer() async {
        let api = DeleteFakeAPI()
        let manager = manager(with: [dto(1, author: 2, canDelete: false)], api: api)

        #expect(await manager.deleteMarker(id: id(1)) == .notPermitted)
        #expect(api.deleteCalls.isEmpty, "and it must not even ask")
        #expect(manager.markers.count == 1)
    }

    @Test
    func deletingSomethingNotOnTheChartReportsNotFound() async {
        let api = DeleteFakeAPI()
        let manager = manager(with: [], api: api)
        #expect(await manager.deleteMarker(id: id(1)) == .notFound)
    }

    // MARK: - The success path, and what it does to the parent

    /// A moderator deleting another member's marker: permitted by `canDelete`
    /// rather than by ownership, which is the gate the reachable action uses.
    @Test
    func aModeratorCanDeleteSomebodyElsesMarker() async {
        let api = DeleteFakeAPI()
        api.acknowledgement = RLMarkerDeleteResponseDTO(
            detail: "deleted", markerId: id(2), symbolId: symbolId,
            parentMarkerId: id(1), parentDirectResponseCount: 0,
            parentHasResponses: true
        )
        let manager = manager(
            with: [
                dto(1, author: 1, canDelete: true, responses: 1, hasResponses: true),
                dto(2, author: 2, canDelete: true, parent: 1, relationship: "supports")
            ],
            api: api
        )
        manager.selectedMarker = manager.markers.first { $0.id == id(2) }

        #expect(await manager.deleteMarker(id: id(2)) == .deleted)
        #expect(!manager.markers.contains { $0.id == self.id(2) })
        #expect(manager.selectedMarker == nil, "the deleted marker cannot stay selected")
    }

    /// The acceptance bug, at the seam: the parent's active count correctly
    /// falls to zero, and without the structural flag that also erased the only
    /// evidence that the thesis — and the grandchild under the tombstone — still
    /// exists.
    @Test
    func aSoftDeleteDropsTheCountButKeepsTheThesis() async {
        let api = DeleteFakeAPI()
        api.acknowledgement = RLMarkerDeleteResponseDTO(
            detail: "deleted", markerId: id(2), symbolId: symbolId,
            parentMarkerId: id(1),
            parentDirectResponseCount: 0,
            parentResponsesRevision: "2026-09-10T18:00:00.000004Z",
            parentHasResponses: true
        )
        let manager = manager(
            with: [
                dto(1, author: 1, canDelete: true, responses: 1, hasResponses: true),
                dto(2, author: 1, canDelete: true, parent: 1, relationship: "supports")
            ],
            api: api
        )

        #expect(await manager.deleteMarker(id: id(2)) == .deleted)

        let parent = try! #require(manager.markers.first { $0.id == self.id(1) })
        #expect(parent.responseCount == 0, "the active count is active-only, as specified")
        #expect(parent.hasAnyResponses, "but the tombstone keeps the thesis alive")
        #expect(parent.participatesInThesis, "so the disclosure stays on the root")
    }

    /// The other direction: a hard delete leaves no child row at all, and the
    /// flag has to be able to say so.
    @Test
    func aHardDeleteClearsTheStructuralFlagToo() async {
        let api = DeleteFakeAPI()
        api.acknowledgement = RLMarkerDeleteResponseDTO(
            detail: "deleted", markerId: id(2), symbolId: symbolId,
            parentMarkerId: id(1),
            parentDirectResponseCount: 0,
            parentResponsesRevision: "2026-09-10T18:00:01.000004Z",
            parentHasResponses: false
        )
        let manager = manager(
            with: [
                dto(1, author: 1, canDelete: true, responses: 1, hasResponses: true),
                dto(2, author: 1, canDelete: true, parent: 1, relationship: "supports")
            ],
            api: api
        )

        _ = await manager.deleteMarker(id: id(2))

        let parent = try! #require(manager.markers.first { $0.id == self.id(1) })
        #expect(!parent.hasAnyResponses)
        #expect(!parent.participatesInThesis)
    }

    /// An older server omits the flag entirely. That must leave whatever the
    /// client already knew alone rather than reading as "no thesis".
    @Test
    func anAcknowledgementWithoutTheFlagLeavesTheKnownValueAlone() async {
        let api = DeleteFakeAPI()
        api.acknowledgement = RLMarkerDeleteResponseDTO(
            detail: "deleted", markerId: id(2), symbolId: symbolId,
            parentMarkerId: id(1),
            parentDirectResponseCount: 0,
            parentResponsesRevision: "2026-09-10T18:00:02.000004Z"
        )
        let manager = manager(
            with: [
                dto(1, author: 1, canDelete: true, responses: 1, hasResponses: true),
                dto(2, author: 1, canDelete: true, parent: 1, relationship: "supports")
            ],
            api: api
        )

        _ = await manager.deleteMarker(id: id(2))

        let parent = try! #require(manager.markers.first { $0.id == self.id(1) })
        #expect(parent.responseCount == 0)
        #expect(parent.marker.hasResponses == true, "an omitted flag is not a false one")
    }

    // MARK: - Reconciler ordering carries the flag

    /// The flag rides the same revision ordering as the count: an older payload
    /// cannot resurrect a thesis a newer one closed.
    @Test
    func aStaleStructuralFlagIsRejectedWithItsCount() {
        var reconciler = MarkerResponseCountReconciler()
        reconciler.apply(
            MarkerResponseCountUpdate(
                markerId: id(1), directResponseCount: 0,
                revision: MarkerRevision.make("2026-09-10T18:00:05.000009Z"),
                hasResponses: false
            )
        )
        let outcome = reconciler.apply(
            MarkerResponseCountUpdate(
                markerId: id(1), directResponseCount: 1,
                revision: MarkerRevision.make("2026-09-10T18:00:04.000009Z"),
                hasResponses: true
            )
        )
        #expect(outcome == .stale)
        #expect(reconciler.hasResponses(for: id(1)) == false)
        #expect(reconciler.count(for: id(1)) == 0)
    }

    /// A newer payload that omits the flag must not blank one an earlier
    /// payload supplied — absent is "did not say", not "no".
    @Test
    func aNewerPayloadWithoutTheFlagKeepsTheKnownOne() {
        var reconciler = MarkerResponseCountReconciler()
        reconciler.apply(
            MarkerResponseCountUpdate(
                markerId: id(1), directResponseCount: 1,
                revision: MarkerRevision.make("2026-09-10T18:00:05.000009Z"),
                hasResponses: true
            )
        )
        reconciler.apply(
            MarkerResponseCountUpdate(
                markerId: id(1), directResponseCount: 2,
                revision: MarkerRevision.make("2026-09-10T18:00:06.000009Z")
            )
        )
        #expect(reconciler.count(for: id(1)) == 2)
        #expect(reconciler.hasResponses(for: id(1)) == true)
    }

    /// A redelivery of the same revision cannot move the count, but may still
    /// fill in a flag that was missing at that revision.
    @Test
    func aRedeliveryFillsInAMissingFlagAtTheSameRevision() {
        var reconciler = MarkerResponseCountReconciler()
        let revision = MarkerRevision.make("2026-09-10T18:00:07.000009Z")
        reconciler.apply(
            MarkerResponseCountUpdate(markerId: id(1), directResponseCount: 0, revision: revision)
        )
        #expect(reconciler.hasResponses(for: id(1)) == nil)

        reconciler.apply(
            MarkerResponseCountUpdate(
                markerId: id(1), directResponseCount: 0, revision: revision, hasResponses: true
            )
        )
        #expect(reconciler.hasResponses(for: id(1)) == true)
        #expect(reconciler.count(for: id(1)) == 0)
    }
}

/// Records delete calls and can be told to fail.
private final class DeleteFakeAPI: MarkerAPIClient, @unchecked Sendable {
    var acknowledgement = RLMarkerDeleteResponseDTO(detail: "deleted")
    var failure: Error?
    var deleteCalls: [UUID] = []

    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO {
        deleteCalls.append(markerId)
        if let failure { throw failure }
        return acknowledgement
    }

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        RLMarkersListDTO(markers: [], totalCount: 0, hasMore: false, nextCursor: nil)
    }
    func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO {
        throw APIError.serverError(500, "unused")
    }
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.serverError(500, "unused")
    }
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.serverError(500, "unused")
    }
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        throw APIError.serverError(500, "unused")
    }
    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO {
        throw APIError.serverError(500, "unused")
    }
    func addMarkerComment(
        guildId: UUID, markerId: UUID, content: String, attachmentUrl: String?,
        attachmentType: String?, attachmentName: String?, replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO {
        throw APIError.serverError(500, "unused")
    }
    func toggleMarkerCommentReaction(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMarkerCommentDTO {
        throw APIError.serverError(500, "unused")
    }
    func getMarkerCommentReactionReactors(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        throw APIError.serverError(500, "unused")
    }
    func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        throw APIError.serverError(500, "unused")
    }
}
