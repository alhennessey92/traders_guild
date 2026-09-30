//
//  MarkerAvatarFixtures.swift
//  traders_guild
//
//  Avatar-marker scenes for the marker fixture gallery.
//
//  Deterministic and backend-free: avatar pictures are drawn locally and put
//  straight into `AvatarImageCache` under URLs on a reserved `.invalid` host,
//  so the real `CachedAvatarImage` → Canvas symbol → renderer path shows them
//  without a request ever leaving the device. The one deliberate failure uses
//  a missing `file:` URL, which fails without touching the network either.
//

#if DEBUG || TG_ISOLATED_DEV

import SwiftUI
import UIKit

// MARK: - Local avatar pictures

enum MarkerAvatarFixtureImages {
    static let host = "fixtures.tradersguild.invalid"

    /// Authors drawn as initials: no avatar at all.
    static let initialsOnly: Set<String> = ["noor", "omar", "other1", "other4", "other7", "trader2", "trader5"]

    /// Resolves to nothing, so the load fails and initials show.
    static let failingURL = "file:///tg-fixture/missing-avatar.png"

    /// The fixture avatar for `seed`, drawn and cached on first use.
    static func url(for seed: String) -> String {
        let urlString = "https://\(host)/avatars/\(seed).png"
        if let url = URL(string: urlString), AvatarImageCache.shared.image(for: url) == nil {
            AvatarImageCache.shared.store(image(for: seed), for: url)
        }
        return urlString
    }

    /// The avatar a fixture username gets by default.
    static func defaultURL(forUsername username: String) -> String? {
        guard !username.isEmpty, !initialsOnly.contains(username) else { return nil }
        return url(for: username)
    }

    /// A stylised portrait: background, shoulders, head, hair, all from a
    /// stable hash of `seed` so every run draws the same picture.
    static func image(for seed: String) -> UIImage {
        let hash = stableHash(seed)
        let hue = CGFloat(hash % 360) / 360
        let side: CGFloat = 160
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let cg = ctx.cgContext
            let top = UIColor(hue: hue, saturation: 0.55, brightness: 0.78, alpha: 1)
            let bottom = UIColor(hue: hue, saturation: 0.75, brightness: 0.42, alpha: 1)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: side), options: [])

            let skinTones: [UIColor] = [
                UIColor(red: 0.96, green: 0.80, blue: 0.69, alpha: 1),
                UIColor(red: 0.85, green: 0.65, blue: 0.50, alpha: 1),
                UIColor(red: 0.65, green: 0.45, blue: 0.32, alpha: 1),
                UIColor(red: 0.45, green: 0.30, blue: 0.22, alpha: 1),
            ]
            let skin = skinTones[Int(hash / 7 % UInt64(skinTones.count))]
            let shirt = UIColor(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.45, brightness: 0.85, alpha: 1)
            let hair = UIColor(white: CGFloat(hash / 11 % 4) * 0.12 + 0.08, alpha: 1)

            shirt.setFill()
            UIBezierPath(ovalIn: CGRect(x: 22, y: 112, width: 116, height: 100)).fill()
            skin.setFill()
            UIBezierPath(roundedRect: CGRect(x: 68, y: 92, width: 24, height: 28), cornerRadius: 8).fill()
            UIBezierPath(ovalIn: CGRect(x: 46, y: 34, width: 68, height: 76)).fill()
            hair.setFill()
            let hairPath = UIBezierPath(ovalIn: CGRect(x: 42, y: 26, width: 76, height: 46))
            hairPath.fill()
            UIColor(white: 0.1, alpha: 0.85).setFill()
            UIBezierPath(ovalIn: CGRect(x: 64, y: 70, width: 7, height: 7)).fill()
            UIBezierPath(ovalIn: CGRect(x: 89, y: 70, width: 7, height: 7)).fill()
        }
    }

    /// djb2 over UTF-8 — Swift's own `hashValue` is seeded per process.
    static func stableHash(_ string: String) -> UInt64 {
        string.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
    }
}

// MARK: - Scenes

