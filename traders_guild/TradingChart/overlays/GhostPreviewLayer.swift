import SwiftUI

struct GhostPreviewLayer: View {
    @ObservedObject var placementState: MarkerPlacementState
    let yForPrice: (Double) -> CGFloat?
    let width: CGFloat
    let topSafeAreaInset: CGFloat
    let bottomPanelPadding: CGFloat
    let xForTime: ((Date) -> CGFloat?)?
    let guidePoint: (time: Date, price: Double)?
    let drawingInteractionPhase: DrawingInteractionPhase
    let editingDrawingId: UUID?
    /// Optional price formatter — uses symbol-appropriate decimal places when provided.
    var formatPrice: ((Double) -> String)?
    @State private var annotationDragStartOffsets: [UUID: CGPoint] = [:]
    @State private var emojiScaleStartValues: [UUID: CGFloat] = [:]

    init(
        placementState: MarkerPlacementState,
        yForPrice: @escaping (Double) -> CGFloat?,
        width: CGFloat,
        topSafeAreaInset: CGFloat = 0,
        bottomPanelPadding: CGFloat = 74,
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
        self.bottomPanelPadding = bottomPanelPadding
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
                drawHorizontalLines(context: context)
                drawTrendlines(context: context)
                drawZones(context: context)
                drawTrendlinePlacementPreview(context: context)
                drawGuideCrosshair(context: context, size: size)
            }
            .allowsHitTesting(false)

