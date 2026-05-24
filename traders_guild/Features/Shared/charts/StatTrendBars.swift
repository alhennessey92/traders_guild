//
//  StatTrendBars.swift
//  traders_guild
//
//  Date-bucketed BarMark chart used for the 30-day reputation / accuracy
//  trends. Replaces the previously-inline BreakdownDateBarChart while
//  keeping the same visual semantics:
//
//   • centeredBaseline = true  → bars grow above/below a zero baseline,
//     positive points use `point.tint`, negatives are auto-tinted red.
//   • centeredBaseline = false → bars grow upward from zero (used for
//     accuracy where values are always in [0, 1]).
//

import SwiftUI
import Charts

struct StatTrendBarPoint: Identifiable {
    let day: Date
    let value: Double
    let tint: Color
    var id: Date { day }
}

struct StatTrendBars: View {
    let points: [StatTrendBarPoint]
    let centeredBaseline: Bool
    var height: CGFloat = 64
    var emptyMessage: String = "No 30-day trend data"

    var body: some View {
        VStack(spacing: 6) {
            chartArea
                .frame(height: height)
            dateAxisLabels
        }
    }

    @ViewBuilder
    private var chartArea: some View {
        if points.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.symbolDetailCardFill)
                .overlay(
                    Text(emptyMessage)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                )
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.tint)
                .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: yScaleDomain)
            .chartPlotStyle { plot in
                plot.padding(.vertical, 1)
            }
            .overlay(alignment: .center) {
                if centeredBaseline {
                    Rectangle()
                        .fill(AppColors.surfaceWhite12)
                        .frame(height: 0.5)
                }
            }
        }
    }

    private var dateAxisLabels: some View {
        HStack {
            Text(dateLabel(for: points.first?.day))
            Spacer()
            Text(dateLabel(for: points.dropFirst(points.count / 2).first?.day))
            Spacer()
            Text(dateLabel(for: points.last?.day))
        }
        .font(.caption2)
        .foregroundColor(AppColors.greyText.opacity(0.85))
    }

    private var yScaleDomain: ClosedRange<Double> {
        let magnitudes = points.map { abs($0.value) }
        let maxMag = max(magnitudes.max() ?? 1, 0.0001)
        if centeredBaseline {
            return -maxMag...maxMag
        }
        let maxVal = max(points.map(\.value).max() ?? 0, 0.0001)
        return 0...maxVal
    }

    private func dateLabel(for date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
