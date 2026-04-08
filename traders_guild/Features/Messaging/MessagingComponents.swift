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

struct ChatMarkerLinkDraft: Equatable, Identifiable, MarkerListItemData {
    var marker: RLTopMarkerDTO

    var id: UUID { marker.id }
    var markerId: UUID { marker.id }
    var symbolId: UUID { marker.symbolId }
    var symbolTicker: String { marker.symbolTicker }
    var symbolBrandColor: String? { marker.symbolBrandColor }
    var symbolAssetClass: String { marker.symbolAssetClass }
    var authorId: UUID { marker.authorId }
    var authorUsername: String { marker.authorUsername }
    var authorInitials: String { marker.authorInitials }
    var authorAvatarUrl: String? { marker.authorAvatarUrl }
    var authorIsOnline: Bool { marker.authorIsOnline }
    var authorReputation: Int { marker.authorReputation }
    var authorAccuracyRate: Double? { marker.authorAccuracyRate }
    var authorRole: String { marker.authorRole }
    var intent: String { marker.intent }
    var title: String? { marker.title }
    var notePreview: String? { marker.notePreview }
    var selectedEmoji: String? { marker.selectedEmoji }
    var alertSeverity: String? { marker.alertSeverity }
    var createdAt: Date { marker.createdAt }
    var createdAtFormatted: String { marker.createdAtFormatted }
    var candleTimestamp: Date { marker.candleTimestamp }
    var timeframe: String { marker.timeframe }
    var price: Double { marker.price }
    var setupSummary: RLSetupSummaryDTO? { marker.setupSummary }
    var likeCount: Int {
        get { marker.likeCount }
        set { marker.likeCount = newValue }
    }
    var isLikedByCurrentUser: Bool {
        get { marker.isLikedByCurrentUser }
        set { marker.isLikedByCurrentUser = newValue }
    }
    var commentCount: Int { marker.commentCount }
    var isCurrentUserMarker: Bool { marker.isCurrentUserMarker }
    var intentEnum: RLMarkerIntent { marker.intentEnum }
    var authorAccuracyFormatted: String? { marker.authorAccuracyFormatted }
    var predictionResult: RLPredictionResultDTO? { nil }
    var displayTimestamp: String { marker.displayTimestamp }
    var trackingStateEnum: RLTrackingState? { marker.trackingStateEnum }

    var markerType: String { intent }

    var cleanedNotePreview: String? {
        guard let notePreview else { return nil }
        if intentEnum == .alert {
            let stripped = MarkerAlertSeverity.stripKnownPrefix(from: notePreview)
            return stripped.isEmpty ? nil : stripped
        }
        let trimmed = notePreview.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var payload: MarkerSharePayloadV1 {
        MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: symbolId,
            symbolTicker: symbolTicker,
            symbolAssetClass: symbolAssetClass,
            symbolBrandColor: symbolBrandColor,
            timeframe: timeframe,
            candleTimestamp: candleTimestamp,
            markerType: intent,
            intent: intent,
            selectedEmoji: selectedEmoji,
            alertSeverity: alertSeverity
        )
    }

    init(marker: RLTopMarkerDTO) {
        self.marker = marker
    }
}

struct ChatComposerLayoutMetrics {
    static let barHeight: CGFloat = 44
    static let containerHorizontalPadding: CGFloat = 16
    static let containerVerticalPadding: CGFloat = 8
    static let attachmentPanelGap: CGFloat = 12

    static var attachmentPanelBottomOffset: CGFloat {
        barHeight + containerVerticalPadding + attachmentPanelGap
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
    let attachments: [ChatAttachmentDraft]
    let markerShareDrafts: [ChatMarkerLinkDraft]
    let replyDraft: ChatReplyDraft?

    init(
        text: String,
        attachment: ChatAttachmentDraft?,
        markerShareDraft: ChatMarkerLinkDraft? = nil,
        replyDraft: ChatReplyDraft? = nil
    ) {
        self.text = text
        self.attachments = attachment.map { [$0] } ?? []
        self.markerShareDrafts = markerShareDraft.map { [$0] } ?? []
        self.replyDraft = replyDraft
    }

    init(
        text: String,
        attachments: [ChatAttachmentDraft],
        markerShareDrafts: [ChatMarkerLinkDraft] = [],
        replyDraft: ChatReplyDraft? = nil
    ) {
        self.text = text
        self.attachments = attachments
        self.markerShareDrafts = markerShareDrafts
        self.replyDraft = replyDraft
    }

    var hasBodyContent: Bool {
        !text.isEmpty || !markerShareDrafts.isEmpty || !attachments.isEmpty
    }

    func encodedContent(fallback: String = "") -> String {
        let note = text.isEmpty ? fallback : text
        guard !markerShareDrafts.isEmpty else { return note }
        return MarkerShareCodec.buildMessage(
            note: note,
            payloads: markerShareDrafts.map(\.payload)
        )
    }
}

extension ChatReplyDraft {
    init<Message: RLChatMessageDisplayable>(message: Message) {
        self.messageId = message.id
        self.authorDisplayName = message.authorUsername
        let visibleText = ChatMessageVisibleText.value(for: message)
        if !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.contentPreview = visibleText
        } else if let attachmentName = message.messageAttachments.first?.attachmentName, !attachmentName.isEmpty {
            self.contentPreview = attachmentName
        } else {
            self.contentPreview = "Attachment"
        }
        self.attachmentType = message.messageAttachments.first?.attachmentType
        self.attachmentName = message.messageAttachments.first?.attachmentName
    }
}

