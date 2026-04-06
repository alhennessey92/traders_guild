//
//  ManageChatroomsView.swift
//  traders_guild
//
//  Owner/Admin chatroom management (create, edit, archive).
//

import SwiftUI

struct ManageChatroomsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rlAppState: RLAppState
    @EnvironmentObject private var rightDrawerViewModel: RLRightDrawerViewModel

    @State private var chatrooms: [RLGuildChatroomDTO] = []
    @State private var isLoading = true
    @State private var editorState: ChatroomEditorState?
    @State private var deletingChatroom: RLGuildChatroomDTO?
    @State private var processingChatroomId: UUID?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .cyan,
                    title: "Manage Chatrooms",
                    subtitle: "Create, edit, and archive channels"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
                .adminSheetChrome(edge: .top)

                content
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }

            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .task { await loadChatrooms() }
        .sheet(item: $editorState) { state in
            ChatroomEditorSheet(
                title: state.title,
                buttonTitle: state.buttonTitle,
                initialName: state.initialName,
                initialDescription: state.initialDescription,
                initialIcon: state.initialIcon
            ) { name, description, icon in
                await saveEditor(state: state, name: name, description: description, icon: icon)
            }
            .presentationDetents([.medium, .large])
        }
        .alert(
            "Archive Chatroom",
            isPresented: Binding(
                get: { deletingChatroom != nil },
                set: { presented in
                    if !presented { deletingChatroom = nil }
                }
            ),
            presenting: deletingChatroom
        ) { chatroom in
            Button("Archive", role: .destructive) {
                Task { await archiveChatroom(chatroom) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { chatroom in
            Text("Archive \(chatroom.displayIcon) \(chatroom.name)? Existing messages remain available.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading chatrooms...")
                    .tint(AppColors.accentColor)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                AdminSectionCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Guild Channels")
                                .font(.headline)
                                .foregroundColor(AppColors.whiteText)
                            Text("\(chatrooms.count) active chatroom\(chatrooms.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        Spacer()
                        Button {
                            editorState = .create
                        } label: {
                            Label("New", systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                }

                if chatrooms.isEmpty {
                    UnifiedEmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Chatrooms",
                        subtitle: "Create your first guild chatroom."
                    )
                    .padding(.top, 30)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(chatrooms) { chatroom in
                                chatroomRow(chatroom)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }

    private func chatroomRow(_ chatroom: RLGuildChatroomDTO) -> some View {
        AdminSectionCard {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(chatroom.isActive ? AppColors.bullCandleGreen : AppColors.greyText)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(chatroom.displayIcon) \(chatroom.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.whiteText)
                        if chatroom.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        if chatroom.isMuted {
                            Image(systemName: "speaker.slash.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    Text(chatroom.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (chatroom.description ?? "") : "No description yet")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)

                    Text(chatroom.lastActivityFormatted)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText.opacity(0.9))
                }

                Spacer()

                if chatroom.canManageChatroom {
                    Menu {
                        Button {
                            editorState = .edit(chatroom)
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }

                        Button(role: .destructive) {
                            deletingChatroom = chatroom
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    } label: {
                        if processingChatroomId == chatroom.id {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppColors.primaryForeground)
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(AppColors.greyText)
                        }
                    }
                }
            }
        }
    }

    private func loadChatrooms() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await rlAppState.fetchCurrentGuildChatrooms()
            chatrooms = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            chatrooms = []
        }
    }

    private func saveEditor(
        state: ChatroomEditorState,
        name: String,
        description: String,
        icon: String
    ) async -> Bool {
        do {
            switch state {
            case .create:
                _ = try await rlAppState.createChatroom(name: name, description: description, icon: icon)
            case .edit(let chatroom):
                processingChatroomId = chatroom.id
                _ = try await rlAppState.updateChatroom(
                    chatroomId: chatroom.id,
                    name: name,
                    description: description,
                    icon: icon
                )
                processingChatroomId = nil
            }
            await refreshRightDrawerChatrooms()
            editorState = nil
            await loadChatrooms()
            return true
        } catch {
            processingChatroomId = nil
            return false
        }
    }

    private func archiveChatroom(_ chatroom: RLGuildChatroomDTO) async {
        deletingChatroom = nil
        processingChatroomId = chatroom.id
        defer { processingChatroomId = nil }

        do {
            try await rlAppState.deleteChatroom(chatroomId: chatroom.id)
            await refreshRightDrawerChatrooms()
            await loadChatrooms()
        } catch {
            // RLAppState handles toast
        }
    }

    private func refreshRightDrawerChatrooms() async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        await rightDrawerViewModel.refreshChatrooms(for: guildId, appState: rlAppState)
    }
}

private enum ChatroomEditorState: Identifiable {
    case create
    case edit(RLGuildChatroomDTO)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let chatroom):
            return "edit-\(chatroom.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: return "New Chatroom"
        case .edit: return "Edit Chatroom"
        }
    }

    var buttonTitle: String {
        switch self {
        case .create: return "Create Chatroom"
        case .edit: return "Save Changes"
        }
    }

    var initialName: String {
        switch self {
        case .create:
            return ""
        case .edit(let chatroom):
            return chatroom.name
        }
    }

    var initialDescription: String {
        switch self {
        case .create:
            return ""
        case .edit(let chatroom):
            return chatroom.description ?? ""
        }
    }

    var initialIcon: String {
        switch self {
        case .create:
            return "#"
        case .edit(let chatroom):
            return chatroom.displayIcon
        }
    }
}

