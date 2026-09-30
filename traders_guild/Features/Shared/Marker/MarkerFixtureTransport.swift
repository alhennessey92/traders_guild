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

    init(mode: Mode, author: RLGuildMemberDTO) {
        self.mode = mode
        self.author = author
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
        try await MainActor.run {
            createRequests.append(body)
            switch mode {
            case .succeed:
                break
            case .failFirst(let detail):
                if createRequests.count == 1 { throw APIError.badRequest(detail) }
            case .failAlways(let detail):
                throw APIError.badRequest(detail)
            }
            return marker(from: body, guildId: guildId)
        }
    }

    /// What a server would hand back for `body`.
    private func marker(from body: RLCreateMarkerRequest, guildId: UUID) -> RLChartMarkerDTO {
        let components = body.components.enumerated().map { index, component in
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: component.componentType,
                payload: MarkerComponentPayload.decode(componentType: component.componentType, rawPayload: component.payload),
                ordering: index
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
    nonisolated func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.networkError("fixture")
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
