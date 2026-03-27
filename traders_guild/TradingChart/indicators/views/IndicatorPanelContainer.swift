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
    
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var timeframe: RLChartTimeframe = .h1
    var timeframePanelCount: Int = 0
    var bottomAxisPanelIndex: Int? = nil
    
    @Binding var rsiPanelHeight: CGFloat
    @Binding var macdPanelHeight: CGFloat
    @Binding var stochasticPanelHeight: CGFloat
    @Binding var cciPanelHeight: CGFloat
    @Binding var williamsRPanelHeight: CGFloat
    @Binding var atrPanelHeight: CGFloat
    @Binding var volumePanelHeight: CGFloat
    
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
                ForEach(Array(activePanelTypes.enumerated()), id: \.element) { index, panelType in
                    panelView(for: panelType, isBottomPanel: bottomAxisPanelIndex == index)
                }
            }
        }
    }
    
    // MARK: - Panel Views
    
    @ViewBuilder
    private func panelView(for type: PanelIndicatorType, isBottomPanel: Bool) -> some View {
        switch type {
        case .rsi:
            RSIPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $rsiPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .macd:
            MACDPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $macdPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .stochastic:
            StochasticPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $stochasticPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .cci:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                panelType: .cci,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $cciPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .williamsR:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                panelType: .williamsR,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $williamsRPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .atr:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                panelType: .atr,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $atrPanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
            )
            
        case .volume:
            GenericIndicatorPanelView(
                indicatorManager: indicatorManager,
                chartData: chartData,
                gestureState: gestureState,
                panelType: .volume,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                timeframe: timeframe,
                panelHeight: $volumePanelHeight,
                minPanelHeight: IndicatorManager.minPanelHeight,
                maxPanelHeight: adjustedMaxHeight,
                isBottomPanel: isBottomPanel
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
        ChartPanelReserveCalculator.stackReserve(
            panelHeights: activePanelTypes.map(panelHeight(for:))
        )
    }
}
