//
//  RealTimeService.swift
//  traders_guild
//
//  Manages WebSocket connections, heartbeats, and event broadcasting.
//  Matches backend router.py logic.
//

import Foundation
import Combine

// MARK: - Connection Status
enum RealTimeConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(Error)
}

func == (lhs: RealTimeConnectionStatus, rhs: RealTimeConnectionStatus) -> Bool {
    switch (lhs, rhs) {
    case (.disconnected, .disconnected),
         (.connecting, .connecting),
         (.connected, .connected):
        return true
    case (.error(let lhsError), .error(let rhsError)):
        return lhsError.localizedDescription == rhsError.localizedDescription
    default:
        return false
    }
}

// MARK: - Real Time Service
class RealTimeService: ObservableObject {
    
    // MARK: - Properties
    
    static let shared = RealTimeService()
    
    @Published var connectionStatus: RealTimeConnectionStatus = .disconnected
    
    // Stream for incoming messages (other ViewModels listen to this)
    let messageSubject = PassthroughSubject<WSIncomingMessage, Never>()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectAttempt = 0
    private var activeToken: String?
    private var isIntentionalDisconnect = false
    
    // Subscriptions tracking
    private var subscribedChannels = Set<String>()
    private var subscriptionsQueue = Set<String>() // Channels waiting to be subscribed upon connection
    private var channelOwners: [String: Set<String>] = [:]
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    // MARK: - Lifecycle
    
    private init() {}
    
    /// Connect to the WebSocket using the provided JWT token
    func connect(token: String) {
        // If we're already connected/connecting with a different token, restart.
        if connectionStatus == .connected || connectionStatus == .connecting {
            if activeToken != token {
                print("🔁 [WS] Token changed, reconnecting")
                reconnectWithNewToken(token)
            }
            return
        }
        
        self.activeToken = token
        self.isIntentionalDisconnect = false
        self.reconnectAttempt = 0
        
        print("🌐 [WS] Initiating connect")
        establishConnection()
    }

    private func reconnectWithNewToken(_ token: String) {
        activeToken = token
        isIntentionalDisconnect = false
        reconnectAttempt = 0

        // Preserve subscriptions by moving them to the queue for re-subscribe.
        subscriptionsQueue.formUnion(subscribedChannels)
        subscriptionsQueue.formUnion(channelOwners.keys)
        subscribedChannels.removeAll()

        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected

        establishConnection()
    }
    
    private func establishConnection() {
        guard let token = activeToken else { return }
        
        connectionStatus = .connecting
        
        // Determine URL scheme (ws or wss) based on environment
        // Leveraging existing APIService logic but swapping protocol
        let httpURL = APIService.messaging.baseURL
        let wsURLString = httpURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "/api/v1/messaging", with: "/ws/messaging")
        
        guard let url = URL(string: "\(wsURLString)?token=\(token)") else {
            print("❌ [WS] Invalid URL")
            connectionStatus = .error(APIError.invalidURL)
            return
        }
        
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        
        webSocketTask?.resume()
        
        receiveMessage()
        startPingTimer()
        
