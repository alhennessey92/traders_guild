import SwiftUI

private enum MarkerDrawingSubTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case lines = "Lines"
    case zones = "Zones"
    case annotations = "Annotations"
    case patterns = "Patterns"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .lines: return "line.3.horizontal"
        case .zones: return "square.dashed"
        case .annotations: return "text.bubble"
        case .patterns: return "triangle"
        }
    }
}

struct MarkerPlacementDrawingsTab: View {
    @ObservedObject var placementState: MarkerPlacementState

    @State private var selectedSubTab: MarkerDrawingSubTab = .active
    @State private var limitWarning: String?
    @State private var infoMessage: String?

    private let annotationEmojis: [String] = [
        "🎯", "🔥", "🐻", "🐂", "✅", "❌",
        "🚀", "⚡", "💡", "📉", "📈", "🧠",
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                tabTitleHeader

                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .standard,
                    theme: .blue,
                    spacing: 6
                )

                overlayUsageHeader

                if let infoMessage {
                    statusMessage(infoMessage, color: AppColors.greyText)
                }

                if let limitWarning {
                    statusMessage(limitWarning, color: .orange.opacity(0.95))
                }

                switch selectedSubTab {
                case .active:
                    activeSubTab
                case .lines:
                    linesSubTab
                case .zones:
                    zonesSubTab
                case .annotations:
                    annotationsSubTab
                case .patterns:
                    patternsSubTab
                }
            }
            .padding(.trailing, 2)
        }
    }

    private var tabTitleHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(RLComponentType.drawingTrendline.color.opacity(0.2))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "pencil.and.ruler")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RLComponentType.drawingTrendline.color.opacity(0.95))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Drawings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Add trendlines, zones, and annotations")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
    }

    private var overlayUsageHeader: some View {
        HStack(spacing: 8) {
            Text("Drawing Overlays")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Spacer(minLength: 0)

            Text("\(placementState.drawingOverlayCount)/15")
                .font(.caption.weight(.semibold))
                .foregroundColor(placementState.drawingOverlayCount >= 15 ? .orange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppColors.whiteText.opacity(0.09)))
        }
    }

    private var activeSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Drawings & Annotations")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            if placementState.drawingOverlayDrafts.isEmpty {
                Text("No drawing overlays attached.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            } else {
                ForEach(placementState.drawingOverlayDrafts) { draft in
                    activeOverlayRow(draft)
                }
            }
        }
    }

    @ViewBuilder
    private func activeOverlayRow(_ draft: MarkerComponentDraft) -> some View {
        switch draft.payload {
        case .drawingTrendline(let payload):
            HStack(spacing: 10) {
                Image(systemName: "pencil.and.ruler")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RLComponentType.drawingTrendline.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    let isHorizontal = abs(payload.startPrice - payload.endPrice) < 0.0000001
                    Text(isHorizontal ? "Horizontal Line" : "Trendline")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Tap Edit to continue adjusting on chart")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Button("Edit") {
                    placementState.activeTool = .draw
                    placementState.activeSubTool = MarkerToolOption.drawTrendline.rawValue
                    placementState.beginEditingDrawing(draft.id)
                    selectedSubTab = .lines
                    infoMessage = "Trendline edit mode active. Drag handles on chart."
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(placementState.intent.color)
                .buttonStyle(.plain)

                removeDraftButton(draft.id)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)

        case .drawingZone:
            HStack(spacing: 10) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RLComponentType.drawingZone.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zone")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Tap Edit to continue adjusting on chart")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Button("Edit") {
                    placementState.activeTool = .draw
                    placementState.activeSubTool = MarkerToolOption.drawZone.rawValue
                    placementState.beginEditingDrawing(draft.id)
                    selectedSubTab = .zones
                    infoMessage = "Zone edit mode active. Drag handles on chart."
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(placementState.intent.color)
                .buttonStyle(.plain)

                removeDraftButton(draft.id)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)

        case .note(let payload):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RLComponentType.textNote.color)
                    Text("Text Note")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                    removeDraftButton(draft.id)
                }

                TextField(
                    "Enter annotation",
                    text: noteBinding(for: draft.id, fallback: payload.text),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.whiteText.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)

        case .reactionEmoji(let payload):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RLComponentType.reactionEmoji.color)
                    Text("Emoji")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                    Text(payload.emoji)
                        .font(.system(size: 18))
                    removeDraftButton(draft.id)
                }

                HStack(spacing: 6) {
                    ForEach(annotationEmojis, id: \.self) { emoji in
                        Button {
                            placementState.updateComponent(
                                id: draft.id,
                                payload: .reactionEmoji(
                                    EmojiPayload(
                                        emoji: emoji,
                                        offsetX: payload.offsetX,
                                        offsetY: payload.offsetY
                                    )
                                )
                            )
                        } label: {
                            Text(emoji)
                                .font(.system(size: 16))
                                .frame(width: 30, height: 26)
                                .background(
                                    Capsule()
                                        .fill(payload.emoji == emoji ? placementState.intent.color.opacity(0.35) : AppColors.whiteText.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)

        default:
            EmptyView()
        }
    }

    private var linesSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line Tools")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            toolCard(
                title: "Trendline Tool",
                subtitle: "Drag-tap-drag-tap on chart to place.",
                icon: "pencil.and.ruler",
                isActive: placementState.activeTool == .draw && placementState.activeSubTool == MarkerToolOption.drawTrendline.rawValue,
                actionTitle: "Activate"
            ) {
                placementState.beginTrendlinePlacement()
                infoMessage = "Trendline tool active."
                limitWarning = nil
            }

            toolCard(
                title: "Horizontal Line",
                subtitle: "Quick-add a neutral horizontal trendline.",
                icon: "line.3.horizontal",
                isActive: false,
                actionTitle: "Add"
            ) {
                addHorizontalTrendline()
            }

            HStack(spacing: 8) {
                quickPillButton("Support", icon: "arrow.down.to.line") {
                    selectHorizontalLevel(.levelSupport, label: "Support")
                }
                quickPillButton("Resistance", icon: "arrow.up.to.line") {
                    selectHorizontalLevel(.levelResistance, label: "Resistance")
                }
            }
        }
    }

    private var zonesSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zone Tools")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            toolCard(
                title: "Zone Tool",
                subtitle: "Tap chart twice to define a zone region.",
                icon: "square.dashed",
                isActive: placementState.activeTool == .draw && placementState.activeSubTool == MarkerToolOption.drawZone.rawValue,
                actionTitle: "Activate"
            ) {
                placementState.beginZonePlacement()
                infoMessage = "Zone tool active."
                limitWarning = nil
            }

            toolCard(
                title: "Quick Add Zone",
                subtitle: "Creates a default zone around current anchor.",
                icon: "plus.square.on.square",
                isActive: false,
                actionTitle: "Add"
            ) {
                quickAddZone()
            }
        }
    }

    private var annotationsSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Annotations")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            noteAnnotationCard
            emojiAnnotationCard
        }
    }

    private var noteAnnotationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RLComponentType.textNote.color)

                Text("Text Note")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer(minLength: 0)

                if textNoteDraft != nil {
                    Button("Remove") {
                        placementState.removeComponent(.textNote)
                        infoMessage = nil
                        limitWarning = nil
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.red.opacity(0.85))
                    .buttonStyle(.plain)
                } else {
                    Button("Add") {
                        addTextNote()
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(placementState.intent.color)
                    .buttonStyle(.plain)
                }
            }

            if let noteDraft = textNoteDraft,
               case let .note(payload) = noteDraft.payload {
                TextField(
                    "Write annotation",
                    text: noteBinding(for: noteDraft.id, fallback: payload.text),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.whiteText.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(overlayCardBackground)
    }

    private var emojiAnnotationCard: some View {
        let currentEmoji = currentEmojiValue

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(RLComponentType.reactionEmoji.color)

                Text("Emoji")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer(minLength: 0)

                if currentEmoji != nil {
                    Button("Remove") {
                        placementState.removeComponent(.reactionEmoji)
                        infoMessage = nil
                        limitWarning = nil
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.red.opacity(0.85))
                    .buttonStyle(.plain)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(annotationEmojis, id: \.self) { emoji in
                    Button {
                        setAnnotationEmoji(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 18))
                            .frame(height: 30)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(currentEmoji == emoji ? placementState.intent.color.opacity(0.35) : AppColors.whiteText.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(overlayCardBackground)
    }

    private var patternsSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Patterns")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            VStack(alignment: .leading, spacing: 4) {
                Text("Coming soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Pattern templates and snap assist tools will land in a later update.")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(overlayCardBackground)
        }
    }

    private var textNoteDraft: MarkerComponentDraft? {
        placementState.component(.textNote)
    }

    private var currentEmojiValue: String? {
        guard case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload else {
            return nil
        }
        return payload.emoji
    }

    private var overlayCardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppColors.whiteText.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
            )
    }

    private func removeDraftButton(_ id: UUID) -> some View {
        Button {
            placementState.removeComponent(id: id)
            infoMessage = nil
            limitWarning = nil
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
    }

    private func toolCard(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button(actionTitle, action: action)
                .font(.caption2.weight(.semibold))
                .foregroundColor(isActive ? .white : placementState.intent.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isActive ? placementState.intent.color.opacity(0.45) : placementState.intent.color.opacity(0.15))
                )
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(overlayCardBackground)
    }

    private func quickPillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func noteBinding(for draftID: UUID, fallback: String) -> Binding<String> {
        Binding(
            get: {
                guard let draft = placementState.components.first(where: { $0.id == draftID }),
                      case let .note(payload) = draft.payload else {
                    return fallback
                }
                return payload.text
            },
            set: { newValue in
                let existingOffsets: (Double?, Double?) = {
                    guard let draft = placementState.components.first(where: { $0.id == draftID }),
                          case let .note(payload) = draft.payload else {
                        return (nil, nil)
                    }
                    return (payload.offsetX, payload.offsetY)
                }()
                placementState.updateComponent(
                    id: draftID,
                    payload: .note(
                        NotePayload(
                            text: newValue,
                            offsetX: existingOffsets.0,
                            offsetY: existingOffsets.1
                        )
                    )
                )
                placementState.note = newValue
            }
        )
    }

    private func addHorizontalTrendline() {
        guard placementState.canAddDrawing else {
            applyDrawingLimitWarning()
            return
        }

        let anchorTime = placementState.anchorDraft?.payload.anchorTime ?? Date()
        let anchorPrice = placementState.anchorDraft?.payload.levelPrice ?? 0

        let payload = MarkerComponentPayload.drawingTrendline(
            TrendlinePayload(
                startTime: anchorTime.addingTimeInterval(-30 * 60),
                startPrice: anchorPrice,
                endTime: anchorTime.addingTimeInterval(30 * 60),
                endPrice: anchorPrice
            )
        )

        if placementState.addDrawingOverlayComponent(.drawingTrendline, payload: payload) == nil {
            applyDrawingLimitWarning()
            return
        }

        placementState.beginTrendlinePlacement()
        infoMessage = "Horizontal line added."
        limitWarning = nil
    }

    private func quickAddZone() {
        guard placementState.canAddDrawing else {
            applyDrawingLimitWarning()
            return
        }

        let anchorTime = placementState.anchorDraft?.payload.anchorTime ?? Date()
        let anchorPrice = placementState.anchorDraft?.payload.levelPrice ?? 0
        let delta = max(abs(anchorPrice) * 0.005, 0.0001)

        let payload = MarkerComponentPayload.drawingZone(
            ZonePayload(
                topPrice: anchorPrice + delta,
                bottomPrice: anchorPrice - delta,
                startTime: anchorTime.addingTimeInterval(-30 * 60),
                endTime: anchorTime.addingTimeInterval(30 * 60)
            )
        )

        if placementState.addDrawingOverlayComponent(.drawingZone, payload: payload) == nil {
            applyDrawingLimitWarning()
            return
        }

        placementState.beginZonePlacement()
        infoMessage = "Default zone added."
        limitWarning = nil
    }

    private func selectHorizontalLevel(_ type: RLComponentType, label: String) {
        let anchorPrice = placementState.anchorDraft?.payload.levelPrice ?? 0

        placementState.activeTool = .levels
        switch type {
        case .levelSupport:
            placementState.activeSubTool = MarkerToolOption.levelSupport.rawValue
            placementState.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: anchorPrice, label: "Support")))
        case .levelResistance:
            placementState.activeSubTool = MarkerToolOption.levelResistance.rawValue
            placementState.upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: anchorPrice, label: "Resistance")))
        default:
            break
        }

        infoMessage = "\(label) level ready. Tap chart to reposition."
        limitWarning = nil
    }

    private func addTextNote() {
        if placementState.component(.textNote) == nil && !placementState.canAddDrawing {
            applyDrawingLimitWarning()
            return
        }

        let text = placementState.note.trimmingCharacters(in: .whitespacesAndNewlines)
        placementState.upsertComponent(
            .textNote,
            payload: .note(NotePayload(text: text.isEmpty ? "Add your context" : text))
        )
        infoMessage = "Text note added."
        limitWarning = nil
    }

    private func setAnnotationEmoji(_ emoji: String) {
        if placementState.component(.reactionEmoji) == nil && !placementState.canAddDrawing {
            applyDrawingLimitWarning()
            return
        }

        placementState.upsertComponent(
            .reactionEmoji,
            payload: .reactionEmoji(EmojiPayload(emoji: emoji))
        )
        infoMessage = nil
        limitWarning = nil
    }

    private func applyDrawingLimitWarning() {
        limitWarning = placementState.limitMessage(for: .drawingOverlays)
        HapticFeedback.light.trigger()
    }
}
