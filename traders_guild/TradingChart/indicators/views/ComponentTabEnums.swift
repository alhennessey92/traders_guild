import SwiftUI

enum ComponentSubTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case indicators = "Indicators"
    case drawings = "Drawings"
    case timeframes = "Timeframes"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .indicators:
            return "chart.line.uptrend.xyaxis.circle"
        case .drawings:
            return "pencil.circle"
        case .timeframes:
            return "clock.circle"
        }
    }
}

enum IndicatorSubTab: String, CaseIterable, UnifiedTabItem {
    case trend = "Trend"
    case volatility = "Volatility"
    case momentum = "Momentum"
    case volume = "Volume"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .trend:
            return IndicatorCategory.trend.icon
        case .volatility:
            return IndicatorCategory.volatility.icon
        case .momentum:
            return IndicatorCategory.momentum.icon
        case .volume:
            return IndicatorCategory.volume.icon
        }
    }

    var category: IndicatorCategory {
        switch self {
        case .trend:
            return .trend
        case .volatility:
            return .volatility
        case .momentum:
            return .momentum
        case .volume:
            return .volume
        }
    }
}

enum DrawingSubTab: String, CaseIterable, UnifiedTabItem {
    case lines = "Lines"
    case zones = "Zones"
    case annotations = "Annotations"
    case patterns = "Patterns"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .lines:
            return "line.3.horizontal"
        case .zones:
            return "square.dashed"
        case .annotations:
            return "text.bubble"
        case .patterns:
            return "triangle"
        }
    }
}

struct ChartPatternMarkerComponent {
    let componentType: RLComponentType
    let payload: MarkerComponentPayload
}

