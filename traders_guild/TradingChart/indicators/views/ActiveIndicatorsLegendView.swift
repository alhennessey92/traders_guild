//
//  ActiveIndicatorsLegendView.swift
//  traders_guild
//
//  Shows active overlay and panel indicators in the chart info box.
//

import SwiftUI

enum ActiveIndicatorLegendKind: Equatable {
    case overlay
    case panel
    case timeframe
}

enum ActiveIndicatorLegendSwatchStyle: Equatable {
    case line
    case dot
}

struct ActiveIndicatorLegendSwatch: Identifiable {
    let id: String
    let color: Color
    let style: ActiveIndicatorLegendSwatchStyle

    init(id: String, color: Color, style: ActiveIndicatorLegendSwatchStyle = .line) {
        self.id = id
        self.color = color
        self.style = style
    }
}

struct ActiveIndicatorLegendEntry: Identifiable {
    let id: String
    let text: String
    let swatches: [ActiveIndicatorLegendSwatch]
    let kind: ActiveIndicatorLegendKind
}

struct TimeframeLegendTextParts: Equatable {
    let prefix: String
    let token: String

    static func split(_ text: String) -> TimeframeLegendTextParts {
        guard text.hasPrefix("TF ") else {
            return TimeframeLegendTextParts(prefix: "", token: text)
        }
        let token = String(text.dropFirst(3))
        return TimeframeLegendTextParts(prefix: "TF ", token: token)
    }
}

struct ChartDrawingLegendEntry: Identifiable {
    let id: UUID
    let text: String
    let accentColor: Color
}

