//
//  MarkerLinkRelationship.swift
//  traders_guild
//
//  The three ways one marker can answer another, and the single source of truth
//  for how that relationship is named, coloured and drawn.
//

import SwiftUI

/// How a response marker relates to the marker it answers.
///
/// The wire format carries a raw string that iOS deliberately does **not** decode
/// into a non-optional enum: the backend may add relationships after this build
/// ships, and an unknown value must render as an ordinary linked marker rather
/// than failing the whole marker's decode. `MarkerLinkRelationshipValue` is the
/// tolerant wrapper every call site should hold; this enum is what you get once
/// the value is one this build understands.
enum MarkerLinkRelationship: String, Codable, CaseIterable, Hashable {
    case supports
    case challenges
    case buildsOn = "builds_on"

    /// Title case, for chips, pickers and ring legends.
    var displayName: String {
        switch self {
        case .supports: return "Supports"
        case .challenges: return "Challenges"
        case .buildsOn: return "Builds on"
        }
    }

    /// Lowercase, for use mid-sentence: "Alex **supports** your marker".
    var verb: String {
        switch self {
        case .supports: return "supports"
        case .challenges: return "challenges"
        case .buildsOn: return "builds on"
        }
    }

    /// One line of explanation shown beside the choice when responding.
    var pickerSubtitle: String {
        switch self {
        case .supports: return "You agree and want to back this idea"
        case .challenges: return "You disagree, or see it going the other way"
        case .buildsOn: return "You extend it — a further target or next leg"
        }
    }

    var icon: String {
        switch self {
        case .supports: return "checkmark"
        case .challenges: return "arrow.triangle.swap"
        case .buildsOn: return "arrow.triangle.branch"
        }
    }

    /// Chrome colour. Chart connectors and rings are chrome, not chart data, so
    /// these deliberately use the semantic status tokens rather than the candle
    /// palette — see the note on `AppColors.onlineStatusGreen`.
    var accentColor: Color {
        switch self {
        case .supports: return AppColors.statusPositive
        case .challenges: return AppColors.statusNegative
        case .buildsOn: return AppColors.accentColor
        }
    }

    /// Distinct dash per relationship so the three are separable without colour.
    /// Deliberately different from the grey stack spine's `[3, 2]`.
    var dashPattern: [CGFloat] {
        switch self {
        case .supports: return [5, 3]
        case .challenges: return [2, 3]
        case .buildsOn: return [7, 3, 2, 3]
        }
    }
}

/// A relationship as it arrived from the server: understood, unknown, or absent.
///
/// Unknown values keep their raw string so the UI can still say *something*
/// truthful ("Linked to …") and so a round-trip through `updating(...)` does not
/// silently drop a relationship this build does not recognise.
struct MarkerLinkRelationshipValue: Equatable, Hashable {
    let raw: String

    init(raw: String) {
        self.raw = raw
    }

    init(_ relationship: MarkerLinkRelationship) {
        self.raw = relationship.rawValue
    }

    /// Non-nil only when this build understands the value.
    var known: MarkerLinkRelationship? {
        MarkerLinkRelationship(rawValue: raw)
    }

    var isKnown: Bool { known != nil }

    var displayName: String {
        known?.displayName ?? Self.humanized(raw)
    }

    var verb: String {
        known?.verb ?? Self.humanized(raw).lowercased()
    }

    var icon: String {
        known?.icon ?? "link"
    }

    var accentColor: Color {
        known?.accentColor ?? AppColors.greyText
    }

    var dashPattern: [CGFloat] {
        known?.dashPattern ?? [4, 3]
    }

    /// "builds_on" -> "Builds on". Only ever shown for values added server-side
    /// after this build shipped; it is a graceful fallback, not a translation.
    static func humanized(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = spaced.first else { return "Linked" }
        return String(first).uppercased() + spaced.dropFirst()
    }

    /// Builds a value from an optional raw string, treating empty as absent.
    static func make(_ raw: String?) -> MarkerLinkRelationshipValue? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return MarkerLinkRelationshipValue(raw: raw)
    }
}

// MARK: - Sentence building

extension MarkerLinkRelationshipValue {
    /// "Supports Alex's BTC prediction" / "Challenges @jamie's setup".
    ///
    /// `subject` is already-resolved display text; this type never reaches for
    /// app state to decide what to call someone.
    func sentence(subject: String?) -> String {
        guard let subject, !subject.isEmpty else { return displayName }
        return "\(displayName) \(subject)"
    }
}
