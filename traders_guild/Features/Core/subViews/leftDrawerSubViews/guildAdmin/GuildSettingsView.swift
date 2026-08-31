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
    @State private var pickedBannerImage: UIImage?
    @State private var bannerImageRemoved = false
    @State private var showBannerImagePicker = false

    // Discord destinations act immediately rather than waiting for "Save
    // Details". Webhook URLs remain write-only bearer secrets.
    @State private var discordChannels: [RLGuildDiscordChannelDTO] = []
    @State private var discordLabelInput = ""
    @State private var discordWebhookInput = ""
    @State private var discordBusy = false
    @State private var showDiscordAddForm = false
    @State private var showDiscordHowTo = false
    @State private var discordPendingRemoval: RLGuildDiscordChannelDTO?
    @State private var showDiscordRemoveConfirm = false
    @State private var discordPendingRename: RLGuildDiscordChannelDTO?
    @State private var discordRenameInput = ""
    @State private var showDiscordRenamePrompt = false

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

    /// True when a banner (newly picked or the guild's existing one) is in play.
    private var hasEffectiveBanner: Bool {
        if pickedBannerImage != nil { return true }
        if bannerImageRemoved { return false }
        return !((rlAppState.currentGuild?.bannerUrl ?? "").isEmpty)
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
        hasSettingsChanges || hasJoinQuestionChanges || hasCrestChanges || hasBannerChanges
    }

    private var hasBannerChanges: Bool {
        pickedBannerImage != nil
            || (bannerImageRemoved && !((rlAppState.currentGuild?.bannerUrl ?? "").isEmpty))
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
                            // The guild's permanent public address. Read-only in
                            // 1.1.7 — it is server-generated and unique, and
                            // renaming it would break links already shared.
                            if let handle = rlAppState.currentGuild?.shareURL {
                                Button {
                                    UIPasteboard.general.string = handle.absoluteString
                                    rlAppState.showSuccess("Guild handle copied")
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Guild handle")
                                                .font(.caption2)
                                                .foregroundColor(AppColors.greyText)
                                            Text(handle.absoluteString
                                                .replacingOccurrences(of: "https://", with: ""))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(AppColors.whiteText)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        Image(systemName: "doc.on.doc")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.guildReputationAccent)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppColors.whiteText.opacity(0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
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

                            Text("Your guild's emblem — shown everywhere your guild appears. Upload your own artwork to stand out; the shield symbols are a fallback.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            HStack {
                                Spacer()
                                crestPreview(size: 64)
                                Spacer()
                            }
                            .padding(.vertical, 2)

                            // Upload leads. Eight near-identical shields made
                            // every guild look the same, so the symbols are now
                            // the fallback for guilds without artwork, and read
                            // that way in the layout too.
                            Button {
                                showCrestImagePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text(hasEffectiveImage ? "Replace image" : "Upload an image")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(AppColors.guildReputationAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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
                                Text("Or choose a symbol")
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                    .padding(.top, 2)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(GuildCrestCatalog.offeredSymbolKeys, id: \.self) { key in
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
                        }

                        AdminSectionCard {
                            Text("Guild Banner")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.whiteText)

                            Text("The wide header across the top of your guild page. Without one it uses a gradient from your crest colour.")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)

                            GuildBannerView(
                                bannerUrl: pickedBannerImage == nil && !bannerImageRemoved
                                    ? rlAppState.currentGuild?.bannerUrl
                                    : nil,
                                crestColor: crestColor,
                                guildName: name,
                                height: 104
                            )
                            .overlay {
                                if let picked = pickedBannerImage {
                                    Image(uiImage: picked)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 104)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.vertical, 2)

                            Button {
                                showBannerImagePicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text(hasEffectiveBanner ? "Replace banner" : "Upload a banner")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(AppColors.guildReputationAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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

                            if hasEffectiveBanner {
                                Button {
                                    if pickedBannerImage != nil {
                                        pickedBannerImage = nil
                                    } else {
                                        bannerImageRemoved = true
                                    }
                                } label: {
                                    Label("Remove banner", systemImage: "xmark.circle.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(AppColors.statusNegative80)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        discordSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)

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
        .sheet(isPresented: $showBannerImagePicker) {
            SharedImagePicker(sourceType: .photoLibrary) { image in
                pickedBannerImage = image
                bannerImageRemoved = false
            }
        }
    }

    // MARK: - Discord channels

    /// Manage the guild's named Discord webhook destinations. A webhook is
    /// channel-bound in Discord, so connecting more channels means adding one
    /// webhook per destination.
    private var discordSection: some View {
        AdminSectionCard {
            HStack(spacing: 8) {
                Image("DiscordLogo")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundColor(AppColors.whiteText)
                Text("Discord")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                if !discordChannels.isEmpty {
                    Text("\(discordChannels.count) connected")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.guildReputationAccent)
                }
            }

            Text("Let members choose where marker and invite posts are sent.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            if !discordChannels.isEmpty {
                VStack(spacing: 10) {
                    ForEach(discordChannels) { channel in
                        discordChannelRow(channel)
                    }
                }
            }

            if showDiscordAddForm || discordChannels.isEmpty {
                AdminInputField(
                    title: "Channel label",
                    placeholder: "#signals",
                    text: $discordLabelInput
                )
                AdminInputField(
                    title: "Webhook URL",
                    placeholder: "https://discord.com/api/webhooks/…",
                    text: $discordWebhookInput
                )

                Button {
                    Task { await addDiscordChannel() }
                } label: {
                    discordButtonLabel("Add channel", tint: AppColors.guildReputationAccent)
                }
                .buttonStyle(.plain)
                .disabled(discordBusy || !canAddDiscordChannel)
            } else {
                Button {
                    showDiscordAddForm = true
                } label: {
                    Label("Add channel", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.guildReputationAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.guildReputationAccent.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(discordBusy)
            }

            discordHowToConnect
        }
        .task(id: rlAppState.currentGuild?.id) { await loadDiscordChannels() }
        .confirmationDialog(
            "Remove this Discord channel?",
            isPresented: $showDiscordRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove channel", role: .destructive) {
                if let channel = discordPendingRemoval {
                    Task { await removeDiscordChannel(channel) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The webhook is forgotten. If this is the default, another connected channel becomes default.")
        }
        .alert("Rename Discord channel", isPresented: $showDiscordRenamePrompt) {
            TextField("#signals", text: $discordRenameInput)
            Button("Rename") {
                if let channel = discordPendingRename {
                    Task { await renameDiscordChannel(channel) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use the channel name members will recognise in share pickers.")
        }
    }

    private var canAddDiscordChannel: Bool {
        !discordLabelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !discordWebhookInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func discordChannelRow(_ channel: RLGuildDiscordChannelDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(channel.displayLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.whiteText)
                        if channel.isDefault {
                            Text("Default")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(AppColors.guildReputationAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.guildReputationAccent.opacity(0.14)))
                        }
                    }
                    discordStatusPill(for: channel)
                }

                Spacer()

                Menu {
                    Button("Send test post", systemImage: "paperplane") {
                        Task { await sendDiscordTestPost(to: channel) }
                    }
                    if !channel.isDefault {
                        Button("Make default", systemImage: "star") {
                            Task { await makeDiscordDefault(channel) }
                        }
                    }
                    Button("Rename", systemImage: "pencil") {
                        discordPendingRename = channel
                        discordRenameInput = channel.label
                        showDiscordRenamePrompt = true
                    }
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        discordPendingRemoval = channel
                        showDiscordRemoveConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(AppColors.greyText)
                }
                .disabled(discordBusy)
            }

            if let masked = channel.webhookMasked {
                Text(masked)
                    .font(.caption2.monospaced())
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let reason = channel.lastFailureReason, channel.needsAttention {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(AppColors.statusWarning)
            }

        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.insetPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }

    private var discordHowToConnect: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDiscordHowTo.toggle()
                }
            } label: {
                HStack {
                    Label("How to connect a Discord channel", systemImage: "questionmark.circle")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: showDiscordHowTo ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(AppColors.greyText)
            }
            .buttonStyle(.plain)

            if showDiscordHowTo {
                Text("1. In Discord, open the channel's Settings.\n2. Choose Integrations → Webhooks → New Webhook.\n3. Copy the Webhook URL and paste it above.\n4. Repeat with a new webhook for each channel you want to offer.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func discordStatusPill(for channel: RLGuildDiscordChannelDTO) -> some View {
        let (label, color): (String, Color) = {
            switch channel.status {
            case "invalid": return ("Needs reconnecting", AppColors.statusNegative)
            case "failing": return ("Delivery failing", AppColors.statusWarning)
            default: return ("Connected", AppColors.statusPositive)
            }
        }()
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func discordButtonLabel(_ title: String, tint: Color) -> some View {
        Group {
            if discordBusy {
                ProgressView().tint(tint)
            } else {
                Text(title).font(.subheadline)
            }
        }
        .foregroundColor(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tint.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func replaceDiscordChannel(_ updated: RLGuildDiscordChannelDTO) {
        if let index = discordChannels.firstIndex(where: { $0.id == updated.id }) {
            discordChannels[index] = updated
        } else {
            discordChannels.append(updated)
        }
    }

    private func loadDiscordChannels() async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        if let response = try? await rlAppState.realApi.getGuildDiscordChannels(guildId: guildId) {
            discordChannels = response.channels
        }
    }

    private func addDiscordChannel() async {
        guard let guildId = rlAppState.currentGuild?.id, !discordBusy else { return }
        let label = discordLabelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let webhookURL = discordWebhookInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !webhookURL.isEmpty else { return }
        discordBusy = true
        defer { discordBusy = false }
        do {
            let channel = try await rlAppState.realApi.createGuildDiscordChannel(
                guildId: guildId,
                webhookUrl: webhookURL,
                label: label
            )
            replaceDiscordChannel(channel)
            discordLabelInput = ""
            discordWebhookInput = ""
            showDiscordAddForm = false
            showDiscordChannelCreationOutcome(channel)
        } catch {
            rlAppState.showError(error, title: "Couldn't add Discord channel", style: .toast)
            await loadDiscordChannels()
        }
    }

    /// The channel is persisted even when its automatic test delivery fails.
    /// Keep it visible for recovery, but never tell the admin an invalid or
    /// failing webhook connected successfully.
    private func showDiscordChannelCreationOutcome(_ channel: RLGuildDiscordChannelDTO) {
        switch channel.status {
        case "invalid":
            rlAppState.showError(
                title: "Discord channel saved, but the webhook is invalid",
                message: "Discord rejected the webhook for \(channel.displayLabel). Remove it and add a fresh Webhook URL.",
                style: .toast
            )
        case "failing":
            rlAppState.showInfo(
                "\(channel.displayLabel) was saved, but its test post failed. Use Send test post to retry."
            )
        case "active":
            rlAppState.showSuccess("\(channel.displayLabel) connected — check Discord for the test post")
        default:
            rlAppState.showInfo("\(channel.displayLabel) was saved. Send a test post to confirm delivery.")
        }
    }

    private func sendDiscordTestPost(to channel: RLGuildDiscordChannelDTO) async {
        guard let guildId = rlAppState.currentGuild?.id, !discordBusy else { return }
        discordBusy = true
        defer { discordBusy = false }
        do {
            replaceDiscordChannel(try await rlAppState.realApi.testGuildDiscordChannel(
                guildId: guildId,
                channelId: channel.id
            ))
            rlAppState.showSuccess("Test post sent to \(channel.displayLabel)")
        } catch {
            rlAppState.showError(error, title: "Test post failed", style: .toast)
            await loadDiscordChannels()
        }
    }

    private func makeDiscordDefault(_ channel: RLGuildDiscordChannelDTO) async {
        guard let guildId = rlAppState.currentGuild?.id, !discordBusy else { return }
        discordBusy = true
        defer { discordBusy = false }
        do {
            _ = try await rlAppState.realApi.updateGuildDiscordChannel(
                guildId: guildId,
                channelId: channel.id,
                isDefault: true
            )
            await loadDiscordChannels()
            rlAppState.showSuccess("\(channel.displayLabel) is now the default")
        } catch {
            rlAppState.showError(error, title: "Couldn't change the default channel", style: .toast)
            await loadDiscordChannels()
        }
    }

    private func renameDiscordChannel(_ channel: RLGuildDiscordChannelDTO) async {
        guard let guildId = rlAppState.currentGuild?.id, !discordBusy else { return }
        let label = discordRenameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        discordBusy = true
        defer { discordBusy = false }
        do {
            replaceDiscordChannel(try await rlAppState.realApi.updateGuildDiscordChannel(
                guildId: guildId,
                channelId: channel.id,
                label: label
            ))
            rlAppState.showSuccess("Discord channel renamed")
        } catch {
            rlAppState.showError(error, title: "Couldn't rename the channel", style: .toast)
            await loadDiscordChannels()
        }
    }

    private func removeDiscordChannel(_ channel: RLGuildDiscordChannelDTO) async {
        guard let guildId = rlAppState.currentGuild?.id, !discordBusy else { return }
        discordBusy = true
        defer { discordBusy = false }
        do {
            try await rlAppState.realApi.deleteGuildDiscordChannel(
                guildId: guildId,
                channelId: channel.id
            )
            discordChannels.removeAll { $0.id == channel.id }
            await loadDiscordChannels()
            rlAppState.showSuccess("\(channel.displayLabel) removed")
        } catch {
            rlAppState.showError(error, title: "Couldn't remove the Discord channel", style: .toast)
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
        let guildHadUploadedBanner = !((rlAppState.currentGuild?.bannerUrl ?? "").isEmpty)
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

            // The banner is a second, independent image: uploading one must
            // never disturb the emblem, and vice versa.
            if let banner = pickedBannerImage, let data = banner.jpegData(compressionQuality: 0.85) {
                _ = try await rlAppState.uploadGuildBanner(imageData: data)
                pickedBannerImage = nil
            } else if bannerImageRemoved && guildHadUploadedBanner {
                _ = try await rlAppState.removeGuildBanner()
                bannerImageRemoved = false
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
