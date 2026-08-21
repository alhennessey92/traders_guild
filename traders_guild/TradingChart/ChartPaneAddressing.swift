//
//  ChartPaneAddressing.swift
//  traders_guild
//
//  Chart notifications used to be posted with `object: nil` and no address, so
//  every chart in the view tree received every one of them. With a single
//  full-screen chart that was indistinguishable from "send it to the chart".
//  With four panes in a macOS window it means "Place Marker" fires four times.
//
//  Everything pane-directed goes through here, stamped with the target pane's
//  identity and filtered on receipt.
//
//  Note that not every chart notification belongs here: `.markerCreatedSuccessfully`
//  is genuinely app-wide — the review prompt and the marker lists all want it —
//  and is deliberately left as a broadcast.
//

import Foundation

enum ChartPaneAddressing {

    /// `userInfo` key carrying the intended recipient.
    static let paneIDKey = "chartPaneID"

    /// Post `name` addressed to a single pane.
    static func post(
        _ name: Notification.Name,
        to paneID: UUID,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        var info = userInfo
        info[paneIDKey] = paneID
        NotificationCenter.default.post(name: name, object: nil, userInfo: info)
    }

    /// Whether `notification` is meant for `paneID`.
    ///
    /// An unaddressed notification is accepted rather than dropped, so a poster
    /// that has not been migrated keeps working instead of silently doing
    /// nothing. That is the safer failure on a single-pane build — but it is the
    /// original bug on a multi-pane one, so debug builds trip an assertion to
    /// surface the missed poster while it is still cheap to fix.
    static func isAddressed(_ notification: Notification, to paneID: UUID) -> Bool {
        guard let target = notification.userInfo?[paneIDKey] as? UUID else {
            assertionFailure(
                "Pane-directed notification \(notification.name.rawValue) was posted "
                + "without a \(paneIDKey). Post it via ChartPaneAddressing.post(_:to:)."
            )
            return true
        }
        return target == paneID
    }
}