private struct ChatroomEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let buttonTitle: String
    let initialName: String
    let initialDescription: String
    let initialIcon: String
    let onSave: (_ name: String, _ description: String, _ icon: String) async -> Bool

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var isSubmitting = false

    init(
        title: String,
        buttonTitle: String,
        initialName: String,
        initialDescription: String,
        initialIcon: String,
        onSave: @escaping (_ name: String, _ description: String, _ icon: String) async -> Bool
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.initialName = initialName
        self.initialDescription = initialDescription
        self.initialIcon = initialIcon
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _description = State(initialValue: initialDescription)
        _icon = State(initialValue: initialIcon)
    }

    private var isValid: Bool {
        ChatroomValidation.isValidName(name)
            && ChatroomValidation.isValidDescription(description)
            && ChatroomValidation.isValidIcon(icon)
    }

    private var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIcon = ChatroomValidation.fallbackIcon(for: icon)
        return trimmedName != initialName.trimmingCharacters(in: .whitespacesAndNewlines)
            || trimmedDescription != initialDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            || normalizedIcon != ChatroomValidation.fallbackIcon(for: initialIcon)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                AdminSectionCard {
                    AdminInputField(title: "Name", placeholder: "e.g. trade-ideas", text: $name)
                    AdminInputTextEditor(
                        title: "Description",
                        placeholder: "What should members use this channel for?",
                        text: $description
                    )
                    AdminInputField(
                        title: "Icon (1 character)",
                        placeholder: "#",
                        text: $icon
                    )
                }
                Spacer()
                AdminFooterActions(
                    primaryTitle: buttonTitle,
                    primaryDisabled: !isValid || !hasChanges,
                    isSubmitting: isSubmitting,
                    onCancel: { dismiss() },
                    onPrimary: { Task { await submit() } }
                )
                .adminSheetChrome(edge: .bottom)
            }
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(AdminSheetBackground())
            .onChange(of: icon) { _, newValue in
                let sanitized = ChatroomValidation.sanitizedIconInput(newValue)
                if sanitized != icon {
                    icon = sanitized
                }
            }
        }
    }

    private func submit() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIcon = ChatroomValidation.fallbackIcon(for: icon)
        let didSave = await onSave(trimmedName, trimmedDescription, finalIcon)
        isSubmitting = false
        if didSave {
            dismiss()
        }
    }
}
