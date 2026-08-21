//
//  ToastPresenting.swift
//  traders_guild
//
//  RLAppState's only remaining UIKit coupling was calling ToastWindowManager
//  directly, and that manager is built on a passthrough UIWindow — a solution to
//  an iPhone-only problem. Routing through this protocol lets macOS present the
//  same RLAppAlert as a plain SwiftUI overlay, and lets tests swallow toasts.
//

import Foundation

@MainActor
protocol ToastPresenting: AnyObject {
    func showToast(_ alert: RLAppAlert, onDismiss: @escaping () -> Void)
    func hideToast()
}

/// Resolves the presenter for the running platform.
///
/// The iOS default is read lazily rather than registered at launch, so there is
/// no window in which an early toast could be dropped because bootstrap hadn't
/// run yet.
@MainActor
enum ToastPresenter {

    private static var override: ToastPresenting?

    static var current: ToastPresenting {
        get {
            if let override { return override }
            #if canImport(UIKit)
            return ToastWindowManager.shared
            #else
            return NoopToastPresenter.shared
            #endif
        }
        set { override = newValue }
    }

    /// Restores the platform default. Intended for test teardown.
    static func resetToDefault() {
        override = nil
    }
}

/// Stand-in until the macOS shell installs its overlay presenter (Phase 4).
/// Alerts still land in `RLAppState.currentAlert`, so nothing is lost — they
/// simply aren't drawn yet.
@MainActor
final class NoopToastPresenter: ToastPresenting {
    static let shared = NoopToastPresenter()
    private init() {}
    func showToast(_ alert: RLAppAlert, onDismiss: @escaping () -> Void) {}
    func hideToast() {}
}
