//
//  ChartOverlayViews.swift — the standalone overlay views layered over the chart canvas
//
//  Split out of TradingChartView.swift, which was 9,744 lines in one file.
//  Pure file movement: no declaration was reordered, renamed or edited, beyond
//  widening file-scope `private` to internal where a type is now referenced
//  across the split. `private` is file-scoped in Swift, so that widening is
//  forced by the move — it is not a design change.
//

import SwiftUI

struct ChartBottomControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    static let cornerRadius: CGFloat = 8
    /// Must be computed: `static let` captures `AppColors` once and never updates when the user changes theme.
    static var inactiveBackground: Color { AppColors.chartBottomControlInactiveFill }
    static var inactiveBorder: Color { AppColors.chartBottomControlBorder }
    static var activeBackground: Color { AppColors.chartBottomControlActiveBackground }
    static var activeBorder: Color { AppColors.chartBottomControlActiveBorder }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? AppColors.gradientBackgroundDark : color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isActive ? AppColors.gradientBackgroundDark : color)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isActive ?
                Self.activeBackground :
                Self.inactiveBackground
            )
            .cornerRadius(Self.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .stroke(
                        isActive ? Self.activeBorder : Self.inactiveBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChartBottomIconControlButton: View {
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? AppColors.gradientBackgroundDark : color)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isActive ?
                    ChartBottomControlButton.activeBackground :
                    ChartBottomControlButton.inactiveBackground
                )
                .cornerRadius(ChartBottomControlButton.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: ChartBottomControlButton.cornerRadius)
                        .stroke(
                            isActive ?
                            ChartBottomControlButton.activeBorder :
                            ChartBottomControlButton.inactiveBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placement Line Drag Overlay (Interactive line during marker placement)

struct PlacementLineDragOverlay: View {
    let markerIntent: RLMarkerIntent
    let defaultPrice: Double
    @Binding var linePrice: Double?
    @Binding var isDragging: Bool
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let priceScale: CGFloat
    let topExclusionHeight: CGFloat

    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    private let haptic = PlatformImpactGenerator(style: .medium)

    private var effectivePrice: Double { linePrice ?? defaultPrice }
    private var lineY: CGFloat { coordinateSystem.yPosition(forPrice: effectivePrice) }

    private var handleCenterX: CGFloat { chartWidth / 2 }

    private func formatPlacementPrice(_ price: Double) -> String {
        formatMainChartPriceLabel(
            price,
            symbol: chartData.currentSymbol,
            priceRange: chartData.priceRange,
            priceScale: priceScale,
            chartHeight: chartHeight
        )
    }

    var body: some View {
        if lineY.isFinite {
            let labelWidth = ChartAxisMetrics.secondaryPriceChipWidth
            let labelCenterX = ChartAxisMetrics.trailingLabelCenterX(totalWidth: chartWidth, width: labelWidth)
            let lineEndX = ChartAxisMetrics.horizontalLineEndX(totalWidth: chartWidth, labelWidth: labelWidth)
            let labelCenterY = ChartAxisMetrics.clampedPriceChipCenterY(
                centerY: lineY,
                totalHeight: chartHeight,
                chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
                topExclusionHeight: topExclusionHeight
            )
            ZStack {
                // Horizontal dashed line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: lineY))
                    path.addLine(to: CGPoint(x: lineEndX, y: lineY))
                }
                .stroke(markerIntent.color, style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                .allowsHitTesting(false)

                // Drag handle centered
                RoundedRectangle(cornerRadius: 4)
                    .fill(markerIntent.color.opacity(isDragging ? 0.5 : 0.35))
                    .frame(width: 40, height: 20)
                    .overlay(
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(AppColors.surfaceWhite60)
                                    .frame(width: 20, height: 1)
                            }
                        }
                    )
                    .position(x: handleCenterX, y: lineY)
                    .allowsHitTesting(false)

                // Price + type label near Y-axis
                SecondaryPriceChipView(
                    label: markerIntent == .setup ? "Entry" : markerIntent.displayName,
                    priceText: formatPlacementPrice(effectivePrice),
                    color: markerIntent.color
                )
                .position(x: labelCenterX, y: labelCenterY)
                .allowsHitTesting(false)

                // Invisible drag hit area
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: chartWidth, height: 44)
                    .position(x: chartWidth / 2, y: lineY)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStartY = coordinateSystem.yPosition(forPrice: effectivePrice)
                                    dragStartPrice = effectivePrice
                                    haptic.impactOccurred()
                                }
                                let newY = dragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                linePrice = newPrice
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(width: chartWidth, height: chartHeight)
        }
    }
}

// MARK: - Placement Support/Resistance Overlay (TP/SL-style draggables)

struct PlacementSupportResistanceOverlay: View {
    @ObservedObject var placementState: MarkerPlacementState
    @Binding var draggingLineType: RLComponentType?
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let priceScale: CGFloat
    var topExclusionHeight: CGFloat = 0

    @State private var dragStartYByType: [RLComponentType: CGFloat] = [:]
    private let haptic = PlatformImpactGenerator(style: .medium)

    private var supportLevel: LevelPayload? {
        guard case let .levelSupport(payload)? = placementState.component(.levelSupport)?.payload else {
            return nil
        }
        return payload
    }

    private var resistanceLevel: LevelPayload? {
        guard case let .levelResistance(payload)? = placementState.component(.levelResistance)?.payload else {
            return nil
        }
        return payload
    }

    private var supportPrice: Double? {
        supportLevel?.price
    }

    private var resistancePrice: Double? {
        resistanceLevel?.price
    }

    private var hasVisiblePlacementLevels: Bool {
        supportPrice != nil || resistancePrice != nil
    }

