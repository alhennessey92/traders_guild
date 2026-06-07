//
//  MiniLineChart.swift
//  traders_guild
//
//  Compact price line for the symbol detail panel. Unlike StatSparkline (which
//  uses an AreaMark and therefore pins the Y-axis to zero — flattening a
//  high-priced series like 60,000–65,000 into a sliver at the top), this scales
//  to the series' own min/max so real peaks and troughs fill the full height.
//

import SwiftUI

struct MiniLineChart: View {
    let values: [Double]
    var tint: Color
    var height: CGFloat = 92

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                areaPath(pts, height: geo.size.height)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.30), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                linePath(pts)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(height: height)
    }

    /// Map values to points, normalising y to the series' own min/max so the line
    /// uses the full available height regardless of absolute price magnitude.
    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, .ulpOfOne)
        let stepX = size.width / CGFloat(values.count - 1)
        // Inset slightly so the stroke isn't clipped at the very top/bottom edges.
        let inset: CGFloat = 2
        let usableHeight = max(size.height - inset * 2, 1)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let y = inset + usableHeight * (1 - CGFloat((value - minValue) / range))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func areaPath(_ pts: [CGPoint], height: CGFloat) -> Path {
        var path = Path()
        guard let first = pts.first, let last = pts.last else { return path }
        path.move(to: CGPoint(x: first.x, y: height))
        path.addLine(to: first)
        for point in pts.dropFirst() { path.addLine(to: point) }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.closeSubpath()
        return path
    }
}
