//
//  MarkerPredictionProgress.swift
//  traders_guild
//
//  Lightweight live prediction status classification.
//

import Foundation

enum MarkerPredictionProgressStatus: String, Equatable {
    case inProgress = "In Progress"
    case approachingTP = "Approaching TP"
    case approachingSL = "Approaching SL"
    case liveUnavailable = "Live unavailable"
}

enum MarkerPredictionProgress {
    static func statusFromComponents(
        components: [RLMarkerComponentDTO],
        fallbackEntryPrice: Double,
        currentPrice: Double?
    ) -> MarkerPredictionProgressStatus {
        let entryPrice = components.first { $0.componentType == RLComponentType.levelEntry.rawValue }?.payload.levelPrice ?? fallbackEntryPrice
        let targetPrice = components.first { $0.componentType == RLComponentType.levelTp.rawValue }?.payload.levelPrice
        let stopLossPrice = components.first { $0.componentType == RLComponentType.levelSl.rawValue }?.payload.levelPrice
        return status(
            entryPrice: entryPrice,
            currentPrice: currentPrice,
            targetPrice: targetPrice,
            stopLossPrice: stopLossPrice
        )
    }

    static func status(
        entryPrice: Double,
        currentPrice: Double?,
        targetPrice: Double?,
        stopLossPrice: Double?
    ) -> MarkerPredictionProgressStatus {
        guard
            let currentPrice,
            let targetPrice,
            let stopLossPrice,
            entryPrice > 0
        else {
            return .liveUnavailable
        }

        let isLong = targetPrice > entryPrice && stopLossPrice < entryPrice
        let isShort = targetPrice < entryPrice && stopLossPrice > entryPrice

        if isLong {
            let tpDenominator = targetPrice - entryPrice
            let slDenominator = entryPrice - stopLossPrice
            guard tpDenominator > 0, slDenominator > 0 else { return .inProgress }

            let tpProgress = (currentPrice - entryPrice) / tpDenominator
            let slProgress = (entryPrice - currentPrice) / slDenominator
            if tpProgress >= 0.75 { return .approachingTP }
            if slProgress >= 0.75 { return .approachingSL }
            return .inProgress
        }

        if isShort {
            let tpDenominator = entryPrice - targetPrice
            let slDenominator = stopLossPrice - entryPrice
            guard tpDenominator > 0, slDenominator > 0 else { return .inProgress }

            let tpProgress = (entryPrice - currentPrice) / tpDenominator
            let slProgress = (currentPrice - entryPrice) / slDenominator
            if tpProgress >= 0.75 { return .approachingTP }
            if slProgress >= 0.75 { return .approachingSL }
            return .inProgress
        }

        return .inProgress
    }

    static func status(
        marker: RLChartMarkerDTO,
        currentPrice: Double?
    ) -> MarkerPredictionProgressStatus {
        statusFromComponents(
            components: marker.components,
            fallbackEntryPrice: marker.price,
            currentPrice: currentPrice
        )
    }

    static func trackingState(for marker: RLChartMarkerDTO) -> RLTrackingState? {
        marker.trackingStateEnum
    }

    // MARK: - Outcome Verification

    /// Whether the marker's outcome has been finalized (TP hit, SL hit, or expired).
    static func isOutcomeFinalized(_ marker: RLChartMarkerDTO) -> Bool {
        marker.trackingStateEnum?.isResolved == true
    }

    /// Build a structured outcome description for display in the marker info box.
    static func outcomeDescription(for marker: RLChartMarkerDTO) -> SetupOutcome? {
        guard let state = marker.trackingStateEnum, state.isResolved else { return nil }

        let result = marker.predictionResult
        return SetupOutcome(
            state: state,
            resultType: result?.resultType,
            triggerPrice: result.map { $0.triggerPrice },
            triggeredAtFormatted: result?.triggeredAtFormatted,
            pnl: result?.pnl,
            isTracked: marker.trackingEnabled
        )
    }
}

// MARK: - Setup Outcome

struct SetupOutcome {
    let state: RLTrackingState
    let resultType: String?
    let triggerPrice: Double?
    let triggeredAtFormatted: String?
    let pnl: Double?
    let isTracked: Bool

    var isWin: Bool { state == .tpHit }
    var isLoss: Bool { state == .slHit }
    var isExpired: Bool { state == .expired }
    var affectsPerformance: Bool { isTracked && !isExpired }

    var impactNote: String? {
        guard isTracked else { return nil }
        if isExpired {
            return "Expired setups do not affect accuracy or reputation"
        }
        return "This result affected your accuracy and reputation"
    }

    var displayLabel: String { state.displayName }

    var displayIcon: String {
        switch state {
        case .tpHit: return "checkmark.circle.fill"
        case .slHit: return "xmark.circle.fill"
        case .expired: return "clock.badge.xmark.fill"
        default: return "questionmark.circle"
        }
    }
}
