//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  COMPREHENSIVE FIX v5 - Addresses ALL issues:
//  1. MarkerCreationSheet now passes candles for proper positioning
//  2. Hit detection uses stored positions (shared calculation)
//  3. Increased stack offsets to prevent name overlap
//  4. Connection lines stop at marker edges
//  5. Better peak/valley detection
//
//  NOTE: ChartMarker and MarkerType are defined in ChartModels.swift
//

import SwiftUI

// MARK: - Marker Manager

class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarker] = []
    @Published var selectedMarker: ChartMarker?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    @Published var expandedClusterCandleIndex: Int? = nil
    
    private let currentUserId: String
    private let currentGuildId: String
    
    var guildId: String { currentGuildId }
    var userId: String { currentUserId }
    
    init(userId: String = "user123", guildId: String = "guild1") {
        self.currentUserId = userId
        self.currentGuildId = guildId
    }
    
    // MARK: - API Loading
    
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
            
            var positionedMarkers = SampleData.updateMarkerPrices(
                markers: fetchedMarkers,
                candles: candles
            )
            
            positionedMarkers = MarkerPositionCalculator.assignStablePositions(
                markers: positionedMarkers,
                candles: candles
            )
            
            await MainActor.run {
                self.markers = positionedMarkers
            }
        } catch {
            print("Failed to load markers: \(error)")
        }
    }
    
    func clearMarkers() {
        markers.removeAll()
        expandedClusterCandleIndex = nil
    }
    
    // MARK: - Marker CRUD
    
    /// Add a new marker WITH proper positioning calculation
    /// This is the PRIMARY method - always use this when candles are available
    func addMarker(
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        username: String,
        note: String? = nil,
        candles: [Candle]
    ) {
        var marker = ChartMarker(
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            userId: currentUserId,
            username: username,
            note: note,
            guildId: currentGuildId
        )
        
        // CRITICAL: Calculate proper position based on existing markers and candle data
        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        
        print("📍 Adding marker at candle \(candleIndex): below=\(positioning.isBelow), tier=\(positioning.tier), stack=\(positioning.stackIndex)")
        
        markers.append(marker)
    }
    
    /// DEPRECATED: Backwards-compatible addMarker without candles
    /// Only use when candles are truly unavailable - positioning will be suboptimal
    func addMarker(
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        username: String,
        note: String? = nil
    ) {
        // Try to get some positioning info from existing markers
        let markersAtCandle = markers.filter { $0.candleIndex == candleIndex }
        let markersAbove = markersAtCandle.filter { !$0.positionedBelow }
        let markersBelow = markersAtCandle.filter { $0.positionedBelow }
        
        // Alternate: if more markers above, put below
        let shouldBeBelow = markersAbove.count > markersBelow.count
        let stackIndex = shouldBeBelow ? markersBelow.count : markersAbove.count
        
        // Check nearby markers for tier
        let nearbyMarkers = markers.filter {
            abs($0.candleIndex - candleIndex) <= MarkerPositionCalculator.proximityRange &&
            $0.positionedBelow == shouldBeBelow
        }
        let usedTiers = Set(nearbyMarkers.map { $0.proximityTier })
        var tier = 0
        while usedTiers.contains(tier) {
            tier += 1
        }
        
        let marker = ChartMarker(
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            userId: currentUserId,
            username: username,
            note: note,
            guildId: currentGuildId,
            positionedBelow: shouldBeBelow,
            proximityTier: tier,
            stackIndex: stackIndex
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
    
    func markersGroupedByCandle() -> [Int: [ChartMarker]] {
        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
    }
    
    func isCluster(candleIndex: Int) -> Bool {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        return group.count > MarkerDisplaySettings.shared.maxBeforeCluster && expandedClusterCandleIndex != candleIndex
    }
    
    func displayMarkers(forCandleIndex candleIndex: Int) -> [ChartMarker] {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        let maxBeforeCluster = MarkerDisplaySettings.shared.maxBeforeCluster
        
        if group.count <= maxBeforeCluster || expandedClusterCandleIndex == candleIndex {
            return group
        } else {
            return []
        }
    }
    
    func toggleClusterExpansion(candleIndex: Int) {
        if expandedClusterCandleIndex == candleIndex {
            expandedClusterCandleIndex = nil
        } else {
            expandedClusterCandleIndex = candleIndex
        }
    }
    
    func clusterInfo(forCandleIndex candleIndex: Int) -> (count: Int, types: Set<MarkerType>)? {
        let group = markersGroupedByCandle()[candleIndex] ?? []
        let maxBeforeCluster = MarkerDisplaySettings.shared.maxBeforeCluster
        guard group.count > maxBeforeCluster && expandedClusterCandleIndex != candleIndex else { return nil }
        return (group.count, Set(group.map { $0.type }))
    }
}

// MARK: - Marker Display Settings

class MarkerDisplaySettings: ObservableObject {
    static let shared = MarkerDisplaySettings()
    
    @Published var baseOffset: CGFloat {
        didSet { UserDefaults.standard.set(baseOffset, forKey: "markerBaseOffset") }
    }
    
    @Published var stackOffset: CGFloat {
        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
    }
    
    @Published var maxBeforeCluster: Int {
        didSet { UserDefaults.standard.set(maxBeforeCluster, forKey: "markerMaxBeforeCluster") }
    }
    
    @Published var proximityTierOffset: CGFloat {
        didSet { UserDefaults.standard.set(proximityTierOffset, forKey: "markerProximityTierOffset") }
    }
    
    @Published var placementExtraOffset: CGFloat {
        didSet { UserDefaults.standard.set(placementExtraOffset, forKey: "markerPlacementExtraOffset") }
    }
    
    private init() {
        // SIGNIFICANTLY INCREASED offsets to prevent overlap
        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 95
        // INCREASED from 40 to 55 to prevent name overlap
        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 55
        self.maxBeforeCluster = UserDefaults.standard.object(forKey: "markerMaxBeforeCluster") as? Int ?? 3
        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 40
        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 45
    }
    
    func resetToDefaults() {
        baseOffset = 95
        stackOffset = 55
        maxBeforeCluster = 3
        proximityTierOffset = 40
        placementExtraOffset = 45
    }
}

// MARK: - Marker Position Calculator

struct MarkerPositionCalculator {
    
    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
    static var baseOffset: CGFloat { settings.baseOffset }
    static var stackOffset: CGFloat { settings.stackOffset }
    static var maxBeforeCluster: Int { settings.maxBeforeCluster }
    static let proximityRange = 4  // Increased from 3
    static let hitRadius: CGFloat = 30  // Increased for better tap detection
    
    static var placementOffset: CGFloat {
        settings.baseOffset + settings.placementExtraOffset
    }
    
    // MARK: - SHARED Position Calculation
    
    /// Calculate the screen position for a marker using its STORED properties
    /// SINGLE SOURCE OF TRUTH - used by both drawing and hit detection
    static func computeMarkerScreenPosition(
        marker: ChartMarker,
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat
    ) -> CGPoint {
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        if marker.positionedBelow {
            baseY = candleLowY + baseOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - baseOffset
            stackDirection = -1.0
        }
        
        let stackOffsetValue = CGFloat(marker.stackIndex) * stackOffset * stackDirection
        let tierOffset = offsetForTier(marker.proximityTier) * stackDirection
        let markerY = baseY + stackOffsetValue + tierOffset
        
        return CGPoint(x: centerX, y: markerY)
    }
    
    /// Calculate PREVIEW position for new marker placement
    /// This determines where the preview marker should snap to
    static func calculatePreviewPosition(
        candleIndex: Int,
        existingMarkers: [ChartMarker],
        candles: [Candle],
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat
    ) -> (position: CGPoint, isBelow: Bool) {
        // Determine if new marker should be above or below
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let shouldBeBelow: Bool
        if markersAtCandle.isEmpty {
            // No existing markers - use peak/valley detection
            shouldBeBelow = shouldPositionBelowUsingPeakValleyDetection(
                candleIndex: candleIndex,
                candles: candles
            )
            
            // Also check nearby marker density
            let nearbyMarkers = existingMarkers.filter {
                abs($0.candleIndex - candleIndex) <= proximityRange
            }
            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
            
            // Override if one side is much more crowded
            if neighborsAbove > neighborsBelow + 2 {
                // Above is crowded, go below
                let baseY = candleLowY + placementOffset
                return (CGPoint(x: centerX, y: baseY), true)
            } else if neighborsBelow > neighborsAbove + 2 {
                // Below is crowded, go above
                let baseY = candleHighY - placementOffset
                return (CGPoint(x: centerX, y: baseY), false)
            }
        } else {
            // Has existing markers - alternate
            let aboveCount = markersAtCandle.filter { !$0.positionedBelow }.count
            let belowCount = markersAtCandle.filter { $0.positionedBelow }.count
            shouldBeBelow = aboveCount > belowCount
        }
        
        // Calculate position
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        if shouldBeBelow {
            baseY = candleLowY + placementOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - placementOffset
            stackDirection = -1.0
        }
        
        let stackOffsetValue = CGFloat(stackIndex) * stackOffset * stackDirection
        let markerY = baseY + stackOffsetValue
        
        return (CGPoint(x: centerX, y: markerY), shouldBeBelow)
    }
    
    // MARK: - Stable Position Assignment
    
    static func assignStablePositions(
        markers: [ChartMarker],
        candles: [Candle]
    ) -> [ChartMarker] {
        var result = markers
        
        let grouped = Dictionary(grouping: result) { $0.candleIndex }
        let sortedIndices = grouped.keys.sorted()
        
        var usedAboveTiers: [Int: Set<Int>] = [:]
        var usedBelowTiers: [Int: Set<Int>] = [:]
        var positionDecisions: [Int: Bool] = [:]
        
        for candleIndex in sortedIndices {
            guard let markersAtCandle = grouped[candleIndex] else { continue }
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            let useSingleMarkerLogic = sorted.count == 1
            
            for (stackIndex, marker) in sorted.enumerated() {
                guard let resultIndex = result.firstIndex(where: { $0.id == marker.id }) else { continue }
                
                let shouldBeBelow: Bool
                
                if useSingleMarkerLogic {
                    let preferBelow = shouldPositionBelowUsingPeakValleyDetection(
                        candleIndex: candleIndex,
                        candles: candles
                    )
                    
                    let leftIsAbove = positionDecisions[candleIndex - 1] == true
                    let rightIsAbove = positionDecisions[candleIndex + 1] == true
                    let leftIsBelow = positionDecisions[candleIndex - 1] == false
                    let rightIsBelow = positionDecisions[candleIndex + 1] == false
                    
                    if leftIsAbove || rightIsAbove {
                        shouldBeBelow = true
                    } else if leftIsBelow || rightIsBelow {
                        shouldBeBelow = false
                    } else {
                        shouldBeBelow = preferBelow
                    }
                    
                    positionDecisions[candleIndex] = !shouldBeBelow
                } else {
                    shouldBeBelow = stackIndex % 2 == 1
                }
                
                let tier: Int
                if shouldBeBelow {
                    tier = calculateProximityTierInternal(
                        candleIndex: candleIndex,
                        usedTiers: &usedBelowTiers
                    )
                } else {
                    tier = calculateProximityTierInternal(
                        candleIndex: candleIndex,
                        usedTiers: &usedAboveTiers
                    )
                }
                
                result[resultIndex].positionedBelow = shouldBeBelow
                result[resultIndex].proximityTier = tier
                result[resultIndex].stackIndex = stackIndex / 2
            }
        }
        
        return result
    }
    
    static func calculatePositionForNewMarker(
        marker: ChartMarker,
        existingMarkers: [ChartMarker],
        candles: [Candle]
    ) -> (isBelow: Bool, tier: Int, stackIndex: Int) {
        let candleIndex = marker.candleIndex
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let shouldBeBelow: Bool
        
        if markersAtCandle.isEmpty {
            // Use peak/valley detection
            shouldBeBelow = shouldPositionBelowUsingPeakValleyDetection(
                candleIndex: candleIndex,
                candles: candles
            )
            
            // Check nearby marker density
            let nearbyMarkers = existingMarkers.filter {
                abs($0.candleIndex - candleIndex) <= proximityRange
            }
            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
            
            if neighborsAbove > neighborsBelow + 2 {
                // Override: above is crowded, go below
                let sameSideNearby = existingMarkers.filter {
                    abs($0.candleIndex - candleIndex) <= proximityRange && $0.positionedBelow
                }
                let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
                var tier = 0
                while usedTiers.contains(tier) { tier += 1 }
                return (isBelow: true, tier: tier, stackIndex: 0)
            } else if neighborsBelow > neighborsAbove + 2 {
                // Override: below is crowded, go above
                let sameSideNearby = existingMarkers.filter {
                    abs($0.candleIndex - candleIndex) <= proximityRange && !$0.positionedBelow
                }
                let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
                var tier = 0
                while usedTiers.contains(tier) { tier += 1 }
                return (isBelow: false, tier: tier, stackIndex: 0)
            }
        } else {
            // Alternate with existing markers
            let aboveCount = markersAtCandle.filter { !$0.positionedBelow }.count
            let belowCount = markersAtCandle.filter { $0.positionedBelow }.count
            shouldBeBelow = aboveCount > belowCount
        }
        
        // Calculate stack index (how many markers on same side of this candle)
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        
        // Find unused tier
        let sameSideNearby = existingMarkers.filter {
            abs($0.candleIndex - candleIndex) <= proximityRange &&
            $0.positionedBelow == shouldBeBelow
        }
        let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
        
        var tier = 0
        while usedTiers.contains(tier) {
            tier += 1
        }
        
        return (isBelow: shouldBeBelow, tier: tier, stackIndex: stackIndex)
    }
    
    // MARK: - Peak/Valley Detection
    
    private static func shouldPositionBelowUsingPeakValleyDetection(
        candleIndex: Int,
        candles: [Candle]
    ) -> Bool {
        guard candleIndex >= 0 && candleIndex < candles.count else { return false }
        
        let windowSize = 5
        let candle = candles[candleIndex]
        
        var lowerHighsCount = 0
        var higherLowsCount = 0
        
        for delta in 1...windowSize {
            if candleIndex - delta >= 0 {
                let leftCandle = candles[candleIndex - delta]
                if leftCandle.high < candle.high { lowerHighsCount += 1 }
                if leftCandle.low > candle.low { higherLowsCount += 1 }
            }
            
            if candleIndex + delta < candles.count {
                let rightCandle = candles[candleIndex + delta]
                if rightCandle.high < candle.high { lowerHighsCount += 1 }
                if rightCandle.low > candle.low { higherLowsCount += 1 }
            }
        }
        
        // At a peak (most neighbors have lower highs) -> position ABOVE (return false)
        // At a valley (most neighbors have higher lows) -> position BELOW (return true)
        let isPeak = lowerHighsCount >= windowSize
        let isValley = higherLowsCount >= windowSize
        
        if isPeak && !isValley {
            return false // Position above at peaks
        } else if isValley && !isPeak {
            return true // Position below at valleys
        } else {
            // Neutral - use simple trend
            if candleIndex > 0 {
                return candle.close < candles[candleIndex - 1].close
            }
            return false
        }
    }
    
    static func calculateProximityTier(
        candleIndex: Int,
        allMarkers: [ChartMarker],
        isBelow: Bool,
        usedTiers: inout [Int: Set<Int>]
    ) -> Int {
        return calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedTiers)
    }
    
    static func offsetForTier(_ tier: Int) -> CGFloat {
        return CGFloat(tier) * settings.proximityTierOffset
    }
    
    private static func calculateProximityTierInternal(
        candleIndex: Int,
        usedTiers: inout [Int: Set<Int>]
    ) -> Int {
        var conflictingTiers: Set<Int> = []
        
        for delta in 1...proximityRange {
            if let leftTiers = usedTiers[candleIndex - delta] {
                conflictingTiers.formUnion(leftTiers)
            }
            if let rightTiers = usedTiers[candleIndex + delta] {
                conflictingTiers.formUnion(rightTiers)
            }
        }
        
        var tier = 0
        while conflictingTiers.contains(tier) {
            tier += 1
        }
        
        if usedTiers[candleIndex] == nil {
            usedTiers[candleIndex] = []
        }
        usedTiers[candleIndex]?.insert(tier)
        
        return tier
    }
}

