//
//  ChatComponents.swift
//  traders_guild
//
//  Unified chat UI components for consistent styling across:
//  - Guild chatrooms
//  - Direct messages (DM)
//  - Chart-specific chats
//  - Marker comments
//
//  All chat interfaces should use these components for consistency.
//  State management remains in individual managers (MessagingManager, ChartChatManager, etc.)

import SwiftUI
import UIKit

// MARK: - ================================================================================================
// MARK: - CHAT CONTEXT ENUM
// MARK: - ================================================================================================

/// Defines the context/type of chat for styling differences
enum ChatContext {
    case directMessage       // 1-1 chat - shows read receipts, no user info header
    case guildChatroom      // Group chat - shows username, role, reputation above bubble
    case chartChat          // Symbol-specific chat - similar to chatroom
    case markerComment      // Marker comments - simplified user info
    
    /// Whether to show user info row above message bubble (for non-current-user messages)
    var showsUserInfoHeader: Bool {
        switch self {
        case .directMessage: return false
        case .guildChatroom, .chartChat, .markerComment: return true
        }
    }
    
    /// Whether to show full user details (role, reputation)
    var showsFullUserDetails: Bool {
        switch self {
        case .directMessage, .markerComment: return false
        case .guildChatroom, .chartChat: return true
        }
    }
    
    /// Whether to show avatar for other users
    var showsAvatar: Bool { true }
    
    /// Whether to show read receipts (only for DMs)
    var showsReadReceipts: Bool {
        self == .directMessage
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT BUBBLE SHAPE
// MARK: - ================================================================================================

/// Unified bubble shape helper
struct ChatBubbleShape {
    static func bubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
        if isFromCurrentUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT AVATAR
// MARK: - ================================================================================================

/// Unified avatar view with online indicator
struct ChatAvatar: View {
    let initials: String
    var avatarURL: String? = nil
    let isOnline: Bool
    var size: CGFloat = 32
    var showOnlineIndicator: Bool = true
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .overlay(
                                Text(initials.uppercased())
                                    .font(size > 40 ? .caption : .caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accentColor)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials.uppercased())
                            .font(size > 40 ? .caption : .caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            if showOnlineIndicator {
                Circle()
                    .fill(isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(
                        Circle()
                            .stroke(AppColors.drawerBackground, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT INPUT FOOTER
// MARK: - ================================================================================================

/// Unified chat input footer - use across all chat interfaces
struct ChatAttachmentDraft: Equatable, Identifiable {
    let id: UUID
    let data: Data
    let filename: String
    let mimeType: String

    init(id: UUID = UUID(), data: Data, filename: String, mimeType: String) {
        self.id = id
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
}

struct ChatMarkerFilter: Equatable {
    var symbolId: UUID? = nil
    var timeframe: String? = nil

    func allows(_ marker: RLTopMarkerDTO) -> Bool {
        if let symbolId, marker.symbolId != symbolId {
            return false
        }
        if let timeframe, marker.timeframe.lowercased() != timeframe.lowercased() {
            return false
        }
        return true
    }
}

struct ChatMarkerLinkDraft: Equatable, Identifiable {
    let markerId: UUID
    let symbolId: UUID
    let symbolTicker: String
    let timeframe: String
    let candleTimestamp: Date
    let intent: String
    let createdAt: Date
    let notePreview: String?

    var id: UUID { markerId }

    var markerType: String { intent }

    var intentEnum: RLMarkerIntent {
        RLMarkerIntent(rawValue: intent) ?? .analysis
    }

    var payload: MarkerSharePayloadV1 {
        MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: symbolId,
            symbolTicker: symbolTicker,
            timeframe: timeframe,
            candleTimestamp: candleTimestamp,
            markerType: intent,
            intent: intent
        )
    }

    init(marker: RLTopMarkerDTO) {
        self.markerId = marker.id
        self.symbolId = marker.symbolId
        self.symbolTicker = marker.symbolTicker
        self.timeframe = marker.timeframe
        self.candleTimestamp = marker.candleTimestamp
        self.intent = marker.intent
        self.createdAt = marker.createdAt
        self.notePreview = marker.notePreview
    }
}

struct ChatReplyDraft: Equatable, Identifiable {
    let messageId: UUID
    let authorDisplayName: String
    let contentPreview: String
    let attachmentType: String?
    let attachmentName: String?

    var id: UUID { messageId }

    var accessoryText: String {
        if let attachmentName, !attachmentName.isEmpty {
            return attachmentName
        }
        return contentPreview
    }
}

struct ChatComposerPayload: Equatable {
    let text: String
    let attachment: ChatAttachmentDraft?
    let markerShareDraft: ChatMarkerLinkDraft?
    let replyDraft: ChatReplyDraft?

    var attachments: [ChatAttachmentDraft] {
        attachment.map { [$0] } ?? []
    }

    init(
        text: String,
        attachment: ChatAttachmentDraft?,
        markerShareDraft: ChatMarkerLinkDraft? = nil,
        replyDraft: ChatReplyDraft? = nil
    ) {
        self.text = text
        self.attachment = attachment
        self.markerShareDraft = markerShareDraft
        self.replyDraft = replyDraft
    }

    var hasBodyContent: Bool {
        !text.isEmpty || markerShareDraft != nil
    }

    func encodedContent(fallback: String = "") -> String {
        let note = text.isEmpty ? fallback : text
        guard let markerShareDraft else { return note }
        return MarkerShareCodec.buildMessage(note: note, payload: markerShareDraft.payload)
    }
}

extension ChatReplyDraft {
    init<Message: RLChatMessageDisplayable>(message: Message) {
        self.messageId = message.id
        self.authorDisplayName = message.authorUsername
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contentPreview = message.content
        } else if let attachmentName = message.attachmentName, !attachmentName.isEmpty {
            self.contentPreview = attachmentName
        } else {
            self.contentPreview = "Attachment"
        }
        self.attachmentType = message.attachmentType
        self.attachmentName = message.attachmentName
    }
}

struct MarkerSharePayloadV1: Codable, Equatable, Hashable {
    let markerId: UUID
    let symbolId: UUID
    let symbolTicker: String?
    let timeframe: String
    let candleTimestamp: Date
    let markerType: String?
    let intent: String?

    var intentEnum: RLMarkerIntent {
        if let intent, let intentEnum = RLMarkerIntent(rawValue: intent) {
            return intentEnum
        }
        if let markerType, let legacyIntent = Self.legacyIntent(from: markerType) {
            return legacyIntent
        }
        return .analysis
    }

    private static func legacyIntent(from markerType: String) -> RLMarkerIntent? {
        switch markerType.lowercased() {
        case "entry", "exit", "stop_loss", "take_profit", "prediction", "setup":
            return .setup
        case "alert":
            return .alert
        case "question":
            return .question
        case "poll":
            return .poll
        case "emoji", "reaction":
            return .reaction
        case "personal":
            return .personal
        case "news":
            return .news
        case "note", "analysis", "support", "resistance", "trendline", "pattern", "indicator", "volume_spike":
            return .analysis
        default:
            return nil
        }
    }

    init(
        markerId: UUID,
        symbolId: UUID,
        symbolTicker: String?,
        timeframe: String,
        candleTimestamp: Date,
        markerType: String? = nil,
        intent: String? = nil
    ) {
        self.markerId = markerId
        self.symbolId = symbolId
        self.symbolTicker = symbolTicker
        self.timeframe = timeframe
        self.candleTimestamp = candleTimestamp
        self.markerType = markerType
        self.intent = intent
    }

    var notificationUserInfo: [String: Any] {
        var info: [String: Any] = [
            "markerId": markerId.uuidString,
            "symbolId": symbolId.uuidString,
            "timeframe": timeframe,
            "candleTimestamp": candleTimestamp
        ]
        if let symbolTicker {
            info["symbolTicker"] = symbolTicker
        }
        if let markerType {
            info["markerType"] = markerType
        }
        if let intent {
            info["intent"] = intent
        }
        return info
    }

    init?(_ userInfo: [AnyHashable: Any]) {
        guard
            let markerIdRaw = userInfo["markerId"] as? String,
            let markerId = UUID(uuidString: markerIdRaw),
            let symbolIdRaw = userInfo["symbolId"] as? String,
            let symbolId = UUID(uuidString: symbolIdRaw),
            let timeframe = userInfo["timeframe"] as? String
        else {
            return nil
        }

        let candleTimestamp: Date
        if let date = userInfo["candleTimestamp"] as? Date {
            candleTimestamp = date
        } else if let value = userInfo["candleTimestamp"] as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: value) {
                candleTimestamp = parsed
            } else {
                iso.formatOptions = [.withInternetDateTime]
                guard let parsed = iso.date(from: value) else { return nil }
                candleTimestamp = parsed
            }
        } else {
            return nil
        }

        self.markerId = markerId
        self.symbolId = symbolId
        self.symbolTicker = userInfo["symbolTicker"] as? String
        self.timeframe = timeframe
        self.candleTimestamp = candleTimestamp
        self.markerType = userInfo["markerType"] as? String
        self.intent = userInfo["intent"] as? String
    }
}

enum MarkerShareCodec {
    private static let tokenPrefix = "[[TG_MARKER_SHARE_V1:"
    private static let tokenSuffix = "]]"

    static func buildMessage(note: String, payload: MarkerSharePayloadV1) -> String {
        guard let token = encodedToken(for: payload) else {
            let fallback = note.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? "Shared marker \(payload.markerId.uuidString.prefix(8).uppercased())" : fallback
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.isEmpty {
            return token
        }
        return "\(trimmedNote)\n\n\(token)"
    }

    static func extract(from content: String) -> (payload: MarkerSharePayloadV1, visibleText: String)? {
        guard let start = content.range(of: tokenPrefix) else { return nil }
        guard let suffixRange = content[start.upperBound...].range(of: tokenSuffix) else { return nil }

        let encoded = String(content[start.upperBound..<suffixRange.lowerBound])
        guard let payload = decodePayload(from: encoded) else { return nil }

        var visible = content
        visible.removeSubrange(start.lowerBound..<suffixRange.upperBound)
        visible = visible.trimmingCharacters(in: .whitespacesAndNewlines)
        return (payload, visible)
    }

    private static func encodedToken(for payload: MarkerSharePayloadV1) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return nil }
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(tokenPrefix)\(encoded)\(tokenSuffix)"
    }

    private static func decodePayload(from encoded: String) -> MarkerSharePayloadV1? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid marker share date \(dateString)"
                )
            }
            return date
        }
        return try? decoder.decode(MarkerSharePayloadV1.self, from: data)
    }
}

struct ChatInputFooter: View {
    @Binding var messageText: String
    var replyDraft: Binding<ChatReplyDraft?>? = nil
    let placeholder: String
    let isSending: Bool
    let onSend: (ChatComposerPayload) -> Void
    var allowsMarkerLinkAttachment: Bool = false
    var markerFilter: ChatMarkerFilter? = nil

