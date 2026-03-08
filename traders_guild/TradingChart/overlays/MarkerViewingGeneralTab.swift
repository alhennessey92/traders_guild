import SwiftUI

struct MarkerViewingGeneralTab: View {
    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    let onClose: () -> Void

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                heroPanel
                requirementsSection
                generalSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var heroPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(liveMarker.intent.color.opacity(0.25))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(liveMarker.intent.color.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: liveMarker.intent.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(liveMarker.intent.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(liveMarker.intent.subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
                Text(authorHandle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.whiteText.opacity(0.85))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    liveMarker.intent.color.opacity(0.32),
                    liveMarker.intent.color.opacity(0.15),
                    AppColors.whiteText.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(liveMarker.intent.color.opacity(0.32), lineWidth: 1)
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
            readOnlyTextBlock(questionText, placeholder: "No question provided")

        case .poll:
            VStack(alignment: .leading, spacing: 8) {
                readOnlyTextBlock(pollQuestionText, placeholder: "No poll question")

                if pollOptions.isEmpty {
                    placeholderText("No poll options")
                } else {
                    ForEach(pollOptions) { option in
                        HStack(spacing: 8) {
                            Text(option.text)
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(2)

                            Spacer(minLength: 0)

                            Text("\(option.voteCount)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppColors.greyText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.whiteText.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
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

            confidenceReadOnlyRow
            statsRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private var confidenceReadOnlyRow: some View {
        HStack(spacing: 8) {
            Text("Confidence")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= (liveMarker.confidence ?? 0) ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(
                            value <= (liveMarker.confidence ?? 0)
                                ? (Color(hex: "#FBBF24") ?? .yellow)
                                : AppColors.greyText.opacity(0.75)
                        )
                }
            }

            Spacer(minLength: 0)

            Text(liveMarker.confidence.map { "\($0)/5" } ?? "Not set")
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.greyText)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statBadge(title: "Likes", value: "\(liveMarker.likeCount)")
            statBadge(title: "Comments", value: "\(liveMarker.commentCount)")
            statBadge(title: "Components", value: "\(liveMarker.components.count)")
        }
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
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.24))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(tint)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
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
        let question = liveMarker.pollQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !question.isEmpty {
            return question
        }
        return trimmedNote
    }

    private var pollOptions: [RLPollOptionDTO] {
        liveMarker.pollOptions ?? []
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
            icon = "exclamationmark.octagon.fill"
        case .severe:
            title = "Severe"
            icon = "exclamationmark.triangle.fill"
        case .moderate:
            title = "Warning"
            icon = "exclamationmark.circle.fill"
        case .mild:
            title = "Informational"
            icon = "info.circle.fill"
        }
        color = severity.color
    }
}
