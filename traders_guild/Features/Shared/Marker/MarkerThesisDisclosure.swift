//
//  MarkerThesisDisclosure.swift
//  traders_guild
//
//  The "Thesis" section in marker details: a lazily-loaded, progressively
//  expandable view of the thread a marker belongs to.
//

import SwiftUI

/// How a thread request failed, and therefore what to do with the cursor.
///
/// The distinction matters: retiring a branch cursor on a transient failure
/// silently loses every remaining response under that node, with no way back.
enum MarkerThreadRequestFailure: Equatable {
    /// Offline, timeout, 5xx, rate limited — keep the cursor, allow a retry.
    case transient
    /// The cursor no longer addresses anything (409). Re-read the thread.
    case staleCursor
    /// The node or thread is gone for good (404/410). Retire the cursor.
    case gone
    /// The capability is switched off server-side (503).
    case unavailable

    static func classify(_ error: Error) -> MarkerThreadRequestFailure {
        if error is MarkerLinkUnavailableError { return .unavailable }

        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let status, let detail):
                if status == 503 || detail.contains(MarkerLinkUnavailableError.detail) {
                    return .unavailable
                }
                switch status {
                case 409: return .staleCursor
                case 404, 410: return .gone
                // 5xx, 429 and anything else are worth another attempt, so the
                // cursor must survive them.
                default: return .transient
                }
            case .badRequest(let detail):
                // A cursor the server no longer recognises comes back as a bad
                // request on some paths; re-reading the thread recovers it.
                return detail.localizedCaseInsensitiveContains("cursor") ? .staleCursor : .transient
            default:
                return .transient
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .transient }
        return .transient
    }
}

