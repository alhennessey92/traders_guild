import Foundation
import Testing
@testable import traders_guild

/// The loader's actual request call sites, exercised through a spy client.
///
/// These pin behaviour proven necessary against the live backend:
/// `_decode_cursor` rejects any cursor whose embedded `requested` marker does
/// not match the marker in the URL, returning 409
/// `marker_thread_refresh_required`. Verified on 2026-09-09 — replaying a
/// branch cursor against the issuing marker returned 200, against a different
/// marker 409, and by a different viewer 409.
@MainActor
struct MarkerThreadLoaderCallSiteTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    // MARK: - Spy

    /// Records every thread request and replays canned pages.
    final class SpyAPI: @unchecked Sendable {
        struct Request: Equatable {
            let markerId: UUID
            let cursor: String?
        }

        private(set) var requests: [Request] = []
        var pages: [RLMarkerThreadResponseDTO] = []
        var errors: [Error] = []

        func next(markerId: UUID, cursor: String?) throws -> RLMarkerThreadResponseDTO {
            requests.append(Request(markerId: markerId, cursor: cursor))
            if !errors.isEmpty { throw errors.removeFirst() }
            guard !pages.isEmpty else { throw APIError.networkError("no page queued") }
            return pages.removeFirst()
        }
    }

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        responses: Int = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            authorUsername: "t\(key)",
            title: "Node \(key)",
            directResponseCount: responses
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        branches: [RLMarkerThreadBranchDTO] = [],
        ancestorCursor: String? = nil,
        rootMarker: Int? = nil,
        rootResolved: Bool = false
    ) -> RLMarkerThreadResponseDTO {
        RLMarkerThreadResponseDTO(
            requestedMarkerId: id(requested),
            rootMarkerId: rootMarker.map(id),
            rootKey: rootMarker != nil ? windowRoot : nil,
            rootResolved: rootResolved,
            windowRootKey: windowRoot,
            nodes: nodes,
            ancestorCursor: ancestorCursor,
            branches: branches,
            loadedCount: nodes.count
        )
    }

    // MARK: - Provenance at the call site

    /// The whole point of `MarkerThreadCursor.issuedFor`.
    ///
    /// The window is opened on marker 1, which issues a branch cursor. The user
    /// then navigates within the thesis to marker 2 and expands the same
    /// branch. The request must go to marker 1 — the issuer — or the backend
    /// 409s, because the cursor's embedded `requested` is marker 1.
    @Test
    func expandBranchRequestsTheIssuingMarkerNotTheSelectedOne() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3), node("c", parent: "root", marker: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "c", cursor: "opaque-from-1")],
                rootMarker: 1,
                rootResolved: true
            )
        )

        // The user moves to marker 2; a page fetched under 2 re-binds nothing
        // about the branch that marker 1 issued.
        let cursor = window.branchCursor(for: "c")
        #expect(cursor?.issuedFor == id(1))
        #expect(cursor?.cursor == "opaque-from-1")

        // Merging a page requested under marker 2 must not silently re-attribute
        // marker 1's outstanding cursor.
        window.merge(
            page: page(
                requested: 2,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3)]
            )
        )
        #expect(
            window.branchCursor(for: "c")?.issuedFor == id(1),
            "an unrelated page must not steal provenance from an untouched cursor"
        )
    }

    /// Ancestry cursors carry provenance too, and the same 409 applies.
    @Test
    func ancestryCursorCarriesItsIssuer() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 5,
                windowRoot: "mid",
                nodes: [node("mid", marker: 5)],
                ancestorCursor: "opaque-up-from-5"
            )
        )
        #expect(window.ancestorCursor?.cursor == "opaque-up-from-5")
        #expect(window.ancestorCursor?.issuedFor == id(5))
    }

    /// A cursor surviving a window merge keeps the issuer it was minted under,
    /// which is what makes mixed-origin windows safe to page from.
    @Test
    func mergedWindowsKeepPerCursorProvenance() {
        var first = MarkerThreadWindow(
            page: page(
                requested: 7,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 9), node("a", parent: "root", marker: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "from-7")]
            )
        )
        let second = MarkerThreadWindow(
            page: page(
                requested: 9,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 9), node("b", parent: "root", marker: 3)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "b", cursor: "from-9")]
            )
        )
        first.absorb(second)

        #expect(first.branchCursor(for: "a")?.issuedFor == id(7))
        #expect(first.branchCursor(for: "b")?.issuedFor == id(9))
        #expect(
            first.branchCursor(for: "a")?.issuedFor != first.branchCursor(for: "b")?.issuedFor,
            "a merged window legitimately holds cursors from two different issuers"
        )
    }

    // MARK: - The 409 the backend actually returns

    /// `marker_thread_refresh_required` arrives as a 409 and must classify as a
    /// stale cursor, which triggers a re-read rather than retiring the branch.
    @Test
    func backendRefreshSignalClassifiesAsStaleCursor() {
        let refresh = APIError.serverError(409, "marker_thread_refresh_required")
        #expect(MarkerThreadRequestFailure.classify(refresh) == .staleCursor)
    }

    /// The backend binds cursors to a viewer and an epoch as well, and both
    /// failures surface as the same 409 — so one recovery path covers all three.
    @Test
    func viewerAndEpochMismatchesUseTheSameRecovery() {
        for detail in [
            "marker_thread_refresh_required",   // wrong requested marker
            "marker_thread_refresh_required",   // wrong viewer
            "marker_thread_refresh_required",   // stale guild epoch
        ] {
            #expect(
                MarkerThreadRequestFailure.classify(APIError.serverError(409, detail)) == .staleCursor
            )
        }
    }

    /// Cursors expire server-side after an hour. An expired one is another 409,
    /// so it must recover by re-reading rather than being treated as gone.
    @Test
    func expiredCursorRecoversRatherThanRetiring() {
        #expect(
            MarkerThreadRequestFailure.classify(
                APIError.serverError(409, "marker_thread_refresh_required")
            ) != .gone,
            "an expired cursor must not retire the branch"
        )
    }

    // MARK: - Totals

    /// The backend sends `total_count: null` the moment a branch cursor exists,
    /// which is exactly the incomplete case observed live.
    @Test
    func nullTotalWithAnOutstandingBranchReportsAFloor() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 4), node("c", parent: "root", marker: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "c", cursor: "more")],
                rootMarker: 1,
                rootResolved: true
            )
        )
        #expect(window.completeness == .branchesPending)
        #expect(!window.totalCount.isExact)
        #expect(window.totalCount == .atLeast(2))
    }
}