    /// Optional: For sheet contexts where we need to expand to full height
    var selectedDetent: Binding<PresentationDetent>? = nil
    var expandedDetent: PresentationDetent = .large

    /// Optional leading accessory view (e.g. back button in chart chat)
    var leadingAccessory: AnyView? = nil

    /// Optional binding to observe/control attachment panel visibility from parent views.
    /// Parents can use this to dismiss the panel when the chat background is tapped.
    var isActionPanelVisible: Binding<Bool>? = nil

    @EnvironmentObject private var appState: RLAppState

    @FocusState private var isInputFocused: Bool

    @StateObject private var speechService = SpeechRecognitionService()

    @State private var showActionPanel = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showMarkerPicker = false
    @State private var selectedAttachment: ChatAttachmentDraft? = nil
    @State private var selectedMarkerDraft: ChatMarkerLinkDraft? = nil
    @State private var markerDrafts: [ChatMarkerLinkDraft] = []
    @State private var isLoadingMarkerDrafts = false
    @State private var markerPickerError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if speechService.isRecording {
                recordingIndicator
            }

            if replyDraft?.wrappedValue != nil || selectedAttachment != nil || selectedMarkerDraft != nil {
                attachmentDraftRow
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showActionPanel {
                attachmentActionPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.height > 40 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        showActionPanel = false
                                    }
                                }
                            }
                    )
            }

            Divider()
                .background(AppColors.surfaceGray30)

            HStack(spacing: 8) {
                if let leadingAccessory {
                    leadingAccessory
                }

                HStack(spacing: 12) {
                    Button {
                        HapticFeedback.light.trigger()
                        isInputFocused = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showActionPanel.toggle()
                        }
                    } label: {
                        Image(systemName: showActionPanel ? "xmark" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showActionPanel ? .white : .secondary)
                            .frame(width: 32, height: 32)
                            .background(showActionPanel ? AppColors.accentColor.opacity(0.8) : Color.clear)
                            .clipShape(Circle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .compositingGroup()

                    TextField(placeholder, text: $messageText)
                        .font(.subheadline)
                        .submitLabel(.send)
                        .focused($isInputFocused)
                        .disabled(isSending)
                        .onSubmit {
                            if canSend {
                                sendComposedMessage()
                            }
                        }
                        .onTapGesture {
                            if expandSheetIfNeeded() {
                                return
                            }
                            if showActionPanel {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showActionPanel = false
                                }
                            }
                        }

                    HStack(spacing: 8) {
                        Button(action: {
                            HapticFeedback.light.trigger()
                            speechService.toggleRecording()
                        }) {
                            Image(systemName: speechService.isRecording ? "mic.circle.fill" : "mic.fill")
                                .font(.title3)
                                .foregroundColor(speechService.isRecording ? .red : .secondary)
                                .frame(width: 32, height: 32)
                                .symbolEffect(.pulse, isActive: speechService.isRecording)
                        }
                        .compositingGroup()

                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 40, height: 40)
                        } else {
                            sendButton
                        }
                    }
                }
                .padding(.leading, 10)
                .frame(height: 44)
                .background(AppColors.whiteText.opacity(0.08))
                .cornerRadius(25)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppColors.sheetBackground)
        .compositingGroup()
        .onChange(of: showActionPanel) { _, newValue in
            isActionPanelVisible?.wrappedValue = newValue
        }
        .onChange(of: isActionPanelVisible?.wrappedValue) { _, newValue in
            if let newValue, newValue != showActionPanel {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showActionPanel = newValue
                }
            }
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                if messageText.isEmpty {
                    messageText = newValue
                } else {
                    let trimmedExisting = messageText.trimmingCharacters(in: .whitespaces)
                    messageText = trimmedExisting + " " + newValue
                }
            }
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            if !isRecording && !speechService.transcribedText.isEmpty {
                speechService.transcribedText = ""
            }
        }
        .onDisappear {
            speechService.cleanup()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(
                onImagesSelected: { selected in
                    showPhotoPicker = false
                    appendAttachments(selected)
                },
                onCancel: { showPhotoPicker = false },
                selectionLimit: 1
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCameraPicker) {
            SharedImagePicker(sourceType: .camera) { image in
                showCameraPicker = false
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                selectedAttachment = ChatAttachmentDraft(
                    data: data,
                    filename: "camera-\(UUID().uuidString.prefix(8)).jpg",
                    mimeType: "image/jpeg"
                )
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                onDocumentsSelected: { selected in
                    showDocumentPicker = false
                    appendAttachments(selected)
                },
                onCancel: { showDocumentPicker = false },
                selectionLimit: 1
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMarkerPicker) {
            ChatMarkerPickerSheet(
                markers: markerDrafts,
                isLoading: isLoadingMarkerDrafts,
                errorMessage: markerPickerError,
                onRetry: {
                    Task { await loadMarkerDrafts() }
                },
                onSelect: { draft in
                    selectedMarkerDraft = draft
                    showMarkerPicker = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @discardableResult
    private func expandSheetIfNeeded() -> Bool {
        guard let detent = selectedDetent,
              detent.wrappedValue != expandedDetent else {
            return false
        }
        detent.wrappedValue = expandedDetent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isInputFocused = true
        }
        return true
    }

    // MARK: - Action Panel (WhatsApp-style)

    private var attachmentActionPanel: some View {
        HStack(spacing: 0) {
            actionPanelButton(icon: "camera.fill", label: "Camera") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showActionPanel = false
                }
                showCameraPicker = true
            }

            actionPanelButton(icon: "photo.on.rectangle.angled", label: "Photos") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showActionPanel = false
                }
                showPhotoPicker = true
            }

            actionPanelButton(icon: "doc.fill", label: "Files") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showActionPanel = false
                }
                showDocumentPicker = true
            }

            if allowsMarkerLinkAttachment {
                actionPanelButton(icon: "target", label: "Marker") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showActionPanel = false
                    }
                    showMarkerPicker = true
                    Task { await loadMarkerDrafts() }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceWhite12, AppColors.surfaceWhite08],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func actionPanelButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.light.trigger()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.surfaceWhite92)
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(AppColors.surfaceWhite14)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.surfaceWhite24, lineWidth: 1)
                            )
                    )
                    .clipShape(Circle())

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppColors.surfaceWhite80)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppColors.statusNegative)
                .frame(width: 8, height: 8)
                .opacity(speechService.isRecording ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.isRecording)

            Text("Listening...")
                .font(.caption)
                .foregroundColor(.red)

            Spacer()

            if let errorMessage = speechService.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }

            Button(action: {
                speechService.stopRecording()
            }) {
                Text("Stop")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppColors.statusNegative10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
    }

    // MARK: - Send Button

    private var sendButton: some View {
        let isEmpty = !canSend

        return Button(action: sendComposedMessage) {
            Image(systemName: "chevron.forward.2")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                .frame(width: 40, height: 40)
                .padding(.leading, 2)
                .background(isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                .clipShape(Capsule())
        }
        .disabled(isEmpty)
        .compositingGroup()
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedAttachment != nil ||
        selectedMarkerDraft != nil
    }

    // MARK: - Attachment Draft Row

    private var attachmentDraftRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let replyDraft = replyDraft?.wrappedValue {
                replyPreviewChip(for: replyDraft)
            }

            HStack {
                Text(draftSummaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
                Spacer(minLength: 8)

                if selectedAttachment == nil {
                    Button {
                        HapticFeedback.light.trigger()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showActionPanel = true
                        }
                    } label: {
                        Text("Attach")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.accentColor)
                    }
                }

                Button("Remove all") {
                    withAnimation {
                        selectedAttachment = nil
                        selectedMarkerDraft = nil
                        replyDraft?.wrappedValue = nil
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.bearCandleRed.opacity(0.92))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let selectedAttachment {
                        attachmentPreviewChip(for: selectedAttachment)
                    }
                    if let selectedMarkerDraft {
                        markerPreviewChip(for: selectedMarkerDraft)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.unhighlightedTextBoxBackground.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }

    private var draftSummaryText: String {
        switch (selectedAttachment != nil, selectedMarkerDraft != nil, replyDraft?.wrappedValue != nil) {
        case (false, false, true):
            return "Reply ready"
        case (false, true, false):
            return "1 marker link ready"
        case (true, false, false):
            return "1 attachment ready"
        case (true, true, false):
            return "1 attachment + marker link ready"
        case (true, false, true):
            return "Reply + attachment ready"
        case (false, true, true):
            return "Reply + marker link ready"
        case (true, true, true):
            return "Reply + attachment + marker link ready"
        case (false, false, false):
            return "Draft ready"
        }
    }

    @ViewBuilder
    private func attachmentPreviewChip(for attachment: ChatAttachmentDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if attachment.isImage, let image = UIImage(data: attachment.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accentColor.opacity(0.92))
                        Text(attachment.filename)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.whiteText.opacity(0.92))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.whiteText.opacity(0.1))
                    )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.surfaceWhite20, lineWidth: 1)
            )

            Button {
                withAnimation { selectedAttachment = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(AppColors.surfaceBlack45, in: Circle())
            }
            .offset(x: 4, y: -4)
        }
    }

    private func replyPreviewChip(for replyDraft: ChatReplyDraft) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption)
                .foregroundColor(AppColors.accentColor.opacity(0.92))

            VStack(alignment: .leading, spacing: 2) {
                Text(replyDraft.authorDisplayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accentColor)
                Text(replyDraft.accessoryText)
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(0.92))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                withAnimation {
                    self.replyDraft?.wrappedValue = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(AppColors.surfaceBlack45, in: Circle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.surfaceWhite08)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                )
        )
    }

    private func markerPreviewChip(for marker: ChatMarkerLinkDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 8) {
                UnifiedMarkerBadge(
                    intent: marker.intentEnum,
                    sizeToken: .small
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Linked Marker")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                    Text("\(marker.symbolTicker) • \(marker.timeframe.uppercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.95))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.whiteText.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                    )
            )

            Button {
                withAnimation { selectedMarkerDraft = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(AppColors.surfaceBlack45, in: Circle())
            }
            .offset(x: 4, y: -4)
        }
    }

    // MARK: - Helpers

    private func appendAttachments(_ selected: [(Data, String, String)]) {
        guard selectedAttachment == nil,
              let first = selected.first else { return }
        selectedAttachment = ChatAttachmentDraft(
            data: first.0,
            filename: first.1,
            mimeType: first.2
        )
    }

    private func setReplyDraft(_ value: ChatReplyDraft?) {
        replyDraft?.wrappedValue = value
    }

    private func currentReplyDraft() -> ChatReplyDraft? {
        replyDraft?.wrappedValue
    }

    private func clearComposerDrafts() {
        messageText = ""
        selectedAttachment = nil
        selectedMarkerDraft = nil
        setReplyDraft(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showActionPanel = false
        }
    }

    @MainActor
    private func loadMarkerDrafts() async {
        guard allowsMarkerLinkAttachment else { return }
        guard let guildId = appState.currentGuild?.id,
              let userId = appState.currentUser?.id else {
            markerPickerError = "No guild or user context found."
            markerDrafts = []
            isLoadingMarkerDrafts = false
            return
        }

        isLoadingMarkerDrafts = true
        markerPickerError = nil

        do {
            let response = try await appState.realApi.getUserMarkers(guildId: guildId, userId: userId)
            let mapped = response.mine
                .filter { markerFilter?.allows($0) ?? true }
                .sorted { $0.createdAt > $1.createdAt }
                .map(ChatMarkerLinkDraft.init(marker:))
            markerDrafts = mapped
            isLoadingMarkerDrafts = false
        } catch {
            markerPickerError = "Failed to load markers."
            markerDrafts = []
            isLoadingMarkerDrafts = false
        }
    }

    private func sendComposedMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, (selectedAttachment != nil || !trimmed.isEmpty || selectedMarkerDraft != nil || currentReplyDraft() != nil) else { return }

        onSend(
            ChatComposerPayload(
                text: trimmed,
                attachment: selectedAttachment,
                markerShareDraft: selectedMarkerDraft,
                replyDraft: currentReplyDraft()
            )
        )

        clearComposerDrafts()
    }
}

