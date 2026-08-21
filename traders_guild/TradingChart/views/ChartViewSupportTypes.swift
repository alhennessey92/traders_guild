//
//  ChartViewSupportTypes.swift — small value types and label helpers the chart draws with
//
//  Split out of TradingChartView.swift, which was 9,744 lines in one file.
//  Pure file movement: no declaration was reordered, renamed or edited, beyond
//  widening file-scope `private` to internal where a type is now referenced
//  across the split. `private` is file-scoped in Swift, so that widening is
//  forced by the move — it is not a design change.
//

import SwiftUI


import SwiftUI

func compactHorizontalPriceLabel(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    switch trimmed.lowercased() {
    case "support":
        return "Sup"
    case "resistance":
        return "Res"
    default:
        return trimmed
    }
}

func secondaryPriceChipText(label: String, priceText: String) -> Text {
    (
        Text("\(compactHorizontalPriceLabel(label)) ")
            .font(.system(size: ChartAxisMetrics.secondaryLabelFontSize, weight: .bold, design: .monospaced))
            .foregroundColor(AppColors.onAccentForeground)
        +
        Text(priceText)
            .font(.system(size: ChartAxisMetrics.secondaryPriceFontSize, weight: .semibold, design: .monospaced))
            .foregroundColor(AppColors.onAccentForeground)
    )
}

func setupCorePriceLabelText(label: String, priceText: String) -> Text {
    secondaryPriceChipText(label: label, priceText: priceText)
}

struct SecondaryPriceChipPatternOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 5
                var startX = -geometry.size.height
                while startX <= geometry.size.width + geometry.size.height {
                    path.move(to: CGPoint(x: startX, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: startX + geometry.size.height, y: 0))
                    startX += spacing
                }
            }
            .stroke(.white.opacity(0.14), lineWidth: 0.7)
        }
    }
}

struct SecondaryPriceChipView: View {
    let label: String
    let priceText: String
    let color: Color
    var showsPattern: Bool = false

    var body: some View {
        secondaryPriceChipText(label: label, priceText: priceText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, ChartAxisMetrics.secondaryPriceChipHorizontalPadding)
            .padding(.vertical, ChartAxisMetrics.secondaryPriceChipVerticalPadding)
            .frame(
                width: ChartAxisMetrics.secondaryPriceChipWidth,
                height: ChartAxisMetrics.secondaryPriceChipHeight
            )
            .background(color.opacity(0.85))
            .clipShape(
                RoundedRectangle(cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
            )
            .overlay {
                if showsPattern {
                    SecondaryPriceChipPatternOverlay()
                        .clipShape(
                            RoundedRectangle(cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
                        )
                }
            }
    }
}

typealias SetupCorePriceChipView = SecondaryPriceChipView

// MARK: - Prediction Placement State

/// Tracks the state of the prediction marker placement flow (3-line system)
struct PredictionPlacementState: Equatable {
    var entryPrice: Double
    var takeProfitPrice: Double
    var stopLossPrice: Double
    var candleIndex: Int

    /// Auto-detect direction from TP position relative to entry
    var isLong: Bool { takeProfitPrice > entryPrice }

    var riskRewardRatio: Double {
        let reward = abs(takeProfitPrice - entryPrice)
        let risk = abs(stopLossPrice - entryPrice)
        guard risk > 0 else { return 0 }
        return reward / risk
    }

    var potentialProfitPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return abs(takeProfitPrice - entryPrice) / entryPrice * 100
    }

    var potentialLossPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return abs(stopLossPrice - entryPrice) / entryPrice * 100
    }
}

/// Which prediction line is currently being dragged
enum PredictionLineType {
    case entry
    case takeProfit
    case stopLoss
}

// MARK: - Pending Marker Info

/// FIXED: Captures marker type at placement time to prevent sheet presentation errors
/// Now Identifiable to support sheet(item:) binding for more robust presentation
struct PendingMarkerInfo: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let markerIntent: RLMarkerIntent
    let targetPrice: Double?
    let horizontalLinePrice: Double?
    let stopLossPrice: Double?

    init(candleIndex: Int, timestamp: Date, price: Double, markerIntent: RLMarkerIntent, targetPrice: Double? = nil, horizontalLinePrice: Double? = nil, stopLossPrice: Double? = nil) {
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.markerIntent = markerIntent
        self.targetPrice = targetPrice
        self.horizontalLinePrice = horizontalLinePrice
        self.stopLossPrice = stopLossPrice
    }
}

struct PreviewPriceLine {
    let candle: RLCandleDTO
    let intent: RLMarkerIntent
    let color: Color
    let label: String?
    let explicitPrice: Double?
}

struct DrawingTextEditorContext: Identifiable {
    enum Kind: Equatable {
        case lineLabel
        case levelLabel
        case note
        case emoji
    }

    let id = UUID()
    let draftId: UUID
    let title: String
    let placeholder: String
    let initialValue: String
    let kind: Kind
}

/// Clips to a fixed rect in the view's own coordinate space.
///
/// Exists so chart layers that only ever needed a rectangular cut-out can use `.clipShape` instead
/// of `.mask`. `.mask` renders its content to an offscreen buffer and alpha-composites every frame;
/// for an opaque rectangle that work buys nothing.
struct FixedRectClip: Shape {
    let rect: CGRect
    func path(in _: CGRect) -> Path { Path(rect) }
}

struct HorizontalAxisPriceLabelItem: Identifiable {
    let id: String
    let text: String
    let price: Double
    let color: Color
}

/// Main trading chart view that handles all chart rendering and interactions
/// Features centered scaling that keeps visible candles in view during zoom
/// Includes marker placement system for collaborative chart annotations
