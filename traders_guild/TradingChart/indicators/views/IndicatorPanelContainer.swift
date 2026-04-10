//
//  IndicatorPanelContainer.swift
//  traders_guild
//
//  Container view that manages stacked indicator panels
//  Supports: RSI, MACD, Stochastic, CCI, Williams %R, ATR, Volume
//

import SwiftUI

struct IndicatorPanelContainer: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    @ObservedObject var viewportStore: IndicatorPanelViewportStore
    
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var timeframe: RLChartTimeframe = .h1
    var timeframePanelCount: Int = 0
    
    @Binding var rsiPanelHeight: CGFloat
    @Binding var macdPanelHeight: CGFloat
    @Binding var stochasticPanelHeight: CGFloat
    @Binding var cciPanelHeight: CGFloat
    @Binding var williamsRPanelHeight: CGFloat
    @Binding var atrPanelHeight: CGFloat
    @Binding var volumePanelHeight: CGFloat
    @Binding var rsiPanelExpandedHeight: CGFloat
    @Binding var macdPanelExpandedHeight: CGFloat
    @Binding var stochasticPanelExpandedHeight: CGFloat
    @Binding var cciPanelExpandedHeight: CGFloat
    @Binding var williamsRPanelExpandedHeight: CGFloat
    @Binding var atrPanelExpandedHeight: CGFloat
    @Binding var volumePanelExpandedHeight: CGFloat
    
    // MARK: - Computed Properties
    
    private var activePanelTypes: [PanelIndicatorType] {
        indicatorManager.activeIndicators.activePanelTypes
    }
    
    private var activePanelCount: Int {
        activePanelTypes.count
    }
    
    private var hasActivePanels: Bool {
        !activePanelTypes.isEmpty
    }
    
    private var adjustedMaxHeight: CGFloat {
        let totalPanels = activePanelCount + timeframePanelCount
        if totalPanels >= 3 {
            return 140
        } else if totalPanels >= 2 {
            return IndicatorManager.maxPanelHeightWith2Panels
        }
        return IndicatorManager.maxPanelHeight
    }
    
    // MARK: - Body
    
    var body: some View {
        if hasActivePanels {
            VStack(spacing: 0) {
                ForEach(Array(activePanelTypes.enumerated()), id: \.element) { _, panelType in
                    panelView(for: panelType)
                }
            }
        }
    }
    
    // MARK: - Panel Views
    
    @ViewBuilder
    private func panelView(for type: PanelIndicatorType) -> some View {
        switch type {
        case .rsi:
            RSIPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .rsi),
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $rsiPanelHeight,
                expandedPanelHeight: $rsiPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .macd:
            MACDPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .macd),
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $macdPanelHeight,
                expandedPanelHeight: $macdPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .stochastic:
            StochasticPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .stochastic),
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $stochasticPanelHeight,
                expandedPanelHeight: $stochasticPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .cci:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .cci),
                panelType: .cci,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $cciPanelHeight,
                expandedPanelHeight: $cciPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .williamsR:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .williamsR),
                panelType: .williamsR,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $williamsRPanelHeight,
                expandedPanelHeight: $williamsRPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .atr:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .atr),
                panelType: .atr,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $atrPanelHeight,
                expandedPanelHeight: $atrPanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
            
        case .volume:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                viewportState: viewportStore.state(for: .volume),
                panelType: .volume,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $volumePanelHeight,
                expandedPanelHeight: $volumePanelExpandedHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight
            )
        }
    }
    
    // MARK: - Height Calculations

    private func panelHeight(for panelType: PanelIndicatorType) -> CGFloat {
        switch panelType {
        case .rsi:
            return rsiPanelHeight
        case .macd:
            return macdPanelHeight
        case .stochastic:
            return stochasticPanelHeight
        case .cci:
            return cciPanelHeight
        case .williamsR:
            return williamsRPanelHeight
        case .atr:
            return atrPanelHeight
        case .volume:
            return volumePanelHeight
        }
    }
    
    var totalPanelHeight: CGFloat {
        let panelHeights = activePanelTypes.map(panelHeight(for:))
        let handlesReserve = CGFloat(panelHeights.count) * ChartPanelReserveCalculator.panelResizeHandleHeight
        let expandedContentReserve = panelHeights
            .map { max(0, $0) }
            .filter { !ChartPanelReserveCalculator.isCollapsedPanelHeight($0) }
            .reduce(0, +)
        return handlesReserve + expandedContentReserve
    }
}
