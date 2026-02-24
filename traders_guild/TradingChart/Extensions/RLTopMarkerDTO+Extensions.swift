//
//  RLTopMarkerDTO+Extensions.swift
//  traders_guild
//
//  UI convenience for top markers.
//

import Foundation

extension RLTopMarkerDTO {
    var markerTypeEnum: RLMarkerType {
        RLMarkerType.fromBackendString(markerType) ?? .note
    }
}