/// What one gallery case draws, and the avatar directory it assumes.
struct MarkerFixtureScene {
    var markers: [ChartMarkerUI]
    var candles: [RLCandleDTO] = MarkerLinkFixtures.candles()
    var selectedId: UUID? = MarkerLinkFixtures.uuid(1)
    /// Applied to `MemberAvatarDirectory.shared` when the case is shown:
    /// user id → avatar URL, or "" for a removed avatar.
    var directory: [UUID: String] = [:]
    /// Cross-timeframe badges for whichever marker is selected.
    var timeframeJumps: [MarkerTimeframeJump] = []
}

extension MarkerLinkFixtures {
    /// A fixture author: the same name always means the same user.
    struct Author {
        let number: Int
        let username: String
        var avatarUrl: String?

        var userId: UUID { uuid(400 + number) }

        static func named(_ username: String, _ number: Int) -> Author {
            Author(number: number, username: username, avatarUrl: MarkerAvatarFixtureImages.defaultURL(forUsername: username))
        }

        static let alex = named("alex", 1)
        static let sam = named("sam", 2)
        static let jamie = named("jamie", 3)
        static let kit = named("kit", 4)
        static let lee = named("lee", 5)
        static let noor = named("noor", 6)
        static let priya = named("priya", 7)
        static let omar = named("omar", 8)
    }

    static func candle(_ index: Int) -> Date {
        baseCandle.addingTimeInterval(Double(index - leadingCandles) * 3600)
    }

    /// A marker by a fixture author, on candle `index` of the default series.
    static func authored(
        _ n: Int,
        by author: Author,
        intent: RLMarkerIntent,
        candleIndex: Int,
        title: String? = nil,
        note: String? = nil,
        parent: Int? = nil,
        relationship: String? = nil,
        responses: Int = 0,
        likes: Int = 0,
        visibility: String = "guild",
        trackingEnabled: Bool = false,
        trackingState: RLTrackingState? = nil,
        prediction: RLPredictionResultDTO? = nil,
        createdOrder: Int? = nil,
        components: [RLComponentType] = []
    ) -> RLChartMarkerDTO {
        let base = marker(
            n, author: author.username, intent: intent, candle: candle(candleIndex), price: 64_000,
            title: title, parent: parent, relationship: relationship, responses: responses, likes: likes
        )
        return RLChartMarkerDTO(
            id: base.id, symbolId: base.symbolId, guildId: base.guildId,
            author: member(author.number, username: author.username, avatarUrl: author.avatarUrl),
            candleTimestamp: base.candleTimestamp, timeframe: base.timeframe, price: base.price,
            intent: base.intent, title: title, note: note, visibility: visibility,
            confidence: nil, trackingEnabled: trackingEnabled, trackingState: trackingState?.rawValue,
            alertSeverity: nil,
            createdAt: base.candleTimestamp.addingTimeInterval(Double(createdOrder ?? n) * 60),
            createdAtFormatted: base.createdAtFormatted, isVisible: true,
            likeCount: likes, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: false, canEdit: false, canDelete: false,
            components: fixtureComponents(components, marker: n), primaryComponentId: nil,
            pollQuestion: intent == .poll ? title : nil,
            pollOptions: nil, userPollVote: nil, predictionResult: prediction,
            parentMarkerId: base.parentMarkerId, linkRelationship: relationship,
            parentPreview: nil, directResponseCount: responses
        )
    }

    // MARK: Individual intents

    /// Analysis, Question and Setup by one author with a picture, then the same
    /// three by one drawn as initials.
    static func avatarIntents() -> MarkerFixtureScene {
        let dtos = [
            authored(1, by: .alex, intent: .analysis, candleIndex: 4, title: "Higher lows holding",
                     components: [.indicator, .indicator, .drawingTrendline, .timeframeLink]),
            authored(2, by: .alex, intent: .question, candleIndex: 5, title: "Breakout or rejection?", likes: 2),
            authored(3, by: .alex, intent: .setup, candleIndex: 6, title: "Long the retest",
                     trackingEnabled: true, trackingState: .active,
                     components: [.levelEntry, .levelSl, .levelTp, .indicator]),
            authored(4, by: .noor, intent: .analysis, candleIndex: 8, title: "Volume fading"),
            authored(5, by: .noor, intent: .question, candleIndex: 9, title: "Anyone see divergence?", responses: 1),
            authored(6, by: .noor, intent: .setup, candleIndex: 10, title: "Short the sweep"),
        ]
        return MarkerFixtureScene(markers: positioned(dtos))
    }