/// Fetches and merges thread pages for one marker.
///
/// Every request is tracked and cancelled when the marker changes, and every
/// completion re-checks both the marker identity and the store generation, so a
/// slow page or a late error can never mutate a selection the user has moved on
/// from.
@MainActor
final class MarkerThreadLoader: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var rows: [MarkerThreadRow] = []
    @Published private(set) var window: MarkerThreadWindow?
    /// Branch node keys with a page currently in flight.
    @Published private(set) var expandingNodeKeys: Set<String> = []
    @Published private(set) var isLoadingAncestry = false
    /// Per-branch retry messages. A branch with a message here still has its
    /// cursor, so the button remains live.
    @Published private(set) var branchFailures: [String: String] = [:]
    @Published private(set) var ancestryFailure: String?

    private var markerId: UUID?
    private var task: Task<Void, Never>?
    private var branchTasks: [String: Task<Void, Never>] = [:]
    private var ancestryTask: Task<Void, Never>?
    /// Store generation this loader's content belongs to.
    private var generation: Int = -1

    deinit {
        task?.cancel()
        ancestryTask?.cancel()
        for task in branchTasks.values { task.cancel() }
    }

    /// Cancel everything in flight. Called when the marker changes so no
    /// continuation can land on the wrong thesis.
    private func cancelAllRequests() {
        task?.cancel()
        task = nil
        ancestryTask?.cancel()
        ancestryTask = nil
        for task in branchTasks.values { task.cancel() }
        branchTasks.removeAll()
    }

    /// Load the initial window, reusing anything the store already holds.
    func load(
        markerId: UUID,
        manager: MarkerManager,
        store: MarkerThreadStore,
        force: Bool = false
    ) {
        if self.markerId != markerId {
            cancelAllRequests()
            rows = []
            window = nil
            state = .idle
            expandingNodeKeys.removeAll()
            isLoadingAncestry = false
            branchFailures.removeAll()
            ancestryFailure = nil
        }
        self.markerId = markerId

        // A cached window is immediately usable — the same thesis reached from
        // another marker, or the same marker after a timeframe change — but
        // only while it belongs to the current generation. A window from an
        // older generation was invalidated and must be re-read.
        if !force, store.generation == generation, let cached = store.window(forMarkerId: markerId) {
            adopt(cached)
            return
        }

        guard state != .loading else { return }
        state = .loading
        let requestGeneration = store.generation
        generation = requestGeneration

        cancelAllRequests()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: nil)
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                // The store refuses a page from a superseded generation, so an
                // invalidation that landed while this was in flight wins.
                let key = store.ingest(
                    page: page,
                    requestedMarkerId: markerId,
                    expectedGeneration: requestGeneration
                )
                guard key != nil, let merged = store.window(forMarkerId: markerId) else {
                    self.state = .idle
                    return
                }
                self.adopt(merged)
            } catch {
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                switch MarkerThreadRequestFailure.classify(error) {
                case .unavailable:
                    self.state = .unavailable
                default:
                    // Retriable, including an initial 409: the disclosure offers
                    // a Retry action for this state.
                    self.state = .failed("Couldn't load this thesis.")
                }
            }
        }
    }

    /// Re-read a thesis because the viewer explicitly asked to see it again.
    ///
    /// A reopen is not a walk. Walking inside an already-open thesis should
    /// reuse the cache — that is what makes tapping through a thesis feel
    /// instant. But reopening is the moment the viewer expects current truth,
    /// and the cached fast path in `load` returns without going near the
    /// server, so a node hidden since the last read would still be on screen.
    ///
    /// Forcing the request alone is not enough either: the fresh first page is
    /// merged into whatever window is retained, and a merge can only add or
    /// update nodes — it can never remove one that has become invisible and
    /// happens to fall outside that page. So the window is discarded first and
    /// rebuilt from the response.
    ///
    /// The current selection survives by construction: the request is anchored
    /// on `markerId`, and a thread response always contains the marker it was
    /// requested for, so the row the viewer is reading is in the fresh page or
    /// the thesis is genuinely no longer visible to them.
    func reopen(markerId: UUID, manager: MarkerManager, store: MarkerThreadStore) {
        refreshAuthoritatively(markerId: markerId, manager: manager, store: store)
    }

    /// Throw away the cached topology and rebuild it from a fresh read.
    ///
    /// Shared by an explicit reopen and by structural paging failures, because
    /// both are the same problem: the cached window may no longer describe the
    /// thesis, and merging cannot fix it. `MarkerThreadWindow.insert` only ever
    /// adds or replaces nodes, and the window root only ever moves *up* — so a
    /// merge can raise a root but never lower one, and never removes an edge.
    ///
    /// That asymmetry is what makes force-loading insufficient. If an ancestor
    /// was hard-deleted and the removal event never reached this viewer, the
    /// branch detaches and the true root moves *down*. A fresh page merged into
    /// the old nodes would keep the deleted ancestor, keep the edge pointing at
    /// it, and render a thesis that no longer exists. Discarding first means the
    /// response defines the topology, which is the only source that knows it.
    ///
    /// Selection is preserved, not nodes: the read is anchored on `markerId`, so
    /// the marker being read about is in the fresh page by construction.
    private func refreshAuthoritatively(
        markerId: UUID,
        manager: MarkerManager,
        store: MarkerThreadStore
    ) {
        cancelAllRequests()
        store.discardWindow(forMarkerId: markerId)
        rows = []
        window = nil
        state = .idle
        expandingNodeKeys.removeAll()
        isLoadingAncestry = false
        branchFailures.removeAll()
        ancestryFailure = nil
        // Belongs to no generation until the fresh page lands, so the cached
        // fast path inside `load` cannot match even within one generation.
        generation = -1
        load(markerId: markerId, manager: manager, store: store, force: true)
    }

    /// Detach from whatever thesis this loader was showing.
    ///
    /// Used when the selection moves to a thesis the disclosure is not open on.
    /// Clearing the rows is not sufficient on its own — the loader would still
    /// be bound to the old `markerId`, so a request already on the wire could
    /// land and repopulate a section the viewer has navigated away from.
    func reset() {
        cancelAllRequests()
        markerId = nil
        rows = []
        window = nil
        state = .idle
        generation = -1
        expandingNodeKeys.removeAll()
        isLoadingAncestry = false
        branchFailures.removeAll()
        ancestryFailure = nil
    }

    /// Drop every row and window this loader is holding.
    ///
    /// Called when the store's generation moves — a block, a report, a
    /// moderation action, a reconnect. Content already on screen was authorised
    /// under the previous generation, so it is cleared immediately rather than
    /// left visible until the next reload.
    func clearForInvalidation() {
        cancelAllRequests()
        rows = []
        window = nil
        state = .idle
        generation = -1
        expandingNodeKeys.removeAll()
        isLoadingAncestry = false
        branchFailures.removeAll()
        ancestryFailure = nil
    }

    // No explicit reset for a capability flip: switching the feature off hides
    // the disclosure entirely, and switching it on re-mounts it, so `onAppear`
    // re-runs `load` — which re-reads because the store's generation has moved
    // past this loader's. A separate reset path would only be a second way to
    // do the same thing.

    /// Page more responses under one structural node.
    ///
    /// A failure here must not cost the reader the rest of the branch. Only a
    /// server saying the cursor is *gone* retires it; anything transient keeps
    /// the cursor so the button can be pressed again, and a stale cursor
    /// re-reads the branch from its anchor.
    func expandBranch(
        nodeKey: String,
        manager: MarkerManager,
        store: MarkerThreadStore
    ) {
        guard let markerId,
              let cursor = window?.branchCursor(for: nodeKey),
              !expandingNodeKeys.contains(nodeKey) else { return }

        expandingNodeKeys.insert(nodeKey)
        let requestGeneration = store.generation

        let task = Task { [weak self] in
            guard let self else { return }
            // Even the cleanup is guarded: a task that outlived its selection
            // or generation must not touch newer loader state on its way out.
            defer {
                if self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) {
                    self.expandingNodeKeys.remove(nodeKey)
                }
            }
            do {
                // Fetched against the marker the cursor was ISSUED for, not the
                // one currently selected. Cursors are encrypted and bound to
                // their issuing `requested_marker_id`, so replaying one against
                // a marker reached by navigating within the thesis 409s.
                let page = try await manager.fetchThreadPage(
                    markerId: cursor.issuedFor,
                    cursor: cursor.cursor
                )
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                // Ingested under the SELECTED marker's identity: provenance
                // governs the fetch, selection governs the cache entry.
                let key = store.ingest(
                    page: page,
                    requestedMarkerId: markerId,
                    expectedGeneration: requestGeneration,
                    consumedBranchKey: nodeKey
                )
                guard key != nil, let merged = store.window(forMarkerId: markerId) else { return }
                self.adopt(merged)
                self.branchFailures[nodeKey] = nil
            } catch {
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                self.handleBranchFailure(
                    error,
                    nodeKey: nodeKey,
                    markerId: markerId,
                    manager: manager,
                    store: store
                )
            }
        }
        branchTasks[nodeKey] = task
    }

    /// True only while this loader still belongs to the marker and generation a
    /// request was issued under.
    ///
    /// Cancellation alone is not enough: a task can complete between the store
    /// being invalidated and the loader being torn down, and a stale *failure*
    /// could otherwise retire a cursor or overwrite a newer loader's state.
    private func isCurrent(markerId: UUID, generation requestGeneration: Int, store: MarkerThreadStore) -> Bool {
        !Task.isCancelled
            && self.markerId == markerId
            && store.generation == requestGeneration
            && self.generation == requestGeneration
    }

    private func handleBranchFailure(
        _ error: Error,
        nodeKey: String,
        markerId: UUID,
        manager: MarkerManager,
        store: MarkerThreadStore
    ) {
        switch MarkerThreadRequestFailure.classify(error) {
        case .staleCursor:
            // The cursor no longer addresses anything, which means the server's
            // idea of this thesis has moved out from under the cached one. The
            // whole window goes, not just the cursor: a structural 409 is
            // exactly the case where the retained topology may be wrong, and a
            // merge could never correct it.
            branchFailures[nodeKey] = "That moved — reloading."
            refreshAuthoritatively(markerId: markerId, manager: manager, store: store)

        case .gone:
            // The issuing marker was hard-deleted while paging. Its children
            // detached and the real root moved down, so the cached parent edges
            // are stale in the one direction a merge cannot repair.
            branchFailures[nodeKey] = nil
            refreshAuthoritatively(markerId: markerId, manager: manager, store: store)

        case .unavailable:
            branchFailures[nodeKey] = "Linked markers are temporarily unavailable."

        case .transient:
            // Cursor deliberately preserved: offline, timeout, 5xx and rate
            // limiting are all retryable, and discarding the cursor would lose
            // every remaining response under this node permanently.
            branchFailures[nodeKey] = "Couldn't load. Tap to retry."
        }
    }

    /// Walk further up toward the root.
    func loadMoreAncestry(manager: MarkerManager, store: MarkerThreadStore) {
        guard let markerId,
              let cursor = window?.ancestorCursor,
              !isLoadingAncestry else { return }

        isLoadingAncestry = true
        let requestGeneration = store.generation

        ancestryTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) {
                    self.isLoadingAncestry = false
                }
            }
            do {
                // Same provenance rule as branches: the ancestry cursor belongs
                // to the marker whose response minted it.
                let page = try await manager.fetchThreadPage(
                    markerId: cursor.issuedFor,
                    cursor: cursor.cursor
                )
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                let key = store.ingest(
                    page: page,
                    requestedMarkerId: markerId,
                    expectedGeneration: requestGeneration
                )
                guard key != nil, let merged = store.window(forMarkerId: markerId) else { return }
                self.adopt(merged)
                self.ancestryFailure = nil
            } catch {
                guard self.isCurrent(markerId: markerId, generation: requestGeneration, store: store) else {
                    return
                }
                // Ancestry needs the same classification as branches: treating
                // every failure as transient left a stale 409 cursor retrying
                // forever against a cursor the server will never accept again.
                switch MarkerThreadRequestFailure.classify(error) {
                case .staleCursor, .gone:
                    // Same reasoning as a branch: an ancestry cursor the server
                    // refuses means the chain above this marker changed, and
                    // that is precisely the change a merge cannot express.
                    self.ancestryFailure = nil
                    self.refreshAuthoritatively(markerId: markerId, manager: manager, store: store)
                case .unavailable:
                    self.ancestryFailure = "Linked markers are temporarily unavailable."
                case .transient:
                    // The cursor is untouched, so this stays retryable.
                    self.ancestryFailure = "Couldn't load earlier responses."
                }
            }
        }
    }

    private func adopt(_ merged: MarkerThreadWindow) {
        window = merged
        // Highlight follows the loader's current marker, not the window's. One
        // window is shared by every marker in a thesis, so a walk that reuses it
        // would otherwise keep pointing at whichever marker opened it.
        rows = merged.displayRows(selectedMarkerId: markerId)
        state = .loaded
    }
}