enum ChartPatternDrawingTemplate: String, CaseIterable, Identifiable {
    case breakoutRetest
    case rangeReversal
    case risingChannel
    case headAndShoulders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakoutRetest:
            return "Breakout Retest"
        case .rangeReversal:
            return "Range Reversal"
        case .risingChannel:
            return "Rising Channel"
        case .headAndShoulders:
            return "Head & Shoulders"
        }
    }

    var subtitle: String {
        switch self {
        case .breakoutRetest:
            return "Breakout level, retest zone, and momentum guide"
        case .rangeReversal:
            return "Range high, range low, mean zone, and note"
        case .risingChannel:
            return "Parallel channel guides with a context note"
        case .headAndShoulders:
            return "Shoulder guides, neckline, and pattern label"
        }
    }

    var icon: String {
        switch self {
        case .breakoutRetest:
            return "arrow.up.right.circle"
        case .rangeReversal:
            return "arrow.left.and.right"
        case .risingChannel:
            return "line.diagonal.arrow"
        case .headAndShoulders:
            return "waveform.path.ecg"
        }
    }

    var tintHex: String {
        switch self {
        case .breakoutRetest:
            return "#F59E0B"
        case .rangeReversal:
            return "#38BDF8"
        case .risingChannel:
            return "#10B981"
        case .headAndShoulders:
            return "#F43F5E"
        }
    }

    var requiredDrawingSlots: Int {
        1
    }

    var toolKind: MarkerDrawingToolKind {
        switch self {
        case .breakoutRetest:
            return .breakoutRetest
        case .rangeReversal:
            return .rangeReversal
        case .risingChannel:
            return .risingChannel
        case .headAndShoulders:
            return .headAndShoulders
        }
    }

    var requiredGuidePoints: Int {
        switch self {
        case .rangeReversal, .headAndShoulders:
            return 4
        case .breakoutRetest, .risingChannel:
            return 3
        }
    }

    var pointLabels: [String] {
        switch self {
        case .breakoutRetest:
            return ["Breakout level start", "Breakout level end", "Retest reaction"]
        case .rangeReversal:
            return ["Range high", "Range low", "Rejection", "Target / mean"]
        case .risingChannel:
            return ["Lower channel start", "Lower channel end", "Upper guide"]
        case .headAndShoulders:
            return ["Left shoulder", "Head", "Right shoulder", "Neckline"]
        }
    }

    func payload(
        points: [PatternGuidePointPayload],
        accentColorHex: String?
    ) -> ChartPatternPayload {
        ChartPatternPayload(
            patternKey: rawValue,
            title: title,
            points: points,
            colorHex: accentColorHex ?? tintHex,
            lineStyle: .dashed,
            lineWidth: 2
        )
    }

    func chartDrawing(
        anchorTime: Date,
        anchorPrice: Double,
        accentColorHex: String
    ) -> ChartDrawing {
        let anchor = PatternAnchor(time: anchorTime, price: anchorPrice)
        let points = defaultPoints(anchor: anchor).map { point in
            ChartDrawingPoint(time: point.time, price: point.price)
        }
        return ChartDrawing(
            type: .pattern,
            points: points,
            colorHex: accentColorHex,
            lineStyle: .dashed,
            lineWidth: 2,
            note: title,
            patternKey: rawValue
        )
    }

    func chartDrawings(
        anchorTime: Date,
        anchorPrice: Double,
        accentColorHex: String
    ) -> [ChartDrawing] {
        [
            chartDrawing(
                anchorTime: anchorTime,
                anchorPrice: anchorPrice,
                accentColorHex: accentColorHex
            )
        ]
    }

    private func defaultPoints(anchor: PatternAnchor) -> [PatternGuidePointPayload] {
        switch self {
        case .breakoutRetest:
            return [
                PatternGuidePointPayload(time: anchor.time(minutes: -75), price: anchor.price(offset: 0.85), label: pointLabels[0]),
                PatternGuidePointPayload(time: anchor.time(minutes: 15), price: anchor.price(offset: 0.85), label: pointLabels[1]),
                PatternGuidePointPayload(time: anchor.time(minutes: 75), price: anchor.price(offset: -0.2), label: pointLabels[2]),
            ]
        case .rangeReversal:
            return [
                PatternGuidePointPayload(time: anchor.time(minutes: -80), price: anchor.price(offset: 1.8), label: pointLabels[0]),
                PatternGuidePointPayload(time: anchor.time(minutes: -80), price: anchor.price(offset: -1.8), label: pointLabels[1]),
                PatternGuidePointPayload(time: anchor.time(minutes: 35), price: anchor.price(offset: -1.5), label: pointLabels[2]),
                PatternGuidePointPayload(time: anchor.time(minutes: 90), price: anchor.price(offset: 0.2), label: pointLabels[3]),
            ]
        case .risingChannel:
            return [
                PatternGuidePointPayload(time: anchor.time(minutes: -90), price: anchor.price(offset: -1.8), label: pointLabels[0]),
                PatternGuidePointPayload(time: anchor.time(minutes: 90), price: anchor.price(offset: 0.65), label: pointLabels[1]),
                PatternGuidePointPayload(time: anchor.time(minutes: -90), price: anchor.price(offset: 0.3), label: pointLabels[2]),
            ]
        case .headAndShoulders:
            return [
                PatternGuidePointPayload(time: anchor.time(minutes: -90), price: anchor.price(offset: 0.2), label: pointLabels[0]),
                PatternGuidePointPayload(time: anchor.time(minutes: -30), price: anchor.price(offset: 2.0), label: pointLabels[1]),
                PatternGuidePointPayload(time: anchor.time(minutes: 45), price: anchor.price(offset: 0.25), label: pointLabels[2]),
                PatternGuidePointPayload(time: anchor.time(minutes: 0), price: anchor.price(offset: -1.15), label: pointLabels[3]),
            ]
        }
    }

    func markerComponents(
        anchorTime: Date,
        anchorPrice: Double,
        accentColorHex: String?
    ) -> [ChartPatternMarkerComponent] {
        let anchor = PatternAnchor(time: anchorTime, price: anchorPrice)
        let accent = accentColorHex ?? tintHex

        switch self {
        case .breakoutRetest:
            return [
                zone(anchor, top: 0.45, bottom: -0.45, start: -90, end: 90, colorHex: "#22C55E"),
                horizontal(anchor, price: 0.85, label: "Breakout", colorHex: "#F59E0B"),
                trendline(anchor, startMinute: -90, startOffset: -1.8, endMinute: 90, endOffset: 0.75, colorHex: accent),
                note(anchor, price: 1.45, text: "Breakout retest", colorHex: accent),
            ]
        case .rangeReversal:
            return [
                horizontal(anchor, price: 1.8, label: "Range High", colorHex: "#F43F5E"),
                horizontal(anchor, price: -1.8, label: "Range Low", colorHex: "#10B981"),
                zone(anchor, top: 0.45, bottom: -0.45, start: -90, end: 90, colorHex: "#38BDF8"),
                note(anchor, price: 2.35, text: "Range reversal", colorHex: "#38BDF8"),
            ]
        case .risingChannel:
            return [
                trendline(anchor, startMinute: -90, startOffset: -1.8, endMinute: 90, endOffset: 0.65, colorHex: accent),
                trendline(anchor, startMinute: -90, startOffset: 0.3, endMinute: 90, endOffset: 2.75, colorHex: accent),
                note(anchor, price: 3.25, text: "Rising channel", colorHex: accent),
            ]
        case .headAndShoulders:
            return [
                trendline(anchor, startMinute: -90, startOffset: 0.2, endMinute: -30, endOffset: 2.0, colorHex: accent),
                trendline(anchor, startMinute: -30, startOffset: 2.0, endMinute: 60, endOffset: 0.25, colorHex: accent),
                horizontal(anchor, price: -1.15, label: "Neckline", colorHex: "#F43F5E"),
                note(anchor, price: 2.55, text: "Head & Shoulders", colorHex: accent),
            ]
        }
    }

    private struct PatternAnchor {
        let time: Date
        let price: Double

        var priceStep: Double {
            max(abs(price) * 0.012, 0.0001)
        }

        func time(minutes offset: Double) -> Date {
            time.addingTimeInterval(offset * 60)
        }

        func price(offset: Double) -> Double {
            price + priceStep * offset
        }
    }

    private func trendline(
        _ anchor: PatternAnchor,
        startMinute: Double,
        startOffset: Double,
        endMinute: Double,
        endOffset: Double,
        colorHex: String
    ) -> ChartPatternMarkerComponent {
        ChartPatternMarkerComponent(
            componentType: .drawingTrendline,
            payload: .drawingTrendline(
                TrendlinePayload(
                    startTime: anchor.time(minutes: startMinute),
                    startPrice: anchor.price(offset: startOffset),
                    endTime: anchor.time(minutes: endMinute),
                    endPrice: anchor.price(offset: endOffset),
                    colorHex: colorHex,
                    lineStyle: .dashed,
                    lineWidth: 2
                )
            )
        )
    }

    private func horizontal(
        _ anchor: PatternAnchor,
        price offset: Double,
        label: String,
        colorHex: String
    ) -> ChartPatternMarkerComponent {
        ChartPatternMarkerComponent(
            componentType: .drawingHorizontalLine,
            payload: .drawingHorizontalLine(
                HorizontalLinePayload(
                    price: anchor.price(offset: offset),
                    label: label,
                    colorHex: colorHex,
                    lineStyle: .dashed,
                    lineWidth: 2
                )
            )
        )
    }

    private func zone(
        _ anchor: PatternAnchor,
        top: Double,
        bottom: Double,
        start: Double,
        end: Double,
        colorHex: String
    ) -> ChartPatternMarkerComponent {
        ChartPatternMarkerComponent(
            componentType: .drawingZone,
            payload: .drawingZone(
                ZonePayload(
                    topPrice: anchor.price(offset: top),
                    bottomPrice: anchor.price(offset: bottom),
                    startTime: anchor.time(minutes: start),
                    endTime: anchor.time(minutes: end),
                    colorHex: colorHex,
                    lineStyle: .dotted,
                    lineWidth: 1.5
                )
            )
        )
    }

    private func note(
        _ anchor: PatternAnchor,
        price offset: Double,
        text: String,
        colorHex: String
    ) -> ChartPatternMarkerComponent {
        ChartPatternMarkerComponent(
            componentType: .textNote,
            payload: .note(
                NotePayload(
                    text: text,
                    anchorTime: anchor.time(minutes: 0),
                    anchorPrice: anchor.price(offset: offset),
                    fontSize: 13,
                    colorHex: colorHex
                )
            )
        )
    }
}
