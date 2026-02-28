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
}
