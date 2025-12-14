//
//  ChartMarkerSystem.swift
//  traders_guild
//
// TODO: - add app state here for real guildid and user id for api

import SwiftUI

// MARK: - Marker Manager

class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarker] = []
    @Published var selectedMarker: ChartMarker?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    @Published var markersHidden: Bool = false  // Toggle to hide all markers
    
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
        // If markers are hidden globally, return empty array
        if markersHidden { return [] }
        
        return markers.filter { marker in
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
    
    /// Distance from candle high/low to marker center (user adjustable)
    @Published var baseOffset: CGFloat {
        didSet { UserDefaults.standard.set(baseOffset, forKey: "markerBaseOffset") }
    }
    
    /// Distance between stacked markers
    @Published var stackOffset: CGFloat {
        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
    }
    
    /// Minimum stack spacing regardless of scale (prevents overlap)
    @Published var minStackSpacing: CGFloat {
        didSet { UserDefaults.standard.set(minStackSpacing, forKey: "markerMinStackSpacing") }
    }
    
    @Published var proximityTierOffset: CGFloat {
        didSet { UserDefaults.standard.set(proximityTierOffset, forKey: "markerProximityTierOffset") }
    }
    
    @Published var placementExtraOffset: CGFloat {
        didSet { UserDefaults.standard.set(placementExtraOffset, forKey: "markerPlacementExtraOffset") }
    }
    
    private init() {
        // Distance from candle to marker (user adjustable in settings)
        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 70
        // Stack spacing between markers (marker diameter is 32px)
        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 36
        // Minimum stack spacing to prevent overlap at any scale (must be > marker diameter of 32)
        self.minStackSpacing = UserDefaults.standard.object(forKey: "markerMinStackSpacing") as? CGFloat ?? 34
        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 25
        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 40
    }
    
    func resetToDefaults() {
        baseOffset = 70
        stackOffset = 36
        minStackSpacing = 34
        proximityTierOffset = 25
        placementExtraOffset = 40
    }
}

// MARK: - Marker Position Calculator

struct MarkerPositionCalculator {
    
    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
    static var baseOffset: CGFloat { settings.baseOffset }
    static var stackOffset: CGFloat { settings.stackOffset }
    static var minStackSpacing: CGFloat { settings.minStackSpacing }
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
        
        // Apply dampening to priceScale to make scaling less extreme
        // Base offset follows the candle more closely
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        
        // Stack offset scales but has a MINIMUM to prevent overlap
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        // Ensure stack spacing never goes below minimum
        let scaledStackOffset = Swift.max(minStackSpacing, scaledStackOffsetRaw)
        
        let scaledBaseOffset = baseOffset * dampenedBaseScale
        let scaledTierOffset = offsetForTier(marker.proximityTier) * dampenedBaseScale
        
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
    /// Uses the same positioning logic as actual marker placement
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
        
        // Apply dampening with minimum floor for stack offset
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledPlacementOffset = placementOffset * dampenedBaseScale
        
        // Stack offset scales but has a MINIMUM to prevent overlap
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        let scaledStackOffset = Swift.max(minStackSpacing, scaledStackOffsetRaw)
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            // RULE 1: Has existing markers - place on SAME side as existing ones
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
            // No existing markers on this candle - use the same logic as new marker placement
            shouldBeBelow = determineSideForNewMarker(
                candleIndex: candleIndex,
                existingMarkers: existingMarkers,
                candles: candles
            )
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
    
    /// Proximity range for determining if markers are "close" to each other
    /// Used to decide if a marker should flip to opposite side
    private static let closeProximityRange = 2  // 1-2 candles away
    
    static func assignStablePositions(
        markers: [ChartMarker],
        candles: [Candle]
    ) -> [ChartMarker] {
        var result = markers
        
        let grouped = Dictionary(grouping: result) { $0.candleIndex }
        let sortedIndices = grouped.keys.sorted()
        
        var usedAboveTiers: [Int: Set<Int>] = [:]
        var usedBelowTiers: [Int: Set<Int>] = [:]
        
        // Track which side each candle's markers are on (for proximity checks)
        var candleSideDecisions: [Int: Bool] = [:]  // candleIndex -> isBelow
        
        for candleIndex in sortedIndices {
            guard let markersAtCandle = grouped[candleIndex] else { continue }
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            // FIXED: Calculate the tier ONCE per candle, not per marker
            // All markers on the same candle share the same tier but have different stack indices
            
            // Determine which side this candle's markers should be on
            let shouldBeBelow = determineSideForCandle(
                candleIndex: candleIndex,
                candles: candles,
                existingDecisions: candleSideDecisions
            )
            
            // Record this decision for proximity checks on subsequent candles
            candleSideDecisions[candleIndex] = shouldBeBelow
            
            // Calculate tier ONCE for this candle (all markers share it)
            let tier: Int
            if shouldBeBelow {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedBelowTiers)
            } else {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedAboveTiers)
            }
            
