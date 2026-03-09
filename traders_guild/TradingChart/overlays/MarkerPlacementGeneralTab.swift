import SwiftUI

struct MarkerPlacementGeneralTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    @State private var intentChangeWarning: String?
    @State private var pendingIntentSwitch: PendingIntentSwitch?
    @State private var isIntentPickerExpanded = false

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }()

    private let alertSeverityOptions: [AlertSeverityOption] = [
        .init(
            label: "Critical",
            icon: "exclamationmark.octagon.fill",
            severity: .critical,
            defaultMessage: "Critical alert"
        ),
        .init(
            label: "Severe",
            icon: "exclamationmark.triangle.fill",
            severity: .severe,
            defaultMessage: "Severe alert"
        ),
        .init(
            label: "Warning",
            icon: "exclamationmark.shield.fill",
            severity: .moderate,
            defaultMessage: "Warning alert"
        ),
        .init(
            label: "Informational",
            icon: "info.circle.fill",
            severity: .mild,
            defaultMessage: "Informational alert"
        ),
    ]

    private let reactionEmojis: [String] = [
        "🎯", "🔥", "🐻", "🐂", "✅", "❌",
        "🚀", "⚡", "💡", "📉", "📈", "⏳",
        "🧠", "💰", "🛑", "🎉", "👀", "📝",
        "😬", "🤔", "🙌", "💥", "🔍", "📌",
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                heroPanel

                if isIntentPickerExpanded {
                    intentPicker
                }

                requirementsSection
                generalSection
            }
            .padding(.trailing, 2)
        }
        .onAppear {
            syncNewsURLFromComponent()
            if placementState.alertSeverity == nil {
                placementState.alertSeverity = inferredAlertSeverity(from: placementState.note)
            }
        }
        .alert(item: $pendingIntentSwitch) { pending in
            Alert(
                title: Text("Switch to \(pending.targetIntent.displayName)?"),
                message: Text("This removes incompatible components: \(pending.incompatibleComponentSummary)."),
                primaryButton: .destructive(Text("Remove and Switch")) {
                    applyIntentSwitch(pending)
                },
                secondaryButton: .cancel {
                    pendingIntentSwitch = nil
                }
            )
        }
    }

    private var heroPanel: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isIntentPickerExpanded.toggle()
            }
            HapticFeedback.light.trigger()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    UnifiedMarkerBadge(
                        intent: placementState.intent,
                        alertSeverity: placementState.intent == .alert ? placementState.alertSeverity : nil,
                        sizeToken: .large
                    )

                    Circle()
                        .fill(AppColors.sheetBackground.opacity(0.96))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "arrow.2.circlepath")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppColors.whiteText.opacity(0.9))
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(placementState.intent.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text(placementState.intent.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: isIntentPickerExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.whiteText.opacity(0.75))
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        placementState.intent.color.opacity(0.32),
                        placementState.intent.color.opacity(0.15),
                        AppColors.whiteText.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(placementState.intent.color.opacity(0.32), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var intentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap to switch marker type")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)

            let columns = [
                GridItem(.adaptive(minimum: 96), spacing: 8),
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(RLMarkerIntent.allCases, id: \.rawValue) { intent in
                    intentPickerCard(for: intent)
                }
            }

            if let intentChangeWarning {
                Text(intentChangeWarning)
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.95))
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(sectionCardBackground())
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Requirements",
                subtitle: "Intent-specific fields",
                icon: "list.bullet.clipboard",
                tint: placementState.intent == .setup && placementState.trackingEnabled
                    ? .green
                    : placementState.intent.color
            )
            requirementsContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    @ViewBuilder
    private var requirementsContent: some View {
        switch placementState.intent {
        case .setup:
            VStack(spacing: 10) {
                levelInputRow(
                    title: "Take Profit",
                    componentType: .levelTp,
                    color: RLComponentType.levelTp.color
                )
                levelInputRow(
                    title: "Stop Loss",
                    componentType: .levelSl,
                    color: RLComponentType.levelSl.color
                )
                Toggle(isOn: $placementState.trackingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tracked Setup")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        Text("Monitor entry, SL, and TP transitions")
                            .foregroundColor(AppColors.greyText)
                            .font(.caption)
                    }
                }
                .tint(placementState.trackingEnabled ? .green : placementState.intent.color)

                if placementState.trackingEnabled {
                    trackedSetupBanner
                    trackedSetupRepChips
                }
            }

        case .analysis:
            placementInputField("Write analysis context", text: $placementState.note, axis: .vertical)
                .lineLimit(3...6)

        case .alert:
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(alertSeverityOptions) { option in
                    alertSeverityButton(option)
                }
            }

        case .question:
            placementInputField("Type your question", text: $placementState.note, axis: .vertical)
                .lineLimit(3...5)

        case .poll:
            pollFields

        case .news:
            placementInputField("https://example.com/news-link", text: newsURLBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

        case .reaction:
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(reactionEmojis, id: \.self) { emoji in
                    Button {
                        placementState.upsertComponent(
                            .reactionEmoji,
                            payload: .reactionEmoji(EmojiPayload(emoji: emoji))
                        )
                        HapticFeedback.light.trigger()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 19))
                            .frame(height: 34)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(currentReactionEmoji == emoji ? placementState.intent.color.opacity(0.35) : AppColors.whiteText.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                currentReactionEmoji == emoji
                                                    ? placementState.intent.color.opacity(0.6)
                                                    : AppColors.whiteText.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .personal:
            Text("No additional requirements")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .padding(.vertical, 4)
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "General",
                subtitle: "Metadata and summary",
                icon: "square.grid.2x2.fill",
                tint: AppColors.whiteText.opacity(0.85)
            )

            placementInputField("Title (optional)", text: $placementState.title)

            placementInputField("Description / Note", text: $placementState.note, axis: .vertical)
                .lineLimit(2...5)
                .onChange(of: placementState.note) { _, newValue in
                    if placementState.component(.textNote) != nil {
                        placementState.upsertComponent(.textNote, payload: .note(NotePayload(text: newValue)))
                    }
                }

            statsRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private func intentPickerCard(for intent: RLMarkerIntent) -> some View {
        let isSelected = placementState.intent == intent
        return Button {
            handleIntentSelection(intent)
        } label: {
            VStack(spacing: 6) {
                UnifiedMarkerBadge(
                    intent: intent,
                    alertSeverity: intent == .alert ? placementState.alertSeverity : nil,
                    sizeToken: .small,
                    isSelected: isSelected
                )

                Text(intent.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 74)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? intent.color.opacity(0.22) : AppColors.whiteText.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                    ? intent.color.opacity(0.6)
                                    : AppColors.whiteText.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func levelInputRow(
        title: String,
        componentType: RLComponentType,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)

            Spacer(minLength: 0)

            TextField("0.0", value: levelValueBinding(for: componentType), formatter: Self.priceFormatter)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
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
                .frame(width: 132)
        }
    }

    private var trackedSetupBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.green.opacity(0.95))
            VStack(alignment: .leading, spacing: 1) {
                Text("Tracking Mode Active")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text("Estimated reputation impact now shown")
                    .font(.caption2)
                    .foregroundColor(.green.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var trackedSetupRepChips: some View {
        HStack(spacing: 8) {
            trackedRepChip(
                title: "Rep + (est)",
                value: placementState.estimatedTrackingRepGain.map { "+\($0)" } ?? "—",
                tint: .green
            )
            trackedRepChip(
                title: "Rep - (est)",
                value: placementState.estimatedTrackingRepLoss.map { "-\($0)" } ?? "—",
                tint: .red
            )
        }
    }

    private func trackedRepChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.greyText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(tint.opacity(0.95))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(0.32), lineWidth: 1)
                )
        )
    }

    private func levelValueBinding(for type: RLComponentType) -> Binding<Double> {
        Binding<Double>(
            get: {
                placementState.componentPrice(type)
                    ?? placementState.anchorDraft?.payload.levelPrice
                    ?? 0
            },
            set: { newValue in
                switch type {
                case .levelTp:
                    placementState.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: newValue, label: "TP")))
                case .levelSl:
                    placementState.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: newValue, label: "SL")))
                case .levelSupport:
                    placementState.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: newValue, label: "Support")))
                case .levelResistance:
                    placementState.upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: newValue, label: "Resistance")))
                case .levelEntry:
                    placementState.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: newValue, label: "Entry")))
                default:
                    break
                }
            }
        )
    }

    private func alertSeverityButton(_ option: AlertSeverityOption) -> some View {
        let isSelected = placementState.alertSeverity == option.severity
        let severityColor = option.severity.color
        return Button {
            applyAlertSeverity(option)
            HapticFeedback.light.trigger()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 15, weight: .bold))
                Text(option.label)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundColor(isSelected ? .white : severityColor.opacity(0.92))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? severityColor.opacity(0.38) : severityColor.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                    ? severityColor.opacity(0.72)
                                    : severityColor.opacity(0.35),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var pollFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            placementInputField("Poll question", text: $placementState.pollQuestion)

            ForEach(placementState.pollOptions.indices, id: \.self) { idx in
                HStack(spacing: 8) {
                    placementInputField("Option \(idx + 1)", text: $placementState.pollOptions[idx])
                    if placementState.pollOptions.count > 2 {
                        Button {
                            placementState.pollOptions.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                placementState.pollOptions.append("")
            } label: {
                Label("Add option", systemImage: "plus.circle.fill")
                    .font(.caption)
                    .foregroundColor(placementState.intent.color)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func placementInputField(
        _ title: String,
        text: Binding<String>,
        axis: Axis = .horizontal
    ) -> some View {
        TextField(title, text: text, axis: axis)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.whiteText.opacity(0.09), AppColors.whiteText.opacity(0.06)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                    )
            )
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statBadge(title: "Components", value: "\(placementState.components.count)")
            statBadge(title: "Drawings", value: "\(placementState.drawingOverlayCount)")
            statBadge(title: "Timeframes", value: "\(placementState.timeframeLinkCount)")
        }
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

    private var newsURLBinding: Binding<String> {
        Binding<String>(
            get: { placementState.newsURL },
            set: { newValue in
                placementState.newsURL = newValue
                syncNewsComponent(with: newValue)
            }
        )
    }

    private var currentReactionEmoji: String? {
        guard case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload else {
            return nil
        }
        return payload.emoji
    }

    private func syncNewsURLFromComponent() {
        guard placementState.newsURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard case let .link(payload)? = placementState.component(.linkURL)?.payload else { return }
        placementState.newsURL = payload.url
    }

    private func syncNewsComponent(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            placementState.removeComponent(.linkURL)
            return
        }

        let existingTitle: String?
        if case let .link(payload)? = placementState.component(.linkURL)?.payload {
            existingTitle = payload.title
        } else {
            existingTitle = nil
        }

        placementState.upsertComponent(
            .linkURL,
            payload: .link(LinkPayload(url: trimmed, title: existingTitle, previewImage: nil))
        )
    }

    private func applyAlertSeverity(_ option: AlertSeverityOption) {
        placementState.alertSeverity = option.severity

        let trimmed = placementState.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseWithoutSeverity = stripExistingSeverityPrefix(from: trimmed)
        let base = baseWithoutSeverity.isEmpty ? option.defaultMessage : baseWithoutSeverity
        placementState.note = "[\(option.label)] \(base)"
        placementState.upsertComponent(
            .textNote,
            payload: .note(NotePayload(text: placementState.note))
        )
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

    private func inferredAlertSeverity(from note: String) -> MarkerAlertSeverity? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[Critical] ") { return .critical }
        if trimmed.hasPrefix("[Severe] ") { return .severe }
        if trimmed.hasPrefix("[Warning] ") { return .moderate }
        if trimmed.hasPrefix("[Informational] ") { return .mild }
        return nil
    }

    private func incompatibleComponents(for newIntent: RLMarkerIntent) -> [MarkerComponentDraft] {
        let allowedTypes = allowedComponentTypes(for: newIntent)
        return placementState.components.filter {
            $0.componentType != .anchor && !allowedTypes.contains($0.componentType)
        }
    }

    private func handleIntentSelection(_ newIntent: RLMarkerIntent) {
        guard newIntent != placementState.intent else { return }

        let incompatible = incompatibleComponents(for: newIntent)
        guard incompatible.isEmpty else {
            let names = Array(Set(incompatible.map { $0.componentType.displayName })).sorted()
            pendingIntentSwitch = PendingIntentSwitch(
                targetIntent: newIntent,
                incompatibleComponentIDs: incompatible.map(\.id),
                incompatibleComponentSummary: names.joined(separator: ", ")
            )
            intentChangeWarning = "Switching intent removes: \(names.joined(separator: ", "))."
            HapticFeedback.light.trigger()
            return
        }

        pendingIntentSwitch = nil
        intentChangeWarning = nil
        placementState.setIntent(newIntent)
        withAnimation(.easeInOut(duration: 0.2)) {
            isIntentPickerExpanded = false
        }
    }

    private func applyIntentSwitch(_ pending: PendingIntentSwitch) {
        for componentID in pending.incompatibleComponentIDs {
            placementState.removeComponent(id: componentID)
        }
        pendingIntentSwitch = nil
        intentChangeWarning = nil
        placementState.setIntent(pending.targetIntent)
        withAnimation(.easeInOut(duration: 0.2)) {
            isIntentPickerExpanded = false
        }
    }

    private func allowedComponentTypes(for intent: RLMarkerIntent) -> Set<RLComponentType> {
        let drawingAndIndicators: Set<RLComponentType> = [.drawingTrendline, .drawingZone, .indicator]

        switch intent {
        case .analysis:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .reactionEmoji, .timeframeLink, .linkURL])
                .union(drawingAndIndicators)
        case .setup:
            return Set<RLComponentType>([.anchor, .levelEntry, .levelSl, .levelTp, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .news:
            return Set<RLComponentType>([.anchor, .linkURL, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .poll, .question:
            return Set<RLComponentType>([.anchor, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .reaction:
            return Set<RLComponentType>([.anchor, .reactionEmoji, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .alert:
            return Set<RLComponentType>([.anchor, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .personal:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        }
    }
}

private struct PendingIntentSwitch: Identifiable {
    let id: UUID = UUID()
    let targetIntent: RLMarkerIntent
    let incompatibleComponentIDs: [UUID]
    let incompatibleComponentSummary: String
}

private struct AlertSeverityOption: Identifiable {
    let id: String
    let label: String
    let icon: String
    let severity: MarkerAlertSeverity
    let defaultMessage: String

    init(label: String, icon: String, severity: MarkerAlertSeverity, defaultMessage: String) {
        self.id = label
        self.label = label
        self.icon = icon
        self.severity = severity
        self.defaultMessage = defaultMessage
    }
}
