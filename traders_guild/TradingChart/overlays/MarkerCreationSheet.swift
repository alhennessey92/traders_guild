import SwiftUI

/// Backwards-compatible entry point that now delegates to the v2 composer.
/// Keep this type while remaining call sites are migrated.
@available(*, deprecated, message: "Use the inline placement flow in TradingChartView/MainView.")
struct MarkerCreationSheet: View {
    @ObservedObject var markerManager: MarkerManager
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let username: String
    let chartData: ChartDataManager
    let candles: [RLCandleDTO]
    let markerIntent: RLMarkerIntent
    let initialTargetPrice: Double?
    let initialHorizontalLinePrice: Double?
    let initialStopLossPrice: Double?
    @Binding var placementAlertSeverity: MarkerAlertSeverity?
    @Binding var placementSelectedEmoji: String?

    var body: some View {
        MarkerComposerSheet(
            markerManager: markerManager,
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            chartData: chartData,
            candles: candles,
            markerIntent: markerIntent,
            initialTargetPrice: initialTargetPrice,
            initialHorizontalLinePrice: initialHorizontalLinePrice,
            initialStopLossPrice: initialStopLossPrice
        )
    }
}

/// Legacy marker settings panel has been replaced by intent/component controls.
struct MarkerSettingsView: View {
    var body: some View {
        Text("Marker settings moved to Composer")
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            .padding(12)
    }
}
