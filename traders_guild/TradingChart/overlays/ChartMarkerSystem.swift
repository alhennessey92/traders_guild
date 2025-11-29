
//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  UPDATED v2 - Smart positioning + Marker clustering
//  - Markers positioned above candles with smart offset to avoid interference
//  - Multiple markers on same candle stack vertically or cluster if >3
//  - Load markers via API instead of hardcoding
//

import SwiftUI

// MARK: - Marker Manager

class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarker] = []
    @Published var selectedMarker: ChartMarker?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    
    /// Expanded cluster (shows all markers when tapped)
    @Published var expandedClusterCandleIndex: Int? = nil
    
    private let currentUserId: String
    private let currentGuildId: String
    
    /// Public accessor for guild ID
    var guildId: String {
        currentGuildId
    }
    
    init(userId: String = "user123", guildId: String = "guild1") {
        self.currentUserId = userId
        self.currentGuildId = guildId
    }
    
    // MARK: - API Loading
    
    /// Load markers from the API
    /// Call this after chart data is loaded
    func loadMarkersFromAPI(
        api: MockAPIService,
        symbol: String,
        guildId: UUID,
        timeframe: ChartTimeframe,
        candles: [Candle]
    ) async {
        do {
            let fetchedMarkers = try await api.fetchGuildChartMarkers(
                symbol: symbol,
                guildId: guildId,
                timeframe: timeframe,
                candleCount: candles.count
            )
            
            // Update marker prices based on actual candle data
            let positionedMarkers = SampleData.updateMarkerPrices(
                markers: fetchedMarkers,
                candles: candles
            )
            
            await MainActor.run {
                self.markers = positionedMarkers
            }
        } catch {
            print("Failed to load markers: \(error)")
        }
    }
    
    /// Clear all markers (when switching symbols)
    func clearMarkers() {
        markers.removeAll()
        expandedClusterCandleIndex = nil
    }
    
    // MARK: - Marker CRUD
    
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
    
    // MARK: - Filtering
    
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
    
    // MARK: - Clustering Logic
    
    /// Group markers by candle index
    func markersGroupedByCandle() -> [Int: [ChartMarker]] {
        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
    }
    
    /// Check if a candle has a cluster (more than 3 markers)
    func isCluster(candleIndex: Int) -> Bool {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        return group.count > 3 && expandedClusterCandleIndex != candleIndex
    }
    
    /// Get markers to display for a candle (handles clustering)
    func displayMarkers(forCandleIndex candleIndex: Int) -> [ChartMarker] {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        
        if group.count <= 3 || expandedClusterCandleIndex == candleIndex {
            return group
        } else {
            // Return empty - cluster indicator will be shown instead
            return []
        }
    }
    
    /// Toggle cluster expansion
    func toggleClusterExpansion(candleIndex: Int) {
        if expandedClusterCandleIndex == candleIndex {
            expandedClusterCandleIndex = nil
        } else {
            expandedClusterCandleIndex = candleIndex
        }
    }
    
    /// Get cluster info for a candle
    func clusterInfo(forCandleIndex candleIndex: Int) -> (count: Int, types: Set<MarkerType>)? {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        guard group.count > 3 && expandedClusterCandleIndex != candleIndex else { return nil }
        return (group.count, Set(group.map { $0.type }))
    }
}

// MARK: - Marker Position Calculator

/// Calculates smart positions for markers to avoid candle interference
/// Now considers adjacent candle markers and trend direction for smarter placement
struct MarkerPositionCalculator {
    
    /// Base offset above candle high (in pixels) - increased for better clearance
    static let baseOffset: CGFloat = 75
    
    /// Additional offset per stacked marker
    static let stackOffset: CGFloat = 38
    
    /// Maximum markers before clustering kicks in
    static let maxBeforeCluster = 3
    
    /// Horizontal range (in candle indices) to check for nearby markers
    static let proximityRange = 2
    
