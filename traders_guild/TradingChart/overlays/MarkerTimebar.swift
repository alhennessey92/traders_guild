//
//  MarkerTimebar.swift
//  traders_guild
//
//  FIXED v3 - Time indicator now positioned prominently above bottom sheet
//  Styled to match price indicator (yellow) but in blue
//

import SwiftUI

enum MarkerPlacementLabelFormatter {
    static func format(_ timestamp: Date, timeframe: RLChartTimeframe, timeZone: TimeZone = .current) -> String {
        ChartXAxisLabelEngine.formatCrosshairTimestamp(timestamp, timeframe: timeframe, timeZone: timeZone)
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
    let isTodayBoundary: Bool
}

enum ChartXAxisLabelStyle {
    case mainChart
    case indicatorPanel

    var primaryFontSize: CGFloat {
        switch self {
        case .mainChart:
            return 12.5
        case .indicatorPanel:
            return 10
        }
    }

    var secondaryFontSize: CGFloat {
        switch self {
        case .mainChart:
            return 11.5
        case .indicatorPanel:
            return 9
        }
    }
}

enum ChartXAxisLabelEngine {
    private struct AxisPolicy {
        let preferredIntervals: [TimeInterval]
        let boundarySpacingBoost: CGFloat
    }

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
        var now: Date = Date()
    }

