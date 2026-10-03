//
//  MarkerFixtureTransport.swift
//  traders_guild
//
//  An in-memory marker API for the guided-creation fixtures and tests.
//
//  Not the backend. It records exactly what the app would send and answers
//  the way it is told to — including the way the *current* backend answers a
//  text-only Analysis (400) before the Stage 4 validation change — so the
//  guided flow's posting, failure and retry can be exercised without a server,
//  an account or a network. Nothing here is compiled into production builds.
//

#if DEBUG || TG_ISOLATED_DEV

import Foundation

@MainActor
final class MarkerFixtureTransport: MarkerAPIClient {
    enum Mode: Equatable {
        case succeed
        /// Fail the first create with this 400 detail, then succeed.
        case failFirst(detail: String)
        case failAlways(detail: String)
    }

    /// The current backend's refusal of an Analysis with no chart component.
    static let analysisNeedsComponentDetail = "Analysis markers require at least one chart component"

    var mode: Mode
    let author: RLGuildMemberDTO
    private(set) var createRequests: [RLCreateMarkerRequest] = []
    /// Every update, in order, with the marker it was for.
    private(set) var updateRequests: [(markerId: UUID, body: RLUpdateMarkerRequest)] = []
    /// The markers updates apply to, as the server holds them.
    var storedMarkers: [UUID: RLChartMarkerDTO] = [:]
    /// Hold every update until `releaseHeldUpdates()`.
    var holdsUpdates = false
    private var heldUpdates: [CheckedContinuation<Void, Never>] = []
    var heldUpdateCount: Int { heldUpdates.count }

    /// Hold every create until `releaseHeldCreates()` — a server that is slow
    /// to answer, for exercising what can happen while a post is in flight.
    var holdsCreates = false
    private var heldCreates: [CheckedContinuation<Void, Never>] = []
    var heldCreateCount: Int { heldCreates.count }

    init(mode: Mode, author: RLGuildMemberDTO) {
        self.mode = mode
        self.author = author
    }

    /// Let every held create answer.
    func releaseHeldCreates() {
        let held = heldCreates
        heldCreates.removeAll()
        held.forEach { $0.resume() }
    }

    func releaseHeldUpdates() {
        let held = heldUpdates
        heldUpdates.removeAll()
        held.forEach { $0.resume() }
    }

    /// The last update body exactly as the app would send it.
    var lastUpdateJSON: String? {
        guard let last = updateRequests.last?.body else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(last) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// The last request as the app would send it, pretty-printed.
    var lastRequestJSON: String? {
        guard let last = createRequests.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(last) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        let attempt = await record(body)
        await waitIfHeld()
        return try await answer(attempt: attempt, body: body, guildId: guildId)
    }

    private func record(_ body: RLCreateMarkerRequest) -> Int {
        createRequests.append(body)
        return createRequests.count
    }

    private func waitIfHeld() async {
        guard holdsCreates else { return }
        await withCheckedContinuation { continuation in
            heldCreates.append(continuation)
        }
    }

    private func answer(attempt: Int, body: RLCreateMarkerRequest, guildId: UUID) throws -> RLChartMarkerDTO {
        switch mode {
        case .succeed:
            break
        case .failFirst(let detail):
            if attempt == 1 { throw APIError.badRequest(detail) }
        case .failAlways(let detail):
            throw APIError.badRequest(detail)
        }
        return marker(from: body, guildId: guildId)
    }

    /// What a server would hand back for `body`.
    private func marker(from body: RLCreateMarkerRequest, guildId: UUID) -> RLChartMarkerDTO {
        let components = body.components.enumerated().map { index, component in
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: component.componentType,
                payload: MarkerComponentPayload.decode(componentType: component.componentType, rawPayload: component.payload),
                ordering: index,
                originalRawPayload: component.payload
            )
        }
        let anchor = components.first { $0.componentTypeEnum == .anchor }?.payload
        let created = Date()
        return RLChartMarkerDTO(
            id: UUID(), symbolId: body.symbolId, guildId: guildId, author: author,
            candleTimestamp: anchor?.anchorTime ?? created, timeframe: body.timeframe,
            price: anchor?.levelPrice ?? 0, intent: body.intent, title: body.title, note: body.note,
            visibility: body.visibility, confidence: body.confidence, trackingEnabled: body.trackingEnabled,
            trackingState: body.intent == RLMarkerIntent.setup.rawValue ? (body.trackingEnabled ? "ARMED" : "DRAFT") : nil,
            alertSeverity: nil, createdAt: created, createdAtFormatted: "just now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: components, primaryComponentId: components.first?.id,
            pollQuestion: body.pollQuestion, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: body.parentMarkerId, linkRelationship: body.linkRelationship
        )
    }

    // Everything else is out of scope for creation fixtures.

