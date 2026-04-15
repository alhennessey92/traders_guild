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
    @State private var joinQuestions: [String] = []
    @State private var initialJoinQuestionPrompts: [String] = []
    @State private var isSubmitting = false

    private var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count >= 3
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedJoinQuestionPrompts: [String] {
        joinQuestions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var normalizedJoinQuestions: [RLGuildJoinQuestionInputDTO] {
        normalizedJoinQuestionPrompts.enumerated().map { index, prompt in
            RLGuildJoinQuestionInputDTO(prompt: prompt, isRequired: true, displayOrder: index)
        }
    }

    private var hasSettingsChanges: Bool {
        guard let guild = rlAppState.currentGuild else { return false }
        return trimmedName != guild.name
            || trimmedDescription != (guild.description ?? "")
            || isOpen != guild.isOpen
    }

    private var hasJoinQuestionChanges: Bool {
        normalizedJoinQuestionPrompts != initialJoinQuestionPrompts
    }

    private var hasChanges: Bool {
        hasSettingsChanges || hasJoinQuestionChanges
    }

    private var isMissingRequiredJoinQuestion: Bool {
        !isOpen && normalizedJoinQuestionPrompts.isEmpty
    }

    private var canSave: Bool {
        isValid && hasChanges && !isMissingRequiredJoinQuestion
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "gearshape.fill",
                    iconColor: .blue,
                    title: "Guild Details",
                    subtitle: "Review guild info and update editable fields"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                ScrollView {
                    VStack(spacing: 12) {
                        if let guild = rlAppState.currentGuild {
                            AdminSectionCard {
                                AdminInfoRow(title: "Owner", value: guild.ownerDisplayName ?? guild.ownerUsername ?? "Unknown")
                                AdminInfoRow(title: "Members", value: "\(guild.memberCount)")
                                AdminInfoRow(title: "Visibility", value: guild.isOpen ? "Open" : "Invite Only")
                                AdminInfoRow(title: "Created", value: guild.formattedDate)
                                if let language = guild.language, !language.isEmpty {
                                    AdminInfoRow(title: "Language", value: language)
                                }
                                if let location = guild.location, !location.isEmpty {
                                    AdminInfoRow(title: "Location", value: location)
                                }
                            }
                        }

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

                            if !isOpen {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Questions Required")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppColors.whiteText)

                                    Text("Invite-only guilds must include at least one question. Add up to 3 questions for applicants.")
                                        .font(.caption)
                                        .foregroundColor(
                                            isMissingRequiredJoinQuestion
                                                ? AppColors.statusNegative80
                                                : AppColors.greyText
                                        )

                                    if joinQuestions.isEmpty {
                                        Button {
                                            joinQuestions.append("")
                                        } label: {
                                            Label("Add Question", systemImage: "plus.circle")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(AppColors.guildReputationAccent)
                                        }
                                    } else {
                                        ForEach(joinQuestions.indices, id: \.self) { index in
                                            AdminJoinQuestionField(
                                                title: "Question \(index + 1)",
                                                text: $joinQuestions[index],
                                                canRemove: joinQuestions.count > 1,
                                                onRemove: {
                                                    joinQuestions.remove(at: index)
                                                }
                                            )
                                        }
                                    }

                                    if !joinQuestions.isEmpty && joinQuestions.count < 3 {
                                        Button {
                                            joinQuestions.append("")
                                        } label: {
                                            Label("Add Question", systemImage: "plus.circle")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(AppColors.guildReputationAccent)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                AdminFooterActions(
                    primaryTitle: "Save Details",
                    primaryDisabled: !canSave,
                    isSubmitting: isSubmitting,
                    onCancel: { dismiss() },
                    onPrimary: { Task { await saveSettings() } }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .adminSheetChrome(edge: .bottom)
            }

            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .task(id: rlAppState.currentGuild?.id) {
            await loadJoinQuestions()
        }
        .onAppear {
            guard let guild = rlAppState.currentGuild else { return }
            name = guild.name
            description = guild.description ?? ""
            isOpen = guild.isOpen
            if !guild.isOpen && joinQuestions.isEmpty {
                joinQuestions = [""]
            }
        }
        .onChange(of: isOpen) { _, newValue in
            guard !newValue, joinQuestions.isEmpty else { return }
            joinQuestions = initialJoinQuestionPrompts.isEmpty ? [""] : initialJoinQuestionPrompts
        }
    }

    private func saveSettings() async {
        guard isValid && hasChanges && !isSubmitting else { return }
        guard !isMissingRequiredJoinQuestion else {
            rlAppState.showError(
                title: "Join Question Required",
                message: "Add at least one join question before saving an invite-only guild.",
                style: .toast
            )
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            if !isOpen && hasJoinQuestionChanges {
                _ = try await rlAppState.updateGuildJoinQuestions(
                    questions: normalizedJoinQuestions,
                    showSuccessMessage: !hasSettingsChanges
                )
                initialJoinQuestionPrompts = normalizedJoinQuestionPrompts
            }

            if hasSettingsChanges {
                _ = try await rlAppState.updateGuild(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    isOpen: isOpen
                )
            }

            dismiss()
        } catch {
            // RLAppState handles toast error.
        }
    }

    @MainActor
    private func loadJoinQuestions() async {
        guard let guild = rlAppState.currentGuild else { return }

        do {
            let questions = try await rlAppState.getGuildJoinQuestions(guildId: guild.id)
            let prompts = questions
                .sorted { lhs, rhs in
                    if lhs.displayOrder == rhs.displayOrder {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.displayOrder < rhs.displayOrder
                }
                .map(\.prompt)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            initialJoinQuestionPrompts = prompts
            if !prompts.isEmpty || joinQuestions.isEmpty {
                joinQuestions = prompts.isEmpty ? (guild.isOpen ? [] : [""]) : prompts
            }
        } catch {
            initialJoinQuestionPrompts = []
            if !guild.isOpen && joinQuestions.isEmpty {
                joinQuestions = [""]
            }
        }
    }
}

private struct AdminInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct AdminJoinQuestionField: View {
    let title: String
    @Binding var text: String
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                TextField("Enter a join question", text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .foregroundColor(AppColors.whiteText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1)
                            )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.statusNegative80)
                        .padding(.top, 24)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
