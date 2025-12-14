//
//  chartSheetChatView.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/12/2025.
//
//  Chart-specific chat interface with symbol and guild context
//  FIXED: Proper keyboard handling, fixed input footer, improved header design
//
//  NOTE: Requires KeyboardHandler.swift in your project (shared utility)

import SwiftUI
import Combine

struct chartSheetChatView: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var appState: AppState
    @StateObject private var chartChatManager = ChartChatManager()
    @StateObject private var keyboardHandler = KeyboardHandler()
    
    @State private var messageText = ""
    @State private var showEditSheet = false
    @State private var messageToEdit: ChartChatMessageDTO? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            if chartChatManager.isLoadingChat {
                loadingView
            } else if let chat = chartChatManager.activeChartChat {
                chatContentView(for: chat)
            } else {
                emptyStateView
            }
        }
        .onAppear {
            chartChatManager.configure(with: appState)
            loadChatForCurrentSymbol()
        }
        .onChange(of: chartViewModel.currentSymbol) { _ in
            loadChatForCurrentSymbol()
        }
        .onChange(of: appState.currentGuild) { _ in
            loadChatForCurrentSymbol()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.accentColor)
            
            Text("Loading chat...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Symbol Selected")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Select a symbol to start chatting with your guild")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Chat Content View
    /// This view manages its own layout with fixed input at bottom
    private func chatContentView(for chat: ChartChatDTO) -> some View {
        VStack(spacing: 0) {
            // Header - compact and clean
            chartChatHeader(for: chat)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Messages area - takes remaining space
            if chartChatManager.messages.isEmpty {
                emptyMessagesView
            } else {
                messagesScrollView
            }
            
            // Input Footer - positioned above keyboard when open
            ChartChatInputFooter(
                chat: chat,
                messageText: $messageText,
                isInputFocused: _isInputFocused,
                chartChatManager: chartChatManager
            )
            .environmentObject(appState)
            .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight - 70 : 0)
            .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
        }
    }
    
    // MARK: - Chat Header (Improved Design)
    private func chartChatHeader(for chat: ChartChatDTO) -> some View {
        HStack(spacing: 12) {
            // Symbol avatar with chart icon
            Circle()
                .fill(AppColors.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accentColor)
                )
            
            // Symbol info
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.symbolTicker)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(chat.guildName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Active users pill
            if chat.activeUserCount > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("\(chat.activeUserCount) active")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 20)
    }
    
    // MARK: - Empty Messages View
    private var emptyMessagesView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("Start the conversation")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Be the first to share your analysis on \(chartChatManager.activeChartChat?.symbolTicker ?? "this symbol")")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chartChatManager.messages) { message in
                        ChartChatMessageView(
                            message: message,
                            onEdit: {
                                messageToEdit = message
                                showEditSheet = true
                            },
                            onDelete: {
                                Task {
                                    await deleteMessage(message)
                                }
                            }
                        )
                        .environmentObject(appState)
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: chartChatManager.messages.count) { _ in
                if let lastMessage = chartChatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .background(
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                    AppColors.sheetBackground
                    StaticPatternView()
                }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let message = messageToEdit {
                EditChartMessageSheet(
                    message: message,
                    onSave: { newContent in
                        Task {
                            await editMessage(message, newContent: newContent)
                        }
                    }
                )
                .environmentObject(appState)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadChatForCurrentSymbol() {
        guard let symbol = chartViewModel.currentSymbol,
              let guildId = appState.currentGuild?.id else {
            chartChatManager.closeChat()
            return
        }
        
        Task {
            await chartChatManager.updateForSymbol(
                symbol,
                guildId: guildId,
                api: MockAPIService()
            )
        }
    }
    
    private func editMessage(_ message: ChartChatMessageDTO, newContent: String) async {
        do {
            try await chartChatManager.editMessage(
                messageId: message.id,
                newContent: newContent,
                api: MockAPIService()
            )
            showEditSheet = false
            messageToEdit = nil
            appState.showSuccess("Message updated")
        } catch {
            appState.showError(error, title: "Failed to Update Message")
        }
    }
    
    private func deleteMessage(_ message: ChartChatMessageDTO) async {
        do {
            try await chartChatManager.deleteMessage(
                messageId: message.id,
                api: MockAPIService()
            )
            appState.showSuccess("Message deleted")
            HapticFeedback.light.trigger()
        } catch {
            appState.showError(error, title: "Failed to Delete Message")
        }
    }
}

// MARK: - Chart Chat Input Footer
/// Fixed input footer with proper keyboard handling
struct ChartChatInputFooter: View {
    let chat: ChartChatDTO
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let chartChatManager: ChartChatManager
    
    @EnvironmentObject var appState: AppState
    @State private var isSending: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Plus/attachment button
                    Button(action: {
                        // Future: Handle attachments
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    // Text input field
                    TextField("Message \(chat.symbolTicker)...", text: $messageText)
                        .font(.subheadline)
                        .submitLabel(.send)
                        .focused($isInputFocused)
                        .disabled(isSending)
                        .onSubmit {
                            Task { await sendMessage() }
                        }
                    
                    // Right side buttons
                    HStack(spacing: 8) {
                        // Mic button
                        Button(action: {
                            // Future: Handle voice message
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        
                        // Send button
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 40, height: 40)
                        } else {
                            Button(action: {
                                Task { await sendMessage() }
                            }) {
                                Image(systemName: "chevron.forward.2")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .padding(.leading, 2)
                                    .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                                    .clipShape(Capsule())
                            }
                            .disabled(messageText.isEmpty)
                        }
                    }
                }
                .padding(.leading, 10)
                .frame(height: 44)
                .background(AppColors.whiteText.opacity(0.08))
                .cornerRadius(25)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.sheetBackground)
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let textToSend = messageText
        messageText = ""
        isSending = true
        isInputFocused = false
        
        do {
            try await chartChatManager.sendMessage(
                content: textToSend,
                api: MockAPIService()
            )
            HapticFeedback.light.trigger()
        } catch {
            messageText = textToSend
            appState.showError(error, title: "Failed to Send Message")
        }
        
        isSending = false
    }
}