    private func formatPlacementPrice(_ price: Double) -> String {
        formatMainChartPriceLabel(
            price,
            symbol: chartData.currentSymbol,
            priceRange: chartData.priceRange,
            priceScale: priceScale,
            chartHeight: chartHeight
        )
    }

    var body: some View {
        if hasVisiblePlacementLevels {
            ZStack {
                if let price = supportPrice {
                    draggableLine(
                        price: price,
                        componentType: .levelSupport,
                        color: RLComponentType.levelSupport.color,
                        label: supportLevel?.label ?? "Support"
                    )
                }

                if let price = resistancePrice {
                    draggableLine(
                        price: price,
                        componentType: .levelResistance,
                        color: RLComponentType.levelResistance.color,
                        label: resistanceLevel?.label ?? "Resistance"
                    )
                }
            }
            .frame(width: chartWidth, height: chartHeight)
        }
    }

    @ViewBuilder
    private func draggableLine(
        price: Double,
        componentType: RLComponentType,
        color: Color,
        label: String
    ) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)
        let isActive = draggingLineType == componentType
        let labelWidth = ChartAxisMetrics.secondaryPriceChipWidth
        let labelCenterX = ChartAxisMetrics.trailingLabelCenterX(totalWidth: chartWidth, width: labelWidth)
        let lineEndX = ChartAxisMetrics.horizontalLineEndX(totalWidth: chartWidth, labelWidth: labelWidth)
        let labelCenterY = ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: y,
            totalHeight: chartHeight,
            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
            topExclusionHeight: topExclusionHeight
        )

        if y.isFinite {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: lineEndX, y: y))
            }
            .stroke(
                color.opacity(0.82),
                style: StrokeStyle(
                    lineWidth: isActive ? 2.5 : 1.5,
                    dash: [6, 3]
                )
            )
            .allowsHitTesting(false)

            SecondaryPriceChipView(
                label: label,
                priceText: formatPlacementPrice(price),
                color: color
            )
            .position(x: labelCenterX, y: labelCenterY)
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isActive ? 0.5 : 0.3))
                .frame(width: 40, height: 20)
                .overlay(
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(AppColors.surfaceWhite60)
                                .frame(width: 20, height: 1)
                        }
                    }
                )
                .position(x: chartWidth / 2, y: y)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .frame(width: chartWidth, height: 44)
                .position(x: chartWidth / 2, y: y)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if draggingLineType != componentType {
                                draggingLineType = componentType
                                dragStartYByType[componentType] = coordinateSystem.yPosition(forPrice: price)
                                haptic.impactOccurred()
                            }

                            let startY = dragStartYByType[componentType] ?? coordinateSystem.yPosition(forPrice: price)
                            let newY = startY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            upsertPlacementLevel(componentType, price: newPrice)
                        }
                        .onEnded { _ in
                            dragStartYByType.removeValue(forKey: componentType)
                            if draggingLineType == componentType {
                                draggingLineType = nil
                            }
                        }
                )
        }
    }

    private func upsertPlacementLevel(_ componentType: RLComponentType, price: Double) {
        switch componentType {
        case .levelSupport:
            let label = supportLevel?.label ?? "Support"
            placementState.upsertComponent(
                .levelSupport,
                payload: .levelSupport(LevelPayload(price: price, label: label))
            )
        case .levelResistance:
            let label = resistanceLevel?.label ?? "Resistance"
            placementState.upsertComponent(
                .levelResistance,
                payload: .levelResistance(LevelPayload(price: price, label: label))
            )
        default:
            break
        }
    }
}

// MARK: - Prediction Placement Overlay (3-line system: Entry + TP + SL)

struct PredictionPlacementOverlay: View {
    @Binding var placement: PredictionPlacementState?
    @Binding var draggingLine: PredictionLineType?
    let coordinateSystem: ChartCoordinateSystem
    let renderWidth: CGFloat
    let plotWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let priceScale: CGFloat
    let topExclusionHeight: CGFloat

    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    private let haptic = PlatformImpactGenerator(style: .medium)

    private var layout: SetupCorePriceLineLayout {
        SetupCorePriceLineLayout(renderWidth: renderWidth, plotWidth: plotWidth)
    }

    private func formatPlacementPrice(_ price: Double) -> String {
        formatMainChartPriceLabel(
            price,
            symbol: chartData.currentSymbol,
            priceRange: chartData.priceRange,
            priceScale: priceScale,
            chartHeight: chartHeight
        )
    }

    var body: some View {
        if let state = placement {
            ZStack {
                // Fill regions between lines
                fillRegions(state: state)

                // Entry line (green, solid, fixed to latest close in setup mode)
                priceLine(
                    price: state.entryPrice,
                    color: .green,
                    label: "Entry",
                    isDashed: false,
                    lineWidth: 2
                )

                // Take Profit line (blue, dashed, draggable)
                priceLine(
                    price: state.takeProfitPrice,
                    color: .blue,
                    label: "TP",
                    isDashed: true,
                    lineWidth: draggingLine == .takeProfit ? 2.5 : 1.5
                )

                // Stop Loss line (red, dashed, draggable)
                priceLine(
                    price: state.stopLossPrice,
                    color: .red,
                    label: "SL",
                    isDashed: true,
                    lineWidth: draggingLine == .stopLoss ? 2.5 : 1.5
                )

                // Drag handle for TP
                dragHandle(
                    price: state.takeProfitPrice,
                    color: .blue,
                    lineType: .takeProfit,
                    state: state
                )

                // Drag handle for SL
                dragHandle(
                    price: state.stopLossPrice,
                    color: .red,
                    lineType: .stopLoss,
                    state: state
                )
            }
            .frame(width: renderWidth, height: chartHeight, alignment: .leading)
        }
    }

    // MARK: - Fill Regions