    /// Calculate Y positions for markers on the same candle
    /// Returns dictionary of marker ID to Y offset from candle high
    static func calculatePositions(
        markers: [ChartMarker],
        candleIndex: Int
    ) -> [UUID: CGFloat] {
        let markersAtCandle = markers.filter { $0.candleIndex == candleIndex }
        var positions: [UUID: CGFloat] = [:]
        
        // Sort by creation time (oldest first, so they stack consistently)
        let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
        
        for (index, marker) in sorted.enumerated() {
            // Each marker stacks above the previous one
            let offset = baseOffset + (CGFloat(index) * stackOffset)
            positions[marker.id] = offset
        }
        
        return positions
    }
    
    /// Check if markers should alternate above/below candle
    /// Returns true if marker should be below candle
    static func shouldPositionBelow(
        markerIndex: Int,
        totalMarkers: Int
    ) -> Bool {
        // If we have 2-3 markers, alternate positions
        guard totalMarkers >= 2 && totalMarkers <= maxBeforeCluster else { return false }
        return markerIndex % 2 == 1 // Odd indices go below
    }
    
    /// Determine if marker should be below based on trend direction
    /// Uptrend = markers above, Downtrend = markers below
    static func shouldPositionBelowBasedOnTrend(
        candle: Candle,
        previousCandle: Candle?
    ) -> Bool {
        guard let prev = previousCandle else { return false }
        
        // If current candle high is lower than previous, we're in a downtrend
        // In downtrend, position markers below candles for better visibility
        return candle.high < prev.high
    }
    
    /// Calculate extra vertical offset based on nearby markers to prevent overlap
    /// Returns additional offset if there are markers on adjacent candles
    static func calculateProximityOffset(
        candleIndex: Int,
        allMarkers: [ChartMarker],
        isBelow: Bool
    ) -> CGFloat {
        // Count markers on adjacent candles (within proximityRange)
        var nearbyCount = 0
        for delta in 1...proximityRange {
            let leftIndex = candleIndex - delta
            let rightIndex = candleIndex + delta
            
            nearbyCount += allMarkers.filter { $0.candleIndex == leftIndex }.count
            nearbyCount += allMarkers.filter { $0.candleIndex == rightIndex }.count
        }
        
        // If there are nearby markers, add staggered offset
        if nearbyCount > 0 {
            // Alternate vertical position based on candle index (even/odd)
            let staggerOffset: CGFloat = candleIndex % 2 == 0 ? 20 : 0
            return staggerOffset
        }
        
        return 0
    }
}

// MARK: - Canvas Drawing Functions

struct ChartMarkerSystem {
    
