//
//  GlobalAlertModifier.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI
import UIKit

/// Window that only intercepts touches landing on the actual toast bubble.
/// Everything else passes through to the app underneath.
///
/// SwiftUI's `Button` (and most other interactive controls) doesn't expose
/// a per-element UIView for hit testing — `super.hitTest` for a tap inside a
/// SwiftUI hierarchy returns the hosting view itself. The previous heuristic
/// (filter out hits on `rootViewController.view`) therefore swallowed every
/// tap on the dismiss button: the system reported the host view, we
/// returned nil, and the tap fell through to the content behind the toast.
///
/// Fix: track the toast bubble's actual frame in window coordinates (reported
/// from SwiftUI via a `PreferenceKey`) and only accept hits that land inside
/// that frame. SwiftUI then dispatches the tap to the right control, while
/// taps outside the bubble cleanly pass through.
final class ToastPassthroughWindow: UIWindow {
    var toastFrame: CGRect = .zero

    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !toastFrame.isEmpty, toastFrame.contains(point) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

/// Preference key the SwiftUI toast view uses to report its bubble frame
/// (in global coordinates) up to the window manager.
struct ToastFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

@MainActor
class ToastWindowManager: ObservableObject {
    static let shared = ToastWindowManager()

    private var toastWindow: ToastPassthroughWindow?
    private var activeAlertId: UUID?

    private init() {}

    func showToast(_ alert: RLAppAlert, onDismiss: @escaping () -> Void) {
        activeAlertId = alert.id

        // Create window if needed (passthrough so touches outside the toast
        // bubble still reach the app underneath).
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

        // Capture-frame container: ErrorToastView reports its rendered
        // frame in global coordinates so the window can hit-test against it.
        let toastView = VStack {
            Spacer()
            ErrorToastView(alert: alert, onDismiss: { [weak self] in
                guard let self = self else { return }
                if self.activeAlertId == alert.id {
                    onDismiss()
                    self.hideToast()
                }
            })
            .padding(.bottom, 20)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ToastFrameKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
        }
        .onPreferenceChange(ToastFrameKey.self) { [weak self] frame in
            self?.toastWindow?.toastFrame = frame
        }

        let hostingController = UIHostingController(rootView: toastView)
        hostingController.view.backgroundColor = .clear

        window.rootViewController = hostingController
        window.isHidden = false

        // Animate in
        window.alpha = 0
        UIView.animate(withDuration: 0.3) {
            window.alpha = 1
        }
    }

    func hideToast() {
        guard let window = toastWindow else { return }
        activeAlertId = nil

        UIView.animate(withDuration: 0.3, animations: {
            window.alpha = 0
        }) { _ in
            window.isHidden = true
            window.rootViewController = nil
            window.toastFrame = .zero
        }
    }
}