    @ViewBuilder
    private func fillRegions(state: PredictionPlacementState) -> some View {
        let entryY = coordinateSystem.yPosition(forPrice: state.entryPrice)
        let tpY = coordinateSystem.yPosition(forPrice: state.takeProfitPrice)
        let slY = coordinateSystem.yPosition(forPrice: state.stopLossPrice)

        if entryY.isFinite, tpY.isFinite {
            let tpTop = min(entryY, tpY)
            let tpHeight = abs(entryY - tpY)
            Rectangle()
                .fill(AppColors.statusPositive06)
                .frame(width: layout.fillWidth, height: max(0, tpHeight))
                .position(x: layout.fillWidth / 2, y: tpTop + tpHeight / 2)
                .allowsHitTesting(false)
        }

        if entryY.isFinite, slY.isFinite {
            let slTop = min(entryY, slY)
            let slHeight = abs(entryY - slY)
            Rectangle()
                .fill(AppColors.statusNegative.opacity(0.06))
                .frame(width: layout.fillWidth, height: max(0, slHeight))
                .position(x: layout.fillWidth / 2, y: slTop + slHeight / 2)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Price Line

    @ViewBuilder
    private func priceLine(price: Double, color: Color, label: String, isDashed: Bool, lineWidth: CGFloat) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)

        if y.isFinite {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: layout.lineEndX, y: y))
            }
            .stroke(color.opacity(0.8), style: StrokeStyle(
                lineWidth: lineWidth,
                dash: isDashed ? [6, 3] : []
            ))
            .allowsHitTesting(false)

            SetupCorePriceChipView(
                label: label,
                priceText: formatPlacementPrice(price),
                color: color,
                showsPattern: true
            )
            .position(
                x: layout.labelCenterX,
                y: ChartAxisMetrics.clampedPriceChipCenterY(
                    centerY: y,
                    totalHeight: chartHeight,
                    chipHeight: ChartAxisMetrics.setupCorePriceChipHeight,
                    topExclusionHeight: topExclusionHeight
                )
            )
            .allowsHitTesting(false)
        }
    }

    // MARK: - Drag Handle

    @ViewBuilder
    private func dragHandle(price: Double, color: Color, lineType: PredictionLineType, state: PredictionPlacementState) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)
        let isActive = draggingLine == lineType

        if y.isFinite {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isActive ? 0.5 : 0.3))
                .frame(width: 40, height: 20)
                .overlay(
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(AppColors.surfaceWhite60)
                                .frame(width: 20, height: 1)
                        }
                    }
                )
                .position(x: layout.plotHandleCenterX, y: y)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .frame(width: plotWidth, height: 44)
                .position(x: layout.plotHandleCenterX, y: y)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if draggingLine != lineType {
                                draggingLine = lineType
                                dragStartY = coordinateSystem.yPosition(forPrice: price)
                                dragStartPrice = price
                                haptic.impactOccurred()
                            }
                            let newY = dragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)

                            if var p = placement {
                                let entry = p.entryPrice
                                let wasLong = p.takeProfitPrice > entry

                                switch lineType {
                                case .entry:
                                    break
                                case .takeProfit:
                                    p.takeProfitPrice = newPrice
                                    let nowLong = newPrice > entry
                                    if wasLong != nowLong {
                                        let slOffset = abs(p.stopLossPrice - entry)
                                        p.stopLossPrice = nowLong ? entry - slOffset : entry + slOffset
                                    }
                                case .stopLoss:
                                    p.stopLossPrice = newPrice
                                    let nowLong = p.takeProfitPrice > entry
                                    let slCrossedToTPSide = (newPrice > entry) == nowLong
                                    if slCrossedToTPSide {
                                        let tpOffset = abs(p.takeProfitPrice - entry)
                                        p.takeProfitPrice = newPrice > entry ? entry - tpOffset : entry + tpOffset
                                    }
                                }
                                placement = p
                            }
                        }
                        .onEnded { _ in
                            draggingLine = nil
                        }
                )
        }
    }
}

// MARK: - Draggable Marker Line Overlay (Entry / Exit / TP / SL)

struct DraggableMarkerLineOverlay: View {
    let marker: ChartMarkerUI
    let currentPrice: Double
    let levelType: RLComponentType
    @ObservedObject var markerManager: MarkerManager
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragPrice: Double? = nil
    @State private var isDragging = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0

    private var effectivePrice: Double { dragPrice ?? currentPrice }
    private var lineY: CGFloat { coordinateSystem.yPosition(forPrice: effectivePrice) }

    var body: some View {
        if lineY.isFinite {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: chartWidth, height: chartHeight)
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: chartWidth, height: 44)
                        .position(x: chartWidth / 2, y: lineY)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDragging {
                                        isDragging = true
                                        dragStartY = coordinateSystem.yPosition(forPrice: currentPrice)
                                        dragStartPrice = currentPrice
                                    }
                                    let newY = dragStartY + value.translation.height
                                    let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                    dragPrice = newPrice
                                }
                                .onEnded { value in
                                    let newY = dragStartY + value.translation.height
                                    let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                    Task {
                                        await markerManager.updateMarker(
                                            id: marker.id,
                                            horizontalLinePrice: newPrice,
                                            horizontalLineType: levelType
                                        )
                                    }
                                    dragPrice = nil
                                    isDragging = false
                                }
                        )
                )
        }
    }
}

// MARK: - Draggable Prediction Lines (Entry + TP + SL)

struct DraggablePredictionLinesOverlay: View {
    private enum DragLineKind {
        case entry
        case takeProfit
        case stopLoss
    }

    let marker: ChartMarkerUI
    let entryPrice: Double
    let targetPrice: Double?
    let stopLossPrice: Double?
    @ObservedObject var markerManager: MarkerManager
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragEntryPrice: Double? = nil
    @State private var dragTakeProfitPrice: Double? = nil
    @State private var dragStopLossPrice: Double? = nil
    @State private var entryDragStartY: CGFloat = 0
    @State private var takeProfitDragStartY: CGFloat = 0
    @State private var stopLossDragStartY: CGFloat = 0

