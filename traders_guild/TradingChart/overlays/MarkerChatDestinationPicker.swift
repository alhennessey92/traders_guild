//
//  MarkerChatDestinationPicker.swift
//  traders_guild
//
//  Picks which in-guild conversation a marker is shared into: this symbol's
//  chart chat, or any of the guild's chatrooms.
//

import SwiftUI

/// Where a marker can be posted inside the guild.
enum MarkerChatDestination: Identifiable, Equatable {
    /// The chat attached to the marker's own symbol — the conversation already looking at it.
    case chartChat(symbolId: UUID, ticker: String?)
    case chatroom(RLGuildChatroomDTO)

    var id: String {
        switch self {
        case .chartChat(let symbolId, _): return "chart-\(symbolId.uuidString)"
        case .chatroom(let room): return "room-\(room.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .chartChat(_, let ticker):
            return ticker.map { "\($0) chart chat" } ?? "Chart chat"
        case .chatroom(let room):
            return room.name
        }
    }

    var subtitle: String {
        switch self {
        case .chartChat:
            return "Everyone reading this symbol's chart"
        case .chatroom(let room):
            if let description = room.description, !description.isEmpty { return description }
            return room.memberCount == 1 ? "1 member" : "\(room.memberCount) members"
        }
    }

    var icon: String {
        switch self {
        case .chartChat: return "chart.xyaxis.line"
        case .chatroom: return "number"
        }
    }

    static func == (lhs: MarkerChatDestination, rhs: MarkerChatDestination) -> Bool { lhs.id == rhs.id }
}

/// Sends the marker as a `MarkerShareCodec` token, exactly as the DM picker does — it renders
/// as a tappable marker card in the conversation and never navigates away from the chart.
struct MarkerChatDestinationPicker: View {
    let marker: RLChartMarkerDTO
    let symbolTicker: String?
    /// Optional caption written in the share prompt; sent as the visible message.
    var caption: String = ""
    @ObservedObject var appState: RLAppState
    /// Called after the picker dismisses (sent or cancelled) so the parent share sheet tears down.
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chatrooms: [RLGuildChatroomDTO] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = true
    @State private var isSending = false

    private var destinations: [MarkerChatDestination] {
        var all: [MarkerChatDestination] = [
            .chartChat(symbolId: marker.symbolId, ticker: symbolTicker)
        ]
        // A chatroom you cannot post in is not a destination.
        all.append(contentsOf: chatrooms.filter(\.canSendMessages).map { .chatroom($0) })
        return all
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.sheetBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accentColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(destinations) { destination in
                            Button { toggle(destination) } label: {
                                MarkerChatDestinationRow(
                                    destination: destination,
                                    isSelected: selected.contains(destination.id)
                                )
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(AppColors.surfaceWhite10)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Send to chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onClose()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending…" : "Send") {
                        Task { await send() }
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty || isSending)
                }
            }
            .task { await loadChatrooms() }
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ destination: MarkerChatDestination) {
        if selected.contains(destination.id) {
            selected.remove(destination.id)
        } else {
            selected.insert(destination.id)
        }
    }

    private func loadChatrooms() async {
        defer { isLoading = false }
        // The marker's own guild, not just the selected one: a marker opened from a shared
        // link can belong somewhere else.
        let guildId = marker.guildId
        // fetchGuildChatrooms already surfaces a toast on failure; the chart chat is still
        // offered on its own if the list cannot be read.
        chatrooms = (try? await appState.fetchGuildChatrooms(guildId: guildId)) ?? []
    }

    private func send() async {
        guard !selected.isEmpty else { return }
        isSending = true
        defer { isSending = false }

        let payload = MarkerSharePayloadV1(
            markerId: marker.id,
            symbolId: marker.symbolId,
            symbolTicker: symbolTicker,
            timeframe: marker.timeframe,
            candleTimestamp: marker.candleTimestamp,
            intent: marker.intent,
            alertSeverity: marker.alertSeverity
        )
        let content = MarkerShareCodec.buildMessage(
            note: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            payload: payload
        )

        var sentCount = 0
        var failedCount = 0
        for destination in destinations where selected.contains(destination.id) {
            do {
                switch destination {
                case .chartChat(let symbolId, _):
                    let chat = try await appState.getOrCreateChartChat(
                        guildId: marker.guildId,
                        symbolId: symbolId
                    )
                    _ = try await appState.sendChartChatMessage(chatId: chat.id, content: content)
                case .chatroom(let room):
                    _ = try await appState.sendChatroomMessage(chatroomId: room.id, content: content)
                }
                sentCount += 1
            } catch {
                failedCount += 1
            }
        }

        if sentCount > 0 {
            appState.showSuccess(sentCount == 1 ? "Marker shared." : "Marker shared to \(sentCount) chats.")
        }
        if failedCount > 0 {
            appState.showError(
                title: "Couldn’t share to \(failedCount) chat\(failedCount == 1 ? "" : "s")",
                message: "Please try again.",
                style: .toast
            )
        }

        dismiss()
        onClose()
    }
}

private struct MarkerChatDestinationRow: View {
    let destination: MarkerChatDestination
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppColors.surfaceWhite10)
                Image(systemName: destination.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(destination.subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? AppColors.accentColor : AppColors.secondaryForeground.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
