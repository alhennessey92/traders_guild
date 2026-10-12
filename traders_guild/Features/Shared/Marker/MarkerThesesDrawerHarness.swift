//
//  MarkerThesesDrawerHarness.swift
//  traders_guild
//
//  Backend-free fixture for the drawer's Theses tab and threaded Live Feed:
//  the real `MarkerThesesList` and `MarkerThreadedFeed` (with the real
//  `MarkerListItem`) over a fixture activity page shaped like a 1.5 server's.
//  Nothing here touches app state, the keychain or the network; taps only
//  report what they would open.
//
//  Launch: `-DrawerThesesFixture theses|feed [-TGAvatarMarkersExperiment YES]`.
//  Debug and isolated-DEV builds only.
//

#if DEBUG || TG_ISOLATED_DEV

import SwiftUI

struct MarkerThesesDrawerHarness: View {
    static var launchTab: DrawerMarkerTab? {
        switch UserDefaults.standard.string(forKey: "DrawerThesesFixture") {
        case "theses": return .theses
        case "feed": return .liveFeed
        default: return nil
        }
    }

    @State private var selectedTab: DrawerMarkerTab
    @State private var lastAction = "—"

    init(tab: DrawerMarkerTab) {
        _selectedTab = State(initialValue: tab)
    }

    private let items = MarkerThesesDrawerHarness.page()

