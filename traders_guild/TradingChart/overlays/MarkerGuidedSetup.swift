import SwiftUI

/// Long or Short, as the author chooses it on the Setup ticket. The side
/// itself is still read from the levels (`setupSide`); choosing one moves
/// Take Profit and Stop Loss to that side of Entry.
enum MarkerSetupDirection: String, CaseIterable, Identifiable {
    case long, short

    var id: String { rawValue }
    var title: String { self == .long ? "Long" : "Short" }
    var icon: String { self == .long ? "arrow.up.right" : "arrow.down.right" }
}

/// A side change that would move levels the author set (or a saved Setup's),
/// waiting on their say-so. Says exactly what moves.
struct MarkerSetupSideChange: Identifiable, Equatable {
    let id = UUID()
    let direction: MarkerSetupDirection
    let takeProfitFrom: Double
    let takeProfitTo: Double
    let stopLossFrom: Double
    let stopLossTo: Double

    var summary: String {
        "Take Profit \(MarkerGuidedFormat.displayPrice(takeProfitFrom)) → \(MarkerGuidedFormat.displayPrice(takeProfitTo))"
            + " · Stop Loss \(MarkerGuidedFormat.displayPrice(stopLossFrom)) → \(MarkerGuidedFormat.displayPrice(stopLossTo))"
    }
}

extension MarkerPlacementState {
    /// The side the levels describe, when they describe one.
    var setupDirection: MarkerSetupDirection? {
        switch setupSide {
        case .long?: return .long
        case .short?: return .short
        default: return nil
        }
    }

    /// Where Take Profit and Stop Loss go on `direction`'s side of Entry,
    /// each keeping its distance from Entry. Nil without three real prices,
    /// a level sitting on Entry, or a mirrored price that would not be a
    /// price at all.
    func setupLevels(for direction: MarkerSetupDirection) -> (takeProfit: Double, stopLoss: Double)? {
        guard let entry = guidedSetupEntryPrice, let tp = componentPrice(.levelTp), let sl = componentPrice(.levelSl),
              entry.isFinite, tp.isFinite, sl.isFinite else { return nil }
        let reward = abs(tp - entry)
        let risk = abs(sl - entry)
        guard reward > 0, risk > 0 else { return nil }
        let levels = direction == .long ? (entry + reward, entry - risk) : (entry - reward, entry + risk)
        guard levels.0 > 0, levels.1 > 0 else { return nil }
        return (levels.0, levels.1)
    }

    /// The author chose a side. Levels the chart suggested move straight
    /// away: they are not the author's. Levels the author set, and a saved
    /// Setup's, move only once they agree, so the change is returned for a
    /// confirmation instead. Nothing is ever mirrored silently.
    func requestSetupDirection(_ direction: MarkerSetupDirection) -> MarkerSetupSideChange? {
        guard intent == .setup, isGuidedFlowActive, !isGuidedSubmissionInFlight, !isGuidedEditLocked,
              setupDirection != direction,
              let levels = setupLevels(for: direction),
              let tp = componentPrice(.levelTp), let sl = componentPrice(.levelSl) else { return nil }
        let change = MarkerSetupSideChange(direction: direction, takeProfitFrom: tp, takeProfitTo: levels.takeProfit,
                                           stopLossFrom: sl, stopLossTo: levels.stopLoss)
        guard !isGuidedEdit, !setupLevelsEdited else { return change }
        applySetupSideChange(change)
        // Still the chart's suggestion, just on the other side.
        recordSetupLevelSeed()
        return nil
    }

    /// Moves the levels as `change` says. Each keeps its saved label, colour
    /// and keys; only the price changes.
    func applySetupSideChange(_ change: MarkerSetupSideChange) {
        guard intent == .setup, !isGuidedSubmissionInFlight, !isGuidedEditLocked else { return }
        workspace.levelInputs[.levelTp] = nil
        workspace.levelInputs[.levelSl] = nil
        guidedLevelPriceBinding(for: .levelTp).wrappedValue = change.takeProfitTo
        guidedLevelPriceBinding(for: .levelSl).wrappedValue = change.stopLossTo
    }

    // MARK: Adjust on chart

    /// The author is moving Take Profit and Stop Loss on the chart, with the
    /// workspace collapsed to its tool bar.
    var isAdjustingSetupOnChart: Bool { workspace.setupAdjustBaseline != nil }

    /// Remembers the levels exactly, so Cancel can put them back.
    @discardableResult
    func beginSetupAdjust() -> Bool {
        guard intent == .setup, isGuidedFlowActive, !isGuidedSubmissionInFlight, !isGuidedEditLocked else { return false }
        workspace.setupAdjustBaseline = components.filter { [.levelTp, .levelSl].contains($0.componentType) }
        return true
    }

    /// Cancel: the levels exactly as they were, identity, label and keys included.
    func cancelSetupAdjust() {
        guard let baseline = workspace.setupAdjustBaseline else { return }
        var updated = components
        for saved in baseline {
            if let index = updated.firstIndex(where: { $0.componentType == saved.componentType }) {
                updated[index] = saved
            } else {
                updated.append(saved)
            }
        }
        if updated != components { components = updated }
        workspace.levelInputs[.levelTp] = nil
        workspace.levelInputs[.levelSl] = nil
        workspace.setupAdjustBaseline = nil
    }

    /// Done, or the workspace reopened: the levels stay where they were moved.
    func finishSetupAdjust() {
        guard isAdjustingSetupOnChart else { return }
        workspace.levelInputs[.levelTp] = nil
        workspace.levelInputs[.levelSl] = nil
        workspace.setupAdjustBaseline = nil
    }

    /// The chart's Take Profit and Stop Loss handles moved during a guided
    /// Setup edit. Their prices change and nothing else does: the saved
    /// label, colour and keys stay, and Entry and the anchor are never
    /// touched (they are sent as saved).
    func applyChartSetupLevels(takeProfit: Double, stopLoss: Double) {
        guard isGuidedEdit, intent == .setup, !isGuidedEditLocked, !isGuidedSubmissionInFlight else { return }
        for (type, price) in [(RLComponentType.levelTp, takeProfit), (.levelSl, stopLoss)] where price.isFinite && price > 0 {
            if let current = componentPrice(type), abs(current - price) < 0.0000001 { continue }
            workspace.levelInputs[type] = nil
            guidedLevelPriceBinding(for: type).wrappedValue = price
        }
    }

    /// "TP 65,000.00 · SL 63,000.00 · R:R 1:2.40", for the chart tool bar,
    /// where it must fit one line.
    var setupAdjustReadout: String {
        let ratio = guidedSetupRiskReward.flatMap { $0.isFinite ? String(format: "R:R 1:%.2f", $0) : nil } ?? "R:R —"
        return "TP \(MarkerGuidedFormat.displayPrice(componentPrice(.levelTp)))"
            + " · SL \(MarkerGuidedFormat.displayPrice(componentPrice(.levelSl)))"
            + " · \(ratio)"
    }
}