enum ActiveIndicatorsLegendComposer {
    static func entries(from active: ActiveIndicators) -> [ActiveIndicatorLegendEntry] {
        var entries: [ActiveIndicatorLegendEntry] = []

        for ma in active.enabledMovingAverages {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "ma-\(ma.id.uuidString)",
                    text: ma.label,
                    swatches: [
                        ActiveIndicatorLegendSwatch(
                            id: "ma-line-\(ma.id.uuidString)",
                            color: ma.color.color
                        )
                    ],
                    kind: .overlay
                )
            )
        }

        if let vwap = active.vwap, vwap.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "vwap-\(vwap.id.uuidString)",
                    text: vwap.showStandardDeviationBands ? "VWAP ±σ" : "VWAP",
                    swatches: vwap.showStandardDeviationBands
                        ? [
                            ActiveIndicatorLegendSwatch(id: "vwap-upper-\(vwap.id.uuidString)", color: vwap.upperBandColor.color),
                            ActiveIndicatorLegendSwatch(id: "vwap-line-\(vwap.id.uuidString)", color: vwap.color.color),
                            ActiveIndicatorLegendSwatch(id: "vwap-lower-\(vwap.id.uuidString)", color: vwap.lowerBandColor.color),
                        ]
                        : [
                            ActiveIndicatorLegendSwatch(id: "vwap-line-\(vwap.id.uuidString)", color: vwap.color.color),
                        ],
                    kind: .overlay
                )
            )
        }

        if let sar = active.parabolicSAR, sar.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "sar-\(sar.id.uuidString)",
                    text: "SAR",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "sar-bull-\(sar.id.uuidString)", color: sar.bullishColor.color, style: .dot),
                        ActiveIndicatorLegendSwatch(id: "sar-bear-\(sar.id.uuidString)", color: sar.bearishColor.color, style: .dot),
                    ],
                    kind: .overlay
                )
            )
        }

        if let bb = active.bollingerBands, bb.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "bb-\(bb.id.uuidString)",
                    text: "BB(\(bb.period), \(String(format: "%.1f", bb.standardDeviations))σ)",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "bb-upper-\(bb.id.uuidString)", color: bb.upperBandColor.color),
                        ActiveIndicatorLegendSwatch(id: "bb-mid-\(bb.id.uuidString)", color: bb.color.color),
                        ActiveIndicatorLegendSwatch(id: "bb-lower-\(bb.id.uuidString)", color: bb.lowerBandColor.color),
                    ],
                    kind: .overlay
                )
            )
        }

        if let dc = active.donchianChannels, dc.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "dc-\(dc.id.uuidString)",
                    text: "DC(\(dc.period))",
                    swatches: {
                        var swatches = [
                            ActiveIndicatorLegendSwatch(id: "dc-upper-\(dc.id.uuidString)", color: dc.upperBandColor.color),
                        ]
                        if dc.showMiddleLine {
                            swatches.append(
                                ActiveIndicatorLegendSwatch(id: "dc-mid-\(dc.id.uuidString)", color: dc.color.color)
                            )
                        }
                        swatches.append(
                            ActiveIndicatorLegendSwatch(id: "dc-lower-\(dc.id.uuidString)", color: dc.lowerBandColor.color)
                        )
                        return swatches
                    }(),
                    kind: .overlay
                )
            )
        }

        if let kc = active.keltnerChannels, kc.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "kc-\(kc.id.uuidString)",
                    text: "KC(\(kc.emaPeriod), \(kc.atrPeriod))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "kc-upper-\(kc.id.uuidString)", color: kc.upperBandColor.color),
                        ActiveIndicatorLegendSwatch(id: "kc-mid-\(kc.id.uuidString)", color: kc.color.color),
                        ActiveIndicatorLegendSwatch(id: "kc-lower-\(kc.id.uuidString)", color: kc.lowerBandColor.color),
                    ],
                    kind: .overlay
                )
            )
        }

        if let rsi = active.rsi, rsi.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "rsi-\(rsi.id.uuidString)",
                    text: "RSI(\(rsi.period))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "rsi-line-\(rsi.id.uuidString)", color: rsi.color.color)
                    ],
                    kind: .panel
                )
            )
        }

        if let macd = active.macd, macd.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "macd-\(macd.id.uuidString)",
                    text: "MACD(\(macd.fastPeriod),\(macd.slowPeriod),\(macd.signalPeriod))",
                    swatches: {
                        var swatches = [
                            ActiveIndicatorLegendSwatch(id: "macd-line-\(macd.id.uuidString)", color: macd.color.color)
                        ]
                        if macd.showSignalLine {
                            swatches.append(
                                ActiveIndicatorLegendSwatch(id: "macd-signal-\(macd.id.uuidString)", color: macd.signalColor.color)
                            )
                        }
                        if macd.showHistogram {
                            swatches.append(
                                ActiveIndicatorLegendSwatch(id: "macd-hist-pos-\(macd.id.uuidString)", color: macd.histogramPositiveColor.color)
                            )
                            swatches.append(
                                ActiveIndicatorLegendSwatch(id: "macd-hist-neg-\(macd.id.uuidString)", color: macd.histogramNegativeColor.color)
                            )
                        }
                        return swatches
                    }(),
                    kind: .panel
                )
            )
        }

        if let stochastic = active.stochastic, stochastic.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "stoch-\(stochastic.id.uuidString)",
                    text: "Stoch(\(stochastic.kPeriod),\(stochastic.dPeriod))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "stoch-k-\(stochastic.id.uuidString)", color: stochastic.color.color),
                        ActiveIndicatorLegendSwatch(id: "stoch-d-\(stochastic.id.uuidString)", color: stochastic.dColor.color),
                    ],
                    kind: .panel
                )
            )
        }

        if let cci = active.cci, cci.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "cci-\(cci.id.uuidString)",
                    text: "CCI(\(cci.period))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "cci-line-\(cci.id.uuidString)", color: cci.color.color)
                    ],
                    kind: .panel
                )
            )
        }

        if let williamsR = active.williamsR, williamsR.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "wpr-\(williamsR.id.uuidString)",
                    text: "W%R(\(williamsR.period))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "wpr-line-\(williamsR.id.uuidString)", color: williamsR.color.color)
                    ],
                    kind: .panel
                )
            )
        }

        if let atr = active.atr, atr.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "atr-\(atr.id.uuidString)",
                    text: "ATR(\(atr.period))",
                    swatches: [
                        ActiveIndicatorLegendSwatch(id: "atr-line-\(atr.id.uuidString)", color: atr.color.color)
                    ],
                    kind: .panel
                )
            )
        }

        if let volume = active.volume, volume.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "vol-\(volume.id.uuidString)",
                    text: volume.showMA ? "VOL(MA\(volume.maPeriod))" : "VOL",
                    swatches: {
                        var swatches = [
                            ActiveIndicatorLegendSwatch(id: "vol-bull-\(volume.id.uuidString)", color: volume.bullishColor.color),
                            ActiveIndicatorLegendSwatch(id: "vol-bear-\(volume.id.uuidString)", color: volume.bearishColor.color),
                        ]
                        if volume.showMA {
                            swatches.append(
                                ActiveIndicatorLegendSwatch(id: "vol-ma-\(volume.id.uuidString)", color: volume.maColor.color)
                            )
                        }
                        return swatches
                    }(),
                    kind: .panel
                )
            )
        }

        return entries
    }

    static func labels(from active: ActiveIndicators) -> [String] {
        entries(from: active).map(\.text)
    }
}

