//
//  MarkerListItem.swift
//  traders_guild
//
//  Unified marker list item component used across the app:
//  - Left drawer marker tab (capsule style)
//  - Chart bottom sheet markers (capsule style)
//  - User profile markers tab (capsule style)
//  - MarkerActivitySheet timeline (inline style)
//

import SwiftUI

// MARK: - Style

enum MarkerListItemStyle {
    case capsule   // Left drawer, chart bottom sheet
    case card      // UnifiedContentCard presentation
    case inline    // Timeline rows (no background, compact)
}

// MARK: - MarkerListItem

struct MarkerListItem<M: MarkerListItemData>: View {
    let marker: M
    var style: MarkerListItemStyle = .capsule
    var showMyBadge: Bool = false
    var currentPrice: Double? = nil
    var likeAnimationMarkerId: UUID? = nil
    var onLike: (() -> Void)? = nil
    let onTap: () -> Void

    private let capsuleCornerRadius: CGFloat = 16
    private let capsuleIconSize: CGFloat = 44

    // MARK: - Computed Properties

    private var hasNotePreview: Bool {
        guard let note = marker.notePreview else { return false }
        return !note.isEmpty
    }

    private var isLikeAnimating: Bool {
        likeAnimationMarkerId == marker.id
    }

    private var trackingState: RLTrackingState? {
        marker.trackingStateEnum
    }

    private var approachingStatus: MarkerPredictionProgressStatus? {
        guard marker.intentEnum == .setup,
              let setupSummary = marker.setupSummary,
              let trackingState,
              trackingState.isLive else { return nil }

        let status = MarkerPredictionProgress.status(
            entryPrice: setupSummary.entryPrice ?? marker.price,
            currentPrice: currentPrice,
            targetPrice: setupSummary.tpPrice,
            stopLossPrice: setupSummary.slPrice
        )
        return (status == .approachingTP || status == .approachingSL) ? status : nil
    }

    private var liveSetupMetrics: LiveSetupMetrics? {
        guard marker.intentEnum == .setup,
              let setupSummary = marker.setupSummary,
              let trackingState,
              trackingState.isLive,
              let stopLossPrice = setupSummary.slPrice,
              let targetPrice = setupSummary.tpPrice,
              let currentPrice else { return nil }

        let entryPrice = setupSummary.entryPrice ?? marker.price
        return LiveSetupMetrics.compute(
            entryPrice: entryPrice,
            stopLossPrice: stopLossPrice,
            targetPrice: targetPrice,
            currentPrice: currentPrice
        )
    }

    private var outcome: SetupOutcome? {
        guard marker.intentEnum == .setup,
              let trackingState,
              trackingState.isResolved else { return nil }

        return SetupOutcome(
            state: trackingState,
            resultType: marker.predictionResult?.resultType,
            triggerPrice: marker.predictionResult?.triggerPrice,
            triggeredAtFormatted: marker.predictionResult?.triggeredAtFormatted,
            pnl: marker.predictionResult?.pnl,
            isTracked: true,
            guildRepDelta: marker.predictionResult?.guildRepDelta,
            globalRepDelta: marker.predictionResult?.globalRepDelta
        )
    }

    private var hasExpandableContent: Bool {
        switch marker.intentEnum {
        case .setup:
            return liveSetupMetrics != nil || outcome != nil || hasNotePreview
        case .question, .poll:
            return hasNotePreview
        case .alert, .news:
            return hasNotePreview
        case .analysis:
            return hasNotePreview
        default:
            return false
        }
    }

    // MARK: - Contextual summary text for line 1

    private var contextSummary: String? {
        switch marker.intentEnum {
        case .setup:
            if let outcome {
                if let pnl = outcome.pnl {
                    return formatPnL(pnl)
                }
                if outcome.isExpired { return "Expired" }
                return nil
            }
            if let metrics = liveSetupMetrics {
                return formatPnL(metrics.currentPnL)
            }
            return nil
        default:
            return nil
        }
    }

    private var contextSummaryColor: Color {
        switch marker.intentEnum {
        case .setup:
            if let outcome {
                if outcome.isWin { return AppColors.statusPositive70 }
                if outcome.isLoss { return AppColors.statusNegative70 }
                return AppColors.surfaceGray90
            }
            if let metrics = liveSetupMetrics {
                return metrics.isMovingTowardTarget
                    ? RLComponentType.levelTp.color
                    : RLComponentType.levelSl.color
            }
            return AppColors.surfaceWhite70
        default:
            return AppColors.surfaceWhite70
        }
    }

    private var containerCornerRadius: CGFloat {
        capsuleCornerRadius
    }

    private var shouldShowIconLikeBadge: Bool {
        marker.likeCount > 0
    }

