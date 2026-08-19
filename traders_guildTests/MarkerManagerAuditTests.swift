import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import traders_guild

@MainActor
struct MarkerManagerAuditTests {
    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    @Test
    func visibilityModeAndTypeFiltering() {
        let me = makeMember(
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            username: "me",
            isFriend: false
        )
        let friend = makeMember(
            userId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            username: "friend",
            isFriend: true
        )
        let stranger = makeMember(
            userId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            username: "stranger",
            isFriend: false
        )

        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.markers = [
            makeMarker(
                id: UUID(),
                author: me,
                intent: .setup,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0
            ),
            makeMarker(
                id: UUID(),
                author: friend,
                intent: .analysis,
                isCurrentUserMarker: false,
                isLikedByCurrentUser: false,
                likeCount: 0
            ),
            makeMarker(
                id: UUID(),
                author: stranger,
                intent: .alert,
                isCurrentUserMarker: false,
                isLikedByCurrentUser: false,
                likeCount: 0
            )
        ]

        manager.visibilityMode = .all
        manager.visibleIntents = Set(RLMarkerIntent.allCases)
        #expect(manager.filteredMarkers.count == 3)

        manager.visibilityMode = .mine
        #expect(manager.filteredMarkers.count == 1)
        #expect(manager.filteredMarkers.first?.author.username == "me")

        manager.visibilityMode = .friends
        #expect(manager.filteredMarkers.count == 1)
        #expect(manager.filteredMarkers.first?.author.username == "friend")

        manager.visibilityMode = .all
        manager.visibleIntents = [.setup, .analysis]
        #expect(manager.filteredMarkers.count == 2)

        manager.visibilityMode = .off
        #expect(manager.filteredMarkers.isEmpty)
    }

    @Test
    func intentFilteringAppliesWhenConfigured() {
        let me = makeMember(
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            username: "me",
            isFriend: false
        )
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)

        manager.markers = [
            makeMarker(
                id: UUID(),
                author: me,
                intent: .analysis,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0
            ),
            makeMarker(
                id: UUID(),
                author: me,
                intent: .setup,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0
            )
        ]