enum TimeframeLegendComposer {
    static func entries(from panels: [TimeframePanelEntry]) -> [ActiveIndicatorLegendEntry] {
        panels.map { panel in
            ActiveIndicatorLegendEntry(
                id: "tf-\(panel.source.rawValue)-\(panel.id.uuidString)",
                text: timeframeLabel(for: panel.timeframe),
                swatches: [],
                kind: .timeframe
            )
        }
    }

    static func labels(from panels: [TimeframePanelEntry]) -> [String] {
        entries(from: panels).map(\.text)
    }

    private static func timeframeLabel(for timeframe: RLChartTimeframe) -> String {
        switch timeframe {
        case .m1, .m5, .m15, .m30:
            return "TF \(timeframe.rawValue)"
        default:
            return "TF \(timeframe.shortName.uppercased())"
        }
    }
}

enum ChartDrawingsLegendComposer {
    static func entries(
        from drawings: [ChartDrawing],
        formatPrice: (Double) -> String
    ) -> [ChartDrawingLegendEntry] {
        drawings.compactMap { drawing in
            let accentColor = Color(hex: drawing.colorHex) ?? accentColor(for: drawing.type)
            switch drawing.type {
            case .horizontalLine, .supportLevel, .resistanceLevel:
                guard let price = drawing.points.first?.price else { return nil }
                let fallbackLabel: String = {
                    switch drawing.type {
                    case .horizontalLine: return "Line"
                    case .supportLevel: return "Support"
                    case .resistanceLevel: return "Resistance"
                    default: return drawing.type.title
                    }
                }()
                let trimmedLabel = drawing.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let label = trimmedLabel.isEmpty ? fallbackLabel : trimmedLabel
                return ChartDrawingLegendEntry(
                    id: drawing.id,
                    text: "\(label) \(formatPrice(price))",
                    accentColor: accentColor
                )

            case .trendline, .zone:
                return ChartDrawingLegendEntry(
                    id: drawing.id,
                    text: drawing.type.title,
                    accentColor: accentColor
                )

            case .textNote:
                let trimmed = drawing.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return ChartDrawingLegendEntry(
                    id: drawing.id,
                    text: trimmed.isEmpty ? "Note" : trimmed,
                    accentColor: accentColor
                )

            case .emoji:
                let emoji = drawing.emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return ChartDrawingLegendEntry(
                    id: drawing.id,
                    text: emoji.isEmpty ? "Emoji" : emoji,
                    accentColor: accentColor
                )
            }
        }
    }