// MARK: - Chart Chat Message View
struct ChartChatMessageView: View {
    let message: ChartChatMessageDTO
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isCurrentUserMessage {
                Spacer(minLength: 48)
            } else {
                // Author avatar
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.author.globalMember.username.prefix(2)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            VStack(alignment: message.alignment, spacing: 4) {
                // Message bubble
                HStack(spacing: 8) {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(message.isCurrentUserMessage ? .white.opacity(0.7) : .secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.isCurrentUserMessage ?
                    AppColors.accentDarkColor :
                    Color.gray.opacity(0.2)
                )
                .clipShape(messageBubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
                .contextMenu {
                    if message.canEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    if message.canDelete {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    Button {
                        UIPasteboard.general.string = message.content
                        appState.showSuccess("Copied to clipboard")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                // Timestamp
                Text(message.timestampFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isCurrentUserMessage {
                Spacer(minLength: 48)
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }
    
    private func messageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
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

// MARK: - Edit Chart Message Sheet
struct EditChartMessageSheet: View {
    let message: ChartChatMessageDTO
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedText: String
    
    init(message: ChartChatMessageDTO, onSave: @escaping (String) -> Void) {
        self.message = message
        self.onSave = onSave
        _editedText = State(initialValue: message.content)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Message", text: $editedText, axis: .vertical)
                    .lineLimit(5...10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
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
                    Button("Save") {
                        onSave(editedText)
                        dismiss()
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// NOTE: KeyboardHandler class is in KeyboardHandler.swift (shared utility)






////
////  chartSheetChatView.swift
////  traders_guild
////
////  Created by Al Hennessey on 14/12/2025.
////
////  Chart-specific chat interface with symbol and guild context
////  FIXED: Proper keyboard handling, fixed input footer, improved header design
//
//import SwiftUI
//import Combine
//
//struct chartSheetChatView: View {
//    @ObservedObject var chartViewModel: ChartViewModel
//    @EnvironmentObject var appState: AppState
//    @StateObject private var chartChatManager = ChartChatManager()
//    @StateObject private var keyboardHandler = KeyboardHandler()
//    
//    @State private var messageText = ""
//    @State private var showEditSheet = false
//    @State private var messageToEdit: ChartChatMessageDTO? = nil
//    @FocusState private var isInputFocused: Bool
//    
//    var body: some View {
//        ZStack {
//            if chartChatManager.isLoadingChat {
//                loadingView
//            } else if let chat = chartChatManager.activeChartChat {
//                chatContentView(for: chat)
//            } else {
//                emptyStateView
//            }
//        }
//        .onAppear {
//            chartChatManager.configure(with: appState)
//            loadChatForCurrentSymbol()
//        }
//        .onChange(of: chartViewModel.currentSymbol) { _ in
//            loadChatForCurrentSymbol()
//        }
//        .onChange(of: appState.currentGuild) { _ in
//            loadChatForCurrentSymbol()
//        }
//    }
//    
//    // MARK: - Loading View
//    private var loadingView: some View {
//        VStack(spacing: 16) {
//            ProgressView()
//                .scaleEffect(1.2)
//                .tint(AppColors.accentColor)
//            
//            Text("Loading chat...")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // MARK: - Empty State View
//    private var emptyStateView: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "chart.line.uptrend.xyaxis")
//                .font(.system(size: 48))
//                .foregroundColor(.gray.opacity(0.5))
//            
//            Text("No Symbol Selected")
//                .font(.headline)
//                .foregroundColor(.white)
//            
//            Text("Select a symbol to start chatting with your guild")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // MARK: - Main Chat Content View
//    /// This view manages its own layout with fixed input at bottom
//    private func chatContentView(for chat: ChartChatDTO) -> some View {
//        VStack(spacing: 0) {
//            // Header - compact and clean
//            chartChatHeader(for: chat)
//            
//            Divider()
//                .background(Color.gray.opacity(0.3))
//            
//            // Messages area - takes remaining space
//            if chartChatManager.messages.isEmpty {
//                emptyMessagesView
//            } else {
//                messagesScrollView
//            }
//            
//            // Input Footer - positioned above keyboard when open
//            ChartChatInputFooter(
//                chat: chat,
//                messageText: $messageText,
//                isInputFocused: _isInputFocused,
//                chartChatManager: chartChatManager
//            )
//            .environmentObject(appState)
//            .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight - 70 : 0)
//            .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
//        }
//    }
//    
//    // MARK: - Chat Header (Improved Design)
//    private func chartChatHeader(for chat: ChartChatDTO) -> some View {
//        HStack(spacing: 12) {
//            // Symbol avatar with chart icon
//            Circle()
//                .fill(AppColors.accentColor.opacity(0.2))
//                .frame(width: 40, height: 40)
//                .overlay(
//                    Image(systemName: "chart.line.uptrend.xyaxis")
//                        .font(.system(size: 16, weight: .semibold))
//                        .foregroundColor(AppColors.accentColor)
//                )
//            
//            // Symbol info
//            VStack(alignment: .leading, spacing: 2) {
//                Text(chat.symbolTicker)
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white)
//                
//                Text(chat.guildName)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            Spacer()
//            
//            // Active users pill
//            if chat.activeUserCount > 0 {
//                HStack(spacing: 6) {
//                    Circle()
//                        .fill(Color.green)
//                        .frame(width: 6, height: 6)
//                    
//                    Text("\(chat.activeUserCount) active")
//                        .font(.caption2)
//                        .fontWeight(.medium)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.horizontal, 10)
//                .padding(.vertical, 6)
//                .background(Color.white.opacity(0.06))
//                .clipShape(Capsule())
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 12)
//    }
//    
//    // MARK: - Empty Messages View
//    private var emptyMessagesView: some View {
//        VStack(spacing: 12) {
//            Spacer()
//            
//            Image(systemName: "bubble.left.and.bubble.right")
//                .font(.system(size: 36))
//                .foregroundColor(.gray.opacity(0.4))
//            
//            Text("Start the conversation")
//                .font(.subheadline)
//                .fontWeight(.medium)
//                .foregroundColor(.secondary)
//            
//            Text("Be the first to share your analysis on \(chartChatManager.activeChartChat?.symbolTicker ?? "this symbol")")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal, 32)
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // MARK: - Messages Scroll View
//    private var messagesScrollView: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(spacing: 12) {
//                    ForEach(chartChatManager.messages) { message in
//                        ChartChatMessageView(
//                            message: message,
//                            onEdit: {
//                                messageToEdit = message
//                                showEditSheet = true
//                            },
//                            onDelete: {
//                                Task {
//                                    await deleteMessage(message)
//                                }
//                            }
//                        )
//                        .environmentObject(appState)
//                        .id(message.id)
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 12)
//            }
//            .scrollDismissesKeyboard(.interactively)
//            .onTapGesture {
//                isInputFocused = false
//            }
//            .onChange(of: chartChatManager.messages.count) { _ in
//                if let lastMessage = chartChatManager.messages.last {
//                    withAnimation(.easeOut(duration: 0.2)) {
//                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showEditSheet) {
//            if let message = messageToEdit {
//                EditChartMessageSheet(
//                    message: message,
//                    onSave: { newContent in
//                        Task {
//                            await editMessage(message, newContent: newContent)
//                        }
//                    }
//                )
//                .environmentObject(appState)
//            }
//        }
//    }
//    
//    // MARK: - Actions
//    
//    private func loadChatForCurrentSymbol() {
//        guard let symbol = chartViewModel.currentSymbol,
//              let guildId = appState.currentGuild?.id else {
//            chartChatManager.closeChat()
//            return
//        }
//        
//        Task {
//            await chartChatManager.updateForSymbol(
//                symbol,
//                guildId: guildId,
//                api: MockAPIService()
//            )
//        }
//    }
//    
//    private func editMessage(_ message: ChartChatMessageDTO, newContent: String) async {
//        do {
//            try await chartChatManager.editMessage(
//                messageId: message.id,
//                newContent: newContent,
//                api: MockAPIService()
//            )
//            showEditSheet = false
//            messageToEdit = nil
//            appState.showSuccess("Message updated")
//        } catch {
//            appState.showError(error, title: "Failed to Update Message")
//        }
//    }
//    
//    private func deleteMessage(_ message: ChartChatMessageDTO) async {
//        do {
//            try await chartChatManager.deleteMessage(
//                messageId: message.id,
//                api: MockAPIService()
//            )
//            appState.showSuccess("Message deleted")
//            HapticFeedback.light.trigger()
//        } catch {
//            appState.showError(error, title: "Failed to Delete Message")
//        }
//    }
//}
//
//// MARK: - Chart Chat Input Footer
///// Fixed input footer with proper keyboard handling
//struct ChartChatInputFooter: View {
//    let chat: ChartChatDTO
//    @Binding var messageText: String
//    @FocusState var isInputFocused: Bool
//    let chartChatManager: ChartChatManager
//    
//    @EnvironmentObject var appState: AppState
//    @State private var isSending: Bool = false
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            Divider()
//                .background(Color.gray.opacity(0.3))
//            
//            HStack(spacing: 0) {
//                HStack(spacing: 12) {
//                    // Plus/attachment button
//                    Button(action: {
//                        // Future: Handle attachments
//                    }) {
//                        Image(systemName: "plus")
//                            .font(.title3)
//                            .foregroundColor(.secondary)
//                            .frame(width: 32, height: 32)
//                    }
//                    
//                    // Text input field
//                    TextField("Message \(chat.symbolTicker)...", text: $messageText)
//                        .font(.subheadline)
//                        .submitLabel(.send)
//                        .focused($isInputFocused)
//                        .disabled(isSending)
//                        .onSubmit {
//                            Task { await sendMessage() }
//                        }
//                    
//                    // Right side buttons
//                    HStack(spacing: 8) {
//                        // Mic button
//                        Button(action: {
//                            // Future: Handle voice message
//                        }) {
//                            Image(systemName: "mic.fill")
//                                .font(.title3)
//                                .foregroundColor(.secondary)
//                                .frame(width: 32, height: 32)
//                        }
//                        
//                        // Send button
//                        if isSending {
//                            ProgressView()
//                                .scaleEffect(0.8)
//                                .frame(width: 40, height: 40)
//                        } else {
//                            Button(action: {
//                                Task { await sendMessage() }
//                            }) {
//                                Image(systemName: "chevron.forward.2")
//                                    .font(.title3)
//                                    .fontWeight(.bold)
//                                    .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
//                                    .frame(width: 40, height: 40)
//                                    .padding(.leading, 2)
//                                    .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
//                                    .clipShape(Capsule())
//                            }
//                            .disabled(messageText.isEmpty)
//                        }
//                    }
//                }
//                .padding(.leading, 10)
//                .frame(height: 44)
//                .background(AppColors.whiteText.opacity(0.08))
//                .cornerRadius(25)
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//        }
//        .background(AppColors.sheetBackground)
//    }
//    
//    private func sendMessage() async {
//        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
//        
//        let textToSend = messageText
//        messageText = ""
//        isSending = true
//        isInputFocused = false
//        
//        do {
//            try await chartChatManager.sendMessage(
//                content: textToSend,
//                api: MockAPIService()
//            )
//            HapticFeedback.light.trigger()
//        } catch {
//            messageText = textToSend
//            appState.showError(error, title: "Failed to Send Message")
//        }
//        
//        isSending = false
//    }
//}
//
//// MARK: - Chart Chat Message View
//struct ChartChatMessageView: View {
//    let message: ChartChatMessageDTO
//    let onEdit: () -> Void
//    let onDelete: () -> Void
//    
//    @EnvironmentObject var appState: AppState
//    @State private var showDeleteConfirmation = false
//    
//    var body: some View {
//        HStack(alignment: .top) {
//            if message.isCurrentUserMessage {
//                Spacer(minLength: 48)
//            } else {
//                // Author avatar
//                Circle()
//                    .fill(AppColors.accentColor.opacity(0.3))
//                    .frame(width: 32, height: 32)
//                    .overlay(
//                        Text(String(message.author.globalMember.username.prefix(2)))
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                    )
//            }
//            
//            VStack(alignment: message.alignment, spacing: 4) {
//                // Message bubble
//                HStack(spacing: 8) {
//                    Text(message.content)
//                        .font(.subheadline)
//                        .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
//                    
//                    if message.isEdited {
//                        Text("(edited)")
//                            .font(.caption2)
//                            .foregroundColor(message.isCurrentUserMessage ? .white.opacity(0.7) : .secondary)
//                    }
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(
//                    message.isCurrentUserMessage ?
//                    AppColors.accentDarkColor :
//                    Color.gray.opacity(0.2)
//                )
//                .clipShape(messageBubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
//                .contextMenu {
//                    if message.canEdit {
//                        Button {
//                            onEdit()
//                        } label: {
//                            Label("Edit", systemImage: "pencil")
//                        }
//                    }
//                    
//                    if message.canDelete {
//                        Button(role: .destructive) {
//                            showDeleteConfirmation = true
//                        } label: {
//                            Label("Delete", systemImage: "trash")
//                        }
//                    }
//                    
//                    Button {
//                        UIPasteboard.general.string = message.content
//                        appState.showSuccess("Copied to clipboard")
//                    } label: {
//                        Label("Copy", systemImage: "doc.on.doc")
//                    }
//                }
//                
//                // Timestamp
//                Text(message.timestampFormatted)
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//            
//            if !message.isCurrentUserMessage {
//                Spacer(minLength: 48)
//            }
//        }
//        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Delete", role: .destructive) {
//                onDelete()
//            }
//        } message: {
//            Text("Are you sure you want to delete this message? This cannot be undone.")
//        }
//    }
//    
//    private func messageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
//        if isFromCurrentUser {
//            return UnevenRoundedRectangle(
//                topLeadingRadius: 16,
//                bottomLeadingRadius: 16,
//                bottomTrailingRadius: 4,
//                topTrailingRadius: 16
//            )
//        } else {
//            return UnevenRoundedRectangle(
//                topLeadingRadius: 4,
//                bottomLeadingRadius: 16,
//                bottomTrailingRadius: 16,
//                topTrailingRadius: 16
//            )
//        }
//    }
//}
//
//// MARK: - Edit Chart Message Sheet
//struct EditChartMessageSheet: View {
//    let message: ChartChatMessageDTO
//    let onSave: (String) -> Void
//    
//    @Environment(\.dismiss) private var dismiss
//    @State private var editedText: String
//    
//    init(message: ChartChatMessageDTO, onSave: @escaping (String) -> Void) {
//        self.message = message
//        self.onSave = onSave
//        _editedText = State(initialValue: message.content)
//    }
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//                TextField("Message", text: $editedText, axis: .vertical)
//                    .lineLimit(5...10)
//                    .padding()
//                    .background(Color.gray.opacity(0.1))
//                    .cornerRadius(10)
//                    .padding()
//                
//                Spacer()
//            }
//            .navigationTitle("Edit Message")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        onSave(editedText)
//                        dismiss()
//                    }
//                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Keyboard Handler
///// Tracks keyboard height for proper input positioning
//final class KeyboardHandler: ObservableObject {
//    @Published var keyboardHeight: CGFloat = 0
//    
//    private var cancellables = Set<AnyCancellable>()
//    
//    init() {
//        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
//            .compactMap { notification -> CGFloat? in
//                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
//            }
//            .sink { [weak self] height in
//                self?.keyboardHeight = height
//            }
//            .store(in: &cancellables)
//        
//        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
//            .sink { [weak self] _ in
//                self?.keyboardHeight = 0
//            }
//            .store(in: &cancellables)
//    }
//}
