//
//  Haptics.swift
//  traders_guild
//
//  Moved here from Features/Shared/other/HapticFeedback.swift so the chart and
//  feature code can keep calling `HapticFeedback.medium.trigger()` unchanged on
//  a platform that has no haptics hardware. On macOS every case is a no-op.
//
//  The signature is deliberately identical to the original — no @MainActor, no
//  async — so none of the ~60 existing call sites need to change.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum HapticFeedback {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case selection
    case success
    case warning
    case error

    func trigger() {
        #if canImport(UIKit)
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }
}

/// Mirror of `UIImpactFeedbackGenerator` for the call sites that hold one as a
/// stored property rather than going through `HapticFeedback`.
///
/// Deliberately a class with the same shape and the same method names, so those
/// sites port by renaming the type alone — same object, same lifetime, same
/// calls, and therefore the same feel on iOS. Includes the `intensity:` variant
/// the chart uses for its softer taps. Every method is a no-op on macOS.
final class PlatformImpactGenerator {

    enum Style {
        case light, medium, heavy, soft, rigid

        #if canImport(UIKit)
        var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }
        #endif
    }

    #if canImport(UIKit)
    private let generator: UIImpactFeedbackGenerator
    #endif

    init(style: Style) {
        #if canImport(UIKit)
        generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        #endif
    }

    func prepare() {
        #if canImport(UIKit)
        generator.prepare()
        #endif
    }

    func impactOccurred() {
        #if canImport(UIKit)
        generator.impactOccurred()
        #endif
    }

    func impactOccurred(intensity: CGFloat) {
        #if canImport(UIKit)
        generator.impactOccurred(intensity: intensity)
        #endif
    }
}
