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
            isTracked: marker.trackingEnabled,
            guildRepDelta: result?.guildRepDelta,
            globalRepDelta: result?.globalRepDelta
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
    let guildRepDelta: Int?
    let globalRepDelta: Int?

    var isWin: Bool { state == .tpHit }
    var isLoss: Bool { state == .slHit }
    var isExpired: Bool { state == .expired }
    var affectsPerformance: Bool { isTracked && !isExpired }

    var impactNote: String? {
        guard isTracked else { return nil }
        if isExpired {
            return "Expired setups do not affect accuracy or reputation"
        }
        if isLoss {
            return "This result affected your accuracy only"
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

    /// Formatted rep change string, e.g. "+25" or "-10"
    var repChangeText: String? {
        guard let delta = guildRepDelta else { return nil }
        return delta >= 0 ? "+\(delta)" : "\(delta)"
    }
}

// MARK: - Live Setup Metrics

/// Computed metrics for displaying a live setup progress strip.
/// Shared between MarkerActivityCard, MarkerViewingGeneralTab, and MarkerDetailView.
struct LiveSetupMetrics {
    let entryPrice: Double
    let stopLossPrice: Double
    let targetPrice: Double
    let currentPrice: Double
    let currentPnL: Double
    let entryPosition: Double
    let currentPosition: Double
    let isLong: Bool
    let isMovingTowardTarget: Bool

    /// Normalized SL position within [0, 1] range.
    var stopLossPosition: Double { isLong ? 0.0 : 1.0 }

    /// Normalized TP position within [0, 1] range.
    var targetPosition: Double { isLong ? 1.0 : 0.0 }

    /// Compute metrics from setup prices and current market price.
    /// Returns nil if prices are invalid or the setup direction can't be determined.
    static func compute(
        entryPrice: Double,
        stopLossPrice: Double,
        targetPrice: Double,
        currentPrice: Double
    ) -> LiveSetupMetrics? {
        guard entryPrice > 0 else { return nil }

        let isLong = targetPrice > entryPrice && stopLossPrice < entryPrice
        let isShort = targetPrice < entryPrice && stopLossPrice > entryPrice
        guard isLong || isShort else { return nil }

        let rangeLow = min(stopLossPrice, targetPrice)
        let rangeHigh = max(stopLossPrice, targetPrice)
        guard rangeHigh > rangeLow else { return nil }

        let clampedCurrent = min(max(currentPrice, rangeLow), rangeHigh)
        let currentPnL = isLong
            ? ((currentPrice - entryPrice) / entryPrice) * 100
            : ((entryPrice - currentPrice) / entryPrice) * 100

        let entryPosition = (entryPrice - rangeLow) / (rangeHigh - rangeLow)
        let currentPosition = (clampedCurrent - rangeLow) / (rangeHigh - rangeLow)
        let isMovingTowardTarget = isLong ? currentPrice > entryPrice : currentPrice < entryPrice

        return LiveSetupMetrics(
            entryPrice: entryPrice,
            stopLossPrice: stopLossPrice,
            targetPrice: targetPrice,
            currentPrice: currentPrice,
            currentPnL: currentPnL,
            entryPosition: entryPosition,
            currentPosition: currentPosition,
            isLong: isLong,
            isMovingTowardTarget: isMovingTowardTarget
        )
    }

    /// Compute metrics from setup prices with an optional current price.
    /// Returns nil if prices are invalid or the setup direction can't be determined.
    /// When currentPrice is nil, returns metrics with current clamped to entry.
    static func compute(
        entryPrice: Double,
        stopLossPrice: Double,
        targetPrice: Double,
        currentPrice: Double?
    ) -> LiveSetupMetrics? {
        guard let currentPrice else {
            return compute(
                entryPrice: entryPrice,
                stopLossPrice: stopLossPrice,
                targetPrice: targetPrice,
                currentPrice: entryPrice
            )
        }
        return compute(
            entryPrice: entryPrice,
            stopLossPrice: stopLossPrice,
            targetPrice: targetPrice,
            currentPrice: currentPrice
        )
    }
}
