//
//  MarkerIntentBadge.swift
//  traders_guild
//
//  What an avatar-led marker says around its author's face: the intent badge,
//  the idle intent ring and, on selection, its component arcs.
//

import SwiftUI

// MARK: - Intent badge

/// The small badge that tells an avatar-led marker's intent at a glance, now
/// that the face has taken the glyph's place.
///
/// Shared by the chart canvas and the SwiftUI marker badge so both say the
/// same thing. Existing TG iconography and colours: the intent's own colour,
/// and for Setup the tracking state's icon and colour.
enum MarkerIntentBadge {
    struct Style: Equatable {
        let symbol: String
        let color: Color
        /// The badge's outline as a filled SF Symbol, for an alert: its
        /// urgency's shape. Nil for the plain disc every other badge wears.
        var shape: String? = nil
        /// Moves the glyph inside a shape whose visual centre is not its
        /// frame's centre (a triangle's sits low), as a fraction of the badge.
        var glyphOffset: CGFloat = 0
        /// The glyph's colour where the on-accent white would not read.
        var glyphColor: Color? = nil
    }

    /// A Setup's lifecycle, as far as the badge is concerned.
    enum SetupStatus: Equatable {
        /// Not tracked: no accuracy or reputation at stake.
        case untracked
        case armed
        case active
        case takeProfit
        case stopLoss
        case expired
        /// The caller has no tracking data (some list payloads), so the badge
        /// must not claim either way.
        case unknown

        /// A resolved result wins over the stored state; an untracked Setup
        /// with no state is `.untracked`.
        static func from(
            trackingEnabled: Bool,
            trackingState: RLTrackingState?,
            predictionResult: RLPredictionResultDTO?
        ) -> SetupStatus {
            if let predictionResult {
                return predictionResult.isWin ? .takeProfit : .stopLoss
            }
            switch trackingState {
            case .draft?: return .untracked
            case .armed?: return .armed
            case .active?: return .active
            case .tpHit?: return .takeProfit
            case .slHit?: return .stopLoss
            case .expired?: return .expired
            case nil: return trackingEnabled ? .armed : .untracked
            }
        }

        static func from(_ marker: RLChartMarkerDTO) -> SetupStatus {
            from(
                trackingEnabled: marker.trackingEnabled,
                trackingState: marker.trackingStateEnum,
                predictionResult: marker.predictionResult
            )
        }

        /// Lists carry only a raw tracking state, if anything.
        static func from(summaryTrackingState raw: String?) -> SetupStatus {
            guard let raw, let state = RLTrackingState(rawValue: raw.uppercased()) else { return .unknown }
            return from(trackingEnabled: state != .draft, trackingState: state, predictionResult: nil)
        }
    }

    /// An alert's ring and accent under the prototype. The legacy alert colour
    /// is a neutral grey that reads as "disabled" beside the other rings;
    /// amber says "look here". Its badge carries the severity's own colour.
    static var alertAccent: Color { AppColors.statusWarning }

    /// The colour an intent wears in the prototype: its ring, its badge, its
    /// name and buttons in the sheet. An alert wears its urgency's colour once
    /// it has one.
    static func accentColor(for intent: RLMarkerIntent, alertSeverity: MarkerAlertSeverity? = nil) -> Color {
        guard intent == .alert else { return intent.color }
        return alertSeverity?.color ?? alertAccent
    }

    /// Text or a glyph on a filled accent: dark on Severe's yellow, where
    /// white does not read; white everywhere else.
    static func onAccentForeground(for intent: RLMarkerIntent, alertSeverity: MarkerAlertSeverity? = nil) -> Color {
        intent == .alert && alertSeverity == .severe ? Color.black.opacity(0.82) : .white
    }