struct MarkerSharePayloadV1: Codable, Equatable, Hashable {
    let markerId: UUID
    let symbolId: UUID
    let symbolTicker: String?
    let symbolAssetClass: String?
    let symbolBrandColor: String?
    let timeframe: String
    let candleTimestamp: Date
    let markerType: String?
    let intent: String?
    let selectedEmoji: String?
    let alertSeverity: String?

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
        symbolAssetClass: String? = nil,
        symbolBrandColor: String? = nil,
        timeframe: String,
        candleTimestamp: Date,
        markerType: String? = nil,
        intent: String? = nil,
        selectedEmoji: String? = nil,
        alertSeverity: String? = nil
    ) {
        self.markerId = markerId
        self.symbolId = symbolId
        self.symbolTicker = symbolTicker
        self.symbolAssetClass = symbolAssetClass
        self.symbolBrandColor = symbolBrandColor
        self.timeframe = timeframe
        self.candleTimestamp = candleTimestamp
        self.markerType = markerType
        self.intent = intent
        self.selectedEmoji = selectedEmoji
        self.alertSeverity = alertSeverity
    }

    var selectedEmojiValue: String? {
        let trimmed = selectedEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var alertSeverityEnum: MarkerAlertSeverity? {
        guard intentEnum == .alert else { return nil }
        return MarkerAlertSeverity.resolved(rawValue: alertSeverity)
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
        if let symbolAssetClass {
            info["symbolAssetClass"] = symbolAssetClass
        }
        if let symbolBrandColor {
            info["symbolBrandColor"] = symbolBrandColor
        }
        if let markerType {
            info["markerType"] = markerType
        }
        if let intent {
            info["intent"] = intent
        }
        if let selectedEmojiValue {
            info["selectedEmoji"] = selectedEmojiValue
        }
        if let alertSeverity {
            info["alertSeverity"] = alertSeverity
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
        self.symbolAssetClass = (userInfo["symbolAssetClass"] ?? userInfo["symbol_asset_class"]) as? String
        self.symbolBrandColor = (userInfo["symbolBrandColor"] ?? userInfo["symbol_brand_color"]) as? String
        self.timeframe = timeframe
        self.candleTimestamp = candleTimestamp
        self.markerType = userInfo["markerType"] as? String
        self.intent = userInfo["intent"] as? String
        self.selectedEmoji = (userInfo["selectedEmoji"] ?? userInfo["selected_emoji"]) as? String
        self.alertSeverity = (userInfo["alertSeverity"] ?? userInfo["alert_severity"]) as? String
    }
}

enum MarkerShareCodec {
    private static let tokenPrefix = "[[TG_MARKER_SHARE_V1:"
    private static let tokenSuffix = "]]"

    static func buildMessage(note: String, payload: MarkerSharePayloadV1) -> String {
        buildMessage(note: note, payloads: [payload])
    }

    static func buildMessage(note: String, payloads: [MarkerSharePayloadV1]) -> String {
        let tokens = payloads.compactMap(encodedToken(for:))
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tokens.isEmpty else { return trimmedNote }
        guard !trimmedNote.isEmpty else {
            return tokens.joined(separator: "\n\n")
        }
        return ([trimmedNote] + tokens).joined(separator: "\n\n")
    }

    static func extract(from content: String) -> (payload: MarkerSharePayloadV1, visibleText: String)? {
        guard let extracted = extractAll(from: content),
              let first = extracted.payloads.first else { return nil }
        return (first, extracted.visibleText)
    }

    static func extractAll(from content: String) -> (payloads: [MarkerSharePayloadV1], visibleText: String)? {
        var mutableContent = content
        var payloads: [MarkerSharePayloadV1] = []

        while let start = mutableContent.range(of: tokenPrefix),
              let suffixRange = mutableContent[start.upperBound...].range(of: tokenSuffix) {
            let encoded = String(mutableContent[start.upperBound..<suffixRange.lowerBound])
            if let payload = decodePayload(from: encoded) {
                payloads.append(payload)
            }
            mutableContent.removeSubrange(start.lowerBound..<suffixRange.upperBound)
        }

        let visibleText = mutableContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return payloads.isEmpty ? nil : (payloads, visibleText)
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

enum ChatMessageVisibleText {
    static func value<Message: RLChatMessageDisplayable>(for message: Message) -> String {
        MarkerShareCodec.extractAll(from: message.content)?.visibleText ?? message.content
    }
}

struct ChatInputFooter: View {
    @Binding var messageText: String
    var replyDraft: Binding<ChatReplyDraft?>? = nil
    let placeholder: String
    let isSending: Bool
    let onSend: @MainActor (ChatComposerPayload) async -> Bool
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

    /// Guild members available for @mention autocomplete. Pass non-empty to enable mentions.
    var mentionCandidates: [RLGuildMemberDTO] = []

    @EnvironmentObject private var appState: RLAppState

    @FocusState private var isInputFocused: Bool

    @StateObject private var speechService = SpeechRecognitionService()

    @State private var showActionPanel = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showMarkerPicker = false
    @State private var selectedAttachments: [ChatAttachmentDraft] = []
    @State private var selectedMarkerDrafts: [ChatMarkerLinkDraft] = []
    @State private var markerDrafts: [ChatMarkerLinkDraft] = []
    @State private var isLoadingMarkerDrafts = false
    @State private var markerPickerError: String? = nil
    @State private var isDispatchingSend = false

    private var isLightGreyChrome: Bool { ThemeManager.shared.currentTheme == .lightGrey }
    private var actionPanelBottomOffset: CGFloat {
        ChatComposerLayoutMetrics.attachmentPanelBottomOffset
    }

    private var composerAccessoryIdleColor: Color {
        isLightGreyChrome ? AppColors.standardSearchFieldAccessory : Color.secondary
    }

    /// The partial @mention query extracted from the current cursor position
    private var mentionQuery: String? {
        guard !mentionCandidates.isEmpty else { return nil }
        // Find the last @mention being typed
        guard let atRange = messageText.range(of: "@", options: .backwards) else { return nil }
        let afterAt = String(messageText[atRange.upperBound...])
        // Must be at the end of text with no spaces (still typing the mention)
        guard !afterAt.contains(" ") else { return nil }
        return afterAt.lowercased()
    }

    private var mentionSuggestions: [RLGuildMemberDTO] {
        guard let query = mentionQuery else { return [] }
        let currentUserId = appState.currentUser?.id
        let filtered = mentionCandidates.filter { member in
            member.userId != currentUserId &&
            member.username.lowercased().hasPrefix(query)
        }
        return Array(filtered.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            if speechService.isRecording {
                recordingIndicator
            }

            if hasDraftContent {
                attachmentDraftRow
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // @mention autocomplete suggestions
            if !mentionSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(mentionSuggestions, id: \.userId) { member in
                        Button {
                            insertMention(member)
                        } label: {
                            HStack(spacing: 10) {
                                ChatAvatar(
                                    initials: member.initials,
                                    avatarURL: member.avatarUrl,
                                    isOnline: member.isOnline,
                                    size: 28
                                )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(member.username)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.whiteText)
                                    if !member.displayName.isEmpty, member.displayName != member.username {
                                        Text(member.displayName)
                                            .font(.caption2)
                                            .foregroundColor(AppColors.greyText)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(AppColors.surfaceGray10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            .foregroundColor(showActionPanel ? .white : composerAccessoryIdleColor)
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
                                .foregroundColor(speechService.isRecording ? .red : composerAccessoryIdleColor)
                                .frame(width: 32, height: 32)
                                .symbolEffect(.pulse, isActive: speechService.isRecording)
                        }
                        .compositingGroup()

                        if isSending || isDispatchingSend {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 40, height: 40)
                        } else {
                            sendButton
                        }
                    }
                }
                .padding(.leading, 10)
                .frame(height: ChatComposerLayoutMetrics.barHeight)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(AppColors.standardSearchFieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    AppColors.standardSearchFieldStroke.opacity(isLightGreyChrome ? 1 : 0.85),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .padding(.horizontal, ChatComposerLayoutMetrics.containerHorizontalPadding)
            .padding(.vertical, ChatComposerLayoutMetrics.containerVerticalPadding)
        }
        .background(
            ChatChromeBarBackground()
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .bottom) {
            if showActionPanel {
                attachmentActionPanel
                    .padding(.bottom, actionPanelBottomOffset)
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
                    .zIndex(1)
            }
        }
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
                selectionLimit: 5
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCameraPicker) {
            SharedImagePicker(sourceType: .camera) { image in
                showCameraPicker = false
                guard let data = image.jpegData(compressionQuality: 0.85) else { return }
                selectedAttachments.append(ChatAttachmentDraft(
                    data: data,
                    filename: "camera-\(UUID().uuidString.prefix(8)).jpg",
                    mimeType: "image/jpeg"
                ))
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                onDocumentsSelected: { selected in
                    showDocumentPicker = false
                    appendAttachments(selected)
                },
                onCancel: { showDocumentPicker = false },
                selectionLimit: 5
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
                    if !selectedMarkerDrafts.contains(where: { $0.id == draft.id }) {
                        selectedMarkerDrafts.append(draft)
                    }
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
                .fill(AppColors.panelFillEmphasis)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.standardSearchFieldStroke.opacity(0.8), lineWidth: 1)
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

    private var hasDraftContent: Bool {
        replyDraft?.wrappedValue != nil || !selectedAttachments.isEmpty || !selectedMarkerDrafts.isEmpty
    }

    private var canSend: Bool {
        !isDispatchingSend && (
            !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !selectedAttachments.isEmpty ||
            !selectedMarkerDrafts.isEmpty
        )
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

                if selectedAttachments.count < 5 {
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
                        selectedAttachments = []
                        selectedMarkerDrafts = []
                        replyDraft?.wrappedValue = nil
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.bearCandleRed.opacity(0.92))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(selectedAttachments.enumerated()), id: \.offset) { index, attachment in
                        attachmentPreviewChip(for: attachment, at: index)
                    }
                    ForEach(selectedMarkerDrafts) { markerDraft in
                        markerPreviewChip(for: markerDraft)
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
        let attachCount = selectedAttachments.count
        let hasAttach = attachCount > 0
        let markerCount = selectedMarkerDrafts.count
        let hasMarker = markerCount > 0
        let hasReply = replyDraft?.wrappedValue != nil
        let attachLabel = attachCount == 1 ? "1 attachment" : "\(attachCount) attachments"
        let markerLabel = markerCount == 1 ? "1 marker link" : "\(markerCount) marker links"

        switch (hasAttach, hasMarker, hasReply) {
        case (false, false, true):
            return "Reply ready"
        case (false, true, false):
            return "\(markerLabel) ready"
        case (true, false, false):
            return "\(attachLabel) ready"
        case (true, true, false):
            return "\(attachLabel) + \(markerLabel) ready"
        case (true, false, true):
            return "Reply + \(attachLabel) ready"
        case (false, true, true):
            return "Reply + \(markerLabel) ready"
        case (true, true, true):
            return "Reply + \(attachLabel) + \(markerLabel) ready"
        case (false, false, false):
            return "Draft ready"
        }
    }

    @ViewBuilder
    private func attachmentPreviewChip(for attachment: ChatAttachmentDraft, at index: Int) -> some View {
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
                withAnimation { let _ = selectedAttachments.remove(at: index) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.primaryForeground)
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
                    .foregroundColor(AppColors.primaryForeground)
                    .background(AppColors.surfaceBlack45, in: Circle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.symbolDetailCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.surfaceWhite20, lineWidth: 1)
                )
        )
    }

    private func markerPreviewChip(for marker: ChatMarkerLinkDraft) -> some View {
        LinkedMarkerRow(
            intent: marker.intentEnum,
            alertSeverity: marker.alertSeverityEnum,
            emoji: marker.selectedEmoji,
            ticker: marker.symbolTicker,
            assetClass: marker.symbolAssetClass,
            brandColorHex: marker.symbolBrandColor,
            timeframe: marker.timeframe,
            subtitle: marker.cleanedNotePreview ?? marker.createdAt.formatted(date: .abbreviated, time: .shortened),
            style: .attachmentDraft,
            trailingAction: {
                withAnimation { selectedMarkerDrafts.removeAll { $0.id == marker.id } }
            }
        )
    }

    // MARK: - Helpers

    private func appendAttachments(_ selected: [(Data, String, String)]) {
        let remaining = 5 - selectedAttachments.count
        guard remaining > 0 else { return }
        let toAdd = selected.prefix(remaining).map {
            ChatAttachmentDraft(data: $0.0, filename: $0.1, mimeType: $0.2)
        }
        selectedAttachments.append(contentsOf: toAdd)
    }

    private func setReplyDraft(_ value: ChatReplyDraft?) {
        replyDraft?.wrappedValue = value
    }

    private func currentReplyDraft() -> ChatReplyDraft? {
        replyDraft?.wrappedValue
    }

    private func clearComposerDrafts() {
        messageText = ""
        selectedAttachments = []
        selectedMarkerDrafts = []
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
        guard !isSending,
              !isDispatchingSend,
              (!selectedAttachments.isEmpty || !trimmed.isEmpty || !selectedMarkerDrafts.isEmpty || currentReplyDraft() != nil) else {
            return
        }

        let payload = ChatComposerPayload(
            text: trimmed,
            attachments: selectedAttachments,
            markerShareDrafts: selectedMarkerDrafts,
            replyDraft: currentReplyDraft()
        )
        isDispatchingSend = true
        Task { @MainActor in
            let didSend = await onSend(payload)
            isDispatchingSend = false
            if didSend {
                clearComposerDrafts()
            }
        }
    }

    /// Insert selected @mention into the text, replacing the partial @query
    private func insertMention(_ member: RLGuildMemberDTO) {
        // Find the last @ and replace everything after it with the full username + space
        guard let atRange = messageText.range(of: "@", options: .backwards) else { return }
        messageText = String(messageText[messageText.startIndex..<atRange.lowerBound]) + "@\(member.username) "
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
        ZStack {
            ChatBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
                footer
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppColors.statusInfo22.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.statusInfo95)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Link Marker")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Share one of your markers in chat using the same marker row presentation.")
                        .font(.caption)
                        .foregroundColor(AppColors.surfaceWhite70)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.surfaceWhite80)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .background(AppColors.sheetBackground.opacity(0.96))

            Divider()
                .background(AppColors.surfaceGray30)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ProgressView()
                Text("Loading markers...")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(AppColors.bearCandleRed)
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if markers.isEmpty {
            ChatEmptyStateView(
                icon: "target",
                title: "No markers found",
                subtitle: "Place a marker to share it in chat."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(markers) { marker in
                        MarkerListItem(
                            marker: marker,
                            style: .capsule,
                            onTap: {
                                onSelect(marker)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.surfaceGray30)

            HStack(spacing: 12) {
                Text(footerTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.surfaceWhite80)

                Spacer(minLength: 0)

                Text(footerHint)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.sheetBackground.opacity(0.94))
        }
    }

    private var footerTitle: String {
        if isLoading {
            return "Loading your markers"
        }
        if errorMessage != nil {
            return "Unable to load markers"
        }
        return "\(markers.count) marker\(markers.count == 1 ? "" : "s") available"
    }

    private var footerHint: String {
        if errorMessage != nil {
            return "Use Retry above to try again"
        }
        return "Tap a row to link it"
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT BACKGROUND
// MARK: - ================================================================================================

enum ChatBackgroundStyle {
    case standard
    case elevated
}

/// Unified chat background with material and pattern
struct ChatBackground: View {
    var style: ChatBackgroundStyle = .standard

    private var overlayColors: [Color] {
        switch style {
        case .standard:
            return [AppColors.chatBackgroundOverlayStandardStart, AppColors.chatBackgroundOverlayStandardEnd]
        case .elevated:
            return [AppColors.chatBackgroundOverlayElevatedStart, AppColors.chatBackgroundOverlayElevatedEnd]
        }
    }

    private var patternOpacity: Double {
        switch style {
        case .standard:
            return AppColors.chatBackgroundPatternMultiplyStandard
        case .elevated:
            return AppColors.chatBackgroundPatternMultiplyElevated
        }
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            LinearGradient(
                colors: overlayColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            StaticPatternView(targetOpacity: patternOpacity)
        }
    }
}

/// Messaging header/footer chrome: on lightGrey matches symbol chat header (sheet + grouped tint). Dark/mid: flat sheet only (unchanged).
struct ChatChromeBarBackground: View {
    var body: some View {
        Group {
            if ThemeManager.shared.currentTheme == .lightGrey {
                ZStack {
                    AppColors.sheetBackground
                    AppColors.symbolSheetGroupedPanelFill
                }
            } else {
                AppColors.sheetBackground
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EMPTY & LOADING STATES
// MARK: - ================================================================================================

/// Unified loading view for chat
/// Thin wrapper around UnifiedLoadingState for chat-specific loading.
/// Uses the design-system component for consistent styling.
struct ChatLoadingView: View {
    var message: String = "Loading messages..."

    var body: some View {
        UnifiedLoadingState(message: message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Thin wrapper around UnifiedEmptyState for chat-specific empty states.
/// Uses the design-system component for consistent styling.
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
        UnifiedEmptyState(
            icon: icon,
            title: title,
            subtitle: subtitle
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wrapper to make URL usable with .sheet(item:)
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - ================================================================================================
// MARK: - FULL-SCREEN IMAGE VIEWER
// MARK: - ================================================================================================

/// Full-screen image viewer with pinch-to-zoom and dismiss gesture.
/// Presented as a sheet when tapping an image attachment in chat.
struct ChatFullScreenImageViewer: View {
    let imageUrl: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        scale = lastScale * value.magnification
                                    }
                                    .onEnded { _ in
                                        lastScale = max(scale, 1.0)
                                        scale = max(scale, 1.0)
                                        if scale <= 1.0 {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.greyText)
                            Text("Failed to load image")
                                .font(.subheadline)
                                .foregroundColor(AppColors.greyText)
                        }
                    case .empty:
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColors.primaryForeground)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.greyText)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationBackground(.black)
    }
}

// MARK: - ================================================================================================
// MARK: - LINKED TEXT (URL DETECTION)
// MARK: - ================================================================================================

/// Text view that auto-detects URLs (tappable) and @mentions (highlighted).
/// Falls back to plain Text if no URLs or mentions are found for performance.
struct LinkedText: View {
    let text: String
    let foregroundColor: Color

    private static let mentionRegex = try! NSRegularExpression(
        pattern: #"(?:^|(?<=\s))@([a-zA-Z0-9_-]{1,30})(?=\s|$|[.,!?;:])"#
    )
    private static let boldRegex = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
    private static let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
    private static let codeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)

    init(_ text: String, foregroundColor: Color = .primary) {
        self.text = text
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        if let attributed = Self.buildAttributedString(text: text, baseColor: foregroundColor) {
            Text(attributed)
                .font(.subheadline)
                .tint(AppColors.accentColor)
        } else {
            Text(text)
                .font(.subheadline)
                .foregroundColor(foregroundColor)
        }
    }

    /// Represents a styled segment of parsed message text.
    private enum TextSegment {
        case plain(String)
        case bold(String)
        case italic(String)
        case code(String)
        case link(String, URL)
        case mention(String)
    }

    private static func buildAttributedString(text: String, baseColor: Color) -> AttributedString? {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Detect URLs
        let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let urlMatches = urlDetector?.matches(in: text, range: fullRange) ?? []

        // Detect @mentions
        let mentionMatches = mentionRegex.matches(in: text, range: fullRange)

        // Detect markdown
        let boldMatches = boldRegex.matches(in: text, range: fullRange)
        let italicMatches = italicRegex.matches(in: text, range: fullRange)
        let codeMatches = codeRegex.matches(in: text, range: fullRange)

        let hasFormatting = !urlMatches.isEmpty || !mentionMatches.isEmpty ||
                           !boldMatches.isEmpty || !italicMatches.isEmpty || !codeMatches.isEmpty
        guard hasFormatting else { return nil }

        // Build a list of non-overlapping styled ranges, sorted by location.
        // Priority: URL > code > bold > italic > mention
        struct StyledRange {
            let range: NSRange
            let segment: (NSString) -> TextSegment
        }

        var candidates: [StyledRange] = []

        for match in urlMatches {
            guard let url = match.url else { continue }
            candidates.append(StyledRange(range: match.range) { ns in
                .link(ns.substring(with: match.range), url)
            })
        }
        for match in codeMatches {
            let innerRange = match.range(at: 1)
            candidates.append(StyledRange(range: match.range) { ns in
                .code(ns.substring(with: innerRange))
            })
        }
        for match in boldMatches {
            let innerRange = match.range(at: 1)
            candidates.append(StyledRange(range: match.range) { ns in
                .bold(ns.substring(with: innerRange))
            })
        }
        for match in italicMatches {
            let innerRange = match.range(at: 1)
            candidates.append(StyledRange(range: match.range) { ns in
                .italic(ns.substring(with: innerRange))
            })
        }
        for match in mentionMatches {
            candidates.append(StyledRange(range: match.range) { ns in
                .mention(ns.substring(with: match.range))
            })
        }

        // Remove overlapping ranges (keep higher-priority / earlier ones)
        candidates.sort { $0.range.location < $1.range.location }
        var accepted: [StyledRange] = []
        var lastEnd = 0
        for c in candidates {
            if c.range.location >= lastEnd {
                accepted.append(c)
                lastEnd = c.range.location + c.range.length
            }
        }

        // Build segments
        var segments: [TextSegment] = []
        var cursor = 0
        for sr in accepted {
            if sr.range.location > cursor {
                segments.append(.plain(nsString.substring(with: NSRange(location: cursor, length: sr.range.location - cursor))))
            }
            segments.append(sr.segment(nsString))
            cursor = sr.range.location + sr.range.length
        }
        if cursor < nsString.length {
            segments.append(.plain(nsString.substring(from: cursor)))
        }

        // Build AttributedString
        var result = AttributedString()
        for segment in segments {
            var part: AttributedString
            switch segment {
            case .plain(let s):
                part = AttributedString(s)
                part.foregroundColor = baseColor
            case .bold(let s):
                part = AttributedString(s)
                part.foregroundColor = baseColor
                part.font = .subheadline.weight(.bold)
            case .italic(let s):
                part = AttributedString(s)
                part.foregroundColor = baseColor
                part.font = .subheadline.italic()
            case .code(let s):
                part = AttributedString(s)
                part.foregroundColor = AppColors.accentColor
                part.font = .system(.caption, design: .monospaced).weight(.medium)
            case .link(let s, let url):
                part = AttributedString(s)
                part.link = url
                part.underlineStyle = .single
            case .mention(let s):
                part = AttributedString(s)
                part.foregroundColor = AppColors.accentColor
                part.font = .subheadline.weight(.semibold)
            }
            result.append(part)
        }

        return result
    }
}

// MARK: - ================================================================================================
// MARK: - DATE SEPARATOR & MESSAGE GROUPING
// MARK: - ================================================================================================

/// Date separator header shown between messages from different days
struct ChatDateSeparator: View {
    let date: Date

    private var displayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack {
            line
            Text(displayText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.greyText)
                .padding(.horizontal, 10)
            line
        }
        .padding(.vertical, 8)
    }

    private var line: some View {
        Rectangle()
            .fill(AppColors.surfaceWhite15)
            .frame(height: 0.5)
    }
}

/// Determines whether a message should show its header (avatar + user info) or be grouped with the previous message.
/// Messages are grouped when: same author, within 2 minutes, and on the same calendar day.
enum ChatMessageGrouping {
    static func shouldShowHeader<Message: RLChatMessageDisplayable>(
        message: Message,
        previousMessage: Message?
    ) -> Bool {
        guard let prev = previousMessage else { return true }
        guard prev.authorUserId == message.authorUserId else { return true }
        guard abs(message.timestamp.timeIntervalSince(prev.timestamp)) < 120 else { return true }
        guard Calendar.current.isDate(message.timestamp, inSameDayAs: prev.timestamp) else { return true }
        return false
    }

    static func shouldShowDateSeparator<Message: RLChatMessageDisplayable>(
        message: Message,
        previousMessage: Message?
    ) -> Bool {
        guard let prev = previousMessage else { return true }
        return !Calendar.current.isDate(message.timestamp, inSameDayAs: prev.timestamp)
    }
}

// MARK: - ================================================================================================
// MARK: - SCROLL TO BOTTOM BUTTON
// MARK: - ================================================================================================

/// Floating button that appears when user scrolls away from the bottom of the chat.
/// Shows unread count badge when new messages arrive while scrolled up.
struct ChatScrollToBottomButton: View {
    let unreadCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(AppColors.surfaceGray20)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.whiteText)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.surfaceWhite15, lineWidth: 1)
                    )

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.onAccentForeground)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accentColor)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - ================================================================================================
// MARK: - TYPING INDICATOR BUBBLE
// MARK: - ================================================================================================

/// Animated typing indicator with bouncing dots, shown inline below the last message.
struct TypingIndicatorBubble: View {
    var username: String? = nil
    @State private var dotOffset: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let username {
                    Text(username)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondaryForeground)
                }

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AppColors.surfaceWhite50)
                            .frame(width: 6, height: 6)
                            .offset(y: dotOffset[index])
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    ChatBubbleShape.bubbleShape(isFromCurrentUser: false)
                        .fill(AppColors.surfaceGray20)
                )
            }

            Spacer()
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotOffset[i] = -4
            }
        }
    }
}

