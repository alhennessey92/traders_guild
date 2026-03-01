//
//  MarkerTimebar.swift
//  traders_guild
//
//  FIXED v3 - Time indicator now positioned prominently above bottom sheet
//  Styled to match price indicator (yellow) but in blue
//

import SwiftUI

enum MarkerPlacementLabelFormatter {
    static func format(_ timestamp: Date, timeframe: RLChartTimeframe) -> String {
        ChartXAxisLabelEngine.formatCrosshairTimestamp(timestamp, timeframe: timeframe)
    }
}

struct ChartXAxisLabel: Equatable {
    enum Kind: Equatable {
        case primary
        case secondary
    }

    let text: String
    let x: CGFloat
    let kind: Kind
}

enum ChartXAxisLabelStyle {
    case mainChart
    case indicatorPanel

    var primaryFontSize: CGFloat {
        switch self {
        case .mainChart:
            return 12
        case .indicatorPanel:
            return 10
        }
    }

    var secondaryFontSize: CGFloat {
        switch self {
        case .mainChart:
            return 11
        case .indicatorPanel:
            return 9
        }
    }
}

enum ChartXAxisLabelEngine {
    struct Input {
        let candles: [RLCandleDTO]
        let timeframe: RLChartTimeframe
        let totalOffset: CGFloat
        let totalCandleWidth: CGFloat
        let actualCandleWidth: CGFloat
        let width: CGFloat
        var timeZone: TimeZone = .current
        var locale: Locale = Locale(identifier: "en_US_POSIX")
        var minSpacing: CGFloat = 44
    }

    static func drawLabels(
        context: GraphicsContext,
        size: CGSize,
        input: Input,
        style: ChartXAxisLabelStyle
    ) {
        let labels = makeLabels(input: input)
        for label in labels {
            let fontSize = label.kind == .primary ? style.primaryFontSize : style.secondaryFontSize
            let weight: Font.Weight = label.kind == .primary ? .bold : .regular
            let color: Color = label.kind == .primary ? .white : .gray

            context.draw(
                Text(label.text)
                    .font(.system(size: fontSize, weight: weight))
                    .foregroundColor(color),
                at: CGPoint(x: label.x, y: 10)
            )
        }
    }

    static func makeLabels(input: Input) -> [ChartXAxisLabel] {
        guard !input.candles.isEmpty, input.totalCandleWidth > 0, input.width > 0 else { return [] }

        let visibleStartIndex = max(0, Int(-input.totalOffset / input.totalCandleWidth) - 2)
        let visibleEndIndex = min(
            input.candles.count - 1,
            max(visibleStartIndex, visibleStartIndex + Int(input.width / input.totalCandleWidth) + 4)
        )
        guard visibleStartIndex <= visibleEndIndex else { return [] }

        let calendar = makeCalendar(timeZone: input.timeZone)
        let stepSeconds = labelStepSeconds(
            timeframe: input.timeframe,
            totalCandleWidth: input.totalCandleWidth,
            visibleWidth: input.width
        )

        var labels: [ChartXAxisLabel] = []
        var lastPlacedX: CGFloat = -.greatestFiniteMagnitude
        var seenBuckets = Set<Int64>()

        let firstLabel = labelAt(
            candleIndex: visibleStartIndex,
            input: input,
            calendar: calendar
        )
        labels.append(firstLabel)
        lastPlacedX = firstLabel.x
        seenBuckets.insert(bucketKey(for: input.candles[visibleStartIndex].timestamp, stepSeconds: stepSeconds))

        if visibleEndIndex - visibleStartIndex > 1 {
            for index in (visibleStartIndex + 1)..<visibleEndIndex {
                let candle = input.candles[index]
                let x = xPosition(for: index, input: input)
                guard x >= -50 && x <= input.width + 50 else { continue }

                let boundary = isPrimaryBoundary(candle.timestamp, timeframe: input.timeframe, calendar: calendar)
                let bucket = bucketKey(for: candle.timestamp, stepSeconds: stepSeconds)
                let minSpacing = boundary ? max(58, input.minSpacing + 10) : input.minSpacing
                let hasSpacing = x - lastPlacedX >= minSpacing

                if boundary {
                    if hasSpacing {
                        labels.append(
                            ChartXAxisLabel(
                                text: formatLabel(
                                    candle.timestamp,
                                    timeframe: input.timeframe,
                                    kind: .primary,
                                    timeZone: input.timeZone,
                                    locale: input.locale
                                ),
                                x: x,
                                kind: .primary
                            )
                        )
                        lastPlacedX = x
                    }
                    seenBuckets.insert(bucket)
                    continue
                }

                if seenBuckets.contains(bucket) {
                    continue
                }

                if hasSpacing {
                    labels.append(
                        ChartXAxisLabel(
                            text: formatLabel(
                                candle.timestamp,
                                timeframe: input.timeframe,
                                kind: .secondary,
                                timeZone: input.timeZone,
                                locale: input.locale
                            ),
                            x: x,
                            kind: .secondary
                        )
                    )
                    lastPlacedX = x
                    seenBuckets.insert(bucket)
                }
            }
        }

        if visibleEndIndex != visibleStartIndex {
            let lastLabel = labelAt(
                candleIndex: visibleEndIndex,
                input: input,
                calendar: calendar
            )

            if let lastPlaced = labels.last {
                if abs(lastLabel.x - lastPlaced.x) >= 34 {
                    labels.append(lastLabel)
                } else if lastLabel.kind == .primary && lastPlaced.kind != .primary {
                    labels[labels.count - 1] = lastLabel
                }
            } else {
                labels.append(lastLabel)
            }
        }

        return labels
    }

