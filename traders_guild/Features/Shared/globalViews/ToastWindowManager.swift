//
//  GlobalAlertModifier.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI
import UIKit

/// Window that only accepts touches in the bottom toast region so the rest of the app stays interactive.
private final class ToastPassthroughWindow: UIWindow {
    /// Height of the bottom strip where the toast lives; touches outside pass through.
    private let toastRegionHeight: CGFloat = 140

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let inToastRegion = point.y >= bounds.maxY - toastRegionHeight
        guard inToastRegion else { return nil }

        let hitView = super.hitTest(point, with: event)
        if hitView === rootViewController?.view {
            return nil
        }
        return hitView
    }
}

@MainActor
class ToastWindowManager: ObservableObject {
    static let shared = ToastWindowManager()
    
    private var toastWindow: UIWindow?
    private var activeAlertId: UUID?
    
    private init() {}
    
    func showToast(_ alert: RLAppAlert, onDismiss: @escaping () -> Void) {
        activeAlertId = alert.id

        // Create window if needed (passthrough so touches outside toast don't block app)
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
        
        // ✅ Uses your ErrorToastView!
        let toastView = VStack {
            Spacer()
            ErrorToastView(alert: alert, onDismiss: {
                if self.activeAlertId == alert.id {
                    onDismiss()
                    self.hideToast()
                }
            })
            .padding(.bottom, 20)
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
        }
    }
}

//struct GlobalAlertModifier: ViewModifier {
//    @EnvironmentObject var appState: AppState
//    
//    func body(content: Content) -> some View {
//        ZStack {
//            content
//            
//            // Toast overlay
//            if let alert = appState.currentAlert, alert.style == .toast {
//                VStack {
//                    Spacer()
//                    ErrorToastView(alert: alert, onDismiss: {
//                        appState.clearAlert()
//                    })
//                    .padding(.bottom, 20)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//                }
//                .animation(.spring(), value: appState.currentAlert?.id)
//            }
//        }
//    }
//}
//
//extension View {
//    func withGlobalAlerts() -> some View {
//        self.modifier(GlobalAlertModifier())
//    }
//}