    private var effectiveEntryPrice: Double { dragEntryPrice ?? entryPrice }
    private var effectiveTakeProfitPrice: Double? {
        targetPrice.map { dragTakeProfitPrice ?? $0 } ?? dragTakeProfitPrice
    }
    private var effectiveStopLossPrice: Double? {
        stopLossPrice.map { dragStopLossPrice ?? $0 } ?? dragStopLossPrice
    }

    var body: some View {
        ZStack {
            if let target = effectiveTakeProfitPrice {
                draggableStrip(price: target, lineKind: .takeProfit)
            }
            if let stopLoss = effectiveStopLossPrice {
                draggableStrip(price: stopLoss, lineKind: .stopLoss)
            }
            draggableStrip(price: effectiveEntryPrice, lineKind: .entry)
        }
        .frame(width: chartWidth, height: chartHeight)
    }

    @ViewBuilder
    private func draggableStrip(price: Double, lineKind: DragLineKind) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)
        if y.isFinite {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: chartWidth, height: 44)
                .position(x: chartWidth / 2, y: y)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            switch lineKind {
                            case .takeProfit:
                                if dragTakeProfitPrice == nil { takeProfitDragStartY = y }
                                let newY = takeProfitDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                dragTakeProfitPrice = newPrice
                            case .stopLoss:
                                if dragStopLossPrice == nil { stopLossDragStartY = y }
                                let newY = stopLossDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                dragStopLossPrice = newPrice
                            case .entry:
                                if dragEntryPrice == nil { entryDragStartY = y }
                                let newY = entryDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                dragEntryPrice = newPrice
                            }
                        }
                        .onEnded { value in
                            switch lineKind {
                            case .takeProfit:
                                let newY = takeProfitDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                Task { await markerManager.updateMarker(id: marker.id, targetPrice: newPrice) }
                                dragTakeProfitPrice = nil
                            case .stopLoss:
                                let newY = stopLossDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                Task { await markerManager.updateMarker(id: marker.id, stopLossPrice: newPrice) }
                                dragStopLossPrice = nil
                            case .entry:
                                let newY = entryDragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                Task { await markerManager.updateMarker(id: marker.id, horizontalLinePrice: newPrice) }
                                dragEntryPrice = nil
                            }
                        }
                )
        }
    }
}

// MARK: - Marker Price Lines Overlay

struct MarkerPriceLinesOverlay: View {
    let selectedMarker: ChartMarkerUI?
    let previewMarker: PreviewPriceLine?
    let pendingInfo: PendingMarkerInfo?
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let priceScale: CGFloat
    let topExclusionHeight: CGFloat
    var isPredictionPlacementActive: Bool = false

    private func formatPlacementPrice(_ price: Double) -> String {
        formatMainChartPriceLabel(
            price,
            symbol: chartData.currentSymbol,
            priceRange: chartData.priceRange,
            priceScale: priceScale,
            chartHeight: chartHeight
        )
    }

    private func priceChipCenterY(rawY: CGFloat, chipHeight: CGFloat) -> CGFloat {
        ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: rawY,
            totalHeight: chartHeight,
            chipHeight: chipHeight,
            topExclusionHeight: topExclusionHeight
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawSelectedMarkerLine(context: context, size: size)
                drawPreviewMarkerLine(context: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawSelectedMarkerLine(context: GraphicsContext, size: CGSize) {
        guard let marker = selectedMarker else { return }

        // Prediction markers: show Entry (green) + TP (blue) + SL (red) with fill regions
        // Skip when PredictionPlacementOverlay is active to avoid duplicate lines
        if marker.intent == .setup {
            guard !isPredictionPlacementActive else { return }
            drawPredictionMarkerLines(context: context, size: size, marker: marker)
            drawSupplementalSetupLevels(context: context, size: size, marker: marker)
            return
        }

        drawNonSetupLevels(context: context, size: size, marker: marker)
    }

    private func drawNonSetupLevels(context: GraphicsContext, size: CGSize, marker: ChartMarkerUI) {
        for component in marker.levelComponents {
            guard let price = component.payload.levelPrice else { continue }
            let style = levelStyle(for: component.componentTypeEnum)
            drawPriceLine(
                context: context,
                size: size,
                price: price,
                color: style.color,
                isDashed: style.isDashed,
                label: style.label
            )
        }
    }

    private func drawPredictionMarkerLines(context: GraphicsContext, size: CGSize, marker: ChartMarkerUI) {
        let entryPrice = marker.entryPrice ?? marker.price
        let tpPrice = marker.targetPrice
        let slPrice = marker.stopLossPrice
        let layout = setupLayout(renderWidth: size.width)
        let lineEndX = layout.lineEndX

        // Entry line (green, solid)
        let entryY = coordinateSystem.yPosition(forPrice: entryPrice)
        if entryY >= 0 && entryY <= chartHeight {
            let entryPath = Path { p in
                p.move(to: CGPoint(x: 0, y: entryY))
                p.addLine(to: CGPoint(x: lineEndX, y: entryY))
            }
            context.stroke(entryPath, with: .color(AppColors.statusPositive60), style: StrokeStyle(lineWidth: 2))
            drawPriceLabel(context: context, y: entryY, price: entryPrice, color: .green, label: "Entry", layout: layout)
        }

        // TP line (blue, dashed) + green fill region
        if let tp = tpPrice {
            let tpY = coordinateSystem.yPosition(forPrice: tp)

            // Green fill between entry and TP
            let fillTop = min(entryY, tpY)
            let fillHeight = abs(entryY - tpY)
            if fillHeight > 0 {
                let fillRect = CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)
                context.fill(Path(fillRect), with: .color(AppColors.statusPositive06))
            }

            if tpY >= 0 && tpY <= chartHeight {
                let tpPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: tpY))
                    p.addLine(to: CGPoint(x: lineEndX, y: tpY))
                }
                context.stroke(tpPath, with: .color(AppColors.statusInfo60), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                drawPriceLabel(context: context, y: tpY, price: tp, color: .blue, label: "TP", layout: layout)
            }
        }

