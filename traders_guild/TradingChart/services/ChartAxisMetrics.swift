import CoreGraphics

enum ChartAxisMetrics {
    static let yAxisLaneWidth: CGFloat = 59

    static let horizontalPriceChipHeight: CGFloat = 24
    static let horizontalPriceChipHorizontalPadding: CGFloat = 6
    static let horizontalPriceChipVerticalPadding: CGFloat = 3
    static let horizontalPriceChipCornerRadius: CGFloat = 4
    static let horizontalLabelFontSize: CGFloat = 10
    static let horizontalPriceFontSize: CGFloat = 11
    static let horizontalChipTrailingInset: CGFloat = 6
    static let horizontalLabeledChipWidth: CGFloat = 100

    static let currentPriceChipWidth: CGFloat = 76
    static let directionalPriceChipWidth: CGFloat = 94
    static let directionalArrowChipWidth: CGFloat = 36
    static let directionalArrowChipHeight: CGFloat = 28
    static let currentPriceChipHeight: CGFloat = 24

    static func plotWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth - yAxisLaneWidth)
    }

    static func horizontalLineEndX(totalWidth: CGFloat, labelWidth: CGFloat? = nil) -> CGFloat {
        guard let labelWidth else {
            return plotWidth(totalWidth: totalWidth)
        }
        return trailingLabelMaxX(totalWidth: totalWidth, width: labelWidth)
    }

    static func yAxisLaneCenterX(totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth - (yAxisLaneWidth * 0.5))
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
}
