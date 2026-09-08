//
//  MarkerThesisDisclosure.swift
//  traders_guild
//
//  The "Thesis" section in marker details: a lazily-loaded, progressively
//  expandable view of the thread a marker belongs to.
//

import SwiftUI

/// Fetches and merges thread pages for one marker.
///
/// Owns exactly one in-flight request. Changing the marker cancels the previous
/// one, so a slow page for a marker the user has already left can never land on
/// top of the current thesis.
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

    private var markerId: UUID?
    private var task: Task<Void, Never>?
    /// Store generation this loader's content belongs to.
    private var generation: Int = -1

    deinit { task?.cancel() }

    /// Load the initial window, reusing anything the store already holds.
    func load(
        markerId: UUID,
        manager: MarkerManager,
        store: MarkerThreadStore,
        force: Bool = false
    ) {
        if self.markerId != markerId {
            task?.cancel()
            task = nil
            rows = []
            window = nil
            state = .idle
            expandingNodeKeys.removeAll()
            isLoadingAncestry = false
        }
        self.markerId = markerId

        // A cached window from another timeframe — or another marker in the
        // same thesis — is immediately usable.
        if !force, store.generation == generation, let cached = store.window(forMarkerId: markerId) {
            adopt(cached)
            return
        }
        if !force, let cached = store.window(forMarkerId: markerId) {
            generation = store.generation
            adopt(cached)
            return
        }

        guard state != .loading else { return }
        state = .loading
        let requestGeneration = store.generation
        generation = requestGeneration

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: nil)
                guard !Task.isCancelled else { return }
                // The store may have been invalidated while we waited.
                guard store.generation == requestGeneration else { return }
                guard self.markerId == markerId else { return }
                store.ingest(page: page, requestedMarkerId: markerId)
                if let merged = store.window(forMarkerId: markerId) {
                    self.adopt(merged)
                }
            } catch is MarkerLinkUnavailableError {
                guard !Task.isCancelled, self.markerId == markerId else { return }
                self.state = .unavailable
            } catch {
                guard !Task.isCancelled, self.markerId == markerId else { return }
                self.state = .failed("Couldn't load this thesis.")
            }
        }
    }

    /// Page more responses under one structural node.
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

        Task { [weak self] in
            guard let self else { return }
            defer { self.expandingNodeKeys.remove(nodeKey) }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: cursor)
                guard !Task.isCancelled, store.generation == requestGeneration else { return }
                store.ingest(page: page, requestedMarkerId: markerId)
                if let merged = store.window(forMarkerId: markerId) {
                    self.adopt(merged)
                }
            } catch {
                // Stop offering a branch we cannot page, rather than leaving a
                // button that fails every time it is pressed.
                store.markBranchExhausted(markerId: markerId, nodeKey: nodeKey)
                if let merged = store.window(forMarkerId: markerId) {
                    self.adopt(merged)
                }
            }
        }
    }

    /// Walk further up toward the root.
    func loadMoreAncestry(manager: MarkerManager, store: MarkerThreadStore) {
        guard let markerId,
              let cursor = window?.ancestorCursor,
              !isLoadingAncestry else { return }

        isLoadingAncestry = true
        let requestGeneration = store.generation

        Task { [weak self] in
            guard let self else { return }
            defer { self.isLoadingAncestry = false }
            do {
                let page = try await manager.fetchThreadPage(markerId: markerId, cursor: cursor)
                guard !Task.isCancelled, store.generation == requestGeneration else { return }
                store.ingest(page: page, requestedMarkerId: markerId)
                if let merged = store.window(forMarkerId: markerId) {
                    self.adopt(merged)
                }
            } catch {
                self.state = .failed("Couldn't load earlier responses.")
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
                        Text("Load earlier responses")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(AppColors.accentColor)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            ForEach(loader.rows) { row in
                MarkerThreadRowView(row: row) {
                    onOpenMarker?(row.node)
                }

                if row.hasMoreResponses {
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
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text("More responses")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(AppColors.accentColor)
                        .padding(.leading, CGFloat(min(row.depth, 2)) * 14 + 34)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
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
