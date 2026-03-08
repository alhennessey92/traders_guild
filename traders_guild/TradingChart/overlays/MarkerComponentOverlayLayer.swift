import SwiftUI

/// Renders a marker's components (levels, trendlines, zones) as temporary overlays
/// on the chart when a marker is selected and its detail view is open.
/// Uses solid lines (not dashed like GhostPreviewLayer) to differentiate from placement preview.
struct MarkerComponentOverlayLayer: View {
    let components: [RLMarkerComponentDTO]
    let yForPrice: (Double) -> CGFloat?
    let width: CGFloat
    let xForTime: ((Date) -> CGFloat?)?
    var formatPrice: ((Double) -> String)?

    var body: some View {
        Canvas { context, size in
            drawTrendlines(context: context)
            drawZones(context: context)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Computed Helpers

    private var trendlineComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingTrendline }
    }

    private var zoneComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum == .drawingZone }
    }

    // MARK: - Canvas Drawing

    private func drawTrendlines(context: GraphicsContext) {
        for component in trendlineComponents {
            guard case let .drawingTrendline(payload) = component.payload else { continue }
            guard let startY = yForPrice(payload.startPrice),
                  let endY = yForPrice(payload.endPrice) else { continue }

            let startX = xForTime?(payload.startTime) ?? width * 0.2
            let endX = xForTime?(payload.endTime) ?? width * 0.8

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(
                path,
                with: .color(RLComponentType.drawingTrendline.color.opacity(0.7)),
                style: StrokeStyle(lineWidth: 1.8)
            )
        }
    }

    private func drawZones(context: GraphicsContext) {
        for component in zoneComponents {
            guard case let .drawingZone(payload) = component.payload else { continue }
            guard let topY = yForPrice(payload.topPrice),
                  let bottomY = yForPrice(payload.bottomPrice) else { continue }

            let startX = (payload.startTime.flatMap { xForTime?($0) }) ?? width * 0.2
            let endX = (payload.endTime.flatMap { xForTime?($0) }) ?? width * 0.8
            let rect = CGRect(
                x: min(startX, endX),
                y: min(topY, bottomY),
                width: abs(endX - startX),
                height: max(2, abs(bottomY - topY))
            )

            context.fill(Path(rect), with: .color(RLComponentType.drawingZone.color.opacity(0.15)))
            context.stroke(
                Path(rect),
                with: .color(RLComponentType.drawingZone.color.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1.2)
            )
        }
    }
}
