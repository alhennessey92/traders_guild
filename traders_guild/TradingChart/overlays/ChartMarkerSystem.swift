//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  UPDATED - Symbol-aware price formatting
//

import SwiftUI

// MARK: - Marker Types

enum MarkerType: String, Codable, CaseIterable {
    case entry = "Entry"
    case exit = "Exit"
    case stopLoss = "Stop Loss"
    case takeProfit = "Take Profit"
    case support = "Support"
    case resistance = "Resistance"
    case alert = "Alert"
    case pattern = "Pattern"
    case note = "Note"
    
    var color: Color {
        switch self {
        case .entry: return .green
        case .exit: return .orange
        case .stopLoss: return .red
        case .takeProfit: return .blue
        case .support: return .purple
        case .resistance: return .pink
        case .alert: return .yellow
        case .pattern: return .cyan
        case .note: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .entry: return "arrow.up.circle.fill"
        case .exit: return "arrow.down.circle.fill"
        case .stopLoss: return "xmark.shield.fill"
        case .takeProfit: return "checkmark.shield.fill"
        case .support: return "arrow.up"
        case .resistance: return "arrow.down"
        case .alert: return "bell.fill"
        case .pattern: return "sparkles"
        case .note: return "note.text"
        }
    }
}

// MARK: - Chart Marker Model

struct ChartMarker: Identifiable, Codable {
    let id: UUID
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let type: MarkerType
    let userId: String
    let username: String
    var note: String?
    let createdAt: Date
    let guildId: String
    var isVisible: Bool
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    
    init(
        id: UUID = UUID(),
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        userId: String,
        username: String,
        note: String? = nil,
        guildId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.type = type
        self.userId = userId
        self.username = username
        self.note = note
        self.guildId = guildId
        self.createdAt = createdAt
        self.isVisible = true
        self.likeCount = 0
        self.isLikedByCurrentUser = false
    }
}

// MARK: - Marker Manager

class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarker] = []
    @Published var selectedMarker: ChartMarker?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    
    private let currentUserId: String
    private let currentGuildId: String
    
    init(userId: String = "user123", guildId: String = "guild1") {
        self.currentUserId = userId
        self.currentGuildId = guildId
    }
    
    func addMarker(
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        username: String,
        note: String? = nil
    ) {
        let marker = ChartMarker(
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            userId: currentUserId,
            username: username,
            note: note,
            guildId: currentGuildId
        )
        markers.append(marker)
    }
    
    func deleteMarker(id: UUID) {
        markers.removeAll { $0.id == id }
    }
    
    func updateMarker(id: UUID, note: String) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        markers[index].note = note
    }
    
    func toggleLike(markerId: UUID) {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        markers[index].isLikedByCurrentUser.toggle()
        markers[index].likeCount += markers[index].isLikedByCurrentUser ? 1 : -1
    }
    
    var filteredMarkers: [ChartMarker] {
        markers.filter { marker in
            guard marker.isVisible else { return false }
            guard visibleTypes.contains(marker.type) else { return false }
            if showOnlyMyMarkers && marker.userId != currentUserId {
                return false
            }
            return true
        }
    }
}

// MARK: - Marker Creation Sheet (Updated with symbol-aware formatting)

