import CoreGraphics

enum ChartAxisMetrics {
    static let yAxisLaneWidth: CGFloat = 64
    static let indicatorPanelYAxisLaneWidth: CGFloat = 44
    static let indicatorPanelYAxisLabelWidth: CGFloat = 40
    static let indicatorPanelYAxisLabelFontSize: CGFloat = 10

    static let horizontalPriceChipHeight: CGFloat = 24
    static let horizontalPriceChipHorizontalPadding: CGFloat = 6
    static let horizontalPriceChipVerticalPadding: CGFloat = 3
    static let horizontalPriceChipCornerRadius: CGFloat = 4
    static let horizontalLabelFontSize: CGFloat = 10
    static let horizontalPriceFontSize: CGFloat = 11
    static let horizontalChipTrailingInset: CGFloat = 6
    static let horizontalLabeledChipWidth: CGFloat = 100

    static let secondaryPriceChipWidth: CGFloat = 90
    static let secondaryPriceChipHeight: CGFloat = 22
    static let secondaryPriceChipHorizontalPadding: CGFloat = 4
    static let secondaryPriceChipVerticalPadding: CGFloat = 2
    static let secondaryLabelFontSize: CGFloat = 9
    static let secondaryPriceFontSize: CGFloat = 10

    static let setupCorePriceChipWidth: CGFloat = secondaryPriceChipWidth
    static let setupCorePriceChipHeight: CGFloat = secondaryPriceChipHeight
    static let setupCorePriceChipHorizontalPadding: CGFloat = secondaryPriceChipHorizontalPadding
    static let setupCorePriceChipVerticalPadding: CGFloat = secondaryPriceChipVerticalPadding
    static let setupCoreLabelFontSize: CGFloat = secondaryLabelFontSize
    static let setupCorePriceFontSize: CGFloat = secondaryPriceFontSize

    static let currentPriceChipWidth: CGFloat = 66
    static let directionalPriceChipWidth: CGFloat = 94
    static let directionalArrowChipWidth: CGFloat = 36
    static let directionalArrowChipHeight: CGFloat = 28
    static let currentPriceChipHeight: CGFloat = 24

    static func plotWidth(totalWidth: CGFloat, axisLaneWidth: CGFloat = yAxisLaneWidth) -> CGFloat {
        max(0, totalWidth - axisLaneWidth)
    }

    static func horizontalLineEndX(totalWidth: CGFloat, labelWidth: CGFloat? = nil) -> CGFloat {
        guard let labelWidth else {
            return plotWidth(totalWidth: totalWidth)
        }
        return trailingLabelMaxX(totalWidth: totalWidth, width: labelWidth)
    }

    static func yAxisLaneCenterX(totalWidth: CGFloat, axisLaneWidth: CGFloat = yAxisLaneWidth) -> CGFloat {
        max(0, totalWidth - (axisLaneWidth * 0.5))
    }

    static func trailingLabelMinX(totalWidth: CGFloat, width: CGFloat) -> CGFloat {
        max(0, totalWidth - width - horizontalChipTrailingInset)
    }

    static func trailingLabelCenterX(totalWidth: CGFloat, width: CGFloat) -> CGFloat {
        trailingLabelMinX(totalWidth: totalWidth, width: width) + (width * 0.5)
    }

    static func trailingLabelMaxX(totalWidth: CGFloat, width: CGFloat) -> CGFloat {
        trailingLabelMinX(totalWidth: totalWidth, width: width) + width
    }

    static func labelRect(
        totalWidth: CGFloat,
        centerY: CGFloat,
        width: CGFloat,
        height: CGFloat = horizontalPriceChipHeight
    ) -> CGRect {
        return CGRect(
            x: trailingLabelMinX(totalWidth: totalWidth, width: width),
            y: centerY - (height * 0.5),
            width: width,
            height: height
        )
    }

    static func setupCoreLabelRect(totalWidth: CGFloat, centerY: CGFloat) -> CGRect {
        labelRect(
            totalWidth: totalWidth,
            centerY: centerY,
            width: setupCorePriceChipWidth,
            height: setupCorePriceChipHeight
        )
    }

    static func secondaryLabelRect(totalWidth: CGFloat, centerY: CGFloat) -> CGRect {
        labelRect(
            totalWidth: totalWidth,
            centerY: centerY,
            width: secondaryPriceChipWidth,
            height: secondaryPriceChipHeight
        )
    }
}

struct SetupCorePriceLineLayout {
    let renderWidth: CGFloat
    let plotWidth: CGFloat

    init(renderWidth: CGFloat, plotWidth: CGFloat? = nil) {
        let resolvedRenderWidth = max(0, renderWidth)
        self.renderWidth = resolvedRenderWidth
        self.plotWidth = max(0, plotWidth ?? ChartAxisMetrics.plotWidth(totalWidth: resolvedRenderWidth))
    }

    var labelWidth: CGFloat { ChartAxisMetrics.setupCorePriceChipWidth }
    var lineEndX: CGFloat { ChartAxisMetrics.trailingLabelMaxX(totalWidth: renderWidth, width: labelWidth) }
    var fillWidth: CGFloat { lineEndX }
    var labelCenterX: CGFloat { ChartAxisMetrics.trailingLabelCenterX(totalWidth: renderWidth, width: labelWidth) }
    var plotHandleCenterX: CGFloat { plotWidth * 0.5 }

    func labelRect(centerY: CGFloat) -> CGRect {
        ChartAxisMetrics.setupCoreLabelRect(totalWidth: renderWidth, centerY: centerY)
    }
}
