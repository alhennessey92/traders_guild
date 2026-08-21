//
//  MacRootView.swift
//  Traders Guild for macOS
//
//  Placeholder shell. The real three-column layout — left sidebar, chart pane
//  grid, right sidebar, top control bar, bottom inspector — lands in the shell
//  phase. For now this exists to prove the target boots, signs in against the
//  live backend, and that sandbox + keychain + ATS + the WebSocket all work,
//  which is where infrastructure surprises actually live.
//

import SwiftUI

struct MacRootView: View {

    @EnvironmentObject private var rlAppState: RLAppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Traders Guild")
                .font(.system(size: 34, weight: .heavy))

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                row("Session restored", rlAppState.isSessionRestored)
                row("Authenticated", rlAppState.isAuthenticated)
                GridRow {
                    Text("Signed in as").foregroundStyle(.secondary)
                    Text(rlAppState.currentUser?.username ?? "—")
                }
                GridRow {
                    Text("Guild").foregroundStyle(.secondary)
                    Text(rlAppState.currentGuild?.name ?? "—")
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding(20)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func row(_ label: String, _ value: Bool) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Label(
                value ? "yes" : "no",
                systemImage: value ? "checkmark.circle.fill" : "circle.dashed"
            )
            .foregroundStyle(value ? Color.green : Color.secondary)
        }
    }
}
