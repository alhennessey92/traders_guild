import Foundation
import CoreGraphics
import Testing
@testable import traders_guild

@MainActor
struct MarkerHorizontalLinePayloadTests {
    @Test
    func horizontalLineComponentRoundTripsThroughDTOEncoding() throws {
        let component = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.drawingHorizontalLine.rawValue,
            payload: .drawingHorizontalLine(
                HorizontalLinePayload(
                    price: 1.23456,
                    label: "Breakout Level",
                    colorHex: "#10B981",
                    lineStyle: .dotted,
                    lineWidth: 2.5
                )
            ),
            ordering: 4
        )

        let data = try JSONEncoder().encode(component)
        let decoded = try JSONDecoder().decode(RLMarkerComponentDTO.self, from: data)

        #expect(decoded.componentType == RLComponentType.drawingHorizontalLine.rawValue)
        #expect(decoded.ordering == 4)

        if case let .drawingHorizontalLine(payload) = decoded.payload {
            #expect(payload.price == 1.23456)
            #expect(payload.label == "Breakout Level")
            #expect(payload.colorHex == "#10B981")
            #expect(payload.lineStyle == .dotted)
            #expect(payload.lineWidth == 2.5)
        } else {
            Issue.record("Expected drawing.horizontal_line payload after decode")
        }
    }

    @Test
    func buildCreateRequestPersistsHorizontalLineLabel() {
        let state = MarkerPlacementState()
        let anchorTime = Date(timeIntervalSince1970: 1_700_000_000)
        state.reset(to: .analysis, anchorTime: anchorTime, anchorPrice: 1.2000)

        _ = state.addDrawingOverlayComponent(
            .drawingHorizontalLine,
            payload: .drawingHorizontalLine(
                HorizontalLinePayload(
                    price: 1.245,
                    label: "Liquidity Sweep",
                    colorHex: "#8B5CF6",
                    lineStyle: .solid,
                    lineWidth: 3
                )
            )
        )

        let request = state.buildCreateRequest(symbolId: UUID(), timeframe: "1h")
        let horizontal = request.components.first {
            $0.componentType == RLComponentType.drawingHorizontalLine.rawValue
        }

        #expect(horizontal != nil)
        #expect((horizontal?.payload["label"]?.value as? String) == "Liquidity Sweep")
        #expect((horizontal?.payload["price"]?.value as? Double) == 1.245)
        #expect((horizontal?.payload["color_hex"]?.value as? String) == "#8B5CF6")
        #expect((horizontal?.payload["line_style"]?.value as? String) == "solid")
        #expect((horizontal?.payload["line_width"]?.value as? Int) == 3)
    }

    @Test
    func renderedGlyphFocusPriceUsesStackedMarkerLayoutNotCandleClose() {
        let candle = RLCandleDTO(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            timestampFormatted: nil,
            open: 100,
            high: 110,
            low: 90,
            close: 101,
            volume: nil,
            volumeFormatted: nil
        )

        var marker = ChartMarkerUI(marker: makeMarkerDTO(timestamp: candle.timestamp), candleIndex: 0)
        marker.positionedBelow = false
        marker.proximityTier = 1
        marker.stackIndex = 2

        let focusPrice = MarkerFocusHelper.renderedGlyphFocusPrice(
            marker: marker,
            candles: [candle],
            chartSize: CGSize(width: 390, height: 520),
            priceRange: (min: 80, max: 130),
            priceScale: 1,
            verticalOffset: 0,
            totalCandleWidth: 16,
            actualCandleWidth: 12,
            totalOffset: 120
        )

        #expect(focusPrice != nil)
        if let focusPrice {
            #expect(abs(focusPrice - candle.close) > 0.001)
            #expect(focusPrice > candle.high)
        }
    }

    private func makeMarkerDTO(timestamp: Date) -> RLChartMarkerDTO {
        let author = RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 10,
            contributionScore: 20,
            dateJoined: Date(timeIntervalSince1970: 1_600_000_000),
            accuracyRate: 0.65,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: UUID(),
            username: "tester",
            displayName: "Tester",
            avatarUrl: nil,
            isOnline: true,
            globalReputation: 100,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )

        let anchor = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: timestamp, price: 101)),
            ordering: 0
        )

        return RLChartMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            guildId: UUID(),
            author: author,
            candleTimestamp: timestamp,
            timeframe: "1h",
            price: 101,
            intent: RLMarkerIntent.analysis.rawValue,
            title: nil,
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            trackingState: nil,
            alertSeverity: nil,
            createdAt: timestamp,
            createdAtFormatted: "now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: false,
            canEdit: false,
            canDelete: false,
            components: [anchor],
            primaryComponentId: anchor.id,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: nil,
            predictionResult: nil
        )
    }
}
