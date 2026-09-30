//
//  MarkerSetupEditorParts.swift
//  traders_guild
//
//  Setup editing pieces shared by the placement General tab and the guided
//  Setup details, so both edit the same values the same way. Moved from
//  `MarkerPlacementGeneralTab` unchanged.
//

import SwiftUI

extension MarkerPlacementState {
    /// A price field bound straight to a level component.
    func levelPriceBinding(for type: RLComponentType) -> Binding<Double> {
        Binding<Double>(
            get: {
                self.componentPrice(type)
                    ?? self.anchorDraft?.payload.levelPrice
                    ?? 0
            },
            set: { newValue in
                switch type {
                case .levelTp:
                    self.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: newValue, label: "TP")))
                case .levelSl:
                    self.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: newValue, label: "SL")))
                case .levelSupport:
                    self.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: newValue, label: "Support")))
                case .levelResistance:
                    self.upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: newValue, label: "Resistance")))
                case .levelEntry:
                    self.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: newValue, label: "Entry")))
                default:
                    break
                }
            }
        )
    }
}

/// One tidy card for tracking mode: a slim header line + the estimated
/// reputation impact chips (replaces the old banner + separate chip row).
struct MarkerTrackedSetupCard: View {
    @ObservedObject var placementState: MarkerPlacementState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(RLComponentType.levelEntry.color)
                Text("Tracking active")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Spacer(minLength: 0)
                Text("Est. reputation")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.greyText)
            }

            HStack(spacing: 8) {
                trackedRepChip(
                    title: "If TP hits",
                    value: placementState.estimatedTrackingRepGain.map { "+\($0)" } ?? "—",
                    tint: RLComponentType.levelTp.color
                )
                trackedRepChip(
                    title: "If SL hits",
                    value: placementState.estimatedTrackingRepLoss.map { "-\($0)" } ?? "—",
                    tint: RLComponentType.levelSl.color
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RLComponentType.levelEntry.color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(RLComponentType.levelEntry.color.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func trackedRepChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.greyText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(tint.opacity(0.95))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(0.32), lineWidth: 1)
                )
        )
    }
}

/// A Setup's side, read from its levels as the chart's Entry / TP / SL lines
/// already do: long when the target is above entry and the stop below.
enum MarkerSetupSide: Equatable {
    case long
    case short
    /// Target and stop on the same side of entry.
    case inconsistent

    static func of(entry: Double?, takeProfit: Double?, stopLoss: Double?) -> MarkerSetupSide? {
        guard let entry, let takeProfit, let stopLoss else { return nil }
        if takeProfit > entry && stopLoss < entry { return .long }
        if takeProfit < entry && stopLoss > entry { return .short }
        return .inconsistent
    }

    var title: String {
        switch self {
        case .long: return "Long"
        case .short: return "Short"
        case .inconsistent: return "TP and SL on the same side"
        }
    }
}

extension MarkerPlacementState {
    /// Read against the Entry the chart shows (`guidedSetupEntryPrice`).
    var setupSide: MarkerSetupSide? {
        MarkerSetupSide.of(
            entry: guidedSetupEntryPrice,
            takeProfit: componentPrice(.levelTp),
            stopLoss: componentPrice(.levelSl)
        )
    }
}