    /// An alert's badge outline and mark, by urgency: the shapes its glyphs
    /// have always had (owner, 11 Oct): a circled "i", a shield, a triangle,
    /// an octagon. Without an urgency yet, the shield.
    static func alertShape(for severity: MarkerAlertSeverity?) -> (shape: String, glyph: String, glyphOffset: CGFloat) {
        switch severity {
        case .mild?: return ("circle.fill", "info", 0)
        case .severe?: return ("triangle.fill", "exclamationmark", 0.1)
        case .critical?: return ("octagon.fill", "exclamationmark", 0)
        case .moderate?, nil: return ("shield.fill", "exclamationmark", -0.04)
        }
    }

    /// The badge for an intent, or `nil` for intents that keep their glyph.
    /// An alert's badge takes its severity's colour when it is known.
    static func style(
        intent: RLMarkerIntent,
        setupStatus: SetupStatus = .unknown,
        alertSeverity: MarkerAlertSeverity? = nil
    ) -> Style? {
        switch intent {
        case .analysis:
            return Style(symbol: "waveform.path.ecg", color: AppColors.intentAnalysisTeal)
        case .question:
            return Style(symbol: "questionmark", color: AppColors.intentQuestionBlue)
        case .poll:
            return Style(symbol: "chart.bar.fill", color: AppColors.intentPollPurple)
        case .alert:
            let look = alertShape(for: alertSeverity)
            return Style(
                symbol: look.glyph,
                color: accentColor(for: .alert, alertSeverity: alertSeverity),
                shape: look.shape,
                glyphOffset: look.glyphOffset,
                glyphColor: alertSeverity == .severe ? onAccentForeground(for: .alert, alertSeverity: .severe) : nil
            )
        case .setup:
            switch setupStatus {
            case .untracked:
                return Style(symbol: RLTrackingState.draft.icon, color: RLTrackingState.draft.color)
            case .armed:
                return Style(symbol: RLTrackingState.armed.icon, color: RLTrackingState.armed.color)
            case .active:
                return Style(symbol: RLTrackingState.active.icon, color: RLTrackingState.active.color)
            case .takeProfit:
                return Style(symbol: "checkmark", color: RLTrackingState.tpHit.color)
            case .stopLoss:
                return Style(symbol: "xmark", color: RLTrackingState.slHit.color)
            case .expired:
                return Style(symbol: "clock", color: RLTrackingState.expired.color)
            case .unknown:
                return Style(symbol: "scope", color: AppColors.intentSetupGreen)
            }
        case .news, .reaction, .personal:
            return nil
        }
    }

    // MARK: Palette badges

    /// Analysis, Question, Poll and Alert wear their own multi-colour SF
    /// Symbol (the icons the markers had before v1.5) on a small glass disc,
    /// rather than a glyph on a coloured disc (owner, 11 Oct: "much cleaner").
    /// An alert's is its urgency's (shield, triangle, octagon, circled "i").
    /// A Setup keeps its lifecycle badge: it says where the trade stands.
    static func usesPaletteSymbol(intent: RLMarkerIntent) -> Bool {
        [.analysis, .question, .poll, .alert].contains(intent)
    }

    /// A palette badge is larger than a glyph badge, so its second colour
    /// reads.
    static let paletteDiameter: CGFloat = 19

    /// A palette badge's frame, centred where a glyph badge's would be.
    static func paletteRect(center: CGPoint, isBelow: Bool, scale: CGFloat = 1) -> CGRect {
        let glyph = rect(center: center, isBelow: isBelow, scale: scale)
        let side = paletteDiameter
        return CGRect(x: glyph.midX - side / 2, y: glyph.midY - side / 2, width: side, height: side)
    }

    /// Where the badge sits: on the side away from the candle, mirroring the
    /// like badge across the glyph's horizontal axis. The candle side already
    /// holds the like and response badges; outward is free at rest, and at 45°
    /// from the outward vertical it clears the stack neighbour straight above
    /// (or below) — 4pt to that neighbour's like badge at any selection scale.
    static func rect(center: CGPoint, isBelow: Bool, scale: CGFloat = 1) -> CGRect {
        let outset = MarkerLinkRenderer.badgeOutset(scale: scale)
        let size = MarkerLinkRenderer.badgeSize
        let yOffset: CGFloat = isBelow ? 5 + outset : -17 - outset
        return CGRect(x: center.x + 8 + outset, y: center.y + yOffset, width: size, height: size)
    }
}

