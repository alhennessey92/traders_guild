//
//  ActiveIndicatorsLegendView.swift
//  traders_guild
//
//  Shows active overlay indicators on the chart with colors and settings
//  Displayed below symbol/price in top-left corner
//

import SwiftUI

struct ActiveIndicatorsLegendView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    
    var body: some View {
        if hasActiveOverlayIndicators {
            VStack(alignment: .leading, spacing: 2) {
                // Moving Averages
                ForEach(activeMovingAverages) { ma in
                    legendItem(
                        color: ma.color.color,
                        text: ma.label
                    )
                }
                
                // VWAP
                if let vwap = indicatorManager.activeIndicators.vwap, vwap.isEnabled {
                    legendItem(
                        color: vwap.color.color,
                        text: vwap.showStandardDeviationBands ? "VWAP ±σ" : "VWAP"
                    )
                }
                
                // Parabolic SAR
                if let sar = indicatorManager.activeIndicators.parabolicSAR, sar.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(sar.bullishColor.color)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(sar.bearishColor.color)
                            .frame(width: 6, height: 6)
                        Text("SAR")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Bollinger Bands
                if let bb = indicatorManager.activeIndicators.bollingerBands, bb.isEnabled {
                    legendItem(
                        color: bb.color.color,
                        text: "BB(\(bb.period), \(String(format: "%.1f", bb.standardDeviations))σ)"
                    )
                }
                
                // Donchian Channels
                if let dc = indicatorManager.activeIndicators.donchianChannels, dc.isEnabled {
                    legendItem(
                        color: dc.upperBandColor.color,
                        text: "DC(\(dc.period))"
                    )
                }
                
                // Keltner Channels
                if let kc = indicatorManager.activeIndicators.keltnerChannels, kc.isEnabled {
                    legendItem(
                        color: kc.color.color,
                        text: "KC(\(kc.emaPeriod), \(kc.atrPeriod))"
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.4))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Helper Views
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 2)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeMovingAverages: [MovingAverageConfig] {
        indicatorManager.activeIndicators.movingAverages.filter { $0.isEnabled }
    }
    
    private var hasActiveOverlayIndicators: Bool {
        // Check if any overlay indicator is active
        !activeMovingAverages.isEmpty ||
        (indicatorManager.activeIndicators.vwap?.isEnabled == true) ||
        (indicatorManager.activeIndicators.parabolicSAR?.isEnabled == true) ||
        (indicatorManager.activeIndicators.bollingerBands?.isEnabled == true) ||
        (indicatorManager.activeIndicators.donchianChannels?.isEnabled == true) ||
        (indicatorManager.activeIndicators.keltnerChannels?.isEnabled == true)
    }
}

// MARK: - Compact Version (for tighter spaces)

struct ActiveIndicatorsLegendCompactView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    
    var body: some View {
        if hasActiveOverlayIndicators {
            HStack(spacing: 8) {
                ForEach(legendItems, id: \.text) { item in
                    HStack(spacing: 3) {
                        if item.isDot {
                            Circle()
                                .fill(item.color)
                                .frame(width: 5, height: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(item.color)
                                .frame(width: 10, height: 2)
                        }
                        Text(item.text)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
        }
    }
    
    private struct LegendItem: Hashable {
        let color: Color
        let text: String
        let isDot: Bool
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
        }
        
        static func == (lhs: LegendItem, rhs: LegendItem) -> Bool {
            lhs.text == rhs.text
        }
    }
    
    private var legendItems: [LegendItem] {
        var items: [LegendItem] = []
        
        // Moving Averages
        for ma in indicatorManager.activeIndicators.movingAverages where ma.isEnabled {
            items.append(LegendItem(color: ma.color.color, text: "\(ma.type.shortName)\(ma.period)", isDot: false))
        }
        
        // VWAP
        if let vwap = indicatorManager.activeIndicators.vwap, vwap.isEnabled {
            items.append(LegendItem(color: vwap.color.color, text: "VWAP", isDot: false))
        }
        
        // Parabolic SAR
        if let sar = indicatorManager.activeIndicators.parabolicSAR, sar.isEnabled {
            items.append(LegendItem(color: sar.bullishColor.color, text: "SAR", isDot: true))
        }
        
        // Bollinger Bands
        if let bb = indicatorManager.activeIndicators.bollingerBands, bb.isEnabled {
            items.append(LegendItem(color: bb.color.color, text: "BB\(bb.period)", isDot: false))
        }
        
        // Donchian Channels
        if let dc = indicatorManager.activeIndicators.donchianChannels, dc.isEnabled {
            items.append(LegendItem(color: dc.upperBandColor.color, text: "DC\(dc.period)", isDot: false))
        }
        
        // Keltner Channels
        if let kc = indicatorManager.activeIndicators.keltnerChannels, kc.isEnabled {
            items.append(LegendItem(color: kc.color.color, text: "KC\(kc.emaPeriod)", isDot: false))
        }
        
        return items
    }
    
    private var hasActiveOverlayIndicators: Bool {
        !legendItems.isEmpty
    }
}
