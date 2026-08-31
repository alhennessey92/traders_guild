import SwiftUI

struct MarkerViewingGeneralTab: View {
    @EnvironmentObject private var rlAppState: RLAppState
    @State private var showReportReasonSheet: Bool = false
    @State private var isSubmittingPollVote: Bool = false
    @State private var submittingPollVoteOptionId: UUID? = nil

    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    let onClose: () -> Void
    var symbolDTO: RLTradingSymbolDTO? = nil
    var onAuthorTap: (() -> Void)? = nil
    var canEditMarker: Bool = false
    var onEditMarker: ((ChartMarkerUI) -> Void)? = nil
    var onShareMarker: (() -> Void)? = nil

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy  HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private var liveMarker: ChartMarkerUI {
        markerManager.markers.first(where: { $0.id == marker.id }) ?? marker
    }

    private var orderedComponents: [RLMarkerComponentDTO] {
        liveMarker.components.sorted {
            if $0.ordering != $1.ordering { return $0.ordering < $1.ordering }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private var componentMetrics: MarkerViewingComponentMetrics {
        MarkerViewingComponentMetrics(marker: liveMarker)
    }

    private var isReportedMarker: Bool {
        rlAppState.hasReportedMarker(guildId: liveMarker.guildId, markerId: liveMarker.id)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                heroPanel
                markerSpecificsBox
                generalDisclosure
                symbolInfoDisclosure
                authorDisclosure
                if canShowShareAction {
                    shareMarkerButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showReportReasonSheet) {
            ReportReasonSheet(
                title: "Why are you reporting this marker?",
                includeScam: false,
                onReasonSelected: { reason in
                    handleReport(reason: reason)
                    showReportReasonSheet = false
                },
                onCancel: { showReportReasonSheet = false }
            )
        }
    }

    private var heroColor: Color {
        if liveMarker.intent == .alert, let severity = liveMarker.alertSeverity {
            return severity.color
        }
        return liveMarker.intent.color
    }

    private var heroPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            UnifiedMarkerBadge(
                intent: liveMarker.intent,
                alertSeverity: liveMarker.alertSeverity,
                sizeToken: .large,
                emoji: liveMarker.intent == .reaction ? reactionEmoji : nil,
                avatar: MarkerAvatarIdentity.forMarker(liveMarker)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(liveMarker.intent.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(liveMarker.intent.subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if canShowEditAction {
                heroEditButton
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    heroColor.opacity(0.32),
                    heroColor.opacity(0.15),
                    AppColors.componentsScaffoldHeaderNeutralEndpoint,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(heroColor.opacity(0.32), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var markerSpecificsBox: some View {
        requirementsContent
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.whiteText.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.whiteText.opacity(0.14), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private var requirementsContent: some View {
        switch liveMarker.intent {
        case .setup:
            VStack(spacing: 10) {
                if let outcome = MarkerPredictionProgress.outcomeDescription(for: liveMarker.marker) {
                    SetupOutcomeCard(
                        outcome: outcome,
                        size: .standard,
                        riskRewardText: setupRiskRewardText,
                        formatPrice: { formattedPrice($0) },
                        // Only where the same share affordance already exists —
                        // the card must not offer what the panel would refuse.
                        onShare: onShareMarker
                    )
                } else {
                    setupStateHeader
                    liveProgressSection
                }
                setupLevelsRow
            }

        case .analysis:
            readOnlyTextBlock(analysisText, placeholder: "No analysis provided")

        case .alert:
            VStack(alignment: .leading, spacing: 8) {
                if let alertPresentation {
                    HStack(spacing: 8) {
                        Image(systemName: alertPresentation.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(alertPresentation.title)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(alertPresentation.color.opacity(0.42))
                            .overlay(
                                Capsule()
                                    .stroke(alertPresentation.color.opacity(0.66), lineWidth: 1)
                            )
                    )
                } else {
                    placeholderText("Severity not set")
                }

                if !alertBodyText.isEmpty {
                    readOnlyTextBlock(alertBodyText, placeholder: "No alert note")
                }
            }

        case .question:
            readOnlyQuestionBlock(
                questionText,
                placeholder: "No question provided",
                label: "QUESTION"
            )

        case .poll:
            VStack(alignment: .leading, spacing: 8) {
                readOnlyQuestionBlock(
                    pollQuestionText,
                    placeholder: "No poll question",
                    label: "POLL QUESTION"
                )

                if pollOptions.isEmpty {
                    placeholderText("No poll options")
                } else {
                    ForEach(pollOptions) { option in
                        let isSelected = selectedPollOptionId == option.id || option.hasVoted
                        let isSubmitting = isSubmittingPollVote && submittingPollVoteOptionId == option.id

                        Button {
                            handlePollVote(optionId: option.id)
                        } label: {
                            HStack(spacing: 8) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MarkerPollStyleTokens.selectedAccent)
                                }

                                Text(option.text)
                                    .font(.caption.weight(isSelected ? .semibold : .regular))
                                    .foregroundColor(AppColors.primaryForeground)
                                    .lineLimit(2)

                                Spacer(minLength: 0)

                                if isSubmitting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(MarkerPollStyleTokens.progressSubmittingTint)
                                } else {
                                    Text("\(option.voteCount)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(isSelected ? MarkerPollStyleTokens.selectedAccent : MarkerPollStyleTokens.unselectedCount)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? MarkerPollStyleTokens.selectedBackground : MarkerPollStyleTokens.unselectedBackground)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                isSelected ? MarkerPollStyleTokens.selectedBorder : MarkerPollStyleTokens.unselectedBorder,
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmittingPollVote)
                    }
                }
            }

        case .news:
            if let newsURL {
                NewsLinkPreviewCard(
                    urlString: newsURL,
                    accentColor: liveMarker.intent.color
                )
            } else {
                placeholderText("No link attached")
            }

        case .reaction:
            if let reactionEmoji, !reactionEmoji.isEmpty {
                HStack(spacing: 10) {
                    Text(reactionEmoji)
                        .font(.system(size: 26))
                    Text("Reaction selected")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
            } else {
                placeholderText("No reaction selected")
            }

        case .personal:
            placeholderText("No additional requirements")
        }
    }

    private var generalDisclosure: some View {
        UnifiedDisclosureGroupCustomHeader(isExpandedByDefault: false) { isExpanded in
            disclosureHeader(
                title: "General",
                icon: "square.grid.2x2.fill",
                isExpanded: isExpanded
            )
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                if let title = liveMarker.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    readOnlyMetaRow(title: "Title", value: title)
                }

                readOnlyMetaRow(
                    title: "Description",
                    value: generalDescriptionText.isEmpty ? "No description" : generalDescriptionText
                )

                HStack(spacing: 8) {
                    Text("Visibility")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)

                    Text(visibilityLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.onAccentForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(visibilityColor.opacity(0.38)))
                }

                statsRow

                if !liveMarker.isCurrentUserMarker {
                    if isReportedMarker {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Reported")
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(AppColors.statusNegative95)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.statusNegative35)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.statusNegative70, lineWidth: 1)
                                )
                        )
                    } else {
                        Button {
                            HapticFeedback.medium.trigger()
                            showReportReasonSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Report Marker")
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundColor(AppColors.statusNegative92)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.statusNegative20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(AppColors.statusNegative40, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(disclosureContentBackground())
        }
    }

    private func handleReport(reason: String) {
        Task {
            do {
                _ = try await rlAppState.reportMarker(
                    guildId: liveMarker.guildId,
                    markerId: liveMarker.id,
                    reason: reason
                )
            } catch {
                return
            }
        }
    }

    private var statsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statBadge(title: "Likes", value: "\(liveMarker.likeCount)")
                statBadge(title: "Comments", value: "\(liveMarker.commentCount)")
                statBadge(title: "Components", value: "\(componentMetrics.displayedComponentCount)")
            }
            HStack(spacing: 8) {
                if let confidence = liveMarker.confidence {
                    // Confidence is a 1-5 rating, not a percentage — a % sign made maximum
                    // conviction read as "5%". Matches Android's MarkerDetailSheet.
                    statBadge(title: "Confidence", value: "\(confidence)/5")
                }
                let tfCount = componentMetrics.timeframeComponents.count
                if tfCount > 0 {
                    statBadge(title: "Timeframes", value: "\(tfCount)")
                }
            }
        }
    }

    private var canShowEditAction: Bool {
        canEditMarker &&
        onEditMarker != nil
    }

    private var heroEditButton: some View {
        Button {
            onEditMarker?(liveMarker)
            HapticFeedback.light.trigger()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .bold))
                Text("Edit")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(AppColors.primaryForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.whiteText.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var setupStateHeader: some View {
        let state = liveMarker.trackingState ?? .draft
        return HStack(spacing: 8) {
            TrackingStatePill(state: state, size: .standard)
            Spacer(minLength: 0)
            Text(liveMarker.timeframe.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.primaryForeground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.whiteText.opacity(0.10))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.whiteText.opacity(0.16), lineWidth: 1)
                        )
                )
        }
    }

    private var setupRiskRewardText: String? {
        guard let entry = setupEntryPrice,
              let tp = setupTpPrice,
              let sl = setupSlPrice else { return nil }
        let reward = abs(tp - entry)
        let risk = abs(entry - sl)
        guard risk > 0.000_000_1, reward > 0 else { return nil }
        return String(format: "R:R %.2f", reward / risk)
    }

    private var setupLevelsRow: some View {
        HStack(spacing: 8) {
            setupLevelCell(title: "Entry", value: formattedPrice(setupEntryPrice), color: RLComponentType.levelEntry.color)
            setupLevelCell(title: "TP", value: formattedPrice(setupTpPrice), color: RLComponentType.levelTp.color)
            setupLevelCell(title: "SL", value: formattedPrice(setupSlPrice), color: RLComponentType.levelSl.color)
        }
    }

    private func setupLevelCell(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(color)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.primaryForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var liveProgressSection: some View {
        let state = liveMarker.trackingState ?? .draft
        if state.isLive,
           let entryPrice = setupEntryPrice,
           let tpPrice = setupTpPrice,
           let slPrice = setupSlPrice,
           let currentPrice = symbolDTO?.currentPrice,
           let metrics = LiveSetupMetrics.compute(
               entryPrice: entryPrice,
               stopLossPrice: slPrice,
               targetPrice: tpPrice,
               currentPrice: currentPrice
           ) {
            UnifiedSetupProgressStrip(
                metrics: metrics,
                size: .detail,
                formatPrice: { formattedPrice($0) }
            )
        }
    }

    private func readOnlyTextBlock(_ text: String, placeholder: String) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.caption)
            .foregroundColor(text.isEmpty ? AppColors.greyText : AppColors.primaryForeground)
            .lineLimit(nil)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func readOnlyQuestionBlock(_ text: String, placeholder: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(AppColors.statusInfo90)
                .tracking(0.4)

            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(text.isEmpty ? AppColors.surfaceWhite74 : AppColors.surfaceWhite96)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.statusInfo20,
                            AppColors.whiteText.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.statusInfo50, lineWidth: 1)
                )
        )
    }

    private func readOnlyMetaRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            readOnlyTextBlock(value, placeholder: "Not set")
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            .padding(.vertical, 4)
    }

    private func statBadge(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func disclosureHeader(
        title: String,
        icon: String,
        isExpanded: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.disclosureHeaderIconForeground)
                .frame(width: 18)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.disclosureChevronForeground)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [AppColors.searchBarGradientLeading, AppColors.searchBarGradientTrailing],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }

    private var symbolInfoDisclosure: some View {
        UnifiedDisclosureGroupCustomHeader(isExpandedByDefault: false) { isExpanded in
            disclosureHeader(
                title: "Symbol Info",
                icon: "chart.xyaxis.line",
                isExpanded: isExpanded
            )
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                // Symbol hero card with avatar
                if let symbol = symbolDTO {
                    HStack(spacing: 12) {
                        TradingSymbolIconView(symbol: symbol, size: 40, cornerRadiusRatio: 0.22)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(symbol.ticker)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(AppColors.primaryForeground)
                            HStack(spacing: 6) {
                                Text(symbol.displayName)
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                    .lineLimit(1)
                                Text(symbol.assetClass.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.whiteText.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                            }
                        }

                        Spacer(minLength: 0)

                        // Live price + 24h change
                        if let priceStr = symbol.priceFormatted {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(priceStr)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(AppColors.primaryForeground)
                                if let changeStr = symbol.changeFormatted {
                                    let isUp = symbol.isUp ?? false
                                    Text(changeStr)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(isUp ? AppColors.markerPositiveForeground : AppColors.statusNegative85)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.whiteText.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                // Placement metadata chips
                HStack(spacing: 8) {
                    metaChip(label: liveMarker.timeframe.uppercased(), icon: "clock")
                    metaChip(
                        label: Self.priceFormatter.string(from: NSNumber(value: liveMarker.price)) ?? "\(liveMarker.price)",
                        icon: "tag"
                    )
                    if let confidence = liveMarker.confidence {
                        metaChip(label: "\(confidence)/5", icon: "gauge.with.needle")
                    }
                }

                // Placement time details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Placed")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Self.fullDateFormatter.string(from: liveMarker.createdAt))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppColors.primaryForeground)
                            Text(liveMarker.createdAtFormatted)
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Candle Time")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer(minLength: 0)
                        Text(Self.fullDateFormatter.string(from: liveMarker.candleTimestamp))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.primaryForeground)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .padding(12)
            .background(disclosureContentBackground())
        }
    }

    private func metaChip(label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.greyText)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var authorDisclosure: some View {
        UnifiedDisclosureGroupCustomHeader(isExpandedByDefault: false) { isExpanded in
            disclosureHeader(
                title: "Author",
                icon: "person.circle.fill",
                isExpanded: isExpanded
            )
        } content: {
            Button {
                onAuthorTap?()
            } label: {
                HStack(spacing: 10) {
                    UnifiedMemberAvatar(
                        username: liveMarker.author.username,
                        avatarURL: liveMarker.author.avatarUrl,
                        isOnline: liveMarker.author.isOnline,
                        size: 36,
                        showOnlineIndicator: true
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(authorHandle)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)

                        HStack(spacing: 6) {
                            Text(liveMarker.author.memberRole.displayName)
                            Text("Rep \(liveMarker.author.reputation)")
                            if let acc = liveMarker.author.accuracyFormatted {
                                Text("Acc \(acc)")
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(12)
            .background(disclosureContentBackground())
        }
    }

    private var canShowShareAction: Bool {
        onShareMarker != nil &&
        MarkerShare.canShareWithinGuild(visibility: liveMarker.visibility)
    }

    private var isAuthoredByCurrentUser: Bool {
        if liveMarker.isCurrentUserMarker {
            return true
        }
        guard let currentUserId = rlAppState.currentUser?.id else { return false }
        return liveMarker.author.userId == currentUserId
    }

    private var shareMarkerSubtitle: String {
        if isAuthoredByCurrentUser {
            return "Share with your guild or post to X, Discord & more."
        }
        return "Send this guild marker directly to another member."
    }

    private var shareMarkerButton: some View {
        Button {
            onShareMarker?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.onAccentForeground.opacity(0.16))
                        .frame(width: 42, height: 42)

                    if liveMarker.intent == .reaction,
                       let emoji = reactionEmoji,
                       !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 20, weight: .semibold))
                    } else {
                        Image(
                            systemName: MarkerVisualSpec.symbol(
                                for: liveMarker.intent,
                                severity: liveMarker.alertSeverity
                            )
                        )
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(AppColors.onAccentForeground)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Share Marker")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.onAccentForeground)

                    Text(shareMarkerSubtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppColors.onAccentForeground.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.onAccentForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.friendAccent.opacity(0.96),
                                AppColors.statusPositive70.opacity(0.82),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.onAccentForeground.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func disclosureContentBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.whiteText.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.whiteText.opacity(0.11), lineWidth: 1)
            )
    }

    private func sectionCardBackground(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [AppColors.whiteText.opacity(0.10), AppColors.whiteText.opacity(0.075)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
            )
    }

    private var authorHandle: String {
        let username = liveMarker.author.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return "Unknown author" }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    private var setupEntryPrice: Double? {
        liveMarker.entryPrice ?? liveMarker.anchorComponent?.payload.levelPrice ?? liveMarker.price
    }

    private var setupTpPrice: Double? {
        liveMarker.targetPrice ?? componentPrice(.levelTp)
    }

    private var setupSlPrice: Double? {
        liveMarker.stopLossPrice ?? componentPrice(.levelSl)
    }

    private var analysisText: String {
        trimmedNote
    }

    private var questionText: String {
        let trimmedTitle = liveMarker.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return trimmedNote
    }

    private var pollQuestionText: String {
        liveMarker.resolvedPollQuestion ?? ""
    }

    private var pollOptions: [RLPollOptionDTO] {
        liveMarker.pollOptions ?? []
    }

    private var selectedPollOptionId: UUID? {
        liveMarker.userPollVote
    }

    private func handlePollVote(optionId: UUID) {
        guard !isSubmittingPollVote else { return }
        isSubmittingPollVote = true
        submittingPollVoteOptionId = optionId

        Task {
            defer {
                isSubmittingPollVote = false
                submittingPollVoteOptionId = nil
            }

            do {
                try await markerManager.voteOnPoll(markerId: liveMarker.id, optionId: optionId)
                HapticFeedback.light.trigger()
            } catch {
                print("Failed to vote on poll marker from detail view: \(error)")
            }
        }
    }

    private var newsURL: String? {
        for component in orderedComponents where component.componentTypeEnum == .linkURL {
            guard case let .link(payload) = component.payload else { continue }
            let trimmed = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private var reactionEmoji: String? {
        if let emoji = liveMarker.selectedEmoji?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
            return emoji
        }
        for component in orderedComponents where component.componentTypeEnum == .reactionEmoji {
            guard case let .reactionEmoji(payload) = component.payload else { continue }
            let trimmed = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private var generalDescriptionText: String {
        trimmedNote
    }

    private var visibilityLabel: String {
        let trimmed = liveMarker.visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "private" ? "Private" : "Guild"
    }

    private var visibilityColor: Color {
        visibilityLabel == "Private"
            ? Color(hex: "#6B7280") ?? .gray
            : liveMarker.intent.color
    }

    private var trimmedNote: String {
        liveMarker.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var alertBodyText: String {
        stripExistingSeverityPrefix(from: trimmedNote)
    }

    private var alertPresentation: AlertPresentation? {
        if let severity = liveMarker.alertSeverity {
            return AlertPresentation(from: severity)
        }

        let value = trimmedNote
        if value.hasPrefix("[Critical] ") { return AlertPresentation(from: .critical) }
        if value.hasPrefix("[Severe] ") { return AlertPresentation(from: .severe) }
        if value.hasPrefix("[Warning] ") { return AlertPresentation(from: .moderate) }
        if value.hasPrefix("[Informational] ") { return AlertPresentation(from: .mild) }
        return nil
    }

    private func stripExistingSeverityPrefix(from text: String) -> String {
        let knownPrefixes = [
            "[Critical] ",
            "[Severe] ",
            "[Warning] ",
            "[Informational] ",
        ]
        for prefix in knownPrefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }

    private func component(_ type: RLComponentType) -> RLMarkerComponentDTO? {
        orderedComponents.first { $0.componentTypeEnum == type }
    }

    private func componentPrice(_ type: RLComponentType) -> Double? {
        component(type)?.payload.levelPrice
    }

    private func formattedPrice(_ value: Double?) -> String {
        guard let value else { return "Not set" }
        return Self.priceFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.5f", value)
    }
}

private struct AlertPresentation {
    let title: String
    let icon: String
    let color: Color

    init(from severity: MarkerAlertSeverity) {
        switch severity {
        case .critical:
            title = "Critical"
        case .severe:
            title = "Severe"
        case .moderate:
            title = "Warning"
        case .mild:
            title = "Informational"
        }
        icon = severity.markerIcon
        color = severity.color
    }
}