        // SL line (red, dashed) + red fill region
        if let sl = slPrice {
            let slY = coordinateSystem.yPosition(forPrice: sl)

            // Red fill between entry and SL
            let fillTop = min(entryY, slY)
            let fillHeight = abs(entryY - slY)
            if fillHeight > 0 {
                let fillRect = CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)
                context.fill(Path(fillRect), with: .color(AppColors.statusNegative.opacity(0.06)))
            }

            if slY >= 0 && slY <= chartHeight {
                let slPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: slY))
                    p.addLine(to: CGPoint(x: lineEndX, y: slY))
                }
                context.stroke(slPath, with: .color(AppColors.statusNegative60), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                drawPriceLabel(context: context, y: slY, price: sl, color: .red, label: "SL", layout: layout)
            }
        }
    }

    private func drawSupplementalSetupLevels(context: GraphicsContext, size: CGSize, marker: ChartMarkerUI) {
        for component in marker.levelComponents {
            guard
                let type = component.componentTypeEnum,
                type != .levelEntry,
                type != .levelSl,
                type != .levelTp,
                let price = component.payload.levelPrice
            else {
                continue
            }

            let style = levelStyle(for: type)
            drawPriceLine(
                context: context,
                size: size,
                price: price,
                color: style.color,
                isDashed: style.isDashed,
                label: style.label
            )
        }
    }

    private func levelStyle(for type: RLComponentType?) -> (color: Color, label: String?, isDashed: Bool) {
        switch type {
        case .levelEntry:
            return (.green, "Entry", false)
        case .levelTp:
            return (.blue, "TP", true)
        case .levelSl:
            return (.red, "SL", true)
        case .levelSupport:
            return (RLComponentType.levelSupport.color, "Sup", true)
        case .levelResistance:
            return (RLComponentType.levelResistance.color, "Res", true)
        default:
            return (AppColors.surfaceWhite75, nil, true)
        }
    }

    private func drawPriceLabel(
        context: GraphicsContext,
        y: CGFloat,
        price: Double,
        color: Color,
        label: String,
        layout: SetupCorePriceLineLayout
    ) {
        let priceText = formatPlacementPrice(price)
        let displayY = priceChipCenterY(rawY: y, chipHeight: ChartAxisMetrics.setupCorePriceChipHeight)
        let labelRect = layout.labelRect(centerY: displayY)
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
        context.fill(roundedPath, with: .color(color))
        if isSetupCorePriceLabel(label) {
            drawSetupPriceLabelPattern(
                context: context,
                labelRect: labelRect,
                cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius
            )
        }
        var labelContext = context
        labelContext.clip(to: roundedPath)
        labelContext.draw(
            setupCorePriceLabelText(label: label, priceText: priceText),
            at: CGPoint(x: labelRect.midX, y: displayY)
        )
    }
    
    private func drawPreviewMarkerLine(context: GraphicsContext, size: CGSize) {
        guard let preview = previewMarker else { return }

        // Prediction: draw full 3-line system using pending info
        if preview.intent == .setup,
           let pending = pendingInfo,
           pending.markerIntent == .setup {
            let entryPrice = pending.horizontalLinePrice ?? pending.price
            let layout = setupLayout(renderWidth: size.width)
            let lineEndX = layout.lineEndX

            // Entry line (green)
            let entryY = coordinateSystem.yPosition(forPrice: entryPrice)
            if entryY >= 0 && entryY <= chartHeight {
                let entryPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: entryY))
                    p.addLine(to: CGPoint(x: lineEndX, y: entryY))
                }
                context.stroke(entryPath, with: .color(AppColors.statusPositive60), style: StrokeStyle(lineWidth: 2))
                drawPriceLabel(context: context, y: entryY, price: entryPrice, color: .green, label: "Entry", layout: layout)
            }

            // TP line (blue)
            if let tp = pending.targetPrice {
                let tpY = coordinateSystem.yPosition(forPrice: tp)
                let fillTop = min(entryY, tpY)
                let fillHeight = abs(entryY - tpY)
                if fillHeight > 0 {
                    context.fill(Path(CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)), with: .color(AppColors.statusPositive06))
                }
                if tpY >= 0 && tpY <= chartHeight {
                    let tpPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: tpY))
                        p.addLine(to: CGPoint(x: lineEndX, y: tpY))
                    }
                    context.stroke(tpPath, with: .color(AppColors.statusInfo60), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    drawPriceLabel(context: context, y: tpY, price: tp, color: .blue, label: "TP", layout: layout)
                }
            }

            // SL line (red)
            if let sl = pending.stopLossPrice {
                let slY = coordinateSystem.yPosition(forPrice: sl)
                let fillTop = min(entryY, slY)
                let fillHeight = abs(entryY - slY)
                if fillHeight > 0 {
                    context.fill(Path(CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)), with: .color(AppColors.statusNegative.opacity(0.06)))
                }
                if slY >= 0 && slY <= chartHeight {
                    let slPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: slY))
                        p.addLine(to: CGPoint(x: lineEndX, y: slY))
                    }
                    context.stroke(slPath, with: .color(AppColors.statusNegative60), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    drawPriceLabel(context: context, y: slY, price: sl, color: .red, label: "SL", layout: layout)
                }
            }
            return
        }

        // Non-prediction: single static line
        let linePrice: Double
        if let pending = pendingInfo, let draggedPrice = pending.horizontalLinePrice {
            linePrice = draggedPrice
        } else if let explicitPrice = preview.explicitPrice {
            linePrice = explicitPrice
        } else {
            linePrice = preview.candle.close
        }

        drawPriceLine(
            context: context,
            size: size,
            price: linePrice,
            color: preview.color,
            isDashed: true,
            label: preview.label
        )
    }
    
    private func drawPriceLine(
        context: GraphicsContext,
        size: CGSize,
        price: Double,
        color: Color,
        isDashed: Bool,
        label: String? = nil
    ) {
        let y = coordinateSystem.yPosition(forPrice: price)
        
        guard y >= 0 && y <= chartHeight else { return }
        
        let labelWidth = label != nil
            ? ChartAxisMetrics.secondaryPriceChipWidth
            : ChartAxisMetrics.currentPriceChipWidth
        let chipHeight = label != nil
            ? ChartAxisMetrics.secondaryPriceChipHeight
            : ChartAxisMetrics.currentPriceChipHeight
        let displayY = priceChipCenterY(rawY: y, chipHeight: chipHeight)
        let labelRect = ChartAxisMetrics.labelRect(
            totalWidth: size.width,
            centerY: displayY,
            width: labelWidth,
            height: chipHeight
        )
        let lineEndX = labelRect.maxX

        let linePath = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))
        }
        
        let strokeStyle = isDashed ?
            StrokeStyle(lineWidth: 1.5, dash: [6, 4]) :
            StrokeStyle(lineWidth: 2)
        
        context.stroke(linePath, with: .color(color.opacity(0.6)), style: strokeStyle)
        
        let priceText = formatPlacementPrice(price)
        
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
        context.fill(roundedPath, with: .color(color))
        if isSetupCorePriceLabel(label) {
            drawSetupPriceLabelPattern(
                context: context,
                labelRect: labelRect,
                cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius
            )
        }

        var labelContext = context
        labelContext.clip(to: roundedPath)
        if let label {
            labelContext.draw(
                secondaryPriceChipText(label: label, priceText: priceText),
                at: CGPoint(x: labelRect.midX, y: displayY)
            )
        } else {
            labelContext.draw(
                Text(priceText)
                    .font(.system(size: ChartAxisMetrics.horizontalPriceFontSize, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.onAccentForeground),
                at: CGPoint(x: labelRect.midX, y: displayY)
            )
        }
    }

    private func setupLayout(renderWidth: CGFloat) -> SetupCorePriceLineLayout {
        SetupCorePriceLineLayout(renderWidth: renderWidth)
    }

    private func isSetupCorePriceLabel(_ label: String?) -> Bool {
        guard let label else { return false }
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized == "ENTRY" || normalized == "TP" || normalized == "SL"
    }

    private func drawSetupPriceLabelPattern(
        context: GraphicsContext,
        labelRect: CGRect,
        cornerRadius: CGFloat
    ) {
        var patternContext = context
        let clipPath = Path(roundedRect: labelRect, cornerRadius: cornerRadius)
        patternContext.clip(to: clipPath)

        var stripes = Path()
        let spacing: CGFloat = 5
        var startX = labelRect.minX - labelRect.height
        while startX <= labelRect.maxX + labelRect.height {
            stripes.move(to: CGPoint(x: startX, y: labelRect.maxY))
            stripes.addLine(to: CGPoint(x: startX + labelRect.height, y: labelRect.minY))
            startX += spacing
        }

        patternContext.stroke(
            stripes,
            with: .color(.white.opacity(0.14)),
            lineWidth: 0.7
        )
    }
}