/// Typing indicator for chatrooms — shows who is typing from the set of active typing user IDs.
struct ChatroomTypingIndicator: View {
    let typingUsernames: [String]

    var body: some View {
        if !typingUsernames.isEmpty {
            let label = typingUsernames.count == 1
                ? typingUsernames[0]
                : typingUsernames.count == 2
                    ? "\(typingUsernames[0]) and \(typingUsernames[1])"
                    : "\(typingUsernames[0]) and \(typingUsernames.count - 1) others"

            TypingIndicatorBubble(username: label)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
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
                .padding(.bottom, 32)
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
                                    errorMessage = RLUserFacingErrorMapper.message(from: error)
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
            .background(ChatChromeBarBackground())
            
            Divider()
        }
    }
}

struct ChatSurfaceHeader<Content: View>: View {
    var horizontalPadding: CGFloat = 16
    var topPadding: CGFloat = 20
    var bottomPadding: CGFloat = 14
    var showsDivider: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ChatChromeBarBackground())

            if showsDivider {
                Divider()
                    .background(AppColors.surfaceGray30)
            }
        }
    }
}

/// Standard dismiss button for chat sheets
struct ChatDismissButton: View {
    let action: () -> Void
    
    var body: some View {
        SheetCloseButton(action: action, tint: .secondary)
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
                .foregroundColor(AppColors.secondaryForeground)
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
                    .foregroundColor(AppColors.surfaceWhite70)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.symbolDetailCardFill)
            .overlay(
                Capsule()
                    .stroke(AppColors.surfaceWhite12, lineWidth: 1)
            )
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
// MARK: - CHAT SEARCH VIEW
// MARK: - ================================================================================================

/// Search view for finding messages across guild chatrooms.
struct ChatSearchView: View {
    @EnvironmentObject var appState: RLAppState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [RLMessageSearchResultDTO] = []
    @State private var isSearching = false
    @State private var totalCount = 0
    @State private var hasMore = false
    @State private var nextCursor: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.sheetBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        UnifiedSearchBar(
                            text: $searchText,
                            placeholder: "Search messages..."
                        )