    /// Draw markers directly in the chart canvas with smart positioning
    /// - Markers stack above candles to avoid interference
    /// - Single markers on adjacent candles use trend-based positioning
    /// - Clusters shown when >3 markers on same candle
    /// - Supports animation for tapped markers
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
        totalOffset: CGFloat,
        expandedClusterIndex: Int? = nil,
        markerManager: MarkerManager? = nil,
        tappedMarkerId: UUID? = nil  // For tap animation
    ) {
        let scaledHeight = chartSize.height * priceScale
        
        // Get all visible markers for proximity calculations
        let allVisibleMarkers = markers.filter { $0.isVisible }
        
        // Group markers by candle
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        
        // Sort candle indices for consistent processing (needed for trend calculation)
        let sortedCandleIndices = groupedMarkers.keys.sorted()
        
        // Track which candles already have above/below markers for alternation
        var usedPositions: [Int: Bool] = [:]  // candleIndex -> isAbove (true = above, false = below)
        
        for candleIndex in sortedCandleIndices {
            guard let markersAtCandle = groupedMarkers[candleIndex],
                  candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            
            // Skip if not visible on screen
            if x < -totalCandleWidth * 2 || x > chartSize.width + totalCandleWidth * 2 {
                continue
            }
            
            let candle = candles[candleIndex]
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            
            let centerX = x + actualCandleWidth / 2
            
            // Check if this should be a cluster
            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
            
            if isCluster {
                // Draw cluster indicator
                drawClusterIndicator(
                    context: context,
                    position: CGPoint(x: centerX, y: candleHighY - MarkerPositionCalculator.baseOffset),
                    candleHighPoint: CGPoint(x: centerX, y: candleHighY),
                    count: markersAtCandle.count,
                    types: Set(markersAtCandle.map { $0.type })
                )
            } else {
                // Draw individual markers with smart stacking
                let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
                
                // For single markers, use trend-based and proximity-aware positioning
                let useTrendPositioning = sorted.count == 1
                
                for (index, marker) in sorted.enumerated() {
                    var shouldBeBelow: Bool
                    
                    if useTrendPositioning {
                        // Single marker: check trend and nearby markers
                        let previousCandle = candleIndex > 0 ? candles[candleIndex - 1] : nil
                        let trendBelow = MarkerPositionCalculator.shouldPositionBelowBasedOnTrend(
                            candle: candle,
                            previousCandle: previousCandle
                        )
                        
                        // Check if adjacent candles have markers above/below
                        let leftHasAbove = usedPositions[candleIndex - 1] == true
                        let rightHasAbove = usedPositions[candleIndex + 1] == true
                        let leftHasBelow = usedPositions[candleIndex - 1] == false
                        let rightHasBelow = usedPositions[candleIndex + 1] == false
                        
                        // Alternate with neighbors to prevent overlap
                        if leftHasAbove || rightHasAbove {
                            shouldBeBelow = true  // Go below if neighbors are above
                        } else if leftHasBelow || rightHasBelow {
                            shouldBeBelow = false  // Go above if neighbors are below
                        } else {
                            shouldBeBelow = trendBelow  // Use trend direction
                        }
                        
                        // Record this position for future markers
                        usedPositions[candleIndex] = !shouldBeBelow
                    } else {
                        // Multiple markers: use alternating positions
                        shouldBeBelow = MarkerPositionCalculator.shouldPositionBelow(
                            markerIndex: index,
                            totalMarkers: sorted.count
                        )
                    }
                    
                    let baseY: CGFloat
                    let anchorY: CGFloat
                    let stackDirection: CGFloat
                    
                    if shouldBeBelow {
                        // Position below candle low
                        baseY = candleLowY + MarkerPositionCalculator.baseOffset
                        anchorY = candleLowY
                        stackDirection = 1.0 // Stack downward
                    } else {
                        // Position above candle high (default)
                        baseY = candleHighY - MarkerPositionCalculator.baseOffset
                        anchorY = candleHighY
                        stackDirection = -1.0 // Stack upward
                    }
                    
                    // Calculate stacking offset (only for markers on same side)
                    let sameSideIndex = index / 2 // Every other marker is on same side
                    var stackOffsetValue = CGFloat(sameSideIndex) * MarkerPositionCalculator.stackOffset * stackDirection
                    
                    // Add proximity offset for single markers on adjacent candles
                    if useTrendPositioning {
                        let proximityOffset = MarkerPositionCalculator.calculateProximityOffset(
                            candleIndex: candleIndex,
                            allMarkers: allVisibleMarkers,
                            isBelow: shouldBeBelow
                        )
                        stackOffsetValue += proximityOffset * stackDirection
                    }
                    
                    let markerY = baseY + stackOffsetValue
                    
                    // Check if this marker should be animated (tapped)
                    let isAnimated = tappedMarkerId == marker.id
                    let scale: CGFloat = isAnimated ? 1.3 : 1.0
                    
                    // Draw the marker (with scale if animated)
                    drawSingleMarker(
                        context: context,
                        marker: marker,
                        position: CGPoint(x: centerX, y: markerY),
                        anchorPoint: CGPoint(x: centerX, y: anchorY),
                        isBelow: shouldBeBelow,
                        scale: scale
                    )
                }
            }
        }
    }
    
    /// Draw a single marker with connection line
    /// Supports scale animation for tap feedback
    private static func drawSingleMarker(
        context: GraphicsContext,
        marker: ChartMarker,
        position: CGPoint,
        anchorPoint: CGPoint,
        isBelow: Bool,
        scale: CGFloat = 1.0  // Animation scale (1.0 = normal, >1.0 = enlarged)
    ) {
        // Apply scale transform for animation
        let baseRadius: CGFloat = 16
        let scaledRadius = baseRadius * scale
        
        // Draw connection line (not scaled - stays consistent)
        let lineStartY = isBelow ? position.y - scaledRadius : position.y + scaledRadius
        let connectionPath = Path { path in
            path.move(to: CGPoint(x: position.x, y: lineStartY))
            path.addLine(to: anchorPoint)
        }
        context.stroke(
            connectionPath,
            with: .color(marker.type.color.opacity(0.6)),
            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
        )
        
        // Draw marker circle background (scaled)
        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.85)))
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 2.5 * scale)
        
        // Draw icon (scaled)
        if let resolved = context.resolveSymbol(id: marker.id) {
            // Apply scale transform to the resolved symbol
            var scaledContext = context
            scaledContext.scaleBy(x: scale, y: scale)
            let scaledPosition = CGPoint(x: position.x / scale, y: position.y / scale)
            scaledContext.draw(resolved, at: scaledPosition)
        } else {
            // Fallback: draw colored circle with letter (scaled)
            let iconRadius: CGFloat = 10 * scale
            let iconCircle = CGRect(
                x: position.x - iconRadius,
                y: position.y - iconRadius,
                width: iconRadius * 2,
                height: iconRadius * 2
            )
            context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color))
            
            context.draw(
                Text(String(marker.type.rawValue.prefix(1)))
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundColor(.white),
                at: position
            )
        }
        
        // Draw like badge (not scaled to keep it readable)
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = isBelow ? (scaledRadius + 4) : -(scaledRadius + 4)
            let likeCircleRect = CGRect(
                x: position.x + 10,
                y: position.y + badgeOffset - 9,
                width: 18,
                height: 18
            )
            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
            
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 19, y: position.y + badgeOffset)
            )
        }
        
        // Draw username label for other users' markers
        // (Small label below/above the marker)
        let labelY = isBelow ? position.y + scaledRadius + 8 : position.y - scaledRadius - 8
        context.draw(
            Text(marker.username)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.8)),
            at: CGPoint(x: position.x, y: labelY)
        )
    }
    
    /// Draw cluster indicator when >3 markers on same candle
    private static func drawClusterIndicator(
        context: GraphicsContext,
        position: CGPoint,
        candleHighPoint: CGPoint,
        count: Int,
        types: Set<MarkerType>
    ) {
        // FIXED: Sort types to get consistent color (prevents flickering on re-render)
        // Set iteration order is not guaranteed, so sorting ensures consistent color
        let sortedTypes = types.sorted { $0.rawValue < $1.rawValue }
        let primaryColor = sortedTypes.first?.color ?? .gray
        
        // Draw connection line
        let connectionPath = Path { path in
            path.move(to: CGPoint(x: position.x, y: position.y + 20))
            path.addLine(to: candleHighPoint)
        }
        
        context.stroke(
            connectionPath,
            with: .color(primaryColor.opacity(0.6)),
            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
        )
        
        // Draw cluster circle (larger than single marker)
        let circleRect = CGRect(
            x: position.x - 20,
            y: position.y - 20,
            width: 40,
            height: 40
        )
        
        // Solid background
        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.9)))
        
        // Draw colored ring (consistent color from sorted types)
        context.stroke(Path(ellipseIn: circleRect), with: .color(primaryColor), lineWidth: 3)
        
        // Draw count number
        context.draw(
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white),
            at: position
        )
        
        // Draw small "markers" label
        context.draw(
            Text("markers")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.7)),
            at: CGPoint(x: position.x, y: position.y + 28)
        )
        
        // Draw tap hint
        context.draw(
            Text("tap to expand")
                .font(.system(size: 7))
                .foregroundColor(.white.opacity(0.5)),
            at: CGPoint(x: position.x, y: position.y + 38)
        )
    }
}

