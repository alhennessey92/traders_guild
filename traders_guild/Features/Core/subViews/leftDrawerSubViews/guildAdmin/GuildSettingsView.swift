//
//  GuildSettingsView.swift
//  traders_guild
//
//  Admin Panel - Guild Settings View
//  Update guild name, description, and visibility
//

import SwiftUI

struct GuildSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isOpen: Bool = true
    @State private var isSubmitting: Bool = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        name.count >= 3
    }

    private var hasChanges: Bool {
        guard let guild = rlAppState.currentGuild else { return false }
        return name != guild.name ||
               description != (guild.description ?? "") ||
               isOpen != guild.isOpen
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    UnifiedIconBadge(
                        icon: "gearshape.fill",
                        color: .blue,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guild Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Update your guild's details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // Form
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Guild Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            TextField("Guild name...", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Description Field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("(Optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }

                        // Open/Closed Toggle
                        Toggle(isOn: $isOpen) {
                            HStack(spacing: 8) {
                                Image(systemName: isOpen ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isOpen ? .green : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Open Guild")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(isOpen ? "Anyone can join" : "Invite only")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Spacer()

                Divider()

                // Action Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: saveSettings) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Saving..." : "Save Settings")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || !hasChanges || isSubmitting)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal)
            .padding(.bottom, 20)

            // Dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {
            if let guild = rlAppState.currentGuild {
                name = guild.name
                description = guild.description ?? ""
                isOpen = guild.isOpen
            }
        }
    }

    private func saveSettings() {
        guard isValid && hasChanges else { return }
        isSubmitting = true

        Task {
            do {
                _ = try await rlAppState.updateGuild(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    isOpen: isOpen
                )
                dismiss()
            } catch {
                isSubmitting = false
            }
        }
    }
}
