//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  COMPREHENSIVE UPDATE v6 - Major refactor:
//  1. Markers favor top placement (only below for severe troughs)
//  2. Tighter stacking with reduced spacing
//  3. Remove clustering - show all markers individually
//  4. One type per candle restriction (offer like instead)
//  5. Display SF Symbol icons instead of first letter
//  6. Selected marker scales up and shows custom views (lines)
//  7. Hide usernames when multiple markers on same candle
//  8. Horizontal lines for Entry/Exit/Support/Resistance markers
//

import SwiftUI

// MARK: - Marker Manager

class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarker] = []
    @Published var selectedMarker: ChartMarker?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    
    /// Tracks if we should show a "like existing marker" prompt
    @Published var duplicateMarkerToLike: ChartMarker?
    @Published var showDuplicateAlert: Bool = false
    
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
            
            // ISSUE #2 FIX: Complete reset of positioning fields to force proper recalculation
            // Historical markers might have stale positioning data that causes overlaps
            // We need to clear ALL positioning data, not just the main fields
            for i in 0..<positionedMarkers.count {
                positionedMarkers[i].positionedBelow = false
                positionedMarkers[i].proximityTier = 0
                positionedMarkers[i].stackIndex = 0
                // Clear any cached visual properties that might affect rendering
                positionedMarkers[i].isVisible = true
            }
            
            // Force a stable sort by creation date before recalculating positions
            // This ensures consistent stacking order
            positionedMarkers.sort { $0.createdAt < $1.createdAt }
            
            // Now calculate proper positions with fresh state
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
        selectedMarker = nil
    }
    
    // MARK: - Duplicate Type Check
    
    /// Check if a marker of the same type already exists on this candle
    /// Returns the existing marker if found
    func existingMarkerOfType(_ type: MarkerType, atCandleIndex candleIndex: Int) -> ChartMarker? {
        return markers.first { marker in
            marker.candleIndex == candleIndex && marker.type == type
        }
    }
    
    /// Check if adding a marker is allowed (no duplicate types on same candle)
    func canAddMarker(type: MarkerType, atCandleIndex candleIndex: Int) -> Bool {
        return existingMarkerOfType(type, atCandleIndex: candleIndex) == nil
    }
    
    // MARK: - Marker CRUD
    
    /// Add a new marker with proper positioning calculation
    /// Returns true if added successfully, false if duplicate type exists
    @discardableResult
    func addMarker(
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        username: String,
        note: String? = nil,
        candles: [Candle],
        horizontalLinePrice: Double? = nil,
        targetPrice: Double? = nil,
        alertSeverity: MarkerAlertSeverity? = nil,
        trendlineDirection: TrendlineDirection? = nil,
        selectedIndicator: String? = nil,
        chartPattern: ChartPattern? = nil,
        selectedEmoji: String? = nil,
        pollQuestion: String? = nil,
        pollOptions: [PollOption]? = nil
    ) -> Bool {
        print("🔧 === MARKER MANAGER - ADD MARKER ===")
        print("🔧 Type: \(type)")
        print("🔧 Candle Index: \(candleIndex)")
        print("🔧 Price: \(price)")
        print("🔧 Target Price: \(String(describing: targetPrice))")
        print("🔧 Horizontal Line Price: \(String(describing: horizontalLinePrice))")
        print("🔧 Candles count: \(candles.count)")
        
        // Validate candle index
        guard candleIndex >= 0 && candleIndex < candles.count else {
            print("🔧 ❌ ERROR: Invalid candle index \(candleIndex) (candles: \(candles.count))")
            return false
        }
        
        // Check for duplicate type on same candle
        if let existingMarker = existingMarkerOfType(type, atCandleIndex: candleIndex) {
            print("🔧 ⚠️ Duplicate marker detected: \(existingMarker.id)")
            print("🔧 Showing duplicate alert...")
            duplicateMarkerToLike = existingMarker
            showDuplicateAlert = true
            return false
        }
        
        print("🔧 ✓ No duplicate found")
        
        // Calculate line price based on marker type
        var linePrice = horizontalLinePrice
        if type.hasHorizontalLine && linePrice == nil && candleIndex >= 0 && candleIndex < candles.count {
            let candle = candles[candleIndex]
            print("🔧 Calculating line price from candle:")
            print("🔧 Candle: O:\(candle.open) H:\(candle.high) L:\(candle.low) C:\(candle.close)")
            print("🔧 Line source: \(type.lineSource)")
            
            // FIXED: For prediction markers, always use candle close as entry price
            // The target price is stored separately in the targetPrice field
            if type == .predictionTarget {
                linePrice = candle.close  // Entry price is always the candle close
                print("🔧 Prediction marker - using candle close as entry price: \(linePrice ?? 0)")
            } else {
                switch type.lineSource {
                case .candleOpen:
                    linePrice = candle.open
                case .candleClose:
                    linePrice = candle.close
                case .candleHigh:
                    linePrice = candle.high
                case .candleLow:
                    linePrice = candle.low
                case .custom:
                    linePrice = targetPrice
                case .none:
                    break
                }
            }
            
            print("🔧 Calculated line price: \(String(describing: linePrice))")
        }
        
        print("🔧 Creating ChartMarker...")
        var marker = ChartMarker(
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            userId: currentUserId,
            username: username,
            note: note,
            guildId: currentGuildId,
            horizontalLinePrice: linePrice,
            targetPrice: targetPrice,
            alertSeverity: alertSeverity,
            trendlineDirection: trendlineDirection,
            selectedIndicator: selectedIndicator,
            chartPattern: chartPattern,
            selectedEmoji: selectedEmoji,
            pollQuestion: pollQuestion,
            pollOptions: pollOptions
        )
        
        print("🔧 ✓ Marker created: \(marker.id)")
        print("🔧 Marker has target: \(marker.targetPrice != nil)")
        print("🔧 Marker has line: \(marker.horizontalLinePrice != nil)")
        
        // Calculate proper position
        print("🔧 Calculating position...")
        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        
        print("🔧 Position: below=\(positioning.isBelow) tier=\(positioning.tier) stack=\(positioning.stackIndex)")
        
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        
        markers.append(marker)
        print("🔧 ✅ Marker appended to array. Total markers: \(markers.count)")
        return true
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
    
    func addComment(markerId: UUID, text: String, username: String) {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        let comment = MarkerComment(userId: currentUserId, username: username, text: text)
        markers[index].comments.append(comment)
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
    
    /// Get count of markers at a specific candle
    func markerCount(atCandleIndex candleIndex: Int) -> Int {
        markersGroupedByCandle()[candleIndex]?.count ?? 0
    }
    
    /// Check if we should hide usernames (more than 1 marker on candle)
    func shouldHideUsername(forCandleIndex candleIndex: Int) -> Bool {
        markerCount(atCandleIndex: candleIndex) > 1
    }
}

// MARK: - Marker Display Settings

class MarkerDisplaySettings: ObservableObject {
    static let shared = MarkerDisplaySettings()
    
    @Published var baseOffset: CGFloat {
        didSet { UserDefaults.standard.set(baseOffset, forKey: "markerBaseOffset") }
    }
    
    /// REDUCED stack offset for tighter stacking
    @Published var stackOffset: CGFloat {
        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
    }
    
    @Published var proximityTierOffset: CGFloat {
        didSet { UserDefaults.standard.set(proximityTierOffset, forKey: "markerProximityTierOffset") }
    }
    
    @Published var placementExtraOffset: CGFloat {
        didSet { UserDefaults.standard.set(placementExtraOffset, forKey: "markerPlacementExtraOffset") }
    }
    
    private init() {
        // Adjusted offsets for new stacking behavior
        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 70
        // REDUCED from 28 to 20 for tighter stacking (Issue #1 fix)
        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 20
        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 25
        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 40
    }
    
    func resetToDefaults() {
        baseOffset = 70
        stackOffset = 20
        proximityTierOffset = 25
        placementExtraOffset = 40
    }
}

// MARK: - Marker Position Calculator

struct MarkerPositionCalculator {
    
    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
    static var baseOffset: CGFloat { settings.baseOffset }
    static var stackOffset: CGFloat { settings.stackOffset }
    static let proximityRange = 3
    static let hitRadius: CGFloat = 28
    
    static var placementOffset: CGFloat {
        settings.baseOffset + settings.placementExtraOffset
    }
    
    // MARK: - SHARED Position Calculation
    
    /// Calculate the screen position for a marker using its STORED properties
    /// FIXED: Now accepts priceScale to scale marker distance when vertically zooming
    static func computeMarkerScreenPosition(
        marker: ChartMarker,
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0  // NEW: Scale marker distance with vertical zoom
    ) -> CGPoint {
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        // FIXED: Apply dampening to priceScale to make scaling less extreme
        // Dampening factor of 0.5 means markers scale at 50% of the rate of candles
        // Examples: 2x zoom → 1.5x marker distance, 3x zoom → 2x marker distance
        let dampenedScale = dampenPriceScale(priceScale, dampening: 0.75)
        
        let scaledBaseOffset = baseOffset * dampenedScale
        let scaledStackOffset = stackOffset * dampenedScale
        let scaledTierOffset = offsetForTier(marker.proximityTier) * dampenedScale
        
        if marker.positionedBelow {
            baseY = candleLowY + scaledBaseOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - scaledBaseOffset
            stackDirection = -1.0
        }
        
        let stackOffsetValue = CGFloat(marker.stackIndex) * scaledStackOffset * stackDirection
        let tierOffset = scaledTierOffset * stackDirection
        let markerY = baseY + stackOffsetValue + tierOffset
        
        return CGPoint(x: centerX, y: markerY)
    }
    
    /// Apply dampening to price scale to make marker scaling less extreme
    /// - Parameters:
    ///   - priceScale: The raw vertical zoom scale (1.0 = normal, 2.0 = 2x zoom, etc.)
    ///   - dampening: How much to dampen (0.0 = no scaling, 1.0 = full scaling)
    /// - Returns: Dampened scale factor
    private static func dampenPriceScale(_ priceScale: CGFloat, dampening: CGFloat) -> CGFloat {
        // Use interpolation between 1.0 (no scale) and priceScale (full scale)
        // dampening = 0.5 means halfway between no scaling and full scaling
        return 1.0 + (priceScale - 1.0) * dampening
    }
    
    /// Calculate PREVIEW position for new marker placement
    /// UPDATED: Now favors top placement by default
    /// FIXED: Now accepts priceScale to scale preview marker distance
    static func calculatePreviewPosition(
        candleIndex: Int,
        existingMarkers: [ChartMarker],
        candles: [Candle],
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0  // NEW: Scale preview marker distance
    ) -> (position: CGPoint, isBelow: Bool) {
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        // FIXED: Apply dampening to priceScale for preview marker too
        let dampenedScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledPlacementOffset = placementOffset * dampenedScale
        let scaledStackOffset = stackOffset * dampenedScale
        
        // NEW LOGIC: Default to ABOVE (false = not below)
        // Only go below if:
        // 1. There are already markers above and we need to alternate
        // 2. It's a severe peak (lower candles on both sides)
        
        let shouldBeBelow: Bool
        
        if markersAtCandle.isEmpty {
            // No existing markers - check for severe peak first, otherwise default to above
            let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
            let isSevereTrough = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: false)
            
            if isSeverePeak && !isSevereTrough {
                // Severe peak - place below
                shouldBeBelow = true
            } else {
                // Default to above (including severe troughs and neutral cases)
                shouldBeBelow = false
            }
            
            // Check nearby marker density and adjust if needed
            let nearbyMarkers = existingMarkers.filter {
                abs($0.candleIndex - candleIndex) <= proximityRange
            }
            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
            
            // If above is very crowded, consider below
            if neighborsAbove > neighborsBelow + 3 && !isSevereTrough {
                let baseY = candleLowY + scaledPlacementOffset
                return (CGPoint(x: centerX, y: baseY), true)
            }
        } else {
            // FIXED: Has existing markers - place on SAME side as existing ones
            // This ensures all markers stack together instead of alternating
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false // Fallback - should never reach here
            }
        }
        
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        if shouldBeBelow {
            baseY = candleLowY + scaledPlacementOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - scaledPlacementOffset
            stackDirection = -1.0
        }
        
        let stackOffsetValue = CGFloat(stackIndex) * scaledStackOffset * stackDirection
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
        
        for candleIndex in sortedIndices {
            guard let markersAtCandle = grouped[candleIndex] else { continue }
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            // Track markers placed above and below for this candle
            var aboveStackIndex = 0
            var belowStackIndex = 0
            
            for marker in sorted {
                guard let resultIndex = result.firstIndex(where: { $0.id == marker.id }) else { continue }
                
                // NEW: Favor above placement
                // First marker always goes above unless severe peak
                // Subsequent markers alternate
                let shouldBeBelow: Bool
                
                // FIXED: All markers on same candle should be on the same side
                // First marker determines side, all others follow
                if sorted.count == 1 {
                    // Single marker - check for severe peak
                    let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
                    shouldBeBelow = isSeverePeak
                } else {
                    // Multiple markers - ALL go on same side
                    // First marker (aboveStackIndex == 0 && belowStackIndex == 0) determines side
                    if aboveStackIndex == 0 && belowStackIndex == 0 {
                        let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
                        shouldBeBelow = isSeverePeak
                    } else if aboveStackIndex > 0 {
                        // We already have markers above, keep stacking above
                        shouldBeBelow = false
                    } else {
                        // We already have markers below, keep stacking below
                        shouldBeBelow = true
                    }
                }
                
                let stackIndex: Int
                if shouldBeBelow {
                    stackIndex = belowStackIndex
                    belowStackIndex += 1
                } else {
                    stackIndex = aboveStackIndex
                    aboveStackIndex += 1
                }
                
                let tier: Int
                if shouldBeBelow {
                    tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedBelowTiers)
                } else {
                    tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedAboveTiers)
                }
                
                result[resultIndex].positionedBelow = shouldBeBelow
                result[resultIndex].proximityTier = tier
                result[resultIndex].stackIndex = stackIndex
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
            // NEW: Default to above unless severe peak
            let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
            shouldBeBelow = isSeverePeak
            
            // Check nearby marker density
            let nearbyMarkers = existingMarkers.filter {
                abs($0.candleIndex - candleIndex) <= proximityRange
            }
            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
            
            if neighborsAbove > neighborsBelow + 3 {
                // Above is crowded, go below
                let sameSideNearby = existingMarkers.filter {
                    abs($0.candleIndex - candleIndex) <= proximityRange && $0.positionedBelow
                }
                let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
                var tier = 0
                while usedTiers.contains(tier) { tier += 1 }
                return (isBelow: true, tier: tier, stackIndex: 0)
            }
        } else {
            // FIXED: Has existing markers - place on SAME side as existing ones
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        }
        
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        
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
    
    // MARK: - Severe Peak/Trough Detection
    
    /// Check if a candle is a severe peak (for placing below) or severe trough (for placing above)
    /// A severe peak/trough requires BOTH neighbors to be lower/higher
    private static func isSeverePeakOrTrough(
        candleIndex: Int,
        candles: [Candle],
        checkPeak: Bool
    ) -> Bool {
        guard candleIndex > 0 && candleIndex < candles.count - 1 else { return false }
        
        let candle = candles[candleIndex]
        let leftCandle = candles[candleIndex - 1]
        let rightCandle = candles[candleIndex + 1]
        
        if checkPeak {
            // Severe peak: candle high is above BOTH neighbors' highs
            return candle.high > leftCandle.high && candle.high > rightCandle.high
        } else {
            // Severe trough: candle low is below BOTH neighbors' lows
            return candle.low < leftCandle.low && candle.low < rightCandle.low
        }
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
        markerManager: MarkerManager? = nil,
        selectedMarkerId: UUID? = nil,
        chartData: ChartDataManager? = nil
    ) {
        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        
        // HORIZONTAL LINES REMOVED FROM CANVAS
        // Now drawn in MarkerPriceLinesOverlay (SwiftUI layer on top of y-axis)
        // This ensures price labels appear above the y-axis overlay
        
        /*
        // Draw horizontal lines for selected marker first (behind markers)
        if let selectedId = selectedMarkerId,
           let selectedMarker = markers.first(where: { $0.id == selectedId }),
           selectedMarker.type.hasHorizontalLine,
           selectedMarker.candleIndex >= 0 && selectedMarker.candleIndex < candles.count {
            let candle = candles[selectedMarker.candleIndex]
            if let linePrice = selectedMarker.getLinePrice(candle: candle) {
                drawHorizontalLine(
                    context: context,
                    price: linePrice,
                    chartSize: chartSize,
                    priceRange: priceRange,
                    priceScale: priceScale,
                    verticalOffset: verticalOffset,
                    color: selectedMarker.type.color,
                    markerX: CGFloat(selectedMarker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2,
                    chartData: chartData
                )
            }
            
            // Draw target price line for prediction markers
            if selectedMarker.type == .predictionTarget, let targetPrice = selectedMarker.targetPrice {
                drawHorizontalLine(
                    context: context,
                    price: targetPrice,
                    chartSize: chartSize,
                    priceRange: priceRange,
                    priceScale: priceScale,
                    verticalOffset: verticalOffset,
                    color: .red.opacity(0.8),
                    markerX: CGFloat(selectedMarker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2,
                    isDashed: true,
                    chartData: chartData
                )
            }
        }
        */
        
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
            
            // No clustering - show all markers
            let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            let hideUsernames = markersAtCandle.count > 1
            
            var markerPositions: [(marker: ChartMarker, position: CGPoint)] = []
            for marker in sortedMarkers {
                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: marker,
                    candleHighY: candleHighY,
                    candleLowY: candleLowY,
                    centerX: centerX,
                    priceScale: priceScale  // FIXED: Pass priceScale for vertical zoom scaling
                )
                markerPositions.append((marker, position))
            }
            
            let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
            let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
            
            drawStackedConnectionLines(context: context, markers: aboveMarkers, anchorY: candleHighY, centerX: centerX, isBelow: false)
            drawStackedConnectionLines(context: context, markers: belowMarkers, anchorY: candleLowY, centerX: centerX, isBelow: true)
            
            for (marker, position) in markerPositions {
                let isSelected = selectedMarkerId == marker.id
                let scale: CGFloat = isSelected ? 1.3 : 1.0
                
                drawSingleMarker(
                    context: context,
                    marker: marker,
                    position: position,
                    isBelow: marker.positionedBelow,
                    scale: scale,
                    hideUsername: hideUsernames,
                    isSelected: isSelected
                )
            }
        }
    }
    
    private static func drawHorizontalLine(
        context: GraphicsContext,
        price: Double,
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        color: Color,
        markerX: CGFloat,
        isDashed: Bool = false,
        chartData: ChartDataManager? = nil
    ) {
        let scaledHeight = chartSize.height * priceScale
        let y = chartSize.height - (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
        
        // Draw line from left edge, stopping before Y-axis (matching PriceIndicatorView)
        let lineEndX = chartSize.width - 60
        let linePath = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))
        }
        
        let strokeStyle = isDashed ?
            StrokeStyle(lineWidth: 1.5, dash: [6, 4]) :
            StrokeStyle(lineWidth: 2)
        
        context.stroke(linePath, with: .color(color.opacity(0.6)), style: strokeStyle)
        
        // Y-axis price label (matching PriceIndicatorView style)
        let labelX = chartSize.width - 35
        let labelRect = CGRect(
            x: labelX - 35,
            y: y - 11,
            width: 70,
            height: 22
        )
        
        // Draw label background with marker color
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
        context.fill(roundedPath, with: .color(color))
        
        // Format price using symbol-aware formatting if chartData available
        let priceText = chartData?.formatPrice(price) ?? String(format: "%.5f", price)
        
        // Draw price text (white text on colored background)
        context.draw(
            Text(priceText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: labelX, y: y)
        )
    }
    
    private static func drawStackedConnectionLines(
        context: GraphicsContext,
        markers: [(marker: ChartMarker, position: CGPoint)],
        anchorY: CGFloat,
        centerX: CGFloat,
        isBelow: Bool
    ) {
        guard !markers.isEmpty else { return }
        
        let baseRadius: CGFloat = 14
        var previousY = anchorY
        
        for (marker, position) in markers {
            let markerEdgeY: CGFloat = isBelow ? position.y - baseRadius : position.y + baseRadius
            
            let linePath = Path { path in
                path.move(to: CGPoint(x: centerX, y: previousY))
                path.addLine(to: CGPoint(x: centerX, y: markerEdgeY))
            }
            
            context.stroke(
                linePath,
                with: .color(marker.type.color.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
            )
            
            previousY = isBelow ? position.y + baseRadius : position.y - baseRadius
        }
    }
    
    private static func drawSingleMarker(
        context: GraphicsContext,
        marker: ChartMarker,
        position: CGPoint,
        isBelow: Bool,
        scale: CGFloat = 1.0,
        hideUsername: Bool = false,
        isSelected: Bool = false
    ) {
        let baseRadius: CGFloat = 14
        let scaledRadius = baseRadius * scale
        
        // Selection glow effect
        if isSelected {
            let glowRect = CGRect(
                x: position.x - scaledRadius - 4,
                y: position.y - scaledRadius - 4,
                width: (scaledRadius + 4) * 2,
                height: (scaledRadius + 4) * 2
            )
            context.fill(Path(ellipseIn: glowRect), with: .color(marker.type.color.opacity(0.3)))
        }
        
        // Shadow
        let shadowRect = CGRect(
            x: position.x - scaledRadius + 1.5,
            y: position.y - scaledRadius + 1.5,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.35)))
        
        // Main circle
        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.95)))
        
        let borderWidth: CGFloat = isSelected ? 3.5 : 2.5
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color.opacity(0.6)), lineWidth: borderWidth * scale)
        
        // Inner colored circle
        let iconRadius: CGFloat = 9 * scale
        let iconCircle = CGRect(
            x: position.x - iconRadius,
            y: position.y - iconRadius,
            width: iconRadius * 2,
            height: iconRadius * 2
        )
        context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color.opacity(0.5)))
        
        // Draw SF Symbol icon instead of first letter
        // For emoji markers, show the emoji
        let displayText: String
        if marker.type == .emoji, let emoji = marker.selectedEmoji {
            displayText = emoji
        } else {
            // Use a unicode character that resembles the SF Symbol
            // (Canvas can't render SF Symbols directly, so we use similar characters)
            displayText = getIconCharacter(for: marker.type)
        }
        
        context.draw(
            Text(displayText)
                .font(.system(size: 12 * scale, weight: .heavy))
                .foregroundColor(.white.opacity(0.8)),
            at: position
        )
        
        // Like badge
