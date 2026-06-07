//
//  GlobalAlertModifier.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI
import UIKit

/// Passes touches through to the app underneath, except taps that land on the
/// toast bar itself.
///
/// The bar is hosted as a **bottom-pinned child view** (not a full-screen
/// SwiftUI tree), so a tap resolves either to the bar's hosting view — which we
/// keep, letting SwiftUI dispatch it to the dismiss button — or to the empty
/// full-screen container root view, which we pass through. This avoids the
/// fragile "track the bubble frame via a PreferenceKey" approach, which broke
/// once the bar started bleeding into the safe area.
final class ToastPassthroughWindow: UIWindow {
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // A tap that resolves to the empty full-screen container (everything
        // except the bar) passes through to the app underneath.
        if hit === rootViewController?.view { return nil }
        return hit
    }
}

@MainActor
class ToastWindowManager: ObservableObject {
    static let shared = ToastWindowManager()

    private var toastWindow: ToastPassthroughWindow?
    private var activeAlertId: UUID?
    private weak var activeBarHost: UIViewController?

    private init() {}

    func showToast(_ alert: RLAppAlert, onDismiss: @escaping () -> Void) {
        activeAlertId = alert.id

        // Create window if needed (passthrough so touches outside the bar still
        // reach the app underneath).
        if toastWindow == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let window = ToastPassthroughWindow(windowScene: windowScene)
                window.windowLevel = .alert + 1
                window.backgroundColor = .clear
                window.isUserInteractionEnabled = true
                toastWindow = window
            }
        }

        guard let window = toastWindow else { return }

        // Bottom safe-area inset (home indicator). Read from the app's key
        // window — already laid out, so reliable — and shared by this device.
        let bottomInset = Self.keyWindowBottomInset()

        let bar = ErrorToastView(alert: alert, bottomInset: bottomInset, onDismiss: { [weak self] in
            guard let self = self else { return }
            if self.activeAlertId == alert.id {
                onDismiss()
                self.hideToast()
            }
        })

        // Self-sizing SwiftUI host (intrinsic height), pinned full-width to the
        // bottom of a clear full-screen container.
        let host = UIHostingController(rootView: bar)
        host.view.backgroundColor = .clear
        host.sizingOptions = [.intrinsicContentSize]
        // Stop the hosting controller from adding the bottom safe-area inset on
        // top of our own padding (that was making the bar's text float high).
        host.safeAreaRegions = []

        let container = UIViewController()
        container.view.backgroundColor = .clear
        container.addChild(host)
        container.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
        ])
        host.didMove(toParent: container)

        window.rootViewController = container
        window.isHidden = false
        activeBarHost = host

        // Slide up + fade in (window alpha + bar transform).
        window.alpha = 0
        container.view.layoutIfNeeded()
        host.view.transform = CGAffineTransform(translationX: 0, y: host.view.bounds.height + 20)
        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]
        ) {
            window.alpha = 1
            host.view.transform = .identity
        }
    }

    /// Bottom safe-area inset from the app's current key window (already laid
    /// out, so reliable — the freshly-created toast window may still report 0).
    private static func keyWindowBottomInset() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    func hideToast() {
        guard let window = toastWindow else { return }
        activeAlertId = nil
        let host = activeBarHost
        activeBarHost = nil

        UIView.animate(withDuration: 0.28, animations: {
            window.alpha = 0
            if let host { host.view.transform = CGAffineTransform(translationX: 0, y: host.view.bounds.height + 20) }
        }) { _ in
            window.isHidden = true
            window.rootViewController = nil
            host?.view.transform = .identity
        }
    }
}
