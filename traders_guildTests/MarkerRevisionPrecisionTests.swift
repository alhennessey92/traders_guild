import Foundation
import Testing
@testable import traders_guild

/// Microsecond-exact revision ordering.
///
/// The backend advances a parent's `responses_revision` by microseconds under a
/// row lock. Foundation's `ISO8601DateFormatter` truncates the fractional part
/// to milliseconds, so two revisions one microsecond apart decode to the *same*
/// `Date` — and a reconciler comparing `Date`s would treat a genuine count
/// change as already-seen and drop it. These tests pin the exact traces.
struct MarkerRevisionPrecisionTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private let earlier = "2026-09-09T10:00:00.123001+00:00"
    private let later = "2026-09-09T10:00:00.123002+00:00"

    // MARK: - The defect this type exists to prevent

    /// The reproduction: Foundation collapses these two instants, and
    /// `MarkerRevision` does not.
    @Test
    func foundationCollapsesMicrosecondsWhereMarkerRevisionDoesNot() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let a = try #require(formatter.date(from: earlier))
        let b = try #require(formatter.date(from: later))
        #expect(
            a.timeIntervalSince1970 == b.timeIntervalSince1970,
            "documents the Foundation behaviour this type works around"
        )

        let ra = try #require(MarkerRevision(wire: earlier))
        let rb = try #require(MarkerRevision(wire: later))
        #expect(ra != rb, "one microsecond apart must not compare equal")
        #expect(ra < rb)
        #expect(rb.microsecondsSinceEpoch - ra.microsecondsSinceEpoch == 1)
    }

    // MARK: - Parsing

    @Test
    func parsesEveryShapeTheBackendEmits() throws {
        let offset = try #require(MarkerRevision(wire: "2026-09-09T10:00:00.123456+00:00"))
        let zulu = try #require(MarkerRevision(wire: "2026-09-09T10:00:00.123456Z"))
        #expect(offset == zulu, "the same instant in both spellings is one revision")

        // A missing fractional part is zero microseconds, not a parse failure.
        let bare = try #require(MarkerRevision(wire: "2026-09-09T10:00:00Z"))
        #expect(bare.microsecondsSinceEpoch % 1_000_000 == 0)
        #expect(bare < offset)

        // Shorter and longer fractions normalise to microseconds.
        let millis = try #require(MarkerRevision(wire: "2026-09-09T10:00:00.123Z"))
        #expect(millis.microsecondsSinceEpoch == bare.microsecondsSinceEpoch + 123_000)
        let nanos = try #require(MarkerRevision(wire: "2026-09-09T10:00:00.123456789Z"))
        #expect(nanos.microsecondsSinceEpoch == bare.microsecondsSinceEpoch + 123_456)
    }

    @Test
    func agreesWithFoundationAtWholeSeconds() throws {
        let text = "2026-09-09T10:00:00Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let expected = try #require(formatter.date(from: text))
        let revision = try #require(MarkerRevision(wire: text))
        #expect(revision.microsecondsSinceEpoch == Int64(expected.timeIntervalSince1970) * 1_000_000)
    }

    /// Malformed input must return nil, never trap.
    ///
    /// The arithmetic is integer and unchecked inputs would reach it, so the
    /// domain is restricted to what Python's `datetime` can actually emit
    /// before any multiplication happens. Each case below previously either
    /// parsed silently wrong or risked overflow.
    @Test
    func rejectsMalformedValuesWithoutTrapping() {
        let malformed = [
            "",                                   // empty
            "   ",                                // blank
            "not-a-timestamp",
            "2026-09-09",                         // date only, no time
            "2026-09-09T",                        // no clock
            "2026-13-01T00:00:00Z",               // month 13
            "2026-00-01T00:00:00Z",               // month 0
            "2026-02-31T00:00:00Z",               // Feb 31 must not normalise into March
            "2025-02-29T00:00:00Z",               // not a leap year
            "0000-01-01T00:00:00Z",               // year below the datetime domain
            "10000-01-01T00:00:00Z",              // year above it
            "99999999999999-01-01T00:00:00Z",     // the overflow candidate
            "2026-09-09T24:00:00Z",               // hour 24
            "2026-09-09T10:60:00Z",               // minute 60
            "2026-09-09T10:00:61Z",               // second 61
            "2026-09-09T10:00:00:00Z",            // a fourth clock component
            "2026-09-09T10Z",                     // no minutes
            "2026-09-09T1x:00:00Z",               // non-numeric clock
            "2026-09-09T10:00:00.Z",              // empty fraction
            "2026-09-09T10:00:00.12x456Z",        // non-numeric fraction
            "2026-09-09T10:00:00+99:00",          // hour offset out of range
            "2026-09-09T10:00:00+00:99",          // minute offset out of range
            "2026-09-09T10:00:00+0",              // truncated offset
            "2026-09-09T10:00:00+ab:cd",          // non-numeric offset
            "2026-9-9T10:00:00Z",                 // unpadded date components
        ]

        for value in malformed {
            #expect(MarkerRevision(wire: value) == nil, "should reject: \(value)")
        }

        #expect(MarkerRevision.make(nil) == nil)
        #expect(MarkerRevision.make("   ") == nil)
    }

    /// The real wire domain still parses, so the tightening did not overreach.
    @Test
    func acceptsTheRealWireDomain() {
        let valid = [
            "2026-09-09T10:00:00Z",
            "2026-09-09T10:00:00+00:00",
            "2026-09-09T10:00:00.353082+00:00",
            "2026-09-09T10:00:00.353082Z",
            "2024-02-29T00:00:00Z",               // a genuine leap day
            "0001-01-01T00:00:00Z",               // datetime.min
            "9999-12-31T23:59:59.999999Z",        // datetime.max
            "2026-09-09T10:00:00",                // no zone: treated as UTC
            "2026-09-09T10:00Z",                  // seconds omitted
        ]
        for value in valid {
            #expect(MarkerRevision(wire: value) != nil, "should accept: \(value)")
        }
    }

    /// The extremes of the domain must not overflow the microsecond arithmetic.
    @Test
    func domainExtremesDoNotOverflow() throws {
        let min = try #require(MarkerRevision(wire: "0001-01-01T00:00:00Z"))
        let max = try #require(MarkerRevision(wire: "9999-12-31T23:59:59.999999Z"))
        #expect(min < max)
        #expect(min.microsecondsSinceEpoch < 0, "before the epoch")
        #expect(max.microsecondsSinceEpoch > 0)
    }

    // MARK: - Reconciler

    /// The failure that would have shipped: a count change carried by a
    /// one-microsecond-newer revision must be applied, not swallowed.
    @Test
    func reconcilerAppliesAOneMicrosecondNewerCount() throws {
        var reconciler = MarkerResponseCountReconciler()
        let first = MarkerResponseCountUpdate(
            markerId: id(1), directResponseCount: 1, revision: MarkerRevision(wire: earlier)
        )
        let second = MarkerResponseCountUpdate(
            markerId: id(1), directResponseCount: 2, revision: MarkerRevision(wire: later)
        )

        #expect(reconciler.apply(first) == .applied(1))
        #expect(
            reconciler.apply(second) == .applied(2),
            "a microsecond-newer revision must advance the count"
        )
        #expect(reconciler.count(for: id(1)) == 2)
    }

    /// And the ordering still holds in the other direction.
    @Test
    func reconcilerRejectsAOneMicrosecondOlderCount() throws {
        var reconciler = MarkerResponseCountReconciler()
        _ = reconciler.apply(
            .init(markerId: id(1), directResponseCount: 5, revision: MarkerRevision(wire: later))
        )
        #expect(
            reconciler.apply(
                .init(markerId: id(1), directResponseCount: 4, revision: MarkerRevision(wire: earlier))
            ) == .stale
        )
        #expect(reconciler.count(for: id(1)) == 5)
    }

    // MARK: - Through the real decoders

    /// End to end on the create path: two payloads one microsecond apart, both
    /// decoded by the app's own decoder, must move the parent's count.
    @Test
    func createPayloadsOneMicrosecondApartBothApply() throws {
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: raw)
        }

        func marker(count: Int, revision: String) throws -> RLChartMarkerDTO {
            try decoder.decode(RLChartMarkerDTO.self, from: Data(Self.markerJSON(
                parentCount: count, parentRevision: revision
            ).utf8))
        }

        var reconciler = MarkerResponseCountReconciler()
        let firstUpdate = try #require(marker(count: 1, revision: earlier).parentCountUpdate)
        let secondUpdate = try #require(marker(count: 2, revision: later).parentCountUpdate)

        // The revisions survived the decoder with their precision intact.
        #expect(firstUpdate.revision != secondUpdate.revision)

        #expect(reconciler.apply(firstUpdate) == .applied(1))
        #expect(reconciler.apply(secondUpdate) == .applied(2))
    }

    /// The same through the websocket envelope, which is a different decoder.
    @Test
    func websocketPayloadsOneMicrosecondApartBothApply() throws {
        func envelope(count: Int, revision: String) throws -> RLChartMarkerDTO {
            let json = """
            {"type":"marker_created","channel":"guild:x:markers","payload":\
            \(Self.markerJSON(parentCount: count, parentRevision: revision))}
            """
            let message = try JSONDecoder().decode(WSIncomingMessage.self, from: Data(json.utf8))
            return try #require(message.payload(as: RLChartMarkerDTO.self))
        }

        var reconciler = MarkerResponseCountReconciler()
        let first = try #require(envelope(count: 3, revision: earlier).parentCountUpdate)
        let second = try #require(envelope(count: 4, revision: later).parentCountUpdate)

        #expect(first.revision != second.revision, "the WS decoder must not round these together")
        #expect(reconciler.apply(first) == .applied(3))
        #expect(reconciler.apply(second) == .applied(4))
    }

    /// A locally patched marker carries the server's own spelling back, so a
    /// later comparison is still exact rather than a re-rendered approximation.
    @Test
    func localPatchPreservesTheServerSpelling() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let marker = try decoder.decode(
            RLChartMarkerDTO.self,
            from: Data(Self.markerJSON(parentCount: 1, parentRevision: earlier, ownRevision: later).utf8)
        )

        let patched = marker.updating(directResponseCount: 9, responsesRevision: later)
        #expect(patched.responsesRevision == later, "the wire spelling round-trips verbatim")
        #expect(patched.responsesRevisionValue == MarkerRevision(wire: later))
        #expect(patched.responseCount == 9)
    }

    // MARK: - Fixture

    private static func markerJSON(
        parentCount: Int,
        parentRevision: String,
        ownRevision: String? = nil
    ) -> String {
        """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "symbol_id": "22222222-2222-2222-2222-222222222222",
          "guild_id": "33333333-3333-3333-3333-333333333333",
          "author": {
            "membership_id": "55555555-5555-5555-5555-555555555555",
            "role": "member", "reputation": 0, "contribution_score": 0,
            "date_joined": "2026-01-01T00:00:00Z",
            "user_id": "44444444-4444-4444-4444-444444444444",
            "username": "alex", "display_name": "Alex",
            "is_online": false, "global_reputation": 0,
            "is_friend": false, "is_blocked": false, "is_blocked_by": false
          },
          "candle_timestamp": "2026-09-01T12:00:00Z",
          "timeframe": "1h", "price": 64000.0,
          "intent": "analysis", "visibility": "guild",
          "tracking_enabled": false,
          "created_at": "2026-09-01T12:00:00Z",
          "created_at_formatted": "just now",
          "is_visible": true,
          "like_count": 0, "is_liked_by_current_user": false,
          "comment_count": 0, "comments": [],
          "is_current_user_marker": false, "can_edit": false, "can_delete": false,
          "components": [],
          "parent_marker_id": "99999999-9999-9999-9999-999999999999",
          "link_relationship": "supports",
          "direct_response_count": 0,
          \(ownRevision.map { "\"responses_revision\": \"\($0)\"," } ?? "")
          "parent_direct_response_count": \(parentCount),
          "parent_responses_revision": "\(parentRevision)"
        }
        """
    }
}