    /// One author several times, beside several different authors.
    static func repeatedAndDistinctAuthors() -> MarkerFixtureScene {
        let dtos = [
            authored(1, by: .alex, intent: .analysis, candleIndex: 3, title: "First look"),
            authored(2, by: .alex, intent: .setup, candleIndex: 5, title: "Entry"),
            authored(3, by: .alex, intent: .question, candleIndex: 7, title: "Still valid?"),
            authored(4, by: .alex, intent: .analysis, candleIndex: 7, title: "Update", createdOrder: 9),
            authored(5, by: .sam, intent: .analysis, candleIndex: 4, title: "Disagree"),
            authored(6, by: .jamie, intent: .question, candleIndex: 6, title: "Target?"),
            authored(7, by: .kit, intent: .setup, candleIndex: 8, title: "Short"),
            authored(8, by: .omar, intent: .analysis, candleIndex: 9, title: "Range"),
        ]
        return MarkerFixtureScene(markers: positioned(dtos))
    }

    // MARK: Stacks and density

    /// Four on one candle above, three on another below.
    static func sameCandleStacks() -> MarkerFixtureScene {
        var laid = positioned([
            authored(1, by: .alex, intent: .analysis, candleIndex: 5, title: "A", likes: 3),
            authored(2, by: .sam, intent: .question, candleIndex: 5, title: "B", responses: 2),
            authored(3, by: .noor, intent: .setup, candleIndex: 5, title: "C"),
            authored(4, by: .priya, intent: .analysis, candleIndex: 5, title: "D", likes: 1),
            authored(5, by: .jamie, intent: .setup, candleIndex: 8, title: "E"),
            authored(6, by: .kit, intent: .analysis, candleIndex: 8, title: "F", likes: 5),
            authored(7, by: .omar, intent: .question, candleIndex: 8, title: "G"),
        ])
        for index in laid.indices where laid[index].candleIndex == 8 {
            laid[index].positionedBelow = true
        }
        // Selects a marker with no responses: a declared-but-unloaded thesis
        // would put the stack into focus and fade the rest, which is not what
        // this case reviews.
        return MarkerFixtureScene(markers: laid, selectedId: uuid(3))
    }

    /// Neighbouring candles, where proximity tiers stagger the stacks.
    static func adjacentCandleStacks() -> MarkerFixtureScene {
        let authors: [Author] = [.alex, .sam, .jamie, .kit, .noor, .priya, .lee, .omar]
        let intents: [RLMarkerIntent] = [.analysis, .question, .setup]
        var dtos: [RLChartMarkerDTO] = []
        for index in 0..<9 {
            dtos.append(
                authored(
                    index + 1, by: authors[index % authors.count], intent: intents[index % 3],
                    candleIndex: 4 + index / 2, title: "Idea \(index + 1)", likes: index % 3
                )
            )
        }
        return MarkerFixtureScene(markers: positioned(dtos), selectedId: nil)
    }

    /// The zoomed-out chart: many narrow candles, markers on neighbours.
    static func zoomedOut() -> MarkerFixtureScene {
        let candles = self.candles(count: 60)
        let authors: [Author] = [.alex, .sam, .jamie, .kit, .noor, .priya, .lee, .omar]
        let intents: [RLMarkerIntent] = [.analysis, .question, .setup, .analysis, .news]
        var dtos: [RLChartMarkerDTO] = []
        for index in 0..<36 {
            let candleIndex = 8 + (index * 7) % 44
            dtos.append(
                authored(
                    index + 1, by: authors[index % authors.count], intent: intents[index % intents.count],
                    candleIndex: candleIndex, title: nil, likes: index % 4 == 0 ? 2 : 0
                )
            )
        }
        return MarkerFixtureScene(markers: positioned(dtos, candles: candles), candles: candles, selectedId: nil)
    }