// MARK: - Marker Creation Sheet

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
                        Text(chartData.formatPrice(price))
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

// MARK: - Marker Detail Sheet

struct MarkerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    let marker: ChartMarker
    let currentUserId: String
    let chartData: ChartDataManager
    
    @State private var isEditing = false
    @State private var editedNote: String = ""
    
    /// Backwards-compatible initializer
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
    
    /// Full initializer with chartData
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
                        Text(chartData.formatPrice(marker.price))
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

// MARK: - Cluster Expansion Sheet

struct ClusterExpansionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    let candleIndex: Int
    let chartData: ChartDataManager
    let onSelectMarker: (ChartMarker) -> Void
    
    private var markersAtCandle: [ChartMarker] {
        markerManager.filteredMarkers.filter { $0.candleIndex == candleIndex }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(markersAtCandle) { marker in
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSelectMarker(marker)
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Marker type icon
                            Circle()
                                .fill(marker.type.color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: marker.type.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(marker.type.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("by \(marker.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let note = marker.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            // Like count
                            if marker.likeCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("\(marker.likeCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(markersAtCandle.count) Markers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}









////
////  ChartMarkerSystem.swift
////  traders_guild
////
////  UPDATED v2 - Smart positioning + Marker clustering
////  - Markers positioned above candles with smart offset to avoid interference
////  - Multiple markers on same candle stack vertically or cluster if >3
////  - Load markers via API instead of hardcoding
////
//
//import SwiftUI
//
//// MARK: - Marker Manager
//
//class MarkerManager: ObservableObject {
//    @Published var markers: [ChartMarker] = []
//    @Published var selectedMarker: ChartMarker?
//    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
//    @Published var showOnlyMyMarkers: Bool = false
//    
//    /// Expanded cluster (shows all markers when tapped)
//    @Published var expandedClusterCandleIndex: Int? = nil
//    
//    private let currentUserId: String
//    private let currentGuildId: String
//    
//    /// Public accessor for guild ID
//    var guildId: String {
//        currentGuildId
//    }
//    
//    init(userId: String = "user123", guildId: String = "guild1") {
//        self.currentUserId = userId
//        self.currentGuildId = guildId
//    }
//    
//    // MARK: - API Loading
//    
//    /// Load markers from the API
//    /// Call this after chart data is loaded
//    func loadMarkersFromAPI(
//        api: MockAPIService,
//        symbol: String,
//        guildId: UUID,
//        timeframe: ChartTimeframe,
//        candles: [Candle]
//    ) async {
//        do {
//            let fetchedMarkers = try await api.fetchGuildChartMarkers(
//                symbol: symbol,
//                guildId: guildId,
//                timeframe: timeframe,
//                candleCount: candles.count
//            )
//            
//            // Update marker prices based on actual candle data
//            let positionedMarkers = SampleData.updateMarkerPrices(
//                markers: fetchedMarkers,
//                candles: candles
//            )
//            
//            await MainActor.run {
//                self.markers = positionedMarkers
//            }
//        } catch {
//            print("Failed to load markers: \(error)")
//        }
//    }
//    
//    /// Clear all markers (when switching symbols)
//    func clearMarkers() {
//        markers.removeAll()
//        expandedClusterCandleIndex = nil
//    }
//    
//    // MARK: - Marker CRUD
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
//    // MARK: - Filtering
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
//    
//    // MARK: - Clustering Logic
//    
//    /// Group markers by candle index
//    func markersGroupedByCandle() -> [Int: [ChartMarker]] {
//        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
//    }
//    
//    /// Check if a candle has a cluster (more than 3 markers)
//    func isCluster(candleIndex: Int) -> Bool {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        return group.count > 3 && expandedClusterCandleIndex != candleIndex
//    }
//    
//    /// Get markers to display for a candle (handles clustering)
//    func displayMarkers(forCandleIndex candleIndex: Int) -> [ChartMarker] {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        
//        if group.count <= 3 || expandedClusterCandleIndex == candleIndex {
//            return group
//        } else {
//            // Return empty - cluster indicator will be shown instead
//            return []
//        }
//    }
//    
//    /// Toggle cluster expansion
//    func toggleClusterExpansion(candleIndex: Int) {
//        if expandedClusterCandleIndex == candleIndex {
//            expandedClusterCandleIndex = nil
//        } else {
//            expandedClusterCandleIndex = candleIndex
//        }
//    }
//    
//    /// Get cluster info for a candle
//    func clusterInfo(forCandleIndex candleIndex: Int) -> (count: Int, types: Set<MarkerType>)? {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        guard group.count > 3 && expandedClusterCandleIndex != candleIndex else { return nil }
//        return (group.count, Set(group.map { $0.type }))
//    }
//}
//
//// MARK: - Marker Position Calculator
//
///// Calculates smart positions for markers to avoid candle interference
//struct MarkerPositionCalculator {
//    
//    /// Base offset above candle high (in pixels) - increased for better clearance
//    static let baseOffset: CGFloat = 75
//    
//    /// Additional offset per stacked marker
//    static let stackOffset: CGFloat = 38
//    
//    /// Maximum markers before clustering kicks in
//    static let maxBeforeCluster = 3
//    
//    /// Calculate Y positions for markers on the same candle
//    /// Returns dictionary of marker ID to Y offset from candle high
//    static func calculatePositions(
//        markers: [ChartMarker],
//        candleIndex: Int
//    ) -> [UUID: CGFloat] {
//        let markersAtCandle = markers.filter { $0.candleIndex == candleIndex }
//        var positions: [UUID: CGFloat] = [:]
//        
//        // Sort by creation time (oldest first, so they stack consistently)
//        let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//        
//        for (index, marker) in sorted.enumerated() {
//            // Each marker stacks above the previous one
//            let offset = baseOffset + (CGFloat(index) * stackOffset)
//            positions[marker.id] = offset
//        }
//        
//        return positions
//    }
//    
//    /// Check if markers should alternate above/below candle
//    /// Returns true if marker should be below candle
//    static func shouldPositionBelow(
//        markerIndex: Int,
//        totalMarkers: Int
//    ) -> Bool {
//        // If we have 2-3 markers, alternate positions
//        guard totalMarkers >= 2 && totalMarkers <= maxBeforeCluster else { return false }
//        return markerIndex % 2 == 1 // Odd indices go below
//    }
//}
//
//// MARK: - Canvas Drawing Functions
//
//struct ChartMarkerSystem {
//    
//    /// Draw markers directly in the chart canvas with smart positioning
//    /// - Markers stack above candles to avoid interference
//    /// - Clusters shown when >3 markers on same candle
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
//        totalOffset: CGFloat,
//        expandedClusterIndex: Int? = nil,
//        markerManager: MarkerManager? = nil
//    ) {
//        let scaledHeight = chartSize.height * priceScale
//        
//        // Group markers by candle
//        let groupedMarkers = Dictionary(grouping: markers.filter { $0.isVisible }) { $0.candleIndex }
//        
//        for (candleIndex, markersAtCandle) in groupedMarkers {
//            guard candleIndex >= 0 && candleIndex < candles.count else { continue }
//            
//            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
//            
//            // Skip if not visible on screen
//            if x < -totalCandleWidth * 2 || x > chartSize.width + totalCandleWidth * 2 {
//                continue
//            }
//            
//            let candle = candles[candleIndex]
//            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            
//            let centerX = x + actualCandleWidth / 2
//            
//            // Check if this should be a cluster
//            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
//            
//            if isCluster {
//                // Draw cluster indicator
//                drawClusterIndicator(
//                    context: context,
//                    position: CGPoint(x: centerX, y: candleHighY - MarkerPositionCalculator.baseOffset),
//                    candleHighPoint: CGPoint(x: centerX, y: candleHighY),
//                    count: markersAtCandle.count,
//                    types: Set(markersAtCandle.map { $0.type })
//                )
//            } else {
//                // Draw individual markers with smart stacking
//                let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//                
//                for (index, marker) in sorted.enumerated() {
//                    // Calculate position with stacking
//                    let shouldBeBelow = MarkerPositionCalculator.shouldPositionBelow(
//                        markerIndex: index,
//                        totalMarkers: sorted.count
//                    )
//                    
//                    let baseY: CGFloat
//                    let anchorY: CGFloat
//                    let stackDirection: CGFloat
//                    
//                    if shouldBeBelow {
//                        // Position below candle low
//                        baseY = candleLowY + MarkerPositionCalculator.baseOffset
//                        anchorY = candleLowY
//                        stackDirection = 1.0 // Stack downward
//                    } else {
//                        // Position above candle high (default)
//                        baseY = candleHighY - MarkerPositionCalculator.baseOffset
//                        anchorY = candleHighY
//                        stackDirection = -1.0 // Stack upward
//                    }
//                    
//                    // Calculate stacking offset (only for markers on same side)
//                    let sameSideIndex = index / 2 // Every other marker is on same side
//                    let stackOffset = CGFloat(sameSideIndex) * MarkerPositionCalculator.stackOffset * stackDirection
//                    let markerY = baseY + stackOffset
//                    
//                    // Draw the marker
//                    drawSingleMarker(
//                        context: context,
//                        marker: marker,
//                        position: CGPoint(x: centerX, y: markerY),
//                        anchorPoint: CGPoint(x: centerX, y: anchorY),
//                        isBelow: shouldBeBelow
//                    )
//                }
//            }
//        }
//    }
//    
//    /// Draw a single marker with connection line
//    private static func drawSingleMarker(
//        context: GraphicsContext,
//        marker: ChartMarker,
//        position: CGPoint,
//        anchorPoint: CGPoint,
//        isBelow: Bool
//    ) {
//        // Draw connection line
//        let lineStartY = isBelow ? position.y - 16 : position.y + 16
//        let connectionPath = Path { path in
//            path.move(to: CGPoint(x: position.x, y: lineStartY))
//            path.addLine(to: anchorPoint)
//        }
//        context.stroke(
//            connectionPath,
//            with: .color(marker.type.color.opacity(0.6)),
//            style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
//        )
//        
//        // Draw marker circle background
//        let circleRect = CGRect(
//            x: position.x - 16,
//            y: position.y - 16,
//            width: 32,
//            height: 32
//        )
//        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.85)))
//        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 2.5)
//        
//        // Draw icon
//        if let resolved = context.resolveSymbol(id: marker.id) {
//            context.draw(resolved, at: position)
//        } else {
//            // Fallback: draw colored circle with letter
//            let iconCircle = CGRect(
//                x: position.x - 10,
//                y: position.y - 10,
//                width: 20,
//                height: 20
//            )
//            context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color))
//            
//            context.draw(
//                Text(String(marker.type.rawValue.prefix(1)))
//                    .font(.system(size: 12, weight: .bold))
//                    .foregroundColor(.white),
//                at: position
//            )
//        }
//        
//        // Draw like badge
//        if marker.likeCount > 0 {
//            let badgeOffset: CGFloat = isBelow ? 20 : -20
//            let likeCircleRect = CGRect(
//                x: position.x + 10,
//                y: position.y + badgeOffset - 9,
//                width: 18,
//                height: 18
//            )
//            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
//            
//            context.draw(
//                Text("\(marker.likeCount)")
//                    .font(.system(size: 10, weight: .bold))
//                    .foregroundColor(.white),
//                at: CGPoint(x: position.x + 19, y: position.y + badgeOffset)
//            )
//        }
//        
//        // Draw username label for other users' markers
//        // (Small label below/above the marker)
//        let labelY = isBelow ? position.y + 24 : position.y - 24
//        context.draw(
//            Text(marker.username)
//                .font(.system(size: 8, weight: .medium))
//                .foregroundColor(.white.opacity(0.8)),
//            at: CGPoint(x: position.x, y: labelY)
//        )
//    }
//    
//    /// Draw cluster indicator when >3 markers on same candle
//    private static func drawClusterIndicator(
//        context: GraphicsContext,
//        position: CGPoint,
//        candleHighPoint: CGPoint,
//        count: Int,
//        types: Set<MarkerType>
//    ) {
//        // FIXED: Sort types to get consistent color (prevents flickering on re-render)
//        // Set iteration order is not guaranteed, so sorting ensures consistent color
//        let sortedTypes = types.sorted { $0.rawValue < $1.rawValue }
//        let primaryColor = sortedTypes.first?.color ?? .gray
//        
//        // Draw connection line
//        let connectionPath = Path { path in
//            path.move(to: CGPoint(x: position.x, y: position.y + 20))
//            path.addLine(to: candleHighPoint)
//        }
//        
//        context.stroke(
//            connectionPath,
//            with: .color(primaryColor.opacity(0.6)),
//            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
//        )
//        
//        // Draw cluster circle (larger than single marker)
//        let circleRect = CGRect(
//            x: position.x - 20,
//            y: position.y - 20,
//            width: 40,
//            height: 40
//        )
//        
//        // Solid background
//        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.9)))
//        
//        // Draw colored ring (consistent color from sorted types)
//        context.stroke(Path(ellipseIn: circleRect), with: .color(primaryColor), lineWidth: 3)
//        
//        // Draw count number
//        context.draw(
//            Text("\(count)")
//                .font(.system(size: 16, weight: .bold))
//                .foregroundColor(.white),
//            at: position
//        )
//        
//        // Draw small "markers" label
//        context.draw(
//            Text("markers")
//                .font(.system(size: 8))
//                .foregroundColor(.white.opacity(0.7)),
//            at: CGPoint(x: position.x, y: position.y + 28)
//        )
//        
//        // Draw tap hint
//        context.draw(
//            Text("tap to expand")
//                .font(.system(size: 7))
//                .foregroundColor(.white.opacity(0.5)),
//            at: CGPoint(x: position.x, y: position.y + 38)
//        )
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
//                        Text(chartData.formatPrice(price))
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
//    let chartData: ChartDataManager
//    
//    @State private var isEditing = false
//    @State private var editedNote: String = ""
//    
//    /// Backwards-compatible initializer
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
//    /// Full initializer with chartData
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
//                        Text(chartData.formatPrice(marker.price))
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
//// MARK: - Cluster Expansion Sheet
//
//struct ClusterExpansionSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    let candleIndex: Int
//    let chartData: ChartDataManager
//    let onSelectMarker: (ChartMarker) -> Void
//    
//    private var markersAtCandle: [ChartMarker] {
//        markerManager.filteredMarkers.filter { $0.candleIndex == candleIndex }
//    }
//    
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(markersAtCandle) { marker in
//                    Button(action: {
//                        dismiss()
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                            onSelectMarker(marker)
//                        }
//                    }) {
//                        HStack(spacing: 12) {
//                            // Marker type icon
//                            Circle()
//                                .fill(marker.type.color)
//                                .frame(width: 32, height: 32)
//                                .overlay {
//                                    Image(systemName: marker.type.icon)
//                                        .font(.system(size: 14))
//                                        .foregroundColor(.white)
//                                }
//                            
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text(marker.type.rawValue)
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                                
//                                Text("by \(marker.username)")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                
//                                if let note = marker.note, !note.isEmpty {
//                                    Text(note)
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                        .lineLimit(1)
//                                }
//                            }
//                            
//                            Spacer()
//                            
//                            // Like count
//                            if marker.likeCount > 0 {
//                                HStack(spacing: 2) {
//                                    Image(systemName: "heart.fill")
//                                        .font(.caption)
//                                        .foregroundColor(.red)
//                                    Text("\(marker.likeCount)")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                }
//                            }
//                            
//                            Image(systemName: "chevron.right")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                        .padding(.vertical, 4)
//                    }
//                }
//            }
//            .navigationTitle("\(markersAtCandle.count) Markers")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Done") { dismiss() }
//                }
//            }
//        }
//    }
//}
//
//
