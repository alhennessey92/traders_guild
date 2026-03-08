//
//  RLTopMarkerDTO+Extensions.swift
//  traders_guild
//
//  UI convenience for top markers.
//

import Foundation

extension RLTopMarkerDTO {
    var trackingStateEnum: RLTrackingState? {
        guard let rawState = setupSummary?.trackingState else { return nil }
        return RLTrackingState(rawValue: rawState)
    }
}