    static func formatCrosshairTimestamp(
        _ timestamp: Date,
        timeframe: RLChartTimeframe,
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = locale

        switch timeframe {
        case .d1, .w1, .mn:
            formatter.dateFormat = "dd MMM yyyy"
        case .h4, .h1, .m30, .m15, .m5, .m1:
            formatter.dateFormat = "dd MMM HH:mm"
        }

        return formatter.string(from: timestamp)
    }

    private static func labelAt(
        candleIndex: Int,
        input: Input,
        calendar: Calendar
    ) -> ChartXAxisLabel {
        let candle = input.candles[candleIndex]
        let boundary = isPrimaryBoundary(candle.timestamp, timeframe: input.timeframe, calendar: calendar)
        let kind: ChartXAxisLabel.Kind = boundary ? .primary : .secondary
        return ChartXAxisLabel(
            text: formatLabel(
                candle.timestamp,
                timeframe: input.timeframe,
                kind: kind,
                timeZone: input.timeZone,
                locale: input.locale
            ),
            x: xPosition(for: candleIndex, input: input),
            kind: kind
        )
    }

    private static func xPosition(for candleIndex: Int, input: Input) -> CGFloat {
        CGFloat(candleIndex) * input.totalCandleWidth + input.totalOffset + input.actualCandleWidth / 2
    }

    private static func bucketKey(for timestamp: Date, stepSeconds: TimeInterval) -> Int64 {
        Int64(floor(timestamp.timeIntervalSince1970 / stepSeconds))
    }

    private static func makeCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private static func formatLabel(
        _ timestamp: Date,
        timeframe: RLChartTimeframe,
        kind: ChartXAxisLabel.Kind,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = locale

        switch (timeframe, kind) {
        case (.m1, .secondary), (.m5, .secondary), (.m15, .secondary), (.m30, .secondary), (.h1, .secondary), (.h4, .secondary):
            formatter.dateFormat = "HH:mm"
        case (.m1, .primary), (.m5, .primary), (.m15, .primary), (.m30, .primary), (.h1, .primary), (.h4, .primary):
            formatter.dateFormat = "dd MMM"
        case (.d1, .secondary):
            formatter.dateFormat = "dd MMM"
        case (.d1, .primary):
            formatter.dateFormat = "MMM yyyy"
        case (.w1, .secondary):
            formatter.dateFormat = "dd MMM"
        case (.w1, .primary):
            formatter.dateFormat = "MMM yyyy"
        case (.mn, .secondary):
            formatter.dateFormat = "MMM yy"
        case (.mn, .primary):
            formatter.dateFormat = "yyyy"
        }

        return formatter.string(from: timestamp)
    }

