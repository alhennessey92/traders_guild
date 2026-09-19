import Foundation
import Testing
@testable import traders_guild

/// `MarkerManager.linkBridges` — how a loaded marker whose parent was deleted
/// finds the ancestor it is still linked to.
///
/// The server's tombstone preview carries no grandparent id, but the thesis
/// window lists the tombstone with its `parentKey`, so the chain is walked
/// there: through unavailable nodes only, to the first node whose marker is
/// loaded on this chart.
@MainActor
struct MarkerLinkBridgeTests {

    private let guildId = UUID()
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

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

    private func marker(_ n: Int, parent: Int? = nil, grandparentInPreview: Int? = nil) -> ChartMarkerUI {
        let preview: RLMarkerLinkPreviewDTO? = parent.map { p in
            RLMarkerLinkPreviewDTO(
                nodeKey: "k\(p)", parentKey: grandparentInPreview.map { "k\($0)" },
                markerId: nil, parentMarkerId: grandparentInPreview.map(id),
                linkRelationship: nil, isUnavailable: true
            )
        }
        let dto = RLChartMarkerDTO(
            id: id(n), symbolId: symbolId, guildId: guildId, author: member(1),
            candleTimestamp: t0, timeframe: "1h", price: 1,
            intent: "analysis", title: "M\(n)", note: nil, visibility: "guild",
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: t0, createdAtFormatted: "now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent.map(id), linkRelationship: parent == nil ? nil : "supports",
            parentPreview: preview
        )
        return ChartMarkerUI(marker: dto, candleIndex: 0)
    }

    /// A thesis node as the window holds it. `marker: nil` is a tombstone.
    private func node(_ key: Int, parent: Int? = nil, marker: Int?) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: "k\(key)", parentKey: parent.map { "k\($0)" },
            markerId: marker.map(id), linkRelationship: key == 1 ? nil : "supports",
            isUnavailable: marker == nil, guildId: guildId, symbolId: symbolId,
            ticker: "BTC/USD", timeframe: "1h", candleTimestamp: t0, price: 1
        )
    }

    /// The manager holds its store weakly — the session owns it — so a test
    /// must keep the store alive itself, or the window silently vanishes.
    private func manager(
        markers: [ChartMarkerUI], window nodes: [RLMarkerLinkPreviewDTO], requested: Int
    ) -> (MarkerManager, MarkerThreadStore) {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.markers = markers
        let store = MarkerThreadStore()
        store.activate(accountId: me.userId, guildId: guildId)
        _ = store.ingest(
            page: RLMarkerThreadResponseDTO(
                requestedMarkerId: id(requested), rootMarkerId: id(1), rootKey: "k1", rootResolved: true,
                windowRootKey: "k1", nodes: nodes, ancestorCursor: nil, branches: [],
                totalCount: nodes.count, loadedCount: nodes.count, truncated: false
            ),
            requestedMarkerId: id(requested),
            expectedGeneration: store.generation
        )
        manager.threadStore = store
        return (manager, store)
    }

    @Test
    func aDeletedMiddleMarkerBridgesTheGrandchildToTheRoot() {
        // 1 (root, loaded) ← 2 (deleted) ← 3 (loaded)
        let (manager, store) = manager(
            markers: [marker(1), marker(3, parent: 2)],
            window: [node(1, marker: 1), node(2, parent: 1, marker: nil), node(3, parent: 2, marker: 3)],
            requested: 3
        )
        withExtendedLifetime(store) {
            #expect(manager.linkBridges == [MarkerLinkBridge(childId: id(3), ancestorId: id(1))])
            #expect(manager.linkGraph.loadedParent(of: id(3))?.id == id(1))
            #expect(manager.linkGraph.allEdges.first?.viaUnavailable == true)
        }
    }

    @Test
    func twoDeletedGenerationsAreSteppedOver() {
        // 1 ← 2 (deleted) ← 4 (deleted) ← 5 (loaded)
        let (manager, store) = manager(
            markers: [marker(1), marker(5, parent: 4)],
            window: [
                node(1, marker: 1), node(2, parent: 1, marker: nil),
                node(4, parent: 2, marker: nil), node(5, parent: 4, marker: 5),
            ],
            requested: 5
        )
        withExtendedLifetime(store) {
            #expect(manager.linkBridges == [MarkerLinkBridge(childId: id(5), ancestorId: id(1))])
        }
    }

    /// A middle marker that is merely on another timeframe is not stepped
    /// over: the response answers it, and the badge is how you reach it.
    @Test
    func aLiveAncestorOnAnotherTimeframeStopsTheChain() {
        // 1 (loaded) ← 2 (live, not on this chart) ← 3 (loaded)
        let (manager, store) = manager(
            markers: [marker(1), marker(3, parent: 2)],
            window: [node(1, marker: 1), node(2, parent: 1, marker: 2), node(3, parent: 2, marker: 3)],
            requested: 3
        )
        withExtendedLifetime(store) {
            #expect(manager.linkBridges.isEmpty)
            #expect(manager.linkGraph.allEdges.isEmpty)
        }
    }

    @Test
    func noBridgeWithoutAWindowOrWithoutALoadedAncestor() {
        let me = member(1)
        let bare = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        bare.linkedMarkersEnabled = true
        bare.markers = [marker(1), marker(3, parent: 2)]
        #expect(bare.linkBridges.isEmpty, "no store, no window")

        // Window present, but the root is not loaded on this chart.
        let (manager, store) = manager(
            markers: [marker(3, parent: 2)],
            window: [node(1, marker: 1), node(2, parent: 1, marker: nil), node(3, parent: 2, marker: 3)],
            requested: 3
        )
        withExtendedLifetime(store) {
            #expect(manager.linkBridges.isEmpty)
        }
    }

    /// Should the server ever hydrate a grandparent id on the tombstone, it
    /// is used without a window.
    @Test
    func aHydratedGrandparentIdNeedsNoWindow() {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.markers = [marker(1), marker(3, parent: 2, grandparentInPreview: 1)]
        #expect(manager.threadStore == nil)
        #expect(manager.linkBridges == [MarkerLinkBridge(childId: id(3), ancestorId: id(1))])
    }
}