// MARK: - Marker Drawing Overlay

struct MarkerDrawingOverlay: View {
    let selectedMarker: ChartMarkerUI?
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                drawSelectedMarkerDrawings(context: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawSelectedMarkerDrawings(context: GraphicsContext, size: CGSize) {
        guard let marker = selectedMarker else { return }

        for component in marker.drawingComponents {
            switch component.payload {
            case .drawingHorizontalLine(let payload):
                drawHorizontalLine(context: context, payload: payload)
            case .drawingTrendline(let payload):
                drawTrendline(context: context, payload: payload)
            case .drawingZone(let payload):
                drawZone(context: context, payload: payload, marker: marker)
            case .drawingPattern(let payload):
                drawPattern(context: context, payload: payload)
            default:
                continue
            }
        }
    }

    private func drawTrendline(context: GraphicsContext, payload: TrendlinePayload) {
        guard
            let startX = xPosition(for: payload.startTime),
            let endX = xPosition(for: payload.endTime)
        else {
            return
        }

        let startY = coordinateSystem.yPosition(forPrice: payload.startPrice)
        let endY = coordinateSystem.yPosition(forPrice: payload.endPrice)

        guard
            startY.isFinite, endY.isFinite,
            startY >= -30, startY <= chartHeight + 30,
            endY >= -30, endY <= chartHeight + 30
        else {
            return
        }

        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        let trendlineColor = Color(hex: payload.colorHex ?? "") ?? RLComponentType.drawingTrendline.color

        context.stroke(
            path,
            with: .color(trendlineColor.opacity(0.68)),
            style: StrokeStyle(
                lineWidth: CGFloat(payload.lineWidth ?? 2.0),
                dash: (payload.lineStyle ?? .dashed).dashPattern
            )
        )
    }

    private func drawHorizontalLine(context: GraphicsContext, payload: HorizontalLinePayload) {
        let y = coordinateSystem.yPosition(forPrice: payload.price)
        guard y.isFinite, y >= -30, y <= chartHeight + 30 else {
            return
        }

        let startX: CGFloat = 0
        let endX = ChartAxisMetrics.horizontalLineEndX(
            totalWidth: chartWidth,
            labelWidth: ChartAxisMetrics.secondaryPriceChipWidth
        )

        var path = Path()
        path.move(to: CGPoint(x: startX, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))

        let lineColor = Color(hex: payload.colorHex ?? "") ?? RLComponentType.drawingHorizontalLine.color
        let lineStyle = payload.lineStyle ?? .dashed
        let lineWidth = resolvedIndicatorLineWidth(
            for: lineStyle,
            preferredWidth: CGFloat(payload.lineWidth ?? defaultIndicatorLineWidth(for: lineStyle))
        )
        context.stroke(
            path,
            with: .color(lineColor.opacity(0.8)),
            style: StrokeStyle(
                lineWidth: lineWidth,
                dash: lineStyle.dashPattern
            )
        )
    }

    private func drawZone(context: GraphicsContext, payload: ZonePayload, marker: ChartMarkerUI) {
        let candlesCount = coordinateSystem.chartData.candles.count
        guard candlesCount > 0 else { return }

        let fallbackStartIndex = max(0, min(candlesCount - 1, marker.candleIndex - 8))
        let fallbackEndIndex = max(0, min(candlesCount - 1, marker.candleIndex + 8))

        let startX = payload.startTime.flatMap(xPosition(for:))
            ?? coordinateSystem.xCenterPosition(forCandleIndex: fallbackStartIndex)
        let endX = payload.endTime.flatMap(xPosition(for:))
            ?? coordinateSystem.xCenterPosition(forCandleIndex: fallbackEndIndex)

        let topY = coordinateSystem.yPosition(forPrice: payload.topPrice)
        let bottomY = coordinateSystem.yPosition(forPrice: payload.bottomPrice)

        guard
            topY.isFinite, bottomY.isFinite,
            topY >= -40, topY <= chartHeight + 40,
            bottomY >= -40, bottomY <= chartHeight + 40
        else {
            return
        }

        let rect = CGRect(
            x: min(startX, endX),
            y: min(topY, bottomY),
            width: max(2, abs(endX - startX)),
            height: max(2, abs(bottomY - topY))
        )
        let zoneColor = Color(hex: payload.colorHex ?? "") ?? RLComponentType.drawingZone.color

        context.fill(
            Path(rect),
            with: .color(zoneColor.opacity(0.16))
        )
        context.stroke(
            Path(rect),
            with: .color(zoneColor.opacity(0.55)),
            style: StrokeStyle(
                lineWidth: CGFloat(payload.lineWidth ?? 1.4),
                dash: (payload.lineStyle ?? .dashed).dashPattern
            )
        )
    }

    private func drawPattern(context: GraphicsContext, payload: ChartPatternPayload) {
        let points = payload.points.compactMap { point -> CGPoint? in
            guard let x = xPosition(for: point.time) else { return nil }
            let y = coordinateSystem.yPosition(forPrice: point.price)
            guard y.isFinite else { return nil }
            return CGPoint(x: x, y: y)
        }
        guard points.count >= 2 else { return }
        let patternColor = Color(hex: payload.colorHex ?? "") ?? RLComponentType.drawingPattern.color
        let style = StrokeStyle(
            lineWidth: CGFloat(payload.lineWidth ?? 2.0),
            dash: (payload.lineStyle ?? .dashed).dashPattern
        )

        for segment in patternSegments(for: payload.patternKey, points: points) {
            var path = Path()
            path.move(to: segment.start)
            path.addLine(to: segment.end)
            context.stroke(path, with: .color(patternColor.opacity(0.68)), style: style)
        }
    }

    private func patternSegments(
        for patternKey: String,
        points: [CGPoint]
    ) -> [(start: CGPoint, end: CGPoint)] {
        guard points.count >= 2 else { return [] }
        if patternKey == ChartPatternDrawingTemplate.risingChannel.rawValue, points.count >= 3 {
            let lowerStart = points[0]
            let lowerEnd = points[1]
            let upperStart = points[2]
            let delta = CGPoint(x: lowerEnd.x - lowerStart.x, y: lowerEnd.y - lowerStart.y)
            let upperEnd = CGPoint(x: upperStart.x + delta.x, y: upperStart.y + delta.y)
            return [(lowerStart, lowerEnd), (upperStart, upperEnd)]
        }
        if patternKey == ChartPatternDrawingTemplate.headAndShoulders.rawValue, points.count >= 4 {
            let necklineStart = CGPoint(x: points[0].x, y: points[3].y)
            let necklineEnd = CGPoint(x: points[2].x, y: points[3].y)
            return [(points[0], points[1]), (points[1], points[2]), (necklineStart, necklineEnd)]
        }
        return (1..<points.count).map { index in
            (start: points[index - 1], end: points[index])
        }
    }

    private func xPosition(for timestamp: Date) -> CGFloat? {
        guard let index = coordinateSystem.candleIndex(forTimestamp: timestamp) else { return nil }
        return coordinateSystem.xCenterPosition(forCandleIndex: index)
    }

    private func defaultIndicatorLineWidth(for lineStyle: MarkerDrawingLineStyle) -> Double {
        lineStyle == .solid ? 2.0 : 1.5
    }

    private func resolvedIndicatorLineWidth(
        for lineStyle: MarkerDrawingLineStyle,
        preferredWidth: CGFloat
    ) -> CGFloat {
        if lineStyle == .solid {
            return max(preferredWidth, 2.0)
        }
        return max(preferredWidth, 1.5)
    }
}

// MARK: - Prediction Target Line Overlay

struct PredictionTargetLineOverlay: View {
    let entryPrice: Double
    @Binding var targetPrice: Double?
    @Binding var isDragging: Bool
    let isInteractive: Bool
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let topExclusionHeight: CGFloat
    let formatPrice: (Double) -> String
    
