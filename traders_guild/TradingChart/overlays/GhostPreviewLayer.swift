import SwiftUI

struct GhostPreviewLayer: View {
    @ObservedObject var placementState: MarkerPlacementState
    let yForPrice: (Double) -> CGFloat?
    let width: CGFloat
    let topSafeAreaInset: CGFloat
    let xForTime: ((Date) -> CGFloat?)?
    let guidePoint: (time: Date, price: Double)?
    let drawingInteractionPhase: DrawingInteractionPhase
    let editingDrawingId: UUID?
    /// Optional price formatter — uses symbol-appropriate decimal places when provided.
    var formatPrice: ((Double) -> String)?
    @State private var annotationDragStartOffsets: [UUID: CGPoint] = [:]

    init(
        placementState: MarkerPlacementState,
        yForPrice: @escaping (Double) -> CGFloat?,
        width: CGFloat,
        topSafeAreaInset: CGFloat = 0,
        xForTime: ((Date) -> CGFloat?)? = nil,
        guidePoint: (time: Date, price: Double)? = nil,
        drawingInteractionPhase: DrawingInteractionPhase = .idle,
        editingDrawingId: UUID? = nil,
        formatPrice: ((Double) -> String)? = nil
    ) {
        self.placementState = placementState
        self.yForPrice = yForPrice
        self.width = width
        self.topSafeAreaInset = topSafeAreaInset
        self.xForTime = xForTime
        self.guidePoint = guidePoint
        self.drawingInteractionPhase = drawingInteractionPhase
        self.editingDrawingId = editingDrawingId
        self.formatPrice = formatPrice
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Canvas layer for lines, zones, and anchor crosshair
            Canvas { context, size in
                drawLevels(context: context)
                drawTrendlines(context: context)
                drawZones(context: context)
                drawTrendlinePlacementPreview(context: context)
                drawGuideCrosshair(context: context, size: size)
            }
            .allowsHitTesting(false)

            // SwiftUI overlay for price labels (crisp text rendering)
            ForEach(placementState.components.filter { $0.componentType.isLevel }, id: \.id) { draft in
                if let price = draft.payload.levelPrice, let y = yForPrice(price) {
                    let isFixedSetupEntry = placementState.intent == .setup && draft.componentType == .levelEntry
                    priceLabelView(
                        label: draft.componentType.shortLabel,
                        price: price,
                        color: draft.componentType.color,
                        y: y,
                        isFixed: isFixedSetupEntry
                    )
                }
            }

            if shouldShowSetupInfoPanel {
                setupInfoPanel
                    .padding(.leading, 8)
                    .padding(.top, setupInfoTopPadding)
                    .allowsHitTesting(false)
            }

            annotationOverlayLayer
        }
    }

    // MARK: - Price Label (SwiftUI overlay for crisp text)

    private func priceLabelView(label: String, price: Double, color: Color, y: CGFloat, isFixed: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                if isFixed {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.82))
                }
                Text(formattedPrice(price))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
                    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.8))
            )
            .padding(.trailing, 64) // offset from right edge to stay left of Y-axis
        }
        .position(x: width / 2, y: y)
        .allowsHitTesting(false)
    }

    // MARK: - Canvas Drawing

    private func drawLevels(context: GraphicsContext) {
        for draft in placementState.components where draft.componentType.isLevel {
            guard let price = draft.payload.levelPrice, let y = yForPrice(price) else { continue }
            let isFixedSetupEntry = placementState.intent == .setup && draft.componentType == .levelEntry

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))

            context.stroke(
                path,
                with: .color(color(for: draft.componentType).opacity(isFixedSetupEntry ? 0.72 : 0.58)),
                style: isFixedSetupEntry
                    ? StrokeStyle(lineWidth: 1.8)
                    : StrokeStyle(lineWidth: 1.6, dash: [8, 6])
            )
        }
    }

    private func drawTrendlines(context: GraphicsContext) {
        for trendline in placementState.components where trendline.componentType == .drawingTrendline {
            guard case let .drawingTrendline(payload) = trendline.payload else { continue }
            guard let startY = yForPrice(payload.startPrice), let endY = yForPrice(payload.endPrice) else { continue }

            let startX = xForTime?(payload.startTime) ?? width * 0.24
            let endX = xForTime?(payload.endTime) ?? width * 0.76

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(
                path,
                with: .color(RLComponentType.drawingTrendline.color.opacity(0.64)),
                style: StrokeStyle(lineWidth: 2.0, dash: [10, 6])
            )

            if drawingInteractionPhase == .editing, editingDrawingId == trendline.id {
                context.stroke(
                    path,
                    with: .color(RLComponentType.drawingTrendline.color.opacity(0.92)),
                    style: StrokeStyle(lineWidth: 2.8)
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: startX, y: startY),
                    color: RLComponentType.drawingTrendline.color,
                    size: 20
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: endX, y: endY),
                    color: RLComponentType.drawingTrendline.color,
                    size: 20
                )
            }
        }
    }

    private func drawZones(context: GraphicsContext) {
        for zone in placementState.components where zone.componentType == .drawingZone {
            guard case let .drawingZone(payload) = zone.payload else { continue }
            guard let topY = yForPrice(payload.topPrice), let bottomY = yForPrice(payload.bottomPrice) else { continue }

            let startX = (payload.startTime.flatMap { xForTime?($0) }) ?? width * 0.22
            let endX = (payload.endTime.flatMap { xForTime?($0) }) ?? width * 0.78
            let rect = CGRect(
                x: min(startX, endX),
                y: min(topY, bottomY),
                width: abs(endX - startX),
                height: max(2, abs(bottomY - topY))
            )

            context.fill(Path(rect), with: .color(RLComponentType.drawingZone.color.opacity(0.18)))
            context.stroke(
                Path(rect),
                with: .color(RLComponentType.drawingZone.color.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.4, dash: [6, 5])
            )

            if drawingInteractionPhase == .editing, editingDrawingId == zone.id {
                context.stroke(
                    Path(rect),
                    with: .color(RLComponentType.drawingZone.color.opacity(0.9)),
                    style: StrokeStyle(lineWidth: 2.2)
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: startX, y: topY),
                    color: RLComponentType.drawingZone.color,
                    size: 20
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: endX, y: bottomY),
                    color: RLComponentType.drawingZone.color,
                    size: 20
                )
            }
        }
    }

    private func drawTrendlinePlacementPreview(context: GraphicsContext) {
        guard drawingInteractionPhase == .placingSecondPoint,
              let firstPoint = placementState.pendingDrawingFirstPoint,
              let guidePoint,
              let firstY = yForPrice(firstPoint.price),
              let guideY = yForPrice(guidePoint.price) else {
            return
        }

        let firstX = xForTime?(firstPoint.time) ?? width * 0.5
        let guideX = xForTime?(guidePoint.time) ?? width * 0.5

        var path = Path()
        path.move(to: CGPoint(x: firstX, y: firstY))
        path.addLine(to: CGPoint(x: guideX, y: guideY))
        context.stroke(
            path,
            with: .color(RLComponentType.drawingTrendline.color.opacity(0.82)),
            style: StrokeStyle(lineWidth: 2.2)
        )

        drawControlHandle(
            context: context,
            center: CGPoint(x: firstX, y: firstY),
            color: RLComponentType.drawingTrendline.color,
            size: 18
        )
        drawControlHandle(
            context: context,
            center: CGPoint(x: guideX, y: guideY),
            color: RLComponentType.drawingTrendline.color,
            size: 18
        )
    }

    private func drawGuideCrosshair(context: GraphicsContext, size: CGSize) {
        guard drawingInteractionPhase == .placingFirstPoint || drawingInteractionPhase == .placingSecondPoint,
              let guidePoint,
              let y = yForPrice(guidePoint.price) else {
            return
        }

        let x = xForTime?(guidePoint.time) ?? size.width / 2

        var crosshair = Path()
        crosshair.move(to: CGPoint(x: x, y: 0))
        crosshair.addLine(to: CGPoint(x: x, y: size.height))
        crosshair.move(to: CGPoint(x: 0, y: y))
        crosshair.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(
            crosshair,
            with: .color(Color.white.opacity(0.22)),
            style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
        )

        drawControlHandle(
            context: context,
            center: CGPoint(x: x, y: y),
            color: .white,
            size: 14
        )
    }

    private func drawControlHandle(context: GraphicsContext, center: CGPoint, color: Color, size: CGFloat) {
        let outerHalf = size / 2
        let innerSize = max(6, size * 0.45)
        let innerHalf = innerSize / 2
        let outerRect = CGRect(x: center.x - outerHalf, y: center.y - outerHalf, width: size, height: size)
        let innerRect = CGRect(x: center.x - innerHalf, y: center.y - innerHalf, width: innerSize, height: innerSize)
        context.fill(Path(ellipseIn: outerRect), with: .color(Color.black.opacity(0.75)))
        context.stroke(
            Path(ellipseIn: outerRect),
            with: .color(color.opacity(0.8)),
            style: StrokeStyle(lineWidth: 1.0)
        )
        context.fill(Path(ellipseIn: innerRect), with: .color(color.opacity(0.95)))
    }

    // MARK: - Helpers

    private func color(for componentType: RLComponentType) -> Color {
        componentType.color
    }

    private var shouldShowSetupInfoPanel: Bool {
        placementState.intent == .setup && placementState.setupEntryPrice != nil
    }

    private var annotationOverlayLayer: some View {
        ZStack {
            ForEach(annotationDrafts) { draft in
                annotationView(for: draft)
            }
        }
    }

    private var annotationDrafts: [MarkerComponentDraft] {
        placementState.components.filter {
            $0.componentType == .textNote || $0.componentType == .reactionEmoji
        }
    }

    @ViewBuilder
    private func annotationView(for draft: MarkerComponentDraft) -> some View {
        if let anchorPoint = annotationAnchorPoint {
            let offset = annotationOffset(for: draft.payload)
            let x = anchorPoint.x + CGFloat(offset.x)
            let y = anchorPoint.y + CGFloat(offset.y)
            let isSelectedForEditing = drawingInteractionPhase == .editing && editingDrawingId == draft.id

            switch draft.payload {
            case .note(let payload):
                if isSelectedForEditing {
                    annotationNoteView(text: payload.text, isSelected: true)
                        .position(x: x, y: y)
                        .highPriorityGesture(annotationDragGesture(draftId: draft.id, payload: draft.payload))
                        .allowsHitTesting(true)
                } else {
                    annotationNoteView(text: payload.text, isSelected: false)
                        .position(x: x, y: y)
                        .allowsHitTesting(false)
                }
            case .reactionEmoji(let payload):
                if isSelectedForEditing {
                    annotationEmojiView(emoji: payload.emoji, isSelected: true)
                        .position(x: x, y: y)
                        .highPriorityGesture(annotationDragGesture(draftId: draft.id, payload: draft.payload))
                        .allowsHitTesting(true)
                } else {
                    annotationEmojiView(emoji: payload.emoji, isSelected: false)
                        .position(x: x, y: y)
                        .allowsHitTesting(false)
                }
            default:
                EmptyView()
            }
        }
    }

    private func annotationNoteView(text: String, isSelected: Bool) -> some View {
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note" : text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(2)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(isSelected ? 0.82 : 0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                RLComponentType.textNote.color.opacity(isSelected ? 0.9 : 0.55),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
            )
            .shadow(
                color: RLComponentType.textNote.color.opacity(isSelected ? 0.35 : 0),
                radius: isSelected ? 6 : 0,
                x: 0,
                y: 0
            )
    }

    private func annotationEmojiView(emoji: String, isSelected: Bool) -> some View {
        Text(emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎯" : emoji)
            .font(.system(size: 23))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(isSelected ? 0.8 : 0.66))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                RLComponentType.reactionEmoji.color.opacity(isSelected ? 0.92 : 0.55),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
            )
            .shadow(
                color: RLComponentType.reactionEmoji.color.opacity(isSelected ? 0.35 : 0),
                radius: isSelected ? 6 : 0,
                x: 0,
                y: 0
            )
    }

    private func annotationDragGesture(
        draftId: UUID,
        payload: MarkerComponentPayload
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard drawingInteractionPhase == .editing, editingDrawingId == draftId else {
                    return
                }
                let baseOffset = annotationDragStartOffsets[draftId] ?? CGPoint(
                    x: annotationOffset(for: payload).x,
                    y: annotationOffset(for: payload).y
                )
                if annotationDragStartOffsets[draftId] == nil {
                    annotationDragStartOffsets[draftId] = baseOffset
                }

                let nextOffset = CGPoint(
                    x: baseOffset.x + value.translation.width,
                    y: baseOffset.y + value.translation.height
                )
                updateAnnotationOffset(draftId: draftId, payload: payload, offset: nextOffset)
            }
            .onEnded { _ in
                guard drawingInteractionPhase == .editing, editingDrawingId == draftId else {
                    annotationDragStartOffsets[draftId] = nil
                    return
                }
                annotationDragStartOffsets[draftId] = nil
            }
    }

    private var annotationAnchorPoint: CGPoint? {
        guard let anchor = placementState.anchorDraft,
              let anchorPrice = anchor.payload.levelPrice,
              let anchorY = yForPrice(anchorPrice) else {
            return nil
        }
        let anchorX = xForTime?(anchor.payload.anchorTime ?? Date()) ?? width * 0.5
        return CGPoint(x: anchorX, y: anchorY)
    }

    private func annotationOffset(for payload: MarkerComponentPayload) -> CGPoint {
        switch payload {
        case let .note(note):
            return CGPoint(x: note.offsetX ?? 0, y: note.offsetY ?? -36)
        case let .reactionEmoji(emoji):
            return CGPoint(x: emoji.offsetX ?? 0, y: emoji.offsetY ?? -68)
        default:
            return .zero
        }
    }

    private func updateAnnotationOffset(
        draftId: UUID,
        payload: MarkerComponentPayload,
        offset: CGPoint
    ) {
        switch payload {
        case let .note(note):
            placementState.updateComponent(
                id: draftId,
                payload: .note(
                    NotePayload(
                        text: note.text,
                        offsetX: Double(offset.x),
                        offsetY: Double(offset.y)
                    )
                )
            )
        case let .reactionEmoji(emoji):
            placementState.updateComponent(
                id: draftId,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: emoji.emoji,
                        offsetX: Double(offset.x),
                        offsetY: Double(offset.y)
                    )
                )
            )
        default:
            break
        }
    }

    private var setupInfoTopPadding: CGFloat {
        let chartInfoTop = topSafeAreaInset > 0 ? topSafeAreaInset + 62 : 124
        return chartInfoTop + 98
    }

    private var setupInfoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            setupMetricRow(
                label: "Entry",
                value: placementState.setupEntryPrice.map(formattedPrice) ?? "—",
                valueColor: .white
            )
            setupMetricRow(
                label: "TP",
                value: componentPriceText(.levelTp),
                valueColor: .green
            )
            setupMetricRow(
                label: "SL",
                value: componentPriceText(.levelSl),
                valueColor: .red
            )
            setupMetricRow(
                label: "Pip Range",
                value: placementState.setupPnLPips.map(formattedPips) ?? "—",
                valueColor: .white.opacity(0.9)
            )
            setupMetricRow(
                label: "R:R",
                value: placementState.setupRiskReward.map { String(format: "%.2f", $0) } ?? "—",
                valueColor: .white.opacity(0.9)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 178, alignment: .leading)
        .background(Color.black.opacity(0.28))
        .cornerRadius(8)
    }

    private func setupMetricRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }

    private func componentPriceText(_ componentType: RLComponentType) -> String {
        guard let price = placementState.componentPrice(componentType) else { return "—" }
        return formattedPrice(price)
    }

    private func formattedPrice(_ price: Double) -> String {
        if let formatPrice {
            return formatPrice(price)
        }
        // Fallback: auto-detect appropriate decimal places
        if price >= 100 {
            return String(format: "%.2f", price)
        } else if price >= 1 {
            return String(format: "%.4f", price)
        } else {
            return String(format: "%.5f", price)
        }
    }

    private func formattedPips(_ pips: Double) -> String {
        if pips >= 1000 {
            return String(format: "%.0f", pips)
        }
        return String(format: "%.1f", pips)
    }
}
