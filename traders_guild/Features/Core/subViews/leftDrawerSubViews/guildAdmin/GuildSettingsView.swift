//
//  GuildSettingsView.swift
//  traders_guild
//
//  Admin Panel - Guild settings editor.
//

import SwiftUI

struct GuildSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rlAppState: RLAppState

    @State private var name = ""
    @State private var description = ""
    @State private var isOpen = true
    @State private var isSubmitting = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private var hasChanges: Bool {
        guard let guild = rlAppState.currentGuild else { return false }
        return name != guild.name
            || description != (guild.description ?? "")
            || isOpen != guild.isOpen
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "gearshape.fill",
                    iconColor: .blue,
                    title: "Guild Settings",
                    subtitle: "Update name, description, and visibility"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)

                Divider()
                    .background(AppColors.surfaceWhite15)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 12) {
                        AdminSectionCard {
                            AdminInputField(
                                title: "Guild Name",
                                placeholder: "Guild name",
                                text: $name
                            )
                            AdminInputTextEditor(
                                title: "Description (Optional)",
                                placeholder: "Tell members what this guild is about",
                                text: $description
                            )
                            AdminToggleRow(
                                title: "Open Guild",
                                subtitle: isOpen ? "Anyone can join" : "Invite only",
                                icon: isOpen ? "lock.open.fill" : "lock.fill",
                                iconColor: isOpen ? .green : .orange,
                                isOn: $isOpen
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                AdminFooterActions(
                    primaryTitle: "Save Settings",
                    primaryDisabled: !isValid || !hasChanges,
                    isSubmitting: isSubmitting,
                    onCancel: { dismiss() },
                    onPrimary: { Task { await saveSettings() } }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .onAppear {
            guard let guild = rlAppState.currentGuild else { return }
            name = guild.name
            description = guild.description ?? ""
            isOpen = guild.isOpen
        }
    }

    private func saveSettings() async {
        guard isValid && hasChanges && !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await rlAppState.updateGuild(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : description.trimmingCharacters(in: .whitespacesAndNewlines),
                isOpen: isOpen
            )
            dismiss()
        } catch {
            // RLAppState handles toast error.
        }
    }
}