    private static func labelStepSeconds(
        timeframe: RLChartTimeframe,
        totalCandleWidth: CGFloat,
        visibleWidth: CGFloat
    ) -> TimeInterval {
        let visibleCandles = max(2.0, Double(visibleWidth / totalCandleWidth))
        let targetLabels = max(4.0, min(7.0, visibleCandles / 8.0))
        let roughStep = (visibleCandles * timeframe.seconds) / targetLabels

        let niceIntervals: [TimeInterval] = [
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 14400, 21600, 28800, 43200,
            86400, 172800, 259200, 432000,
            604800, 1209600, 2592000, 5184000
        ]

        for interval in niceIntervals where interval >= roughStep * 0.75 {
            return interval
        }

        return niceIntervals.last ?? timeframe.seconds
    }

    private static func isPrimaryBoundary(_ timestamp: Date, timeframe: RLChartTimeframe, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: timestamp)

        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            return components.hour == 0 && components.minute == 0
        case .d1:
            return components.day == 1
        case .w1:
            return components.day == 1 || components.day == 15
        case .mn:
            return components.month == 1
        }
    }
}

// MARK: - X-Axis Time Indicator (Matches Y-Axis Price Indicator Style)

/// Time indicator for marker placement.
/// Uses the same position and formatting behavior as crosshair time labels.
struct MarkerXAxisTimeIndicator: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartHeight: CGFloat
    let timeframe: RLChartTimeframe

    private var timeLabelY: CGFloat {
        let bottomAreaHeight = chartHeight * 0.11
        return chartHeight - bottomAreaHeight - 21
    }

    var body: some View {
        CrosshairTimeLabel(timestamp: timestamp, timeframe: timeframe)
            .position(x: xPosition, y: timeLabelY)
        .allowsHitTesting(false)
    }
}

// MARK: - Full Width Time Bar (Alternative)

/// Full-width time selection bar - use if you want more visual prominence
struct MarkerPlacementTimeBar: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    
    /// INCREASED from 70 to 130 to stay visible above bottom sheets
    private let barBottomOffset: CGFloat = 130
    
    var body: some View {
        ZStack {
            // Semi-transparent bar background
            Rectangle()
                .fill(Color.blue.opacity(0.15))
                .frame(height: 40)
            
            // Highlighted section under selected candle
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.4))
                .frame(width: 75, height: 40)
                .position(x: xPosition, y: 20)
            
            // Time label
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                Text(timestamp.chartTimeLabel)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.blue)
                    .shadow(color: .blue.opacity(0.5), radius: 6, x: 0, y: 2)
            )
            .position(x: xPosition, y: 20)
        }
        .frame(width: chartWidth, height: 40)
        .position(x: chartWidth / 2, y: chartHeight - barBottomOffset)
        .allowsHitTesting(false)
    }
}

// MARK: - Simple Time Pill (Minimal)

struct MarkerPlacementTimeIndicator: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartHeight: CGFloat
    
    private let indicatorBottomOffset: CGFloat = 120
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            
            Text(timestamp.chartTimeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .position(x: xPosition, y: chartHeight - indicatorBottomOffset)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("X-Axis Indicator") {
    ZStack {
        Color.black
        MarkerXAxisTimeIndicator(
            timestamp: Date(),
            xPosition: 200,
            chartHeight: 600,
            timeframe: .h1
        )
    }
}

#Preview("Time Bar") {
    ZStack {
        Color.black
        MarkerPlacementTimeBar(
            timestamp: Date(),
            xPosition: 200,
            chartWidth: 400,
            chartHeight: 600
        )
    }
}