private struct ChatMarkerPickerSheet: View {
    let markers: [ChatMarkerLinkDraft]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onSelect: (ChatMarkerLinkDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading markers...")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(AppColors.bearCandleRed)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText)
                        Button("Retry", action: onRetry)
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if markers.isEmpty {
                    ChatEmptyStateView(
                        icon: "target",
                        title: "No markers found",
                        subtitle: "Place a marker to share it in chat."
                    )
                } else {
                    List(markers) { marker in
                        Button {
                            onSelect(marker)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                UnifiedMarkerBadge(
                                    intent: marker.intentEnum,
                                    sizeToken: .medium
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(marker.symbolTicker) • \(marker.timeframe.uppercased())")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppColors.whiteText)
                                    Text(marker.intentEnum.displayName)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(marker.intentEnum.color.opacity(0.9))
                                    Text(marker.candleTimestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(AppColors.greyText)
                                    if let note = marker.notePreview, !note.isEmpty {
                                        Text(note)
                                            .font(.caption2)
                                            .foregroundColor(AppColors.greyText.opacity(0.9))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(ChatBackground())
                }
            }
            .navigationTitle("Link Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accentColor)
                }
            }
            .background(ChatBackground())
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT BACKGROUND
// MARK: - ================================================================================================

/// Unified chat background with material and pattern
struct ChatBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            StaticPatternView()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EMPTY & LOADING STATES
// MARK: - ================================================================================================

/// Unified loading view for chat
struct ChatLoadingView: View {
    var message: String = "Loading messages..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.accentColor)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Unified empty state view for chat
struct ChatEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    init(
        icon: String = "bubble.left.and.bubble.right",
        title: String = "No messages yet",
        subtitle: String = "Start the conversation!"
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accentColor.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT SCROLL VIEW
// MARK: - ================================================================================================

/// Unified scrollable messages container with auto-scroll behavior
struct ChatScrollView<Message: RLChatMessageDisplayable, Content: View>: View {
    let messages: [Message]
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottomImmediately(proxy: proxy)
            }
            .background(ChatBackground())
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func scrollToBottomImmediately(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EDIT MESSAGE SHEET
// MARK: - ================================================================================================

/// Unified edit message sheet - can be used for any message type
struct UnifiedEditMessageSheet: View {
    let originalContent: String
    let onSave: (String) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedText: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    init(originalContent: String, onSave: @escaping (String) async throws -> Void) {
        self.originalContent = originalContent
        self.onSave = onSave
        _editedText = State(initialValue: originalContent)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Message", text: $editedText, axis: .vertical)
                    .lineLimit(5...10)
                    .padding()
                    .background(AppColors.surfaceGray10)
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                isSaving = true
                                do {
                                    try await onSave(editedText)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isSaving = false
                            }
                        }
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT HEADER COMPONENTS
// MARK: - ================================================================================================

/// Generic chat header view - customize for specific chat types
struct ChatHeader<LeftContent: View, CenterContent: View, RightContent: View>: View {
    @ViewBuilder let leftContent: () -> LeftContent
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let rightContent: () -> RightContent
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                leftContent()
                Spacer()
                centerContent()
                Spacer()
                rightContent()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppColors.sheetBackground)
            
            Divider()
        }
    }
}

/// Standard dismiss button for chat sheets
struct ChatDismissButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

/// Standard back button for chat navigation
struct ChatBackButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.accentColor)
        }
    }
}

/// Settings button for chat header
struct ChatSettingsButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - ACTIVE USERS PILL
// MARK: - ================================================================================================

/// Active users indicator pill (for chart chat headers)
struct ActiveUsersPill: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 6, height: 6)
                