//        if marker.likeCount > 0 {
//            let badgeOffset: CGFloat = (scaledRadius - 11)
//            let likeCircleRect = CGRect(
//                x: position.x + 7,
//                y: position.y + badgeOffset,
//                width: 12,
//                height: 12
//            )
//            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
//            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 0.8)
//            context.draw(
//                Text("\(marker.likeCount)")
//                    .font(.system(size: 8, weight: .bold))
//                    .foregroundColor(.white),
//                at: CGPoint(x: position.x + 13, y: position.y + badgeOffset + 6)
//            )
//        }
        
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = (scaledRadius - 11)
            let likeCircleRect = CGRect(
                x: position.x + 7,
                y: position.y + badgeOffset,
                width: 13,
                height: 13
            )
            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red.opacity(0.8)))
            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 1)
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 14, y: position.y + badgeOffset + 6)
            )
        }
//        if marker.likeCount > 0 {
//            let badgeOffset: CGFloat = isBelow ? -(scaledRadius + 2) : (scaledRadius - 12)
//            let likeCircleRect = CGRect(
//                x: position.x + 6,
//                y: position.y + badgeOffset,
//                width: 14,
//                height: 14
//            )
//            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
//            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 0.5)
//            context.draw(
//                Text("\(marker.likeCount)")
//                    .font(.system(size: 8, weight: .bold))
//                    .foregroundColor(.white),
//                at: CGPoint(x: position.x + 13, y: position.y + badgeOffset + 6)
//            )
//        }
        
        // Username label - only show if not hidden
        if !hideUsername {
            let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
            context.draw(
                Text(marker.username)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.85)),
                at: CGPoint(x: position.x, y: labelY)
            )
        }
    }
    
    /// Get a unicode character that represents the marker type
    /// (Since Canvas can't render SF Symbols directly)
    private static func getIconCharacter(for type: MarkerType) -> String {
        switch type {
            case .note: return "✎"
            case .question: return "?"
            case .alert: return "!"
            case .entry: return "↑"
            case .exit: return "↓"
            case .stopLoss: return "✕"      // ADD THIS
            case .takeProfit: return "✓"    // ADD THIS
            case .support: return "S"
            case .resistance: return "R"
            case .indicator: return "★"
            case .trendline: return "⤴"
            case .pattern: return "◇"
            case .volumeSpike: return "⚡"
            case .predictionTarget: return "⊛"
            case .emoji: return "☺"
            case .poll: return "✓"
            case .personal: return "●"
        }
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
        totalOffset: CGFloat
    ) -> ChartMarker? {
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
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            for marker in sorted.reversed() {
                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: marker,
                    candleHighY: candleHighY,
                    candleLowY: candleLowY,
                    centerX: centerX,
                    priceScale: priceScale  // FIXED: Pass priceScale for vertical zoom scaling
                )
                
                let distance = hypot(location.x - position.x, location.y - position.y)
                if distance <= hitRadius {
                    return marker
                }
            }
        }
        
        return nil
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
    let candles: [Candle]
    let markerType: MarkerType
    let initialTargetPrice: Double?  // NEW: For prediction markers
    
    @State private var note: String = ""
    
    // Type-specific state
    @State private var alertSeverity: MarkerAlertSeverity = .moderate
    @State private var trendlineDirection: TrendlineDirection = .up
    @State private var selectedIndicator: String = "RSI"
    @State private var chartPattern: ChartPattern = .doubleTop
    @State private var selectedEmoji: String = "🎯"
    @State private var pollQuestion: String = ""
    @State private var pollOption1: String = ""
    @State private var pollOption2: String = ""
    @State private var targetPrice: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Marker Info") {
                    HStack {
                        Image(systemName: markerType.icon)
                            .foregroundColor(markerType.color)
                            .frame(width: 30)
                        Text(markerType.rawValue)
                            .foregroundColor(.primary)
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
                
                // Type-specific options
                typeSpecificOptions
                
                Section("Note (Optional)") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add \(markerType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMarker()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.25), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.25)))
        .interactiveDismissDisabled(true)
        .onAppear {
            // Initialize target price for prediction markers
            if let initialTarget = initialTargetPrice {
                targetPrice = chartData.formatPrice(initialTarget)
                print("📝 ✓ Initialized target price field: \(targetPrice)")
            }
        }
    }
    
    @ViewBuilder
    private var typeSpecificOptions: some View {
        switch markerType {
        case .alert:
            Section("Alert Severity") {
                Picker("Severity", selection: $alertSeverity) {
                    ForEach(MarkerAlertSeverity.allCases, id: \.self) { severity in
                        HStack {
                            Circle()
                                .fill(severity.color)
                                .frame(width: 12, height: 12)
                            Text(severity.rawValue)
                        }
                        .tag(severity)
                    }
                }
                .pickerStyle(.menu)
            }
            
        case .trendline:
            Section("Trend Direction") {
                Picker("Direction", selection: $trendlineDirection) {
                    ForEach(TrendlineDirection.allCases, id: \.self) { direction in
                        Text(direction.rawValue).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
            }
            
        case .indicator:
            Section("Indicator") {
                Picker("Select Indicator", selection: $selectedIndicator) {
                    Text("RSI").tag("RSI")
                    Text("MACD").tag("MACD")
                    Text("Moving Average").tag("MA")
                    Text("Bollinger Bands").tag("BB")
                    Text("Stochastic").tag("STOCH")
                    Text("ATR").tag("ATR")
                }
                .pickerStyle(.menu)
            }
            
        case .pattern:
            Section("Chart Pattern") {
                Picker("Pattern", selection: $chartPattern) {
                    ForEach(ChartPattern.allCases, id: \.self) { pattern in
                        Text(pattern.rawValue).tag(pattern)
                    }
                }
                .pickerStyle(.menu)
            }
            
        case .emoji:
            Section("Select Emoji") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(["🎯", "🚀", "💰", "⚠️", "📈", "📉", "💎", "🔥", "⭐", "💡", "🤔", "👀"], id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.title)
                                .padding(8)
                                .background(selectedEmoji == emoji ? Color.blue.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)  // FIXED: Allows button taps in Form
                    }
                }
            }
            
        case .poll:
            Section("Poll Question") {
                TextField("Question", text: $pollQuestion)
            }
            Section("Options") {
                TextField("Option 1", text: $pollOption1)
                TextField("Option 2", text: $pollOption2)
            }
            
        case .predictionTarget:
            Section("Target Price") {
                TextField("Enter target price", text: $targetPrice)
                    .keyboardType(.decimalPad)
                Text("A horizontal line will be drawn at the target price")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        
        // FIXED: Explicit handling for markers that show horizontal lines
        case .entry:
            Section("Entry Details") {
                HStack {
                    Text("Entry Price")
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                Text("A horizontal line will be drawn at the candle close price")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .exit:
            Section("Exit Details") {
                HStack {
                    Text("Exit Price")
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
                Text("A horizontal line will be drawn at the candle close price")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .stopLoss:
            Section("Stop Loss Details") {
                HStack {
                    Text("Stop Loss Price")
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                Text("A horizontal line will be drawn at this price level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .takeProfit:
            Section("Take Profit Details") {
                HStack {
                    Text("Take Profit Price")
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
                Text("A horizontal line will be drawn at this price level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .support:
            Section("Support Level") {
                HStack {
                    Text("Support Price")
                    Spacer()
                    if candleIndex >= 0 && candleIndex < candles.count {
                        Text(chartData.formatPrice(candles[candleIndex].low))
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                    }
                }
                Text("A horizontal line will be drawn at the candle low")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .resistance:
            Section("Resistance Level") {
                HStack {
                    Text("Resistance Price")
                    Spacer()
                    if candleIndex >= 0 && candleIndex < candles.count {
                        Text(chartData.formatPrice(candles[candleIndex].high))
                            .foregroundColor(.pink)
                            .fontWeight(.semibold)
                    }
                }
                Text("A horizontal line will be drawn at the candle high")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        
        // Simple markers that just need notes
        case .note, .question, .volumeSpike, .personal:
            EmptyView()  // These just use the standard Note section
        }
    }
    
    private func addMarker() {
        print("📝 === MARKER CREATION SHEET - ADD MARKER ===")
        print("📝 Marker Type: \(markerType)")
        print("📝 Candle Index: \(candleIndex)")
        print("📝 Price: \(price)")
        print("📝 Timestamp: \(timestamp)")
        print("📝 Note: \(note.isEmpty ? "(empty)" : note)")
        print("📝 Target Price String: '\(targetPrice)'")
        
        var pollOptions: [PollOption]? = nil
        if markerType == .poll && !pollOption1.isEmpty {
            pollOptions = [
                PollOption(text: pollOption1),
                PollOption(text: pollOption2.isEmpty ? "Option 2" : pollOption2)
            ]
            print("📝 Poll Options: \(pollOptions!.count) options")
        }
        
        let target = Double(targetPrice)
        print("📝 Parsed Target Price: \(String(describing: target))")
        
        if markerType == .predictionTarget && target == nil {
            print("📝 ⚠️ WARNING: Prediction marker without target price!")
        }
        
        print("📝 Calling markerManager.addMarker...")
        let success = markerManager.addMarker(
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: markerType,
            username: username,
            note: note.isEmpty ? nil : note,
            candles: candles,
            targetPrice: target,
            alertSeverity: markerType == .alert ? alertSeverity : nil,
            trendlineDirection: markerType == .trendline ? trendlineDirection : nil,
            selectedIndicator: markerType == .indicator ? selectedIndicator : nil,
            chartPattern: markerType == .pattern ? chartPattern : nil,
            selectedEmoji: markerType == .emoji ? selectedEmoji : nil,
            pollQuestion: markerType == .poll ? pollQuestion : nil,
            pollOptions: pollOptions
        )
        
        if success {
            print("📝 ✅ Marker added successfully!")
            dismiss()
        } else {
            print("📝 ❌ Failed to add marker (duplicate detected)")
            // Note: duplicate alert is shown by MarkerManager
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
    @State private var newComment: String = ""
    
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
                
                // Type-specific info
                typeSpecificInfo
                
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
                
                // Comments section
                Section("Comments") {
                    ForEach(marker.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.username)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(comment.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(comment.text)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    HStack {
                        TextField("Add comment...", text: $newComment)
                        Button {
                            guard !newComment.isEmpty else { return }
                            markerManager.addComment(markerId: marker.id, text: newComment, username: "You")
                            newComment = ""
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Share/Save/Report buttons
                Section {
                    Button {
                        // Share action
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        // Save action
                    } label: {
                        Label("Save", systemImage: "bookmark")
                    }
                    
                    Button(role: .destructive) {
                        // Report action
                    } label: {
                        Label("Report", systemImage: "flag")
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
        .presentationDetents([.fraction(0.25), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.25)))
        .onAppear {
            editedNote = marker.note ?? ""
        }
    }
    
    @ViewBuilder
    private var typeSpecificInfo: some View {
        switch marker.type {
        case .alert:
            if let severity = marker.alertSeverity {
                Section("Alert Details") {
                    HStack {
                        Circle()
                            .fill(severity.color)
                            .frame(width: 12, height: 12)
                        Text(severity.rawValue)
                    }
                }
            }
            
        case .trendline:
            if let direction = marker.trendlineDirection {
                Section("Trendline Direction") {
                    Text(direction.rawValue)
                }
            }
            
        case .indicator:
            if let indicator = marker.selectedIndicator {
                Section("Indicator") {
                    Text(indicator)
                }
            }
            
        case .pattern:
            if let pattern = marker.chartPattern {
                Section("Chart Pattern") {
                    Text(pattern.rawValue)
                }
            }
            
        case .predictionTarget:
            if let target = marker.targetPrice {
                Section("Prediction") {
                    HStack {
                        Text("Target Price")
                        Spacer()
                        Text(chartData.formatPrice(target))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
        case .poll:
            if let question = marker.pollQuestion, let options = marker.pollOptions {
                Section("Poll: \(question)") {
                    ForEach(options) { option in
                        HStack {
                            Text(option.text)
                            Spacer()
                            Text("\(option.voteCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Temporary Marker Placement Indicator

/// Shows a temporary price line indicator while placing a marker
/// Matches the style of PriceIndicatorView for consistency
struct MarkerPlacementPriceIndicator: View {
    let price: Double
    let markerType: MarkerType
    let priceScale: CGFloat
    let verticalOffset: CGFloat
    let chartHeight: CGFloat
    let priceRange: (min: Double, max: Double)
    let chartData: ChartDataManager
    
    private var indicatorYPosition: CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    private var isVisible: Bool {
        indicatorYPosition >= 0 && indicatorYPosition <= chartHeight
    }
    
    private var formattedPrice: String {
        chartData.formatPrice(price)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible && price > 0 {
                Canvas { context, size in
                    let y = indicatorYPosition
                    let lineEndX = size.width - 60
                    
                    // Draw horizontal dashed line
                    let linePath = Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: lineEndX, y: y))
                    }
                    context.stroke(
                        linePath,
                        with: .color(markerType.color.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
                    
                    // Draw price label background (colored by marker type)
                    let labelX = size.width - 35
                    let labelRect = CGRect(
                        x: labelX - 35,
                        y: y - 11,
                        width: 70,
                        height: 22
                    )
                    let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
                    context.fill(roundedPath, with: .color(markerType.color))
                    
                    // Draw price text
                    let text = Text(formattedPrice)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    context.draw(text, at: CGPoint(x: labelX, y: y))
                }
            }
        }
        .allowsHitTesting(false)
    }
}



////
////  ChartMarkerSystem.swift
////  traders_guild
////
////  COMPREHENSIVE UPDATE v6 - Major refactor:
////  1. Markers favor top placement (only below for severe troughs)
////  2. Tighter stacking with reduced spacing
////  3. Remove clustering - show all markers individually
////  4. One type per candle restriction (offer like instead)
////  5. Display SF Symbol icons instead of first letter
////  6. Selected marker scales up and shows custom views (lines)
////  7. Hide usernames when multiple markers on same candle
////  8. Horizontal lines for Entry/Exit/Support/Resistance markers
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
//    /// Tracks if we should show a "like existing marker" prompt
//    @Published var duplicateMarkerToLike: ChartMarker?
//    @Published var showDuplicateAlert: Bool = false
//    
//    private let currentUserId: String
//    private let currentGuildId: String
//    
//    var guildId: String { currentGuildId }
//    var userId: String { currentUserId }
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
//            // ISSUE #2 FIX: Complete reset of positioning fields to force proper recalculation
//            // Historical markers might have stale positioning data that causes overlaps
//            // We need to clear ALL positioning data, not just the main fields
//            for i in 0..<positionedMarkers.count {
//                positionedMarkers[i].positionedBelow = false
//                positionedMarkers[i].proximityTier = 0
//                positionedMarkers[i].stackIndex = 0
//                // Clear any cached visual properties that might affect rendering
//                positionedMarkers[i].isVisible = true
//            }
//            
//            // Force a stable sort by creation date before recalculating positions
//            // This ensures consistent stacking order
//            positionedMarkers.sort { $0.createdAt < $1.createdAt }
//            
//            // Now calculate proper positions with fresh state
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
//        selectedMarker = nil
//    }
//    
//    // MARK: - Duplicate Type Check
//    
//    /// Check if a marker of the same type already exists on this candle
//    /// Returns the existing marker if found
//    func existingMarkerOfType(_ type: MarkerType, atCandleIndex candleIndex: Int) -> ChartMarker? {
//        return markers.first { marker in
//            marker.candleIndex == candleIndex && marker.type == type
//        }
//    }
//    
//    /// Check if adding a marker is allowed (no duplicate types on same candle)
//    func canAddMarker(type: MarkerType, atCandleIndex candleIndex: Int) -> Bool {
//        return existingMarkerOfType(type, atCandleIndex: candleIndex) == nil
//    }
//    
//    // MARK: - Marker CRUD
//    
//    /// Add a new marker with proper positioning calculation
//    /// Returns true if added successfully, false if duplicate type exists
//    @discardableResult
//    func addMarker(
//        candleIndex: Int,
//        timestamp: Date,
//        price: Double,
//        type: MarkerType,
//        username: String,
//        note: String? = nil,
//        candles: [Candle],
//        horizontalLinePrice: Double? = nil,
//        targetPrice: Double? = nil,
//        alertSeverity: MarkerAlertSeverity? = nil,
//        trendlineDirection: TrendlineDirection? = nil,
//        selectedIndicator: String? = nil,
//        chartPattern: ChartPattern? = nil,
//        selectedEmoji: String? = nil,
//        pollQuestion: String? = nil,
//        pollOptions: [PollOption]? = nil
//    ) -> Bool {
//        print("🔧 === MARKER MANAGER - ADD MARKER ===")
//        print("🔧 Type: \(type)")
//        print("🔧 Candle Index: \(candleIndex)")
//        print("🔧 Price: \(price)")
//        print("🔧 Target Price: \(String(describing: targetPrice))")
//        print("🔧 Horizontal Line Price: \(String(describing: horizontalLinePrice))")
//        print("🔧 Candles count: \(candles.count)")
//        
//        // Validate candle index
//        guard candleIndex >= 0 && candleIndex < candles.count else {
//            print("🔧 ❌ ERROR: Invalid candle index \(candleIndex) (candles: \(candles.count))")
//            return false
//        }
//        
//        // Check for duplicate type on same candle
//        if let existingMarker = existingMarkerOfType(type, atCandleIndex: candleIndex) {
//            print("🔧 ⚠️ Duplicate marker detected: \(existingMarker.id)")
//            print("🔧 Showing duplicate alert...")
//            duplicateMarkerToLike = existingMarker
//            showDuplicateAlert = true
//            return false
//        }
//        
//        print("🔧 ✓ No duplicate found")
//        
//        // Calculate line price based on marker type
//        var linePrice = horizontalLinePrice
//        if type.hasHorizontalLine && linePrice == nil && candleIndex >= 0 && candleIndex < candles.count {
//            let candle = candles[candleIndex]
//            print("🔧 Calculating line price from candle:")
//            print("🔧 Candle: O:\(candle.open) H:\(candle.high) L:\(candle.low) C:\(candle.close)")
//            print("🔧 Line source: \(type.lineSource)")
//            
//            switch type.lineSource {
//            case .candleOpen:
//                linePrice = candle.open
//            case .candleClose:
//                linePrice = candle.close
//            case .candleHigh:
//                linePrice = candle.high
//            case .candleLow:
//                linePrice = candle.low
//            case .custom:
//                linePrice = targetPrice
//            case .none:
//                break
//            }
//            
//            print("🔧 Calculated line price: \(String(describing: linePrice))")
//        }
//        
//        print("🔧 Creating ChartMarker...")
//        var marker = ChartMarker(
//            candleIndex: candleIndex,
//            timestamp: timestamp,
//            price: price,
//            type: type,
//            userId: currentUserId,
//            username: username,
//            note: note,
//            guildId: currentGuildId,
//            horizontalLinePrice: linePrice,
//            targetPrice: targetPrice,
//            alertSeverity: alertSeverity,
//            trendlineDirection: trendlineDirection,
//            selectedIndicator: selectedIndicator,
//            chartPattern: chartPattern,
//            selectedEmoji: selectedEmoji,
//            pollQuestion: pollQuestion,
//            pollOptions: pollOptions
//        )
//        
//        print("🔧 ✓ Marker created: \(marker.id)")
//        print("🔧 Marker has target: \(marker.targetPrice != nil)")
//        print("🔧 Marker has line: \(marker.horizontalLinePrice != nil)")
//        
//        // Calculate proper position
//        print("🔧 Calculating position...")
//        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
//            marker: marker,
//            existingMarkers: markers,
//            candles: candles
//        )
//        
//        print("🔧 Position: below=\(positioning.isBelow) tier=\(positioning.tier) stack=\(positioning.stackIndex)")
//        
//        marker.positionedBelow = positioning.isBelow
//        marker.proximityTier = positioning.tier
//        marker.stackIndex = positioning.stackIndex
//        
//        markers.append(marker)
//        print("🔧 ✅ Marker appended to array. Total markers: \(markers.count)")
//        return true
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
//    func addComment(markerId: UUID, text: String, username: String) {
//        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
//        let comment = MarkerComment(userId: currentUserId, username: username, text: text)
//        markers[index].comments.append(comment)
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
//    /// Get count of markers at a specific candle
//    func markerCount(atCandleIndex candleIndex: Int) -> Int {
//        markersGroupedByCandle()[candleIndex]?.count ?? 0
//    }
//    
//    /// Check if we should hide usernames (more than 1 marker on candle)
//    func shouldHideUsername(forCandleIndex candleIndex: Int) -> Bool {
//        markerCount(atCandleIndex: candleIndex) > 1
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
//    /// REDUCED stack offset for tighter stacking
//    @Published var stackOffset: CGFloat {
//        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
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
//        // Adjusted offsets for new stacking behavior
//        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 70
//        // REDUCED from 28 to 20 for tighter stacking (Issue #1 fix)
//        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 20
//        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 25
//        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 40
//    }
//    
//    func resetToDefaults() {
//        baseOffset = 70
//        stackOffset = 20
//        proximityTierOffset = 25
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
//    static let proximityRange = 3
//    static let hitRadius: CGFloat = 28
//    
//    static var placementOffset: CGFloat {
//        settings.baseOffset + settings.placementExtraOffset
//    }
//    
//    // MARK: - SHARED Position Calculation
//    
//    /// Calculate the screen position for a marker using its STORED properties
//    /// FIXED: Now accepts priceScale to scale marker distance when vertically zooming
//    static func computeMarkerScreenPosition(
//        marker: ChartMarker,
//        candleHighY: CGFloat,
//        candleLowY: CGFloat,
//        centerX: CGFloat,
//        priceScale: CGFloat = 1.0  // NEW: Scale marker distance with vertical zoom
//    ) -> CGPoint {
//        let baseY: CGFloat
//        let stackDirection: CGFloat
//        
//        // FIXED: Apply dampening to priceScale to make scaling less extreme
//        // Dampening factor of 0.5 means markers scale at 50% of the rate of candles
//        // Examples: 2x zoom → 1.5x marker distance, 3x zoom → 2x marker distance
//        let dampenedScale = dampenPriceScale(priceScale, dampening: 0.75)
//        
//        let scaledBaseOffset = baseOffset * dampenedScale
//        let scaledStackOffset = stackOffset * dampenedScale
//        let scaledTierOffset = offsetForTier(marker.proximityTier) * dampenedScale
//        
//        if marker.positionedBelow {
//            baseY = candleLowY + scaledBaseOffset
//            stackDirection = 1.0
//        } else {
//            baseY = candleHighY - scaledBaseOffset
//            stackDirection = -1.0
//        }
//        
//        let stackOffsetValue = CGFloat(marker.stackIndex) * scaledStackOffset * stackDirection
//        let tierOffset = scaledTierOffset * stackDirection
//        let markerY = baseY + stackOffsetValue + tierOffset
//        
//        return CGPoint(x: centerX, y: markerY)
//    }
//    
//    /// Apply dampening to price scale to make marker scaling less extreme
//    /// - Parameters:
//    ///   - priceScale: The raw vertical zoom scale (1.0 = normal, 2.0 = 2x zoom, etc.)
//    ///   - dampening: How much to dampen (0.0 = no scaling, 1.0 = full scaling)
//    /// - Returns: Dampened scale factor
//    private static func dampenPriceScale(_ priceScale: CGFloat, dampening: CGFloat) -> CGFloat {
//        // Use interpolation between 1.0 (no scale) and priceScale (full scale)
//        // dampening = 0.5 means halfway between no scaling and full scaling
//        return 1.0 + (priceScale - 1.0) * dampening
//    }
//    
//    /// Calculate PREVIEW position for new marker placement
//    /// UPDATED: Now favors top placement by default
//    /// FIXED: Now accepts priceScale to scale preview marker distance
//    static func calculatePreviewPosition(
//        candleIndex: Int,
//        existingMarkers: [ChartMarker],
//        candles: [Candle],
//        candleHighY: CGFloat,
//        candleLowY: CGFloat,
//        centerX: CGFloat,
//        priceScale: CGFloat = 1.0  // NEW: Scale preview marker distance
//    ) -> (position: CGPoint, isBelow: Bool) {
//        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
//        
//        // FIXED: Apply dampening to priceScale for preview marker too
//        let dampenedScale = dampenPriceScale(priceScale, dampening: 0.75)
//        let scaledPlacementOffset = placementOffset * dampenedScale
//        let scaledStackOffset = stackOffset * dampenedScale
//        
//        // NEW LOGIC: Default to ABOVE (false = not below)
//        // Only go below if:
//        // 1. There are already markers above and we need to alternate
//        // 2. It's a severe peak (lower candles on both sides)
//        
//        let shouldBeBelow: Bool
//        
//        if markersAtCandle.isEmpty {
//            // No existing markers - check for severe peak first, otherwise default to above
//            let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
//            let isSevereTrough = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: false)
//            
//            if isSeverePeak && !isSevereTrough {
//                // Severe peak - place below
//                shouldBeBelow = true
//            } else {
//                // Default to above (including severe troughs and neutral cases)
//                shouldBeBelow = false
//            }
//            
//            // Check nearby marker density and adjust if needed
//            let nearbyMarkers = existingMarkers.filter {
//                abs($0.candleIndex - candleIndex) <= proximityRange
//            }
//            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
//            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
//            
//            // If above is very crowded, consider below
//            if neighborsAbove > neighborsBelow + 3 && !isSevereTrough {
//                let baseY = candleLowY + scaledPlacementOffset
//                return (CGPoint(x: centerX, y: baseY), true)
//            }
//        } else {
//            // FIXED: Has existing markers - place on SAME side as existing ones
//            // This ensures all markers stack together instead of alternating
//            if let firstMarker = markersAtCandle.first {
//                shouldBeBelow = firstMarker.positionedBelow
//            } else {
//                shouldBeBelow = false // Fallback - should never reach here
//            }
//        }
//        
//        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
//        let baseY: CGFloat
//        let stackDirection: CGFloat
//        
//        if shouldBeBelow {
//            baseY = candleLowY + scaledPlacementOffset
//            stackDirection = 1.0
//        } else {
//            baseY = candleHighY - scaledPlacementOffset
//            stackDirection = -1.0
//        }
//        
//        let stackOffsetValue = CGFloat(stackIndex) * scaledStackOffset * stackDirection
//        let markerY = baseY + stackOffsetValue
//        
//        return (CGPoint(x: centerX, y: markerY), shouldBeBelow)
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
//        
//        for candleIndex in sortedIndices {
//            guard let markersAtCandle = grouped[candleIndex] else { continue }
//            
//            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//            
//            // Track markers placed above and below for this candle
//            var aboveStackIndex = 0
//            var belowStackIndex = 0
//            
//            for marker in sorted {
//                guard let resultIndex = result.firstIndex(where: { $0.id == marker.id }) else { continue }
//                
//                // NEW: Favor above placement
//                // First marker always goes above unless severe peak
//                // Subsequent markers alternate
//                let shouldBeBelow: Bool
//                
//                // FIXED: All markers on same candle should be on the same side
//                // First marker determines side, all others follow
//                if sorted.count == 1 {
//                    // Single marker - check for severe peak
//                    let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
//                    shouldBeBelow = isSeverePeak
//                } else {
//                    // Multiple markers - ALL go on same side
//                    // First marker (aboveStackIndex == 0 && belowStackIndex == 0) determines side
//                    if aboveStackIndex == 0 && belowStackIndex == 0 {
//                        let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
//                        shouldBeBelow = isSeverePeak
//                    } else if aboveStackIndex > 0 {
//                        // We already have markers above, keep stacking above
//                        shouldBeBelow = false
//                    } else {
//                        // We already have markers below, keep stacking below
//                        shouldBeBelow = true
//                    }
//                }
//                
//                let stackIndex: Int
//                if shouldBeBelow {
//                    stackIndex = belowStackIndex
//                    belowStackIndex += 1
//                } else {
//                    stackIndex = aboveStackIndex
//                    aboveStackIndex += 1
//                }
//                
//                let tier: Int
//                if shouldBeBelow {
//                    tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedBelowTiers)
//                } else {
//                    tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedAboveTiers)
//                }
//                
//                result[resultIndex].positionedBelow = shouldBeBelow
//                result[resultIndex].proximityTier = tier
//                result[resultIndex].stackIndex = stackIndex
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
//        
//        let shouldBeBelow: Bool
//        
//        if markersAtCandle.isEmpty {
//            // NEW: Default to above unless severe peak
//            let isSeverePeak = isSeverePeakOrTrough(candleIndex: candleIndex, candles: candles, checkPeak: true)
//            shouldBeBelow = isSeverePeak
//            
//            // Check nearby marker density
//            let nearbyMarkers = existingMarkers.filter {
//                abs($0.candleIndex - candleIndex) <= proximityRange
//            }
//            let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
//            let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
//            
//            if neighborsAbove > neighborsBelow + 3 {
//                // Above is crowded, go below
//                let sameSideNearby = existingMarkers.filter {
//                    abs($0.candleIndex - candleIndex) <= proximityRange && $0.positionedBelow
//                }
//                let usedTiers = Set(sameSideNearby.map { $0.proximityTier })
//                var tier = 0
//                while usedTiers.contains(tier) { tier += 1 }
//                return (isBelow: true, tier: tier, stackIndex: 0)
//            }
//        } else {
//            // FIXED: Has existing markers - place on SAME side as existing ones
//            if let firstMarker = markersAtCandle.first {
//                shouldBeBelow = firstMarker.positionedBelow
//            } else {
//                shouldBeBelow = false
//            }
//        }
//        
//        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
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
//        return (isBelow: shouldBeBelow, tier: tier, stackIndex: stackIndex)
//    }
//    
//    // MARK: - Severe Peak/Trough Detection
//    
//    /// Check if a candle is a severe peak (for placing below) or severe trough (for placing above)
//    /// A severe peak/trough requires BOTH neighbors to be lower/higher
//    private static func isSeverePeakOrTrough(
//        candleIndex: Int,
//        candles: [Candle],
//        checkPeak: Bool
//    ) -> Bool {
//        guard candleIndex > 0 && candleIndex < candles.count - 1 else { return false }
//        
//        let candle = candles[candleIndex]
//        let leftCandle = candles[candleIndex - 1]
//        let rightCandle = candles[candleIndex + 1]
//        
//        if checkPeak {
//            // Severe peak: candle high is above BOTH neighbors' highs
//            return candle.high > leftCandle.high && candle.high > rightCandle.high
//        } else {
//            // Severe trough: candle low is below BOTH neighbors' lows
//            return candle.low < leftCandle.low && candle.low < rightCandle.low
//        }
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
//        markerManager: MarkerManager? = nil,
//        selectedMarkerId: UUID? = nil,
//        chartData: ChartDataManager? = nil
//    ) {
//        let scaledHeight = chartSize.height * priceScale
//        let allVisibleMarkers = markers.filter { $0.isVisible }
//        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
//        
//        // HORIZONTAL LINES REMOVED FROM CANVAS
//        // Now drawn in MarkerPriceLinesOverlay (SwiftUI layer on top of y-axis)
//        // This ensures price labels appear above the y-axis overlay
//        
//        /*
//        // Draw horizontal lines for selected marker first (behind markers)
//        if let selectedId = selectedMarkerId,
//           let selectedMarker = markers.first(where: { $0.id == selectedId }),
//           selectedMarker.type.hasHorizontalLine,
//           selectedMarker.candleIndex >= 0 && selectedMarker.candleIndex < candles.count {
//            let candle = candles[selectedMarker.candleIndex]
//            if let linePrice = selectedMarker.getLinePrice(candle: candle) {
//                drawHorizontalLine(
//                    context: context,
//                    price: linePrice,
//                    chartSize: chartSize,
//                    priceRange: priceRange,
//                    priceScale: priceScale,
//                    verticalOffset: verticalOffset,
//                    color: selectedMarker.type.color,
//                    markerX: CGFloat(selectedMarker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2,
//                    chartData: chartData
//                )
//            }
//            
//            // Draw target price line for prediction markers
//            if selectedMarker.type == .predictionTarget, let targetPrice = selectedMarker.targetPrice {
//                drawHorizontalLine(
//                    context: context,
//                    price: targetPrice,
//                    chartSize: chartSize,
//                    priceRange: priceRange,
//                    priceScale: priceScale,
//                    verticalOffset: verticalOffset,
//                    color: .red.opacity(0.8),
//                    markerX: CGFloat(selectedMarker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2,
//                    isDashed: true,
//                    chartData: chartData
//                )
//            }
//        }
//        */
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
//            // No clustering - show all markers
//            let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//            let hideUsernames = markersAtCandle.count > 1
//            
//            var markerPositions: [(marker: ChartMarker, position: CGPoint)] = []
//            for marker in sortedMarkers {
//                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
//                    marker: marker,
//                    candleHighY: candleHighY,
//                    candleLowY: candleLowY,
//                    centerX: centerX,
//                    priceScale: priceScale  // FIXED: Pass priceScale for vertical zoom scaling
//                )
//                markerPositions.append((marker, position))
//            }
//            
//            let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
//            let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
//            
//            drawStackedConnectionLines(context: context, markers: aboveMarkers, anchorY: candleHighY, centerX: centerX, isBelow: false)
//            drawStackedConnectionLines(context: context, markers: belowMarkers, anchorY: candleLowY, centerX: centerX, isBelow: true)
//            
//            for (marker, position) in markerPositions {
//                let isSelected = selectedMarkerId == marker.id
//                let scale: CGFloat = isSelected ? 1.3 : 1.0
//                
//                drawSingleMarker(
//                    context: context,
//                    marker: marker,
//                    position: position,
//                    isBelow: marker.positionedBelow,
//                    scale: scale,
//                    hideUsername: hideUsernames,
//                    isSelected: isSelected
//                )
//            }
//        }
//    }
//    
//    private static func drawHorizontalLine(
//        context: GraphicsContext,
//        price: Double,
//        chartSize: CGSize,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        color: Color,
//        markerX: CGFloat,
//        isDashed: Bool = false,
//        chartData: ChartDataManager? = nil
//    ) {
//        let scaledHeight = chartSize.height * priceScale
//        let y = chartSize.height - (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
//        
//        // Draw line from left edge, stopping before Y-axis (matching PriceIndicatorView)
//        let lineEndX = chartSize.width - 60
//        let linePath = Path { path in
//            path.move(to: CGPoint(x: 0, y: y))
//            path.addLine(to: CGPoint(x: lineEndX, y: y))
//        }
//        
//        let strokeStyle = isDashed ?
//            StrokeStyle(lineWidth: 1.5, dash: [6, 4]) :
//            StrokeStyle(lineWidth: 2)
//        
//        context.stroke(linePath, with: .color(color.opacity(0.6)), style: strokeStyle)
//        
//        // Y-axis price label (matching PriceIndicatorView style)
//        let labelX = chartSize.width - 35
//        let labelRect = CGRect(
//            x: labelX - 35,
//            y: y - 11,
//            width: 70,
//            height: 22
//        )
//        
//        // Draw label background with marker color
//        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
//        context.fill(roundedPath, with: .color(color))
//        
//        // Format price using symbol-aware formatting if chartData available
//        let priceText = chartData?.formatPrice(price) ?? String(format: "%.5f", price)
//        
//        // Draw price text (white text on colored background)
//        context.draw(
//            Text(priceText)
//                .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white),
//            at: CGPoint(x: labelX, y: y)
//        )
//    }
//    
//    private static func drawStackedConnectionLines(
//        context: GraphicsContext,
//        markers: [(marker: ChartMarker, position: CGPoint)],
//        anchorY: CGFloat,
//        centerX: CGFloat,
//        isBelow: Bool
//    ) {
//        guard !markers.isEmpty else { return }
//        
//        let baseRadius: CGFloat = 14
//        var previousY = anchorY
//        
//        for (marker, position) in markers {
//            let markerEdgeY: CGFloat = isBelow ? position.y - baseRadius : position.y + baseRadius
//            
//            let linePath = Path { path in
//                path.move(to: CGPoint(x: centerX, y: previousY))
//                path.addLine(to: CGPoint(x: centerX, y: markerEdgeY))
//            }
//            
//            context.stroke(
//                linePath,
//                with: .color(marker.type.color.opacity(0.6)),
//                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
//            )
//            
//            previousY = isBelow ? position.y + baseRadius : position.y - baseRadius
//        }
//    }
//    
//    private static func drawSingleMarker(
//        context: GraphicsContext,
//        marker: ChartMarker,
//        position: CGPoint,
//        isBelow: Bool,
//        scale: CGFloat = 1.0,
//        hideUsername: Bool = false,
//        isSelected: Bool = false
//    ) {
//        let baseRadius: CGFloat = 14
//        let scaledRadius = baseRadius * scale
//        
//        // Selection glow effect
//        if isSelected {
//            let glowRect = CGRect(
//                x: position.x - scaledRadius - 4,
//                y: position.y - scaledRadius - 4,
//                width: (scaledRadius + 4) * 2,
//                height: (scaledRadius + 4) * 2
//            )
//            context.fill(Path(ellipseIn: glowRect), with: .color(marker.type.color.opacity(0.3)))
//        }
//        
//        // Shadow
//        let shadowRect = CGRect(
//            x: position.x - scaledRadius + 1.5,
//            y: position.y - scaledRadius + 1.5,
//            width: scaledRadius * 2,
//            height: scaledRadius * 2
//        )
//        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.35)))
//        
//        // Main circle
//        let circleRect = CGRect(
//            x: position.x - scaledRadius,
//            y: position.y - scaledRadius,
//            width: scaledRadius * 2,
//            height: scaledRadius * 2
//        )
//        context.fill(Path(ellipseIn: circleRect), with: .color(.black.opacity(0.95)))
//        
//        let borderWidth: CGFloat = isSelected ? 3.5 : 2.5
//        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color.opacity(0.6)), lineWidth: borderWidth * scale)
//        
//        // Inner colored circle
//        let iconRadius: CGFloat = 9 * scale
//        let iconCircle = CGRect(
//            x: position.x - iconRadius,
//            y: position.y - iconRadius,
//            width: iconRadius * 2,
//            height: iconRadius * 2
//        )
//        context.fill(Path(ellipseIn: iconCircle), with: .color(marker.type.color.opacity(0.5)))
//        
//        // Draw SF Symbol icon instead of first letter
//        // For emoji markers, show the emoji
//        let displayText: String
//        if marker.type == .emoji, let emoji = marker.selectedEmoji {
//            displayText = emoji
//        } else {
//            // Use a unicode character that resembles the SF Symbol
//            // (Canvas can't render SF Symbols directly, so we use similar characters)
//            displayText = getIconCharacter(for: marker.type)
//        }
//        
//        context.draw(
//            Text(displayText)
//                .font(.system(size: 12 * scale, weight: .heavy))
//                .foregroundColor(.white.opacity(0.8)),
//            at: position
//        )
//        
//        // Like badge
////        if marker.likeCount > 0 {
////            let badgeOffset: CGFloat = (scaledRadius - 11)
////            let likeCircleRect = CGRect(
////                x: position.x + 7,
////                y: position.y + badgeOffset,
////                width: 12,
////                height: 12
////            )
////            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
////            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 0.8)
////            context.draw(
////                Text("\(marker.likeCount)")
////                    .font(.system(size: 8, weight: .bold))
////                    .foregroundColor(.white),
////                at: CGPoint(x: position.x + 13, y: position.y + badgeOffset + 6)
////            )
////        }
//        
//        if marker.likeCount > 0 {
//            let badgeOffset: CGFloat = (scaledRadius - 11)
//            let likeCircleRect = CGRect(
//                x: position.x + 7,
//                y: position.y + badgeOffset,
//                width: 13,
//                height: 13
//            )
//            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red.opacity(0.8)))
//            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 1)
//            context.draw(
//                Text("\(marker.likeCount)")
//                    .font(.system(size: 8, weight: .bold))
//                    .foregroundColor(.white),
//                at: CGPoint(x: position.x + 14, y: position.y + badgeOffset + 6)
//            )
//        }
////        if marker.likeCount > 0 {
////            let badgeOffset: CGFloat = isBelow ? -(scaledRadius + 2) : (scaledRadius - 12)
////            let likeCircleRect = CGRect(
////                x: position.x + 6,
////                y: position.y + badgeOffset,
////                width: 14,
////                height: 14
////            )
////            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.red))
////            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 0.5)
////            context.draw(
////                Text("\(marker.likeCount)")
////                    .font(.system(size: 8, weight: .bold))
////                    .foregroundColor(.white),
////                at: CGPoint(x: position.x + 13, y: position.y + badgeOffset + 6)
////            )
////        }
//        
//        // Username label - only show if not hidden
//        if !hideUsername {
//            let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
//            context.draw(
//                Text(marker.username)
//                    .font(.system(size: 8, weight: .medium))
//                    .foregroundColor(.white.opacity(0.85)),
//                at: CGPoint(x: position.x, y: labelY)
//            )
//        }
//    }
//    
//    /// Get a unicode character that represents the marker type
//    /// (Since Canvas can't render SF Symbols directly)
//    private static func getIconCharacter(for type: MarkerType) -> String {
//        switch type {
//            case .note: return "✎"
//            case .question: return "?"
//            case .alert: return "!"
//            case .entry: return "↑"
//            case .exit: return "↓"
//            case .stopLoss: return "✕"      // ADD THIS
//            case .takeProfit: return "✓"    // ADD THIS
//            case .support: return "S"
//            case .resistance: return "R"
//            case .indicator: return "★"
//            case .trendline: return "⤴"
//            case .pattern: return "◇"
//            case .volumeSpike: return "⚡"
//            case .predictionTarget: return "⊛"
//            case .emoji: return "☺"
//            case .poll: return "✓"
//            case .personal: return "●"
//        }
//    }
//    
//    // MARK: - Hit Detection
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
//        totalOffset: CGFloat
//    ) -> ChartMarker? {
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
//            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
//            
//            for marker in sorted.reversed() {
//                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
//                    marker: marker,
//                    candleHighY: candleHighY,
//                    candleLowY: candleLowY,
//                    centerX: centerX,
//                    priceScale: priceScale  // FIXED: Pass priceScale for vertical zoom scaling
//                )
//                
//                let distance = hypot(location.x - position.x, location.y - position.y)
//                if distance <= hitRadius {
//                    return marker
//                }
//            }
//        }
//        
//        return nil
//    }
//}
//
//// MARK: - Marker Creation Sheet
//
//struct MarkerCreationSheet: View {
//    @Environment(\.dismiss) private var dismiss
//    @ObservedObject var markerManager: MarkerManager
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let username: String
//    let chartData: ChartDataManager
//    let candles: [Candle]
//    let markerType: MarkerType
//    let initialTargetPrice: Double?  // NEW: For prediction markers
//    
//    @State private var note: String = ""
//    
//    // Type-specific state
//    @State private var alertSeverity: MarkerAlertSeverity = .moderate
//    @State private var trendlineDirection: TrendlineDirection = .up
//    @State private var selectedIndicator: String = "RSI"
//    @State private var chartPattern: ChartPattern = .doubleTop
//    @State private var selectedEmoji: String = "🎯"
//    @State private var pollQuestion: String = ""
//    @State private var pollOption1: String = ""
//    @State private var pollOption2: String = ""
//    @State private var targetPrice: String = ""
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Marker Info") {
//                    HStack {
//                        Image(systemName: markerType.icon)
//                            .foregroundColor(markerType.color)
//                            .frame(width: 30)
//                        Text(markerType.rawValue)
//                            .foregroundColor(.primary)
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
//                // Type-specific options
//                typeSpecificOptions
//                
//                Section("Note (Optional)") {
//                    TextEditor(text: $note)
//                        .frame(minHeight: 80)
//                }
//            }
//            .navigationTitle("Add \(markerType.rawValue)")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Add") {
//                        addMarker()
//                    }
//                }
//            }
//        }
//        .presentationDetents([.fraction(0.25), .medium, .large])
//        .presentationDragIndicator(.visible)
//        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.25)))
//        .interactiveDismissDisabled(true)
//        .onAppear {
//            // Initialize target price for prediction markers
//            if let initialTarget = initialTargetPrice {
//                targetPrice = chartData.formatPrice(initialTarget)
//                print("📝 ✓ Initialized target price field: \(targetPrice)")
//            }
//        }
//    }
//    
//    @ViewBuilder
//    private var typeSpecificOptions: some View {
//        switch markerType {
//        case .alert:
//            Section("Alert Severity") {
//                Picker("Severity", selection: $alertSeverity) {
//                    ForEach(MarkerAlertSeverity.allCases, id: \.self) { severity in
//                        HStack {
//                            Circle()
//                                .fill(severity.color)
//                                .frame(width: 12, height: 12)
//                            Text(severity.rawValue)
//                        }
//                        .tag(severity)
//                    }
//                }
//                .pickerStyle(.menu)
//            }
//            
//        case .trendline:
//            Section("Trend Direction") {
//                Picker("Direction", selection: $trendlineDirection) {
//                    ForEach(TrendlineDirection.allCases, id: \.self) { direction in
//                        Text(direction.rawValue).tag(direction)
//                    }
//                }
//                .pickerStyle(.segmented)
//            }
//            
//        case .indicator:
//            Section("Indicator") {
//                Picker("Select Indicator", selection: $selectedIndicator) {
//                    Text("RSI").tag("RSI")
//                    Text("MACD").tag("MACD")
//                    Text("Moving Average").tag("MA")
//                    Text("Bollinger Bands").tag("BB")
//                    Text("Stochastic").tag("STOCH")
//                    Text("ATR").tag("ATR")
//                }
//                .pickerStyle(.menu)
//            }
//            
//        case .pattern:
//            Section("Chart Pattern") {
//                Picker("Pattern", selection: $chartPattern) {
//                    ForEach(ChartPattern.allCases, id: \.self) { pattern in
//                        Text(pattern.rawValue).tag(pattern)
//                    }
//                }
//                .pickerStyle(.menu)
//            }
//            
//        case .emoji:
//            Section("Select Emoji") {
//                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
//                    ForEach(["🎯", "🚀", "💰", "⚠️", "📈", "📉", "💎", "🔥", "⭐", "💡", "🤔", "👀"], id: \.self) { emoji in
//                        Button {
//                            selectedEmoji = emoji
//                        } label: {
//                            Text(emoji)
//                                .font(.title)
//                                .padding(8)
//                                .background(selectedEmoji == emoji ? Color.blue.opacity(0.3) : Color.clear)
//                                .cornerRadius(8)
//                        }
//                        .buttonStyle(.borderless)  // FIXED: Allows button taps in Form
//                    }
//                }
//            }
//            
//        case .poll:
//            Section("Poll Question") {
//                TextField("Question", text: $pollQuestion)
//            }
//            Section("Options") {
//                TextField("Option 1", text: $pollOption1)
//                TextField("Option 2", text: $pollOption2)
//            }
//            
//        case .predictionTarget:
//            Section("Target Price") {
//                TextField("Enter target price", text: $targetPrice)
//                    .keyboardType(.decimalPad)
//                Text("A horizontal line will be drawn at the target price")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        
//        // FIXED: Explicit handling for markers that show horizontal lines
//        case .entry:
//            Section("Entry Details") {
//                HStack {
//                    Text("Entry Price")
//                    Spacer()
//                    Text(chartData.formatPrice(price))
//                        .foregroundColor(.green)
//                        .fontWeight(.semibold)
//                }
//                Text("A horizontal line will be drawn at the candle close price")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//        case .exit:
//            Section("Exit Details") {
//                HStack {
//                    Text("Exit Price")
//                    Spacer()
//                    Text(chartData.formatPrice(price))
//                        .foregroundColor(.orange)
//                        .fontWeight(.semibold)
//                }
//                Text("A horizontal line will be drawn at the candle close price")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//        case .stopLoss:
//            Section("Stop Loss Details") {
//                HStack {
//                    Text("Stop Loss Price")
//                    Spacer()
//                    Text(chartData.formatPrice(price))
//                        .foregroundColor(.red)
//                        .fontWeight(.semibold)
//                }
//                Text("A horizontal line will be drawn at this price level")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//        case .takeProfit:
//            Section("Take Profit Details") {
//                HStack {
//                    Text("Take Profit Price")
//                    Spacer()
//                    Text(chartData.formatPrice(price))
//                        .foregroundColor(.blue)
//                        .fontWeight(.semibold)
//                }
//                Text("A horizontal line will be drawn at this price level")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//        case .support:
//            Section("Support Level") {
//                HStack {
//                    Text("Support Price")
//                    Spacer()
//                    if candleIndex >= 0 && candleIndex < candles.count {
//                        Text(chartData.formatPrice(candles[candleIndex].low))
//                            .foregroundColor(.purple)
//                            .fontWeight(.semibold)
//                    }
//                }
//                Text("A horizontal line will be drawn at the candle low")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//        case .resistance:
//            Section("Resistance Level") {
//                HStack {
//                    Text("Resistance Price")
//                    Spacer()
//                    if candleIndex >= 0 && candleIndex < candles.count {
//                        Text(chartData.formatPrice(candles[candleIndex].high))
//                            .foregroundColor(.pink)
//                            .fontWeight(.semibold)
//                    }
//                }
//                Text("A horizontal line will be drawn at the candle high")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        
//        // Simple markers that just need notes
//        case .note, .question, .volumeSpike, .personal:
//            EmptyView()  // These just use the standard Note section
//        }
//    }
//    
//    private func addMarker() {
//        print("📝 === MARKER CREATION SHEET - ADD MARKER ===")
//        print("📝 Marker Type: \(markerType)")
//        print("📝 Candle Index: \(candleIndex)")
//        print("📝 Price: \(price)")
//        print("📝 Timestamp: \(timestamp)")
//        print("📝 Note: \(note.isEmpty ? "(empty)" : note)")
//        print("📝 Target Price String: '\(targetPrice)'")
//        
//        var pollOptions: [PollOption]? = nil
//        if markerType == .poll && !pollOption1.isEmpty {
//            pollOptions = [
//                PollOption(text: pollOption1),
//                PollOption(text: pollOption2.isEmpty ? "Option 2" : pollOption2)
//            ]
//            print("📝 Poll Options: \(pollOptions!.count) options")
//        }
//        
//        let target = Double(targetPrice)
//        print("📝 Parsed Target Price: \(String(describing: target))")
//        
//        if markerType == .predictionTarget && target == nil {
//            print("📝 ⚠️ WARNING: Prediction marker without target price!")
//        }
//        
//        print("📝 Calling markerManager.addMarker...")
//        let success = markerManager.addMarker(
//            candleIndex: candleIndex,
//            timestamp: timestamp,
//            price: price,
//            type: markerType,
//            username: username,
//            note: note.isEmpty ? nil : note,
//            candles: candles,
//            targetPrice: target,
//            alertSeverity: markerType == .alert ? alertSeverity : nil,
//            trendlineDirection: markerType == .trendline ? trendlineDirection : nil,
//            selectedIndicator: markerType == .indicator ? selectedIndicator : nil,
//            chartPattern: markerType == .pattern ? chartPattern : nil,
//            selectedEmoji: markerType == .emoji ? selectedEmoji : nil,
//            pollQuestion: markerType == .poll ? pollQuestion : nil,
//            pollOptions: pollOptions
//        )
//        
//        if success {
//            print("📝 ✅ Marker added successfully!")
//            dismiss()
//        } else {
//            print("📝 ❌ Failed to add marker (duplicate detected)")
//            // Note: duplicate alert is shown by MarkerManager
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
//    @State private var newComment: String = ""
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
//                // Type-specific info
//                typeSpecificInfo
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
//                // Comments section
//                Section("Comments") {
//                    ForEach(marker.comments) { comment in
//                        VStack(alignment: .leading, spacing: 4) {
//                            HStack {
//                                Text(comment.username)
//                                    .font(.caption)
//                                    .fontWeight(.semibold)
//                                Spacer()
//                                Text(comment.createdAt, style: .relative)
//                                    .font(.caption2)
//                                    .foregroundColor(.secondary)
//                            }
//                            Text(comment.text)
//                                .font(.subheadline)
//                        }
//                        .padding(.vertical, 4)
//                    }
//                    
//                    HStack {
//                        TextField("Add comment...", text: $newComment)
//                        Button {
//                            guard !newComment.isEmpty else { return }
//                            markerManager.addComment(markerId: marker.id, text: newComment, username: "You")
//                            newComment = ""
//                        } label: {
//                            Image(systemName: "arrow.up.circle.fill")
//                                .foregroundColor(.blue)
//                        }
//                    }
//                }
//                
//                // Share/Save/Report buttons
//                Section {
//                    Button {
//                        // Share action
//                    } label: {
//                        Label("Share", systemImage: "square.and.arrow.up")
//                    }
//                    
//                    Button {
//                        // Save action
//                    } label: {
//                        Label("Save", systemImage: "bookmark")
//                    }
//                    
//                    Button(role: .destructive) {
//                        // Report action
//                    } label: {
//                        Label("Report", systemImage: "flag")
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
//        .presentationDetents([.fraction(0.25), .medium, .large])
//        .presentationDragIndicator(.visible)
//        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.25)))
//        .onAppear {
//            editedNote = marker.note ?? ""
//        }
//    }
//    
//    @ViewBuilder
//    private var typeSpecificInfo: some View {
//        switch marker.type {
//        case .alert:
//            if let severity = marker.alertSeverity {
//                Section("Alert Details") {
//                    HStack {
//                        Circle()
//                            .fill(severity.color)
//                            .frame(width: 12, height: 12)
//                        Text(severity.rawValue)
//                    }
//                }
//            }
//            
//        case .trendline:
//            if let direction = marker.trendlineDirection {
//                Section("Trendline Direction") {
//                    Text(direction.rawValue)
//                }
//            }
//            
//        case .indicator:
//            if let indicator = marker.selectedIndicator {
//                Section("Indicator") {
//                    Text(indicator)
//                }
//            }
//            
//        case .pattern:
//            if let pattern = marker.chartPattern {
//                Section("Chart Pattern") {
//                    Text(pattern.rawValue)
//                }
//            }
//            
//        case .predictionTarget:
//            if let target = marker.targetPrice {
//                Section("Prediction") {
//                    HStack {
//                        Text("Target Price")
//                        Spacer()
//                        Text(chartData.formatPrice(target))
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            
//        case .poll:
//            if let question = marker.pollQuestion, let options = marker.pollOptions {
//                Section("Poll: \(question)") {
//                    ForEach(options) { option in
//                        HStack {
//                            Text(option.text)
//                            Spacer()
//                            Text("\(option.voteCount)")
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//            }
//            
//        default:
//            EmptyView()
//        }
//    }
//}
//
//// MARK: - Temporary Marker Placement Indicator
//
///// Shows a temporary price line indicator while placing a marker
///// Matches the style of PriceIndicatorView for consistency
//struct MarkerPlacementPriceIndicator: View {
//    let price: Double
//    let markerType: MarkerType
//    let priceScale: CGFloat
//    let verticalOffset: CGFloat
//    let chartHeight: CGFloat
//    let priceRange: (min: Double, max: Double)
//    let chartData: ChartDataManager
//    
//    private var indicatorYPosition: CGFloat {
//        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
//        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
//    }
//    
//    private var isVisible: Bool {
//        indicatorYPosition >= 0 && indicatorYPosition <= chartHeight
//    }
//    
//    private var formattedPrice: String {
//        chartData.formatPrice(price)
//    }
//    
//    var body: some View {
//        GeometryReader { geometry in
//            if isVisible && price > 0 {
//                Canvas { context, size in
//                    let y = indicatorYPosition
//                    let lineEndX = size.width - 60
//                    
//                    // Draw horizontal dashed line
//                    let linePath = Path { path in
//                        path.move(to: CGPoint(x: 0, y: y))
//                        path.addLine(to: CGPoint(x: lineEndX, y: y))
//                    }
//                    context.stroke(
//                        linePath,
//                        with: .color(markerType.color.opacity(0.7)),
//                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
//                    )
//                    
//                    // Draw price label background (colored by marker type)
//                    let labelX = size.width - 35
//                    let labelRect = CGRect(
//                        x: labelX - 35,
//                        y: y - 11,
//                        width: 70,
//                        height: 22
//                    )
//                    let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
//                    context.fill(roundedPath, with: .color(markerType.color))
//                    
//                    // Draw price text
//                    let text = Text(formattedPrice)
//                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                        .foregroundColor(.white)
//                    
//                    context.draw(text, at: CGPoint(x: labelX, y: y))
//                }
//            }
//        }
//        .allowsHitTesting(false)
//    }
//}
//
//
//
//
//