    // FIXED: Store initial Y position when drag starts to prevent feedback loop
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    
    var body: some View {
        ZStack {
            targetLineCanvas
            
            if isInteractive, let currentTargetPrice = targetPrice {
                draggableArea(currentTargetPrice: currentTargetPrice)
            }
        }
    }
    
    @ViewBuilder
    private var targetLineCanvas: some View {
        Canvas { context, size in
            guard let targetPrice = targetPrice else { return }
            
            let y = coordinateSystem.yPosition(forPrice: targetPrice)
            guard y >= 0 && y <= chartHeight else { return }
            
            drawTargetLine(context: context, size: size, y: y)
            drawTargetLabel(context: context, size: size, y: y)
            
            if isInteractive {
                drawDragHandle(context: context, y: y)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawTargetLine(context: GraphicsContext, size: CGSize, y: CGFloat) {
        let labelWidth = ChartAxisMetrics.secondaryPriceChipWidth
        let lineEndX = ChartAxisMetrics.horizontalLineEndX(totalWidth: size.width, labelWidth: labelWidth)
        let linePath = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))
        }
        
        let lineWidth: CGFloat = isDragging ? 3 : 2
        context.stroke(linePath, with: .color(AppColors.statusWarning80), style: StrokeStyle(lineWidth: lineWidth))
    }
    
