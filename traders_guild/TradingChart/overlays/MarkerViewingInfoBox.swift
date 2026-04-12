import Foundation
import SwiftUI

struct MarkerViewingInfoBox: View {
    let marker: ChartMarkerUI
    let chartWidth: CGFloat
    let yAxisWidth: CGFloat
    @Binding var isCollapsed: Bool
    let formatPrice: (Double) -> String
    var currentPrice: Double? = nil
    let isSubmittingPollVote: Bool
    let submittingPollVoteOptionId: UUID?
    let onVote: (UUID, UUID) -> Void

    private var expandedWidth: CGFloat {
        min(max(220, chartWidth * 0.34), max(244, chartWidth - yAxisWidth - 12))
    }

    private var setupApproachingStatus: MarkerPredictionProgressStatus? {
        guard marker.intent == .setup else { return nil }
        let status = MarkerPredictionProgress.status(
            entryPrice: marker.entryPrice ?? marker.price,
            currentPrice: currentPrice,
            targetPrice: marker.targetPrice,
            stopLossPrice: marker.stopLossPrice
        )
        return (status == .approachingTP || status == .approachingSL) ? status : nil
    }

    private var setupLiveMetrics: LiveSetupMetrics? {
        guard marker.intent == .setup,
              let targetPrice = marker.targetPrice,
              let stopLossPrice = marker.stopLossPrice else {
            return nil
        }
        return LiveSetupMetrics.compute(
            entryPrice: marker.entryPrice ?? marker.price,
            stopLossPrice: stopLossPrice,
            targetPrice: targetPrice,
            currentPrice: currentPrice
        )
    }

    private var setupOutcome: SetupOutcome? {
        guard marker.intent == .setup else { return nil }
        return MarkerPredictionProgress.outcomeDescription(for: marker.marker)
    }

    private var setupRiskRewardText: String? {
        let resolvedEntryPrice = marker.entryPrice ?? marker.horizontalLinePrice ?? marker.price
        guard let targetPrice = marker.targetPrice,
              let stopLossPrice = marker.stopLossPrice else {
            return nil
        }

        let reward = abs(targetPrice - resolvedEntryPrice)
        let risk = abs(resolvedEntryPrice - stopLossPrice)
        guard risk > 0.000_000_1, reward > 0 else { return nil }
        return String(format: "R:R %.2f", reward / risk)
    }

    private var setupResolvedDetailParts: [String] {
        guard let outcome = setupOutcome else { return [] }
        return [
            outcome.triggerPrice.map(formatPrice),
            outcome.triggeredAtFormatted
        ].compactMap { $0 }
    }

    private var setupOutcomePnlText: String? {
        guard let pnl = setupOutcome?.pnl else { return nil }
        return pnl >= 0 ? String(format: "+%.2f%%", pnl) : String(format: "%.2f%%", pnl)
    }

    private var setupOutcomePnlColor: Color {
        guard let outcome = setupOutcome, let pnl = outcome.pnl else { return AppColors.primaryForeground }
        return pnl >= 0 ? outcome.state.color : RLComponentType.levelSl.color
    }

    private var setupOutcomeRepTint: Color {
        guard let outcome = setupOutcome else { return AppColors.primaryForeground }
        return (outcome.guildRepDelta ?? 0) >= 0 ? outcome.state.color : RLComponentType.levelSl.color
    }

    private var reactionEmoji: String? {
        let trimmed = marker.selectedEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedStrip
            } else {
                expandedPanel
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
    }