        manager.visibleIntents = [.analysis]
        #expect(manager.filteredMarkers.count == 1)
        #expect(manager.filteredMarkers.first?.intent == .analysis)
    }

    @Test
    func foreignPrivateMarkersAreFilteredEvenInAllMode() {
        let me = makeMember(
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            username: "me",
            isFriend: false
        )
        let friend = makeMember(
            userId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            username: "friend",
            isFriend: true
        )

        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.markers = [
            makeMarker(
                id: UUID(),
                author: me,
                intent: .personal,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0,
                visibility: "private"
            ),
            makeMarker(
                id: UUID(),
                author: friend,
                intent: .personal,
                isCurrentUserMarker: false,
                isLikedByCurrentUser: false,
                likeCount: 0,
                visibility: "private"
            ),
            makeMarker(
                id: UUID(),
                author: friend,
                intent: .analysis,
                isCurrentUserMarker: false,
                isLikedByCurrentUser: false,
                likeCount: 0,
                visibility: "guild"
            ),
        ]

        manager.visibilityMode = .all
        #expect(manager.filteredMarkers.count == 2)
        #expect(manager.filteredMarkers.allSatisfy {
            $0.visibility != "private" || $0.author.userId == me.userId
        })
    }

    @Test
    func toggleLikeSurvivesConcurrentMarkerRemoval() async throws {
        let me = makeMember(userId: UUID(), username: "me", isFriend: false)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        let markerId = UUID()

        manager.markers = [
            makeMarker(
                id: markerId,
                author: me,
                intent: .setup,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 1
            )
        ]

        let api = MarkerAuditFakeAPI()
        api.toggleLikeDelayNs = 120_000_000
        api.toggleLikeResult = RLLikeMarkerDTO(markerId: markerId, likeCount: 2, isLiked: true)
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let toggleTask = Task { await manager.toggleLike(markerId: markerId) }
        try await Task.sleep(nanoseconds: 20_000_000)
        manager.markers.removeAll { $0.id == markerId }

        await toggleTask.value
        #expect(manager.markers.isEmpty)
    }

    @Test
    func addCommentSurvivesConcurrentMarkerRemoval() async throws {
        let me = makeMember(userId: UUID(), username: "me", isFriend: false)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        let markerId = UUID()

        manager.markers = [
            makeMarker(
                id: markerId,
                author: me,
                intent: .analysis,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0
            )
        ]

        let api = MarkerAuditFakeAPI()
        api.addCommentDelayNs = 120_000_000
        api.addCommentResult = makeComment(
            markerId: markerId,
            author: me,
            content: "saved comment"
        )
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let addTask = Task { await manager.addComment(markerId: markerId, content: "test") }
        try await Task.sleep(nanoseconds: 20_000_000)
        manager.markers.removeAll { $0.id == markerId }

        await addTask.value
        #expect(manager.markers.isEmpty)
    }

    @Test
    func deleteCommentRollsBackOnFailure() async throws {
        let me = makeMember(userId: UUID(), username: "me", isFriend: false)
        let markerId = UUID()
        let comment = makeComment(markerId: markerId, author: me, content: "temporary")

        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.markers = [
            makeMarker(
                id: markerId,
                author: me,
                intent: .analysis,
                isCurrentUserMarker: true,
                isLikedByCurrentUser: false,
                likeCount: 0,
                comments: [comment]
            )
        ]

        let api = MarkerAuditFakeAPI()
        api.shouldFailDeleteComment = true
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let success = await manager.deleteComment(markerId: markerId, commentId: comment.id)
        #expect(!success)
        #expect(manager.markers.first?.comments.count == 1)
        #expect(manager.markers.first?.comments.first?.id == comment.id)
    }

    @Test
    func trackingStateChangedRealtimeEventPatchesExistingMarker() async throws {
        let me = makeMember(userId: UUID(), username: "me", isFriend: false)
        let markerId = UUID()
        let timestamp = Date()

        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        let api = MarkerAuditFakeAPI()

        let markerDTO = RLChartMarkerDTO(
            id: markerId,
            symbolId: symbolId,
            guildId: guildId,
            author: me,
            candleTimestamp: timestamp,
            timeframe: RLChartTimeframe.h1.toBackendString(),
            price: 1.2345,
            intent: RLMarkerIntent.setup.rawValue,
            title: "Setup",
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: true,
            trackingState: RLTrackingState.armed.rawValue,
            alertSeverity: nil,
            createdAt: timestamp,
            createdAtFormatted: "now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true,
            components: [
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.anchor.rawValue,
                    payload: .anchor(AnchorPayload(time: timestamp, price: 1.2345)),
                    ordering: 0
                ),
            ],
            primaryComponentId: nil,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: nil,
            predictionResult: nil
        )
        api.markersResponse = RLMarkersListDTO(markers: [markerDTO], totalCount: 1, hasMore: false, nextCursor: nil)

        let dataManager = ChartDataManager()
        dataManager.candles = [
            RLCandleDTO(
                timestamp: timestamp,
                open: 1.2,
                high: 1.25,
                low: 1.19,
                close: 1.24,
                volume: nil
            ),
        ]
        manager.configureRealTime(dataManager: dataManager)
        await manager.loadMarkersFromAPI(
            api: api,
            symbolId: symbolId,
            symbol: "BTCUSD",
            guildId: guildId,
            timeframe: .h1,
            candles: dataManager.candles
        )

        let payload = AnyCodable([
            "marker_id": markerId.uuidString,
            "old_state": RLTrackingState.armed.rawValue,
            "new_state": RLTrackingState.active.rawValue,
            "guild_id": guildId.uuidString,
            "symbol_id": symbolId.uuidString,
        ] as [String: Any])
        let channel = "guild:\(guildId.uuidString.lowercased()):markers"
        RealTimeService.shared.messageSubject.send(
            WSIncomingMessage(
                type: "tracking_state_changed",
                channel: channel,
                payload: payload,
                userId: nil,
                isTyping: nil,
                message: nil,
                channels: nil
            )
        )

        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(manager.markers.first?.trackingState == .active)
    }
}

struct MarkerPlacementFormattingTests {
    @Test
    func formatterUsesTimeframeAwarePatterns() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-01-15T13:45:00Z"))
        let intraday = MarkerPlacementLabelFormatter.format(date, timeframe: .m5)
        let daily = MarkerPlacementLabelFormatter.format(date, timeframe: .d1)

