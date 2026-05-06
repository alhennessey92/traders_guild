import SwiftUI

struct ChartAnnotationBubbleMetrics {
    static let maxWidth: CGFloat = 180
    static let minWidth: CGFloat = 52
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 6
    static let cornerRadius: CGFloat = 7
    static let fontSize: CGFloat = 11
    static let lineHeight: CGFloat = 14
    static let maxVisibleLines = 4

    private static let sideInset: CGFloat = 16
    private static let estimatedAverageCharacterWidth: CGFloat = 6.2

    static func displayText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note" : text
    }

    static func maxBubbleWidth(plotWidth: CGFloat) -> CGFloat {
        min(maxWidth, max(minWidth, plotWidth - sideInset))
    }

    static func visibleLineCount(for text: String, plotWidth: CGFloat) -> Int {
        min(maxVisibleLines, max(1, estimatedWrappedLineCount(for: text, plotWidth: plotWidth)))
    }

    static func estimatedSize(for text: String, plotWidth: CGFloat) -> CGSize {
        let display = displayText(text)
        let maxTextWidth = max(1, maxBubbleWidth(plotWidth: plotWidth) - horizontalPadding * 2)
        let longestLineWidth = display
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { CGFloat($0.count) * estimatedAverageCharacterWidth }
            .max() ?? 0
        let textWidth = min(maxTextWidth, max(estimatedAverageCharacterWidth * 4, longestLineWidth))
        let visibleLines = CGFloat(visibleLineCount(for: display, plotWidth: plotWidth))

        return CGSize(
            width: ceil(textWidth + horizontalPadding * 2),
            height: ceil(visibleLines * lineHeight + verticalPadding * 2)
        )
    }

    static func hitRect(
        center: CGPoint,
        text: String,
        plotWidth: CGFloat,
        touchExpansion: CGFloat = 8
    ) -> CGRect {
        let size = estimatedSize(for: text, plotWidth: plotWidth)
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        ).insetBy(dx: -touchExpansion, dy: -touchExpansion)
    }

    private static func estimatedWrappedLineCount(for text: String, plotWidth: CGFloat) -> Int {
        let display = displayText(text)
        let maxTextWidth = max(1, maxBubbleWidth(plotWidth: plotWidth) - horizontalPadding * 2)

        return display
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { total, line in
                guard !line.isEmpty else { return total + 1 }
                let rawLineWidth = CGFloat(line.count) * estimatedAverageCharacterWidth
                return total + max(1, Int(ceil(rawLineWidth / maxTextWidth)))
            }
    }
}

struct GhostPreviewLayer: View {
    @ObservedObject var placementState: MarkerPlacementState
    let yForPrice: (Double) -> CGFloat?
    let width: CGFloat
    let topSafeAreaInset: CGFloat
    let bottomPanelPadding: CGFloat
    let xForTime: ((Date) -> CGFloat?)?
    let timeForX: ((CGFloat) -> Date?)?
    let guidePoint: (time: Date, price: Double)?
    let drawingInteractionPhase: DrawingInteractionPhase
    let editingDrawingId: UUID?
    let showsInfoPanels: Bool
    /// Optional price formatter — uses symbol-appropriate decimal places when provided.
    var formatPrice: ((Double) -> String)?
    /// When true, emoji rendering is suppressed here (handled by a separate lower-z layer).
    let suppressEmojiBackground: Bool
    @State private var annotationDragStartCenters: [UUID: CGPoint] = [:]
    @State private var emojiScaleStartValues: [UUID: CGFloat] = [:]
    @State private var textFontSizeStartValues: [UUID: CGFloat] = [:]