/// The Thesis section of the marker detail sheet.
struct MarkerThesisDisclosure: View {
    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    @ObservedObject var store: MarkerThreadStore
    @StateObject private var loader = MarkerThreadLoader()
    @State private var isExpanded: Bool = false

    /// Jump to another marker in this thesis.
    var onOpenMarker: ((RLMarkerLinkPreviewDTO) -> Void)?

    private var window: MarkerThreadWindow? { loader.window }

    /// Before the thread loads, the only honest number is the marker's own
    /// direct responses — never presented as a thesis total.
    private var headerCountText: String {
        guard let window else {
            let count = marker.responseCount
            return count == 1 ? "1 direct response" : "\(count) direct responses"
        }
        let total = window.totalCount
        switch total {
        case .exact(let n):
            return n == 1 ? "1 in this thesis" : "\(n) in this thesis"
        case .atLeast(let n):
            return "\(n)+ in this thesis"
        }
    }

    /// Relationship breakdown, shown *beneath* the count rather than instead of
    /// it.
    ///
    /// It tallies only the relationships this build understands, among the
    /// nodes currently loaded, so its sum is a floor and frequently lower than
    /// the thesis total. Presenting it where the total belongs would read as
    /// the size of the thesis and quietly under-report it — worst on exactly
    /// the deep and wide theses where the total matters most.
    private var tallyText: String? {
        guard let window else { return nil }
        let tallies = window.relationshipTallies()
        guard !tallies.isEmpty else { return nil }
        return MarkerLinkRelationship.allCases
            .compactMap { relationship in
                guard let count = tallies[relationship], count > 0 else { return nil }
                return "\(count) \(relationship.verb)"
            }
            .joined(separator: " · ")
    }

