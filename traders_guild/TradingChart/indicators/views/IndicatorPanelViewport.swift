import SwiftUI
import UIKit

enum ChartPanelResizeHandleStyle {
    case indicator
    case timeframe
}

struct IndicatorPanelViewport {
    let rawValueRange: (min: Double, max: Double)
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let visualHeight: CGFloat
    let priceScale: CGFloat
    let verticalPanOffset: CGFloat

    var drawableHeight: CGFloat {
        max(1, visualHeight - topPadding - bottomPadding)
    }

    var contentBottomY: CGFloat {
        visualHeight - bottomPadding
    }

    var visualCenterY: CGFloat {
        topPadding + drawableHeight / 2
    }

    var transformedTopValue: Double {
        value(atY: topPadding)
    }

    var transformedMidValue: Double {
        value(atY: visualCenterY)
    }

    var transformedBottomValue: Double {
        value(atY: contentBottomY)
    }

    func yPosition(for value: Double) -> CGFloat {
        let range = rawValueRange.max - rawValueRange.min
        guard range > 0 else { return visualCenterY }

        let normalized = (value - rawValueRange.min) / range
        let basisY = topPadding + drawableHeight * (1.0 - CGFloat(normalized))
        return visualCenterY + (basisY - visualCenterY) * priceScale + verticalPanOffset
    }

    func value(atY y: CGFloat) -> Double {
        let range = rawValueRange.max - rawValueRange.min
        guard range > 0, priceScale > 0 else { return rawValueRange.min }

        let unscaledY = ((y - verticalPanOffset - visualCenterY) / priceScale) + visualCenterY
        let normalized = 1.0 - ((unscaledY - topPadding) / drawableHeight)
        return rawValueRange.min + Double(normalized) * range
    }

    func dynamicLevels(
        maxVisibleLabels: Int = 5,
        targetIntervals: Double = 4,
        emphasis: [Double] = []
    ) -> [Double] {
        let visibleMin = min(transformedTopValue, transformedBottomValue)
        let visibleMax = max(transformedTopValue, transformedBottomValue)
        let visibleRange = visibleMax - visibleMin
        let step = sparseNiceStep(for: visibleRange, targetIntervals: targetIntervals)
        guard step.isFinite, step > 0 else { return [] }

        let startValue = floor(visibleMin / step) * step
        let endValue = ceil(visibleMax / step) * step
        guard startValue.isFinite, endValue.isFinite, startValue <= endValue else { return [] }

        var levels: [Double] = []
        var currentValue = startValue
        var count = 0
        while currentValue <= endValue && count < 48 {
            appendLevel(currentValue, to: &levels, tolerance: step * 0.15)
            currentValue += step
            count += 1
        }

        for value in emphasis where value >= visibleMin - step * 0.1 && value <= visibleMax + step * 0.1 {
            appendLevel(value, to: &levels, tolerance: step * 0.15)
        }

        let sortedLevels = levels.sorted(by: >)
        guard sortedLevels.count > maxVisibleLabels else { return sortedLevels }

        let stride = Int(ceil(Double(sortedLevels.count) / Double(maxVisibleLabels)))
        return sortedLevels.enumerated().compactMap { index, value in
            index.isMultiple(of: stride) ? value : nil
        }
    }

    private func appendLevel(_ value: Double, to levels: inout [Double], tolerance: Double) {
        guard !levels.contains(where: { abs($0 - value) <= tolerance }) else { return }
        levels.append(value)
    }

    private func sparseNiceStep(for visibleRange: Double, targetIntervals: Double) -> Double {
        guard visibleRange.isFinite, visibleRange > 0, targetIntervals > 0 else { return 1 }

        let roughStep = visibleRange / targetIntervals
        let magnitude = pow(10.0, floor(log10(roughStep)))
        let normalized = roughStep / magnitude

        let niceNormalized: Double
        if normalized <= 1.0 {
            niceNormalized = 1.0
        } else if normalized <= 2.0 {
            niceNormalized = 2.0
        } else if normalized <= 2.5 {
            niceNormalized = 2.5
        } else if normalized <= 5.0 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }

        return niceNormalized * magnitude
    }
}