// MARK: - Idle ring

/// The one restrained ring an avatar-led marker wears at rest.
enum MarkerIntentRing {
    static let lineWidth: CGFloat = 1.25
    static let opacity: Double = 0.7

    static func color(for intent: RLMarkerIntent) -> Color? {
        guard MarkerAvatarPresentation.experimentIntents.contains(intent) else { return nil }
        return MarkerIntentBadge.accentColor(for: intent)
    }

    /// The ring to stroke at the disc edge, or `nil` for the ordinary glass
    /// stroke. A relationship ring, when the marker has one, replaces the
    /// intent ring rather than stacking with it.
    static func strokeColor(
        intent: RLMarkerIntent,
        showsDecorations: Bool,
        hasRelationshipRing: Bool
    ) -> Color? {
        guard showsDecorations, !hasRelationshipRing else { return nil }
        return color(for: intent)
    }
}

// MARK: - Component arcs

/// Up to three short arcs outside a *selected* avatar-led marker, one per kind
/// of supporting context it carries. A hint that there is more, not a list.
enum MarkerComponentArcs {
    enum Category: Int, CaseIterable, Comparable {
        case indicators
        case drawings
        case timeframesAndLinks

        static func < (lhs: Category, rhs: Category) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Existing component colour tokens.
        var color: Color {
            switch self {
            case .indicators: return AppColors.componentIndicatorOrange
            case .drawings: return AppColors.componentSupportPurple
            case .timeframesAndLinks: return AppColors.componentTimeframeCyan
            }
        }

        /// The three groups the plan names — indicators; drawings and
        /// supporting levels; timeframes and links — and nothing else.
        ///
        /// The anchor and a Setup's own Entry / SL / TP are structure, not
        /// supporting context. Text notes and reaction emoji are neither
        /// drawings nor supporting levels, so they produce no arc either.
        static func of(_ type: RLComponentType) -> Category? {
            switch type {
            case .indicator:
                return .indicators
            case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern,
                 .levelSupport, .levelResistance:
                return .drawings
            case .timeframeLink, .linkURL:
                return .timeframesAndLinks
            case .anchor, .levelEntry, .levelSl, .levelTp, .textNote, .reactionEmoji:
                return nil
            }
        }
    }

    /// Distinct categories, in fixed order. Repeats collapse into one arc.
    static func categories(of components: [RLMarkerComponentDTO]) -> [Category] {
        Set(components.compactMap { $0.componentTypeEnum.flatMap(Category.of) }).sorted()
    }

    static let radiusOffset: CGFloat = 3.5
    static let lineWidth: CGFloat = 2
    static let opacity: Double = 0.85
    /// While a branch is focused the relationship ring is the authority.
    static let opacityUnderRelationshipRing: Double = 0.4

    /// Fixed angular slot per category, in screen degrees (0° = right, 90° =
    /// down), for a glyph above its candle; mirrored for one below.
    ///
    /// The three slots run across the left and outward side, the only stretch
    /// of the rim no badge ever occupies: the like and response badges sit on
    /// the candle side and the intent badge outward-right. A category keeps its
    /// slot whatever else is present, so its position means something.
    static func slot(for category: Category, isBelow: Bool) -> (start: Angle, end: Angle) {
        let start: Double
        switch category {
        case .indicators: start = 167
        case .drawings: start = 215
        case .timeframesAndLinks: start = 263
        }
        let end = start + 36
        return isBelow
            ? (.degrees(-end), .degrees(-start))
            : (.degrees(start), .degrees(end))
    }
}
