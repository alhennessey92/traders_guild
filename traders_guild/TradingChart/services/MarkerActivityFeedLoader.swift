//
//  MarkerActivityFeedLoader.swift
//  traders_guild
//
//  Shared marker activity loader for chart sheet and left drawer surfaces.
//

import Foundation

struct MarkerActivityFeedSnapshot {
    let markersByScope: [RLMarkerActivityScope: [RLMarkerActivityItemDTO]]
    let totalCountByScope: [RLMarkerActivityScope: Int]
    let lastUpdated: Date
}

enum MarkerActivityFeedLoader {
    static func loadTopTab(
        api: RealAPIService,
        guildId: UUID,
        symbolId: UUID? = nil,
        topTab: RLMarkerActivityTopTab,
        scopes: [RLMarkerActivityScope] = Array(RLMarkerActivityScope.allCases),
        limit: Int = 60,
        fetchAllPages: Bool = false
    ) async throws -> MarkerActivityFeedSnapshot {
        try await loadScopes(
            api: api,
            guildId: guildId,
            symbolId: symbolId,
            state: topTab.activityState,
            window: topTab.activityWindow,
            scopes: scopes,
            limit: limit,
            fetchAllPages: fetchAllPages
        )
    }

    static func loadScopes(
        api: RealAPIService,
        guildId: UUID,
        symbolId: UUID? = nil,
        state: RLMarkerActivityState,
        window: RLMarkerActivityWindow? = nil,
        scopes: [RLMarkerActivityScope] = Array(RLMarkerActivityScope.allCases),
        limit: Int = 50,
        fetchAllPages: Bool = false
    ) async throws -> MarkerActivityFeedSnapshot {
        try await withThrowingTaskGroup(
            of: (RLMarkerActivityScope, RLMarkerActivityListDTO).self
        ) { group in
            for scope in scopes {
                group.addTask {
                    let response = try await loadScope(
                        api: api,
                        guildId: guildId,
                        symbolId: symbolId,
                        scope: scope,
                        state: state,
                        window: window,
                        limit: limit,
                        fetchAllPages: fetchAllPages
                    )
                    return (scope, response)
                }
            }

            var markersByScope: [RLMarkerActivityScope: [RLMarkerActivityItemDTO]] = [:]
            var totalCountByScope: [RLMarkerActivityScope: Int] = [:]
            var timestamps: [Date] = []

            for try await (scope, response) in group {
                markersByScope[scope] = response.markers
                totalCountByScope[scope] = response.totalCount
                timestamps.append(response.lastUpdated)
            }

            return MarkerActivityFeedSnapshot(
                markersByScope: markersByScope,
                totalCountByScope: totalCountByScope,
                lastUpdated: timestamps.max() ?? Date()
            )
        }
    }

    private static func loadScope(
        api: RealAPIService,
        guildId: UUID,
        symbolId: UUID?,
        scope: RLMarkerActivityScope,
        state: RLMarkerActivityState,
        window: RLMarkerActivityWindow?,
        limit: Int,
        fetchAllPages: Bool
    ) async throws -> RLMarkerActivityListDTO {
        let firstPage = try await api.getMarkerActivity(
            guildId: guildId,
            symbolId: symbolId,
            scope: scope,
            state: state,
            window: window,
            limit: limit
        )

        guard fetchAllPages, firstPage.hasMore else {
            return firstPage
        }

        var markers = firstPage.markers
        var cursor = firstPage.nextCursor
        var lastUpdated = firstPage.lastUpdated

        while let nextCursor = cursor, !nextCursor.isEmpty {
            let nextPage = try await api.getMarkerActivity(
                guildId: guildId,
                symbolId: symbolId,
                scope: scope,
                state: state,
                window: window,
                limit: limit,
                cursor: nextCursor
            )
            markers.append(contentsOf: nextPage.markers)
            if nextPage.lastUpdated > lastUpdated {
                lastUpdated = nextPage.lastUpdated
            }
            cursor = nextPage.hasMore ? nextPage.nextCursor : nil
        }

        return RLMarkerActivityListDTO(
            markers: markers,
            totalCount: firstPage.totalCount,
            hasMore: false,
            nextCursor: nil,
            lastUpdated: lastUpdated
        )
    }
}
