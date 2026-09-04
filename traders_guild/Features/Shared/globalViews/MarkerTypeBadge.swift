//
//  MarkerTypeBadge.swift
//  traders_guild
//
//  A marker's type, in its own colour.
//

import SwiftUI

/// "SETUP", "ALERT · CRITICAL" — the marker's type as a tinted pill.
///
/// Wraps `MarkerListSpecificsLabel`, which owns the 8.5pt/heavy/0.4-tracking
/// metrics the marker list already uses, so the two cannot drift. Android's
/// `MarkerTypeLabel` is the same component with the same metrics.
///
/// The colour is the **domain** one (`RLMarkerIntent.color`), not the glyph
/// accent. The two disagree for `alert` (no severity) and `personal`; the text
/// label has always used the domain colour, and this is a text label.
struct MarkerTypeBadge: View {
    let intent: RLMarkerIntent
    var severity: MarkerAlertSeverity?

    private var tint: Color { severity?.color ?? intent.color }

    private var label: String {
        if let severity {
            return "\(intent.displayName) · \(severity.displayLabel)".uppercased()
        }
        return intent.displayName.uppercased()
    }

    var body: some View {
        MarkerListSpecificsLabel(label: label, color: tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(tint.opacity(0.38), lineWidth: 1)
                    )
            )
    }
}