            // SwiftUI overlay for price labels (crisp text rendering)
            ForEach(placementState.components.filter { $0.componentType.isLevel }, id: \.id) { draft in
                if shouldRenderLevelLabel(for: draft.componentType),
                   let price = draft.payload.levelPrice,
                   let y = yForPrice(price) {
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

            if shouldShowInfoPanels {
                VStack {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 0) {
                        infoPanelsStack
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, infoPanelsBottomPadding)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                        .foregroundColor(AppColors.surfaceWhite82)
                }
                Text(formattedPrice(price))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite90)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(AppColors.surfaceBlack70)
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
            guard shouldRenderSetupCoreLevelLine(for: draft.componentType) else { continue }
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
            let trendlineColor = placementState.drawingColor(
                for: trendline.id,
                fallback: RLComponentType.drawingTrendline.color
            )
            let isHorizontal = abs(payload.startPrice - payload.endPrice) < 0.0000001

            if isHorizontal {
                drawHorizontalLine(
                    context: context,
                    y: startY,
                    price: payload.startPrice,
                    label: "Line",
                    color: trendlineColor,
                    isEditing: drawingInteractionPhase == .editing && editingDrawingId == trendline.id
                )
                continue
            }

            let startX = xForTime?(payload.startTime) ?? width * 0.24
            let endX = xForTime?(payload.endTime) ?? width * 0.76

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(
                path,
                with: .color(trendlineColor.opacity(0.64)),
                style: StrokeStyle(lineWidth: 2.0, dash: [10, 6])
            )

            if drawingInteractionPhase == .editing, editingDrawingId == trendline.id {
                context.stroke(
                    path,
                    with: .color(trendlineColor.opacity(0.92)),
                    style: StrokeStyle(lineWidth: 2.8)
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: startX, y: startY),
                    color: trendlineColor,
                    size: 20
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: endX, y: endY),
                    color: trendlineColor,
                    size: 20
                )
            }
        }
    }

    private func drawHorizontalLines(context: GraphicsContext) {
        for line in placementState.components where line.componentType == .drawingHorizontalLine {
            guard case let .drawingHorizontalLine(payload) = line.payload else { continue }
            guard let y = yForPrice(payload.price) else { continue }
            let lineColor = placementState.drawingColor(
                for: line.id,
                fallback: RLComponentType.drawingHorizontalLine.color
            )
            let resolvedLabel: String = {
                let trimmed = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? "Line" : trimmed
            }()
            drawHorizontalLine(
                context: context,
                y: y,
                price: payload.price,
                label: resolvedLabel,
                color: lineColor,
                isEditing: drawingInteractionPhase == .editing && editingDrawingId == line.id
            )
        }
    }

    private func drawHorizontalLine(
        context: GraphicsContext,
        y: CGFloat,
        price: Double,
        label: String,
        color: Color,
        isEditing: Bool
    ) {
        let startX: CGFloat = 0
        let endX: CGFloat = max(0, width - 60)
        var path = Path()
        path.move(to: CGPoint(x: startX, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))
        context.stroke(
            path,
            with: .color(color.opacity(isEditing ? 0.92 : 0.64)),
            style: StrokeStyle(lineWidth: isEditing ? 2.6 : 2.0, dash: [10, 6])
        )

        drawHorizontalLineLabel(
            context: context,
            y: y,
            price: price,
            label: label,
            color: color
        )

        if isEditing {
            drawControlHandle(
                context: context,
                center: CGPoint(x: (startX + endX) * 0.5, y: y),
                color: color,
                size: 20
            )
        }
    }

    private func drawHorizontalLineLabel(
        context: GraphicsContext,
        y: CGFloat,
        price: Double,
        label: String,
        color: Color
    ) {
        let displayText = "\(label) \(formattedPrice(price))"
        let estimatedWidth = max(52, CGFloat(displayText.count) * 5.6 + 10)
        let labelX = max(10 + estimatedWidth / 2, width - 38)

        let labelRect = CGRect(
            x: labelX - estimatedWidth / 2,
            y: y - 11,
            width: estimatedWidth,
            height: 22
        )

        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
        context.fill(roundedPath, with: .color(color.opacity(0.88)))
        context.draw(
            Text(displayText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: labelX, y: y)
        )
    }

    private func drawZones(context: GraphicsContext) {
        for zone in placementState.components where zone.componentType == .drawingZone {
            guard case let .drawingZone(payload) = zone.payload else { continue }
            guard let topY = yForPrice(payload.topPrice), let bottomY = yForPrice(payload.bottomPrice) else { continue }
            let zoneColor = placementState.drawingColor(
                for: zone.id,
                fallback: RLComponentType.drawingZone.color
            )

            let startX = (payload.startTime.flatMap { xForTime?($0) }) ?? width * 0.22
            let endX = (payload.endTime.flatMap { xForTime?($0) }) ?? width * 0.78
            let rect = CGRect(
                x: min(startX, endX),
                y: min(topY, bottomY),
                width: abs(endX - startX),
                height: max(2, abs(bottomY - topY))
            )

            context.fill(Path(rect), with: .color(zoneColor.opacity(0.18)))
            context.stroke(
                Path(rect),
                with: .color(zoneColor.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.4, dash: [6, 5])
            )

            if drawingInteractionPhase == .editing, editingDrawingId == zone.id {
                context.stroke(
                    Path(rect),
                    with: .color(zoneColor.opacity(0.9)),
                    style: StrokeStyle(lineWidth: 2.2)
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: startX, y: topY),
                    color: zoneColor,
                    size: 20
                )
                drawControlHandle(
                    context: context,
                    center: CGPoint(x: endX, y: bottomY),
                    color: zoneColor,
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
            with: .color(AppColors.surfaceWhite22),
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
        context.fill(Path(ellipseIn: outerRect), with: .color(AppColors.surfaceBlack75))
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
            // Alert markers: note text is managed in the general tab, not as a chart overlay
            if $0.componentType == .textNote {
                return placementState.intent != .alert
            }
            if $0.componentType == .reactionEmoji {
                return placementState.intent != .reaction
            }
            return false
        }
    }

    private func shouldRenderLevelLabel(for componentType: RLComponentType) -> Bool {
        if componentType == .levelSupport || componentType == .levelResistance {
            return false
        }
        return shouldRenderSetupCoreLevelLine(for: componentType)
    }

    private func shouldRenderSetupCoreLevelLine(for componentType: RLComponentType) -> Bool {
        if placementState.intent != .setup { return true }
        return componentType != .levelEntry && componentType != .levelTp && componentType != .levelSl
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
                        .scaleEffect(placementState.emojiScale(for: draft.id))
                        .position(x: x, y: y)
                        .highPriorityGesture(annotationDragGesture(draftId: draft.id, payload: draft.payload))
                        .simultaneousGesture(annotationEmojiScaleGesture(draftId: draft.id))
                        .allowsHitTesting(true)
                } else {
                    annotationEmojiView(emoji: payload.emoji, isSelected: false)
                        .scaleEffect(placementState.emojiScale(for: draft.id))
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
                    .fill(AppColors.systemBlack.opacity(isSelected ? 0.82 : 0.7))
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
                    .fill(AppColors.systemBlack.opacity(isSelected ? 0.8 : 0.66))
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

    private func annotationEmojiScaleGesture(draftId: UUID) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard drawingInteractionPhase == .editing, editingDrawingId == draftId else {
                    return
                }
                if emojiScaleStartValues[draftId] == nil {
                    emojiScaleStartValues[draftId] = placementState.emojiScale(for: draftId)
                }
                let base = emojiScaleStartValues[draftId] ?? placementState.emojiScale(for: draftId)
                placementState.setEmojiScale(base * value, for: draftId)
            }
            .onEnded { _ in
                emojiScaleStartValues[draftId] = nil
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

    private var infoPanelsBottomPadding: CGFloat {
        bottomPanelPadding
    }

    private var infoPanelsStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowChecklistPanel {
                checklistPanel
            }
        }
    }

    private var infoPanelWidth: CGFloat {
        min(224, max(168, width * 0.36))
    }

    private var shouldShowInfoPanels: Bool {
        shouldShowChecklistPanel
    }

    private var shouldShowChecklistPanel: Bool {
        !placementState.placementChecklistItems.isEmpty
    }

    private var checklistPanel: some View {
        Group {
            if placementState.isChecklistCollapsed {
                collapsedChecklistStrip
            } else {
                expandedChecklistPanel
            }
        }
    }

    private var expandedChecklistPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(placementState.intent.color.opacity(0.92))
                    Text("Checklist")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite94)
                    Spacer(minLength: 0)
                    Text("\(completedChecklistItemCount)/\(placementState.placementChecklistItems.count)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.surfaceWhite80)
                }

                Divider()
                    .overlay(AppColors.surfaceWhite12)

                ForEach(placementState.placementChecklistItems) { item in
                    checklistRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OverlayPanelChrome.sideHandle(icon: "chevron.left")
                .onTapGesture(perform: toggleChecklistPanel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: infoPanelWidth, alignment: .leading)
        .background(OverlayPanelChrome.background(cornerRadius: 12))
    }

    private var collapsedChecklistStrip: some View {
        VStack(spacing: 7) {
            Image(systemName: "checklist")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(placementState.intent.color.opacity(0.92))
            Text("\(completedChecklistItemCount)/\(placementState.placementChecklistItems.count)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.surfaceWhite90)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppColors.surfaceWhite82)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
        .frame(width: 30, alignment: .center)
        .background(OverlayPanelChrome.background(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: toggleChecklistPanel)
    }

    private var completedChecklistItemCount: Int {
        placementState.placementChecklistItems.filter { $0.isComplete }.count
    }

    private func checklistRow(_ item: MarkerPlacementChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(item.isComplete ? AppColors.statusPositive95 : AppColors.surfaceWhite50)

            Text(item.title)
                .font(.system(size: 9.5, weight: item.isRequired ? .semibold : .regular))
                .foregroundColor(item.isComplete ? AppColors.surfaceWhite93 : AppColors.surfaceWhite82)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Text(item.isRequired ? "REQ" : "TIP")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(item.isRequired ? AppColors.statusWarning95 : AppColors.greyText)
        }
    }

    private func toggleChecklistPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            placementState.isChecklistCollapsed.toggle()
        }
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

}