    private var expandedPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OverlayPanelChrome.sideHandle(icon: "chevron.left")
                .onTapGesture { toggleCollapse() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: expandedWidth, alignment: .leading)
        .background(OverlayPanelChrome.background(cornerRadius: 12))
    }

    private var collapsedStrip: some View {
        VStack(spacing: 6) {
            UnifiedMarkerBadge(
                intent: marker.intent,
                alertSeverity: marker.alertSeverity,
                sizeToken: .tiny,
                emoji: marker.intent == .reaction ? reactionEmoji : nil
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.listRowChevronForeground)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(width: 30)
        .background(OverlayPanelChrome.background(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: toggleCollapse)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            UnifiedMarkerBadge(
                intent: marker.intent,
                alertSeverity: marker.alertSeverity,
                sizeToken: .small,
                emoji: marker.intent == .reaction ? reactionEmoji : nil
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(marker.intent.displayName) Marker")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Details")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch marker.intent {
        case .setup:
            setupContent

        case .analysis:
            bodyText(marker.note, placeholder: "No analysis text provided.")

        case .alert:
            VStack(alignment: .leading, spacing: 7) {
                if let severity = marker.alertSeverity {
                    HStack(spacing: 7) {
                        Image(systemName: severity.markerIcon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(severity.rawValue)
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(severity.color.opacity(0.45))
                            .overlay(
                                Capsule()
                                    .stroke(severity.color.opacity(0.68), lineWidth: 1)
                            )
                    )
                }
                bodyText(marker.note, placeholder: "No alert note.")
            }

        case .question:
            questionBodyText(
                marker.note,
                placeholder: "No question provided.",
                label: "QUESTION"
            )

        case .poll:
            pollContent

        case .news:
            if let newsURL {
                NewsLinkPreviewCard(
                    urlString: newsURL,
                    accentColor: marker.intent.color,
                    displayMode: .compact
                )
            } else {
                bodyText(marker.note, placeholder: "No link or note provided.")
            }

        case .reaction:
            if let reactionEmoji {
                HStack(spacing: 8) {
                    Text(reactionEmoji)
                        .font(.system(size: 22))
                    Text("Reaction selected")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.surfaceDetailSecondaryForeground)
                    Spacer(minLength: 0)
                }
            } else {
                bodyText(nil, placeholder: "No reaction selected.")
            }

        case .personal:
            bodyText(marker.note, placeholder: "Private marker.")
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        if let outcome = setupOutcome {
            resolvedSetupSummary(outcome)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    if let trackingState = marker.trackingState {
                        TrackingStatePill(state: trackingState, size: .compact)
                    }
                    if let approachingStatus = setupApproachingStatus {
                        ApproachingLevelChip(status: approachingStatus)
                    }
                }
                if let setupLiveMetrics {
                    UnifiedSetupProgressStrip(metrics: setupLiveMetrics, size: .compact)
                } else {
                    bodyText(nil, placeholder: "Setup levels unavailable.")
                }
            }
        }
    }

    private func resolvedSetupSummary(_ outcome: SetupOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let trackingState = marker.trackingState {
                    TrackingStatePill(state: trackingState, size: .compact)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: outcome.displayIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(outcome.state.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(outcome.displayLabel)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(AppColors.primaryForeground)

                    if !setupResolvedDetailParts.isEmpty {
                        Text(setupResolvedDetailParts.joined(separator: " · "))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(AppColors.overlayPanelSecondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                if let setupOutcomePnlText {
                    Text(setupOutcomePnlText)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(setupOutcomePnlColor)
                }
            }

            if setupRiskRewardText != nil || outcome.repChangeText != nil {
                HStack(spacing: 8) {
                    if let setupRiskRewardText {
                        compactOutcomeStat(
                            label: setupRiskRewardText,
                            tint: AppColors.surfaceWhite70
                        )
                    }

                    if let repText = outcome.repChangeText {
                        compactOutcomeStat(
                            label: "Rep \(repText)",
                            tint: setupOutcomeRepTint
                        )
                    }
                }
            }
        }
    }

    private func compactOutcomeStat(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private var pollContent: some View {
        let question = marker.resolvedPollQuestion ?? ""
        let options = marker.pollOptions ?? []
        let totalVotes = max(0, options.reduce(0) { $0 + $1.voteCount })

        return VStack(alignment: .leading, spacing: 7) {
            if !question.isEmpty {
                questionBodyText(
                    question,
                    placeholder: "No poll question.",
                    label: "POLL QUESTION"
                )
            }

            if options.isEmpty {
                bodyText(nil, placeholder: "No poll options.")
            } else {
                ForEach(options) { option in
                    pollOptionRow(option: option, totalVotes: totalVotes)
                }
            }
        }
    }

    private func pollOptionRow(option: RLPollOptionDTO, totalVotes: Int) -> some View {
        let isSelected = marker.userPollVote == option.id || option.hasVoted
        let isSubmitting = isSubmittingPollVote && submittingPollVoteOptionId == option.id
        let percentage = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

        return Button {
            onVote(marker.id, option.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.text)
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.65)
                            .tint(MarkerPollStyleTokens.progressSubmittingTint)
                    } else {
                        Text("\(option.voteCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? MarkerPollStyleTokens.selectedAccent : MarkerPollStyleTokens.unselectedCount)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(MarkerPollStyleTokens.progressBackground)
                        Capsule()
                            .fill(isSelected ? MarkerPollStyleTokens.progressSelected : MarkerPollStyleTokens.progressUnselected)
                            .frame(width: max(3, geometry.size.width * percentage))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? MarkerPollStyleTokens.selectedBackground : MarkerPollStyleTokens.unselectedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isSelected ? MarkerPollStyleTokens.selectedBorder : MarkerPollStyleTokens.unselectedBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmittingPollVote)
    }

    private func valueRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.primaryForeground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(AppColors.insetPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppColors.adaptiveOverlay18, lineWidth: 1)
                )
        )
    }

    private func bodyText(_ text: String?, placeholder: String) -> some View {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Text(value.isEmpty ? placeholder : value)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(value.isEmpty ? AppColors.surfaceDetailTertiaryForeground : AppColors.surfaceDetailPrimaryForeground)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(AppColors.insetPanelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(AppColors.adaptiveOverlay18, lineWidth: 1)
                    )
            )
    }

    private func questionBodyText(_ text: String?, placeholder: String, label: String) -> some View {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(AppColors.statusInfo90)
                .tracking(0.4)

            Text(value.isEmpty ? placeholder : value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(value.isEmpty ? AppColors.overlayPanelSecondaryText : AppColors.primaryForeground)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.statusInfo20,
                            AppColors.symbolDetailCardFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppColors.statusInfo50, lineWidth: 1)
                )
        )
    }

    private func toggleCollapse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isCollapsed.toggle()
        }
    }

    private var newsURL: String? {
        for component in marker.components {
            guard component.componentTypeEnum == .linkURL,
                  case let .link(payload) = component.payload else {
                continue
            }
            let value = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