                Text("\(count) active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.surfaceWhite06)
            .clipShape(Capsule())
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CONVENIENCE EXTENSIONS
// MARK: - ================================================================================================

extension View {
    /// Apply standard chat sheet presentation modifiers
    func chatSheetPresentation() -> some View {
        self
            .presentationDetents([.fraction(0.9)])
            .presentationBackground {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                    AppColors.sheetBackground
                }
            }
            .presentationCornerRadius(33)
    }
    
    /// Hide keyboard helper
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ================================================================================================
// MARK: - RL MESSAGE PROTOCOL (for RLAppState-based messaging)
// MARK: - ================================================================================================

/// Protocol for RL message types - uses RLMemberRole instead of MemberRole
protocol RLChatMessageDisplayable: Identifiable {
    var id: UUID { get }
    var content: String { get }
    var timestampFormatted: String { get }
    var isEdited: Bool { get }
    var isCurrentUserMessage: Bool { get }
    var canEdit: Bool { get }
    var canDelete: Bool { get }

    // Author info
    var authorUsername: String { get }
    var authorInitials: String { get }
    var authorAvatarUrl: String? { get }
    var authorIsOnline: Bool { get }
    var authorRole: RLMemberRole { get }
    var authorReputation: Int { get }
    var authorAccuracy: Double? { get }
    var authorIsFriend: Bool { get }
    var authorIsBlocked: Bool { get }

    // Attachment info
    var attachmentUrl: String? { get }
    var attachmentType: String? { get }
    var attachmentName: String? { get }
    var replyPreview: RLMessageReplyPreviewDTO? { get }
    var reactions: [RLMessageReactionDTO] { get }
}

// MARK: - ================================================================================================
// MARK: - RL MESSAGE BUBBLE
// MARK: - ================================================================================================

enum ChatAuthorTapRouting {
    static func resolved(
        onAuthorTap: (() -> Void)?,
        onAvatarTap: (() -> Void)?
    ) -> (() -> Void)? {
        onAuthorTap ?? onAvatarTap
    }
}

/// RL version of ChatMessageBubble - works with RLAppState and RLMemberRole
struct RLChatMessageBubble<Message: RLChatMessageDisplayable>: View {
    let message: Message
    let context: ChatContext
    let isRead: Bool
    let onAvatarTap: (() -> Void)?
    let onAuthorTap: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReport: (() -> Void)?
    let onCopy: (() -> Void)?
    let onReply: (() -> Void)?
    let onToggleReaction: ((String) -> Void)?
    let onVisibleReactionTap: (() -> Void)?
    let onMarkerShareTap: ((MarkerSharePayloadV1) -> Void)?
    
    @EnvironmentObject var chatSurfaceOverlayCoordinator: ChatSurfaceOverlayCoordinator

    init(
        message: Message,
        context: ChatContext,
        isRead: Bool = false,
        onAvatarTap: (() -> Void)? = nil,
        onAuthorTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onReport: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil,
        onReply: (() -> Void)? = nil,
        onToggleReaction: ((String) -> Void)? = nil,
        onVisibleReactionTap: (() -> Void)? = nil,
        onMarkerShareTap: ((MarkerSharePayloadV1) -> Void)? = nil
    ) {
        self.message = message
        self.context = context
        self.isRead = isRead
        self.onAvatarTap = onAvatarTap
        self.onAuthorTap = onAuthorTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onReport = onReport
        self.onCopy = onCopy
        self.onReply = onReply
        self.onToggleReaction = onToggleReaction
        self.onVisibleReactionTap = onVisibleReactionTap
        self.onMarkerShareTap = onMarkerShareTap
    }

    private var resolvedAuthorTap: (() -> Void)? {
        ChatAuthorTapRouting.resolved(onAuthorTap: onAuthorTap, onAvatarTap: onAvatarTap)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isCurrentUserMessage {
                Spacer()
            } else if context.showsAvatar {
                avatarView
            }
            
            VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
                // User info header (for group chats, non-current user)
                if !message.isCurrentUserMessage && context.showsUserInfoHeader {
                    userInfoHeader
                }
                
                bubbleStack
            }
            
            if !message.isCurrentUserMessage {
                Spacer()
            }
        }
    }