    init(
        placementState: MarkerPlacementState,
        yForPrice: @escaping (Double) -> CGFloat?,
        width: CGFloat,
        topSafeAreaInset: CGFloat = 0,
        bottomPanelPadding: CGFloat = 74,
        xForTime: ((Date) -> CGFloat?)? = nil,
        timeForX: ((CGFloat) -> Date?)? = nil,
        guidePoint: (time: Date, price: Double)? = nil,
        drawingInteractionPhase: DrawingInteractionPhase = .idle,
        editingDrawingId: UUID? = nil,
        showsInfoPanels: Bool = true,
        formatPrice: ((Double) -> String)? = nil,
        suppressEmojiBackground: Bool = false
    ) {
        self.placementState = placementState
        self.yForPrice = yForPrice
        self.width = width
        self.topSafeAreaInset = topSafeAreaInset
        self.bottomPanelPadding = bottomPanelPadding
        self.xForTime = xForTime
        self.timeForX = timeForX
        self.guidePoint = guidePoint
        self.drawingInteractionPhase = drawingInteractionPhase
        self.editingDrawingId = editingDrawingId
        self.showsInfoPanels = showsInfoPanels
        self.formatPrice = formatPrice
        self.suppressEmojiBackground = suppressEmojiBackground
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Emoji layer — only rendered here when not suppressed
            // (when suppressed, a separate lower-z view handles non-editing emojis)
            if !suppressEmojiBackground {
                emojiBackgroundLayer
            }

            // Canvas layer for lines, zones, and anchor crosshair
            Canvas { context, size in
                drawLevels(context: context)
                drawHorizontalLines(context: context)
                drawTrendlines(context: context)
                drawZones(context: context)
                drawEmojiResizeHandles(context: context)
                drawTrendlinePlacementPreview(context: context)
                drawGuideCrosshair(context: context, size: size)
            }
            .allowsHitTesting(false)

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

            // Text notes on top, readable above candles
            textNoteOverlayLayer

            // When emojis are suppressed, still render the actively-edited emoji here for gestures
            if suppressEmojiBackground {
                editingEmojiOverlay
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawLevels(context: GraphicsContext) {
        let lineEndX = ChartAxisMetrics.horizontalLineEndX(
            totalWidth: width,
            labelWidth: ChartAxisMetrics.secondaryPriceChipWidth
        )
        for draft in placementState.components where draft.componentType.isLevel {
            guard shouldRenderSetupCoreLevelLine(for: draft.componentType) else { continue }
            guard let price = draft.payload.levelPrice, let y = yForPrice(price) else { continue }
            let isFixedSetupEntry = placementState.intent == .setup && draft.componentType == .levelEntry
            let lineColor = drawingColor(for: draft)
            let lineStyle = draft.payload.drawingLineStyle ?? (isFixedSetupEntry ? .solid : .dashed)
            let lineWidth = CGFloat(
                draft.payload.drawingLineWidth
                ?? defaultIndicatorLineWidth(for: lineStyle, isFixed: isFixedSetupEntry)
            )

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))

            context.stroke(
                path,
                with: .color(lineColor.opacity(isFixedSetupEntry ? 0.84 : 0.8)),
                style: StrokeStyle(
                    lineWidth: resolvedIndicatorLineWidth(
                        for: lineStyle,
                        preferredWidth: lineWidth,
                        isFixed: isFixedSetupEntry
                    ),
                    dash: lineStyle.dashPattern
                )
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
                    color: trendlineColor,
                    lineStyle: payload.lineStyle ?? .dashed,
                    lineWidth: CGFloat(payload.lineWidth ?? 2.0),
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
                style: StrokeStyle(
                    lineWidth: CGFloat(payload.lineWidth ?? 2.0),
                    dash: (payload.lineStyle ?? .dashed).dashPattern
                )
            )

            if drawingInteractionPhase == .editing, editingDrawingId == trendline.id {
                context.stroke(
                    path,
                    with: .color(trendlineColor.opacity(0.92)),
                    style: StrokeStyle(lineWidth: CGFloat(max(payload.lineWidth ?? 2.0, 2.4)))
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
            drawHorizontalLine(
                context: context,
                y: y,
                color: lineColor,
                lineStyle: payload.lineStyle ?? .dashed,
                lineWidth: CGFloat(
                    payload.lineWidth
                    ?? defaultIndicatorLineWidth(for: payload.lineStyle ?? .dashed)
                ),
                isEditing: drawingInteractionPhase == .editing && editingDrawingId == line.id
            )
        }
    }

    private func drawHorizontalLine(
        context: GraphicsContext,
        y: CGFloat,
        color: Color,
        lineStyle: MarkerDrawingLineStyle,
        lineWidth: CGFloat,
        isEditing: Bool
    ) {
        let startX: CGFloat = 0
        let endX = ChartAxisMetrics.horizontalLineEndX(
            totalWidth: width,
            labelWidth: ChartAxisMetrics.secondaryPriceChipWidth
        )
        var path = Path()
        path.move(to: CGPoint(x: startX, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))
        let resolvedLineWidth = resolvedIndicatorLineWidth(
            for: lineStyle,
            preferredWidth: lineWidth,
            isFixed: lineStyle == .solid
        )
        context.stroke(
            path,
            with: .color(color.opacity(isEditing ? 0.9 : 0.8)),
            style: StrokeStyle(
                lineWidth: isEditing ? max(resolvedLineWidth, 2.4) : resolvedLineWidth,
                dash: lineStyle.dashPattern
            )
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
                style: StrokeStyle(
                    lineWidth: CGFloat(payload.lineWidth ?? 1.4),
                    dash: (payload.lineStyle ?? .dashed).dashPattern
                )
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

    private func drawEmojiResizeHandles(context: GraphicsContext) {
        guard drawingInteractionPhase == .editing else { return }
        for draft in placementState.components where draft.componentType == .reactionEmoji {
            guard draft.id == editingDrawingId else { continue }
            guard let anchorPoint = annotationAnchorPoint(for: draft.payload) else { continue }
            let offset = annotationOffset(for: draft.payload)
            let x = anchorPoint.x + CGFloat(offset.x)
            let y = anchorPoint.y + CGFloat(offset.y)
            guard x.isFinite, y.isFinite else { continue }

            let scale = placementState.emojiScale(for: draft.id)
            let halfSize = 13 * scale
            let handleColor = RLComponentType.reactionEmoji.color

            // Two diagonal corner handles (like zones)
            drawControlHandle(
                context: context,
                center: CGPoint(x: x - halfSize, y: y - halfSize),
                color: handleColor,
                size: 20
            )
            drawControlHandle(
                context: context,
                center: CGPoint(x: x + halfSize, y: y + halfSize),
                color: handleColor,
                size: 20
            )

            // Bounding rect outline
            let boundingRect = CGRect(
                x: x - halfSize, y: y - halfSize,
                width: halfSize * 2, height: halfSize * 2
            )
            context.stroke(
                Path(boundingRect),
                with: .color(handleColor.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1.0, dash: [4, 3])
            )
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
        let activeTool = placementState.activeDrawingWorkflowTool
        let toolRequiresGuide = activeTool.map { MarkerDrawingToolRegistry.definition(for: $0).requiresGuidePlacement } ?? false
        let shouldShowGuide = (
            toolRequiresGuide
            && (drawingInteractionPhase == .placingFirstPoint || drawingInteractionPhase == .placingSecondPoint)
        )
            || (
                drawingInteractionPhase == .editing
                && placementState.drawingSession.selectedHandle != nil
                && activeTool?.group == .pointSequence
            )

        guard shouldShowGuide,
              let guidePoint,
              let y = yForPrice(guidePoint.price),
              y.isFinite else {
            return
        }

        let x = xForTime?(guidePoint.time) ?? size.width / 2
        guard x.isFinite else { return }

        var crosshair = Path()
        crosshair.move(to: CGPoint(x: x, y: -2))
        crosshair.addLine(to: CGPoint(x: x, y: size.height + 2))
        crosshair.move(to: CGPoint(x: -2, y: y))
        crosshair.addLine(to: CGPoint(x: size.width + 2, y: y))
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

    private func defaultIndicatorLineWidth(for lineStyle: MarkerDrawingLineStyle, isFixed: Bool = false) -> Double {
        if isFixed || lineStyle == .solid {
            return 2.0
        }
        return 1.5
    }

    private func resolvedIndicatorLineWidth(
        for lineStyle: MarkerDrawingLineStyle,
        preferredWidth: CGFloat,
        isFixed: Bool = false
    ) -> CGFloat {
        if isFixed || lineStyle == .solid {
            return max(preferredWidth, 2.0)
        }
        return max(preferredWidth, 1.5)
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

    private func drawingColor(for draft: MarkerComponentDraft) -> Color {
        placementState.drawingColor(for: draft.id, fallback: color(for: draft.componentType))
    }

    private var shouldShowSetupInfoPanel: Bool {
        placementState.intent == .setup && placementState.setupEntryPrice != nil
    }

    private var emojiBackgroundLayer: some View {
        ZStack {
            ForEach(emojiDrafts) { draft in
                annotationView(for: draft)
            }
        }
    }

    private var textNoteOverlayLayer: some View {
        ZStack {
            ForEach(textNoteDrafts) { draft in
                annotationView(for: draft)
            }
        }
    }

    private var emojiDrafts: [MarkerComponentDraft] {
        placementState.components.filter {
            $0.componentType == .reactionEmoji && placementState.intent != .reaction
        }
    }

    private var textNoteDrafts: [MarkerComponentDraft] {
        placementState.components.filter {
            $0.componentType == .textNote && placementState.intent != .alert
        }
    }

    /// When emoji background is suppressed, the actively-edited emoji still needs gesture handling at this z-level.
    private var editingEmojiOverlay: some View {
        ZStack {
            if drawingInteractionPhase == .editing,
               let editingId = editingDrawingId,
               let draft = emojiDrafts.first(where: { $0.id == editingId }) {
                annotationView(for: draft)
            }
        }
    }

    private func shouldRenderLevelLabel(for componentType: RLComponentType) -> Bool {
        return shouldRenderPriceLabel(for: componentType)
    }

    private func shouldRenderPriceLabel(for componentType: RLComponentType) -> Bool {
        componentType == .drawingHorizontalLine || shouldRenderSetupCoreLevelLine(for: componentType)
    }

    private func resolvedLevelLabel(for draft: MarkerComponentDraft) -> String {
        switch draft.payload {
        case .levelSupport(let payload):
            return (payload.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? payload.label! : "Support")
        case .levelResistance(let payload):
            return (payload.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? payload.label! : "Resistance")
        case .drawingHorizontalLine(let payload):
            let trimmed = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Line" : trimmed
        default:
            return draft.componentType.shortLabel
        }
    }

    private func shouldRenderSetupCoreLevelLine(for componentType: RLComponentType) -> Bool {
        if placementState.intent != .setup { return true }
        return componentType != .levelEntry && componentType != .levelTp && componentType != .levelSl
    }

    @ViewBuilder
    private func annotationView(for draft: MarkerComponentDraft) -> some View {
        if let anchorPoint = annotationAnchorPoint(for: draft.payload) {
            let offset = annotationOffset(for: draft.payload)
            let x = anchorPoint.x + CGFloat(offset.x)
            let y = anchorPoint.y + CGFloat(offset.y)
            if x.isFinite, y.isFinite {
                let isSelectedForEditing = drawingInteractionPhase == .editing && editingDrawingId == draft.id

                switch draft.payload {
                case .note(let payload):
                    let resolvedFontSize = CGFloat(payload.fontSize ?? Double(ChartAnnotationBubbleMetrics.fontSize))
                    if isSelectedForEditing {
                        annotationNoteView(text: payload.text, isSelected: true, fontSize: resolvedFontSize, colorHex: payload.colorHex)
                            .position(x: x, y: y)
                            .highPriorityGesture(annotationDragGesture(draftId: draft.id, payload: draft.payload))
                            .simultaneousGesture(annotationTextScaleGesture(draftId: draft.id, payload: payload))
                            .allowsHitTesting(true)
                    } else {
                        annotationNoteView(text: payload.text, isSelected: false, fontSize: resolvedFontSize, colorHex: payload.colorHex)
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
    }

    private func annotationNoteView(
        text: String,
        isSelected: Bool,
        fontSize: CGFloat = ChartAnnotationBubbleMetrics.fontSize,
        colorHex: String? = nil
    ) -> some View {
        let displayText = ChartAnnotationBubbleMetrics.displayText(text)
        let resolvedColor = Color(hex: colorHex ?? "") ?? AppColors.primaryForeground
        return Text(verbatim: displayText)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(resolvedColor)
            .lineLimit(ChartAnnotationBubbleMetrics.maxVisibleLines)
            .multilineTextAlignment(.center)
            .frame(maxWidth: ChartAnnotationBubbleMetrics.maxBubbleWidth(plotWidth: width))
            .padding(.horizontal, isSelected ? ChartAnnotationBubbleMetrics.horizontalPadding : 4)
            .padding(.vertical, isSelected ? ChartAnnotationBubbleMetrics.verticalPadding : 2)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: ChartAnnotationBubbleMetrics.cornerRadius)
                            .fill(AppColors.surfaceWhite04)
                            .overlay(
                                RoundedRectangle(cornerRadius: ChartAnnotationBubbleMetrics.cornerRadius)
                                    .stroke(
                                        RLComponentType.textNote.color.opacity(0.72),
                                        lineWidth: 1.2
                                    )
                            )
                    }
                }
            )
            .fixedSize()
            .shadow(
                color: AppColors.systemBlack.opacity(isSelected ? 0.22 : 0.55),
                radius: isSelected ? 3 : 2,
                x: 0,
                y: 1
            )
    }

    private func annotationEmojiView(emoji: String, isSelected: Bool) -> some View {
        Text(emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎯" : emoji)
            .font(.system(size: isSelected ? 26 : 24))
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
                guard let anchorPoint = annotationAnchorPoint(for: payload) else { return }
                let baseCenter = annotationDragStartCenters[draftId] ?? CGPoint(
                    x: anchorPoint.x + annotationOffset(for: payload).x,
                    y: anchorPoint.y + annotationOffset(for: payload).y
                )
                if annotationDragStartCenters[draftId] == nil {
                    annotationDragStartCenters[draftId] = baseCenter
                }

                let nextCenter = CGPoint(
                    x: baseCenter.x + value.translation.width,
                    y: baseCenter.y + value.translation.height
                )
                updateAnnotationPlacement(draftId: draftId, payload: payload, center: nextCenter)
            }
            .onEnded { _ in
                guard drawingInteractionPhase == .editing, editingDrawingId == draftId else {
                    annotationDragStartCenters[draftId] = nil
                    return
                }
                annotationDragStartCenters[draftId] = nil
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
                // Persist scale into the emoji payload so it survives sync
                if let draft = placementState.components.first(where: { $0.id == draftId }),
                   case let .reactionEmoji(payload) = draft.payload {
                    let finalScale = placementState.emojiScale(for: draftId)
                    placementState.updateComponent(
                        id: draftId,
                        payload: .reactionEmoji(
                            EmojiPayload(
                                emoji: payload.emoji,
                                offsetX: payload.offsetX,
                                offsetY: payload.offsetY,
                                anchorTime: payload.anchorTime,
                                anchorPrice: payload.anchorPrice,
                                scale: Double(finalScale)
                            )
                        )
                    )
                }
            }
    }

    private func annotationTextScaleGesture(draftId: UUID, payload: NotePayload) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard drawingInteractionPhase == .editing, editingDrawingId == draftId else { return }
                if textFontSizeStartValues[draftId] == nil {
                    textFontSizeStartValues[draftId] = CGFloat(payload.fontSize ?? Double(ChartAnnotationBubbleMetrics.fontSize))
                }
                let base = textFontSizeStartValues[draftId] ?? ChartAnnotationBubbleMetrics.fontSize
                let newSize = min(28, max(8, base * value))
                placementState.updateComponent(
                    id: draftId,
                    payload: .note(
                        NotePayload(
                            text: payload.text,
                            offsetX: payload.offsetX,
                            offsetY: payload.offsetY,
                            anchorTime: payload.anchorTime,
                            anchorPrice: payload.anchorPrice,
                            fontSize: Double(newSize),
                            colorHex: payload.colorHex
                        )
                    )
                )
            }
            .onEnded { _ in
                textFontSizeStartValues[draftId] = nil
            }
    }

    private func annotationAnchorPoint(for payload: MarkerComponentPayload) -> CGPoint? {
        let fallbackAnchorTime = placementState.anchorDraft?.payload.anchorTime
        let fallbackAnchorPrice = placementState.anchorDraft?.payload.levelPrice

        let anchorTime: Date?
        let anchorPrice: Double?
        switch payload {
        case let .note(note):
            anchorTime = note.anchorTime ?? fallbackAnchorTime
            anchorPrice = note.anchorPrice ?? fallbackAnchorPrice
        case let .reactionEmoji(emoji):
            anchorTime = emoji.anchorTime ?? fallbackAnchorTime
            anchorPrice = emoji.anchorPrice ?? fallbackAnchorPrice
        default:
            anchorTime = fallbackAnchorTime
            anchorPrice = fallbackAnchorPrice
        }

        guard let anchorPrice,
              let anchorY = yForPrice(anchorPrice),
              anchorY.isFinite else {
            return nil
        }
        let anchorX = xForTime?(anchorTime ?? Date()) ?? width * 0.5
        guard anchorX.isFinite else { return nil }
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

    private func updateAnnotationPlacement(
        draftId: UUID,
        payload: MarkerComponentPayload,
        center: CGPoint
    ) {
        switch payload {
        case let .note(note):
            let resolvedAnchorTime = timeForX?(center.x) ?? note.anchorTime ?? placementState.anchorDraft?.payload.anchorTime
            let resolvedAnchorPrice = note.anchorPrice ?? placementState.anchorDraft?.payload.levelPrice
            let resolvedAnchorX = resolvedAnchorTime.flatMap { xForTime?($0) }
            let resolvedAnchorY = resolvedAnchorPrice.flatMap { yForPrice($0) }
            placementState.updateComponent(
                id: draftId,
                payload: .note(
                    NotePayload(
                        text: note.text,
                        offsetX: resolvedAnchorX.map { anchorX in
                            timeForX == nil ? Double(center.x - anchorX) : 0.0
                        },
                        offsetY: resolvedAnchorY.map { Double(center.y - $0) } ?? note.offsetY,
                        anchorTime: resolvedAnchorTime,
                        anchorPrice: resolvedAnchorPrice,
                        fontSize: note.fontSize,
                        colorHex: note.colorHex
                    )
                )
            )
        case let .reactionEmoji(emoji):
            let resolvedAnchorTime = timeForX?(center.x) ?? emoji.anchorTime ?? placementState.anchorDraft?.payload.anchorTime
            let resolvedAnchorPrice = emoji.anchorPrice ?? placementState.anchorDraft?.payload.levelPrice
            let resolvedAnchorX = resolvedAnchorTime.flatMap { xForTime?($0) }
            let resolvedAnchorY = resolvedAnchorPrice.flatMap { yForPrice($0) }
            placementState.updateComponent(
                id: draftId,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: emoji.emoji,
                        offsetX: resolvedAnchorX.map { anchorX in
                            timeForX == nil ? Double(center.x - anchorX) : 0.0
                        },
                        offsetY: resolvedAnchorY.map { Double(center.y - $0) } ?? emoji.offsetY,
                        anchorTime: resolvedAnchorTime,
                        anchorPrice: resolvedAnchorPrice,
                        scale: emoji.scale
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
        showsInfoPanels && shouldShowChecklistPanel
    }

    private var shouldShowChecklistPanel: Bool {
        !placementState.placementChecklistItems.isEmpty
    }

    private var checklistPanel: some View {
        MarkerPlacementChecklistPanel(
            placementState: placementState,
            panelWidth: infoPanelWidth
        )
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

struct MarkerPlacementChecklistPanel: View {
    @ObservedObject var placementState: MarkerPlacementState
    var panelWidth: CGFloat = 188

    var body: some View {
        Group {
            if placementState.isChecklistCollapsed {
                collapsedChecklistStrip
            } else {
                expandedChecklistPanel
            }
        }
        .animation(.easeInOut(duration: 0.2), value: placementState.isChecklistCollapsed)
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
        .frame(width: panelWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.chartPanelBackground.opacity(0.94))
        )
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.chartPanelBackground.opacity(0.94))
        )
        .background(OverlayPanelChrome.background(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: toggleChecklistPanel)
    }

    private var completedChecklistItemCount: Int {
        placementState.placementChecklistItems.filter { $0.isComplete }.count
    }

    private func checklistRow(_ item: MarkerPlacementChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: statusIcon(for: item))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(statusColor(for: item))
                .frame(width: 12)

            Text(item.title)
                .font(.system(size: 9.5, weight: item.isRequired ? .semibold : .regular))
                .foregroundColor(item.isComplete ? AppColors.surfaceWhite93 : AppColors.surfaceWhite82)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusIcon(for item: MarkerPlacementChecklistItem) -> String {
        if item.isComplete {
            return "checkmark.circle.fill"
        }
        return item.isRequired ? "exclamationmark.triangle.fill" : "circle"
    }

    private func statusColor(for item: MarkerPlacementChecklistItem) -> Color {
        if item.isComplete {
            return AppColors.statusPositive95
        }
        return item.isRequired ? AppColors.statusWarning95 : AppColors.surfaceWhite50
    }

    private func toggleChecklistPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            placementState.isChecklistCollapsed.toggle()
        }
    }
}