        #expect(intraday.contains(":"))
        #expect(!daily.contains(":"))
    }

    @Test
    func usernameCollisionSuppressionIsDeterministic() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let visible = ChartMarkerSystem.visibleUsernameMarkerIDs(from: [
            .init(markerId: first, rect: CGRect(x: 0, y: 0, width: 30, height: 12), sortKey: 0),
            .init(markerId: second, rect: CGRect(x: 8, y: 0, width: 30, height: 12), sortKey: 1),
            .init(markerId: third, rect: CGRect(x: 60, y: 0, width: 30, height: 12), sortKey: 2)
        ])

        #expect(visible.contains(first))
        #expect(!visible.contains(second))
        #expect(visible.contains(third))

        let priorityVisible = ChartMarkerSystem.visibleUsernameMarkerIDs(from: [
            .init(markerId: first, rect: CGRect(x: 0, y: 0, width: 30, height: 12), sortKey: 5),
            .init(markerId: second, rect: CGRect(x: 8, y: 0, width: 30, height: 12), sortKey: 1)
        ])

        #expect(!priorityVisible.contains(first))
        #expect(priorityVisible.contains(second))
    }
}

struct MessagingMarkerShareTests {
    @Test
    func markerListMappingAndSortingLatestFirst() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-02-01T10:00:00Z"))
        let older = try #require(ISO8601DateFormatter().date(from: "2026-01-31T10:00:00Z"))
        let oldest = try #require(ISO8601DateFormatter().date(from: "2026-01-30T10:00:00Z"))

        let markers = [
            makeTopMarker(id: UUID(), createdAt: older, timeframe: "h1", intent: "setup"),
            makeTopMarker(id: UUID(), createdAt: now, timeframe: "m5", intent: "setup"),
            makeTopMarker(id: UUID(), createdAt: oldest, timeframe: "d1", intent: "analysis")
        ]

        let mapped = markers
            .sorted { $0.createdAt > $1.createdAt }
            .map(ChatMarkerLinkDraft.init(marker:))

        #expect(mapped.count == 3)
        #expect(mapped[0].createdAt == now)
        #expect(mapped[1].createdAt == older)
        #expect(mapped[2].createdAt == oldest)
        #expect(mapped[0].timeframe == "m5")
    }

    @Test
    func markerShareCodecRoundTripPreservesCaptionAndPayload() {
        let payload = MarkerSharePayloadV1(
            markerId: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            symbolId: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!,
            symbolTicker: "BTCUSD",
            timeframe: "h1",
            candleTimestamp: Date(timeIntervalSince1970: 1_706_000_000)
        )

        let encoded = MarkerShareCodec.buildMessage(note: "Check this marker", payload: payload)
        let extracted = MarkerShareCodec.extract(from: encoded)

        #expect(extracted != nil)
        #expect(extracted?.visibleText == "Check this marker")
        #expect(extracted?.payload == payload)
    }

    @Test
    func composerContentBuilderIncludesMarkerTokenWithAttachmentFallbackText() {
        let draft = ChatMarkerLinkDraft(
            marker: makeTopMarker(
                id: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!,
                createdAt: Date(timeIntervalSince1970: 1_706_100_000),
                timeframe: "m15",
                intent: "analysis"
            )
        )

        let payload = ChatComposerPayload(
            text: "",
            attachment: ChatAttachmentDraft(data: Data([0x01]), filename: "chart.png", mimeType: "image/png"),
            markerShareDraft: draft
        )

        #expect(payload.hasBodyContent)
        #expect(payload.attachments.count == 1)

        let outbound = payload.encodedContent(fallback: "chart.png")
        let extracted = MarkerShareCodec.extract(from: outbound)

        #expect(extracted != nil)
        #expect(extracted?.visibleText == "chart.png")
        #expect(extracted?.payload.markerId == draft.markerId)
        #expect(extracted?.payload.symbolId == draft.symbolId)
        #expect(extracted?.payload.timeframe == draft.timeframe)
    }
}

struct IndicatorHeaderStateTests {
    @Test
    func rsiAndCciConditionLabelsAndColorsAreStable() {
        #expect(RSICondition.overbought.label == "OVERBOUGHT")
        #expect(RSICondition.oversold.label == "OVERSOLD")
        #expect(RSICondition.neutral.label.isEmpty)
        #expect(colorsApproximatelyEqual(UIColor(RSICondition.overbought.color), UIColor.systemRed))
        #expect(colorsApproximatelyEqual(UIColor(RSICondition.oversold.color), UIColor.systemGreen))

        #expect(CCICondition.overbought.label == "OVERBOUGHT")
        #expect(CCICondition.oversold.label == "OVERSOLD")
        #expect(CCICondition.neutral.label.isEmpty)
        #expect(colorsApproximatelyEqual(UIColor(CCICondition.overbought.color), UIColor.systemRed))
        #expect(colorsApproximatelyEqual(UIColor(CCICondition.oversold.color), UIColor.systemGreen))
    }