struct MarkerCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let username: String
    let chartData: ChartDataManager
    
    @State private var selectedType: MarkerType = .note
    @State private var note: String = ""
    
    /// Backwards-compatible initializer (uses fallback formatting)
    init(
        markerManager: MarkerManager,
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        username: String
    ) {
        self.markerManager = markerManager
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.username = username
        self.chartData = ChartDataManager()
    }
    
    /// Full initializer with chartData for symbol-aware formatting
    init(
        markerManager: MarkerManager,
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        username: String,
        chartData: ChartDataManager
    ) {
        self.markerManager = markerManager
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.username = username
        self.chartData = chartData
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Marker Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MarkerType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Location") {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(chartData.formatPrice(price))  // Symbol-aware
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(timestamp.chartTimeLabel)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Note (Optional)") {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        markerManager.addMarker(
                            candleIndex: candleIndex,
                            timestamp: timestamp,
                            price: price,
                            type: selectedType,
                            username: username,
                            note: note.isEmpty ? nil : note
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Marker Detail Sheet (Updated with symbol-aware formatting)

struct MarkerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    let marker: ChartMarker
    let currentUserId: String
    let chartData: ChartDataManager
    
    @State private var isEditing = false
    @State private var editedNote: String = ""
    
    /// Backwards-compatible initializer (uses fallback formatting)
    init(
        markerManager: MarkerManager,
        marker: ChartMarker,
        currentUserId: String
    ) {
        self.markerManager = markerManager
        self.marker = marker
        self.currentUserId = currentUserId
        self.chartData = ChartDataManager()
    }
    
    /// Full initializer with chartData for symbol-aware formatting
    init(
        markerManager: MarkerManager,
        marker: ChartMarker,
        currentUserId: String,
        chartData: ChartDataManager
    ) {
        self.markerManager = markerManager
        self.marker = marker
        self.currentUserId = currentUserId
        self.chartData = chartData
    }
    
    private var isOwnMarker: Bool {
        marker.userId == currentUserId
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Marker Info") {
                    HStack {
                        Image(systemName: marker.type.icon)
                            .foregroundColor(marker.type.color)
                        Text(marker.type.rawValue)
                    }
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(chartData.formatPrice(marker.price))  // Symbol-aware
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(marker.timestamp.chartTimeLabel)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("By")
                        Spacer()
                        Text(marker.username)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let note = marker.note, !note.isEmpty {
                    Section("Note") {
                        if isEditing {
                            TextEditor(text: $editedNote)
                                .frame(minHeight: 100)
                        } else {
                            Text(note)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        markerManager.toggleLike(markerId: marker.id)
                    }) {
                        HStack {
                            Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .foregroundColor(marker.isLikedByCurrentUser ? .red : .gray)
                            Text("\(marker.likeCount) likes")
                        }
                    }
                }
                
                if isOwnMarker {
                    Section {
                        if isEditing {
                            Button("Save Changes") {
                                markerManager.updateMarker(id: marker.id, note: editedNote)
                                isEditing = false
                            }
                        } else {
                            Button("Edit Note") {
                                editedNote = marker.note ?? ""
                                isEditing = true
                            }
                        }
                        
                        Button("Delete Marker", role: .destructive) {
                            markerManager.deleteMarker(id: marker.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Marker Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            editedNote = marker.note ?? ""
        }
    }
}

// MARK: - Canvas Drawing Functions

struct ChartMarkerSystem {
    /// Draw markers directly in the chart canvas
    static func drawMarkers(
        context: GraphicsContext,
        markers: [ChartMarker],
        candles: [Candle],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        let scaledHeight = chartSize.height * priceScale
        
        for marker in markers where marker.isVisible {
            guard marker.candleIndex >= 0 && marker.candleIndex < candles.count else { continue }
            
            let x = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset
            
            if x < -totalCandleWidth || x > chartSize.width + totalCandleWidth {
                continue
            }
            
            let candle = candles[marker.candleIndex]
            let markerY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset - 50
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            
            let markerPosition = CGPoint(x: x + actualCandleWidth / 2, y: markerY)
            let candleHighPoint = CGPoint(x: x + actualCandleWidth / 2, y: candleHighY)
            
            // Draw connection line
            let connectionPath = Path { path in
                path.move(to: CGPoint(x: markerPosition.x, y: markerPosition.y + 16))
                path.addLine(to: candleHighPoint)
            }
            context.stroke(
                connectionPath,
                with: .color(marker.type.color.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )
            
            // Draw marker circle
            let circleRect = CGRect(
                x: markerPosition.x - 16,
                y: markerPosition.y - 16,
                width: 32,
                height: 32
            )
            context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.8)))
            context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 2)
            
            // Draw icon
            if let resolved = context.resolveSymbol(id: marker.id) {
                context.draw(resolved, at: markerPosition)
            } else {
                let iconCircle = CGRect(
                    x: markerPosition.x - 8,
                    y: markerPosition.y - 8,
                    width: 16,
                    height: 16
                )
                context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color))
                
                context.draw(
                    Text(String(marker.type.rawValue.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white),
                    at: markerPosition
                )
            }
            
            // Draw like badge
            if marker.likeCount > 0 {
                let likeCircleRect = CGRect(
                    x: markerPosition.x + 8,
                    y: markerPosition.y - 20,
                    width: 18,
                    height: 18
                )
                context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
                
                context.draw(
                    Text("\(marker.likeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white),
                    at: CGPoint(x: markerPosition.x + 17, y: markerPosition.y - 11)
                )
            }
        }
    }
    
}