                        if totalCount > 0 {
                            HStack {
                                Text("\(totalCount) result\(totalCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(AppColors.surfaceWhite60)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .background(
                        AppColors.sheetBackground
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(AppColors.symbolDetailCardFill)
                                    .frame(height: 1)
                            }
                    )

                    if isSearching && results.isEmpty {
                        UnifiedLoadingState(message: "Searching...")
                            .frame(maxHeight: .infinity)
                    } else if results.isEmpty && !searchText.isEmpty {
                        UnifiedEmptyState(
                            icon: "magnifyingglass",
                            title: "No results",
                            subtitle: "Try a different search term"
                        )
                        .frame(maxHeight: .infinity)
                    } else if results.isEmpty {
                        UnifiedEmptyState(
                            icon: "magnifyingglass",
                            title: "Search messages",
                            subtitle: "Find past messages across all chatrooms"
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(results) { result in
                                    searchResultRow(result)
                                }

                                if hasMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .onAppear { loadMore() }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(ThemeManager.shared.currentTheme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton(action: { dismiss() }, tint: AppColors.accentColor)
                }
            }
            .onChange(of: searchText) { _, newValue in
                performDebouncedSearch(newValue)
            }
        }
        .tint(AppColors.accentColor)
    }

    private func searchResultRow(_ result: RLMessageSearchResultDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Chatroom context
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption2)
                    .foregroundColor(AppColors.accentColor)
                Text(result.chatroomName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentColor)
                Spacer()
                Text(result.message.timestampFormatted)
                    .font(.caption2)
                    .foregroundColor(AppColors.surfaceWhite50)
            }