    static func drawLabels(
        context: GraphicsContext,
        size: CGSize,
        input: Input,
        style: ChartXAxisLabelStyle,
        rightClipMargin: CGFloat = 60
    ) {
        var ctx = context
        let clipRect = CGRect(x: 0, y: 0, width: size.width - rightClipMargin, height: size.height)
        ctx.clip(to: Path(clipRect))

        let labels = makeLabels(input: input)
        for label in labels {
            let fontSize = label.kind == .primary ? style.primaryFontSize : style.secondaryFontSize
            let weight: Font.Weight
            if label.kind == .primary {
                weight = label.isTodayBoundary ? .semibold : .medium
            } else {
                weight = .medium
            }
            let color: Color = label.kind == .primary ? .white : .gray

            ctx.draw(
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
        let policy = axisPolicy(for: input.timeframe)
        let stepSeconds = labelStepSeconds(
            timeframe: input.timeframe,
            totalCandleWidth: input.totalCandleWidth,
            visibleWidth: input.width,
            minSpacing: input.minSpacing,
            policy: policy
        )

        var labels: [ChartXAxisLabel] = []
        var seenBuckets = Set<Int64>()
        var seenPrimaryDays = Set<String>()
        let alignmentTolerance = max(input.timeframe.seconds * 0.45, 1)

        for index in visibleStartIndex...visibleEndIndex {
            let candle = input.candles[index]
            let x = xPosition(for: index, input: input)
            guard x >= -50 && x <= input.width + 50 else { continue }

            let boundary = isPrimaryBoundary(candle.timestamp, timeframe: input.timeframe, calendar: calendar)

            if boundary {
                let dayKey = dayKeyForDate(candle.timestamp, calendar: calendar)
                if !seenPrimaryDays.contains(dayKey) {
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
                            kind: .primary,
                            isTodayBoundary: isTodayBoundaryLabel(
                                timestamp: candle.timestamp,
                                timeframe: input.timeframe,
                                calendar: calendar,
                                now: input.now
                            )
                        )
                    )
                    seenPrimaryDays.insert(dayKey)
                }
                continue
            }

            let bucket = bucketKey(for: candle.timestamp, stepSeconds: stepSeconds)
            if seenBuckets.contains(bucket) || !isAlignedToStep(candle.timestamp, stepSeconds: stepSeconds, tolerance: alignmentTolerance) {
                continue
            }

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
                    kind: .secondary,
                    isTodayBoundary: false
                )
            )
            seenBuckets.insert(bucket)
        }

        return labels.sorted { $0.x < $1.x }
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
            kind: kind,
            isTodayBoundary: false
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
        visibleWidth: CGFloat,
        minSpacing: CGFloat,
        policy: AxisPolicy
    ) -> TimeInterval {
        let visibleCandles = max(2.0, Double(visibleWidth / totalCandleWidth))
        let targetLabels = max(3.0, min(7.0, Double(visibleWidth / max(minSpacing, 56))))
        let roughStep = (visibleCandles * timeframe.seconds) / targetLabels

        for interval in policy.preferredIntervals where interval >= roughStep * 0.92 {
            return interval
        }

        return policy.preferredIntervals.last ?? timeframe.seconds
    }

    private static func isPrimaryBoundary(_ timestamp: Date, timeframe: RLChartTimeframe, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)

        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            return components.hour == 0 && components.minute == 0
        case .d1:
            return components.day == 1
        case .w1:
            return components.day == 1
        case .mn:
            return components.month == 1
        }
    }

    private static func isTodayBoundaryLabel(
        timestamp: Date,
        timeframe: RLChartTimeframe,
        calendar: Calendar,
        now: Date
    ) -> Bool {
        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            return calendar.isDate(timestamp, equalTo: now, toGranularity: .day)
        case .d1, .w1, .mn:
            return false
        }
    }

    private static func dayKeyForDate(_ timestamp: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: timestamp)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year)-\(month)-\(day)"
    }

    private static func isAlignedToStep(_ timestamp: Date, stepSeconds: TimeInterval, tolerance: TimeInterval) -> Bool {
        guard stepSeconds > 0 else { return false }
        let remainder = timestamp.timeIntervalSince1970.truncatingRemainder(dividingBy: stepSeconds)
        let distance = min(remainder, stepSeconds - remainder)
        return distance <= tolerance
    }

    // MARK: - Visible Day Label

    static func visibleDayLabel(input: Input) -> String {
        guard !input.candles.isEmpty, input.totalCandleWidth > 0 else { return "" }

        let leftmostIndex = max(0, Int(floor(-input.totalOffset / input.totalCandleWidth)))
        let visibleCandleCount = max(1, Int(ceil(input.width / input.totalCandleWidth)))
        let rightmostIndex = min(
            input.candles.count - 1,
            max(leftmostIndex, leftmostIndex + visibleCandleCount - 1)
        )
        guard rightmostIndex < input.candles.count else { return "" }

        // Use the most-recent visible candle day, not the oldest visible candle.
        let timestamp = input.candles[rightmostIndex].timestamp
        var calendar = Calendar.current
        calendar.timeZone = input.timeZone

        switch input.timeframe {
        case .d1, .w1, .mn:
            let formatter = DateFormatter()
            formatter.timeZone = input.timeZone
            formatter.locale = input.locale
            formatter.dateFormat = "dd MMM"
            return formatter.string(from: timestamp)
        default:
            break
        }

        let now = input.now
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: timestamp, to: now).day ?? 999
            if daysAgo >= 2 && daysAgo <= 6 {
                let formatter = DateFormatter()
                formatter.timeZone = input.timeZone
                formatter.locale = input.locale
                formatter.dateFormat = "EEEE"
                return formatter.string(from: timestamp)
            } else {
                let formatter = DateFormatter()
                formatter.timeZone = input.timeZone
                formatter.locale = input.locale
                formatter.dateFormat = "dd MMM"
                return formatter.string(from: timestamp)
            }
        }
    }

    private static func axisPolicy(for timeframe: RLChartTimeframe) -> AxisPolicy {
        switch timeframe {
        case .m1:
            return AxisPolicy(
                preferredIntervals: [300, 600, 900, 1800, 3600, 7200, 14400, 21600, 43200, 86400],
                boundarySpacingBoost: 14
            )
        case .m5:
            return AxisPolicy(
                preferredIntervals: [900, 1800, 3600, 7200, 14400, 21600, 43200, 86400, 172800],
                boundarySpacingBoost: 12
            )
        case .m15:
            return AxisPolicy(
                preferredIntervals: [1800, 3600, 7200, 14400, 21600, 43200, 86400, 172800, 259200],
                boundarySpacingBoost: 12
            )
        case .m30:
            return AxisPolicy(
                preferredIntervals: [3600, 7200, 14400, 21600, 43200, 86400, 172800, 259200, 432000],
                boundarySpacingBoost: 10
            )
        case .h1:
            return AxisPolicy(
                preferredIntervals: [3600, 7200, 14400, 21600, 43200, 86400, 172800, 432000],
                boundarySpacingBoost: 10
            )
        case .h4:
            return AxisPolicy(
                preferredIntervals: [14400, 28800, 43200, 86400, 172800, 259200, 432000, 604800],
                boundarySpacingBoost: 8
            )
        case .d1:
            return AxisPolicy(
                preferredIntervals: [86400, 172800, 432000, 604800, 1209600, 2592000],
                boundarySpacingBoost: 8
            )
        case .w1:
            return AxisPolicy(
                preferredIntervals: [604800, 1209600, 2592000, 5184000, 7776000],
                boundarySpacingBoost: 8
            )
        case .mn:
            return AxisPolicy(
                preferredIntervals: [2592000, 5184000, 7776000, 15552000, 31536000],
                boundarySpacingBoost: 8
            )
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
    var timeZone: TimeZone = .current

    private var timeLabelY: CGFloat {
        let bottomAreaHeight = chartHeight * 0.11
        return chartHeight - bottomAreaHeight - 21
    }

    var body: some View {
        CrosshairTimeLabel(timestamp: timestamp, timeframe: timeframe, timeZone: timeZone)
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
