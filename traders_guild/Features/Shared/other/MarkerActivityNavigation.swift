import Foundation

enum MarkerActivityListLoadMode: Equatable {
    case recentFeed
    case archive
    case setupsLive
    case setupsResolved

    var state: RLMarkerActivityState {
        switch self {
        case .recentFeed, .archive:
            return .all
        case .setupsLive:
            return .active
        case .setupsResolved:
            return .resolved
        }
    }

    var limit: Int { 60 }

    var fetchAllPages: Bool {
        switch self {
        case .recentFeed:
            return false
        case .archive, .setupsLive, .setupsResolved:
            return true
        }
    }
}

struct MarkerSymbolGroup: Identifiable, Equatable {
    let symbolId: UUID
    let ticker: String
    let brandColor: String?
    let markers: [RLMarkerActivityItemDTO]

    var id: UUID { symbolId }
    var count: Int { markers.count }
    var latestActivity: Date { markers.first?.activityTimestamp ?? .distantPast }
}

struct MarkerTimeframeGroup: Identifiable, Equatable {
    let rawTimeframe: String
    let title: String
    let markers: [RLMarkerActivityItemDTO]
    let isExpandedByDefault: Bool

    var id: String { rawTimeframe }
    var count: Int { markers.count }
    var latestActivity: Date { markers.first?.activityTimestamp ?? .distantPast }
}

enum MarkerActivityNavigation {
    static func sortedByActivity(_ markers: [RLMarkerActivityItemDTO]) -> [RLMarkerActivityItemDTO] {
        markers.sorted { lhs, rhs in
            if lhs.activityTimestamp == rhs.activityTimestamp {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.activityTimestamp > rhs.activityTimestamp
        }
    }

    static func symbolGroups(from markers: [RLMarkerActivityItemDTO]) -> [MarkerSymbolGroup] {
        Dictionary(grouping: sortedByActivity(markers), by: \.symbolId)
            .compactMap { symbolId, groupedMarkers in
                guard let first = groupedMarkers.first else { return nil }
                return MarkerSymbolGroup(
                    symbolId: symbolId,
                    ticker: first.symbolTicker,
                    brandColor: first.symbolBrandColor,
                    markers: groupedMarkers
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                if lhs.latestActivity != rhs.latestActivity {
                    return lhs.latestActivity > rhs.latestActivity
                }
                return lhs.ticker.localizedCaseInsensitiveCompare(rhs.ticker) == .orderedAscending
            }
    }

    static func timeframeGroups(
        from markers: [RLMarkerActivityItemDTO],
        currentTimeframe: RLChartTimeframe?
    ) -> [MarkerTimeframeGroup] {
        let rawGroups = Dictionary(grouping: sortedByActivity(markers), by: \.timeframe)
            .map { rawTimeframe, groupedMarkers in
                (
                    rawTimeframe: rawTimeframe,
                    title: timeframeTitle(for: rawTimeframe),
                    markers: groupedMarkers
                )
            }
            .sorted { lhs, rhs in
                let lhsRank = timeframeSortRank(for: lhs.rawTimeframe)
                let rhsRank = timeframeSortRank(for: rhs.rawTimeframe)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                let lhsLatest = lhs.markers.first?.activityTimestamp ?? .distantPast
                let rhsLatest = rhs.markers.first?.activityTimestamp ?? .distantPast
                if lhsLatest != rhsLatest {
                    return lhsLatest > rhsLatest
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        let currentRawTimeframe = currentTimeframe?.toBackendString()
        let defaultExpandedKey = rawGroups.contains(where: { $0.rawTimeframe == currentRawTimeframe })
            ? currentRawTimeframe
            : rawGroups.first?.rawTimeframe

        return rawGroups.map { group in
            MarkerTimeframeGroup(
                rawTimeframe: group.rawTimeframe,
                title: group.title,
                markers: group.markers,
                isExpandedByDefault: group.rawTimeframe == defaultExpandedKey
            )
        }
    }

    static func timeframeTitle(for backendTimeframe: String) -> String {
        RLChartTimeframe.fromBackendString(backendTimeframe)?.shortName ?? backendTimeframe.uppercased()
    }

    static func timeframeSortRank(for backendTimeframe: String) -> Int {
        guard let timeframe = RLChartTimeframe.fromBackendString(backendTimeframe),
              let index = RLChartTimeframe.allCases.firstIndex(of: timeframe) else {
            return Int.max
        }
        return index
    }
}