    static func labels(from drawings: [ChartDrawing], formatPrice: (Double) -> String) -> [String] {
        entries(from: drawings, formatPrice: formatPrice).map(\.text)
    }

    private static func accentColor(for type: ChartDrawingType) -> Color {
        Color(hex: type.defaultColorHex) ?? AppColors.surfaceWhite70
    }
}

struct ActiveIndicatorsLegendView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    var timeframeEntries: [ActiveIndicatorLegendEntry] = []
    var drawings: [ChartDrawing] = []
    var formatPrice: (Double) -> String = { price in String(format: "%.4f", price) }

    private var legendEntries: [ActiveIndicatorLegendEntry] {
        timeframeEntries + ActiveIndicatorsLegendComposer.entries(from: indicatorManager.activeIndicators)
    }

    private var drawingEntries: [ChartDrawingLegendEntry] {
        ChartDrawingsLegendComposer.entries(from: drawings, formatPrice: formatPrice)
    }

    var body: some View {
        if !legendEntries.isEmpty || !drawingEntries.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if !legendEntries.isEmpty {
                    ForEach(legendEntries) { entry in
                        legendItem(entry)
                    }
                }

                if !legendEntries.isEmpty && !drawingEntries.isEmpty {
                    Capsule()
                        .fill(AppColors.surfaceWhite12)
                        .frame(width: 26, height: 1)
                        .padding(.vertical, 2)
                }

                if !drawingEntries.isEmpty {
                    ForEach(drawingEntries) { entry in
                        drawingLegendItem(entry)
                    }
                }
            }
            .padding(.top, 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendItem(_ entry: ActiveIndicatorLegendEntry) -> some View {
        HStack(spacing: 4) {
            if !entry.swatches.isEmpty {
                HStack(spacing: 3) {
                    ForEach(entry.swatches) { swatch in
                        switch swatch.style {
                        case .line:
                            RoundedRectangle(cornerRadius: 1)
                                .fill(swatch.color)
                                .frame(width: 10, height: 2)
                        case .dot:
                            Circle()
                                .fill(swatch.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            legendText(for: entry)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func legendText(for entry: ActiveIndicatorLegendEntry) -> some View {
        if entry.kind == .timeframe {
            let parts = TimeframeLegendTextParts.split(entry.text)
            (
                Text(parts.prefix)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.surfaceWhite70)
                +
                Text(parts.token)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
            )
        } else {
            Text(entry.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite80)
        }
    }

    private func drawingLegendItem(_ entry: ChartDrawingLegendEntry) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(entry.accentColor)
                .frame(width: 12, height: 2)

            Text(entry.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite80)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Compact Version (for tighter spaces)

struct ActiveIndicatorsLegendCompactView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    var timeframeEntries: [ActiveIndicatorLegendEntry] = []

    private var legendEntries: [ActiveIndicatorLegendEntry] {
        timeframeEntries + ActiveIndicatorsLegendComposer.entries(from: indicatorManager.activeIndicators)
    }

    var body: some View {
        if !legendEntries.isEmpty {
            HStack(spacing: 8) {
                ForEach(legendEntries) { entry in
                    HStack(spacing: 3) {
                        if let swatch = entry.swatches.first {
                            switch swatch.style {
                            case .line:
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(swatch.color)
                                    .frame(width: 10, height: 2)
                            case .dot:
                                Circle()
                                    .fill(swatch.color)
                                    .frame(width: 5, height: 5)
                            }
                        }

                        compactLegendText(for: entry)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.surfaceBlack30)
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func compactLegendText(for entry: ActiveIndicatorLegendEntry) -> some View {
        if entry.kind == .timeframe {
            let parts = TimeframeLegendTextParts.split(entry.text)
            (
                Text(parts.prefix)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppColors.surfaceWhite66)
                +
                Text(parts.token)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
            )
        } else {
            Text(entry.text)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite70)
        }
    }
}