    /// First and last candle, where the plot clips, and a deep stack.
    static func chartEdges() -> MarkerFixtureScene {
        var dtos = [
            authored(1, by: .alex, intent: .analysis, candleIndex: 0, title: "Left edge"),
            authored(2, by: .sam, intent: .setup, candleIndex: 11, title: "Right edge", likes: 4),
        ]
        let stackAuthors: [Author] = [.jamie, .kit, .noor, .priya, .omar, .lee, .alex, .sam]
        for (offset, author) in stackAuthors.enumerated() {
            dtos.append(authored(10 + offset, by: author, intent: [.analysis, .question, .setup][offset % 3],
                                 candleIndex: 6, title: "Stack \(offset + 1)"))
        }
        return MarkerFixtureScene(markers: positioned(dtos), selectedId: uuid(2))
    }

    // MARK: Setup states

    /// Untracked, armed, live, TP hit and SL hit.
    static func setupStates() -> MarkerFixtureScene {
        let tp = RLPredictionResultDTO(
            resultType: "take_profit", triggerPrice: 64_800, triggeredAt: candle(6),
            triggeredAtFormatted: "1h ago", pnl: 800, guildRepDelta: 5, globalRepDelta: 2
        )
        let sl = RLPredictionResultDTO(
            resultType: "stop_loss", triggerPrice: 63_500, triggeredAt: candle(8),
            triggeredAtFormatted: "1h ago", pnl: -500, guildRepDelta: -2, globalRepDelta: -1
        )
        let dtos = [
            authored(1, by: .alex, intent: .setup, candleIndex: 2, title: "Untracked", trackingState: .draft),
            authored(2, by: .sam, intent: .setup, candleIndex: 4, title: "Armed",
                     trackingEnabled: true, trackingState: .armed),
            authored(3, by: .jamie, intent: .setup, candleIndex: 6, title: "Live",
                     likes: 3, trackingEnabled: true, trackingState: .active),
            authored(4, by: .kit, intent: .setup, candleIndex: 8, title: "TP hit",
                     trackingEnabled: true, trackingState: .tpHit, prediction: tp),
            authored(5, by: .noor, intent: .setup, candleIndex: 10, title: "SL hit",
                     trackingEnabled: true, trackingState: .slHit, prediction: sl),
        ]
        return MarkerFixtureScene(markers: positioned(dtos), selectedId: uuid(3))
    }

    // MARK: Avatar identity states

    static let changedAuthorNumber = 21
    static let removedAuthorNumber = 22

    /// Picture, initials, failed load, changed since the snapshot, removed
    /// since the snapshot, and nothing to draw at all.
    static func avatarStates() -> MarkerFixtureScene {
        let picture = Author.named("priya", 7)
        let initials = Author(number: 20, username: "noor", avatarUrl: nil)
        let failed = Author(number: 23, username: "fern", avatarUrl: MarkerAvatarFixtureImages.failingURL)
        let changed = Author(number: changedAuthorNumber, username: "rae",
                             avatarUrl: MarkerAvatarFixtureImages.url(for: "rae-before"))
        let removed = Author(number: removedAuthorNumber, username: "ivy",
                             avatarUrl: MarkerAvatarFixtureImages.url(for: "ivy"))
        let anonymous = Author(number: 24, username: "", avatarUrl: nil)
        let dtos = [
            authored(1, by: picture, intent: .analysis, candleIndex: 1, title: "Picture"),
            authored(2, by: initials, intent: .analysis, candleIndex: 3, title: "Initials"),
            authored(3, by: failed, intent: .question, candleIndex: 5, title: "Failed load"),
            authored(4, by: changed, intent: .setup, candleIndex: 7, title: "Changed"),
            authored(5, by: removed, intent: .analysis, candleIndex: 9, title: "Removed"),
            authored(6, by: anonymous, intent: .question, candleIndex: 11, title: "Nothing to draw"),
        ]
        return MarkerFixtureScene(
            markers: positioned(dtos),
            selectedId: nil,
            directory: [
                changed.userId: MarkerAvatarFixtureImages.url(for: "rae-after"),
                removed.userId: "",
            ]
        )
    }

    // MARK: Component arcs