    private var reactionEmoji: String? {
        let trimmed = marker.selectedEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .capsule:
            capsuleLayout
        case .card:
            cardLayout
        case .inline:
            inlineLayout
        }
    }

    // MARK: - Capsule Layout

    private var capsuleLayout: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                capsuleIconArea
                    .padding(.top, 2)

                capsuleContent
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)

            capsuleFooter
        }
        .background(
            RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                .fill(AppColors.surfaceWhite04)
                .overlay(
                    RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                        .stroke(AppColors.surfaceWhite08, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
    }

    private var capsuleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            capsuleTopRow
                .frame(maxWidth: .infinity, alignment: .leading)

            capsuleDetailSection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Card Layout

    private var cardLayout: some View {
        UnifiedContentCard(onTap: {
            HapticFeedback.light.trigger()
            onTap()
        }) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    UnifiedMarkerBadge(
                        intent: marker.intentEnum,
                        sizeToken: .large,
                        emoji: marker.intentEnum == .reaction ? reactionEmoji : nil
                    )
                        .padding(.top, 2)

                    cardPrimaryContent
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 14)

                UnifiedAuthorFooter(
                    username: marker.authorUsername,
                    isOnline: marker.authorIsOnline,
                    role: RLMemberRole(from: marker.authorRole),
                    reputation: marker.authorReputation,
                    accuracy: marker.authorAccuracyFormatted,
                    timeText: marker.displayTimestamp,
                    showOnlineStatus: false
                )
            }
        }
    }

    // MARK: - Inline Layout

    private var inlineLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Symbol + timeframe + status
            HStack(spacing: 5) {
                UnifiedMarkerBadge(
                    intent: marker.intentEnum,
                    sizeToken: .tiny,
                    emoji: marker.intentEnum == .reaction ? reactionEmoji : nil
                )

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

            // Row 2: Tracking state (for setups)
            if let trackingState {
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
                            currentPrice: currentPrice,
                            targetPrice: marker.setupSummary?.tpPrice,
                            stopLossPrice: marker.setupSummary?.slPrice
                        )
                        ApproachingLevelChip(status: approachStatus)
                    }
                }
            }

            // Row 3: Marker specifics
            inlineSpecifics

            // Row 4: Timestamp
            Text(marker.displayTimestamp)
                .font(.caption2)
                .foregroundColor(AppColors.greyText.opacity(0.9))
        }
    }

    // MARK: - Shared Primary Content (used by capsule + card)

    private var capsuleTopRow: some View {
        HStack(spacing: 5) {
            Text(marker.symbolTicker)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            MarkerActivityMetaChip(
                icon: "clock",
                text: marker.timeframe.uppercased(),
                tint: AppColors.whiteText.opacity(0.8),
                background: AppColors.whiteText.opacity(0.08)
            )

            if let trackingState, trackingState.isLive {
                Text("LIVE")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.statusPositive70))
            } else if let trackingState, trackingState.isResolved == false {
                TrackingStatePill(state: trackingState, size: .compact)
            }

            if let approachingStatus {
                ApproachingLevelChip(status: approachingStatus)
            }

            if showMyBadge {
                Text("YOU")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.statusInfo60))
            }

            if marker.intentEnum == .setup, let summary = contextSummary {
                Text(summary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(contextSummaryColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var capsuleDetailSection: some View {
        MarkerListSpecificsSection {
            if hasExpandableContent {
                expandedContent
            } else {
                capsuleFallbackDetail
            }
        }
    }

    private var capsuleFooter: some View {
        UnifiedAuthorFooter(
            username: marker.authorUsername,
            isOnline: marker.authorIsOnline,
            role: RLMemberRole(from: marker.authorRole),
            reputation: marker.authorReputation,
            accuracy: marker.authorAccuracyFormatted,
            timeText: marker.displayTimestamp,
            cornerRadius: containerCornerRadius,
            showOnlineStatus: false
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var capsuleFallbackDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkerListSpecificsLabel(
                label: marker.intentEnum.displayName.uppercased(),
                color: marker.intentEnum.color
            )

            Text("Placed @ \(formatPrice(marker.price))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite78)
                .lineLimit(1)
        }
    }

    private var capsuleIconArea: some View {
        Button(action: onTap) {
            UnifiedMarkerBadge(
                intent: marker.intentEnum,
                sizeToken: .large,
                emoji: marker.intentEnum == .reaction ? reactionEmoji : nil
            )
                .frame(width: capsuleIconSize, height: capsuleIconSize)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if shouldShowIconLikeBadge {
                iconLikeBadge
                    .offset(x: -1, y: -1)
            }
        }
        .frame(width: capsuleIconSize, height: capsuleIconSize)
    }

    private var cardPrimaryContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(marker.symbolTicker)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.whiteText)

                MarkerActivityMetaChip(
                    icon: "clock",
                    text: marker.timeframe.uppercased(),
                    tint: AppColors.whiteText.opacity(0.85),
                    background: AppColors.whiteText.opacity(0.10)
                )

                if showMyBadge {
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.statusInfo60))
                }

                Spacer(minLength: 0)

                likeContent
            }

            if let trackingState {
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

                    if let approachingStatus {
                        ApproachingLevelChip(status: approachingStatus)
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }

            if hasExpandableContent {
                MarkerListSpecificsSection {
                    expandedContent
                }
            } else if hasNotePreview, let note = marker.notePreview {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.whiteText.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Like View

    private var likeContent: some View {
        HStack(spacing: 2) {
            Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                .font(.system(size: 9))
                .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
            Text("\(marker.likeCount)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(
            marker.isLikedByCurrentUser
                ? AppColors.markerHeartTint
                : AppColors.markerHeartMuted
        )
    }

    @ViewBuilder
    private var iconLikeBadge: some View {
        if let onLike {
            Button(action: onLike) {
                iconLikeBadgeContent
            }
            .buttonStyle(.plain)
        } else {
            iconLikeBadgeContent
        }
    }

    private var iconLikeBadgeContent: some View {
        Text("\(min(marker.likeCount, 99))")
            .font(.system(size: 7, weight: .bold))
        .foregroundColor(.white)
        .frame(minWidth: 14, minHeight: 14)
        .padding(.horizontal, marker.likeCount > 9 ? 2 : 0)
        .background(
            Capsule()
                .fill(AppColors.markerHeartBadge)
                .overlay(
                    Capsule()
                        .stroke(AppColors.markerHeartTint.opacity(0.35), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch marker.intentEnum {
        case .setup:
            VStack(alignment: .leading, spacing: 8) {
                if let outcome {
                    HStack(spacing: 6) {
                        if let pnl = outcome.pnl {
                            MarkerActivityMetaChip(
                                icon: outcome.isWin ? "arrow.up.right" : "arrow.down.right",
                                text: formatPnL(pnl),
                                tint: outcomeTint(outcome),
                                background: outcomeTint(outcome).opacity(0.15)
                            )
                        } else if outcome.isExpired {
                            MarkerActivityMetaChip(
                                icon: "clock.badge.xmark",
                                text: "No score impact",
                                tint: AppColors.surfaceGray90,
                                background: AppColors.surfaceWhite08
                            )
                        }

                        if let triggeredAt = outcome.triggeredAtFormatted {
                            Text(triggeredAt)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.surfaceWhite60)
                        }
                    }
                } else if let liveSetupMetrics {
                    MarkerActivityMetaChip(
                        icon: liveSetupMetrics.isMovingTowardTarget ? "waveform.path.ecg" : "arrow.down.right",
                        text: "Live \(formatPnL(liveSetupMetrics.currentPnL))",
                        tint: liveSetupMetrics.isMovingTowardTarget
                            ? RLComponentType.levelTp.color
                            : RLComponentType.levelSl.color,
                        background: liveSetupMetrics.isMovingTowardTarget
                            ? RLComponentType.levelTp.color.opacity(0.15)
                            : RLComponentType.levelSl.color.opacity(0.15)
                    )
                    UnifiedSetupProgressStrip(
                        metrics: liveSetupMetrics,
                        size: .standard,
                        formatPrice: formatPrice(_:)
                    )
                }

                if let note = marker.notePreview, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.surfaceWhite80)
                        .lineLimit(4)
                }
            }

        case .question, .poll:
            if let note = marker.notePreview, !note.isEmpty {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.surfaceWhite90)
                    .lineLimit(6)
            }

        case .alert:
            if let note = marker.notePreview, !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(marker.intentEnum.color)
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.surfaceWhite85)
                        .lineLimit(4)
                }
            }

        case .news, .analysis:
            if let note = marker.notePreview, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.surfaceWhite85)
                    .lineLimit(4)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Inline Specifics (for timeline style)

    @ViewBuilder
    private var inlineSpecifics: some View {
        switch marker.intentEnum {
        case .setup:
            if let liveSetupMetrics {
                MarkerListSpecificsSection {
                    UnifiedSetupProgressStrip(
                        metrics: liveSetupMetrics,
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

    // MARK: - Helpers

    private func outcomeTint(_ outcome: SetupOutcome) -> Color {
        if outcome.isWin { return AppColors.statusPositive70 }
        if outcome.isLoss { return AppColors.statusNegative70 }
        return AppColors.surfaceGray90
    }

    private func formatPnL(_ pnl: Double) -> String {
        String(format: "%@%.2f%%", pnl >= 0 ? "+" : "", pnl)
    }

    private func formatPrice(_ price: Double) -> String {
        let absolute = abs(price)
        if absolute >= 1000 {
            return String(format: "%.2f", price)
        }
        if absolute >= 1 {
            return String(format: "%.4f", price)
        }
        return String(format: "%.6f", price)
    }
}
