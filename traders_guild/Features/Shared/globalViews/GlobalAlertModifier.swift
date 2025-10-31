//
//  GlobalAlertModifier.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI

struct GlobalAlertModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // Toast overlay
            if let alert = appState.currentAlert, alert.style == .toast {
                VStack {
                    Spacer()
                    ErrorToastView(alert: alert, onDismiss: {
                        appState.clearAlert()
                    })
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: appState.currentAlert?.id)
            }
        }
    }
}

extension View {
    func withGlobalAlerts() -> some View {
        self.modifier(GlobalAlertModifier())
    }
}
