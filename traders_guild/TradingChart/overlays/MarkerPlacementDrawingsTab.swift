import SwiftUI
import UIKit

private struct DrawingColorOption: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

private struct DrawingLineStyleOption: Identifiable {
    let style: MarkerDrawingLineStyle

    var id: MarkerDrawingLineStyle { style }
}

struct MarkerPlacementDrawingsTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let onBeginInteractiveDrawing: (() -> Void)?
    var mirrorSourceIndicators: [IndicatorPayload] = []
    var mirrorSourceDrawings: [ChartDrawing] = []
    var showsTitleHeader: Bool = true
    var showsMirrorButton: Bool = false

    @State private var selectedSubTab: DrawingSubTab = .lines
    @State private var limitWarning: String?
    @State private var infoMessage: String?
    @State private var colorEditorDraftID: UUID?
    @State private var pendingDrawingColorHex: String?
    @State private var pendingDrawingLineStyle: MarkerDrawingLineStyle = .dashed
    @State private var keyboardInset: CGFloat = 0

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
    private let drawingLineStyleOptions: [DrawingLineStyleOption] = MarkerDrawingLineStyle.allCases.map { DrawingLineStyleOption(style: $0) }

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
            .padding(.bottom, max(keyboardInset + 24, 24))
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTapAndDragBackground()
        .sheet(isPresented: Binding(
            get: { colorEditorDraftID != nil },
            set: { isPresented in
                if !isPresented {
                    colorEditorDraftID = nil
                    pendingDrawingColorHex = nil
                    pendingDrawingLineStyle = .dashed
                }
            }
        )) {
            drawingColorEditorSheet
        }
        .onDisappear {
            keyboardInset = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardInset(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardInset = 0
            }
        }
    }

    private func updateKeyboardInset(from notification: Notification) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let convertedEndFrame = window.convert(endFrame, from: nil)
        let overlap = max(0, window.bounds.maxY - convertedEndFrame.minY - window.safeAreaInsets.bottom)

        withAnimation(.easeOut(duration: 0.2)) {
            keyboardInset = overlap
        }
    }

    private var mirrorChartSetupButton: some View {
        Button {
            mirrorChartSetup()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryForeground)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror Chart Setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Copy current chart drawings and indicators to this marker")
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
        .opacity((mirrorSourceIndicators.isEmpty && mirrorSourceDrawings.isEmpty) ? 0.55 : 1)
        .disabled(mirrorSourceIndicators.isEmpty && mirrorSourceDrawings.isEmpty)
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
                    .foregroundColor(AppColors.primaryForeground)
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
                .foregroundColor(
                    placementState.drawingOverlayCount >= 15
                        ? AppColors.chartOrangeGradientStart
                        : AppColors.statusPositive
                )
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
                        .foregroundColor(AppColors.primaryForeground)
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
                            .foregroundColor(AppColors.primaryForeground)
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
                    .foregroundColor(AppColors.primaryForeground)
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
                        .foregroundColor(AppColors.primaryForeground)
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
                        .foregroundColor(AppColors.primaryForeground)
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
                .foregroundColor(AppColors.primaryForeground)
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
                        .foregroundColor(AppColors.primaryForeground)
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
                                    placementState.anchoredEmojiPayload(
                                        emoji: emoji,
                                        offsetX: payload.offsetX,
                                        offsetY: payload.offsetY,
                                        preserving: payload
                                    )
                                )
                            )
                        } label: {
                            Text(emoji)
                                .font(.system(size: 16))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
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
                color: placementState.drawingColor(
                    for: draft.id,
                    fallback: RLComponentType.levelSupport.color
                ),
                draftId: draft.id
            ) {
                editLevel(draft.id, tool: .support)
            }
        case .levelResistance(let payload):
            levelActiveRow(
                title: payload.label ?? "Resistance",
                subtitle: "Resistance level",
                icon: "arrow.up.to.line",
                color: placementState.drawingColor(
                    for: draft.id,
                    fallback: RLComponentType.levelResistance.color
                ),
                draftId: draft.id
            ) {
                editLevel(draft.id, tool: .resistance)
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
                    .foregroundColor(AppColors.primaryForeground)
                Text("Tap row to edit on chart")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)

            Button {
                openDrawingColorEditor(for: draftId)
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.whiteText.opacity(0.1)))
            }
            .buttonStyle(.plain)

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
                subtitle: "Drag the guide, tap to place each point, then drag handles to refine.",
                icon: "pencil.and.ruler",
                isActive: placementState.activeDrawingWorkflowTool == .trendline,
                actionTitle: "Activate"
            ) {
                guard placementState.canAddDrawing else {
                    applyDrawingLimitWarning()
                    return
                }
                beginInteractiveDrawingSession()
                placementState.startDrawingWorkflow(tool: .trendline)
                infoMessage = "Trendline tool active. Drag to the first point, then tap to set it."
                limitWarning = nil
            }

            toolCard(
                title: "Horizontal Line",
                subtitle: "Drag the guide to price, tap to place, then drag the handle to fine-tune.",
                icon: "line.3.horizontal",
                isActive: placementState.activeDrawingWorkflowTool == .horizontalLine,
                actionTitle: "Activate"
            ) {
                addHorizontalLine()
            }

            toolCard(
                title: "Support Level",
                subtitle: "Drag the guide to price, tap to place, then drag the handle to adjust.",
                icon: "arrow.down.to.line",
                isActive: placementState.activeDrawingWorkflowTool == .support,
                actionTitle: "Activate"
            ) {
                beginInteractiveDrawingSession()
                selectHorizontalLevel(.levelSupport, label: "Support")
            }

            toolCard(
                title: "Resistance Level",
                subtitle: "Drag the guide to price, tap to place, then drag the handle to adjust.",
                icon: "arrow.up.to.line",
                isActive: placementState.activeDrawingWorkflowTool == .resistance,
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
                subtitle: "Drag the guide, tap to place both corners, then drag handles to refine.",
                icon: "square.dashed",
                isActive: placementState.activeDrawingWorkflowTool == .zone,
                actionTitle: "Activate"
            ) {
                guard placementState.canAddDrawing else {
                    applyDrawingLimitWarning()
                    return
                }
                beginInteractiveDrawingSession()
                placementState.startDrawingWorkflow(tool: .zone)
                infoMessage = "Zone tool active. Drag to the first corner, then tap to set it."
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
        VStack(alignment: .leading, spacing: 8) {
            toolCard(
                title: "Text Note",
                subtitle: textNoteDraft == nil
                    ? "Add an anchored text annotation."
                    : "Edit the note inline below.",
                icon: "text.bubble",
                isActive: textNoteDraft != nil,
                actionTitle: textNoteDraft == nil ? "Activate" : "Edit"
            ) {
                addTextNote()
            }

            if let noteDraft = textNoteDraft,
               case let .note(payload) = noteDraft.payload {
                annotationEditorCard {
                    TextField(
                        "Write annotation",
                        text: noteBinding(for: noteDraft.id, fallback: payload.text),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundColor(AppColors.primaryForeground)
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

                annotationRemoveButton("Remove Note") {
                    placementState.removeComponent(.textNote)
                    infoMessage = nil
                    limitWarning = nil
                }
            }
        }
    }

    private var emojiAnnotationCard: some View {
        let currentEmoji = currentEmojiValue

        return VStack(alignment: .leading, spacing: 8) {
            toolCard(
                title: "Emoji",
                subtitle: currentEmoji == nil
                    ? "Pick a single emoji anchored to this marker."
                    : "Choose the emoji below.",
                icon: "face.smiling",
                isActive: currentEmoji != nil,
                actionTitle: currentEmoji == nil ? "Activate" : "Edit"
            ) {
                setAnnotationEmoji(currentEmoji ?? (annotationEmojis.first ?? "🎯"))
            }

            if currentEmoji != nil {
                // Compact horizontal strip — minimises vertical space so the
                // panel stays small and horizontal scroll doesn't fight chart pan.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(annotationEmojis, id: \.self) { emoji in
                            let isSelected = currentEmoji == emoji
                            Button {
                                setAnnotationEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        Circle()
                                            .fill(AppColors.whiteText.opacity(isSelected ? 0.14 : 0.08))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                AppColors.surfaceWhite70.opacity(isSelected ? 0.85 : 0.18),
                                                lineWidth: isSelected ? 1.5 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                annotationRemoveButton("Remove Emoji") {
                    placementState.removeComponent(.reactionEmoji)
                    infoMessage = nil
                    limitWarning = nil
                }
            }
        }
    }

    private var patternsSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Patterns")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            VStack(alignment: .leading, spacing: 4) {
                Text("Planned tools")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Phase 2 builds on this workflow with additional line tools and pattern templates.")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(overlayCardBackground)

            ForEach(MarkerDrawingToolRegistry.futureTools, id: \.kind) { tool in
                HStack(spacing: 10) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite70)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.primaryForeground)
                        Text("Reserved for the phase 2 drawing engine rollout.")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }

                    Spacer(minLength: 0)

                    Text("Later")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(overlayCardBackground)
                .opacity(0.7)
            }
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

    private func annotationEditorCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(overlayCardBackground)
    }

    private func annotationRemoveButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.caption2.weight(.semibold))
            .foregroundColor(AppColors.statusNegative85)
            .buttonStyle(.plain)
            .padding(.leading, 4)
    }

    private var drawingColorEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let draft = currentColorEditingDraft {
                    Text("Adjust the line color and stroke style for \(drawingDisplayName(for: draft.componentType)).")
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
                                        .foregroundColor(AppColors.primaryForeground)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Line Style")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.greyText)

                        ForEach(drawingLineStyleOptions) { option in
                            drawingLineStyleButton(
                                option.style,
                                isSelected: pendingDrawingLineStyle == option.style,
                                color: previewColor(for: draft)
                            )
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
                        .foregroundColor(AppColors.primaryForeground)
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
                        pendingDrawingLineStyle = .dashed
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button("Apply") {
                        applyDrawingColorSelection()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.onAccentForeground)
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
            .navigationTitle("Drawing Style")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(420), .medium])
        .presentationDragIndicator(.visible)
    }

    private var currentColorEditingDraft: MarkerComponentDraft? {
        guard let draftId = colorEditorDraftID else { return nil }
        return placementState.components.first {
            $0.id == draftId && supportsStyleEditing($0.componentType)
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
                .foregroundColor(AppColors.primaryForeground)
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
        let indicatorResult = placementState.attachActiveChartIndicators(mirrorSourceIndicators)
        let drawingResult = placementState.attachActiveChartDrawings(mirrorSourceDrawings)
        let totalAdded = indicatorResult.added + drawingResult.added

        if totalAdded > 0 {
            var mirroredParts: [String] = []
            if drawingResult.added > 0 {
                mirroredParts.append("\(drawingResult.added) drawing\(drawingResult.added == 1 ? "" : "s")")
            }
            if indicatorResult.added > 0 {
                mirroredParts.append("\(indicatorResult.added) indicator\(indicatorResult.added == 1 ? "" : "s")")
            }
            infoMessage = "Mirrored \(mirroredParts.joined(separator: " and ")) from chart."
        } else {
            infoMessage = "No new chart drawings or indicators to mirror."
        }

        if drawingResult.blockedByLimit || indicatorResult.blockedByLimit {
            limitWarning = drawingResult.blockedByLimit
                ? placementState.limitMessage(for: .drawingOverlays)
                : placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
        } else {
            limitWarning = nil
        }
    }

    private func openDrawingColorEditor(for draftID: UUID) {
        guard let draft = placementState.components.first(where: { $0.id == draftID }),
              supportsStyleEditing(draft.componentType) else {
            return
        }

        colorEditorDraftID = draft.id
        pendingDrawingColorHex = placementState.drawingColorHex(for: draft.id)
        pendingDrawingLineStyle = placementState.drawingLineStyle(
            for: draft.id,
            fallback: defaultDrawingLineStyle(for: draft.componentType)
        )
    }

    private func applyDrawingColorSelection() {
        guard let draftID = colorEditorDraftID else { return }
        placementState.setDrawingColorHex(pendingDrawingColorHex, for: draftID)
        placementState.setDrawingLineStyle(pendingDrawingLineStyle, for: draftID)
        colorEditorDraftID = nil
        pendingDrawingColorHex = nil
        pendingDrawingLineStyle = .dashed
        infoMessage = "Updated drawing style."
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
        case .levelSupport:
            return "Support Level"
        case .levelResistance:
            return "Resistance Level"
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
        case .levelSupport:
            return RLComponentType.levelSupport.color
        case .levelResistance:
            return RLComponentType.levelResistance.color
        default:
            return placementState.intent.color
        }
    }

    private func defaultDrawingLineStyle(for componentType: RLComponentType) -> MarkerDrawingLineStyle {
        switch componentType {
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .levelSupport, .levelResistance:
            return .dashed
        default:
            return .solid
        }
    }

    private func previewColor(for draft: MarkerComponentDraft) -> Color {
        if let pendingDrawingColorHex,
           let resolved = Color(hex: pendingDrawingColorHex) {
            return resolved
        }
        return placementState.drawingColor(
            for: draft.id,
            fallback: defaultDrawingColor(for: draft.componentType)
        )
    }

    private func drawingLineStyleButton(
        _ lineStyle: MarkerDrawingLineStyle,
        isSelected: Bool,
        color: Color
    ) -> some View {
        Button {
            pendingDrawingLineStyle = lineStyle
        } label: {
            HStack(spacing: 10) {
                Text(lineStyle.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                    .frame(width: 72, alignment: .leading)

                GeometryReader { geometry in
                    Path { path in
                        let midY = geometry.size.height * 0.5
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 2.0, dash: lineStyle.dashPattern)
                    )
                }
                .frame(height: 18)

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
                                isSelected ? color.opacity(0.9) : AppColors.whiteText.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func supportsStyleEditing(_ componentType: RLComponentType) -> Bool {
        componentType.isDrawing || componentType == .levelSupport || componentType == .levelResistance
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
                        .foregroundColor(AppColors.primaryForeground)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(actionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isActive ? AppColors.onAccentForeground : placementState.intent.color)
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
                let existingPayload: NotePayload? = {
                    guard let draft = placementState.components.first(where: { $0.id == draftID }),
                          case let .note(payload) = draft.payload else {
                        return nil
                    }
                    return payload
                }()
                placementState.updateComponent(
                    id: draftID,
                    payload: .note(
                        placementState.anchoredNotePayload(
                            text: newValue,
                            offsetX: existingPayload?.offsetX,
                            offsetY: existingPayload?.offsetY,
                            preserving: existingPayload
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
        selectedSubTab = .lines
        if placementState.activateImmediateHorizontalDrawing(tool: .horizontalLine) != nil {
            infoMessage = "Horizontal line placed. Drag the handle, then tap empty chart to save."
            limitWarning = nil
        } else {
            applyDrawingLimitWarning()
        }
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
        switch type {
        case .levelSupport:
            _ = placementState.activateImmediateHorizontalDrawing(tool: .support)
        case .levelResistance:
            _ = placementState.activateImmediateHorizontalDrawing(tool: .resistance)
        default:
            break
        }

        selectedSubTab = .lines
        infoMessage = "\(label) level placed. Drag the handle, then tap empty chart to save."
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

    private func editLevel(_ draftID: UUID, tool: MarkerDrawingToolKind) {
        beginInteractiveDrawingSession()
        selectedSubTab = .lines
        placementState.beginEditingDrawing(draftID, tool: tool)
        infoMessage = "\(tool.title) selected. Drag the handle on chart, then tap empty chart to save."
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
            payload: .note(
                placementState.anchoredNotePayload(text: text.isEmpty ? "Add your context" : text)
            )
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

        let existingPayload: EmojiPayload?
        if case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload {
            existingPayload = payload
        } else {
            existingPayload = nil
        }

        placementState.upsertComponent(
            .reactionEmoji,
            payload: .reactionEmoji(
                placementState.anchoredEmojiPayload(
                    emoji: emoji,
                    offsetX: existingPayload?.offsetX,
                    offsetY: existingPayload?.offsetY,
                    preserving: existingPayload
                )
            )
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