            // Author
            Text(result.message.author.username)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.surfaceWhite70)

            // Message content with highlighted search term
            Text(result.message.content)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryForeground)
                .lineLimit(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.symbolDetailCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.symbolDetailCardFill, lineWidth: 1)
                )
        )
    }

    private func performDebouncedSearch(_ query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            totalCount = 0
            hasMore = false
            nextCursor = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(query: query, reset: true)
        }
    }

    private func search(query: String, reset: Bool) async {
        guard let guildId = appState.currentGuild?.id else { return }
        if reset {
            isSearching = true
            nextCursor = nil
        }
        do {
            let response = try await appState.realApi.searchMessages(
                guildId: guildId,
                query: query,
                cursor: reset ? nil : nextCursor
            )
            await MainActor.run {
                if reset {
                    results = response.results
                } else {
                    results.append(contentsOf: response.results)
                }
                totalCount = response.totalCount
                hasMore = response.hasMore
                nextCursor = response.nextCursor
                isSearching = false
            }
        } catch {
            await MainActor.run { isSearching = false }
        }
    }

    private func loadMore() {
        guard hasMore, !isSearching else { return }
        Task { await search(query: searchText, reset: false) }
    }
}

// MARK: - ================================================================================================
// MARK: - RL MESSAGE PROTOCOL (for RLAppState-based messaging)
// MARK: - ================================================================================================

