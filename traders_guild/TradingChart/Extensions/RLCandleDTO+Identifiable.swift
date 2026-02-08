//
//  RLCandleDTO+Identifiable.swift
//  traders_guild
//
//  UI helpers for candle rendering.
//

import Foundation

extension RLCandleDTO: Identifiable {
    var id: Date { timestamp }
}
