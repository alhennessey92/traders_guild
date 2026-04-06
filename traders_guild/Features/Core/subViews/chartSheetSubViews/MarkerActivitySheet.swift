//
//  MarkerActivitySheet.swift
//  traders_guild
//
//  Marker activity timeline with live prediction progress chips.
//

import SwiftUI

struct MarkerActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rlAppState: RLAppState

    let onNavigateToMarker: (RLTopMarkerDTO) -> Void

    @State private var markers: [RLTopMarkerDTO] = []
    @State private var symbolCache: [UUID: RLTradingSymbolDTO] = [:]
    @State private var isLoading = true
    @State private var isRefreshingLiveData = false
    @State private var loadError: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "clock.arrow.circlepath",
                    iconColor: .mint,
                    title: "Marker Activity",
                    subtitle: "Tap a marker to jump to its chart candle",
                    trailing: AnyView(
                        Button {
                            Task { await refreshLiveData() }
                        } label: {
                            if isRefreshingLiveData {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppColors.primaryForeground)
                            } else {
                                Image(systemName: "arrow.clockwise.circle")
                                    .font(.title3)
                                    .foregroundColor(AppColors.whiteText.opacity(0.8))
                            }
                        }
                        .disabled(isRefreshingLiveData || markers.isEmpty)
                    )
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Divider()
                    .background(AppColors.surfaceWhite15)
                    .padding(.top, 12)

                content
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .background(AdminSheetBackground())
        .task { await loadMarkers() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                ProgressView("Loading activity...")
                    .tint(AppColors.accentColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
        } else if let loadError {
            emptyStateCard(
                icon: "exclamationmark.triangle",
                title: "Unable to load markers",
                subtitle: loadError
            )
        } else if markers.isEmpty {
            emptyStateCard(
                icon: "mappin.and.ellipse",
                title: "No marker activity yet",
                subtitle: "Your recent markers will appear here."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(markers.enumerated()), id: \.element.id) { index, marker in
                        markerRow(marker, isLast: index == markers.count - 1)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.symbolDetailCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                        )
                )
                .padding(.bottom, 22)
            }
        }
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        UnifiedEmptyState(
            icon: icon,
            title: title,
            subtitle: subtitle
        )
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.symbolDetailCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }

    private func markerRow(_ marker: RLTopMarkerDTO, isLast: Bool) -> some View {
        Button {
            onNavigateToMarker(marker)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(marker.intentEnum.color)
                        .frame(width: 9, height: 9)

                    if !isLast {
                        Rectangle()
                            .fill(AppColors.panelFillEmphasis)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }

                MarkerListItem(
                    marker: marker,
                    style: .inline,
                    currentPrice: symbolCache[marker.symbolId]?.currentPrice,
                    onTap: {}
                )

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText.opacity(0.8))
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
        .buttonStyle(.plain)
    }


    private func loadMarkers() async {
        guard let guildId = rlAppState.currentGuild?.id,
              let userId = rlAppState.currentUser?.id else {
            isLoading = false
            loadError = "No guild or user selected."
            return
        }

        isLoading = true
        loadError = nil
        do {
            let response = try await rlAppState.realApi.getUserMarkers(guildId: guildId, userId: userId)
            markers = response.mine.sorted { $0.createdAt > $1.createdAt }
            await loadLiveSymbols(for: markers)
        } catch {
            loadError = RLUserFacingErrorMapper.message(from: error)
        }
        isLoading = false
    }

    private func refreshLiveData() async {
        guard !markers.isEmpty else { return }
        await loadLiveSymbols(for: markers, forceReload: true)
    }

    private func loadLiveSymbols(for markers: [RLTopMarkerDTO], forceReload: Bool = false) async {
        let uniqueSymbolIds = Set(markers.map(\.symbolId))
        let symbolIdsToFetch = uniqueSymbolIds.filter { forceReload || symbolCache[$0] == nil }
        guard !symbolIdsToFetch.isEmpty else { return }

        isRefreshingLiveData = true
        defer { isRefreshingLiveData = false }

        var updates: [UUID: RLTradingSymbolDTO] = [:]
        await withTaskGroup(of: (UUID, RLTradingSymbolDTO?).self) { group in
            for symbolId in symbolIdsToFetch {
                group.addTask {
                    let symbol = try? await rlAppState.realApi.getSymbol(symbolId: symbolId)
                    return (symbolId, symbol)
                }
            }

            for await (symbolId, symbol) in group {
                if let symbol {
                    updates[symbolId] = symbol
                }
            }
        }

        symbolCache.merge(updates) { _, newValue in newValue }
    }
}
