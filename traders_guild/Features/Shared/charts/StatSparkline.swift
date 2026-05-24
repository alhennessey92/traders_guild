//
//  StatSparkline.swift
//  traders_guild
//
//  Tiny line-and-area chart used inline inside StatKPITile and elsewhere on
//  the dashboards. Renders a flat baseline placeholder when fewer than two
//  data points are available so the layout never collapses.
//

import SwiftUI
import Charts

struct StatSparkline: View {
    let values: [Double]
    let tint: Color
    var height: CGFloat = 32

    init(values: [Double], tint: Color, height: CGFloat = 32) {
        self.values = values
        self.tint = tint
        self.height = height
    }

    /// Convenience initialiser that maps a series of (Date, value) points.
    init<T>(points: [T], value: (T) -> Double, tint: Color, height: CGFloat = 32) {
        self.values = points.map(value)
        self.tint = tint
        self.height = height
    }

    var body: some View {
        Group {
            if values.count < 2 {
                placeholder
            } else {
                chart
            }
        }
        .frame(height: height)
    }

    private var chart: some View {
        let indexed = values.enumerated().map { (index, value) in
            SparklinePoint(index: index, value: value)
        }
        let gradient = LinearGradient(
            colors: [tint.opacity(0.45), tint.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )

        return Chart(indexed) { point in
            AreaMark(
                x: .value("Index", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(gradient)
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Index", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.vertical, 2)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppColors.symbolDetailCardFill)
            .overlay(
                Rectangle()
                    .fill(tint.opacity(0.35))
                    .frame(height: 1)
            )
    }
}

private struct SparklinePoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}