    private var bubbleStack: some View {
        VStack(
            alignment: message.isCurrentUserMessage ? .trailing : .leading,
            spacing: 4
        ) {
            bubbleChrome
            timestampRow
        }
    }

    private var bubbleChrome: some View {
        VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: -6) {
            messageBubbleContent
                .onLongPressGesture(minimumDuration: 0.4) {
                    HapticFeedback.medium.trigger()
                    chatSurfaceOverlayCoordinator.presentActions(for: message.id)
                }

            if !message.reactions.isEmpty {
                reactionCluster
            }
        }
    }
    
    // MARK: - Avatar View
    @ViewBuilder
    private var avatarView: some View {
        Button(action: { resolvedAuthorTap?() }) {
            ChatAvatar(
                initials: message.authorInitials,
                avatarURL: message.authorAvatarUrl,
                isOnline: message.authorIsOnline,
                size: 32
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - User Info Header
    @ViewBuilder
    private var userInfoHeader: some View {
        if let resolvedAuthorTap {
            Button(action: resolvedAuthorTap) {
                userInfoHeaderContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            userInfoHeaderContent
        }
    }

    private var userInfoHeaderContent: some View {
        HStack(spacing: 2) {
            // Blocked indicator
            if message.authorIsBlocked {
                Image(systemName: "nosign")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.bearCandleRed)
            }
            
            // Username - always grey/white, NOT role colored
            Text(message.authorUsername)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(message.authorIsBlocked ? AppColors.greyText : AppColors.whiteText.opacity(0.9))
            
            // Friend indicator
            if message.authorIsFriend {
                Image(systemName: "person.crop.circle")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(message.authorIsBlocked ? AppColors.greyText : AppColors.friendAccent)
                    .padding(.leading, 3)
            }
            
            // Role · reputation · accuracy (unified with rest of app: announcements, markers, etc.)
            if context.showsFullUserDetails {
                UnifiedRoleBadge(
                    roleName: message.authorRole.displayName,
                    roleColor: message.authorRole.color,
                    reputation: message.authorReputation,
                    accuracy: message.authorAccuracy.map { "\(Int($0 * 100))%" },
                    showReputation: true,
                    fontSize: .caption,
                    iconSize: .caption2
                )
            }
        }
    }
    
    // MARK: - Message Bubble Content

    /// Whether the text content is just the attachment filename (should be hidden for images).
    private var textIsJustFilename: Bool {
        let trimmedText = displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && trimmedText == message.attachmentName
    }

    /// Whether this message contains only an image attachment with no text content.
    private var isImageOnlyMessage: Bool {
        let hasImage = message.attachmentType?.hasPrefix("image/") == true
            && message.attachmentUrl?.isEmpty == false
        let trimmedText = displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = (!trimmedText.isEmpty && !textIsJustFilename) || message.isEdited
        let hasReply = message.replyPreview != nil
        let hasMarkerShare = markerShareContent != nil
        return hasImage && !hasText && !hasReply && !hasMarkerShare
    }

    /// Whether this message has an image with accompanying text (caption).
    private var isImageWithCaptionMessage: Bool {
        let hasImage = message.attachmentType?.hasPrefix("image/") == true
            && message.attachmentUrl?.isEmpty == false
        let trimmedText = displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasImage && !trimmedText.isEmpty && !textIsJustFilename
    }

    private var messageBubbleContent: some View {
        VStack(alignment: .leading, spacing: isImageOnlyMessage ? 0 : 6) {
            if let replyPreview = message.replyPreview {
                replyPreviewView(replyPreview)
            }

            // Attachment preview (if present)
            if let attachmentUrl = message.attachmentUrl, !attachmentUrl.isEmpty {
                attachmentView(url: attachmentUrl, type: message.attachmentType, name: message.attachmentName)
            }

            if let markerShare = markerShareContent {
                MarkerShareCard(
                    payload: markerShare.payload,
                    isCurrentUserMessage: message.isCurrentUserMessage,
                    onTap: {
                        onMarkerShareTap?(markerShare.payload)
                    }
                )
            }

            // Text content + edited indicator (hide filename-only text for image messages)
            if (!displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !textIsJustFilename) || message.isEdited {
                HStack(spacing: 8) {
                    if !displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !textIsJustFilename {
                        Text(displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.subheadline)
                            .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    }

                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(message.isCurrentUserMessage ? AppColors.surfaceWhite70 : .secondary)
                    }
                }
                .padding(.horizontal, isImageWithCaptionMessage ? 8 : 0)
                .padding(.bottom, isImageWithCaptionMessage ? 4 : 0)
            }
        }
        .padding(isImageOnlyMessage ? 2 : 0)
        .padding(.horizontal, isImageOnlyMessage ? 0 : (isImageWithCaptionMessage ? 3 : 12))
        .padding(.vertical, isImageOnlyMessage ? 0 : (isImageWithCaptionMessage ? 3 : 8))
        .background(
            message.isCurrentUserMessage ?
            AppColors.accentDarkColor :
            AppColors.surfaceGray20
        )
        .clipShape(ChatBubbleShape.bubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
    }

    private func replyPreviewView(_ preview: RLMessageReplyPreviewDTO) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Capsule()
                .fill(message.isCurrentUserMessage ? AppColors.surfaceWhite24 : AppColors.accentColor.opacity(0.55))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(preview.authorDisplayName ?? preview.authorUsername)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(message.isCurrentUserMessage ? AppColors.surfaceWhite82 : AppColors.accentColor)
                Text(preview.contentPreview)
                    .font(.caption)
                    .foregroundColor(message.isCurrentUserMessage ? AppColors.surfaceWhite92 : AppColors.whiteText.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(message.isCurrentUserMessage ? AppColors.surfaceBlack45 : AppColors.surfaceBlack30)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(message.isCurrentUserMessage ? AppColors.surfaceWhite12 : AppColors.surfaceWhite08, lineWidth: 1)
                )
        )
    }

    // MARK: - Attachment View
    @ViewBuilder
    private func attachmentView(url: String, type: String?, name: String?) -> some View {
        let isImage = type?.hasPrefix("image/") == true

        if isImage, let imageUrl = URL(string: url) {
            // Image attachment — show inline preview
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 232)
                case .failure:
                    fileAttachmentRow(name: name, type: type)
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 80)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            // Non-image attachment — show file row
            fileAttachmentRow(name: name, type: type)
        }
    }

    private func fileAttachmentRow(name: String?, type: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: type))
                .font(.title3)
                .foregroundColor(message.isCurrentUserMessage ? .white : AppColors.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? "Attachment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    .lineLimit(1)

                Text(type ?? "File")
                    .font(.caption2)
                    .foregroundColor(message.isCurrentUserMessage ? AppColors.surfaceWhite70 : .secondary)
            }
        }
        .padding(8)
        .background(
            (message.isCurrentUserMessage ? AppColors.surfaceWhite15 : AppColors.surfaceGray15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fileIcon(for mimeType: String?) -> String {
        guard let type = mimeType else { return "doc.fill" }
        if type.hasPrefix("image/") { return "photo.fill" }
        if type == "application/pdf" { return "doc.text.fill" }
        if type == "text/plain" { return "doc.plaintext.fill" }
        if type == "application/zip" { return "doc.zipper" }
        return "doc.fill"
    }

    private var markerShareContent: (payload: MarkerSharePayloadV1, visibleText: String)? {
        MarkerShareCodec.extract(from: message.content)
    }

    private var displayMessageText: String {
        markerShareContent?.visibleText ?? message.content
    }
    
    // MARK: - Timestamp Row
    private var timestampRow: some View {
        HStack(spacing: 4) {
            Text(message.timestampFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Read receipt for DMs
            if context.showsReadReceipts && message.isCurrentUserMessage {
                Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(isRead ? AppColors.accentColor : .secondary)
            }
        }
    }

    private var reactionCluster: some View {
        FlowLayout(spacing: 4) {
            ForEach(message.reactions, id: \.emoji) { reaction in
                Button {
                    onVisibleReactionTap?()
                } label: {
                    HStack(spacing: 3) {
                        Text(reaction.emoji)
                            .font(.caption)
                        if reaction.count >= 2 {
                            Text("\(reaction.count)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.surfaceWhite88)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(
                                reaction.reactedByCurrentUser
                                    ? AppColors.accentDarkColor
                                    : AppColors.surfaceBlack85
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        reaction.reactedByCurrentUser
                                            ? AppColors.accentColor.opacity(0.7)
                                            : AppColors.surfaceWhite15,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
}

extension RLMessageReactionDTO {
    var compactBubbleCountText: String? {
        count > 2 ? "\(count)" : nil
    }
}

struct ChatSurfaceOverlayHost<Message: RLChatMessageDisplayable>: View {
    let messages: [Message]
    let reactorsState: ChatReactionReactorsState
    let onQuickReactionSelected: ((Message, String) -> Void)?
    let onReply: ((Message) -> Void)?
    let onEdit: ((Message) -> Void)?
    let onDelete: ((Message) -> Void)?
    let onCopy: ((Message) -> Void)?
    let onReport: ((Message) -> Void)?
    let onFetchReactors: ((Message, String) -> Void)?

    @EnvironmentObject private var appState: RLAppState
    @EnvironmentObject private var chatSurfaceOverlayCoordinator: ChatSurfaceOverlayCoordinator
    @State private var pendingDeleteMessageID: UUID?

    var body: some View {
        Group {
            if let presentation = chatSurfaceOverlayCoordinator.presentation,
               let message = resolvedMessage(for: presentation) {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Color.black.opacity(0.45))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            chatSurfaceOverlayCoordinator.dismissOverlay()
                        }

                    switch presentation {
                    case .messageActions:
                        ChatCenteredMessageActionCard(
                            authorUsername: message.authorUsername,
                            previewText: previewText(for: message),
                            currentUserReactions: Set(message.reactions.filter(\.reactedByCurrentUser).map(\.emoji)),
                            canEdit: message.canEdit && onEdit != nil,
                            canDelete: message.canDelete && onDelete != nil,
                            canReport: !message.isCurrentUserMessage && onReport != nil,
                            canReply: onReply != nil,
                            onEmojiSelected: { emoji in
                                onQuickReactionSelected?(message, emoji)
                                chatSurfaceOverlayCoordinator.dismissOverlay()
                            },
                            onReply: {
                                onReply?(message)
                                chatSurfaceOverlayCoordinator.dismissOverlay()
                            },
                            onEdit: {
                                onEdit?(message)
                                chatSurfaceOverlayCoordinator.dismissOverlay()
                            },
                            onDelete: {
                                pendingDeleteMessageID = message.id
                            },
                            onCopy: {
                                UIPasteboard.general.string = previewText(for: message)
                                onCopy?(message)
                                chatSurfaceOverlayCoordinator.dismissOverlay()
                            },
                            onReport: {
                                onReport?(message)
                                chatSurfaceOverlayCoordinator.dismissOverlay()
                            }
                        )
                        .frame(maxWidth: 340)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    case .reactionReactors(let messageID, let reactions):
                        ChatReactionReactorsCard(
                            reactions: reactions,
                            reactorsState: reactorsState.matches(messageID: messageID)
                                ? reactorsState
                                : ChatReactionReactorsState(messageID: messageID),
                            onSelectEmoji: { emoji in
                                onFetchReactors?(message, emoji)
                            }
                        )
                        .frame(maxWidth: 340)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
                .zIndex(10_000)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .animation(.spring(response: 0.3, dampingFraction: 0.82), value: chatSurfaceOverlayCoordinator.presentation)
            }
        }
        .alert("Delete Message", isPresented: deleteConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingDeleteMessageID = nil
            }
            Button("Delete", role: .destructive) {
                if let messageID = pendingDeleteMessageID,
                   let message = messages.first(where: { $0.id == messageID }) {
                    onDelete?(message)
                }
                pendingDeleteMessageID = nil
                chatSurfaceOverlayCoordinator.dismissOverlay()
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteMessageID != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteMessageID = nil
                }
            }
        )
    }

    private func resolvedMessage(for presentation: ChatSurfaceOverlayPresentation) -> Message? {
        switch presentation {
        case .messageActions(let messageID):
            return messages.first(where: { $0.id == messageID })
        case .reactionReactors(let messageID, _):
            return messages.first(where: { $0.id == messageID })
        }
    }

    private func previewText(for message: Message) -> String {
        if let markerShare = MarkerShareCodec.extract(from: message.content) {
            let visibleText = markerShare.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !visibleText.isEmpty {
                return visibleText
            }
        }

        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if let attachmentName = message.attachmentName, !attachmentName.isEmpty {
            return attachmentName
        }

        return "Attachment"
    }
}

private struct ChatCenteredMessageActionCard: View {
    let authorUsername: String
    let previewText: String
    let currentUserReactions: Set<String>
    let canEdit: Bool
    let canDelete: Bool
    let canReport: Bool
    let canReply: Bool
    let onEmojiSelected: (String) -> Void
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onReport: () -> Void

    private let quickEmojis = ["👍", "🔥", "😂", "🎯", "👀"]
    @State private var tappedEmoji: String?

    private var actionItems: [(title: String, icon: String, destructive: Bool, action: () -> Void)] {
        var items: [(String, String, Bool, () -> Void)] = []
        if canReply {
            items.append(("Reply", "arrowshape.turn.up.left.fill", false, onReply))
        }
        if canEdit {
            items.append(("Edit", "pencil", false, onEdit))
        }
        items.append(("Copy", "doc.on.doc", false, onCopy))
        if canDelete {
            items.append(("Delete", "trash", true, onDelete))
        }
        if canReport {
            items.append(("Report", "exclamationmark.triangle", true, onReport))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Message preview — accent bar style
            HStack(spacing: 10) {
                Capsule()
                    .fill(AppColors.accentColor.opacity(0.6))
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(authorUsername)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.surfaceWhite60)
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 4)

            // Quick reaction emoji row
            HStack(spacing: 8) {
                ForEach(quickEmojis, id: \.self) { emoji in
                    let isAlreadyReacted = currentUserReactions.contains(emoji)
                    Button {
                        tappedEmoji = emoji
                        HapticFeedback.light.trigger()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onEmojiSelected(emoji)
                        }
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isAlreadyReacted ? AppColors.accentDarkColor.opacity(0.4) : AppColors.surfaceWhite06)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isAlreadyReacted ? AppColors.accentColor.opacity(0.7) : AppColors.surfaceWhite12, lineWidth: isAlreadyReacted ? 1.5 : 1)
                                    )
                            )
                            .scaleEffect(tappedEmoji == emoji ? 1.25 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: tappedEmoji)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Divider
            Rectangle()
                .fill(AppColors.surfaceWhite08)
                .frame(height: 1)
                .padding(.horizontal, 4)

            // Action buttons
            VStack(spacing: 2) {
                ForEach(Array(actionItems.enumerated()), id: \.offset) { entry in
                    let item = entry.element
                    actionButton(
                        title: item.title,
                        systemImage: item.icon,
                        action: item.action,
                        isDestructive: item.destructive
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColors.surfaceBlack85.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 28, x: 0, y: 14)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isDestructive: Bool = false
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.surfaceWhite30)
                }
            }
            .foregroundColor(isDestructive ? AppColors.bearCandleRed : AppColors.whiteText)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ChatReactionReactorsCard: View {
    let reactions: [RLMessageReactionDTO]
    let reactorsState: ChatReactionReactorsState
    let onSelectEmoji: (String) -> Void

    @EnvironmentObject private var appState: RLAppState
    @State private var selectedEmoji: String?

    private var activeEmoji: String? {
        selectedEmoji ?? reactions.first?.emoji
    }

    private var totalCount: Int {
        reactions.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text("Reactions")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                Text("\(totalCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.surfaceWhite60)
            }

            // Emoji tabs — scrollable row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(reactions, id: \.emoji) { reaction in
                        let isSelected = activeEmoji == reaction.emoji
                        Button {
                            selectedEmoji = reaction.emoji
                            onSelectEmoji(reaction.emoji)
                        } label: {
                            HStack(spacing: 4) {
                                Text(reaction.emoji)
                                    .font(.callout)
                                Text("\(reaction.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(isSelected ? AppColors.whiteText : AppColors.surfaceWhite70)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? AppColors.accentDarkColor : AppColors.surfaceWhite06)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? AppColors.accentColor.opacity(0.7) : AppColors.surfaceWhite12, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Reactors list for selected emoji
            if let emoji = activeEmoji {
                if reactorsState.isLoading(emoji: emoji) {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppColors.surfaceWhite60)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if let response = reactorsState.response(for: emoji), !response.reactors.isEmpty {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(response.reactors, id: \.membershipId) { reactor in
                                reactorRow(reactor, emoji: emoji)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                } else {
                    Text("No reactors to show yet.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.surfaceWhite50)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColors.surfaceBlack85.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 28, x: 0, y: 14)
        .onAppear {
            // Auto-fetch the first emoji's reactors
            if let first = reactions.first?.emoji {
                onSelectEmoji(first)
            }
        }
    }

    private func reactorRow(_ reactor: RLGuildMemberDTO, emoji: String) -> some View {
        HStack(spacing: 10) {
            // Emoji indicator
            Text(emoji)
                .font(.caption)

            ChatAvatar(
                initials: reactor.initials,
                avatarURL: reactor.avatarUrl,
                isOnline: appState.effectiveOnlineStatus(userId: reactor.userId, fallback: reactor.isOnline),
                size: 32
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(reactor.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)
                Text("@\(reactor.username)")
                    .font(.caption2)
                    .foregroundColor(AppColors.surfaceWhite50)
            }

            Spacer()

            Text(reactor.memberRole.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundColor(reactor.memberRole.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.surfaceWhite06)
        )
    }
}

private struct MarkerShareCard: View {
    let payload: MarkerSharePayloadV1
    let isCurrentUserMessage: Bool
    let onTap: () -> Void

    private var tickerLabel: String {
        if let ticker = payload.symbolTicker, !ticker.isEmpty {
            return ticker
        }
        return payload.symbolId.uuidString.prefix(8).uppercased()
    }

    private var timeframeLabel: String {
        payload.timeframe.uppercased()
    }

    private var timestampLabel: String {
        payload.candleTimestamp.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                UnifiedMarkerBadge(
                    intent: payload.intentEnum,
                    sizeToken: .medium
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.intentEnum.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUserMessage ? AppColors.surfaceWhite80 : AppColors.greyText)
                    Text("\(tickerLabel) • \(timeframeLabel)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUserMessage ? .white : .primary)
                    Text(timestampLabel)
                        .font(.caption2)
                        .foregroundColor(isCurrentUserMessage ? AppColors.surfaceWhite75 : .secondary)
                }

                Spacer(minLength: 6)

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(isCurrentUserMessage ? AppColors.surfaceWhite80 : AppColors.accentColor)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentUserMessage ? AppColors.surfaceWhite15 : AppColors.surfaceWhite10)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ================================================================================================
// MARK: - RL DTO PROTOCOL CONFORMANCES
// MARK: - ================================================================================================

extension RLChatroomMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension RLDMMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension RLChartChatMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension RLMarkerCommentDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}












//
//  MessagingComponents+RL.swift
//  traders_guild
//
//  Extension to add RLChatMessageDisplayable conformance to new RL messaging DTOs.
//  This allows RLChatroomMessageDTO and RLDMMessageDTO to work with RLChatMessageBubble.
//


// MARK: - ================================================================================================
// MARK: - RL CHATROOM SETTINGS VIEW
// MARK: - ================================================================================================

/// Settings view for RLGuildChatroomDTO
struct RLChatroomSettingsView: View {
    let chatroom: RLGuildChatroomDTO
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    
    @State private var notificationsEnabled = true
    @State private var showMuteOptions = false
    @State private var showReportOptions = false
    @State private var isPinned = false
    @State private var isMuted = false

    private var resolvedChatroom: RLGuildChatroomDTO {
        rightDrawerViewModel.findChatroom(id: chatroom.id) ?? chatroom
    }

    private var displayDescription: String {
        let trimmed = resolvedChatroom.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No description yet" : trimmed
    }
    
    var body: some View {
        ZStack {
            StaticMessagingBackgroundView()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Chatroom Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.4))
                                    .frame(width: 36, height: 36)
                                Text(resolvedChatroom.displayIcon)
                                    .font(.subheadline.weight(.semibold))
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.whiteText.opacity(0.4))
                                
                                if isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                        .offset(x: 20, y: -20)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(resolvedChatroom.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.whiteText)
                                    
                                    if isMuted {
                                        Image(systemName: "speaker.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.greyText)
                                    }
                                }
                                
                                Text(displayDescription)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                                    .lineLimit(2)
                                
                                Text("\(resolvedChatroom.memberCount) members")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    // Quick Actions Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Quick Actions")
                        
                        SettingsToggleRow(
                            icon: "pin.fill",
                            title: "Pin Chatroom",
                            subtitle: "Keep at top of list",
                            isOn: Binding(
                                get: { isPinned },
                                set: { newValue in
                                    isPinned = newValue
                                    Task {
                                        _ = try? await rlAppState.updateChatroomSettings(
                                            chatroomId: chatroom.id,
                                            isPinned: newValue
                                        )
                                        await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                                    }
                                }
                            ),
                            iconColor: .yellow
                        )
                    }
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Push Notifications",
                            subtitle: "Get notified about new messages",
                            isOn: Binding(
                                get: { !isMuted },
                                set: { newValue in
                                    isMuted = !newValue
                                    Task {
                                        _ = try? await rlAppState.updateChatroomSettings(
                                            chatroomId: chatroom.id,
                                            isMuted: !newValue
                                        )
                                        await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                                    }
                                }
                            ),
                            iconColor: AppColors.accentColor
                        )
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Chatroom",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report Chatroom",
                            subtitle: "Report inappropriate content",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .onAppear {
            isPinned = resolvedChatroom.isPinned
            isMuted = resolvedChatroom.isMuted
        }
        .alert("Mute Chatroom", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteChatroom(duration: .minutes15) }
            Button("1 Hour") { muteChatroom(duration: .hour1) }
            Button("8 Hours") { muteChatroom(duration: .hours8) }
            Button("24 Hours") { muteChatroom(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this chatroom?")
        }
        .alert("Report Chatroom", isPresented: $showReportOptions) {
            Button("Spam or Scam") { reportChatroom(reason: "spam") }
            Button("Harassment") { reportChatroom(reason: "harassment") }
            Button("Inappropriate Content") { reportChatroom(reason: "inappropriate") }
            Button("Other") { reportChatroom(reason: "other") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this chatroom?")
        }
    }
    
    private func muteChatroom(duration: MuteDuration) {
        Task {
            do {
                _ = try await rlAppState.updateChatroomSettings(chatroomId: chatroom.id, isMuted: true)
                isMuted = true
                await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                rlAppState.showSuccess("Chatroom muted for \(duration.displayName)")
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
    
    private func reportChatroom(reason: String) {
        Task {
            guard let guildId = rlAppState.currentGuild?.id else {
                rlAppState.showError(title: "No Guild Selected", message: "Please select a guild first.", style: .toast)
                return
            }
            do {
                try await rlAppState.reportChatroom(guildId: guildId, chatroomId: chatroom.id, reason: reason)
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - RL DM SETTINGS VIEW
// MARK: - ================================================================================================

/// Settings view for RLDMThreadDTO
struct RLDMSettingsView: View {
    let thread: RLDMThreadDTO
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showMuteOptions = false
    @State private var showBlockConfirmation = false
    @State private var showUnblockConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showReportOptions = false
    
    private var participant: RLGuildMemberDTO {
        thread.participant
    }
    
    var body: some View {
        ZStack {
            StaticMessagingBackgroundView()
            
            ScrollView {
                VStack(spacing: 0) {
                    // User Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            // Avatar
                            UnifiedMemberAvatar(
                                username: participant.username,
                                avatarURL: participant.avatarUrl,
                                isOnline: participant.isOnline,
                                size: 36
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    if thread.isBlocked {
                                        Image(systemName: "nosign")
                                            .font(.caption)
                                            .foregroundColor(AppColors.bearCandleRed)
                                    }

                                    Text(participant.username)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(thread.isBlocked ? AppColors.greyText : AppColors.whiteText)
                                    
                                    if participant.isFriend {
                                        Image(systemName: "person.crop.circle.badge.checkmark")
                                            .font(.caption)
                                            .foregroundColor(AppColors.friendAccent)
                                    }
                                }
                                
                                Text("@\(participant.username)")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                                
                                UnifiedRoleBadge(
                                    member: participant,
                                    showReputation: true,
                                    fontSize: .caption2,
                                    iconSize: .caption2
                                )
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Conversation",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        if thread.isBlocked {
                            SettingsButtonRow(
                                icon: "hand.raised.slash.fill",
                                title: "Unblock User",
                                subtitle: "Allow messages from this user",
                                iconColor: .green
                            ) {
                                showUnblockConfirmation = true
                            }
                        } else {
                            SettingsButtonRow(
                                icon: "hand.raised.fill",
                                title: "Block User",
                                subtitle: "Stop receiving messages",
                                iconColor: .red
                            ) {
                                showBlockConfirmation = true
                            }
                        }
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report User",
                            subtitle: "Report inappropriate behavior",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Danger Zone
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Conversation")
                        
                        SettingsButtonRow(
                            icon: "trash.fill",
                            title: "Delete Conversation",
                            subtitle: "This cannot be undone",
                            iconColor: .red
                        ) {
                            showDeleteConfirmation = true
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .alert("Mute Conversation", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteConversation(duration: .minutes15) }
            Button("1 Hour") { muteConversation(duration: .hour1) }
            Button("8 Hours") { muteConversation(duration: .hours8) }
            Button("24 Hours") { muteConversation(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this conversation?")
        }
        .alert("Block User", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(participant.username)? You won't receive messages from them.")
        }
        .alert("Unblock User", isPresented: $showUnblockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock") {
                unblockUser()
            }
        } message: {
            Text("Are you sure you want to unblock \(participant.username)?")
        }
        .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }
        .sheet(isPresented: $showReportOptions) {
            ReportReasonSheet(
                title: "Why are you reporting this user?",
                includeScam: true,
                onReasonSelected: { reason in
                    reportUser(reason: reason)
                    showReportOptions = false
                },
                onCancel: { showReportOptions = false }
            )
        }
    }
    
    private func muteConversation(duration: MuteDuration) {
        rlAppState.showSuccess("Conversation muted for \(duration.displayName)")
    }
    
    private func blockUser() {
        Task {
            do {
                _ = try await rlAppState.blockUser(membershipId: participant.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                rlAppState.showSuccess("User blocked")
                rlMessagingManager.closeMessage()
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func unblockUser() {
        Task {
            do {
                _ = try await rlAppState.unblockUser(membershipId: participant.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                rlAppState.showSuccess("User unblocked")
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func deleteConversation() {
        Task {
            do {
                try await rlAppState.deleteDMThread(threadId: thread.id)
                rlMessagingManager.closeMessage()
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func reportUser(reason: String) {
        Task {
            do {
                try await rlAppState.reportUser(
                    guildId: thread.guildId,
                    userId: participant.userId,
                    reason: reason
                )
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
}