    /// One marker per arc combination; select each (launch with
    /// `-MarkerFixtureSelect <n>`) to see its arcs.
    static func componentArcs() -> MarkerFixtureScene {
        let dtos = [
            authored(1, by: .alex, intent: .analysis, candleIndex: 2, title: "Indicators only",
                     components: [.indicator, .indicator]),
            authored(2, by: .sam, intent: .question, candleIndex: 4, title: "Drawings and links",
                     components: [.drawingTrendline, .levelSupport, .linkURL]),
            authored(3, by: .jamie, intent: .analysis, candleIndex: 6, title: "All three",
                     components: [.indicator, .drawingZone, .drawingPattern, .timeframeLink, .timeframeLink]),
            authored(4, by: .kit, intent: .setup, candleIndex: 8, title: "Levels only: no arcs",
                     trackingEnabled: true, trackingState: .armed,
                     components: [.anchor, .levelEntry, .levelSl, .levelTp]),
            authored(5, by: .noor, intent: .setup, candleIndex: 10, title: "Levels plus context",
                     trackingEnabled: true, trackingState: .active,
                     components: [.levelEntry, .levelSl, .levelTp, .indicator, .timeframeLink]),
        ]
        return MarkerFixtureScene(markers: positioned(dtos), selectedId: uuid(3))
    }

    // MARK: Cross-timeframe jumps

    /// A selected avatar-led marker with a parent and a response on other
    /// timeframes — the parent jump's tether leaves on the intent badge's
    /// diagonal. Marker 1 sits above its candle, marker 2 below; select either
    /// (`-MarkerFixtureSelect 1|2`).
    static func timeframeJumps() -> MarkerFixtureScene {
        var laid = positioned([
            authored(1, by: .alex, intent: .analysis, candleIndex: 4, title: "Above", parent: 9,
                     relationship: "supports", responses: 1),
            authored(2, by: .sam, intent: .setup, candleIndex: 8, title: "Below", parent: 9,
                     relationship: "builds_on", responses: 1, trackingEnabled: true, trackingState: .active),
        ])
        for index in laid.indices where laid[index].id == uuid(2) {
            laid[index].positionedBelow = true
        }
        let jumps = [
            MarkerTimeframeJump(
                markerId: uuid(9), direction: .toParent,
                relationship: MarkerLinkRelationshipValue(.supports), timeframe: .h4, others: 0,
                preview: preview(9, author: "kit", title: "4h thesis", relationship: nil)
            ),
            MarkerTimeframeJump(
                markerId: uuid(10), direction: .toResponse,
                relationship: MarkerLinkRelationshipValue(.challenges), timeframe: .m15, others: 0,
                preview: preview(10, author: "jamie", title: "15m reply", relationship: "challenges")
            ),
        ]
        return MarkerFixtureScene(markers: laid, selectedId: uuid(1), timeframeJumps: jumps)
    }

    // MARK: Mixed legacy

    /// The prototype's intents beside every intent that keeps its glyph.
    static func mixedLegacy() -> MarkerFixtureScene {
        // Severity comes from the note prefix, as for an alert without the field.
        let alert = authored(4, by: .kit, intent: .alert, candleIndex: 5, note: "[Critical] Liquidity thin")
        let dtos = [
            authored(1, by: .alex, intent: .analysis, candleIndex: 2, title: "Analysis", likes: 2),
            authored(2, by: .sam, intent: .question, candleIndex: 3, title: "Question"),
            authored(3, by: .jamie, intent: .setup, candleIndex: 4, title: "Setup"),
            alert,
            authored(5, by: .priya, intent: .poll, candleIndex: 6, title: "Where does it close?"),
            authored(6, by: .lee, intent: .news, candleIndex: 7, title: "CPI print"),
            authored(7, by: .omar, intent: .reaction, candleIndex: 8),
            authored(8, by: .noor, intent: .personal, candleIndex: 9, title: "My note", visibility: "private"),
            authored(9, by: .alex, intent: .personal, candleIndex: 10, title: "Shared note"),
        ]
        return MarkerFixtureScene(markers: positioned(dtos), selectedId: nil)
    }
}

#endif