    @Test
    func volumeConditionDerivesFromLatestPointDirection() {
        let bullishPoint = VolumeDataPoint(
            candleIndex: 10,
            volume: 1200,
            isBullish: true,
            ma: 900,
            timestamp: Date()
        )
        let bearishPoint = VolumeDataPoint(
            candleIndex: 11,
            volume: 800,
            isBullish: false,
            ma: 950,
            timestamp: Date()
        )

        #expect(bullishPoint.condition == .bullish)
        #expect(bullishPoint.condition.label == "BULLISH")
        #expect(bearishPoint.condition == .bearish)
        #expect(bearishPoint.condition.label == "BEARISH")
    }
}

struct ChatAuthorTapRoutingTests {
    @Test
    func prefersExplicitAuthorTapOverAvatarTap() {
        var calls: [String] = []
        let resolved = ChatAuthorTapRouting.resolved(
            onAuthorTap: { calls.append("author") },
            onAvatarTap: { calls.append("avatar") }
        )

        resolved?()
        #expect(calls == ["author"])
    }

    @Test
    func fallsBackToAvatarTapWhenAuthorTapMissing() {
        var calls: [String] = []
        let resolved = ChatAuthorTapRouting.resolved(
            onAuthorTap: nil,
            onAvatarTap: { calls.append("avatar") }
        )

        resolved?()
        #expect(calls == ["avatar"])
    }

    @Test
    func returnsNilWhenNoTapHandlersProvided() {
        let resolved = ChatAuthorTapRouting.resolved(onAuthorTap: nil, onAvatarTap: nil)
        if case nil = resolved {
            #expect(true)
        } else {
            #expect(false)
        }
    }
}

private final class MarkerAuditFakeAPI: MarkerAPIClient {
    var toggleLikeDelayNs: UInt64 = 0
    var addCommentDelayNs: UInt64 = 0
    var shouldFailDeleteComment = false

    var toggleLikeResult = RLLikeMarkerDTO(markerId: UUID(), likeCount: 0, isLiked: false)
    var markersResponse = RLMarkersListDTO(markers: [], totalCount: 0, hasMore: false, nextCursor: nil)
    var addCommentResult = RLMarkerCommentDTO(
        id: UUID(),
        markerId: UUID(),
        author: RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 0,
            contributionScore: 0,
            dateJoined: Date(),
            accuracyRate: nil,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: UUID(),
            username: "author",
            displayName: "Author",
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 0,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        ),
        content: "comment",
        timestamp: Date(),
        timestampFormatted: "just now",
        isEdited: false,
        isCurrentUserMessage: false,
        canEdit: true,
        canDelete: true
    )

    func getMarkers(
        guildId: UUID,
        symbolId: UUID,
        timeframe: String,
        limit: Int,
        cursor: String?,
        startTime: Date?,
        endTime: Date?
    ) async throws -> RLMarkersListDTO {
        markersResponse
    }

    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        fatalError("createMarkerV2 should not be called in MarkerAuditFakeAPI")
    }

    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        fatalError("updateMarkerV2 should not be called in MarkerAuditFakeAPI")
    }

    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLDetailResponseDTO {
        fatalError("deleteMarker should not be called in MarkerAuditFakeAPI")
    }

    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        if toggleLikeDelayNs > 0 {
            try await Task.sleep(nanoseconds: toggleLikeDelayNs)
        }
        return toggleLikeResult
    }

    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO {
        fatalError("voteOnPoll should not be called in MarkerAuditFakeAPI")
    }

    func addMarkerComment(
        guildId: UUID,
        markerId: UUID,
        content: String,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO {
        if addCommentDelayNs > 0 {
            try await Task.sleep(nanoseconds: addCommentDelayNs)
        }
        return addCommentResult
    }

    func toggleMarkerCommentReaction(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMarkerCommentDTO {
        fatalError("toggleMarkerCommentReaction should not be called in MarkerAuditFakeAPI")
    }

    func getMarkerCommentReactionReactors(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        fatalError("getMarkerCommentReactionReactors should not be called in MarkerAuditFakeAPI")
    }

    func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        if shouldFailDeleteComment {
            throw MarkerAuditError.simulatedFailure
        }
        return RLDetailResponseDTO(detail: "ok")
    }
}

private enum MarkerAuditError: Error {
    case simulatedFailure
}