    private func drawTargetLabel(context: GraphicsContext, size: CGSize, y: CGFloat) {
        guard let targetPrice = targetPrice else { return }
        
        let priceText = formatPrice(targetPrice)
        let displayY = ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: y,
            totalHeight: chartHeight,
            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
            topExclusionHeight: topExclusionHeight
        )
        let labelRect = ChartAxisMetrics.labelRect(
            totalWidth: size.width,
            centerY: displayY,
            width: ChartAxisMetrics.secondaryPriceChipWidth,
            height: ChartAxisMetrics.secondaryPriceChipHeight
        )

        let roundedPath = Path(roundedRect: labelRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
        context.fill(roundedPath, with: .color(AppColors.statusWarning))

        var labelContext = context
        labelContext.clip(to: roundedPath)
        labelContext.draw(
            secondaryPriceChipText(label: "Target", priceText: priceText),
            at: CGPoint(x: labelRect.midX, y: displayY)
        )
    }
    
    private func drawDragHandle(context: GraphicsContext, y: CGFloat) {
        let handleSize: CGFloat = 40
        let handleRect = CGRect(
            x: 10,
            y: y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        
        let handlePath = Path(roundedRect: handleRect, cornerRadius: 8)
        context.fill(handlePath, with: .color(AppColors.statusWarning.opacity(isDragging ? 0.3 : 0.2)))
        
        let arrowsImage = Image(systemName: "arrow.up.arrow.down")
        context.draw(arrowsImage, in: handleRect)
    }
    
    @ViewBuilder
    private func draggableArea(currentTargetPrice: Double) -> some View {
        // FIXED: Capture initial position on drag start to prevent feedback loop
        GeometryReader { geo in
            let currentY = coordinateSystem.yPosition(forPrice: currentTargetPrice)

            if currentY.isFinite {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width, height: 60)
                    .position(x: geo.size.width / 2, y: currentY)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    // FIXED: Capture starting position on first touch
                                    isDragging = true
                                    dragStartY = currentY
                                    dragStartPrice = currentTargetPrice
                                }

                                // FIXED: Calculate new Y based on drag translation from START position
                                // This prevents the feedback loop where changing price changes Y
                                let newY = dragStartY + value.translation.height

                                // Convert to price (unclamped so lines can go beyond visible range)
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                self.targetPrice = newPrice
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
    }
}

// MARK: - Static Target Line

struct StaticTargetLineOverlay: View {
    let entryPrice: Double
    let targetPrice: Double
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    let topExclusionHeight: CGFloat
    let formatPrice: (Double) -> String
    
    var body: some View {
        Canvas { context, size in
            let y = coordinateSystem.yPosition(forPrice: targetPrice)
            guard y >= 0 && y <= chartHeight else { return }
            
            let labelWidth = ChartAxisMetrics.secondaryPriceChipWidth
            let lineEndX = ChartAxisMetrics.horizontalLineEndX(totalWidth: size.width, labelWidth: labelWidth)
            
            let linePath = Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: lineEndX, y: y))
            }
            
            context.stroke(linePath, with: .color(AppColors.statusWarning80), style: StrokeStyle(lineWidth: 2))
            
            let displayY = ChartAxisMetrics.clampedPriceChipCenterY(
                centerY: y,
                totalHeight: chartHeight,
                chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
                topExclusionHeight: topExclusionHeight
            )
            let labelRect = ChartAxisMetrics.labelRect(
                totalWidth: size.width,
                centerY: displayY,
                width: labelWidth,
                height: ChartAxisMetrics.secondaryPriceChipHeight
            )

            let roundedPath = Path(roundedRect: labelRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
            context.fill(roundedPath, with: .color(AppColors.statusWarning))

            var labelContext = context
            labelContext.clip(to: roundedPath)
            labelContext.draw(
                secondaryPriceChipText(label: "Target", priceText: formatPrice(targetPrice)),
                at: CGPoint(x: labelRect.midX, y: displayY)
            )
        }
        .allowsHitTesting(false)
    }
}

struct DrawingTextEditorSheet: View {
    let context: DrawingTextEditorContext
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String

    init(context: DrawingTextEditorContext, onSave: @escaping (String) -> Void) {
        self.context = context
        self.onSave = onSave
        _value = State(initialValue: context.initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(context.title) {
                    if context.kind == .note {
                        TextEditor(text: $value)
                            .frame(minHeight: 120)
                    } else {
                        TextField(context.placeholder, text: $value)
                            .platformAutocapitalization(.never)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.systemBlack)
            .navigationTitle(context.title)
            .platformNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(value)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(context.kind == .note ? 280 : 180)])
    }
}

