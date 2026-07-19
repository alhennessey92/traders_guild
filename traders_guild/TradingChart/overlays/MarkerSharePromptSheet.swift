//
//  MarkerSharePromptSheet.swift
//  traders_guild
//
//  Branded bottom sheet shown right after a guild-visible marker is placed,
//  offering to share it: to guild members via DM, to X, copy link, or the
//  native share sheet. Mirrors GuildInviteHubView's channel styling and reuses
//  MarkerShareKit / GuildInviteShare for the channel actions.
//

import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted by the chart after a guild-visible marker is placed. MainView
    /// presents `MarkerSharePromptSheet` in response so it stacks above the
    /// always-present chart bottom sheet — a sheet presented from inside the
    /// chart contends with that one and floods the log on every live tick.
    static let presentMarkerSharePrompt = Notification.Name("presentMarkerSharePrompt")
}

/// userInfo key carrying the `MarkerShareContext` on `.presentMarkerSharePrompt`.
enum MarkerSharePromptNotification {
    static let contextKey = "shareContext"
}

/// `.sheet(item:)` payload describing the marker to share.
struct MarkerShareContext: Identifiable {
    let id = UUID()
    let marker: RLChartMarkerDTO
    let symbolTicker: String?

    /// Private markers can't be viewed by others, so the guild-DM channel is hidden.
    var isGuildVisible: Bool { marker.visibility == "guild" }
}

struct MarkerSharePromptSheet: View {
    let context: MarkerShareContext
    @ObservedObject var appState: RLAppState

    @Environment(\.dismiss) private var dismiss
    @State private var showRecipientPicker = false
    @State private var caption = ""

    private var shareURL: URL { MarkerShare.markerShareURL(markerId: context.marker.id) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.surfaceWhite20)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            VStack(spacing: 6) {
                Text("Marker placed")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Share it with your guild or the world.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 16)

            TextField("Add a message (optional)", text: $caption, axis: .vertical)
                .lineLimit(1...3)
                .textInputAutocapitalization(.sentences)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surfaceWhite08)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .onChange(of: caption) { _, newValue in
                    if newValue.count > 280 { caption = String(newValue.prefix(280)) }
                }

            HStack(alignment: .top, spacing: 12) {
                if context.isGuildVisible {
                    channel(label: "Guild DM", systemImage: "person.2.fill") {
                        showRecipientPicker = true
                    }
                }
                channel(label: "Post to X", xGlyph: true) { shareToX() }
                channel(label: "Copy link", systemImage: "link") { copyLink() }
                channel(label: "More", systemImage: "square.and.arrow.up") { shareMore() }
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 12)

            Button { dismiss() } label: {
                Text("Not now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.secondaryForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(InvitePressStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .presentationDetents([.height(context.isGuildVisible ? 412 : 394)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRecipientPicker) {
            MarkerDMRecipientPicker(
                marker: context.marker,
                symbolTicker: context.symbolTicker,
                caption: caption,
                appState: appState
            ) {
                // After the picker sends/cancels, close the whole prompt too.
                dismiss()
            }
        }
    }

    // MARK: - Channel button

    private func channel(
        label: String,
        systemImage: String? = nil,
        xGlyph: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppColors.surfaceWhite08)
                        .frame(width: 58, height: 58)
                    if xGlyph {
                        Text("𝕏")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppColors.primaryForeground)
                    } else if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.accentColor)
                    }
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(InvitePressStyle())
    }

    // MARK: - Actions

    private func shareToX() {
        GuildInviteShare.openAppOrWeb(
            MarkerShare.xAppURL(symbolTicker: context.symbolTicker, caption: caption, url: shareURL),
            fallback: MarkerShare.xComposeURL(symbolTicker: context.symbolTicker, caption: caption, url: shareURL)
        )
        dismiss()
    }

    private func copyLink() {
        UIPasteboard.general.string = shareURL.absoluteString
        appState.showSuccess("Marker link copied")
        dismiss()
    }

    private func shareMore() {
        // Presented via UIKit on top of this sheet (same approach as the invite
        // hub) — do NOT dismiss first, or the activity sheet is torn down with us.
        let item = MarkerShareItem(url: shareURL, symbolTicker: context.symbolTicker, caption: caption)
        MarkerShare.presentNativeShareSheet(for: item)
    }
}