private func makeMember(userId: UUID, username: String, isFriend: Bool) -> RLGuildMemberDTO {
    RLGuildMemberDTO(
        membershipId: UUID(),
        role: "member",
        reputation: 100,
        contributionScore: 10,
        dateJoined: Date(),
        accuracyRate: 0.5,
        mutedUntil: nil,
        suspendedUntil: nil,
        userId: userId,
        username: username,
        displayName: username,
        avatarUrl: nil,
        isOnline: true,
        globalReputation: 1000,
        isFriend: isFriend,
        friendshipStatus: isFriend ? "accepted" : nil,
        isBlocked: false,
        isBlockedBy: false
    )
}

private func makeComment(markerId: UUID, author: RLGuildMemberDTO, content: String) -> RLMarkerCommentDTO {
    RLMarkerCommentDTO(
        id: UUID(),
        markerId: markerId,
        author: author,
        content: content,
        timestamp: Date(),
        timestampFormatted: "now",
        isEdited: false,
        isCurrentUserMessage: false,
        canEdit: true,
        canDelete: true
    )
}

private func makeMarker(
    id: UUID,
    author: RLGuildMemberDTO,
    intent: RLMarkerIntent,
    isCurrentUserMarker: Bool,
    isLikedByCurrentUser: Bool,
    likeCount: Int,
    visibility: String = "guild",
    comments: [RLMarkerCommentDTO] = []
) -> ChartMarkerUI {
    let anchorComponent = RLMarkerComponentDTO(
        id: UUID(),
        componentType: RLComponentType.anchor.rawValue,
        payload: .anchor(AnchorPayload(time: Date(), price: 1.2345)),
        ordering: 0
    )
    var components: [RLMarkerComponentDTO] = [anchorComponent]
    if intent == .setup {
        components.append(
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.levelEntry.rawValue,
                payload: .levelEntry(LevelPayload(price: 1.2345, label: nil)),
                ordering: 1
            )
        )
    }
    let dto = RLChartMarkerDTO(
        id: id,
        symbolId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        guildId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        author: author,
        candleTimestamp: Date(),
        timeframe: RLChartTimeframe.h1.toBackendString(),
        price: 1.2345,
        intent: intent.rawValue,
        title: nil,
        note: "test",
        visibility: visibility,
        confidence: nil,
        trackingEnabled: intent == .setup,
        trackingState: intent == .setup ? RLTrackingState.armed.rawValue : nil,
        alertSeverity: nil,
        createdAt: Date(),
        createdAtFormatted: "now",
        isVisible: true,
        likeCount: likeCount,
        isLikedByCurrentUser: isLikedByCurrentUser,
        commentCount: comments.count,
        comments: comments,
        isCurrentUserMarker: isCurrentUserMarker,
        canEdit: true,
        canDelete: true,
        components: components,
        primaryComponentId: anchorComponent.id,
        pollQuestion: nil,
        pollOptions: nil,
        userPollVote: nil,
        predictionResult: nil
    )

    return ChartMarkerUI(marker: dto, candleIndex: 0)
}

private func makeTopMarker(
    id: UUID,
    createdAt: Date,
    timeframe: String,
    intent: String
) -> RLTopMarkerDTO {
    RLTopMarkerDTO(
        id: id,
        symbolId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        symbolTicker: "BTCUSD",
        symbolBrandColor: "#f7931a",
        symbolAssetClass: "crypto",
        guildId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        authorId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        authorUsername: "tester",
        authorInitials: "T",
        authorAvatarUrl: nil,
        authorIsOnline: true,
        authorReputation: 100,
        authorAccuracyRate: 0.62,
        authorRole: "member",
        intent: intent,
        title: nil,
        notePreview: "preview",
        pollQuestion: nil,
        pollOptions: nil,
        selectedEmoji: nil,
        alertSeverity: nil,
        createdAt: createdAt,
        createdAtFormatted: "now",
        candleTimestamp: createdAt,
        timeframe: timeframe,
        price: 50000,
        setupSummary: nil,
        likeCount: 0,
        isLikedByCurrentUser: false,
        commentCount: 0,
        trendingScore: 1.0,
        isCurrentUserMarker: true
    )
}

private func colorsApproximatelyEqual(_ lhs: UIColor, _ rhs: UIColor, tolerance: CGFloat = 0.01) -> Bool {
    var lr: CGFloat = 0
    var lg: CGFloat = 0
    var lb: CGFloat = 0
    var la: CGFloat = 0
    var rr: CGFloat = 0
    var rg: CGFloat = 0
    var rb: CGFloat = 0
    var ra: CGFloat = 0

    guard lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la),
          rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra) else {
        return false
    }

    return abs(lr - rr) <= tolerance
        && abs(lg - rg) <= tolerance
        && abs(lb - rb) <= tolerance
        && abs(la - ra) <= tolerance
}