    var body: some View {
        VStack(spacing: 0) {
            Text("Fixture · drawer theses · last tap: \(lastAction)")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .accessibilityIdentifier("thesesFixture.lastAction")
            UnifiedTabBar(selectedTab: $selectedTab, tabs: [.theses, .liveFeed], size: .compact,
                          theme: .markerNavigation, spacing: 6)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if selectedTab == .theses {
                        MarkerThesesList(
                            theses: MarkerThesisFeed.theses(from: items),
                            onOpen: { lastAction = "thesis \(Self.name(of: $0))" },
                            onOpenReply: { lastAction = "reply @\($0.authorUsername)" }
                        )
                    } else {
                        MarkerThreadedFeed(
                            markers: items,
                            item: { marker in
                                MarkerListItem(marker: marker, style: .capsule, showMyBadge: marker.isCurrentUserMarker,
                                               onLike: { lastAction = "like @\(marker.authorUsername)" },
                                               onTap: { lastAction = "marker @\(marker.authorUsername)" })
                            },
                            onTapReply: { lastAction = "reply @\($0.authorUsername)" },
                            onOpenParent: { lastAction = "parent of @\($0.authorUsername)" }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(colors: [AppColors.drawerBackground, AppColors.sheetBackground],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private static func name(of thesis: MarkerThesis) -> String {
        switch thesis.head {
        case .item(let item): return "@\(item.authorUsername)"
        case .preview(let preview): return "@\(preview.authorUsername ?? "?") (preview)"
        }
    }

    // MARK: - Fixture page

    private static let now = Date()
    private static let authors = ["you", "alex", "sam", "jo", "mk", "lee", "ana", "kai"]

    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "7B2E4C00-0000-4000-8000-%012d", n))!
    }

    private static func item(
        _ n: Int, author: String, intent: RLMarkerIntent, minutesAgo: Double, ticker: String = "BTC/USD",
        timeframe: String = "1h", title: String?, note: String? = nil, parent: Int? = nil,
        relationship: MarkerLinkRelationship? = nil, responses: Int = 0,
        counts: [String: Int]? = nil, lastResponseMinutesAgo: Double? = nil,
        preview: RLMarkerLinkPreviewDTO? = nil, likes: Int = 0, mine: Bool = false
    ) -> RLMarkerActivityItemDTO {
        let date = now.addingTimeInterval(-minutesAgo * 60)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        var dto = RLMarkerActivityItemDTO(
            id: id(n), symbolId: id(900 + (ticker == "BTC/USD" ? 1 : 2)), symbolTicker: ticker, symbolBrandColor: nil,
            symbolAssetClass: "crypto", guildId: id(999), authorId: id(600 + (authors.firstIndex(of: author) ?? 0)),
            authorUsername: author, authorInitials: String(author.prefix(2)).uppercased(), authorAvatarUrl: nil,
            authorIsOnline: false, authorReputation: 120, authorAccuracyRate: 0.64, authorRole: "member",
            intent: intent.rawValue, title: title, notePreview: note, pollQuestion: nil, pollOptions: nil,
            selectedEmoji: nil, alertSeverity: nil, createdAt: date,
            createdAtFormatted: formatter.localizedString(for: date, relativeTo: now),
            activityTimestamp: date, activityTimestampFormatted: formatter.localizedString(for: date, relativeTo: now),
            candleTimestamp: date, timeframe: timeframe, price: 63_850, setupSummary: nil, predictionResult: nil,
            likeCount: likes, isLikedByCurrentUser: false, commentCount: 0, isCurrentUserMarker: mine
        )
        dto.parentMarkerId = parent.map(id)
        dto.linkRelationship = relationship?.rawValue
        dto.directResponseCount = responses
        dto.responseCounts = counts
        dto.lastResponseAt = lastResponseMinutesAgo.map { now.addingTimeInterval(-$0 * 60) }
        dto.parentPreview = preview
        return dto
    }

    /// A 1.5 server's page, newest first: a busy thesis, a reply to one of
    /// its replies, a Question known only from its replies, and markers with
    /// no thread at all.
    static func page() -> [RLMarkerActivityItemDTO] {
        let ethQuestion = RLMarkerLinkPreviewDTO(
            nodeKey: "eth", markerId: id(20), authorId: id(603), authorUsername: "jo", guildId: id(999),
            symbolId: id(902), ticker: "ETH/USD", timeframe: "4h", candleTimestamp: now.addingTimeInterval(-86_400),
            price: 2_450, intent: RLMarkerIntent.question.rawValue, title: "Breakout or fakeout above 2,450?",
            createdAt: now.addingTimeInterval(-86_400), directResponseCount: 3
        )
        return [
            item(6, author: "mk", intent: .analysis, minutesAgo: 4, title: "Next leg 66.2k if the range holds",
                 parent: 1, relationship: .buildsOn),
            item(5, author: "jo", intent: .question, minutesAgo: 12, title: "What does funding say?",
                 note: "Funding flipped positive overnight — is the low really defended?",
                 parent: 1, relationship: .challenges, responses: 1, counts: ["supports": 1], lastResponseMinutesAgo: 2),
            item(7, author: "sam", intent: .analysis, minutesAgo: 2, title: "Funding resets every bounce here",
                 parent: 5, relationship: .supports),
            item(21, author: "you", intent: .analysis, minutesAgo: 25, ticker: "ETH/USD", timeframe: "4h",
                 title: "Fakeout — volume never confirmed", parent: 20, relationship: .challenges,
                 preview: ethQuestion, mine: true),
            item(2, author: "sam", intent: .analysis, minutesAgo: 40, title: "Volume agrees — absorption at the low",
                 parent: 1, relationship: .supports),
            item(30, author: "lee", intent: .setup, minutesAgo: 55, title: "Long the retest", likes: 2),
            item(22, author: "ana", intent: .analysis, minutesAgo: 70, ticker: "ETH/USD", timeframe: "4h",
                 title: "Breakout — weekly close above", parent: 20, relationship: .supports, preview: ethQuestion),
            item(1, author: "alex", intent: .analysis, minutesAgo: 180, title: "Range low holds at 63.8k",
                 note: "Third test of the range low with shrinking sell volume. Invalidated below 63.2k.",
                 responses: 4, counts: ["supports": 2, "challenges": 1, "builds_on": 1], lastResponseMinutesAgo: 4,
                 likes: 5),
            item(31, author: "kai", intent: .question, minutesAgo: 240, title: "Anyone watching the 200 EMA?"),
        ].sorted { $0.activityTimestamp > $1.activityTimestamp }
    }
}

#endif