// MARK: - Chart Marker System (Canvas Drawing)

struct ChartMarkerSystem {
    
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
        tappedMarkerId: UUID? = nil
    ) {
        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        
        for (candleIndex, markersAtCandle) in groupedMarkers {
            guard candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            
            if x < -totalCandleWidth * 2 || x > chartSize.width + totalCandleWidth * 2 {
                continue
            }
            
            let candle = candles[candleIndex]
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let centerX = x + actualCandleWidth / 2
            
            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
            
            if isCluster {
                let typeCounts = Dictionary(grouping: markersAtCandle, by: { $0.type }).mapValues { $0.count }
                let dominantType = typeCounts.max { a, b in
                    if a.value == b.value {
                        return a.key.rawValue > b.key.rawValue
                    }
                    return a.value < b.value
                }?.key
                let primaryColor = dominantType?.color ?? .blue
                
                drawClusterIndicator(
                    context: context,
                    position: CGPoint(x: centerX, y: candleHighY - MarkerPositionCalculator.baseOffset),
                    candleHighPoint: CGPoint(x: centerX, y: candleHighY),
                    count: markersAtCandle.count,
                    primaryColor: primaryColor
                )
            } else {
                let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
                
                var markerPositions: [(marker: ChartMarker, position: CGPoint)] = []
                for marker in sortedMarkers {
                    let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                        marker: marker,
                        candleHighY: candleHighY,
                        candleLowY: candleLowY,
                        centerX: centerX
                    )
                    markerPositions.append((marker, position))
                }
                
                let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
                let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
                
                drawStackedConnectionLines(context: context, markers: aboveMarkers, anchorY: candleHighY, centerX: centerX, isBelow: false)
                drawStackedConnectionLines(context: context, markers: belowMarkers, anchorY: candleLowY, centerX: centerX, isBelow: true)
                
                for (marker, position) in markerPositions {
                    let isAnimated = tappedMarkerId == marker.id
                    let scale: CGFloat = isAnimated ? 1.3 : 1.0
                    
                    drawSingleMarker(
                        context: context,
                        marker: marker,
                        position: position,
                        isBelow: marker.positionedBelow,
                        scale: scale
                    )
                }
            }
        }
    }
    
    private static func drawStackedConnectionLines(
        context: GraphicsContext,
        markers: [(marker: ChartMarker, position: CGPoint)],
        anchorY: CGFloat,
        centerX: CGFloat,
        isBelow: Bool
    ) {
        guard !markers.isEmpty else { return }
        
        let baseRadius: CGFloat = 16
        var previousY = anchorY
        
        for (marker, position) in markers {
            let markerEdgeY: CGFloat = isBelow ? position.y - baseRadius : position.y + baseRadius
            
            let linePath = Path { path in
                path.move(to: CGPoint(x: centerX, y: previousY))
                path.addLine(to: CGPoint(x: centerX, y: markerEdgeY))
            }
            
            context.stroke(
                linePath,
                with: .color(marker.type.color.opacity(0.7)),
                style: StrokeStyle(lineWidth: 2, dash: [4, 3])
            )
            
            previousY = isBelow ? position.y + baseRadius : position.y - baseRadius
        }
    }
    
    private static func drawSingleMarker(
        context: GraphicsContext,
        marker: ChartMarker,
        position: CGPoint,
        isBelow: Bool,
        scale: CGFloat = 1.0
    ) {
        let baseRadius: CGFloat = 16
        let scaledRadius = baseRadius * scale
        
        // Shadow
        let shadowRect = CGRect(
            x: position.x - scaledRadius + 2,
            y: position.y - scaledRadius + 2,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.4)))
        
        // Main circle
        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.9)))
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 3 * scale)
        
        // Inner colored circle
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
        
        // Like badge
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = isBelow ? -(scaledRadius + 4) : (scaledRadius - 12)
            let likeCircleRect = CGRect(
                x: position.x + 9,
                y: position.y + badgeOffset,
                width: 14,
                height: 14
            )
            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
            
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 16, y: position.y + badgeOffset + 7)
            )
        }
        
        // Username label - positioned further to avoid overlap
        let labelY = isBelow ? position.y + scaledRadius + 12 : position.y - scaledRadius - 12
        context.draw(
            Text(marker.username)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.9)),
            at: CGPoint(x: position.x, y: labelY)
        )
    }
    
    private static func drawClusterIndicator(
        context: GraphicsContext,
        position: CGPoint,
        candleHighPoint: CGPoint,
        count: Int,
        primaryColor: Color
    ) {
        let connectionPath = Path { path in
            path.move(to: CGPoint(x: position.x, y: position.y + 22))
            path.addLine(to: candleHighPoint)
        }
        context.stroke(
            connectionPath,
            with: .color(.white.opacity(0.5)),
            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
        )
        
        let clusterRadius: CGFloat = 22
        let circleRect = CGRect(
            x: position.x - clusterRadius,
            y: position.y - clusterRadius,
            width: clusterRadius * 2,
            height: clusterRadius * 2
        )
        
        context.fill(Path(ellipseIn: circleRect), with: .color(primaryColor.opacity(0.9)))
        context.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 2)
        
        context.draw(
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white),
            at: position
        )
    }
    
    // MARK: - Hit Detection
    
    static func findMarkerAtLocation(
        _ location: CGPoint,
        markers: [ChartMarker],
        candles: [Candle],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat,
        expandedClusterIndex: Int? = nil
    ) -> (marker: ChartMarker?, isCluster: Bool, clusterCandleIndex: Int?) {
        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        let hitRadius = MarkerPositionCalculator.hitRadius
        
        let sortedCandleIndices = groupedMarkers.keys.sorted().reversed()
        
        for candleIndex in sortedCandleIndices {
            guard let markersAtCandle = groupedMarkers[candleIndex],
                  candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let candle = candles[candleIndex]
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            let centerX = x + actualCandleWidth / 2
            
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            
            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
            
            if isCluster {
                let clusterY = candleHighY - MarkerPositionCalculator.baseOffset
                let distance = hypot(location.x - centerX, location.y - clusterY)
                if distance <= 28 {
                    return (nil, true, candleIndex)
                }
            } else {
                let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
                
                for marker in sorted.reversed() {
                    let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                        marker: marker,
                        candleHighY: candleHighY,
                        candleLowY: candleLowY,
                        centerX: centerX
                    )
                    
                    let distance = hypot(location.x - position.x, location.y - position.y)
                    if distance <= hitRadius {
                        return (marker, false, nil)
                    }
                }
            }
        }
        
        return (nil, false, nil)
    }
}