enum IndicatorPanelZoomPolicy {
    case fixed(range: ClosedRange<Double>, minimumScale: CGFloat = 1.0)
    case visible(
        hardLowerBound: Double? = nil,
        hardUpperBound: Double? = nil,
        includeZero: Bool = false,
        symmetricAroundZero: Bool = false,
        paddingFraction: Double = 0.08,
        minimumScale: CGFloat = 0.8
    )

    var minimumScale: CGFloat {
        switch self {
        case .fixed(_, let minimumScale):
            return minimumScale
        case .visible(_, _, _, _, _, let minimumScale):
            return minimumScale
        }
    }

    func resolvedRange(
        visibleValues: [Double],
        fallbackValues: [Double] = [],
        emphasisValues: [Double] = []
    ) -> (min: Double, max: Double) {
        switch self {
        case .fixed(let range, _):
            return (range.lowerBound, range.upperBound)

        case .visible(
            let hardLowerBound,
            let hardUpperBound,
            let includeZero,
            let symmetricAroundZero,
            let paddingFraction,
            _
        ):
            let sourceValues = !visibleValues.isEmpty ? visibleValues : fallbackValues
            var minValue = sourceValues.min() ?? 0
            var maxValue = sourceValues.max() ?? 1

            if includeZero {
                minValue = min(minValue, 0)
                maxValue = max(maxValue, 0)
            }

            for emphasis in emphasisValues {
                minValue = min(minValue, emphasis)
                maxValue = max(maxValue, emphasis)
            }

            if symmetricAroundZero {
                let absMax = max(abs(minValue), abs(maxValue))
                minValue = -absMax
                maxValue = absMax
            }

            if maxValue <= minValue {
                let delta = max(1.0, abs(maxValue) * 0.05)
                minValue -= delta
                maxValue += delta
            }

            let range = maxValue - minValue
            let padding = range * paddingFraction
            var paddedMin = minValue - padding
            var paddedMax = maxValue + padding

            if let hardLowerBound {
                paddedMin = max(hardLowerBound, paddedMin)
            }
            if let hardUpperBound {
                paddedMax = min(hardUpperBound, paddedMax)
            }

            if paddedMax <= paddedMin {
                let delta = max(1.0, abs(maxValue) * 0.05)
                paddedMin -= delta
                paddedMax += delta
            }

            return (paddedMin, paddedMax)
        }
    }
}

@MainActor
final class IndicatorPanelViewportState: ObservableObject {
    @Published var priceScale: CGFloat = 1.0
    @Published var verticalPanOffset: CGFloat = 0

    func applyBodyPan(translationY: CGFloat, panelHeight: CGFloat) {
        let proposedOffset = verticalPanOffset + translationY
        verticalPanOffset = clampedVerticalOffset(proposedOffset, panelHeight: panelHeight, priceScale: priceScale)
    }

    func applyPriceScale(
        proposedScale: CGFloat,
        initialPriceScale: CGFloat,
        initialVerticalOffset: CGFloat,
        anchorY: CGFloat,
        panelHeight: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        let clampedScale = min(maxScale, max(minScale, proposedScale))
        let safeInitialScale = max(initialPriceScale, 0.0001)
        let scaleRatio = clampedScale / safeInitialScale
        let proposedOffset = initialVerticalOffset * scaleRatio + anchorY * (1.0 - scaleRatio)

        priceScale = clampedScale
        verticalPanOffset = clampedVerticalOffset(
            proposedOffset,
            panelHeight: panelHeight,
            priceScale: clampedScale
        )
    }

    func reset() {
        priceScale = 1.0
        verticalPanOffset = 0
    }

    private func clampedVerticalOffset(_ offset: CGFloat, panelHeight: CGFloat, priceScale: CGFloat) -> CGFloat {
        let limit = max(36, panelHeight * max(1.0, priceScale) * 0.9)
        return min(limit, max(-limit, offset))
    }
}

@MainActor
final class IndicatorPanelViewportStore: ObservableObject {
    private var states: [PanelIndicatorType: IndicatorPanelViewportState] = [:]

    func state(for panelType: PanelIndicatorType) -> IndicatorPanelViewportState {
        if let state = states[panelType] {
            return state
        }

        let state = IndicatorPanelViewportState()
        states[panelType] = state
        return state
    }

    func reset(_ panelType: PanelIndicatorType) {
        state(for: panelType).reset()
    }
}

