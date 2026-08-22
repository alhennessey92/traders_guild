//
//  MarkerDMRecipientPicker.swift
//  traders_guild
//
//  Multi-select guild-member picker for sharing a just-placed marker via DM.
//  Sends the marker as a MarkerShareCodec token (renders as a tappable marker
//  card in the recipient's DM) using the existing DM endpoints, then returns to
//  the chart — it never navigates into a chat thread.
//

import SwiftUI

struct MarkerDMRecipientPicker: View {
    let marker: RLChartMarkerDTO
    let symbolTicker: String?
    /// Optional caption written in the share prompt; sent as the DM's visible message.
    var caption: String = ""
    @ObservedObject var appState: RLAppState
    /// Called after the picker dismisses (sent or cancelled) so the parent
    /// share sheet can tear down too.
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var members: [RLGuildMemberDTO] = []
    @State private var selected: Set<UUID> = []   // userIds
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isSending = false

    private var filteredMembers: [RLGuildMemberDTO] {
        let base = members.filter {
            !$0.isBlocked && !$0.isBlockedBy && $0.userId != appState.currentUser?.id
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.displayName.lowercased().contains(query) || $0.username.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.sheetBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accentColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMembers.isEmpty {
                    Text("No guild members to share with yet.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryForeground)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(filteredMembers) { member in
                            Button { toggle(member) } label: {
                                MarkerDMRecipientRow(
                                    member: member,
                                    isSelected: selected.contains(member.userId)
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
            .navigationTitle("Send to guild")
            .platformNavigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search members")
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
            .task { await loadMembers() }
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ member: RLGuildMemberDTO) {
        if selected.contains(member.userId) {
            selected.remove(member.userId)
        } else {
            selected.insert(member.userId)
        }
    }

    private func loadMembers() async {
        guard let guildId = appState.currentGuild?.id else {
            isLoading = false
            return
        }
        defer { isLoading = false }
        do {
            // fetchGuildMembers already surfaces a toast on failure.
            let list = try await appState.fetchGuildMembers(guildId: guildId, skip: 0, limit: 100, search: nil)
            members = list.members
        } catch {
            // Swallowed — error already toasted by fetchGuildMembers.
        }
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
        for userId in selected {
            do {
                let thread = try await appState.fetchOrCreateDMThread(participantUserId: userId)
                _ = try await appState.sendDMMessage(threadId: thread.id, content: content)
                sentCount += 1
            } catch {
                failedCount += 1
            }
        }

        if sentCount > 0 {
            appState.showSuccess(sentCount == 1 ? "Marker sent." : "Marker sent to \(sentCount) members.")
        }
        if failedCount > 0 {
            appState.showError(
                title: "Couldn’t send to \(failedCount) member\(failedCount == 1 ? "" : "s")",
                message: "Please try again.",
                style: .toast
            )
        }

        dismiss()
        onClose()
    }
}

// MARK: - Row

private struct MarkerDMRecipientRow: View {
    let member: RLGuildMemberDTO
    let isSelected: Bool

    private var name: String {
        member.displayName.isEmpty ? member.username : member.displayName
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? AppColors.accentColor : AppColors.secondaryForeground.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var avatar: some View {
        ZStack {
            Circle().fill(AppColors.surfaceWhite10)
            if let urlStr = member.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initial
                }
            } else {
                initial
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            if member.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(AppColors.sheetBackground, lineWidth: 2))
            }
        }
    }

    private var initial: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.headline)
            .foregroundColor(AppColors.primaryForeground)
    }
}
