//
//  MarkerCanvasSymbols.swift
//  traders_guild
//
//  The views the marker Canvas resolves by tag: intent glyphs and author avatars.
//

import Combine
import SwiftUI

/// One author's face, registered once for every marker they placed.
struct MarkerAvatarSymbolEntry: Identifiable, Equatable {
    let authorId: UUID
    let identity: MarkerAvatarIdentity

    var id: UUID { authorId }
    var tag: String { MarkerVisualSpec.avatarSymbolTag(authorId: authorId.uuidString) }
}

/// Symbol content for any Canvas that calls `ChartMarkerSystem.drawMarkers`.
///
/// Shared by the chart and the fixture gallery, so the gallery draws with the
/// same resolved symbols the chart does rather than the monochrome fallback.
enum MarkerCanvasSymbols {

    /// Every intent glyph, plus one avatar per author in `avatars`.
    @ViewBuilder
    static func content(avatars: [MarkerAvatarSymbolEntry]) -> some View {
        ForEach(MarkerVisualSpec.allSymbolIDs, id: \.tag) { symbolId in
            intentSymbol(for: symbolId).tag(symbolId.tag)
        }
        ForEach(avatars) { entry in
            avatarSymbol(identity: entry.identity).tag(entry.tag)
        }
    }

    @ViewBuilder
    static func intentSymbol(for symbolId: MarkerSymbolID) -> some View {
        let symbol = MarkerVisualSpec.symbol(for: symbolId.intent, severity: symbolId.alertSeverity)
        let palette = MarkerVisualSpec.palette(for: symbolId.intent, severity: symbolId.alertSeverity)
        let diameter = symbolId.isSelected
            ? MarkerVisualSpec.baseCanvasDiameter * MarkerVisualSpec.selectedScale
            : MarkerVisualSpec.baseCanvasDiameter
        let iconSize = MarkerVisualSpec.iconSize(for: diameter, intent: symbolId.intent)

        if palette.count >= 3 {
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(palette[0], palette[1], palette[2])
        } else if palette.count == 2 {
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(palette[0], palette[1])
        } else {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(palette.first ?? MarkerVisualSpec.iconBaseColor)
        }
    }

    /// Rendered at selected resolution; the renderer scales it down to the disc.
    @ViewBuilder
    static func avatarSymbol(identity: MarkerAvatarIdentity) -> some View {
        let diameter = MarkerAvatarLayout.symbolAvatarDiameter

        if let urlString = identity.url, !urlString.isEmpty, let url = URL(string: urlString) {
            CachedAvatarImage(url: url, size: diameter, initials: identity.initials ?? "")
        } else if MarkerAvatarExperiment.isEnabled {
            // Prototype: an opaque disc that reads in every theme.
            Circle()
                .fill(MarkerAvatarInitialsStyle.fill)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Text(identity.initials ?? "")
                        .font(.system(size: diameter * 0.38, weight: .bold))
                        .foregroundColor(MarkerAvatarInitialsStyle.text)
                )
        } else {
            // Same initials fallback as every other avatar surface, tinted to
            // the personal marker's own palette.
            Circle()
                .fill(RLMarkerIntent.personal.color.opacity(0.30))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Text(identity.initials ?? "")
                        .font(.system(size: diameter * 0.38, weight: .bold))
                        .foregroundColor(
                            MarkerVisualSpec.iconPrimaryColor(for: .personal, severity: nil)
                        )
                )
        }
    }
}

/// The avatar symbols a marker Canvas needs, worked out when markers or the
/// avatar directory change — never per frame.
///
/// The Canvas's `symbols:` builder runs whenever its view body does, which is
/// every pan frame. It reads `entries` and nothing else; the dedupe, directory
/// resolution and prefetch happen here, off that path.
///
/// Historical marker snapshots are read, never written back: a marker's
/// author is a snapshot from when it was fetched, and feeding it into the
/// directory would let an old picture overwrite a newer one or undo a removal.
@MainActor
final class MarkerAvatarSymbolStore: ObservableObject {
    @Published private(set) var entries: [MarkerAvatarSymbolEntry] = []

    /// Which intents wear a face. Changing it re-derives the authors.
    var avatarIntents: Set<RLMarkerIntent> {
        didSet {
            guard avatarIntents != oldValue else { return }
            update(markers: lastMarkers)
        }
    }

    private let prefetch: ([String]) -> Void
    private var lastMarkers: [ChartMarkerUI] = []
    private var authors: [UUID: (author: RLGuildMemberDTO, createdAt: Date)] = [:]
    private var directory: [UUID: String] = [:]
    private var prefetchedURLs: Set<String> = []
    private var directoryCancellable: AnyCancellable?

    init(
        avatarIntents: Set<RLMarkerIntent>,
        directory: AnyPublisher<[UUID: String], Never>? = nil,
        prefetch: (([String]) -> Void)? = nil
    ) {
        self.avatarIntents = avatarIntents
        self.prefetch = prefetch ?? { AvatarImageCache.shared.prefetch(urlStrings: $0) }
        // Delivered synchronously: the directory is main-actor state and
        // publishes on the main thread, so the first value lands during init.
        let source = directory ?? MemberAvatarDirectory.shared.$avatarByUserId.eraseToAnyPublisher()
        directoryCancellable = source
            .sink { [weak self] avatars in
                MainActor.assumeIsolated {
                    guard let self, self.directory != avatars else { return }
                    self.directory = avatars
                    self.rebuild()
                }
            }
    }

    /// Record the authors of `markers` that wear a face.
    ///
    /// Where one author placed several markers, the newest marker's snapshot is
    /// the fallback — it is the least likely to be stale.
    func update(markers: [ChartMarkerUI]) {
        lastMarkers = markers
        var next: [UUID: (author: RLGuildMemberDTO, createdAt: Date)] = [:]
        for marker in markers where avatarIntents.contains(marker.intent) {
            let authorId = marker.author.userId
            if let existing = next[authorId], existing.createdAt >= marker.createdAt { continue }
            next[authorId] = (marker.author, marker.createdAt)
        }
        let changed = next.count != authors.count || next.contains { key, value in
            guard let old = authors[key] else { return true }
            return old.author.avatarUrl != value.author.avatarUrl
                || old.author.username != value.author.username
        }
        authors = next
        if changed { rebuild() }
    }

    private func rebuild() {
        let next = authors
            .map { authorId, entry in
                MarkerAvatarSymbolEntry(
                    authorId: authorId,
                    identity: MarkerAvatarIdentity.forAuthor(entry.author, directory: directory)
                )
            }
            .filter { !$0.identity.isEmpty }
            .sorted { $0.authorId.uuidString < $1.authorId.uuidString }

        if next != entries { entries = next }

        let newURLs = Set(next.compactMap(\.identity.url)).subtracting(prefetchedURLs)
        if !newURLs.isEmpty {
            prefetchedURLs.formUnion(newURLs)
            prefetch(newURLs.sorted())
        }
    }
}
