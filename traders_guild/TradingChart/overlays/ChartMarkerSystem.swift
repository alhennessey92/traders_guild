//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  UPDATED - Symbol-aware price formatting
//

import SwiftUI



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
    
    // MARK: - Sample Guild Markers
    
    /// Generate sample markers from other guild members for testing
    /// Call this after chart data is loaded to place markers on actual candles
    /// - Parameters:
    ///   - candles: The chart candles to place markers on
    ///   - count: Number of sample markers to generate (default 5)
    func generateSampleGuildMarkers(candles: [Candle], count: Int = 5) {
        // Sample guild member data
        let guildMembers: [(userId: String, username: String)] = [
            ("member_alex", "Alex_Trader"),
            ("member_sarah", "SarahFX"),
            ("member_mike", "MikeTheChart"),
            ("member_emma", "EmmaSwings"),
            ("member_james", "JamesPips")
        ]
        
        // Sample notes for markers
        let sampleNotes: [String?] = [
            "Strong support level here",
            "Watching for breakout",
            "Nice entry on the retest",
            nil,
            "Previous resistance now support",
            "Be careful - high volatility zone",
            nil,
            "Good R:R setup"
        ]
        
        // Sample marker types with realistic distribution
        let markerTypes: [MarkerType] = [
            .entry, .entry,
            .exit,
            .stopLoss, .stopLoss,
            .takeProfit,
            .support, .support, .support,
            .resistance, .resistance,
            .alert,
            .note
        ]
        
        guard candles.count >= 20 else { return }
        
        // Generate markers at semi-random positions
        let startIndex = 10  // Don't place markers on very first candles
        let endIndex = candles.count - 5
        let step = max(1, (endIndex - startIndex) / count)
        
        for i in 0..<count {
            let candleIndex = startIndex + (i * step) + Int.random(in: 0...max(0, step/2))
            guard candleIndex < candles.count else { continue }
            
            let candle = candles[candleIndex]
            let member = guildMembers[i % guildMembers.count]
            let markerType = markerTypes[Int.random(in: 0..<markerTypes.count)]
            let note = sampleNotes[Int.random(in: 0..<sampleNotes.count)]
            
            // Calculate price based on marker type
            let price: Double
            switch markerType {
            case .support:
                price = candle.low
            case .resistance:
                price = candle.high
            case .entry, .takeProfit:
                price = candle.close
            case .exit, .stopLoss:
                price = candle.open
            default:
                price = (candle.high + candle.low) / 2
            }
            
            // Create marker with random like count
            var marker = ChartMarker(
                candleIndex: candleIndex,
                timestamp: candle.timestamp,
                price: price,
                type: markerType,
                userId: member.userId,
                username: member.username,
                note: note,
                guildId: currentGuildId,
                createdAt: candle.timestamp.addingTimeInterval(Double.random(in: 60...3600))
            )
            marker.likeCount = Int.random(in: 0...12)
            marker.isLikedByCurrentUser = Bool.random() && marker.likeCount > 0
            
            markers.append(marker)
        }
    }
    
    /// Clear all sample markers (markers not from current user)
    func clearSampleMarkers() {
        markers.removeAll { $0.userId != currentUserId }
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
////  UPDATED - Symbol-aware price formatting
////
//
//import SwiftUI
//
//
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
//// MARK: - Marker Creation Sheet (Updated with symbol-aware formatting)
//
//struct MarkerCreationSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let username: String
//    let chartData: ChartDataManager
//    
//    @State private var selectedType: MarkerType = .note
//    @State private var note: String = ""
//    
//    /// Backwards-compatible initializer (uses fallback formatting)
//    init(
//        markerManager: MarkerManager,
//        candleIndex: Int,
//        timestamp: Date,
//        price: Double,
//        username: String
//    ) {
//        self.markerManager = markerManager
//        self.candleIndex = candleIndex
//        self.timestamp = timestamp
//        self.price = price
//        self.username = username
//        self.chartData = ChartDataManager()
//    }
//    
//    /// Full initializer with chartData for symbol-aware formatting
//    init(
//        markerManager: MarkerManager,
//        candleIndex: Int,
//        timestamp: Date,
//        price: Double,
//        username: String,
//        chartData: ChartDataManager
//    ) {
//        self.markerManager = markerManager
//        self.candleIndex = candleIndex
//        self.timestamp = timestamp
//        self.price = price
//        self.username = username
//        self.chartData = chartData
//    }
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
//                        Text(chartData.formatPrice(price))  // Symbol-aware
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
//// MARK: - Marker Detail Sheet (Updated with symbol-aware formatting)
//
//struct MarkerDetailSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    let marker: ChartMarker
//    let currentUserId: String
//    let chartData: ChartDataManager
//    
//    @State private var isEditing = false
//    @State private var editedNote: String = ""
//    
//    /// Backwards-compatible initializer (uses fallback formatting)
//    init(
//        markerManager: MarkerManager,
//        marker: ChartMarker,
//        currentUserId: String
//    ) {
//        self.markerManager = markerManager
//        self.marker = marker
//        self.currentUserId = currentUserId
//        self.chartData = ChartDataManager()
//    }
//    
//    /// Full initializer with chartData for symbol-aware formatting
//    init(
//        markerManager: MarkerManager,
//        marker: ChartMarker,
//        currentUserId: String,
//        chartData: ChartDataManager
//    ) {
//        self.markerManager = markerManager
//        self.marker = marker
//        self.currentUserId = currentUserId
//        self.chartData = chartData
//    }
//    
//    private var isOwnMarker: Bool {
//        marker.userId == currentUserId
//    }
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Marker Info") {
//                    HStack {
//                        Image(systemName: marker.type.icon)
//                            .foregroundColor(marker.type.color)
//                        Text(marker.type.rawValue)
//                    }
//                    
//                    HStack {
//                        Text("Price")
//                        Spacer()
//                        Text(chartData.formatPrice(marker.price))  // Symbol-aware
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    HStack {
//                        Text("Time")
//                        Spacer()
//                        Text(marker.timestamp.chartTimeLabel)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    HStack {
//                        Text("By")
//                        Spacer()
//                        Text(marker.username)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                if let note = marker.note, !note.isEmpty {
//                    Section("Note") {
//                        if isEditing {
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
//struct ChartMarkerSystem {
//    /// Draw markers directly in the chart canvas
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
//            let x = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset
//            
//            if x < -totalCandleWidth || x > chartSize.width + totalCandleWidth {
//                continue
//            }
//            
//            let candle = candles[marker.candleIndex]
//            let markerY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset - 50
//            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            
//            let markerPosition = CGPoint(x: x + actualCandleWidth / 2, y: markerY)
//            let candleHighPoint = CGPoint(x: x + actualCandleWidth / 2, y: candleHighY)
//            
//            // Draw connection line
//            let connectionPath = Path { path in
//                path.move(to: CGPoint(x: markerPosition.x, y: markerPosition.y + 16))
//                path.addLine(to: candleHighPoint)
//            }
//            context.stroke(
//                connectionPath,
//                with: .color(marker.type.color.opacity(0.6)),
//                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
//            )
//            
//            // Draw marker circle
//            let circleRect = CGRect(
//                x: markerPosition.x - 16,
//                y: markerPosition.y - 16,
//                width: 32,
//                height: 32
//            )
//            context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.8)))
//            context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 2)
//            
//            // Draw icon
//            if let resolved = context.resolveSymbol(id: marker.id) {
//                context.draw(resolved, at: markerPosition)
//            } else {
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
//            // Draw like badge
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
//}