////
////  ChartMarkerSystem.swift
////  traders_guild
////
//
//import SwiftUI
//
//// MARK: - Marker Types
//
//enum MarkerType: String, Codable, CaseIterable {
//    case entry = "Entry"
//    case exit = "Exit"
//    case stopLoss = "Stop Loss"
//    case takeProfit = "Take Profit"
//    case support = "Support"
//    case resistance = "Resistance"
//    case alert = "Alert"
//    case pattern = "Pattern"
//    case note = "Note"
//    
//    var color: Color {
//        switch self {
//        case .entry: return .green
//        case .exit: return .orange
//        case .stopLoss: return .red
//        case .takeProfit: return .blue
//        case .support: return .purple
//        case .resistance: return .pink
//        case .alert: return .yellow
//        case .pattern: return .cyan
//        case .note: return .gray
//        }
//    }
//    
//    var icon: String {
//        switch self {
//        case .entry: return "arrow.up.circle.fill"
//        case .exit: return "arrow.down.circle.fill"
//        case .stopLoss: return "xmark.shield.fill"
//        case .takeProfit: return "checkmark.shield.fill"
//        case .support: return "arrow.up"
//        case .resistance: return "arrow.down"
//        case .alert: return "bell.fill"
//        case .pattern: return "sparkles"
//        case .note: return "note.text"
//        }
//    }
//}
//
//// MARK: - Chart Marker Model
//
//struct ChartMarker: Identifiable, Codable {
//    let id: UUID
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let type: MarkerType
//    let userId: String
//    let username: String
//    var note: String?
//    let createdAt: Date
//    let guildId: String
//    var isVisible: Bool
//    var likeCount: Int
//    var isLikedByCurrentUser: Bool
//    
//    init(
//        id: UUID = UUID(),
//        candleIndex: Int,
//        timestamp: Date,
//        price: Double,
//        type: MarkerType,
//        userId: String,
//        username: String,
//        note: String? = nil,
//        guildId: String,
//        createdAt: Date = Date()
//    ) {
//        self.id = id
//        self.candleIndex = candleIndex
//        self.timestamp = timestamp
//        self.price = price
//        self.type = type
//        self.userId = userId
//        self.username = username
//        self.note = note
//        self.guildId = guildId
//        self.createdAt = createdAt
//        self.isVisible = true
//        self.likeCount = 0
//        self.isLikedByCurrentUser = false
//    }
//}
//
//// MARK: - Marker Manager
//
//class MarkerManager: ObservableObject {
//    @Published var markers: [ChartMarker] = []
//    @Published var selectedMarker: ChartMarker?
//    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
//    @Published var showOnlyMyMarkers: Bool = false
//    
//    private let currentUserId: String
//    private let currentGuildId: String
//    
//    init(userId: String = "user123", guildId: String = "guild1") {
//        self.currentUserId = userId
//        self.currentGuildId = guildId
//    }
//    
//    func addMarker(
//        candleIndex: Int,
//        timestamp: Date,
//        price: Double,
//        type: MarkerType,
//        username: String,
//        note: String? = nil
//    ) {
//        let marker = ChartMarker(
//            candleIndex: candleIndex,
//            timestamp: timestamp,
//            price: price,
//            type: type,
//            userId: currentUserId,
//            username: username,
//            note: note,
//            guildId: currentGuildId
//        )
//        markers.append(marker)
//    }
//    
//    func deleteMarker(id: UUID) {
//        markers.removeAll { $0.id == id }
//    }
//    
//    func updateMarker(id: UUID, note: String) {
//        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
//        markers[index].note = note
//    }
//    
//    func toggleLike(markerId: UUID) {
//        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
//        markers[index].isLikedByCurrentUser.toggle()
//        markers[index].likeCount += markers[index].isLikedByCurrentUser ? 1 : -1
//    }
//    
//    var filteredMarkers: [ChartMarker] {
//        markers.filter { marker in
//            guard marker.isVisible else { return false }
//            guard visibleTypes.contains(marker.type) else { return false }
//            if showOnlyMyMarkers && marker.userId != currentUserId {
//                return false
//            }
//            return true
//        }
//    }
//}
//
//// MARK: - Marker Creation Sheet
//
//struct MarkerCreationSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let username: String
//    
//    @State private var selectedType: MarkerType = .note
//    @State private var note: String = ""
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Marker Type") {
//                    Picker("Type", selection: $selectedType) {
//                        ForEach(MarkerType.allCases, id: \.self) { type in
//                            Label(type.rawValue, systemImage: type.icon)
//                                .tag(type)
//                        }
//                    }
//                    .pickerStyle(.wheel)
//                }
//                
//                Section("Location") {
//                    HStack {
//                        Text("Price")
//                        Spacer()
//                        Text(price.formattedPrice)
//                            .foregroundColor(.secondary)
//                    }
//                    HStack {
//                        Text("Time")
//                        Spacer()
//                        Text(timestamp.chartTimeLabel)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                Section("Note (Optional)") {
//                    TextEditor(text: $note)
//                        .frame(height: 100)
//                }
//            }
//            .navigationTitle("Add Marker")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Add") {
//                        markerManager.addMarker(
//                            candleIndex: candleIndex,
//                            timestamp: timestamp,
//                            price: price,
//                            type: selectedType,
//                            username: username,
//                            note: note.isEmpty ? nil : note
//                        )
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Marker Detail Sheet
//
//struct MarkerDetailSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    let marker: ChartMarker
//    let currentUserId: String
//    
//    @State private var isEditing = false
//    @State private var editedNote: String = ""
//    
//    var isOwnMarker: Bool {
//        marker.userId == currentUserId
//    }
//    
//    var body: some View {
//        NavigationView {
//            List {
//                Section {
//                    HStack {
//                        Image(systemName: marker.type.icon)
//                            .foregroundColor(marker.type.color)
//                        Text(marker.type.rawValue)
//                            .font(.headline)
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("Price:")
//                            Spacer()
//                            Text(marker.price.formattedPrice)
//                                .fontWeight(.semibold)
//                        }
//                        HStack {
//                            Text("Time:")
//                            Spacer()
//                            Text(marker.timestamp.chartTimeLabel)
//                                .foregroundColor(.secondary)
//                        }
//                        HStack {
//                            Text("Created by:")
//                            Spacer()
//                            Text(marker.username)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                    .font(.subheadline)
//                }
//                
//                if let note = marker.note, !note.isEmpty {
//                    Section("Note") {
//                        if isEditing && isOwnMarker {
//                            TextEditor(text: $editedNote)
//                                .frame(minHeight: 100)
//                        } else {
//                            Text(note)
//                        }
//                    }
//                }
//                
//                Section {
//                    Button(action: {
//                        markerManager.toggleLike(markerId: marker.id)
//                    }) {
//                        HStack {
//                            Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
//                                .foregroundColor(marker.isLikedByCurrentUser ? .red : .gray)
//                            Text("\(marker.likeCount) likes")
//                        }
//                    }
//                }
//                
//                if isOwnMarker {
//                    Section {
//                        if isEditing {
//                            Button("Save Changes") {
//                                markerManager.updateMarker(id: marker.id, note: editedNote)
//                                isEditing = false
//                            }
//                        } else {
//                            Button("Edit Note") {
//                                editedNote = marker.note ?? ""
//                                isEditing = true
//                            }
//                        }
//                        
//                        Button("Delete Marker", role: .destructive) {
//                            markerManager.deleteMarker(id: marker.id)
//                            dismiss()
//                        }
//                    }
//                }
//            }
//            .navigationTitle("Marker Details")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Done") { dismiss() }
//                }
//            }
//        }
//        .onAppear {
//            editedNote = marker.note ?? ""
//        }
//    }
//}
//
//// MARK: - Canvas Drawing Functions
//
//
//
//// MARK: - Canvas Drawing Functions
//
//// MARK: - Canvas Drawing Functions
//
//struct ChartMarkerSystem {
//    /// Draw markers directly in the chart canvas using exact same positioning as candles
//    static func drawMarkers(
//        context: GraphicsContext,
//        markers: [ChartMarker],
//        candles: [Candle],
//        chartSize: CGSize,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) {
//        let scaledHeight = chartSize.height * priceScale
//        
//        for marker in markers where marker.isVisible {
//            guard marker.candleIndex >= 0 && marker.candleIndex < candles.count else { continue }
//            
//            // EXACT same X position as candles
//            let x = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset
//            
//            // Skip if not visible
//            if x < -totalCandleWidth || x > chartSize.width + totalCandleWidth {
//                continue
//            }
//            
//            let candle = candles[marker.candleIndex]
//            
//            // Position marker higher above the candle's high point (50 instead of 30)
//            let markerY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset - 50
//            
//            // Calculate candle high point Y position for dotted line
//            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            
//            let markerPosition = CGPoint(x: x + actualCandleWidth / 2, y: markerY)
//            let candleHighPoint = CGPoint(x: x + actualCandleWidth / 2, y: candleHighY)
//            
//            // Draw dotted connection line from marker to candle high
//            let connectionPath = Path { path in
//                path.move(to: CGPoint(x: markerPosition.x, y: markerPosition.y + 16)) // Start from bottom of marker circle
//                path.addLine(to: candleHighPoint)
//            }
//            context.stroke(
//                connectionPath,
//                with: .color(marker.type.color.opacity(0.6)),
//                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
//            )
//            
//            // Draw marker background circle
//            let circleRect = CGRect(
//                x: markerPosition.x - 16,
//                y: markerPosition.y - 16,
//                width: 32,
//                height: 32
//            )
//            context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.8)))
//            context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 2)
//            
//            // Resolve and draw SF Symbol icon
//            if let resolved = context.resolveSymbol(id: marker.id) {
//                context.draw(resolved, at: markerPosition)
//            } else {
//                // Fallback: draw colored circle with letter
//                let iconCircle = CGRect(
//                    x: markerPosition.x - 8,
//                    y: markerPosition.y - 8,
//                    width: 16,
//                    height: 16
//                )
//                context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color))
//                
//                context.draw(
//                    Text(String(marker.type.rawValue.prefix(1)))
//                        .font(.system(size: 12, weight: .bold))
//                        .foregroundColor(.white),
//                    at: markerPosition
//                )
//            }
//            
//            // Draw like count badge if > 0
//            if marker.likeCount > 0 {
//                let likeCircleRect = CGRect(
//                    x: markerPosition.x + 8,
//                    y: markerPosition.y - 20,
//                    width: 18,
//                    height: 18
//                )
//                context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
//                
//                context.draw(
//                    Text("\(marker.likeCount)")
//                        .font(.system(size: 10, weight: .bold))
//                        .foregroundColor(.white),
//                    at: CGPoint(x: markerPosition.x + 17, y: markerPosition.y - 11)
//                )
//            }
//        }
//    }
//    
//    /// Draw marker preview in canvas
//    static func drawMarkerPreview(
//        context: GraphicsContext,
//        candleIndex: Int,
//        candles: [Candle],
//        chartSize: CGSize,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) {
//        guard candleIndex >= 0 && candleIndex < candles.count else { return }
//        
//        let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
//        let candle = candles[candleIndex]
//        let scaledHeight = chartSize.height * priceScale
//        
//        let markerY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset - 30
//        
//        let markerPosition = CGPoint(x: x + actualCandleWidth / 2, y: markerY)
//        
//        // Draw larger preview circle
//        let circleRect = CGRect(
//            x: markerPosition.x - 20,
//            y: markerPosition.y - 20,
//            width: 40,
//            height: 40
//        )
//        
//        context.fill(Path(ellipseIn: circleRect), with: .color(.blue))
//        context.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 3)
//        
//        // Draw pin icon as white circle
//        let pinCircle = CGRect(
//            x: markerPosition.x - 6,
//            y: markerPosition.y - 6,
//            width: 12,
//            height: 12
//        )
//        context.fill(Path(ellipseIn: pinCircle), with: .color(.white))
//        
//        // Draw info box
//        let infoY = markerY + 30
//        let infoBoxRect = CGRect(
//            x: markerPosition.x - 40,
//            y: infoY,
//            width: 80,
//            height: 40
//        )
//        
//        context.fill(Path(roundedRect: infoBoxRect, cornerRadius: 4), with: .color(.blue))
//        
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        let timeText = formatter.string(from: candle.timestamp)
//        
//        context.draw(
//            Text(timeText)
//                .font(.caption2)
//                .foregroundColor(.white),
//            at: CGPoint(x: markerPosition.x, y: infoY + 10)
//        )
//        
//        context.draw(
//            Text(candle.close.formattedPrice)
//                .font(.caption)
//                .fontWeight(.bold)
//                .foregroundColor(.white),
//            at: CGPoint(x: markerPosition.x, y: infoY + 25)
//        )
//    }
//}
