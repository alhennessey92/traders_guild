import SwiftUI

/// Renders a marker's components as read-only overlays when a marker is selected.
struct MarkerComponentOverlayLayer: View {
    let components: [RLMarkerComponentDTO]
    let yForPrice: (Double) -> CGFloat?
    let width: CGFloat
    let xForTime: ((Date) -> CGFloat?)?
    var formatPrice: ((Double) -> String)?
    var chartHeight: CGFloat = 0
    var topExclusionHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawLevels(context: context)
                drawHorizontalLines(context: context)
                drawTrendlines(context: context)
                drawZones(context: context)
                drawPatterns(context: context)
            }
            .allowsHitTesting(false)
        }
    }

    /// Level components to render, excluding Entry/TP/SL for setup markers
    /// (those are rendered by MarkerPriceLinesOverlay with fill regions and custom styling).
    private var levelComponents: [RLMarkerComponentDTO] {
        let isSetupMarker = components.contains { $0.componentTypeEnum == .levelEntry }
        return components.filter { component in
            guard component.componentTypeEnum?.isLevel ?? false else { return false }
            if isSetupMarker {
                let type = component.componentTypeEnum
                if type == .levelEntry || type == .levelTp || type == .levelSl {
                    return false
                }
            }
            return true
        }
    }

    private var horizontalLineComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingHorizontalLine }
    }

    private var trendlineComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingTrendline }
    }

    private var zoneComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingZone }
    }

    private var patternComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingPattern }
    }

    private var labeledComponents: [RLMarkerComponentDTO] {
        components.filter { component in
            switch component.payload {
            case .levelSupport, .levelResistance, .drawingHorizontalLine:
                return true
            default:
                return false
            }
        }
    }

    private func drawLevels(context: GraphicsContext) {
        let lineEndX = ChartAxisMetrics.horizontalLineEndX(
            totalWidth: width,
            labelWidth: ChartAxisMetrics.secondaryPriceChipWidth
        )
        for component in levelComponents {
            guard let price = component.payload.levelPrice,
                  let y = yForPrice(price),
                  y.isFinite else {
                continue
            }

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))

            context.stroke(
                path,
                with: .color(componentColor(component).opacity(0.8)),
                style: drawingStrokeStyle(
                    lineStyle: component.payload.drawingLineStyle ?? .dashed,
                    lineWidth: resolvedIndicatorLineWidth(
                        for: component.payload.drawingLineStyle ?? .dashed,
                        preferredWidth: CGFloat(
                            component.payload.drawingLineWidth
                            ?? defaultIndicatorLineWidth(for: component.payload.drawingLineStyle ?? .dashed)
                        )
                    )
                )
            )
        }
    }

    private func drawHorizontalLines(context: GraphicsContext) {
        let endX = ChartAxisMetrics.horizontalLineEndX(
            totalWidth: width,
            labelWidth: ChartAxisMetrics.secondaryPriceChipWidth
        )
        for component in horizontalLineComponents {
            guard case let .drawingHorizontalLine(payload) = component.payload,
                  let y = yForPrice(payload.price),
                  y.isFinite else {
                continue
            }

            let startX: CGFloat = 0
            var path = Path()
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
            let lineStyle = payload.lineStyle ?? .dashed
            let lineWidth = resolvedIndicatorLineWidth(
                for: lineStyle,
                preferredWidth: CGFloat(payload.lineWidth ?? defaultIndicatorLineWidth(for: lineStyle))
            )

            context.stroke(
                path,
                with: .color(componentColor(component).opacity(0.8)),
                style: drawingStrokeStyle(
                    lineStyle: lineStyle,
                    lineWidth: lineWidth
                )
            )
        }
    }

    private func drawTrendlines(context: GraphicsContext) {
        for component in trendlineComponents {
            guard case let .drawingTrendline(payload) = component.payload,
                  let startY = yForPrice(payload.startPrice),
                  let endY = yForPrice(payload.endPrice),
                  startY.isFinite,
                  endY.isFinite else {
                continue
            }

            let startX = xForTime?(payload.startTime) ?? width * 0.2
            let endX = xForTime?(payload.endTime) ?? width * 0.8
            guard startX.isFinite, endX.isFinite else { continue }

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            context.stroke(
                path,
                with: .color(componentColor(component).opacity(0.72)),
                style: drawingStrokeStyle(
                    lineStyle: payload.lineStyle ?? .dashed,
                    lineWidth: CGFloat(payload.lineWidth ?? 1.8)
                )
            )
        }
    }

    private func drawZones(context: GraphicsContext) {
        for component in zoneComponents {
            guard case let .drawingZone(payload) = component.payload,
                  let topY = yForPrice(payload.topPrice),
                  let bottomY = yForPrice(payload.bottomPrice),
                  topY.isFinite,
                  bottomY.isFinite else {
                continue
            }

            let startX = (payload.startTime.flatMap { xForTime?($0) }) ?? width * 0.2
            let endX = (payload.endTime.flatMap { xForTime?($0) }) ?? width * 0.8
            guard startX.isFinite, endX.isFinite else { continue }
            let rect = CGRect(
                x: min(startX, endX),
                y: min(topY, bottomY),
                width: abs(endX - startX),
                height: max(2, abs(bottomY - topY))
            )
            let color = componentColor(component)

            context.fill(Path(rect), with: .color(color.opacity(0.15)))
            context.stroke(
                Path(rect),
                with: .color(color.opacity(0.55)),
                style: drawingStrokeStyle(
                    lineStyle: payload.lineStyle ?? .dashed,
                    lineWidth: CGFloat(payload.lineWidth ?? 1.2)
                )
            )
        }
    }

    private func drawPatterns(context: GraphicsContext) {
        for component in patternComponents {
            guard case let .drawingPattern(payload) = component.payload else { continue }
            let points = payload.points.compactMap { point -> CGPoint? in
                guard let y = yForPrice(point.price), y.isFinite else { return nil }
                let x = xForTime?(point.time) ?? width * 0.5
                guard x.isFinite else { return nil }
                return CGPoint(x: x, y: y)
            }
            guard points.count >= 2 else { continue }

            let color = componentColor(component)
            let style = drawingStrokeStyle(
                lineStyle: payload.lineStyle ?? .dashed,
                lineWidth: CGFloat(payload.lineWidth ?? 2.0)
            )
            for segment in patternSegments(for: payload.patternKey, points: points) {
                var path = Path()
                path.move(to: segment.start)
                path.addLine(to: segment.end)
                context.stroke(path, with: .color(color.opacity(0.72)), style: style)
            }
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

    private func drawingStrokeStyle(
        lineStyle: MarkerDrawingLineStyle,
        lineWidth: CGFloat
    ) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, dash: lineStyle.dashPattern)
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

    private func componentColor(_ component: RLMarkerComponentDTO) -> Color {
        if let hex = component.payload.drawingColorHex,
           let resolved = Color(hex: hex) {
            return resolved
        }
        return component.componentTypeEnum?.color ?? AppColors.surfaceWhite70
    }

    private func labelInfo(for component: RLMarkerComponentDTO) -> (text: String, price: Double)? {
        switch component.payload {
        case .levelSupport(let payload):
            return (resolvedLabel(payload.label, fallback: "Support"), payload.price)
        case .levelResistance(let payload):
            return (resolvedLabel(payload.label, fallback: "Resistance"), payload.price)
        case .drawingHorizontalLine(let payload):
            return (resolvedLabel(payload.label, fallback: "Line"), payload.price)
        default:
            return nil
        }
    }

    private func resolvedLabel(_ raw: String?, fallback: String) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func priceLabelView(label: String, price: Double, color: Color, y: CGFloat) -> some View {
        let displayY = chartHeight > 0
            ? ChartAxisMetrics.clampedPriceChipCenterY(
                centerY: y,
                totalHeight: chartHeight,
                chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
                topExclusionHeight: topExclusionHeight
            )
            : y
        return HStack(spacing: 3) {
            Text(label)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .font(.system(size: ChartAxisMetrics.secondaryLabelFontSize, weight: .bold, design: .monospaced))
            Text(formattedPrice(price))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .font(.system(size: ChartAxisMetrics.secondaryPriceFontSize, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(AppColors.onAccentForeground)
        .padding(.horizontal, ChartAxisMetrics.secondaryPriceChipHorizontalPadding)
        .padding(.vertical, ChartAxisMetrics.secondaryPriceChipVerticalPadding)
        .frame(width: ChartAxisMetrics.secondaryPriceChipWidth, height: ChartAxisMetrics.secondaryPriceChipHeight)
        .background(color.opacity(0.88))
        .cornerRadius(ChartAxisMetrics.horizontalPriceChipCornerRadius)
        .position(
            x: ChartAxisMetrics.trailingLabelCenterX(
                totalWidth: width,
                width: ChartAxisMetrics.secondaryPriceChipWidth
            ),
            y: displayY
        )
        .allowsHitTesting(false)
    }

    private func formattedPrice(_ price: Double) -> String {
        if let formatPrice {
            return formatPrice(price)
        }
        return String(format: "%.4f", price)
    }
}
