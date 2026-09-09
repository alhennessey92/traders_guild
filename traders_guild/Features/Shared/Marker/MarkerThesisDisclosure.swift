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
                guard !Task.isCancelled, self.markerId == markerId else { return }
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
                guard !Task.isCancelled, self.markerId == markerId else { return }
                switch MarkerThreadRequestFailure.classify(error) {
                case .unavailable:
                    self.state = .unavailable
                default:
                    self.state = .failed("Couldn't load this thesis.")
                }
            }
        }
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
            defer { self.expandingNodeKeys.remove(nodeKey) }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: cursor)
                // Identity as well as generation: a page for a marker the user
                // has already left must never mutate the current selection.
                guard !Task.isCancelled, self.markerId == markerId else { return }
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
                guard !Task.isCancelled, self.markerId == markerId else { return }
                self.handleBranchFailure(
                    error,
                    nodeKey: nodeKey,
                    markerId: markerId,
                    manager: manager,
                    store: store,
                    requestGeneration: requestGeneration
                )
            }
        }
        branchTasks[nodeKey] = task
    }

    private func handleBranchFailure(
        _ error: Error,
        nodeKey: String,
        markerId: UUID,
        manager: MarkerManager,
        store: MarkerThreadStore,
        requestGeneration: Int
    ) {
        switch MarkerThreadRequestFailure.classify(error) {
        case .staleCursor:
            // The cursor no longer addresses anything. Drop it first, then
            // re-read the thread: a fresh initial page restores the cursor if
            // the branch is still live, and leaves it absent if the branch is
            // now exhausted. Keeping the dead cursor would leave a "More
            // responses" button that can never succeed, since an initial page
            // spends no cursor and so cannot retire one.
            store.markBranchExhausted(markerId: markerId, nodeKey: nodeKey)
            branchFailures[nodeKey] = "That moved — reloading."
            load(markerId: markerId, manager: manager, store: store, force: true)

        case .gone:
            // The branch really is unreachable; stop offering a button that
            // can only ever fail.
            store.markBranchExhausted(markerId: markerId, nodeKey: nodeKey)
            if let merged = store.window(forMarkerId: markerId) {
                adopt(merged)
            }

        case .unavailable:
            branchFailures[nodeKey] = "Not available right now."

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
            defer { self.isLoadingAncestry = false }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: cursor)
                guard !Task.isCancelled, self.markerId == markerId else { return }
                let key = store.ingest(
                    page: page,
                    requestedMarkerId: markerId,
                    expectedGeneration: requestGeneration
                )
                guard key != nil, let merged = store.window(forMarkerId: markerId) else { return }
                self.adopt(merged)
                self.ancestryFailure = nil
            } catch {
                guard !Task.isCancelled, self.markerId == markerId else { return }
                // The ancestor cursor is untouched, so this stays retryable.
                self.ancestryFailure = "Couldn't load earlier responses."
            }
        }
    }

    private func adopt(_ merged: MarkerThreadWindow) {
        window = merged
        rows = merged.displayRows()
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
                    message("Linked markers aren't available yet.")
                case .failed(let text):
                    message(text)
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
        .onChange(of: marker.id) { _, newId in
            // Moving within the same thesis keeps the disclosure open; leaving
            // it collapses back to the default.
            isExpanded = store.isExpanded(forMarkerId: newId)
            if isExpanded { loader.load(markerId: newId, manager: markerManager, store: store) }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            store.setExpanded(isExpanded, forMarkerId: marker.id)
            if isExpanded {
                loader.load(markerId: marker.id, manager: markerManager, store: store)
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
                    Text(tallyText ?? headerCountText)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.greyText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thesis, \(tallyText ?? headerCountText)")
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

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
