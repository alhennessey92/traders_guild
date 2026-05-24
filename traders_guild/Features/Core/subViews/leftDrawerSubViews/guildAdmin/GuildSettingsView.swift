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
    @State private var selectedLanguageCode = ""
    @State private var selectedCountryCode = ""
    @State private var joinQuestions: [String] = []
    @State private var initialJoinQuestionPrompts: [String] = []
    @State private var isSubmitting = false
    @State private var crestSymbol = GuildCrestCatalog.defaultSymbolKey
    @State private var crestColor = GuildCrestCatalog.defaultColorKey
    @State private var pickedCrestImage: UIImage?
    @State private var crestImageRemoved = false
    @State private var showCrestImagePicker = false

    private var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count >= 3
    }

    /// True when an image (newly picked or the guild's existing one) is the
    /// effective emblem, so the symbol/colour pickers are hidden.
    private var hasEffectiveImage: Bool {
        if pickedCrestImage != nil { return true }
        if crestImageRemoved { return false }
        return !((rlAppState.currentGuild?.imageUrl ?? "").isEmpty)
    }

    private var crestSymbolOrColorChanged: Bool {
        guard let guild = rlAppState.currentGuild else { return false }
        return crestSymbol != (guild.crestSymbol ?? GuildCrestCatalog.defaultSymbolKey)
            || crestColor != (guild.crestColor ?? GuildCrestCatalog.defaultColorKey)
    }

    private var hasCrestChanges: Bool {
        guard let guild = rlAppState.currentGuild else { return false }
        if pickedCrestImage != nil { return true }
        if crestImageRemoved && !((guild.imageUrl ?? "").isEmpty) { return true }
        return crestSymbolOrColorChanged
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
            || selectedLanguageCode != LocaleOptionCatalog.languageCode(from: guild.language)
            || selectedCountryCode != LocaleOptionCatalog.countryCode(from: guild.location)
    }

    private var hasJoinQuestionChanges: Bool {
        normalizedJoinQuestionPrompts != initialJoinQuestionPrompts
    }

    private var hasChanges: Bool {
        hasSettingsChanges || hasJoinQuestionChanges || hasCrestChanges
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
                                let languageCode = LocaleOptionCatalog.languageCode(from: guild.language)
                                let countryCode = LocaleOptionCatalog.countryCode(from: guild.location)
                                if !languageCode.isEmpty {
                                    AdminInfoRow(title: "Language", value: LocaleOptionCatalog.languageLabel(for: languageCode))
                                }
                                if !countryCode.isEmpty {
                                    AdminInfoRow(title: "Location", value: LocaleOptionCatalog.countryDisplay(for: countryCode))
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
                            AdminLocalePickerField(
                                title: "Language",
                                value: selectedLanguageCode.isEmpty ? "Not specified" : LocaleOptionCatalog.languageLabel(for: selectedLanguageCode),
                                systemImage: "globe"
                            ) {
                                ForEach(LocaleOptionCatalog.languages) { option in
                                    Button(option.label) {
                                        selectedLanguageCode = option.code
                                    }
                                }
                            }
                            AdminLocalePickerField(
                                title: "Country",
                                value: selectedCountryCode.isEmpty ? "Not specified" : LocaleOptionCatalog.countryDisplay(for: selectedCountryCode),
                                systemImage: "mappin.and.ellipse"
                            ) {
                                ForEach(LocaleOptionCatalog.countries) { option in
                                    Button(LocaleOptionCatalog.countryDisplay(for: option.code)) {
                                        selectedCountryCode = option.code
                                    }
                                }
                            }

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

                        AdminSectionCard {
                            Text("Guild Crest")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.whiteText)

                            Text("Your guild's emblem — shown everywhere your guild appears.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            HStack {
                                Spacer()
                                crestPreview(size: 64)
                                Spacer()
                            }
                            .padding(.vertical, 2)

                            if hasEffectiveImage {
                                Button {
                                    if pickedCrestImage != nil {
                                        pickedCrestImage = nil
                                    } else {
                                        crestImageRemoved = true
                                    }
                                } label: {
                                    Label("Remove image", systemImage: "xmark.circle.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(AppColors.statusNegative80)
                                }
                                .buttonStyle(.plain)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(GuildCrestCatalog.symbolKeys, id: \.self) { key in
                                            Button { crestSymbol = key } label: {
                                                Image(systemName: GuildCrestCatalog.sfSymbol(for: key))
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundColor(GuildCrestCatalog.color(for: crestColor))
                                                    .frame(width: 44, height: 44)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(key == crestSymbol ? AppColors.guildReputationAccent.opacity(0.18) : Color.clear)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 10)
                                                                    .stroke(
                                                                        key == crestSymbol ? AppColors.guildReputationAccent : AppColors.surfaceWhite12,
                                                                        lineWidth: key == crestSymbol ? 1.5 : 1
                                                                    )
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }

                                HStack(spacing: 12) {
                                    ForEach(GuildCrestCatalog.colorKeys, id: \.self) { key in
                                        Button { crestColor = key } label: {
                                            Circle()
                                                .fill(GuildCrestCatalog.color(for: key))
                                                .frame(width: 26, height: 26)
                                                .overlay(Circle().stroke(AppColors.whiteText, lineWidth: key == crestColor ? 2 : 0))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }

                            Button {
                                showCrestImagePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Upload an image")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(AppColors.guildReputationAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.guildReputationAccent.opacity(0.14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.guildReputationAccent.opacity(0.5), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
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
            selectedLanguageCode = LocaleOptionCatalog.languageCode(from: guild.language)
            selectedCountryCode = LocaleOptionCatalog.countryCode(from: guild.location)
            crestSymbol = guild.crestSymbol ?? GuildCrestCatalog.defaultSymbolKey
            crestColor = guild.crestColor ?? GuildCrestCatalog.defaultColorKey
            if !guild.isOpen && joinQuestions.isEmpty {
                joinQuestions = [""]
            }
        }
        .onChange(of: isOpen) { _, newValue in
            guard !newValue, joinQuestions.isEmpty else { return }
            joinQuestions = initialJoinQuestionPrompts.isEmpty ? [""] : initialJoinQuestionPrompts
        }
        .sheet(isPresented: $showCrestImagePicker) {
            SharedImagePicker(sourceType: .photoLibrary) { image in
                pickedCrestImage = image
                crestImageRemoved = false
            }
        }
    }

    /// The guild emblem preview — newly picked image, the existing uploaded
    /// image (unless removed), else the symbol crest.
    @ViewBuilder
    private func crestPreview(size: CGFloat) -> some View {
        if let image = pickedCrestImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let urlString = rlAppState.currentGuild?.imageUrl,
                  !urlString.isEmpty,
                  !crestImageRemoved,
                  let url = URL(string: urlString) {
            CachedAvatarImage(url: url, size: size, initials: String(name.first ?? "G"))
        } else {
            GuildCrestView(
                crestSymbol: crestSymbol,
                crestColor: crestColor,
                fallbackInitial: name.first ?? "G",
                size: size
            )
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

        let guildHadUploadedImage = !((rlAppState.currentGuild?.imageUrl ?? "").isEmpty)
        let crestFieldsChanged = crestSymbolOrColorChanged

        do {
            if !isOpen && hasJoinQuestionChanges {
                _ = try await rlAppState.updateGuildJoinQuestions(
                    questions: normalizedJoinQuestions,
                    showSuccessMessage: !hasSettingsChanges && !crestFieldsChanged
                )
                initialJoinQuestionPrompts = normalizedJoinQuestionPrompts
            }

            if hasSettingsChanges || crestFieldsChanged {
                _ = try await rlAppState.updateGuild(
                    name: trimmedName,
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    isOpen: isOpen,
                    language: selectedLanguageCode.isEmpty ? nil : selectedLanguageCode,
                    location: selectedCountryCode.isEmpty ? nil : selectedCountryCode,
                    crestSymbol: crestSymbol,
                    crestColor: crestColor
                )
            }

            if let image = pickedCrestImage, let data = image.jpegData(compressionQuality: 0.85) {
                _ = try await rlAppState.uploadGuildAvatar(imageData: data)
                pickedCrestImage = nil
            } else if crestImageRemoved && guildHadUploadedImage {
                _ = try await rlAppState.removeGuildAvatar()
                crestImageRemoved = false
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

private struct AdminLocalePickerField<MenuContent: View>: View {
    let title: String
    let value: String
    let systemImage: String
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Menu {
                menuContent()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundColor(AppColors.guildReputationAccent)
                        .frame(width: 20)

                    Text(value)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.whiteText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.insetPanelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                        )
                )
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
