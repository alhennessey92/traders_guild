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
        activePanelCount > 1
            ? IndicatorManager.maxPanelHeightWith2Panels
            : IndicatorManager.maxPanelHeight
    }
    
    // MARK: - Body
    
    var body: some View {
        if hasActivePanels {
            VStack(spacing: 0) {
                ForEach(Array(activePanelTypes.enumerated()), id: \.element) { index, panelType in
                    panelView(for: panelType, isBottomPanel: index == activePanelTypes.count - 1)
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
    
    var totalPanelHeight: CGFloat {
        var total: CGFloat = 0
        
        for panelType in activePanelTypes {
            switch panelType {
            case .rsi:
                total += rsiPanelHeight + 22
            case .macd:
                total += macdPanelHeight + 22
            case .stochastic:
                total += stochasticPanelHeight + 22
            case .cci:
                total += cciPanelHeight + 22
            case .williamsR:
                total += williamsRPanelHeight + 22
            case .atr:
                total += atrPanelHeight + 22
            case .volume:
                total += volumePanelHeight + 22
            }
        }

        if hasActivePanels {
            total += 22 // X-axis labels on bottom indicator panel
        }
        
        return total
    }
}