    /// One spoken line: the authoritative count first, breakdown after.
    private var headerAccessibilityLabel: String {
        guard let tallyText else { return "Thesis, \(headerCountText)" }
        return "Thesis, \(headerCountText), \(tallyText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                switch loader.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                case .unavailable:
                    message("Linked markers are temporarily unavailable.")
                case .failed(let text):
                    retry(text)
                case .loaded:
                    threadList
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            isExpanded = store.isExpanded(forMarkerId: marker.id)
            if isExpanded { loader.load(markerId: marker.id, manager: markerManager, store: store) }
        }
        .onChange(of: store.generation) { _, _ in
            // Privacy, moderation and reconnect all advance the generation.
            // Anything held here was authorised under the old one, so it goes
            // immediately; if the section is open it re-reads under the new one.
            loader.clearForInvalidation()
            if isExpanded {
                loader.load(markerId: marker.id, manager: markerManager, store: store)
            }
        }
        .onChange(of: marker.id) { _, newId in
            // Moving within the same thesis keeps the disclosure open; leaving
            // it collapses back to the default.
            isExpanded = store.isExpanded(forMarkerId: newId)
            if isExpanded {
                // Still a walk, so the cache is deliberately reused.
                loader.load(markerId: newId, manager: markerManager, store: store)
            } else {
                // Collapsed on the new marker. Without this the loader stays
                // bound to the previous thesis with its requests still in
                // flight, and expanding here later would show that thesis
                // before the new one arrived.
                loader.reset()
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            store.setExpanded(isExpanded, forMarkerId: marker.id)
            if isExpanded {
                // Opening the section is a request for current state, not a
                // walk through one already open, so this re-reads rather than
                // adopting the cache.
                loader.reopen(markerId: marker.id, manager: markerManager, store: store)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thesis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    // Always the count, never displaced by the breakdown.
                    Text(headerCountText)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                    if let tallyText {
                        Text(tallyText)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText.opacity(0.8))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.greyText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerAccessibilityLabel)
        .accessibilityHint(isExpanded ? "Collapses the thesis" : "Expands the thesis")
    }

    @ViewBuilder
    private var threadList: some View {
        VStack(alignment: .leading, spacing: 2) {
            if window?.hasMoreAncestry == true {
                Button {
                    loader.loadMoreAncestry(manager: markerManager, store: store)
                } label: {
                    HStack(spacing: 6) {
                        if loader.isLoadingAncestry {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        // The cursor survives a failure, so the button stays
                        // live and simply says so.
                        Text(loader.ancestryFailure ?? "Load earlier responses")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(
                        loader.ancestryFailure == nil ? AppColors.accentColor : AppColors.statusWarning
                    )
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loader.ancestryFailure ?? "Load earlier responses")
            }

            ForEach(loader.rows) { row in
                MarkerThreadRowView(row: row) {
                    onOpenMarker?(row.node)
                }

                if row.hasMoreResponses {
                    let failure = loader.branchFailures[row.node.nodeKey]
                    Button {
                        loader.expandBranch(
                            nodeKey: row.node.nodeKey,
                            manager: markerManager,
                            store: store
                        )
                    } label: {
                        HStack(spacing: 6) {
                            if loader.expandingNodeKeys.contains(row.node.nodeKey) {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: failure == nil ? "plus.circle" : "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            // A failed branch keeps its cursor, so this stays a
                            // working retry rather than a dead end.
                            Text(failure ?? "More responses")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(failure == nil ? AppColors.accentColor : AppColors.statusWarning)
                        .padding(.leading, CGFloat(min(row.depth, 2)) * 14 + 34)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(failure ?? "More responses")
                }
            }

            // Only ever stated when the server actually vouched for it.
            if let window, window.completeness != .complete {
                Text("Showing part of this thesis")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .padding(.top, 6)
            }
        }
    }

    /// A failed initial load is retriable — including an initial 409, which a
    /// re-read resolves by re-issuing cursors.
    private func retry(_ text: String) -> some View {
        Button {
            loader.load(markerId: marker.id, manager: markerManager, store: store, force: true)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(text) Tap to retry.")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(AppColors.statusWarning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text) Tap to retry.")
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
