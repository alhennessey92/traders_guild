//
//  PanelGridHelper.swift
//  traders_guild
//
//  Draws vertical grid lines inside indicator panels to match the main chart grid.
//

import SwiftUI

enum PanelGridHelper {
    /// Draw vertical grid lines matching the main chart's grid alignment.
    static func drawVerticalGridLines(
        context: GraphicsContext,
        size: CGSize,
        candles: [RLCandleDTO],
        timeframe: RLChartTimeframe,
        totalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat
    ) {
        let settings = ChartSettings.shared
        guard settings.showGridLines else { return }

        let labels = ChartXAxisLabelEngine.makeLabels(
            input: .init(
                candles: candles,
                timeframe: timeframe,
                totalOffset: totalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                width: size.width,
                timeZone: .current,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 60
            )
        )

        let opacity = settings.gridOpacity

        var majorPath = Path()
        var minorPath = Path()

        for label in labels {
            if label.x >= -100 && label.x <= size.width + 100 {
                if label.kind == .primary {
                    majorPath.move(to: CGPoint(x: label.x, y: 0))
                    majorPath.addLine(to: CGPoint(x: label.x, y: size.height))
                } else {
                    minorPath.move(to: CGPoint(x: label.x, y: 0))
                    minorPath.addLine(to: CGPoint(x: label.x, y: size.height))
                }
            }
        }

        context.stroke(minorPath, with: .color(.gray.opacity(opacity * 0.9)), lineWidth: 0.45)
        context.stroke(majorPath, with: .color(.gray.opacity(min(opacity * 1.7, 1.0))), lineWidth: 0.6)
    }
}