        print("🌐 [WS] Connecting to \(url.absoluteString)...")
    }
    
    /// Disconnect cleanly
    func disconnect() {
        isIntentionalDisconnect = true
        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        subscribedChannels.removeAll()
        print("🔌 [WS] Disconnected")
    }
    
    // MARK: - Sending Messages
    
    /// Subscribe to specific channels (e.g., "chatroom:uuid")
    func subscribe(to channels: [String]) {
        subscribe(to: channels, owner: "default")
    }
    
    /// Subscribe to channels with ownership tagging
    func subscribe(to channels: [String], owner: String) {
        // If not connected, queue them up
        guard connectionStatus == .connected else {
            channels.forEach { channel in
                var owners = channelOwners[channel, default: []]
                owners.insert(owner)
                channelOwners[channel] = owners
                subscriptionsQueue.insert(channel)
            }
            print("🕒 [WS] Queued subscriptions: \(channels) owner=\(owner)")
            return
        }
        
        var channelsToSubscribe: [String] = []
        for channel in channels {
            var owners = channelOwners[channel, default: []]
            let wasEmpty = owners.isEmpty
            owners.insert(owner)
            channelOwners[channel] = owners
            if wasEmpty && !subscribedChannels.contains(channel) {
                channelsToSubscribe.append(channel)
            }
        }
        
        guard !channelsToSubscribe.isEmpty else { return }
        
        let message = WSSubscribeMessage(channels: channelsToSubscribe)
        send(message)
        
        // Optimistically add to tracked set
        channelsToSubscribe.forEach { subscribedChannels.insert($0) }
        print("📡 [WS] Subscribed: \(channelsToSubscribe) owner=\(owner)")
    }
    
    /// Unsubscribe from channels
    func unsubscribe(from channels: [String]) {
        unsubscribe(from: channels, owner: "default")
    }
    
    /// Unsubscribe from channels with ownership tagging
    func unsubscribe(from channels: [String], owner: String) {
        var channelsToRemove: [String] = []
        for channel in channels {
            guard var owners = channelOwners[channel] else { continue }
            owners.remove(owner)
            if owners.isEmpty {
                channelOwners.removeValue(forKey: channel)
                subscriptionsQueue.remove(channel)
                if subscribedChannels.contains(channel) {
                    channelsToRemove.append(channel)
                }
            } else {
                channelOwners[channel] = owners
            }
        }
        
        guard !channelsToRemove.isEmpty else { return }
        
        // Send unsubscribe message if connected
        if connectionStatus == .connected {
            let message = WSUnsubscribeMessage(channels: channelsToRemove)
            send(message)
        }
        
        channelsToRemove.forEach { subscribedChannels.remove($0) }
        print("📡 [WS] Unsubscribed: \(channelsToRemove) owner=\(owner)")
    }
    
    /// Send typing indicator
    func sendTyping(channel: String, isTyping: Bool) {
        let message = WSTypingMessage(channel: channel, isTyping: isTyping)
        send(message)
    }
    
    /// Generic send helper
    private func send<T: Encodable>(_ message: T) {
        guard let data = try? encoder.encode(message),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        
        print("➡️ [WS] Sending: \(jsonString)")
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("❌ [WS] Send error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Receiving Messages
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                print("⬅️ [WS] Received frame")
                self.handleIncomingMessage(message)
                self.receiveMessage() // Loop
                
            case .failure(let error):
                print("❌ [WS] Receive error: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
            }
        }
    }
    
    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) {
        // Upon first successful message, we confirm connection
        if connectionStatus != .connected {
            DispatchQueue.main.async {
                self.connectionStatus = .connected
                self.reconnectAttempt = 0
                self.processPendingSubscriptions()
                print("✅ [WS] Connected")
            }
        }
        
        var data: Data?
        switch message {
        case .string(let text):
            data = text.data(using: .utf8)
        case .data(let binData):
            data = binData
        @unknown default:
            return
        }
        
        guard let validData = data else { return }
        
        do {
            let decodedMessage = try decoder.decode(WSIncomingMessage.self, from: validData)
            print("📥 [WS] Message: type=\(decodedMessage.type) channel=\(decodedMessage.channel ?? "nil")")
            
            // Handle protocol-level messages (pong, errors)
            if decodedMessage.type == "pong" {
                // Heartbeat handled
                return
            }
            
            // Broadcast to app
            DispatchQueue.main.async {
                self.messageSubject.send(decodedMessage)
            }
        } catch {
            print("❌ [WS] Decode error: \(error)")
        }
    }
    
    // MARK: - Subscriptions Queue
    
    private func processPendingSubscriptions() {
        let channels = Array(Set(subscriptionsQueue).union(channelOwners.keys))
        guard !channels.isEmpty else { return }
        
        // Clear queue before calling subscribe to prevent loop, 
        // though subscribe() logic handles connected state check.
        subscriptionsQueue.removeAll()
        
        let channelsToSubscribe = channels.filter { !subscribedChannels.contains($0) }
        guard !channelsToSubscribe.isEmpty else { return }
        let message = WSSubscribeMessage(channels: channelsToSubscribe)
        send(message)
        channelsToSubscribe.forEach { subscribedChannels.insert($0) }
    }
    
    // MARK: - Heartbeat & Reconnection
    
    private func startPingTimer() {
        stopPingTimer()
        // Backend doesn't strictly require pings if TCP keepalive works,
        // but explicit ping/pong is safer for mobile.
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        let message = WSPingMessage()
        send(message)
    }
    
    private func handleDisconnect(error: Error) {
        guard !isIntentionalDisconnect else { return }
        
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.attemptReconnect()
        }
    }
    
    private func attemptReconnect() {
        guard activeToken != nil else { return }
        
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0) // Exponential backoff max 30s
        
        print("🔄 [WS] Reconnecting in \(Int(delay))s (Attempt \(reconnectAttempt))...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isIntentionalDisconnect else { return }
            self.establishConnection()
        }
    }
}