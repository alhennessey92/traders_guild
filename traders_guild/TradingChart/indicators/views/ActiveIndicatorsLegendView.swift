//
//  ActiveIndicatorsLegendView.swift
//  traders_guild
//
//  Shows active overlay and panel indicators in the chart info box.
//

import SwiftUI

enum ActiveIndicatorLegendKind {
    case overlay
    case panel
}

struct ActiveIndicatorLegendEntry: Identifiable {
    let id: String
    let text: String
    let primaryColor: Color
    let secondaryColor: Color?
    let kind: ActiveIndicatorLegendKind
}

enum ActiveIndicatorsLegendComposer {
    static func entries(from active: ActiveIndicators) -> [ActiveIndicatorLegendEntry] {
        var entries: [ActiveIndicatorLegendEntry] = []

        for ma in active.enabledMovingAverages {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "ma-\(ma.id.uuidString)",
                    text: ma.label,
                    primaryColor: ma.color.color,
                    secondaryColor: nil,
                    kind: .overlay
                )
            )
        }

        if let vwap = active.vwap, vwap.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "vwap-\(vwap.id.uuidString)",
                    text: vwap.showStandardDeviationBands ? "VWAP ±σ" : "VWAP",
                    primaryColor: vwap.color.color,
                    secondaryColor: nil,
                    kind: .overlay
                )
            )
        }

        if let sar = active.parabolicSAR, sar.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "sar-\(sar.id.uuidString)",
                    text: "SAR",
                    primaryColor: sar.bullishColor.color,
                    secondaryColor: sar.bearishColor.color,
                    kind: .overlay
                )
            )
        }

        if let bb = active.bollingerBands, bb.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "bb-\(bb.id.uuidString)",
                    text: "BB(\(bb.period), \(String(format: "%.1f", bb.standardDeviations))σ)",
                    primaryColor: bb.color.color,
                    secondaryColor: nil,
                    kind: .overlay
                )
            )
        }

        if let dc = active.donchianChannels, dc.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "dc-\(dc.id.uuidString)",
                    text: "DC(\(dc.period))",
                    primaryColor: dc.upperBandColor.color,
                    secondaryColor: nil,
                    kind: .overlay
                )
            )
        }

        if let kc = active.keltnerChannels, kc.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "kc-\(kc.id.uuidString)",
                    text: "KC(\(kc.emaPeriod), \(kc.atrPeriod))",
                    primaryColor: kc.color.color,
                    secondaryColor: nil,
                    kind: .overlay
                )
            )
        }

        if let rsi = active.rsi, rsi.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "rsi-\(rsi.id.uuidString)",
                    text: "RSI(\(rsi.period))",
                    primaryColor: rsi.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let macd = active.macd, macd.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "macd-\(macd.id.uuidString)",
                    text: "MACD(\(macd.fastPeriod),\(macd.slowPeriod),\(macd.signalPeriod))",
                    primaryColor: macd.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let stochastic = active.stochastic, stochastic.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "stoch-\(stochastic.id.uuidString)",
                    text: "Stoch(\(stochastic.kPeriod),\(stochastic.dPeriod))",
                    primaryColor: stochastic.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let cci = active.cci, cci.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "cci-\(cci.id.uuidString)",
                    text: "CCI(\(cci.period))",
                    primaryColor: cci.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let williamsR = active.williamsR, williamsR.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "wpr-\(williamsR.id.uuidString)",
                    text: "W%R(\(williamsR.period))",
                    primaryColor: williamsR.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let atr = active.atr, atr.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "atr-\(atr.id.uuidString)",
                    text: "ATR(\(atr.period))",
                    primaryColor: atr.color.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        if let volume = active.volume, volume.isEnabled {
            entries.append(
                ActiveIndicatorLegendEntry(
                    id: "vol-\(volume.id.uuidString)",
                    text: volume.showMA ? "VOL(MA\(volume.maPeriod))" : "VOL",
                    primaryColor: volume.bullishColor.color,
                    secondaryColor: nil,
                    kind: .panel
                )
            )
        }

        return entries
    }

    static func labels(from active: ActiveIndicators) -> [String] {
        entries(from: active).map(\.text)
    }

}

struct ActiveIndicatorsLegendView: View {
    @ObservedObject var indicatorManager: IndicatorManager

    private var legendEntries: [ActiveIndicatorLegendEntry] {
        ActiveIndicatorsLegendComposer.entries(from: indicatorManager.activeIndicators)
    }

    var body: some View {
        if !legendEntries.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(legendEntries) { entry in
                    legendItem(entry)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.surfaceBlack40)
            .cornerRadius(6)
        }
    }

    private func legendItem(_ entry: ActiveIndicatorLegendEntry) -> some View {
        HStack(spacing: 4) {
            if let secondaryColor = entry.secondaryColor {
                Circle()
                    .fill(entry.primaryColor)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(secondaryColor)
                    .frame(width: 6, height: 6)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(entry.primaryColor)
                    .frame(width: 12, height: 2)
            }

            Text(entry.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite80)
        }
    }
}

// MARK: - Compact Version (for tighter spaces)

struct ActiveIndicatorsLegendCompactView: View {
    @ObservedObject var indicatorManager: IndicatorManager

    private var legendEntries: [ActiveIndicatorLegendEntry] {
        ActiveIndicatorsLegendComposer.entries(from: indicatorManager.activeIndicators)
    }

    var body: some View {
        if !legendEntries.isEmpty {
            HStack(spacing: 8) {
                ForEach(legendEntries) { entry in
                    HStack(spacing: 3) {
                        if entry.secondaryColor != nil {
                            Circle()
                                .fill(entry.primaryColor)
                                .frame(width: 5, height: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(entry.primaryColor)
                                .frame(width: 10, height: 2)
                        }

                        Text(entry.text)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.surfaceWhite70)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AppColors.surfaceBlack30)
            .cornerRadius(4)
        }
    }
}
