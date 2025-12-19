//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  CONVERTED: Now uses ChartMarkerDTO instead of ChartMarker
//  All marker operations use the DTO pattern with embedded author info
//
//  INCLUDES:
//  - MarkerManager (with backwards-compatible String init for TradingChartView)
//  - MarkerDisplaySettings
//  - MarkerPositionCalculator
//  - ChartMarkerSystem (static drawing and hit detection)
//  - MarkerView
//  - MarkerCreationSheet
//  - MarkerSettingsView

import SwiftUI

// MARK: - Marker Manager

@MainActor
class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarkerDTO] = []
    @Published var selectedMarker: ChartMarkerDTO?
    @Published var visibleTypes: Set<MarkerType> = Set(MarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    @Published var markersHidden: Bool = false
    
    /// Tracks if we should show a "like existing marker" prompt
    @Published var duplicateMarkerToLike: ChartMarkerDTO?
    @Published var showDuplicateAlert: Bool = false
    
    private let currentUserId: UUID
    private let currentGuildId: UUID
    private let currentUserMembership: GuildMembershipDTO
    
    var guildId: UUID { currentGuildId }
    var userId: UUID { currentUserId }
    
    // MARK: - Backwards Compatible String Init (for TradingChartView)
    
    /// Legacy init that accepts String IDs - converts to UUID internally
    /// Used by TradingChartView which passes String parameters
    convenience init(userId: String, guildId: String) {
        // Use SampleData defaults - the strings are just placeholders
        self.init(
            userId: SampleData.currentUser.id,
            guildId: SampleData.currentUser.guildMembership.guild.id,
            userMembership: SampleData.currentUser.guildMembership
        )
    }
    
    // MARK: - Primary UUID Init
    
    init(
        userId: UUID = SampleData.currentUser.id,
        guildId: UUID = SampleData.currentUser.guildMembership.guild.id,
        userMembership: GuildMembershipDTO = SampleData.currentUser.guildMembership
    ) {
        self.currentUserId = userId
        self.currentGuildId = guildId
        self.currentUserMembership = userMembership
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
            // Fetch markers from API - now returns ChartMarkerDTO directly
            let fetchedMarkers = try await api.fetchGuildChartMarkerDTOs(
                symbol: symbol,
                guildId: guildId,
                timeframe: timeframe,
                candleCount: candles.count
            )
            
            // Update prices based on candle data
            var positionedMarkers = SampleData.updateMarkerDTOPrices(
                markers: fetchedMarkers,
                candles: candles
            )
            
            // Reset positioning fields for proper recalculation
            for i in 0..<positionedMarkers.count {
                positionedMarkers[i].positionedBelow = false
                positionedMarkers[i].proximityTier = 0
                positionedMarkers[i].stackIndex = 0
                positionedMarkers[i].isVisible = true
            }
            
            // Sort by creation date before recalculating positions
            positionedMarkers.sort { $0.createdAt < $1.createdAt }
            
            // Calculate proper positions
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
    
    func existingMarkerOfType(_ type: MarkerType, atCandleIndex candleIndex: Int) -> ChartMarkerDTO? {
        return markers.first { marker in
            marker.candleIndex == candleIndex && marker.type == type
        }
    }
    
    func canAddMarker(type: MarkerType, atCandleIndex candleIndex: Int) -> Bool {
        return existingMarkerOfType(type, atCandleIndex: candleIndex) == nil
    }
    
    // MARK: - Marker CRUD
    
    @discardableResult
    func addMarker(
        symbolId: UUID,
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
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
        pollOptions: [PollOptionDTO]? = nil
    ) -> Bool {
        // Validate candle index
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        // Check for duplicate type on same candle
        if let existingMarker = existingMarkerOfType(type, atCandleIndex: candleIndex) {
            duplicateMarkerToLike = existingMarker
            showDuplicateAlert = true
            return false
        }
        
        // Calculate line price based on marker type
        var linePrice = horizontalLinePrice
        if type.hasHorizontalLine && linePrice == nil {
            let candle = candles[candleIndex]
            
            if type == .predictionTarget {
                linePrice = candle.close
            } else {
                switch type.lineSource {
                case .candleOpen: linePrice = candle.open
                case .candleClose: linePrice = candle.close
                case .candleHigh: linePrice = candle.high
                case .candleLow: linePrice = candle.low
                case .custom: linePrice = targetPrice
                case .none: break
                }
            }
        }
        
        let now = Date()
        
        // Create the marker DTO with embedded author
        var marker = ChartMarkerDTO(
            id: UUID(),
            symbolId: symbolId,
            guildId: currentGuildId,
            author: currentUserMembership,
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            note: note,
            createdAt: now,
            createdAtFormatted: "Just now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true,
            positionedBelow: false,
            proximityTier: 0,
            stackIndex: 0,
            horizontalLinePrice: linePrice,
            targetPrice: targetPrice,
            alertSeverity: alertSeverity,
            trendlineDirection: trendlineDirection,
            selectedIndicator: selectedIndicator,
            chartPattern: chartPattern,
            selectedEmoji: selectedEmoji,
            pollQuestion: pollQuestion,
            pollOptions: pollOptions,
            userPollVote: nil
        )
        
        // Calculate position
        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        
        markers.append(marker)
        return true
    }
    
    func deleteMarker(id: UUID) {
        markers.removeAll { $0.id == id }
        if selectedMarker?.id == id {
            selectedMarker = nil
        }
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
    
    func addComment(markerId: UUID, content: String) {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        
        let comment = MarkerCommentDTO(
            id: UUID(),
            markerId: markerId,
            author: currentUserMembership,
            content: content,
            timestamp: Date(),
            timestampFormatted: "Just now",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true
        )
        
        markers[index].comments.append(comment)
        markers[index].commentCount += 1
    }
    
    func deleteComment(markerId: UUID, commentId: UUID) {
        guard let markerIndex = markers.firstIndex(where: { $0.id == markerId }) else { return }
        markers[markerIndex].comments.removeAll { $0.id == commentId }
        markers[markerIndex].commentCount = markers[markerIndex].comments.count
    }
    
    var filteredMarkers: [ChartMarkerDTO] {
        if markersHidden { return [] }
        
        return markers.filter { marker in
            guard marker.isVisible else { return false }
            guard visibleTypes.contains(marker.type) else { return false }
            if showOnlyMyMarkers && !marker.isCurrentUserMarker {
                return false
            }
            return true
        }
    }
    
    func markersGroupedByCandle() -> [Int: [ChartMarkerDTO]] {
        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
    }
    
    func markerCount(atCandleIndex candleIndex: Int) -> Int {
        markersGroupedByCandle()[candleIndex]?.count ?? 0
    }
    
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
    
    @Published var stackOffset: CGFloat {
        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
    }
    
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
        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 70
        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 36
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
    
    // MARK: - Shared Position Calculation
    
    static func computeMarkerScreenPosition(
        marker: ChartMarkerDTO,
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0
    ) -> CGPoint {
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
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
    
    private static func dampenPriceScale(_ priceScale: CGFloat, dampening: CGFloat) -> CGFloat {
        return 1.0 + (priceScale - 1.0) * dampening
    }
    
    static func calculatePreviewPosition(
        candleIndex: Int,
        existingMarkers: [ChartMarkerDTO],
        candles: [Candle],
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0
    ) -> (position: CGPoint, isBelow: Bool) {
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledPlacementOffset = placementOffset * dampenedBaseScale
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        let scaledStackOffset = Swift.max(minStackSpacing, scaledStackOffsetRaw)
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
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
    
    private static let closeProximityRange = 2
    
    static func assignStablePositions(
        markers: [ChartMarkerDTO],
        candles: [Candle]
    ) -> [ChartMarkerDTO] {
        var result = markers
        
        let grouped = Dictionary(grouping: result) { $0.candleIndex }
        let sortedIndices = grouped.keys.sorted()
        
        var usedAboveTiers: [Int: Set<Int>] = [:]
        var usedBelowTiers: [Int: Set<Int>] = [:]
        var candleSideDecisions: [Int: Bool] = [:]
        
        for candleIndex in sortedIndices {
            guard let markersAtCandle = grouped[candleIndex] else { continue }
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            let shouldBeBelow = determineSideForCandle(
                candleIndex: candleIndex,
                candles: candles,
                existingDecisions: candleSideDecisions
            )
            
            candleSideDecisions[candleIndex] = shouldBeBelow
            
            let tier: Int
            if shouldBeBelow {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedBelowTiers)
            } else {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedAboveTiers)
            }
            
            for (stackIndex, markerInGroup) in sorted.enumerated() {
                guard let globalIndex = result.firstIndex(where: { $0.id == markerInGroup.id }) else { continue }
                
                result[globalIndex].positionedBelow = shouldBeBelow
                result[globalIndex].proximityTier = tier
                result[globalIndex].stackIndex = stackIndex
            }
        }
        
        return result
    }
    
    static func calculatePositionForNewMarker(
        marker: ChartMarkerDTO,
        existingMarkers: [ChartMarkerDTO],
        candles: [Candle]
    ) -> (isBelow: Bool, tier: Int, stackIndex: Int) {
        let candleIndex = marker.candleIndex
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
            shouldBeBelow = determineSideForNewMarker(
                candleIndex: candleIndex,
                existingMarkers: existingMarkers,
                candles: candles
            )
        }
        
        let tier: Int
        if !markersAtCandle.isEmpty {
            tier = markersAtCandle.first?.proximityTier ?? 0
        } else {
            tier = calculateProximityTier(
                candleIndex: candleIndex,
                isBelow: shouldBeBelow,
                existingMarkers: existingMarkers
            )
        }
        
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        
        return (shouldBeBelow, tier, stackIndex)
    }
    
    private static func determineSideForNewMarker(
        candleIndex: Int,
        existingMarkers: [ChartMarkerDTO],
        candles: [Candle]
    ) -> Bool {
        var aboveCount = 0
        var belowCount = 0
        
        for offset in -closeProximityRange...closeProximityRange {
            if offset == 0 { continue }
            let neighborIndex = candleIndex + offset
            let nearbyMarkers = existingMarkers.filter { $0.candleIndex == neighborIndex }
            
            for marker in nearbyMarkers {
                if marker.positionedBelow {
                    belowCount += 1
                } else {
                    aboveCount += 1
                }
            }
        }
        
        if aboveCount != belowCount {
            return aboveCount > belowCount
        }
        
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        let candle = candles[candleIndex]
        return candle.isBullish
    }
    
    private static func determineSideForCandle(
        candleIndex: Int,
        candles: [Candle],
        existingDecisions: [Int: Bool]
    ) -> Bool {
        var aboveCount = 0
        var belowCount = 0
        
        for offset in -closeProximityRange...closeProximityRange {
            if offset == 0 { continue }
            let neighborIndex = candleIndex + offset
            
            if let decision = existingDecisions[neighborIndex] {
                if decision {
                    belowCount += 1
                } else {
                    aboveCount += 1
                }
            }
        }
        
        if aboveCount != belowCount {
            return aboveCount > belowCount
        }
        
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        let candle = candles[candleIndex]
        return candle.isBullish
    }
    
    private static func calculateProximityTier(
        candleIndex: Int,
        isBelow: Bool,
        existingMarkers: [ChartMarkerDTO]
    ) -> Int {
        var usedTiers = Set<Int>()
        
        for offset in -proximityRange...proximityRange {
            let neighborIndex = candleIndex + offset
            let nearbyMarkers = existingMarkers.filter {
                $0.candleIndex == neighborIndex && $0.positionedBelow == isBelow
            }
            
            for marker in nearbyMarkers {
                usedTiers.insert(marker.proximityTier)
            }
        }
        
        var tier = 0
        while usedTiers.contains(tier) {
            tier += 1
        }
        
        return tier
    }
    
    private static func calculateProximityTierInternal(
        candleIndex: Int,
        usedTiers: inout [Int: Set<Int>]
    ) -> Int {
        var conflictingTiers = Set<Int>()
        
        for offset in -proximityRange...proximityRange {
            let neighborIndex = candleIndex + offset
            if let tiers = usedTiers[neighborIndex] {
                conflictingTiers.formUnion(tiers)
            }
        }
        
        var tier = 0
        while conflictingTiers.contains(tier) {
            tier += 1
        }
        
        if usedTiers[candleIndex] == nil {
            usedTiers[candleIndex] = Set<Int>()
        }
        usedTiers[candleIndex]?.insert(tier)
        
        return tier
    }
    
    static func offsetForTier(_ tier: Int) -> CGFloat {
        return CGFloat(tier) * settings.proximityTierOffset
    }
    
    static func findMarkerAtPoint(
        point: CGPoint,
        markers: [ChartMarkerDTO],
        markerPositions: [UUID: CGPoint]
    ) -> ChartMarkerDTO? {
        for marker in markers.reversed() {
            if let position = markerPositions[marker.id] {
                let distance = hypot(point.x - position.x, point.y - position.y)
                if distance <= hitRadius {
                    return marker
                }
            }
        }
        return nil
    }
}

// MARK: - Chart Marker System (Canvas Drawing)

struct ChartMarkerSystem {
    
    static func drawMarkers(
        context: GraphicsContext,
        markers: [ChartMarkerDTO],
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
            
            let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            let hideUsernames = markersAtCandle.count > 1
            
            var markerPositions: [(marker: ChartMarkerDTO, position: CGPoint)] = []
            for marker in sortedMarkers {
                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: marker,
                    candleHighY: candleHighY,
                    candleLowY: candleLowY,
                    centerX: centerX,
                    priceScale: priceScale
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
    
    private static func drawStackedConnectionLines(
        context: GraphicsContext,
        markers: [(marker: ChartMarkerDTO, position: CGPoint)],
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
                with: .color(Color.gray.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
            )
            
            previousY = isBelow ? position.y + baseRadius : position.y - baseRadius
        }
    }
    
    private static func drawSingleMarker(
        context: GraphicsContext,
        marker: ChartMarkerDTO,
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
        
        // Fill
        context.fill(Path(ellipseIn: circleRect), with: .color(marker.type.color.opacity(0.3)))
        
        // Border
        let strokeWidth: CGFloat = isSelected ? 3 : 2
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: strokeWidth)
        
        // Icon character
        let iconChar = getIconCharacter(for: marker.type)
        let fontSize: CGFloat = 14 * scale
        context.draw(
            Text(iconChar)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(marker.type.color),
            at: position
        )
        
        // Like count badge
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = isBelow ? -10 : 10
            let badgeRect = CGRect(
                x: position.x + 8,
                y: position.y + badgeOffset,
                width: 18,
                height: 14
            )
            context.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(.red))
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 12, y: position.y + badgeOffset + 7)
            )
        }
        
        // Username label
        if !hideUsername {
            let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
            context.draw(
                Text(marker.author.globalMember.username)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.85)),
                at: CGPoint(x: position.x, y: labelY)
            )
        }
    }
    
    private static func getIconCharacter(for type: MarkerType) -> String {
        switch type {
        case .note: return "✎"
        case .question: return "?"
        case .alert: return "!"
        case .entry: return "↑"
        case .exit: return "↓"
        case .stopLoss: return "✕"
        case .takeProfit: return "✓"
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
        markers: [ChartMarkerDTO],
        candles: [Candle],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) -> ChartMarkerDTO? {
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
                    priceScale: priceScale
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

