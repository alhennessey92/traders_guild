import SwiftUI

struct MarkerViewingGeneralTab: View {
    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    let onClose: () -> Void
    var symbolDTO: RLTradingSymbolDTO? = nil
    var onAuthorTap: (() -> Void)? = nil
    var canEditMarker: Bool = false
    var onEditMarker: ((ChartMarkerUI) -> Void)? = nil

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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                heroPanel
                requirementsSection
                generalSection
                symbolInfoSection
                authorSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                sizeToken: .large
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(liveMarker.intent.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
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
                    AppColors.whiteText.opacity(0.06),
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

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Requirements",
                subtitle: "Intent-specific details",
                icon: "list.bullet.clipboard",
                tint: liveMarker.intent.color
            )
            requirementsContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    @ViewBuilder
    private var requirementsContent: some View {
        switch liveMarker.intent {
        case .setup:
            VStack(spacing: 8) {
                readOnlyValueRow(
                    title: "Entry",
                    value: formattedPrice(setupEntryPrice),
                    color: RLComponentType.levelEntry.color
                )
                readOnlyValueRow(
                    title: "Take Profit",
                    value: formattedPrice(setupTpPrice),
                    color: RLComponentType.levelTp.color
                )
                readOnlyValueRow(
                    title: "Stop Loss",
                    value: formattedPrice(setupSlPrice),
                    color: RLComponentType.levelSl.color
                )
                trackingBadge
                outcomeResultCard
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
                    .foregroundColor(.white)
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
                        HStack(spacing: 8) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MarkerPollStyleTokens.selectedAccent)
                            }

                            Text(option.text)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            Spacer(minLength: 0)

                            Text("\(option.voteCount)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(isSelected ? MarkerPollStyleTokens.selectedAccent : MarkerPollStyleTokens.unselectedCount)
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
                }
            }

        case .news:
            if let newsURL {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(liveMarker.intent.color)
                    Text(newsURL)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(2)
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

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "General",
                subtitle: "Description and metadata",
                icon: "square.grid.2x2.fill",
                tint: AppColors.whiteText.opacity(0.85)
            )

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
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(visibilityColor.opacity(0.38)))
            }

            statsRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
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
                    statBadge(title: "Confidence", value: "\(confidence)%")
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
            .foregroundColor(.white)
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

    private var trackingBadge: some View {
        let stateLabel = liveMarker.trackingState?.displayName
            ?? (liveMarker.trackingEnabled ? "Tracking" : "Not Tracked")
        let stateColor = liveMarker.trackingState?.color
            ?? (liveMarker.trackingEnabled ? liveMarker.intent.color : AppColors.greyText)

        return HStack(spacing: 8) {
            Text("Tracked")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            Text(stateLabel.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(stateColor.opacity(0.38))
                        .overlay(
                            Capsule()
                                .stroke(stateColor.opacity(0.62), lineWidth: 1)
                        )
                )
        }
    }

    @ViewBuilder
    private var outcomeResultCard: some View {
        if let outcome = MarkerPredictionProgress.outcomeDescription(for: liveMarker.marker) {
            VStack(alignment: .leading, spacing: 8) {
                // Outcome header
                HStack(spacing: 8) {
                    Image(systemName: outcome.displayIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(outcome.state.color)

                    Text("Outcome")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)

                    Spacer(minLength: 0)

                    Text(outcome.displayLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(outcome.state.color.opacity(0.42))
                                .overlay(
                                    Capsule()
                                        .stroke(outcome.state.color.opacity(0.62), lineWidth: 1)
                                )
                        )
                }

                // Trigger price
                if let triggerPrice = outcome.triggerPrice {
                    HStack(spacing: 8) {
                        Text("Trigger Price")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer(minLength: 0)
                        Text(formattedPrice(triggerPrice))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                // P&L
                if let pnl = outcome.pnl {
                    HStack(spacing: 8) {
                        Text("P&L")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer(minLength: 0)
                        Text(pnl >= 0 ? "+\(formattedPrice(pnl))" : formattedPrice(pnl))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(pnl >= 0 ? AppColors.statusPositive90 : AppColors.statusNegative85)
                    }
                }

                // Triggered time
                if let triggeredAt = outcome.triggeredAtFormatted {
                    HStack(spacing: 8) {
                        Text("Resolved")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Spacer(minLength: 0)
                        Text(triggeredAt)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.whiteText.opacity(0.7))
                    }
                }

                // Tracking impact note
                if outcome.isTracked {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .semibold))
                        Text("This result affected your accuracy and reputation")
                            .font(.caption2)
                    }
                    .foregroundColor(outcome.isWin ? AppColors.statusPositive90 : AppColors.statusNegative85)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                outcome.state.color.opacity(0.15),
                                outcome.state.color.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(outcome.state.color.opacity(0.28), lineWidth: 1)
                    )
            )
        }
    }

    private func readOnlyValueRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
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
    }

    private func readOnlyTextBlock(_ text: String, placeholder: String) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.caption)
            .foregroundColor(text.isEmpty ? AppColors.greyText : .white)
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
                .foregroundColor(.white)
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

    private func sectionHeader(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint.opacity(0.22))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.22),
                            tint.opacity(0.12),
                            AppColors.whiteText.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tint.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private var symbolInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Symbol Info",
                subtitle: "Placement context",
                icon: "chart.xyaxis.line",
                tint: AppColors.whiteText.opacity(0.85)
            )

            // Symbol hero card with avatar
            if let symbol = symbolDTO {
                HStack(spacing: 12) {
                    TradingSymbolIconView(symbol: symbol, size: 40, cornerRadiusRatio: 0.22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(symbol.ticker)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
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
                                .foregroundColor(.white)
                            if let changeStr = symbol.changeFormatted {
                                let isUp = symbol.isUp ?? false
                                Text(changeStr)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(isUp ? AppColors.statusPositive90 : AppColors.statusNegative85)
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
                    metaChip(label: "\(confidence)%", icon: "gauge.with.needle")
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
                            .foregroundColor(.white)
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
                        .foregroundColor(.white)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private func metaChip(label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.greyText)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
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

    private var authorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Author",
                subtitle: "Marker creator",
                icon: "person.circle.fill",
                tint: AppColors.whiteText.opacity(0.85)
            )

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
                            .foregroundColor(.white)

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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private func sectionCardBackground(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [AppColors.whiteText.opacity(0.07), AppColors.whiteText.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1)
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
        trimmedNote
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
