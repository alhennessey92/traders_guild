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
                                    .tint(.white)
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
                    .foregroundColor(.secondary)
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
                        .fill(AppColors.surfaceWhite04)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.surfaceWhite08, lineWidth: 1)
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
                .fill(AppColors.surfaceWhite04)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.surfaceWhite08, lineWidth: 1)
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
                            .fill(AppColors.surfaceWhite10)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        UnifiedMarkerBadge(intent: marker.intentEnum, sizeToken: .tiny)
                        if let symbolColor = marker.symbolBrandColor {
                            Circle()
                                .fill(Color(hex: symbolColor) ?? .blue)
                                .frame(width: 8, height: 8)
                        }
                        Text(marker.symbolTicker)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.whiteText)

                        Text(marker.timeframe.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.whiteText.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.whiteText.opacity(0.10)))

                        Text(marker.intentEnum.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(marker.intentEnum.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(marker.intentEnum.color.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    if let trackingStateRaw = marker.setupSummary?.trackingState,
                       let trackingState = RLTrackingState(rawValue: trackingStateRaw) {
                        HStack(spacing: 6) {
                            if trackingState.isLive {
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.statusPositive70))
                            }

                            TrackingStatePill(state: trackingState, size: .compact)

                            if marker.intentEnum == .setup {
                                let approachStatus = MarkerPredictionProgress.status(
                                    entryPrice: marker.setupSummary?.entryPrice ?? marker.price,
                                    currentPrice: symbolCache[marker.symbolId]?.currentPrice,
                                    targetPrice: marker.setupSummary?.tpPrice,
                                    stopLossPrice: marker.setupSummary?.slPrice
                                )
                                ApproachingLevelChip(status: approachStatus)
                            }
                        }
                    }

                    markerRowSpecifics(marker)

                    Text(marker.createdAtFormatted)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.9))
                }

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText.opacity(0.8))
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func markerRowSpecifics(_ marker: RLTopMarkerDTO) -> some View {
        switch marker.intentEnum {
        case .setup:
            if let summary = marker.setupSummary,
               let trackingStateRaw = summary.trackingState,
               let trackingState = RLTrackingState(rawValue: trackingStateRaw),
               trackingState.isLive,
               let slPrice = summary.slPrice,
               let tpPrice = summary.tpPrice,
               let currentPrice = symbolCache[marker.symbolId]?.currentPrice,
               let metrics = LiveSetupMetrics.compute(
                   entryPrice: summary.entryPrice ?? marker.price,
                   stopLossPrice: slPrice,
                   targetPrice: tpPrice,
                   currentPrice: currentPrice
               ) {
                MarkerListSpecificsSection {
                    UnifiedSetupProgressStrip(
                        metrics: metrics,
                        size: .standard,
                        formatPrice: { String(format: "%.5f", $0) }
                    )
                }
            } else if let note = marker.notePreview, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

        case .question:
            MarkerListSpecificsSection {
                MarkerListSpecificsLabel(label: "QUESTION", color: marker.intentEnum.color)
                if let note = marker.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.surfaceWhite92)
                        .lineLimit(2)
                }
            }

        case .alert:
            MarkerListSpecificsSection {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Alert")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(marker.intentEnum.color.opacity(0.40))
                        .overlay(Capsule().stroke(marker.intentEnum.color.opacity(0.60), lineWidth: 1))
                )

                if let note = marker.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.surfaceWhite85)
                        .lineLimit(2)
                }
            }

        case .poll:
            MarkerListSpecificsSection {
                MarkerListSpecificsLabel(label: "POLL", color: marker.intentEnum.color)
                if let note = marker.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.surfaceWhite85)
                        .lineLimit(2)
                }
            }

        case .news:
            MarkerListSpecificsSection {
                MarkerListSpecificsLabel(label: "NEWS", color: marker.intentEnum.color)
                if let note = marker.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.surfaceWhite85)
                        .lineLimit(1)
                }
            }

        default:
            if let note = marker.notePreview, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }
        }
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
            loadError = error.localizedDescription
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

