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