struct PanelMiniInfoToken: Identifiable {
    let id = UUID()
    let label: String?
    let value: String
    let valueColor: Color
}

struct PanelMiniInfoBadge: Identifiable {
    let id = UUID()
    let text: String
    let color: Color

    var textColor: Color

    init(text: String, color: Color, textColor: Color? = nil) {
        self.text = text
        self.color = color
        self.textColor = textColor ?? PanelChromeTextColorResolver.textColor(for: color)
    }
}

enum PanelChromeTextColorResolver {
    static func textColor(for background: Color) -> Color {
        let uiColor = UIColor(background)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return AppColors.onAccentForeground
        }

        let luminance =
            (0.2126 * red) +
            (0.7152 * green) +
            (0.0722 * blue)

        return luminance > 0.62 ? AppColors.primaryForeground : AppColors.onAccentForeground
    }

    static func readableAccentColor(_ preferred: Color) -> Color {
        let uiColor = UIColor(preferred)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return preferred
        }

        let luminance =
            (0.2126 * red) +
            (0.7152 * green) +
            (0.0722 * blue)

        return luminance > 0.7 ? AppColors.primaryForeground : preferred
    }
}

struct PanelMiniInfoOverlay: View {
    var leadingBadge: PanelMiniInfoBadge? = nil
    var tokens: [PanelMiniInfoToken]
    var trailingBadge: PanelMiniInfoBadge? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let leadingBadge {
                badgeView(leadingBadge)
            }

            ForEach(tokens) { token in
                HStack(spacing: 3) {
                    if let label = token.label, !label.isEmpty {
                        Text(label)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.panelMiniInfoOverlaySecondaryText)
                    }

                    Text(token.value)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(token.valueColor)
                }
            }

            if let trailingBadge {
                badgeView(trailingBadge)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.panelMiniInfoOverlayFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.panelMiniInfoOverlayStroke, lineWidth: 1)
        )
        .shadow(color: AppColors.surfaceBlack62.opacity(0.12), radius: 2, x: 0, y: 1)
    }

    private func badgeView(_ badge: PanelMiniInfoBadge) -> some View {
        Text(badge.text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(badge.textColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(badge.color)
            )
    }
}

struct IndicatorPanelYAxisLabel: Identifiable {
    let id = UUID()
    let value: Double
    let text: String
    let color: Color
}

struct IndicatorPanelGuideLine {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 0.5
    var dash: [CGFloat] = []
}

func drawIndicatorPanelGuideLines(
    context: GraphicsContext,
    viewport: IndicatorPanelViewport,
    plotWidth: CGFloat,
    guides: [IndicatorPanelGuideLine]
) {
    guard plotWidth > 0 else { return }

    for guide in guides {
        let y = viewport.yPosition(for: guide.value)
        guard y.isFinite else { continue }

        let path = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: plotWidth, y: y))
        }

        context.stroke(
            path,
            with: .color(guide.color),
            style: StrokeStyle(lineWidth: guide.lineWidth, dash: guide.dash)
        )
    }
}

struct IndicatorPanelYAxisLane: View {
    let viewport: IndicatorPanelViewport
    let labels: [IndicatorPanelYAxisLabel]
    var laneWidth: CGFloat = ChartAxisMetrics.indicatorPanelYAxisLaneWidth
    var labelWidth: CGFloat = ChartAxisMetrics.indicatorPanelYAxisLabelWidth

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.panelYAxisLaneBackground

                Canvas { context, size in
                    let x = max(2, min(size.width - 3, labelWidth + 1))

                    for label in labels {
                        let y = viewport.yPosition(for: label.value)
                        guard y >= viewport.topPadding - 12, y <= viewport.contentBottomY + 12 else { continue }

                        context.draw(
                            Text(label.text)
                                .font(.system(size: ChartAxisMetrics.indicatorPanelYAxisLabelFontSize, weight: .semibold, design: .monospaced))
                                .foregroundColor(label.color),
                            at: CGPoint(x: x, y: y),
                            anchor: .trailing
                        )
                    }
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.adaptiveOverlay10)
                    .frame(width: 1)
            }
        }
        .frame(width: laneWidth)
        .allowsHitTesting(false)
    }
}
