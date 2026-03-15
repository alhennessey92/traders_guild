import SwiftUI

private struct DrawingColorOption: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

struct ChartDrawingsSubTab: View {
    @ObservedObject var drawingManager: ChartDrawingManager
    var onBeginInteractiveDrawing: (() -> Void)? = nil

    @State private var selectedSubTab: DrawingSubTab = .lines
    @State private var selectedColorHex: String = "#10B981"
    @State private var infoMessage: String?
    @State private var limitWarning: String?

    private let maxDrawingOverlays = 15
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

    private var textNoteDrawing: ChartDrawing? {
        drawingManager.drawings.first(where: { $0.type == .textNote })
    }

    private var emojiDrawing: ChartDrawing? {
        drawingManager.drawings.first(where: { $0.type == .emoji })
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .compact,
                    theme: .deepSubTab,
                    spacing: 6
                )

                overlayUsageHeader
                colorPalette

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
            .padding(.trailing, 2)
        }
    }

    private var overlayUsageHeader: some View {
        HStack(spacing: 8) {
            Text("Drawing Overlays")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Spacer(minLength: 0)

            Text("\(drawingManager.drawings.count)/\(maxDrawingOverlays)")
                .font(.caption.weight(.semibold))
                .foregroundColor(drawingManager.drawings.count >= maxDrawingOverlays ? .orange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppColors.whiteText.opacity(0.09)))
        }
    }

    private var colorPalette: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Default Color")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            HStack(spacing: 8) {
                ForEach(drawingColorOptions) { option in
                    Button {
                        selectedColorHex = option.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex) ?? .white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColorHex == option.hex ? AppColors.whiteText : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var linesSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            catalogRow(
                title: "Trendline",
                subtitle: "Add a directional trend guide",
                icon: "pencil.and.ruler",
                tint: RLComponentType.drawingTrendline.color
            ) {
                addDrawing(type: .trendline)
            }

            catalogRow(
                title: "Horizontal Line",
                subtitle: "Add a key price level",
                icon: "line.3.horizontal",
                tint: RLComponentType.drawingHorizontalLine.color
            ) {
                addDrawing(type: .horizontalLine)
            }
        }
    }

    private var zonesSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            catalogRow(
                title: "Zone",
                subtitle: "Highlight a support/resistance area",
                icon: "square.dashed",
                tint: RLComponentType.drawingZone.color
            ) {
                addDrawing(type: .zone)
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
            catalogRow(
                title: "Text Note",
                subtitle: textNoteDrawing == nil
                    ? "Add anchored context to the chart"
                    : "Edit the note inline below",
                icon: "text.bubble",
                tint: RLComponentType.textNote.color
            ) {
                addTextNote()
            }

            if let drawing = textNoteDrawing {
                annotationEditorCard {
                    TextField(
                        "Write annotation",
                        text: noteBinding(for: drawing.id, fallback: drawing.note ?? "")
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

                annotationRemoveButton("Remove Note") {
                    drawingManager.removeDrawing(id: drawing.id)
                    infoMessage = nil
                    limitWarning = nil
                }
            }
        }
    }

    private var emojiAnnotationCard: some View {
        let currentEmoji = emojiDrawing?.emoji

        return VStack(alignment: .leading, spacing: 8) {
            catalogRow(
                title: "Emoji",
                subtitle: currentEmoji == nil
                    ? "Add a single emoji annotation"
                    : "Choose the emoji below",
                icon: "face.smiling",
                tint: RLComponentType.reactionEmoji.color
            ) {
                setAnnotationEmoji(currentEmoji ?? (annotationEmojis.first ?? "🎯"))
            }

            if currentEmoji != nil {
                annotationEditorCard {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(annotationEmojis, id: \.self) { emoji in
                            let isSelected = currentEmoji == emoji
                            Button {
                                setAnnotationEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(height: 30)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(AppColors.whiteText.opacity(isSelected ? 0.14 : 0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                AppColors.surfaceWhite70.opacity(isSelected ? 0.85 : 0.18),
                                                lineWidth: isSelected ? 1.5 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                annotationRemoveButton("Remove Emoji") {
                    if let drawing = emojiDrawing {
                        drawingManager.removeDrawing(id: drawing.id)
                        infoMessage = nil
                        limitWarning = nil
                    }
                }
            }
        }
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

    private var patternsSubTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pattern templates are coming soon.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
        }
    }

    private func catalogRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        onAdd: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tint)
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.statusPositive80)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
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

    private func addDrawing(type: ChartDrawingType, note: String? = nil, emoji: String? = nil) {
        guard drawingManager.drawings.count < maxDrawingOverlays else {
            limitWarning = "Maximum \(maxDrawingOverlays) drawing overlays"
            HapticFeedback.light.trigger()
            return
        }

        drawingManager.startDrawingWorkflow(type: type)
        _ = drawingManager.addDrawing(
            type: type,
            colorHex: selectedColorHex,
            note: note,
            emoji: emoji
        )
        onBeginInteractiveDrawing?()
        drawingManager.commitDrawingAndExit()
        limitWarning = nil
        infoMessage = "Added \(type.title)."
    }

    private func addTextNote() {
        guard textNoteDrawing == nil else { return }
        guard drawingManager.drawings.count < maxDrawingOverlays else {
            limitWarning = "Maximum \(maxDrawingOverlays) drawing overlays"
            HapticFeedback.light.trigger()
            return
        }
        _ = drawingManager.addDrawing(type: .textNote, colorHex: selectedColorHex, note: "Add your context")
        infoMessage = "Added Text Note."
        limitWarning = nil
    }

    private func setAnnotationEmoji(_ emoji: String) {
        if let existing = emojiDrawing {
            drawingManager.updateEmoji(id: existing.id, emoji: emoji)
            infoMessage = "Updated Emoji."
            return
        }
        guard drawingManager.drawings.count < maxDrawingOverlays else {
            limitWarning = "Maximum \(maxDrawingOverlays) drawing overlays"
            HapticFeedback.light.trigger()
            return
        }
        _ = drawingManager.addDrawing(type: .emoji, colorHex: selectedColorHex, emoji: emoji)
        infoMessage = "Added Emoji."
        limitWarning = nil
    }

    private func noteBinding(for drawingId: UUID, fallback: String) -> Binding<String> {
        Binding(
            get: {
                drawingManager.drawings.first(where: { $0.id == drawingId })?.note ?? fallback
            },
            set: { newValue in
                drawingManager.updateNote(id: drawingId, note: newValue)
            }
        )
    }

    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
    }
}