/// Protocol for RL message types - uses RLMemberRole instead of MemberRole
protocol RLChatMessageDisplayable: Identifiable {
    var id: UUID { get }
    var content: String { get }
    var timestamp: Date { get }
    var timestampFormatted: String { get }
    var isEdited: Bool { get }
    var isCurrentUserMessage: Bool { get }
    var canEdit: Bool { get }
    var canDelete: Bool { get }

    // Author info
    var authorUserId: UUID { get }
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
    var messageAttachments: [RLMessageAttachmentDTO] { get }
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
    let isPending: Bool
    let isGrouped: Bool
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
    @State private var fullScreenImageUrl: URL? = nil

    init(
        message: Message,
        context: ChatContext,
        isRead: Bool = false,
        isPending: Bool = false,
        isGrouped: Bool = false,
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
        self.isPending = isPending
        self.isGrouped = isGrouped
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
                if isGrouped {
                    // Invisible spacer matching avatar width to keep alignment
                    Color.clear.frame(width: 32, height: 1)
                } else {
                    avatarView
                }
            }

            VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
                // User info header (for group chats, non-current user) — hidden when grouped
                if !message.isCurrentUserMessage && context.showsUserInfoHeader && !isGrouped {
                    userInfoHeader
                }

                bubbleStack
            }

            if !message.isCurrentUserMessage {
                Spacer()
            }
        }
        .opacity(isPending ? 0.6 : 1.0)
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
        return !trimmedText.isEmpty && trimmedText == message.messageAttachments.first?.attachmentName
    }

    /// Whether this message contains only an image attachment with no text content.
    private var isImageOnlyMessage: Bool {
        let hasImage = message.messageAttachments.contains {
            $0.attachmentType?.hasPrefix("image/") == true && !$0.attachmentUrl.isEmpty
        }
        let trimmedText = displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = (!trimmedText.isEmpty && !textIsJustFilename) || message.isEdited
        let hasReply = message.replyPreview != nil
        let hasMarkerShare = !markerShareContents.isEmpty
        return hasImage && !hasText && !hasReply && !hasMarkerShare
    }

    /// Whether this message has an image with accompanying text (caption).
    private var isImageWithCaptionMessage: Bool {
        let hasImage = message.messageAttachments.contains {
            $0.attachmentType?.hasPrefix("image/") == true && !$0.attachmentUrl.isEmpty
        }
        let trimmedText = displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasImage && !trimmedText.isEmpty && !textIsJustFilename
    }

    private var messageBubbleContent: some View {
        VStack(alignment: .leading, spacing: isImageOnlyMessage ? 0 : 6) {
            if let replyPreview = message.replyPreview {
                replyPreviewView(replyPreview)
            }

            // Attachment preview (if present)
            ForEach(message.messageAttachments) { attachment in
                attachmentView(
                    url: attachment.attachmentUrl,
                    type: attachment.attachmentType,
                    name: attachment.attachmentName
                )
            }

            ForEach(Array(markerShareContents.enumerated()), id: \.offset) { _, markerShare in
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
                        LinkedText(
                            displayMessageText.trimmingCharacters(in: .whitespacesAndNewlines),
                            foregroundColor: message.isCurrentUserMessage ? .white : .primary
                        )
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
                        .stroke(message.isCurrentUserMessage ? AppColors.surfaceWhite12 : AppColors.symbolDetailCardFill, lineWidth: 1)
                )
        )
    }

    // MARK: - Attachment View
    @ViewBuilder
    private func attachmentView(url: String, type: String?, name: String?) -> some View {
        let isImage = type?.hasPrefix("image/") == true

        if isImage, let imageUrl = URL(string: url) {
            // Image attachment — show inline preview, tap for full-screen
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 232)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            fullScreenImageUrl = imageUrl
                        }
                case .failure:
                    fileAttachmentRow(name: name, type: type)
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 80)
                @unknown default:
                    EmptyView()
                }
            }
            .sheet(item: Binding(
                get: { fullScreenImageUrl.map { IdentifiableURL(url: $0) } },
                set: { fullScreenImageUrl = $0?.url }
            )) { item in
                ChatFullScreenImageViewer(imageUrl: item.url)
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

    private var markerShareContents: [(payload: MarkerSharePayloadV1, visibleText: String)] {
        MarkerShareCodec.extractAll(from: message.content)?.payloads.map { payload in
            (payload: payload, visibleText: ChatMessageVisibleText.value(for: message))
        } ?? []
    }

    private var displayMessageText: String {
        ChatMessageVisibleText.value(for: message)
    }
    
    // MARK: - Timestamp Row
    private var timestampRow: some View {
        HStack(spacing: 4) {
            Text(message.timestampFormatted)
                .font(.caption2)
                .foregroundColor(AppColors.secondaryForeground)

            // Delivery status for current user's messages
            if message.isCurrentUserMessage {
                if isPending {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else if context.showsReadReceipts {
                    // DMs: sent → read (single → double checkmark)
                    Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption2)
                        .foregroundColor(isRead ? AppColors.accentColor : AppColors.secondaryForeground)
                } else {
                    // Chatrooms: just show sent checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.secondaryForeground)
                }
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
                            canReact: !message.isCurrentUserMessage && onQuickReactionSelected != nil,
                            canEdit: message.isCurrentUserMessage && message.canEdit && onEdit != nil,
                            canDelete: message.isCurrentUserMessage && message.canDelete && onDelete != nil,
                            canReport: !message.isCurrentUserMessage && onReport != nil,
                            canReply: !message.isCurrentUserMessage && onReply != nil,
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
        if let markerShare = MarkerShareCodec.extractAll(from: message.content) {
            let visibleText = markerShare.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !visibleText.isEmpty {
                return visibleText
            }
            if markerShare.payloads.count == 1 {
                return "Shared marker"
            }
            return "Shared \(markerShare.payloads.count) markers"
        }

        let visibleText = ChatMessageVisibleText.value(for: message).trimmingCharacters(in: .whitespacesAndNewlines)
        if !visibleText.isEmpty {
            return visibleText
        }

        if message.messageAttachments.count > 1 {
            return "\(message.messageAttachments.count) attachments"
        }

        if let attachmentName = message.messageAttachments.first?.attachmentName, !attachmentName.isEmpty {
            return attachmentName
        }

        return "Attachment"
    }
}

private struct ChatCenteredMessageActionCard: View {
    let authorUsername: String
    let previewText: String
    let currentUserReactions: Set<String>
    let canReact: Bool
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

    private let quickEmojis = [
        "👍", "🔥", "🚀", "🐂", "🐻", "📈", "📉", "😂", "🎯", "👀",
        "❤️", "😍", "🤣", "😮", "😢", "😡", "🎉", "💯", "🙌", "💪",
        "🤔", "👎", "✅", "❌", "💰", "💎", "⚡", "🧠", "🛑", "🏆",
    ]
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

            if canReact {
                ScrollView(.horizontal, showsIndicators: false) {
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
                                    .frame(width: 48, height: 48)
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
                }

                Rectangle()
                    .fill(AppColors.symbolDetailCardFill)
                    .frame(height: 1)
                    .padding(.horizontal, 4)
            }

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
            LinkedMarkerRow(
                intent: payload.intentEnum,
                alertSeverity: payload.alertSeverityEnum,
                emoji: payload.selectedEmojiValue,
                ticker: tickerLabel,
                assetClass: payload.symbolAssetClass,
                brandColorHex: payload.symbolBrandColor,
                timeframe: timeframeLabel,
                subtitle: timestampLabel,
                style: .messageCard(isCurrentUserMessage: isCurrentUserMessage)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private enum LinkedMarkerRowStyle: Equatable {
    case attachmentDraft
    case messageCard(isCurrentUserMessage: Bool)
}

private struct LinkedMarkerRow: View {
    let intent: RLMarkerIntent
    let alertSeverity: MarkerAlertSeverity?
    let emoji: String?
    let ticker: String
    let assetClass: String?
    let brandColorHex: String?
    let timeframe: String
    let subtitle: String?
    let style: LinkedMarkerRowStyle
    var trailingAction: (() -> Void)? = nil

    private var accentColor: Color {
        if intent == .alert {
            return alertSeverity?.color ?? intent.color
        }
        return intent.color
    }

    private var isCurrentUserMessage: Bool {
        if case let .messageCard(isCurrentUserMessage) = style {
            return isCurrentUserMessage
        }
        return false
    }

    private var backgroundGradient: LinearGradient {
        switch style {
        case .attachmentDraft:
            return LinearGradient(
                colors: [AppColors.searchBarGradientLeading, AppColors.searchBarGradientTrailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .messageCard(let isCurrentUser):
            return LinearGradient(
                colors: [
                    isCurrentUser ? AppColors.surfaceBlack30 : AppColors.surfaceBlack45,
                    isCurrentUser ? AppColors.surfaceBlack45 : AppColors.surfaceBlack62
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var rowStrokeColor: Color {
        switch style {
        case .attachmentDraft:
            return AppColors.linkedMarkerAttachmentStroke
        case .messageCard(let isCurrentUser):
            return isCurrentUser ? AppColors.surfaceWhite12 : AppColors.symbolDetailCardFill
        }
    }

    private var timeframeText: String {
        timeframe.uppercased()
    }

    var body: some View {
        HStack(spacing: 10) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3, height: 28)

            // Prominent marker badge
            UnifiedMarkerBadge(
                intent: intent,
                alertSeverity: alertSeverity,
                sizeToken: .medium,
                emoji: intent == .reaction ? emoji : nil
            )

            // Core info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(ticker)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isCurrentUserMessage ? .white : AppColors.whiteText.opacity(0.96))
                        .lineLimit(1)

                    Text(timeframeText)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppColors.whiteText.opacity(0.88))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.whiteText.opacity(0.10)))
                }

                Text(intent.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.primaryForeground)
                        .background(AppColors.surfaceBlack45, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.surfaceWhite60)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
    }
}

// MARK: - ================================================================================================
// MARK: - RL DTO PROTOCOL CONFORMANCES
// MARK: - ================================================================================================

extension RLChatroomMessageDTO: RLChatMessageDisplayable {
    var authorUserId: UUID { author.userId }
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
    var messageAttachments: [RLMessageAttachmentDTO] {
        if !attachments.isEmpty {
            return attachments
        }
        if let attachmentUrl, !attachmentUrl.isEmpty {
            return [RLMessageAttachmentDTO(attachmentUrl: attachmentUrl, attachmentType: attachmentType, attachmentName: attachmentName)]
        }
        return []
    }
}

extension RLDMMessageDTO: RLChatMessageDisplayable {
    var authorUserId: UUID { author.userId }
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
    var messageAttachments: [RLMessageAttachmentDTO] {
        if !attachments.isEmpty {
            return attachments
        }
        if let attachmentUrl, !attachmentUrl.isEmpty {
            return [RLMessageAttachmentDTO(attachmentUrl: attachmentUrl, attachmentType: attachmentType, attachmentName: attachmentName)]
        }
        return []
    }
}

extension RLChartChatMessageDTO: RLChatMessageDisplayable {
    var authorUserId: UUID { author.userId }
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
    var messageAttachments: [RLMessageAttachmentDTO] {
        if !attachments.isEmpty {
            return attachments
        }
        if let attachmentUrl, !attachmentUrl.isEmpty {
            return [RLMessageAttachmentDTO(attachmentUrl: attachmentUrl, attachmentType: attachmentType, attachmentName: attachmentName)]
        }
        return []
    }
}

extension RLMarkerCommentDTO: RLChatMessageDisplayable {
    var authorUserId: UUID { author.userId }
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorAccuracy: Double? { author.accuracyRate }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
    var messageAttachments: [RLMessageAttachmentDTO] {
        if let attachmentUrl, !attachmentUrl.isEmpty {
            return [RLMessageAttachmentDTO(attachmentUrl: attachmentUrl, attachmentType: attachmentType, attachmentName: attachmentName)]
        }
        return []
    }
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
                    SettingsSectionHeader(title: "Quick Actions")

                    VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.horizontal, 16)
                    }

                    Divider()
                        .background(AppColors.whiteText.opacity(0.2))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Notifications Section
                    SettingsSectionHeader(title: "Notifications")

                    VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.horizontal, 16)

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
                        .background(AppColors.whiteText.opacity(0.2))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Privacy & Safety Section
                    SettingsSectionHeader(title: "Privacy & Safety")

                    VStack(alignment: .leading, spacing: 8) {
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
                rlAppState.showError(
                    title: RLUserFacingCopy.text(.errorNoGuildSelected),
                    message: RLUserFacingCopy.text(.errorSelectGuildFirst),
                    style: .toast
                )
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
                    SettingsSectionHeader(title: "Notifications")

                    VStack(alignment: .leading, spacing: 8) {
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
                        .background(AppColors.whiteText.opacity(0.2))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Privacy & Safety Section
                    SettingsSectionHeader(title: "Privacy & Safety")

                    VStack(alignment: .leading, spacing: 8) {
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
                            icon: isReported ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                            title: isReported ? "Reported" : "Report User",
                            subtitle: isReported ? "Moderators will review your report" : "Report inappropriate behavior",
                            iconColor: isReported ? .green : .red
                        ) {
                            guard !isReported else { return }
                            showReportOptions = true
                        }
                        .disabled(isReported)
                        .opacity(isReported ? 0.72 : 1)
                    }

                    Divider()
                        .background(AppColors.whiteText.opacity(0.2))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Danger Zone
                    SettingsSectionHeader(title: "Conversation")

                    VStack(alignment: .leading, spacing: 8) {
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
    
    private var isReported: Bool {
        rlAppState.hasReportedUser(guildId: thread.guildId, userId: participant.userId)
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