    nonisolated func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        RLMarkersListDTO(markers: [], totalCount: 0, hasMore: false, nextCursor: nil)
    }
    nonisolated func getMarker(markerId: UUID) async throws -> RLChartMarkerDTO { throw APIError.networkError("fixture") }
    /// Answers as chart-service `update_marker` does: a field present in the
    /// body is applied (`null` clears it), a missing one is unchanged;
    /// components, when present, replace them all and need one anchor; and
    /// components on a tracked Setup past ARMED are refused. Mode decides a
    /// failure first, as for creates.
    nonisolated func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        let attempt = await recordUpdate(markerId: markerId, body: body)
        await waitIfUpdateHeld()
        return try await answerUpdate(attempt: attempt, markerId: markerId, body: body)
    }

    private func recordUpdate(markerId: UUID, body: RLUpdateMarkerRequest) -> Int {
        updateRequests.append((markerId, body))
        return updateRequests.count
    }

    private func waitIfUpdateHeld() async {
        guard holdsUpdates else { return }
        await withCheckedContinuation { continuation in
            heldUpdates.append(continuation)
        }
    }

    private func answerUpdate(attempt: Int, markerId: UUID, body: RLUpdateMarkerRequest) throws -> RLChartMarkerDTO {
        switch mode {
        case .succeed: break
        case .failFirst(let detail): if attempt == 1 { throw APIError.badRequest(detail) }
        case .failAlways(let detail): throw APIError.badRequest(detail)
        }
        guard let stored = storedMarkers[markerId] else { throw APIError.serverError(404, "Marker not found") }
        let lockedStates: Set<String> = ["ACTIVE", "TP_HIT", "SL_HIT", "EXPIRED"]
        if body.components != nil, stored.trackingEnabled, lockedStates.contains(stored.trackingState ?? "") {
            throw APIError.badRequest("Cannot edit components on a tracked setup after activation")
        }
        if let components = body.components,
           components.filter({ $0.componentType == RLComponentType.anchor.rawValue }).count != 1 {
            throw APIError.badRequest("Component replacement must include exactly one 'anchor'")
        }
        let components = body.components.map { requests in
            requests.enumerated().map { index, component in
                RLMarkerComponentDTO(
                    id: UUID(), componentType: component.componentType,
                    payload: MarkerComponentPayload.decode(componentType: component.componentType, rawPayload: component.payload),
                    ordering: index,
                    originalRawPayload: component.payload
                )
            }
        } ?? stored.components
        let anchor = components.first { $0.componentTypeEnum == .anchor }?.payload
        let tracking = body.trackingEnabled ?? stored.trackingEnabled
        var trackingState = stored.trackingState
        if let requested = body.trackingEnabled, stored.intent == RLMarkerIntent.setup.rawValue {
            if requested, trackingState == nil || trackingState == "DRAFT" { trackingState = "ARMED" }
            if !requested, [nil, "DRAFT", "ARMED"].contains(trackingState) { trackingState = "DRAFT" }
        }
        let updated = RLChartMarkerDTO(
            id: stored.id, symbolId: stored.symbolId, guildId: stored.guildId, author: stored.author,
            candleTimestamp: anchor?.anchorTime ?? stored.candleTimestamp, timeframe: stored.timeframe,
            price: anchor?.levelPrice ?? stored.price, intent: body.intent ?? stored.intent,
            title: body.clearsTitle ? nil : (body.title ?? stored.title),
            note: body.clearsNote ? nil : (body.note ?? stored.note),
            visibility: body.visibility ?? stored.visibility, confidence: stored.confidence,
            trackingEnabled: tracking, trackingState: trackingState, alertSeverity: stored.alertSeverity,
            createdAt: stored.createdAt, createdAtFormatted: stored.createdAtFormatted, isVisible: true,
            likeCount: stored.likeCount, isLikedByCurrentUser: stored.isLikedByCurrentUser,
            commentCount: stored.commentCount, comments: stored.comments,
            isCurrentUserMarker: stored.isCurrentUserMarker, canEdit: stored.canEdit, canDelete: stored.canDelete,
            components: components, primaryComponentId: components.first?.id,
            pollQuestion: stored.pollQuestion, pollOptions: stored.pollOptions, userPollVote: stored.userPollVote,
            predictionResult: stored.predictionResult,
            parentMarkerId: stored.parentMarkerId, linkRelationship: stored.linkRelationship,
            parentPreview: stored.parentPreview, directResponseCount: stored.directResponseCount
        )
        storedMarkers[markerId] = updated
        return updated
    }
    nonisolated func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO {
        throw APIError.networkError("fixture")
    }
    nonisolated func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO {
        throw APIError.networkError("fixture")
    }
    nonisolated func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO { throw APIError.networkError("fixture") }
    nonisolated func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO { throw APIError.networkError("fixture") }
    nonisolated func addMarkerComment(
        guildId: UUID, markerId: UUID, content: String, attachmentUrl: String?,
        attachmentType: String?, attachmentName: String?, replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO { throw APIError.networkError("fixture") }
    nonisolated func toggleMarkerCommentReaction(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMarkerCommentDTO { throw APIError.networkError("fixture") }
    nonisolated func getMarkerCommentReactionReactors(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMessageReactionReactorsDTO { throw APIError.networkError("fixture") }
    nonisolated func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        throw APIError.networkError("fixture")
    }
}

#endif