            // Assign positions to all markers on this candle
            for (stackIndex, marker) in sorted.enumerated() {
                guard let resultIndex = result.firstIndex(where: { $0.id == marker.id }) else { continue }
                
                result[resultIndex].positionedBelow = shouldBeBelow
                result[resultIndex].proximityTier = tier
                result[resultIndex].stackIndex = stackIndex
            }
        }
        
        return result
    }
    
    /// Determines which side (above/below) markers on a candle should be placed
    /// Priority order:
    /// 1. If 1-2 candles away from a marker on the same side, flip to opposite side
    /// 2. EMA trend: If EMA2 > EMA10, uptrend -> place above; else downtrend -> place below
    /// 3. Default to above
    private static func determineSideForCandle(
        candleIndex: Int,
        candles: [Candle],
        existingDecisions: [Int: Bool]
    ) -> Bool {
        // Check for close proximity markers (1-2 candles away)
        // If there's a marker nearby on above, we should go below (and vice versa)
        var hasCloseMarkerAbove = false
        var hasCloseMarkerBelow = false
        
        for delta in 1...closeProximityRange {
            // Check left neighbor
            if let leftDecision = existingDecisions[candleIndex - delta] {
                if leftDecision {
                    hasCloseMarkerBelow = true
                } else {
                    hasCloseMarkerAbove = true
                }
            }
            // Note: We don't check right neighbors since we process left-to-right
            // and haven't decided on those yet
        }
        
        // Priority 1: Flip if there's a close marker on one side
        if hasCloseMarkerAbove && !hasCloseMarkerBelow {
            return true  // Go below
        } else if hasCloseMarkerBelow && !hasCloseMarkerAbove {
            return false  // Go above
        }
        
        // Priority 2: EMA trend-based placement
        // If EMA2 > EMA10 (uptrend), place above; else (downtrend) place below
        if let emaTrend = calculateEMATrend(candleIndex: candleIndex, candles: candles) {
            return !emaTrend  // emaTrend true = uptrend = above (false), downtrend = below (true)
        }
        
        // Priority 3: Default to above
        return false
    }
    
    // MARK: - EMA Trend Calculation
    
    /// Calculate whether EMA2 > EMA10 at a given candle index
    /// Returns true if uptrend (EMA2 > EMA10), false if downtrend, nil if not enough data
    private static func calculateEMATrend(candleIndex: Int, candles: [Candle]) -> Bool? {
        // Need at least 10 candles to calculate EMA10
        guard candleIndex >= 9 && candleIndex < candles.count else { return nil }
        
        // Calculate EMA2 and EMA10 at this candle
        let ema2 = calculateEMAAtIndex(candles: candles, period: 2, atIndex: candleIndex)
        let ema10 = calculateEMAAtIndex(candles: candles, period: 10, atIndex: candleIndex)
        
        guard let e2 = ema2, let e10 = ema10 else { return nil }
        
        // Uptrend if EMA2 > EMA10
        return e2 > e10
    }
    
    /// Calculate EMA value at a specific candle index
    /// Uses close prices and standard EMA formula
    private static func calculateEMAAtIndex(candles: [Candle], period: Int, atIndex: Int) -> Double? {
        guard atIndex >= period - 1 && atIndex < candles.count && period > 0 else { return nil }
        
        let multiplier = 2.0 / Double(period + 1)
        
        // Calculate initial SMA as seed using the first 'period' candles up to atIndex
        let smaEndIndex = period - 1
        guard smaEndIndex <= atIndex else { return nil }
        
        var sum: Double = 0
        for i in 0...smaEndIndex {
            sum += candles[i].close
        }
        var ema = sum / Double(period)
        
        // Apply EMA formula for remaining candles from period to atIndex
        if period <= atIndex {
            for i in period...atIndex {
                let price = candles[i].close
                ema = (price - ema) * multiplier + ema
            }
        }
        
        return ema
    }
    
    static func calculatePositionForNewMarker(
        marker: ChartMarker,
        existingMarkers: [ChartMarker],
        candles: [Candle]
    ) -> (isBelow: Bool, tier: Int, stackIndex: Int) {
        let candleIndex = marker.candleIndex
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            // RULE 1: If there's a stack, join it on the same side
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
            // No existing markers on this candle - determine side based on proximity and candle shape
            shouldBeBelow = determineSideForNewMarker(
                candleIndex: candleIndex,
                existingMarkers: existingMarkers,
                candles: candles
            )
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
    
    /// Determines which side a new marker should be placed on when there's no existing stack
    /// Priority order:
    /// 1. If 1-2 candles away from a marker on the same side, flip to opposite side
    /// 2. If one side is very crowded nearby (3+ more markers), use the other side
    /// 3. EMA trend: If EMA2 > EMA5, uptrend -> place above; else downtrend -> place below
    /// 4. Default to above
    private static func determineSideForNewMarker(
        candleIndex: Int,
        existingMarkers: [ChartMarker],
        candles: [Candle]
    ) -> Bool {
        // Check for close proximity markers (1-2 candles away)
        let closeMarkers = existingMarkers.filter {
            abs($0.candleIndex - candleIndex) <= closeProximityRange
        }
        
        let closeMarkersAbove = closeMarkers.filter { !$0.positionedBelow }
        let closeMarkersBelow = closeMarkers.filter { $0.positionedBelow }
        
        // RULE 1: If there's a close marker on one side, flip to opposite
        if !closeMarkersAbove.isEmpty && closeMarkersBelow.isEmpty {
            return true  // Go below
        } else if !closeMarkersBelow.isEmpty && closeMarkersAbove.isEmpty {
            return false  // Go above
        }
        
        // RULE 2: Check nearby marker density (wider range)
        let nearbyMarkers = existingMarkers.filter {
            abs($0.candleIndex - candleIndex) <= proximityRange
        }
        let neighborsAbove = nearbyMarkers.filter { !$0.positionedBelow }.count
        let neighborsBelow = nearbyMarkers.filter { $0.positionedBelow }.count
        
        if neighborsAbove > neighborsBelow + 3 {
            return true  // Above is crowded, go below
        }
        
        // RULE 3: EMA trend-based placement
        // If EMA2 > EMA5 (uptrend), place above; else (downtrend) place below
        if let emaTrend = calculateEMATrend(candleIndex: candleIndex, candles: candles) {
            return !emaTrend  // emaTrend true = uptrend = above (false), downtrend = below (true)
        }
        
        // RULE 4: Default to above
        return false
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
                with: .color(.tgMidGrey.opacity(0.6)),
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
        let baseRadius: CGFloat = 16
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
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color.opacity(0.3)), lineWidth: borderWidth * scale)
        
        // Inner colored circle
        let iconRadius: CGFloat = 11 * scale
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
                .font(.system(size: 13 * scale, weight: .heavy))
                .foregroundColor(.white.opacity(0.8)),
            at: position
        )
        
        
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = (scaledRadius - 13)
            let likeCircleRect = CGRect(
                x: position.x + 5,
                y: position.y + badgeOffset,
                width: 14,
                height: 14
            )
            context.fill(Path(ellipseIn: likeCircleRect), with: .color(.tgBear.opacity(0.8)))
            context.stroke(Path(ellipseIn: likeCircleRect), with: .color(.black), lineWidth: 1)
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 12, y: position.y + badgeOffset + 7)
            )
        }

        
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
    let initialTargetPrice: Double?
    
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
        VStack(spacing: 0) {
            // Custom Header
            headerView
            
            Divider()
            
            // Form Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Context Info Card
                    contextInfoCard
                    
                    // Type-specific options
                    typeSpecificOptionsView
                    
                    // Note Section
                    noteSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            
            Divider()
            
            // Action Buttons
            actionButtons
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .interactiveDismissDisabled(true)
        .onAppear {
            // Initialize target price for prediction markers
            if let initialTarget = initialTargetPrice {
                targetPrice = chartData.formatPrice(initialTarget)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 15) {
            // Marker Icon
            ZStack {
                Circle()
                    .fill(markerType.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: markerType.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(markerType.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Add \(markerType.rawValue)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text("Configure marker details")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Context Info Card
    
    private var contextInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Marker Context")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Time")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(timestamp.chartTimeLabel)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                }
                
                HStack {
                    Text("Price")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(chartData.formatPrice(price))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(markerType.color)
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.2))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Type-Specific Options
    
    @ViewBuilder
    private var typeSpecificOptionsView: some View {
        switch markerType {
        case .alert:
            alertOptionsCard
        case .trendline:
            trendlineOptionsCard
        case .indicator:
            indicatorOptionsCard
        case .pattern:
            patternOptionsCard
        case .emoji:
            emojiOptionsCard
        case .poll:
            pollOptionsCard
        case .predictionTarget:
            predictionOptionsCard
        case .entry:
            entryDetailsCard
        case .exit:
            exitDetailsCard
        case .stopLoss:
            stopLossDetailsCard
        case .takeProfit:
            takeProfitDetailsCard
        case .support:
            supportDetailsCard
        case .resistance:
            resistanceDetailsCard
        case .note, .question, .volumeSpike, .personal:
            EmptyView()
        }
    }
    
    // MARK: - Alert Options
    
    private var alertOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Alert Severity")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(MarkerAlertSeverity.allCases, id: \.self) { severity in
                    Button(action: {
                        alertSeverity = severity
                        HapticFeedback.light.trigger()
                    }) {
                        HStack {
                            Circle()
                                .fill(severity.color)
                                .frame(width: 12, height: 12)
                            Text(severity.rawValue)
                                .font(.subheadline)
                                .foregroundColor(AppColors.whiteText)
                            Spacer()
                            if alertSeverity == severity {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            alertSeverity == severity ?
                            AppColors.gradientBackgroundDark.opacity(0.3) :
                            Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Trendline Options
    
    private var trendlineOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Trend Direction")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(TrendlineDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        trendlineDirection = direction
                        HapticFeedback.light.trigger()
                    }) {
                        Text(direction.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(trendlineDirection == direction ? .white : AppColors.greyText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                trendlineDirection == direction ?
                                AppColors.accentColor :
                                AppColors.gradientBackgroundDark.opacity(0.2)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Indicator Options
    
    private var indicatorOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Select Indicator")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            Picker("Indicator", selection: $selectedIndicator) {
                Text("RSI").tag("RSI")
                Text("MACD").tag("MACD")
                Text("Moving Average").tag("MA")
                Text("Bollinger Bands").tag("BB")
                Text("Stochastic").tag("STOCH")
                Text("ATR").tag("ATR")
            }
            .pickerStyle(.menu)
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Pattern Options
    
    private var patternOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "circle.hexagongrid.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Chart Pattern")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            Picker("Pattern", selection: $chartPattern) {
                ForEach(ChartPattern.allCases, id: \.self) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Emoji Options
    
    private var emojiOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "face.smiling")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Select Emoji")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(["🎯", "🚀", "💰", "⚠️", "📈", "📉", "💎", "🔥", "⭐", "💡", "🤔", "👀"], id: \.self) { emoji in
                    Button(action: {
                        selectedEmoji = emoji
                        HapticFeedback.light.trigger()
                    }) {
                        Text(emoji)
                            .font(.title)
                            .frame(width: 50, height: 50)
                            .background(
                                selectedEmoji == emoji ?
                                AppColors.accentColor.opacity(0.3) :
                                AppColors.gradientBackgroundDark.opacity(0.2)
                            )
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Poll Options
    
    private var pollOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "newspaper.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Poll Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 12) {
                TextField("Poll question", text: $pollQuestion)
                    .font(.subheadline)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(8)
                
                TextField("Option 1", text: $pollOption1)
                    .font(.subheadline)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(8)
                
                TextField("Option 2", text: $pollOption2)
                    .font(.subheadline)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Prediction Options
    
    private var predictionOptionsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "staroflife.circle")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Target Price")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 8) {
                TextField("Enter target price", text: $targetPrice)
                    .font(.subheadline)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(8)
                
                Text("A horizontal line will be drawn at the target price")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Entry/Exit/Stop Loss/Take Profit Details
    
    private var entryDetailsCard: some View {
        priceDetailsCard(
            title: "Entry Details",
            icon: "arrow.up.circle",
            priceLabel: "Entry Price",
            priceValue: price,
            priceColor: .green,
            description: "A horizontal line will be drawn at the candle close price"
        )
    }
    
    private var exitDetailsCard: some View {
        priceDetailsCard(
            title: "Exit Details",
            icon: "arrow.down.circle",
            priceLabel: "Exit Price",
            priceValue: price,
            priceColor: .orange,
            description: "A horizontal line will be drawn at the candle close price"
        )
    }
    
    private var stopLossDetailsCard: some View {
        priceDetailsCard(
            title: "Stop Loss Details",
            icon: "xmark.shield",
            priceLabel: "Stop Loss Price",
            priceValue: price,
            priceColor: .red,
            description: "A horizontal line will be drawn at this price level"
        )
    }
    
    private var takeProfitDetailsCard: some View {
        priceDetailsCard(
            title: "Take Profit Details",
            icon: "checkmark.shield",
            priceLabel: "Take Profit Price",
            priceValue: price,
            priceColor: .blue,
            description: "A horizontal line will be drawn at this price level"
        )
    }
    
    @ViewBuilder
    private var supportDetailsCard: some View {
        if candleIndex >= 0 && candleIndex < candles.count {
            priceDetailsCard(
                title: "Support Level",
                icon: "s.circle",
                priceLabel: "Support Price",
                priceValue: candles[candleIndex].low,
                priceColor: .purple,
                description: "A horizontal line will be drawn at the candle low"
            )
        }
    }
    
    @ViewBuilder
    private var resistanceDetailsCard: some View {
        if candleIndex >= 0 && candleIndex < candles.count {
            priceDetailsCard(
                title: "Resistance Level",
                icon: "r.circle",
                priceLabel: "Resistance Price",
                priceValue: candles[candleIndex].high,
                priceColor: .pink,
                description: "A horizontal line will be drawn at the candle high"
            )
        }
    }
    
    private func priceDetailsCard(title: String, icon: String, priceLabel: String, priceValue: Double, priceColor: Color, description: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text(priceLabel)
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    Text(chartData.formatPrice(priceValue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(priceColor)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.2))
                .cornerRadius(8)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Note Section
    
    private var noteSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentColor)
                Text("Add Note (Optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
            }
            
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Add additional context or analysis...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }
                
                TextEditor(text: $note)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
            }
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.gradientBackgroundDark.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.3), lineWidth: 0.5)
                    )
                    .cornerRadius(10)
            }
            
            Button(action: addMarker) {
                Text("Add Marker")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.accentColor)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.sheetBackground)
    }
    
    // MARK: - Add Marker Action
    
    private func addMarker() {
        var pollOptions: [PollOption]? = nil
        if markerType == .poll && !pollOption1.isEmpty {
            pollOptions = [
                PollOption(text: pollOption1),
                PollOption(text: pollOption2.isEmpty ? "Option 2" : pollOption2)
            ]
        }
        
        let target = Double(targetPrice)
        
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
            HapticFeedback.success.trigger()
            dismiss()
        } else {
            HapticFeedback.warning.trigger()
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

// MARK: - Marker Settings View (User-Adjustable Distance)

struct MarkerSettingsView: View {
    @ObservedObject var settings = MarkerDisplaySettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Marker Distance")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Distance from Candle")
                            Spacer()
                            Text("\(Int(settings.baseOffset)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(
                            value: $settings.baseOffset,
                            in: 40...120,
                            step: 5
                        )
                        .tint(.cyan)
                        
                        Text("How far markers appear from candle high/low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Stack Spacing")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Space Between Stacked Markers")
                            Spacer()
                            Text("\(Int(settings.stackOffset)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(
                            value: $settings.stackOffset,
                            in: 34...60,
                            step: 2
                        )
                        .tint(.cyan)
                        
                        Text("Vertical spacing when multiple markers on same candle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Stack Spacing")
                            Spacer()
                            Text("\(Int(settings.minStackSpacing)) pts")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Slider(
                            value: $settings.minStackSpacing,
                            in: 32...50,
                            step: 2
                        )
                        .tint(.orange)
                        
                        Text("Prevents overlap when chart is zoomed out vertically")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(action: {
                        settings.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Marker Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Marker Settings Button (for Chart Controls)

struct MarkerSettingsButton: View {
    @State private var showSettings = false
    
    var body: some View {
        Button(action: {
            showSettings = true
        }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .sheet(isPresented: $showSettings) {
            MarkerSettingsView()
                .presentationDetents([.medium])
        }
    }
}









