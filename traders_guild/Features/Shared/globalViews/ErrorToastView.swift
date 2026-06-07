
//
//  ErrorToastView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/10/2025.
//

import SwiftUI

/// Full-width toast bar pinned to the very bottom of the screen. The solid
/// severity colour bleeds edge-to-edge and into the bottom safe area (so it
/// reaches the device's rounded bottom corners); `bottomInset` keeps the text
/// above the home indicator. Hosted (and animated in/out) by `ToastWindowManager`.
struct ErrorToastView: View {
    let alert: RLAppAlert
    /// Bottom safe-area inset (home indicator) supplied by the host window.
    var bottomInset: CGFloat = 0
    let onDismiss: () -> Void

    private var foreground: Color { alert.severity.toastForeground }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.severity.icon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(foreground)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                if !alert.title.isEmpty {
                    Text(alert.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(foreground)
                }
                Text(alert.message)
                    .font(.footnote)
                    .foregroundColor(foreground.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(5)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(foreground.opacity(0.85))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        // Sit just above the home indicator. On devices with no indicator, 16pt.
        .padding(.bottom, bottomInset > 0 ? max(bottomInset - 12, 14) : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alert.severity.toastBackground)
        // The hosting controller would otherwise add the bottom safe-area inset
        // on top of our own bottom padding (double spacing → text floats high).
        // We handle the home-indicator clearance ourselves via `bottomInset`.
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            // Auto-dismiss after 4 seconds (the window animates the slide-out).
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDismiss()
            }
        }
    }
}