// MARK: - Marker Creation Sheet (FIXED - now passes candles)

struct MarkerCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var markerManager: MarkerManager
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let username: String
    let chartData: ChartDataManager
    /// CRITICAL: Must pass candles for proper positioning
    let candles: [Candle]
    
    @State private var selectedType: MarkerType = .entry
    @State private var note: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Marker Type") {
                    ForEach(MarkerType.allCases, id: \.rawValue) { type in
                        Button(action: { selectedType = type }) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                    .frame(width: 30)
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("Details") {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(timestamp.chartTimeLabel)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(chartData.formatPrice(price))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Note (Optional)") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
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
                        // FIXED: Now passes candles for proper positioning calculation
                        markerManager.addMarker(
                            candleIndex: candleIndex,
                            timestamp: timestamp,
                            price: price,
                            type: selectedType,
                            username: username,
                            note: note.isEmpty ? nil : note,
                            candles: candles
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
    
    init(markerManager: MarkerManager, marker: ChartMarker, currentUserId: String) {
        self.markerManager = markerManager
        self.marker = marker
        self.currentUserId = currentUserId
        self.chartData = ChartDataManager()
    }
    
    init(markerManager: MarkerManager, marker: ChartMarker, currentUserId: String, chartData: ChartDataManager) {
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
                            }
                            
                            Spacer()
                            
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}










////
////  ChartMarkerSystem.swift
////  traders_guild
////
////  COMPREHENSIVE FIX v4 - Addresses:
////  1. Hit detection using stored positions (not recalculated)
////  2. Improved connection lines for stacked markers
////  3. Better peak/valley detection for positioning
////  4. Increased minimum distance from candles
////  5. Shared position calculation function (DRY)
////
////  NOTE: ChartMarker and MarkerType are defined in ChartModels.swift
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
//    @Published var expandedClusterCandleIndex: Int? = nil
//    
//    private let currentUserId: String
//    private let currentGuildId: String
//    
//    var guildId: String { currentGuildId }
//    
//    init(userId: String = "user123", guildId: String = "guild1") {
//        self.currentUserId = userId
//        self.currentGuildId = guildId
//    }
//    
//    // MARK: - API Loading
//    
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
//            var positionedMarkers = SampleData.updateMarkerPrices(
//                markers: fetchedMarkers,
//                candles: candles
//            )
//            
//            positionedMarkers = MarkerPositionCalculator.assignStablePositions(
//                markers: positionedMarkers,
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
//        note: String? = nil,
//        candles: [Candle]
//    ) {
//        var marker = ChartMarker(
//            candleIndex: candleIndex,
//            timestamp: timestamp,
//            price: price,
//            type: type,
//            userId: currentUserId,
//            username: username,
//            note: note,
//            guildId: currentGuildId
//        )
//        
//        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
//            marker: marker,
//            existingMarkers: markers,
//            candles: candles
//        )
//        
//        marker.positionedBelow = positioning.isBelow
//        marker.proximityTier = positioning.tier
//        marker.stackIndex = positioning.stackIndex
//        
//        markers.append(marker)
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
//            guildId: currentGuildId,
//            positionedBelow: false,
//            proximityTier: 0,
//            stackIndex: markers.filter { $0.candleIndex == candleIndex }.count
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
//    
//    func markersGroupedByCandle() -> [Int: [ChartMarker]] {
//        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
//    }
//    
//    func isCluster(candleIndex: Int) -> Bool {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        return group.count > MarkerDisplaySettings.shared.maxBeforeCluster && expandedClusterCandleIndex != candleIndex
//    }
//    
//    func displayMarkers(forCandleIndex candleIndex: Int) -> [ChartMarker] {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        let maxBeforeCluster = MarkerDisplaySettings.shared.maxBeforeCluster
//        
//        if group.count <= maxBeforeCluster || expandedClusterCandleIndex == candleIndex {
//            return group
//        } else {
//            return []
//        }
//    }
//    
//    func toggleClusterExpansion(candleIndex: Int) {
//        if expandedClusterCandleIndex == candleIndex {
//            expandedClusterCandleIndex = nil
//        } else {
//            expandedClusterCandleIndex = candleIndex
//        }
//    }
//    
//    func clusterInfo(forCandleIndex candleIndex: Int) -> (count: Int, types: Set<MarkerType>)? {
//        let group = markersGroupedByCandle()[candleIndex] ?? []
//        let maxBeforeCluster = MarkerDisplaySettings.shared.maxBeforeCluster
//        guard group.count > maxBeforeCluster && expandedClusterCandleIndex != candleIndex else { return nil }
//        return (group.count, Set(group.map { $0.type }))
//    }
//}
//
//// MARK: - Marker Display Settings
//
//class MarkerDisplaySettings: ObservableObject {
//    static let shared = MarkerDisplaySettings()
//    
//    @Published var baseOffset: CGFloat {
//        didSet { UserDefaults.standard.set(baseOffset, forKey: "markerBaseOffset") }
//    }
//    
//    @Published var stackOffset: CGFloat {
//        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
//    }
//    
//    @Published var maxBeforeCluster: Int {
//        didSet { UserDefaults.standard.set(maxBeforeCluster, forKey: "markerMaxBeforeCluster") }
//    }
//    
//    @Published var proximityTierOffset: CGFloat {
//        didSet { UserDefaults.standard.set(proximityTierOffset, forKey: "markerProximityTierOffset") }
//    }
//    
//    @Published var placementExtraOffset: CGFloat {
//        didSet { UserDefaults.standard.set(placementExtraOffset, forKey: "markerPlacementExtraOffset") }
//    }
//    
//    private init() {
//        // INCREASED baseOffset from 75 to 90 for better candle clearance
//        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 90
//        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 40
//        self.maxBeforeCluster = UserDefaults.standard.object(forKey: "markerMaxBeforeCluster") as? Int ?? 3
//        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 35
//        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 40
//    }
//    
//    func resetToDefaults() {
//        baseOffset = 90
//        stackOffset = 40
//        maxBeforeCluster = 3
//        proximityTierOffset = 35
//        placementExtraOffset = 40
//    }
//}
//
//// MARK: - Marker Position Calculator
//
//struct MarkerPositionCalculator {
//    
//    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
//    static var baseOffset: CGFloat { settings.baseOffset }
//    static var stackOffset: CGFloat { settings.stackOffset }
//    static var maxBeforeCluster: Int { settings.maxBeforeCluster }
//    static let proximityRange = 3
//    /// INCREASED hit radius for better tap detection
//    static let hitRadius: CGFloat = 28
//    
//    static var placementOffset: CGFloat {
//        settings.baseOffset + settings.placementExtraOffset
//    }
//    
//    // MARK: - SHARED Position Calculation (Used by BOTH drawing AND hit detection)
//    
//    /// Calculate the screen position for a marker using its STORED properties
//    /// This is the SINGLE SOURCE OF TRUTH - ensures drawing and hit detection match
//    static func computeMarkerScreenPosition(
//        marker: ChartMarker,
//        candleHighY: CGFloat,
//        candleLowY: CGFloat,
//        centerX: CGFloat
//    ) -> CGPoint {
//        let baseY: CGFloat
//        let stackDirection: CGFloat
//        
//        if marker.positionedBelow {
//            baseY = candleLowY + baseOffset
//            stackDirection = 1.0
//        } else {
//            baseY = candleHighY - baseOffset
//            stackDirection = -1.0
//        }
//        
//        let stackOffsetValue = CGFloat(marker.stackIndex) * stackOffset * stackDirection
//        let tierOffset = offsetForTier(marker.proximityTier) * stackDirection
//        let markerY = baseY + stackOffsetValue + tierOffset
//        
//        return CGPoint(x: centerX, y: markerY)
//    }
//    
//    // MARK: - Stable Position Assignment
//    
//    static func assignStablePositions(
//        markers: [ChartMarker],
//        candles: [Candle]
//    ) -> [ChartMarker] {
//        var result = markers
//        
//        let grouped = Dictionary(grouping: result) { $0.candleIndex }
//        let sortedIndices = grouped.keys.sorted()
//        
//        var usedAboveTiers: [Int: Set<Int>] = [:]
//        var usedBelowTiers: [Int: Set<Int>] = [:]
//        var positionDecisions: [Int: Bool] = [:]
//        
//        for candleIndex in sortedIndices {
//            guard let markersAtCandle = grouped[candleIndex] else { continue }
//            
//            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//            let useSingleMarkerLogic = sorted.count == 1
//            
//            for (stackIndex, marker) in sorted.enumerated() {
//                guard let resultIndex = result.firstIndex(where: { $0.id == marker.id }) else { continue }
//                
//                let shouldBeBelow: Bool
//                
//                if useSingleMarkerLogic {
//                    // Use IMPROVED peak/valley detection
//                    let preferBelow = shouldPositionBelowUsingPeakValleyDetection(
//                        candleIndex: candleIndex,
//                        candles: candles
//                    )
//                    
//                    let leftIsAbove = positionDecisions[candleIndex - 1] == true
//                    let rightIsAbove = positionDecisions[candleIndex + 1] == true
//                    let leftIsBelow = positionDecisions[candleIndex - 1] == false
//                    let rightIsBelow = positionDecisions[candleIndex + 1] == false
//                    
//                    if leftIsAbove || rightIsAbove {
//                        shouldBeBelow = true
//                    } else if leftIsBelow || rightIsBelow {
//                        shouldBeBelow = false
//                    } else {
//                        shouldBeBelow = preferBelow
//                    }
//                    
//                    positionDecisions[candleIndex] = !shouldBeBelow
//                } else {
//                    shouldBeBelow = stackIndex % 2 == 1
//                }
//                
//                let tier: Int
//                if shouldBeBelow {
//                    tier = calculateProximityTierInternal(
//                        candleIndex: candleIndex,
//                        usedTiers: &usedBelowTiers
//                    )
//                } else {
//                    tier = calculateProximityTierInternal(
//                        candleIndex: candleIndex,
//                        usedTiers: &usedAboveTiers
//                    )
//                }
//                
//                result[resultIndex].positionedBelow = shouldBeBelow
//                result[resultIndex].proximityTier = tier
//                result[resultIndex].stackIndex = stackIndex / 2
//            }
//        }
//        
//        return result
//    }
//    
//    static func calculatePositionForNewMarker(
//        marker: ChartMarker,
//        existingMarkers: [ChartMarker],
//        candles: [Candle]
//    ) -> (isBelow: Bool, tier: Int, stackIndex: Int) {
//        let candleIndex = marker.candleIndex
//        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
//        let stackIndex = markersAtCandle.count
//        
//        let shouldBeBelow: Bool
//        
//        if markersAtCandle.isEmpty {
//            shouldBeBelow = shouldPositionBelowUsingPeakValleyDetection(
//                candleIndex: candleIndex,
//                candles: candles
//            )
//            
//            let nearbyMarkers = existingMarkers.filter {
//                abs($0.candleIndex - candleIndex) <= proximityRange
//            }
//            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
//            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
//            
//            if neighborsAbove > neighborsBelow + 2 {
//                return (isBelow: true, tier: 0, stackIndex: 0)
//            } else if neighborsBelow > neighborsAbove + 2 {
//                return (isBelow: false, tier: 0, stackIndex: 0)
//            }
//        } else {
//            shouldBeBelow = stackIndex % 2 == 1
//        }
//        
//        let sameSideNearby = existingMarkers.filter {
//            abs($0.candleIndex - candleIndex) <= proximityRange &&
//            $0.positionedBelow == shouldBeBelow
//        }
//        let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
//        
//        var tier = 0
//        while usedTiers.contains(tier) {
//            tier += 1
//        }
//        
//        return (isBelow: shouldBeBelow, tier: tier, stackIndex: stackIndex / 2)
//    }
//    
//    // MARK: - IMPROVED Peak/Valley Detection
//    
//    private static func shouldPositionBelowUsingPeakValleyDetection(
//        candleIndex: Int,
//        candles: [Candle]
//    ) -> Bool {
//        guard candleIndex >= 0 && candleIndex < candles.count else { return false }
//        
//        let windowSize = 5
//        let candle = candles[candleIndex]
//        
//        var lowerHighsCount = 0
//        var higherLowsCount = 0
//        
//        for delta in 1...windowSize {
//            if candleIndex - delta >= 0 {
//                let leftCandle = candles[candleIndex - delta]
//                if leftCandle.high < candle.high { lowerHighsCount += 1 }
//                if leftCandle.low > candle.low { higherLowsCount += 1 }
//            }
//            
//            if candleIndex + delta < candles.count {
//                let rightCandle = candles[candleIndex + delta]
//                if rightCandle.high < candle.high { lowerHighsCount += 1 }
//                if rightCandle.low > candle.low { higherLowsCount += 1 }
//            }
//        }
//        
//        let isPeak = lowerHighsCount >= windowSize * 2 - 2
//        let isValley = higherLowsCount >= windowSize * 2 - 2
//        
//        if isPeak {
//            return false // Position above at peaks
//        } else if isValley {
//            return true // Position below at valleys
//        } else {
//            if candleIndex > 0 {
//                return candle.high < candles[candleIndex - 1].high
//            }
//            return false
//        }
//    }
//    
//    static func calculateProximityTier(
//        candleIndex: Int,
//        allMarkers: [ChartMarker],
//        isBelow: Bool,
//        usedTiers: inout [Int: Set<Int>]
//    ) -> Int {
//        return calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedTiers)
//    }
//    
//    static func offsetForTier(_ tier: Int) -> CGFloat {
//        return CGFloat(tier) * settings.proximityTierOffset
//    }
//    
//    private static func calculateProximityTierInternal(
//        candleIndex: Int,
//        usedTiers: inout [Int: Set<Int>]
//    ) -> Int {
//        var conflictingTiers: Set<Int> = []
//        
//        for delta in 1...proximityRange {
//            if let leftTiers = usedTiers[candleIndex - delta] {
//                conflictingTiers.formUnion(leftTiers)
//            }
//            if let rightTiers = usedTiers[candleIndex + delta] {
//                conflictingTiers.formUnion(rightTiers)
//            }
//        }
//        
//        var tier = 0
//        while conflictingTiers.contains(tier) {
//            tier += 1
//        }
//        
//        if usedTiers[candleIndex] == nil {
//            usedTiers[candleIndex] = []
//        }
//        usedTiers[candleIndex]?.insert(tier)
//        
//        return tier
//    }
//}
//
//// MARK: - Chart Marker System (Canvas Drawing)
//
//struct ChartMarkerSystem {
//    
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
//        markerManager: MarkerManager? = nil,
//        tappedMarkerId: UUID? = nil
//    ) {
//        let scaledHeight = chartSize.height * priceScale
//        let allVisibleMarkers = markers.filter { $0.isVisible }
//        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
//        
//        for (candleIndex, markersAtCandle) in groupedMarkers {
//            guard candleIndex >= 0 && candleIndex < candles.count else { continue }
//            
//            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
//            
//            if x < -totalCandleWidth * 2 || x > chartSize.width + totalCandleWidth * 2 {
//                continue
//            }
//            
//            let candle = candles[candleIndex]
//            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            let centerX = x + actualCandleWidth / 2
//            
//            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
//            
//            if isCluster {
//                let typeCounts = Dictionary(grouping: markersAtCandle, by: { $0.type }).mapValues { $0.count }
//                let dominantType = typeCounts.max { a, b in
//                    if a.value == b.value {
//                        return a.key.rawValue > b.key.rawValue
//                    }
//                    return a.value < b.value
//                }?.key
//                let primaryColor = dominantType?.color ?? .blue
//                
//                drawClusterIndicator(
//                    context: context,
//                    position: CGPoint(x: centerX, y: candleHighY - MarkerPositionCalculator.baseOffset),
//                    candleHighPoint: CGPoint(x: centerX, y: candleHighY),
//                    count: markersAtCandle.count,
//                    primaryColor: primaryColor
//                )
//            } else {
//                let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//                
//                // Calculate positions using SHARED function
//                var markerPositions: [(marker: ChartMarker, position: CGPoint)] = []
//                for marker in sortedMarkers {
//                    let position = MarkerPositionCalculator.computeMarkerScreenPosition(
//                        marker: marker,
//                        candleHighY: candleHighY,
//                        candleLowY: candleLowY,
//                        centerX: centerX
//                    )
//                    markerPositions.append((marker, position))
//                }
//                
//                // Separate by side for proper connection line drawing
//                let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
//                let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
//                
//                // Draw SEGMENTED connection lines
//                drawStackedConnectionLines(
//                    context: context,
//                    markers: aboveMarkers,
//                    anchorY: candleHighY,
//                    centerX: centerX,
//                    isBelow: false
//                )
//                
//                drawStackedConnectionLines(
//                    context: context,
//                    markers: belowMarkers,
//                    anchorY: candleLowY,
//                    centerX: centerX,
//                    isBelow: true
//                )
//                
//                // Draw marker bodies (on top of lines)
//                for (marker, position) in markerPositions {
//                    let isAnimated = tappedMarkerId == marker.id
//                    let scale: CGFloat = isAnimated ? 1.3 : 1.0
//                    
//                    drawSingleMarker(
//                        context: context,
//                        marker: marker,
//                        position: position,
//                        anchorPoint: CGPoint(x: centerX, y: marker.positionedBelow ? candleLowY : candleHighY),
//                        isBelow: marker.positionedBelow,
//                        scale: scale
//                    )
//                }
//            }
//        }
//    }
//    
//    /// Draw connected lines for stacked markers - lines stop at each marker edge
//    private static func drawStackedConnectionLines(
//        context: GraphicsContext,
//        markers: [(marker: ChartMarker, position: CGPoint)],
//        anchorY: CGFloat,
//        centerX: CGFloat,
//        isBelow: Bool
//    ) {
//        guard !markers.isEmpty else { return }
//        
//        let baseRadius: CGFloat = 16
//        var previousY = anchorY
//        
//        for (marker, position) in markers {
//            let markerEdgeY: CGFloat
//            if isBelow {
//                markerEdgeY = position.y - baseRadius
//            } else {
//                markerEdgeY = position.y + baseRadius
//            }
//            
//            let linePath = Path { path in
//                path.move(to: CGPoint(x: centerX, y: previousY))
//                path.addLine(to: CGPoint(x: centerX, y: markerEdgeY))
//            }
//            
//            context.stroke(
//                linePath,
//                with: .color(marker.type.color.opacity(0.7)),
//                style: StrokeStyle(lineWidth: 2, dash: [4, 3])
//            )
//            
//            if isBelow {
//                previousY = position.y + baseRadius
//            } else {
//                previousY = position.y - baseRadius
//            }
//        }
//    }
//    
//    private static func drawSingleMarker(
//        context: GraphicsContext,
//        marker: ChartMarker,
//        position: CGPoint,
//        anchorPoint: CGPoint,
//        isBelow: Bool,
//        scale: CGFloat = 1.0
//    ) {
//        let baseRadius: CGFloat = 16
//        let scaledRadius = baseRadius * scale
//        
//        // Shadow
//        let shadowRect = CGRect(
//            x: position.x - scaledRadius + 2,
//            y: position.y - scaledRadius + 2,
//            width: scaledRadius * 2,
//            height: scaledRadius * 2
//        )
//        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.3)))
//        
//        // Main circle
//        let circleRect = CGRect(
//            x: position.x - scaledRadius,
//            y: position.y - scaledRadius,
//            width: scaledRadius * 2,
//            height: scaledRadius * 2
//        )
//        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.9)))
//        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: 3 * scale)
//        
//        // Icon
//        let iconRadius: CGFloat = 10 * scale
//        let iconCircle = CGRect(
//            x: position.x - iconRadius,
//            y: position.y - iconRadius,
//            width: iconRadius * 2,
//            height: iconRadius * 2
//        )
//        context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color))
//        
//        context.draw(
//            Text(String(marker.type.rawValue.prefix(1)))
//                .font(.system(size: 12 * scale, weight: .bold))
//                .foregroundColor(.white),
//            at: position
//        )
//        
//        // Like badge
//        if marker.likeCount > 0 {
//            let badgeOffset: CGFloat = isBelow ? -(scaledRadius + 3) : (scaledRadius - 13)
//            let likeCircleRect = CGRect(
//                x: position.x + 8,
//                y: position.y + badgeOffset,
//                width: 14,
//                height: 14
//            )
//            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
//            
//            context.draw(
//                Text("\(marker.likeCount)")
//                    .font(.system(size: 9, weight: .bold))
//                    .foregroundColor(.white),
//                at: CGPoint(x: position.x + 15, y: position.y + badgeOffset + 6)
//            )
//        }
//        
//        // Username label
//        let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
//        context.draw(
//            Text(marker.username)
//                .font(.system(size: 9, weight: .medium))
//                .foregroundColor(.white.opacity(0.85)),
//            at: CGPoint(x: position.x, y: labelY)
//        )
//    }
//    
//    private static func drawClusterIndicator(
//        context: GraphicsContext,
//        position: CGPoint,
//        candleHighPoint: CGPoint,
//        count: Int,
//        primaryColor: Color
//    ) {
//        let connectionPath = Path { path in
//            path.move(to: CGPoint(x: position.x, y: position.y + 22))
//            path.addLine(to: candleHighPoint)
//        }
//        context.stroke(
//            connectionPath,
//            with: .color(.white.opacity(0.5)),
//            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
//        )
//        
//        let clusterRadius: CGFloat = 22
//        let circleRect = CGRect(
//            x: position.x - clusterRadius,
//            y: position.y - clusterRadius,
//            width: clusterRadius * 2,
//            height: clusterRadius * 2
//        )
//        
//        context.fill(Path(ellipseIn: circleRect), with: .color(primaryColor.opacity(0.9)))
//        context.stroke(Path(ellipseIn: circleRect), with: .color(.white), lineWidth: 2)
//        
//        context.draw(
//            Text("\(count)")
//                .font(.system(size: 14, weight: .bold))
//                .foregroundColor(.white),
//            at: position
//        )
//    }
//    
//    // MARK: - Hit Detection (Uses SAME position calculation as drawing)
//    
//    static func findMarkerAtLocation(
//        _ location: CGPoint,
//        markers: [ChartMarker],
//        candles: [Candle],
//        chartSize: CGSize,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat,
//        expandedClusterIndex: Int? = nil
//    ) -> (marker: ChartMarker?, isCluster: Bool, clusterCandleIndex: Int?) {
//        let scaledHeight = chartSize.height * priceScale
//        let allVisibleMarkers = markers.filter { $0.isVisible }
//        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
//        let hitRadius = MarkerPositionCalculator.hitRadius
//        
//        let sortedCandleIndices = groupedMarkers.keys.sorted().reversed()
//        
//        for candleIndex in sortedCandleIndices {
//            guard let markersAtCandle = groupedMarkers[candleIndex],
//                  candleIndex >= 0 && candleIndex < candles.count else { continue }
//            
//            let candle = candles[candleIndex]
//            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
//            let centerX = x + actualCandleWidth / 2
//            
//            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//            
//            let isCluster = markersAtCandle.count > MarkerPositionCalculator.maxBeforeCluster && expandedClusterIndex != candleIndex
//            
//            if isCluster {
//                let clusterY = candleHighY - MarkerPositionCalculator.baseOffset
//                let distance = hypot(location.x - centerX, location.y - clusterY)
//                if distance <= 25 {
//                    return (nil, true, candleIndex)
//                }
//            } else {
//                let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//                
//                for marker in sorted.reversed() {
//                    // Use SHARED position calculation - ensures hit matches draw
//                    let position = MarkerPositionCalculator.computeMarkerScreenPosition(
//                        marker: marker,
//                        candleHighY: candleHighY,
//                        candleLowY: candleLowY,
//                        centerX: centerX
//                    )
//                    
//                    let distance = hypot(location.x - position.x, location.y - position.y)
//                    if distance <= hitRadius {
//                        return (marker, false, nil)
//                    }
//                }
//            }
//        }
//        
//        return (nil, false, nil)
//    }
//}
//
//// MARK: - Sheet Views (Unchanged)
//
//struct MarkerCreationSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let username: String
//    let chartData: ChartDataManager
//    
//    @State private var selectedType: MarkerType = .entry
//    @State private var note: String = ""
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Marker Type") {
//                    ForEach(MarkerType.allCases, id: \.rawValue) { type in
//                        Button(action: { selectedType = type }) {
//                            HStack {
//                                Image(systemName: type.icon)
//                                    .foregroundColor(type.color)
//                                    .frame(width: 30)
//                                Text(type.rawValue)
//                                    .foregroundColor(.primary)
//                                Spacer()
//                                if selectedType == type {
//                                    Image(systemName: "checkmark")
//                                        .foregroundColor(.blue)
//                                }
//                            }
//                        }
//                    }
//                }
//                
//                Section("Details") {
//                    HStack {
//                        Text("Time")
//                        Spacer()
//                        Text(timestamp.chartTimeLabel)
//                            .foregroundColor(.secondary)
//                    }
//                    HStack {
//                        Text("Price")
//                        Spacer()
//                        Text(chartData.formatPrice(price))
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                Section("Note (Optional)") {
//                    TextEditor(text: $note)
//                        .frame(minHeight: 80)
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
//        .presentationDetents([.medium, .large])
//        .presentationDragIndicator(.visible)
//        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
//    }
//}
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
//    init(markerManager: MarkerManager, marker: ChartMarker, currentUserId: String) {
//        self.markerManager = markerManager
//        self.marker = marker
//        self.currentUserId = currentUserId
//        self.chartData = ChartDataManager()
//    }
//    
//    init(markerManager: MarkerManager, marker: ChartMarker, currentUserId: String, chartData: ChartDataManager) {
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
//        .presentationDetents([.medium, .large])
//        .presentationDragIndicator(.visible)
//        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
//        .onAppear {
//            editedNote = marker.note ?? ""
//        }
//    }
//}
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
//                            }
//                            
//                            Spacer()
//                            
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
//        .presentationDetents([.medium])
//        .presentationDragIndicator(.visible)
//        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
//    }
//}








