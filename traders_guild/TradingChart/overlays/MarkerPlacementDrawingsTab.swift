import SwiftUI

private enum MarkerDrawingSubTab: String, CaseIterable, UnifiedTabItem {
    case lines = "Lines"
    case zones = "Zones"
    case annotations = "Annotations"
    case patterns = "Patterns"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .lines: return "line.3.horizontal"
        case .zones: return "square.dashed"
        case .annotations: return "text.bubble"
        case .patterns: return "triangle"
        }
    }
}

private struct DrawingColorOption: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

struct MarkerPlacementDrawingsTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let onBeginInteractiveDrawing: (() -> Void)?
    var mirrorSourceIndicators: [IndicatorPayload] = []
    var showsTitleHeader: Bool = true
    var showsMirrorButton: Bool = false

    @State private var selectedSubTab: MarkerDrawingSubTab = .lines
    @State private var limitWarning: String?
    @State private var infoMessage: String?
    @State private var colorEditorDraftID: UUID?
    @State private var pendingDrawingColorHex: String?

    private let annotationEmojis: [String] = [
        "🎯", "🔥", "🐻", "🐂", "✅", "❌",
        "🚀", "⚡", "💡", "📉", "📈", "🧠",
    ]
    private let drawingColorOptions: [DrawingColorOption] = [
        .init(name: "Mint", hex: "#10B981"),
        .init(name: "Sky", hex: "#38BDF8"),
        .init(name: "Amber", hex: "#F59E0B"),
        .init(name: "Rose", hex: "#F43F5E"),
        .init(name: "Violet", hex: "#8B5CF6"),
        .init(name: "Slate", hex: "#94A3B8"),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if showsTitleHeader {
                    tabTitleHeader
                }

                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .compact,
                    theme: .deepSubTab,
                    spacing: 6
                )

                if showsMirrorButton {
                    mirrorChartSetupButton
                }

                overlayUsageHeader

                if let infoMessage {
                    statusMessage(infoMessage, color: AppColors.greyText)
                }

                if let limitWarning {
                    statusMessage(limitWarning, color: AppColors.statusWarning95)
                }

                switch selectedSubTab {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: Binding(
            get: { colorEditorDraftID != nil },
            set: { isPresented in
                if !isPresented {
                    colorEditorDraftID = nil
                    pendingDrawingColorHex = nil
                }
            }
        )) {
            drawingColorEditorSheet
        }
    }

    private var mirrorChartSetupButton: some View {
        Button {
            mirrorChartSetup()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror Chart Setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Copy current chart indicators to this marker")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(mirrorSourceIndicators.isEmpty ? 0.55 : 1)
        .disabled(mirrorSourceIndicators.isEmpty)
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
                Text("Add lines, zones, and annotations")
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

            if placementState.drawingOverlayDrafts.isEmpty && activeLevelDrafts.isEmpty {
                Text("No drawing overlays attached.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            } else {
                ForEach(placementState.drawingOverlayDrafts) { draft in
                    activeOverlayRow(draft)
                }
                ForEach(activeLevelDrafts) { draft in
                    activeLevelRow(draft)
                }
            }
        }
    }

    private var activeLevelDrafts: [MarkerComponentDraft] {
        placementState.components.filter {
            $0.componentType == .levelSupport || $0.componentType == .levelResistance
        }
    }

    @ViewBuilder
    private func activeOverlayRow(_ draft: MarkerComponentDraft) -> some View {
        switch draft.payload {
        case .drawingTrendline:
            let trendlineColor = placementState.drawingColor(
                for: draft.id,
                fallback: RLComponentType.drawingTrendline.color
            )
            HStack(spacing: 10) {
                Image(systemName: "pencil.and.ruler")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(trendlineColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trendline")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Tap row to edit on chart")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Button {
                    openDrawingColorEditor(for: draft.id)
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(trendlineColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppColors.whiteText.opacity(0.1)))
                }
                .buttonStyle(.plain)

                removeDraftButton(draft.id)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                editTrendline(draft.id)
            }

        case .drawingHorizontalLine:
            let lineColor = placementState.drawingColor(
                for: draft.id,
                fallback: RLComponentType.drawingHorizontalLine.color
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(lineColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Horizontal Line")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text("Tap row to edit on chart")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }

                    Spacer(minLength: 0)

                    Button {
                        openDrawingColorEditor(for: draft.id)
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(lineColor)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(AppColors.whiteText.opacity(0.1)))
                    }
                    .buttonStyle(.plain)

                    removeDraftButton(draft.id)
                }

                TextField("Line label", text: horizontalLineLabelBinding(for: draft.id))
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
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                editHorizontalLine(draft.id)
            }

        case .drawingZone:
            let zoneColor = placementState.drawingColor(
                for: draft.id,
                fallback: RLComponentType.drawingZone.color
            )
            HStack(spacing: 10) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(zoneColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zone")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("Tap row to edit on chart")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Button {
                    openDrawingColorEditor(for: draft.id)
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(zoneColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppColors.whiteText.opacity(0.1)))
                }
                .buttonStyle(.plain)

                removeDraftButton(draft.id)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                editZone(draft.id)
            }

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

                let emojiColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                LazyVGrid(columns: emojiColumns, spacing: 6) {
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
                                .frame(height: 28)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
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

    @ViewBuilder
    private func activeLevelRow(_ draft: MarkerComponentDraft) -> some View {
        switch draft.payload {
        case .levelSupport(let payload):
            levelActiveRow(
                title: payload.label ?? "Support",
                subtitle: "Support level",
                icon: "arrow.down.to.line",
                color: RLComponentType.levelSupport.color,
                draftId: draft.id
            ) {
                beginInteractiveDrawingSession()
                placementState.activeTool = .levels
                placementState.activeSubTool = MarkerToolOption.levelSupport.rawValue
            }
        case .levelResistance(let payload):
            levelActiveRow(
                title: payload.label ?? "Resistance",
                subtitle: "Resistance level",
                icon: "arrow.up.to.line",
                color: RLComponentType.levelResistance.color,
                draftId: draft.id
            ) {
                beginInteractiveDrawingSession()
                placementState.activeTool = .levels
                placementState.activeSubTool = MarkerToolOption.levelResistance.rawValue
            }
        default:
            EmptyView()
        }
    }

    private func levelActiveRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        draftId: UUID,
        onActivate: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? subtitle : title)
                    .font(.caption)
                    .foregroundColor(.white)
                Text("Tap row to edit on chart")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
            removeDraftButton(draftId)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(overlayCardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onActivate)
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
                beginInteractiveDrawingSession()
                placementState.startDrawingWorkflow(tool: .trendline)
                infoMessage = "Trendline tool active."
                limitWarning = nil
            }

            toolCard(
                title: "Horizontal Line",
                subtitle: "Add a support/resistance style horizontal line.",
                icon: "line.3.horizontal",
                isActive: placementState.activeTool == .draw
                    && placementState.activeSubTool == MarkerToolOption.drawHorizontalLine.rawValue,
                actionTitle: "Add"
            ) {
                addHorizontalLine()
            }

            toolCard(
                title: "Support Level",
                subtitle: "Add and drag a support line directly on chart.",
                icon: "arrow.down.to.line",
                isActive: placementState.activeTool == .levels
                    && placementState.activeSubTool == MarkerToolOption.levelSupport.rawValue,
                actionTitle: "Activate"
            ) {
                beginInteractiveDrawingSession()
                selectHorizontalLevel(.levelSupport, label: "Support")
            }

            toolCard(
                title: "Resistance Level",
                subtitle: "Add and drag a resistance line directly on chart.",
                icon: "arrow.up.to.line",
                isActive: placementState.activeTool == .levels
                    && placementState.activeSubTool == MarkerToolOption.levelResistance.rawValue,
                actionTitle: "Activate"
            ) {
                beginInteractiveDrawingSession()
                selectHorizontalLevel(.levelResistance, label: "Resistance")
            }

            horizontalLevelLabelEditors
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
                beginInteractiveDrawingSession()
                placementState.startDrawingWorkflow(tool: .zone)
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
                    .foregroundColor(AppColors.statusNegative85)
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
                    .foregroundColor(AppColors.statusNegative85)
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

    private var drawingColorEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let draft = currentColorEditingDraft {
                    Text("Select a color for \(drawingDisplayName(for: draft.componentType)).")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(drawingColorOptions) { option in
                            let isSelected = pendingDrawingColorHex == option.hex
                            Button {
                                pendingDrawingColorHex = option.hex
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: option.hex) ?? AppColors.surfaceWhite70)
                                        .frame(width: 14, height: 14)
                                    Text(option.name)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.white)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isSelected ? AppColors.whiteText.opacity(0.16) : AppColors.whiteText.opacity(0.07))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    isSelected
                                                        ? (Color(hex: option.hex) ?? AppColors.surfaceWhite66)
                                                        : AppColors.whiteText.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        pendingDrawingColorHex = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Use Default Color")
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 0)
                            Circle()
                                .fill(defaultDrawingColor(for: draft.componentType))
                                .frame(width: 14, height: 14)
                        }
                        .foregroundColor(.white)
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
                    .buttonStyle(.plain)
                } else {
                    Text("Drawing not available.")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        colorEditorDraftID = nil
                        pendingDrawingColorHex = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button("Apply") {
                        applyDrawingColorSelection()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(placementState.intent.color.opacity(0.45))
                    )
                    .overlay(
                        Capsule()
                            .stroke(placementState.intent.color.opacity(0.75), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .navigationTitle("Drawing Color")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
    }

    private var currentColorEditingDraft: MarkerComponentDraft? {
        guard let draftId = colorEditorDraftID else { return nil }
        return placementState.components.first {
            $0.id == draftId && $0.componentType.isDrawing
        }
    }

    @ViewBuilder
    private var horizontalLevelLabelEditors: some View {
        if placementState.component(.levelSupport) != nil || placementState.component(.levelResistance) != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Level Labels")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                if placementState.component(.levelSupport) != nil {
                    levelLabelEditorCard(
                        title: "Support Label",
                        placeholder: "Support",
                        binding: levelLabelBinding(for: .levelSupport, defaultLabel: "Support")
                    )
                }

                if placementState.component(.levelResistance) != nil {
                    levelLabelEditorCard(
                        title: "Resistance Label",
                        placeholder: "Resistance",
                        binding: levelLabelBinding(for: .levelResistance, defaultLabel: "Resistance")
                    )
                }
            }
        }
    }

    private func levelLabelEditorCard(
        title: String,
        placeholder: String,
        binding: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.greyText)

            TextField(placeholder, text: binding)
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
    }

    private func removeDraftButton(_ id: UUID) -> some View {
        Button {
            placementState.removeComponent(id: id)
            infoMessage = nil
            limitWarning = nil
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.statusNegative85)
        }
        .buttonStyle(.plain)
    }

    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
    }

    private func mirrorChartSetup() {
        let result = placementState.attachActiveChartIndicators(mirrorSourceIndicators)
        if result.added > 0 {
            infoMessage = "Mirrored \(result.added) indicator\(result.added == 1 ? "" : "s") from chart."
        } else {
            infoMessage = "No new chart indicators to mirror."
        }

        if result.blockedByLimit {
            limitWarning = placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
        } else {
            limitWarning = nil
        }
    }

    private func openDrawingColorEditor(for draftID: UUID) {
        guard let draft = placementState.components.first(where: { $0.id == draftID }),
              draft.componentType.isDrawing else {
            return
        }

        colorEditorDraftID = draft.id
        pendingDrawingColorHex = placementState.drawingColorHex(for: draft.id)
    }

    private func applyDrawingColorSelection() {
        guard let draftID = colorEditorDraftID else { return }
        placementState.setDrawingColorHex(pendingDrawingColorHex, for: draftID)
        colorEditorDraftID = nil
        pendingDrawingColorHex = nil
        infoMessage = "Updated drawing color."
        limitWarning = nil
    }

    private func drawingDisplayName(for componentType: RLComponentType) -> String {
        switch componentType {
        case .drawingTrendline:
            return "Trendline"
        case .drawingHorizontalLine:
            return "Horizontal Line"
        case .drawingZone:
            return "Zone"
        default:
            return "Drawing"
        }
    }

    private func defaultDrawingColor(for componentType: RLComponentType) -> Color {
        switch componentType {
        case .drawingTrendline:
            return RLComponentType.drawingTrendline.color
        case .drawingHorizontalLine:
            return RLComponentType.drawingHorizontalLine.color
        case .drawingZone:
            return RLComponentType.drawingZone.color
        default:
            return placementState.intent.color
        }
    }

    private func toolCard(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.surfaceWhite88)
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

                Text(actionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isActive ? .white : placementState.intent.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isActive ? placementState.intent.color.opacity(0.45) : placementState.intent.color.opacity(0.15))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(overlayCardBackground)
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

    private func horizontalLineLabelBinding(for draftID: UUID) -> Binding<String> {
        Binding(
            get: {
                placementState.horizontalLineLabel(for: draftID, fallback: "Line")
            },
            set: { value in
                placementState.setHorizontalLineLabel(value, for: draftID)
            }
        )
    }

    private func levelLabelBinding(
        for componentType: RLComponentType,
        defaultLabel: String
    ) -> Binding<String> {
        Binding(
            get: {
                guard let component = placementState.component(componentType) else { return defaultLabel }
                switch component.payload {
                case .levelSupport(let payload):
                    return (payload.label ?? defaultLabel).trimmingCharacters(in: .whitespacesAndNewlines)
                case .levelResistance(let payload):
                    return (payload.label ?? defaultLabel).trimmingCharacters(in: .whitespacesAndNewlines)
                default:
                    return defaultLabel
                }
            },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedLabel = trimmed.isEmpty ? defaultLabel : trimmed
                guard let component = placementState.component(componentType) else { return }

                switch component.payload {
                case .levelSupport(let payload):
                    placementState.upsertComponent(
                        .levelSupport,
                        payload: .levelSupport(LevelPayload(price: payload.price, label: resolvedLabel))
                    )
                case .levelResistance(let payload):
                    placementState.upsertComponent(
                        .levelResistance,
                        payload: .levelResistance(LevelPayload(price: payload.price, label: resolvedLabel))
                    )
                default:
                    break
                }
            }
        )
    }

    private func addHorizontalLine() {
        guard placementState.canAddDrawing else {
            applyDrawingLimitWarning()
            return
        }

        beginInteractiveDrawingSession()

        let anchorPrice = placementState.anchorDraft?.payload.levelPrice ?? 0

        let payload = MarkerComponentPayload.drawingHorizontalLine(
            HorizontalLinePayload(
                price: anchorPrice,
                label: "Line"
            )
        )

        guard let draftID = placementState.addDrawingOverlayComponent(.drawingHorizontalLine, payload: payload) else {
            applyDrawingLimitWarning()
            return
        }

        selectedSubTab = .lines
        placementState.beginEditingDrawing(draftID, tool: .horizontalLine)
        infoMessage = "Horizontal line added."
        limitWarning = nil
    }

    private func quickAddZone() {
        guard placementState.canAddDrawing else {
            applyDrawingLimitWarning()
            return
        }

        beginInteractiveDrawingSession()

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

        guard let draftID = placementState.addDrawingOverlayComponent(.drawingZone, payload: payload) else {
            applyDrawingLimitWarning()
            return
        }

        selectedSubTab = .zones
        placementState.beginEditingDrawing(draftID, tool: .zone)
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

        selectedSubTab = .lines
        infoMessage = "\(label) level ready. Drag the on-chart handle to reposition."
        limitWarning = nil
    }

    private func editTrendline(_ draftID: UUID) {
        beginInteractiveDrawingSession()
        selectedSubTab = .lines
        placementState.activeTool = .draw
        placementState.activeSubTool = MarkerToolOption.drawTrendline.rawValue
        placementState.beginEditingDrawing(draftID, tool: .trendline)
        infoMessage = "Trendline selected. Drag handles on chart to edit."
        limitWarning = nil
    }

    private func editHorizontalLine(_ draftID: UUID) {
        beginInteractiveDrawingSession()
        selectedSubTab = .lines
        placementState.activeTool = .draw
        placementState.activeSubTool = MarkerToolOption.drawHorizontalLine.rawValue
        placementState.beginEditingDrawing(draftID, tool: .horizontalLine)
        infoMessage = "Horizontal line selected. Drag handle on chart to edit."
        limitWarning = nil
    }

    private func editZone(_ draftID: UUID) {
        beginInteractiveDrawingSession()
        selectedSubTab = .zones
        placementState.activeTool = .draw
        placementState.activeSubTool = MarkerToolOption.drawZone.rawValue
        placementState.beginEditingDrawing(draftID, tool: .zone)
        infoMessage = "Zone selected. Drag corners on chart to edit."
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
        if let draft = placementState.component(.textNote) {
            beginInteractiveDrawingSession()
            selectedSubTab = .annotations
            placementState.beginEditingDrawing(draft.id, tool: .note)
        }
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
        if placementState.intent != .reaction,
           let draft = placementState.component(.reactionEmoji) {
            beginInteractiveDrawingSession()
            selectedSubTab = .annotations
            placementState.beginEditingDrawing(draft.id, tool: .emoji)
        }
        infoMessage = nil
        limitWarning = nil
    }

    private func beginInteractiveDrawingSession() {
        placementState.prepareForInteractiveDrawing()
        onBeginInteractiveDrawing?()
    }

    private func applyDrawingLimitWarning() {
        limitWarning = placementState.limitMessage(for: .drawingOverlays)
        HapticFeedback.light.trigger()
    }
}
