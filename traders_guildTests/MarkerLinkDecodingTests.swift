import Foundation
import Testing
@testable import traders_guild

/// Wire compatibility for the 1.3.0 link fields.
struct MarkerLinkDecodingTests {

    /// The decoder the app actually uses for chart payloads.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: raw) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "bad date \(raw)")
        }
        return decoder
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - Link preview

    @Test
    func decodesAFullyHydratedPreview() throws {
        let preview = try decode(RLMarkerLinkPreviewDTO.self, """
        {
          "node_key": "n1",
          "parent_key": "n0",
          "marker_id": "11111111-1111-1111-1111-111111111111",
          "parent_marker_id": "00000000-0000-0000-0000-000000000000",
          "link_relationship": "challenges",
          "is_unavailable": false,
          "author_username": "alex",
          "author_display_name": "Alex",
          "symbol_id": "22222222-2222-2222-2222-222222222222",
          "ticker": "BTC",
          "timeframe": "1h",
          "candle_timestamp": "2026-09-01T12:00:00Z",
          "price": 64000.5,
          "intent": "setup",
          "title": "Breakout",
          "direct_response_count": 3,
          "depth": 2
        }
        """)

        #expect(preview.nodeKey == "n1")
        #expect(preview.relationship?.known == .challenges)
        #expect(preview.directResponseCount == 3)
        #expect(preview.canNavigate)
        #expect(preview.possessiveSummary == "Alex's Breakout")
    }

    /// A tombstone keeps structure and nothing else, and can never be tapped.
    @Test
    func decodesATombstone() throws {
        let preview = try decode(RLMarkerLinkPreviewDTO.self, """
        {
          "node_key": "n2",
          "parent_key": "n1",
          "link_relationship": "supports",
          "is_unavailable": true,
          "direct_response_count": 1,
          "depth": 3
        }
        """)

        #expect(preview.isUnavailable)
        #expect(preview.markerId == nil)
        #expect(preview.authorDisplayText == nil)
        #expect(preview.titleDisplayText == nil)
        #expect(!preview.canNavigate)
        #expect(preview.depth == 3)
        #expect(preview.relationship?.known == .supports, "relationship survives on a tombstone")
    }

    /// A relationship added server-side after this build shipped must not fail
    /// the decode, and must still render something truthful.
    @Test
    func toleratesAnUnknownRelationship() throws {
        let preview = try decode(RLMarkerLinkPreviewDTO.self, """
        {"node_key": "n3", "link_relationship": "partially_refutes", "direct_response_count": 0, "depth": 0}
        """)

        #expect(preview.relationship?.known == nil)
        #expect(preview.relationship?.displayName == "Partially refutes")
        #expect(preview.linkRelationship == "partially_refutes", "the raw value is preserved")
    }

    @Test
    func missingOptionalsFallBackSafely() throws {
        let preview = try decode(RLMarkerLinkPreviewDTO.self, #"{"node_key": "n4"}"#)
        #expect(preview.directResponseCount == 0)
        #expect(preview.depth == 0)
        #expect(!preview.isUnavailable)
        #expect(preview.relationship == nil)
    }

    // MARK: - Thread response

    @Test
    func decodesAThreadWindowWithoutATotal() throws {
        let page = try decode(RLMarkerThreadResponseDTO.self, """
        {
          "requested_marker_id": "11111111-1111-1111-1111-111111111111",
          "root_resolved": false,
          "window_root_key": "n1",
          "nodes": [{"node_key": "n1"}],
          "ancestor_cursor": "up-1",
          "branches": [{"node_key": "n1", "cursor": "b-1"}],
          "loaded_count": 1,
          "truncated": true
        }
        """)

        #expect(page.totalCount == nil, "a nil total means unknown, never zero")
        #expect(page.rootMarkerId == nil)
        #expect(!page.rootResolved)
        #expect(page.ancestorCursor == "up-1")
        #expect(page.branches.first?.cursor == "b-1")
        #expect(page.truncated)
    }

    // MARK: - Marker payloads

    /// The live App Store build's payload shape: no link fields at all.
    @Test
    func preThirteenMarkerPayloadStillDecodes() throws {
        let marker = try decode(RLChartMarkerDTO.self, Self.markerJSON(extra: ""))
        #expect(marker.parentMarkerId == nil)
        #expect(marker.linkRelationship == nil)
        #expect(marker.parentPreview == nil)
        #expect(marker.responseCount == 0, "an absent count reads as none, not as missing")
        #expect(!marker.isLinkedResponse)
        #expect(!marker.participatesInThesis)
        #expect(marker.parentCountUpdate == nil)
    }

    @Test
    func linkedMarkerPayloadDecodes() throws {
        let marker = try decode(RLChartMarkerDTO.self, Self.markerJSON(extra: """
        ,
        "parent_marker_id": "99999999-9999-9999-9999-999999999999",
        "link_relationship": "builds_on",
        "direct_response_count": 4,
        "responses_revision": "2026-09-01T12:00:00Z",
        "parent_direct_response_count": 7,
        "parent_responses_revision": "2026-09-01T12:00:01Z",
        "parent_preview": {"node_key": "p1", "is_unavailable": true, "direct_response_count": 7, "depth": 0}
        """))

        #expect(marker.isLinkedResponse)
        #expect(marker.linkRelationshipValue?.known == .buildsOn)
        #expect(marker.responseCount == 4)
        #expect(marker.participatesInThesis)
        #expect(marker.hasUnavailableParent)

        let parentUpdate = try #require(marker.parentCountUpdate)
        #expect(parentUpdate.directResponseCount == 7)
        #expect(parentUpdate.revision != nil)
        #expect(marker.ownCountUpdate?.directResponseCount == 4)
    }

    /// `updating(...)` round-trips through a plain encoder/decoder pair, so the
    /// new fields must survive it — this is how a badge is corrected locally.
    @Test
    func updatingPreservesLinkFields() throws {
        let marker = try decode(RLChartMarkerDTO.self, Self.markerJSON(extra: """
        ,
        "parent_marker_id": "99999999-9999-9999-9999-999999999999",
        "link_relationship": "supports",
        "direct_response_count": 1
        """))

        let bumped = marker.updating(directResponseCount: 9)
        #expect(bumped.responseCount == 9)
        #expect(bumped.parentMarkerId == marker.parentMarkerId, "the link survives a local count patch")
        #expect(bumped.linkRelationshipValue?.known == .supports)
        #expect(bumped.likeCount == marker.likeCount)
    }

    // MARK: - Deletion + capability

    @Test
    func deleteAcknowledgementCarriesParentReconciliation() throws {
        let response = try decode(RLMarkerDeleteResponseDTO.self, """
        {
          "detail": "deleted",
          "marker_id": "11111111-1111-1111-1111-111111111111",
          "parent_marker_id": "99999999-9999-9999-9999-999999999999",
          "parent_direct_response_count": 2,
          "parent_responses_revision": "2026-09-01T12:00:00Z"
        }
        """)
        #expect(response.detail == "deleted")
        #expect(response.parentDirectResponseCount == 2)
    }

    @Test
    func oldDeleteAcknowledgementStillDecodes() throws {
        let response = try decode(RLMarkerDeleteResponseDTO.self, #"{"detail": "Marker deleted"}"#)
        #expect(response.detail == "Marker deleted")
        #expect(response.parentMarkerId == nil)
    }

    @Test
    func deletedEventCarriesParentReconciliation() throws {
        let payload = try decode(MarkerDeletedPayload.self, """
        {
          "marker_id": "11111111-1111-1111-1111-111111111111",
          "guild_id": "22222222-2222-2222-2222-222222222222",
          "parent_marker_id": "99999999-9999-9999-9999-999999999999",
          "parent_direct_response_count": 3
        }
        """)
        #expect(payload.parentCountUpdate?.directResponseCount == 3)
    }

    /// The capability defaults to off, so a server that has never heard of it
    /// leaves the app behaving exactly like 1.2.1.
    @Test
    func capabilityDefaultsOff() throws {
        let flags = try decode(RLRuntimeFlagsDTO.self, #"{"beta_welcome_enabled": true}"#)
        #expect(!flags.linkedMarkersEnabled)
        #expect(flags.betaWelcomeEnabled)
        #expect(!RLRuntimeFlagsDTO.disabled.linkedMarkersEnabled)

        let enabled = try decode(RLRuntimeFlagsDTO.self, #"{"linked_markers_enabled": true}"#)
        #expect(enabled.linkedMarkersEnabled)
    }

    @Test
    func notificationTypeDecodesAndIsPersonal() {
        #expect(RLNotificationType(rawValue: "marker_response") == .markerResponse)
        #expect(RLNotificationType.markerResponse.isPersonal)
    }

    // MARK: - Fixture

    /// A minimal but complete pre-1.3.0 marker payload.
    private static func markerJSON(extra: String) -> String {
        """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "symbol_id": "22222222-2222-2222-2222-222222222222",
          "guild_id": "33333333-3333-3333-3333-333333333333",
          "author": {
            "membership_id": "55555555-5555-5555-5555-555555555555",
            "role": "member",
            "reputation": 0,
            "contribution_score": 0,
            "date_joined": "2026-01-01T00:00:00Z",
            "user_id": "44444444-4444-4444-4444-444444444444",
            "username": "alex",
            "display_name": "Alex",
            "is_online": false,
            "global_reputation": 0,
            "is_friend": false,
            "is_blocked": false,
            "is_blocked_by": false
          },
          "candle_timestamp": "2026-09-01T12:00:00Z",
          "timeframe": "1h",
          "price": 64000.0,
          "intent": "analysis",
          "visibility": "guild",
          "tracking_enabled": false,
          "created_at": "2026-09-01T12:00:00Z",
          "created_at_formatted": "just now",
          "is_visible": true,
          "like_count": 2,
          "is_liked_by_current_user": false,
          "comment_count": 0,
          "comments": [],
          "is_current_user_marker": false,
          "can_edit": false,
          "can_delete": false,
          "components": []
          \(extra)
        }
        """
    }
}
