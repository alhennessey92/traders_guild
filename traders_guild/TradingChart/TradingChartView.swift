
//
//  TradingChartView.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//

import SwiftUI

/// Main trading chart view that handles all chart rendering and interactions
/// Features centered scaling that keeps visible candles in view during zoom
struct TradingChartView: View {
    // MARK: - State Properties
    
    /// Gesture state manager that handles all transformations
    @StateObject private var gestureState = ChartGestureState()
    
    /// Current drag translation for smooth panning feedback
    @GestureState private var dragState: CGSize = .zero
    
    /// Current pinch scale for smooth scaling feedback
    @GestureState private var pinchScale: CGFloat = 1.0
    
    /// Track if user is currently dragging on the Y-axis area for vertical scaling
    @State private var isDraggingOnYAxis = false
    
    /// Starting Y position when beginning Y-axis drag
    @State private var yAxisDragStart: CGFloat = 0
    
    /// The price scale value when starting Y-axis drag (for relative scaling)
    @State private var initialPriceScale: CGFloat = 1.0
    
    /// Track the center of visible candles for centered scaling
    @State private var visibleCandlesCenter: CGFloat = 0
    
    // MARK: - Chart Configuration
    
    /// Base width of each candle (before scaling)
    private let baseCandleWidth: CGFloat = 12
    
    /// Spacing between candles
    private let candleSpacing: CGFloat = 4
    
    /// Edge padding to prevent endless scrolling
    /// User can scroll slightly beyond data bounds but not infinitely
    private let edgePadding: CGFloat = 100
    
    /// Width of the Y-axis interaction area
    private let yAxisWidth: CGFloat = 60
    
    /// Chart view model that manages candlestick data
    @StateObject private var chartData = ChartDataManager()
    
    // MARK: - Sensitivity Configuration
    
    /// Dampening factor for pinch gesture (lower = less sensitive)
    private let pinchSensitivity: CGFloat = 0.25
    
    /// Dampening factor for Y-axis drag (lower = less sensitive)
    private let yAxisSensitivity: CGFloat = 0.3
    
    // MARK: - Computed Properties
    
    /// Actual width of each candle including current scale
    /// This combines base width with both stored scale and active pinch gesture
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale * pinchScale
    }
    
    /// Total width per candle including spacing
    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
    }
    
    /// Calculate the center index of currently visible candles
    /// This is used for centered scaling to keep visible candles in view
    private func calculateVisibleCenter(in width: CGFloat) -> CGFloat {
        let totalOffset = gestureState.panOffset.width + dragState.width
        let visibleStartIndex = -totalOffset / totalCandleWidth
        let visibleCount = width / totalCandleWidth
        return visibleStartIndex + (visibleCount / 2)
    }
    
    /// Calculate clamped vertical offset that respects pan limits
    /// This prevents panning beyond reasonable bounds in real-time
    private func clampedVerticalOffset(chartHeight: CGFloat) -> CGFloat {
        let totalOffset = gestureState.verticalPanOffset + dragState.height
        let scaledHeight = chartHeight * gestureState.priceScale
        let verticalPadding = scaledHeight * 0.5
        return Swift.min(verticalPadding, Swift.max(-verticalPadding, totalOffset))
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background for professional trading chart appearance
                Color.black
                    .ignoresSafeArea()
                
                // Main chart canvas where all drawing happens
                Canvas { context, size in
                    drawChart(
                        context: context,
                        size: size,
                        geometry: geometry
                    )
                }
                // Apply gestures to the canvas
                .gesture(dragGesture(in: geometry.size))
                .simultaneousGesture(pinchGesture(in: geometry.size))
                
                // Fixed Y-axis overlay (stays on right side)
                yAxisOverlay(geometry: geometry)
                
                // Fixed X-axis overlay (stays at bottom)
                xAxisOverlay(geometry: geometry)
                
                // Y-axis interaction overlay for vertical scaling
                // This is an invisible area on the right side of the chart
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: yAxisWidth)
                        .contentShape(Rectangle()) // Ensure full height is tappable
                        .gesture(yAxisDragGesture)
                }
                
                // Price indicator overlay showing current/latest price
                PriceIndicatorView(
                    currentPrice: chartData.currentPrice,
                    priceScale: gestureState.priceScale,
                    verticalOffset: clampedVerticalOffset(chartHeight: geometry.size.height),
                    chartHeight: geometry.size.height,
                    priceRange: chartData.priceRange
                )
            }
        }
        .onAppear {
            // Start generating real-time data when view appears
            chartData.startDataGeneration()
        }
    }
    
    // MARK: - Gestures
    
    /// Drag gesture for panning the chart in all directions
    /// This allows users to explore historical data and adjust vertical position
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragState) { value, state, _ in
                // Only update if not dragging on Y-axis (for scaling)
                if !isDraggingOnYAxis {
                    // Reverse vertical direction for natural feel (drag up = chart moves up)
                    state = CGSize(width: value.translation.width, height: -value.translation.height)
                }
            }
            .onEnded { value in
                // Apply the final translation with limits
                if !isDraggingOnYAxis {
                    // Reverse vertical direction for natural feel
                    let adjustedTranslation = CGSize(width: value.translation.width, height: -value.translation.height)
                    gestureState.applyPan(
                        translation: adjustedTranslation,
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale
                    )
                }
            }
    }
    
    /// Pinch gesture that ONLY affects horizontal scale (candle width)
    /// This scales around the center of visible candles to keep them in view
    /// Now with reduced sensitivity for better control
    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                // Apply dampening to make it less sensitive
                let dampened = 1.0 + (value - 1.0) * pinchSensitivity
                state = dampened
            }
            .onChanged { value in
                // Apply dampening
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                
                // Calculate the center of visible candles before scaling
                let centerIndex = calculateVisibleCenter(in: size.width)
                
                // Store the position of this center candle before scaling
                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
                let oldPosition = centerIndex * (oldCandleWidth + candleSpacing)
                
                // Apply the scale (clamped to reasonable limits)
                let newScale = gestureState.candleWidthScale * dampenedValue
                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
                
                // Calculate new position after scaling
                let newCandleWidth = baseCandleWidth * clampedScale
                let newPosition = centerIndex * (newCandleWidth + candleSpacing)
                
                // Adjust pan offset to keep the center candle in the same screen position
                // This creates the effect of scaling around the visible center
                let offsetAdjustment = oldPosition - newPosition
                gestureState.panOffset.width += offsetAdjustment
                
                // Apply the new scale
                gestureState.candleWidthScale = clampedScale
            }
            .onEnded { value in
                // Finalize the scale when gesture ends
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                let centerIndex = calculateVisibleCenter(in: size.width)
                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
                let oldPosition = centerIndex * (oldCandleWidth + candleSpacing)
                
                let newScale = gestureState.candleWidthScale * dampenedValue
                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
                
                let newCandleWidth = baseCandleWidth * clampedScale
                let newPosition = centerIndex * (newCandleWidth + candleSpacing)
                
                let offsetAdjustment = oldPosition - newPosition
                gestureState.panOffset.width += offsetAdjustment
                gestureState.candleWidthScale = clampedScale
            }
    }
    
    /// Drag gesture on the Y-axis area for vertical scaling
    /// This allows users to compress/expand the price range
    /// Now with reduced sensitivity
    private var yAxisDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDraggingOnYAxis {
                    // First touch - record starting position and current scale
                    isDraggingOnYAxis = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = gestureState.priceScale
                }
                
                // Calculate how far user has dragged
                let dragDistance = value.location.y - yAxisDragStart
                
                // Apply dampened scale factor (less sensitive)
                // Positive drag (down) = zoom out, negative drag (up) = zoom in
                let scaleFactor = 1.0 - (dragDistance / 500.0) * yAxisSensitivity
                
                // Apply the scale with limits
                let newScale = initialPriceScale * scaleFactor
                gestureState.priceScale = Swift.min(3.0, Swift.max(0.5, newScale))
            }
            .onEnded { _ in
                isDraggingOnYAxis = false
            }
    }
    
    // MARK: - Fixed Axis Overlays
    
    /// Y-axis overlay that stays fixed on the right side
    /// Only moves vertically with vertical pan
    @ViewBuilder
    private func yAxisOverlay(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            
            Canvas { context, size in
                let priceRange = chartData.priceRange
                let scaledHeight = geometry.size.height * gestureState.priceScale
                let priceStep = (priceRange.max - priceRange.min) / 10
                
                // Only apply vertical offset, no horizontal movement
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                
                for i in 0...10 {
                    let price = priceRange.min + (priceStep * Double(i))
                    
                    // Calculate Y position with scale and offset
                    let y = size.height - (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
                    
                    // Only draw labels that are visible on screen
                    if y >= -20 && y <= size.height + 20 {
                        // Draw price label
                        context.draw(
                            Text(String(format: "%.2f", price))
                                .font(.system(size: 10))
                                .foregroundColor(.gray),
                            at: CGPoint(x: 30, y: y) // Fixed X position
                        )
                    }
                }
            }
            .frame(width: yAxisWidth)
            .background(Color.black.opacity(0.8))
        }
        .allowsHitTesting(false) // Let touches pass through to the gesture area below
    }
    
    /// X-axis overlay that stays fixed at the bottom
    /// Only moves horizontally with horizontal pan
    /// Time labels smoothly slide with the candles
    @ViewBuilder
    private func xAxisOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            Canvas { context, size in
                // Only apply horizontal offset, no vertical movement
                let totalOffset = gestureState.panOffset.width + dragState.width
                
                // Draw time labels for every 5th candle
                // These will smoothly slide with the horizontal pan
                let labelStride = 5
                for i in stride(from: 0, to: chartData.candles.count, by: labelStride) {
                    let x = CGFloat(i) * totalCandleWidth + totalOffset
                    
                    // Only draw if visible on screen (but calculation stays smooth)
                    if x >= -50 && x <= size.width + 50 {
                        let candle = chartData.candles[i]
                        
                        // Format time label
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        let timeText = formatter.string(from: candle.timestamp)
                        
                        // Draw time label at fixed Y position
                        context.draw(
                            Text(timeText)
                                .font(.system(size: 10))
                                .foregroundColor(.gray),
                            at: CGPoint(x: x + actualCandleWidth / 2, y: 10) // Fixed Y position
                        )
                    }
                }
            }
            .frame(height: 20)
            .background(Color.black.opacity(0.8))
            .padding(.bottom, geometry.size.height * 0.11 + 10) // Raise above bottom sheet (11% + padding)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Chart Drawing
    
    /// Main chart drawing coordinator
    /// Calls individual drawing methods for each chart component
    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        // Create a drawing context with proper clipping
        var drawingContext = context
        
        // Clip to chart bounds to prevent drawing outside
        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))
        
        // Draw components in order (back to front)
        drawGrid(context: drawingContext, size: size)
        drawCandlesticks(context: drawingContext, size: size)
    }
    
    /// Draw the background grid for visual reference
    /// Grid lines help users gauge price levels and time intervals
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridPath = Path { path in
            // Vertical grid lines (time-based)
            // Space them based on current candle width for consistent appearance
            let verticalSpacing = totalCandleWidth * 5 // Grid line every 5 candles
            
            // Calculate starting position to align with candles
            let totalOffset = gestureState.panOffset.width + dragState.width
            var x = totalOffset.truncatingRemainder(dividingBy: verticalSpacing)
            if x > 0 { x -= verticalSpacing } // Ensure we start from the left
            
            // Draw vertical lines across the visible area
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += verticalSpacing
            }
            
            // Horizontal grid lines (price-based)
            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
            let scaledHeight = size.height * gestureState.priceScale
            let horizontalSpacing = scaledHeight / 10
            
            // Calculate starting Y with offset
            var y = -totalVerticalOffset.truncatingRemainder(dividingBy: horizontalSpacing)
            if y > 0 { y -= horizontalSpacing }
            
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += horizontalSpacing
            }
        }
        
        // Draw with subtle gray color for non-intrusive reference
        context.stroke(gridPath, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
    }
    
    /// Draw candlesticks - the main chart content
    /// Each candle shows open, high, low, close prices
    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
        let priceRange = chartData.priceRange
        let scaledHeight = size.height * gestureState.priceScale
        
        // Calculate total offset including current drag
        let totalOffset = gestureState.panOffset.width + dragState.width
        
        // Determine visible candle range with buffer for smooth scrolling
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
        let visibleEndIndex = Swift.min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        
        // Draw each visible candle
        for i in visibleStartIndex..<visibleEndIndex {
            guard i < chartData.candles.count else { continue }
            
            let candle = chartData.candles[i]
            let x = CGFloat(i) * totalCandleWidth + totalOffset
            
            // Skip if candle is outside visible area (performance optimization)
            if x < -totalCandleWidth || x > size.width + totalCandleWidth {
                continue
            }
            
            // Calculate Y positions for OHLC values
            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
            
            // High price Y position (top of wick)
            let highY = size.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
            
            // Low price Y position (bottom of wick)
            let lowY = size.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
            
            // Open price Y position
            let openY = size.height - (CGFloat(candle.open - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
            
            // Close price Y position
            let closeY = size.height - (CGFloat(candle.close - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
            
            // Determine candle color based on price movement
            let candleColor = candle.close >= candle.open ? Color.green : Color.red
            
            // Draw wick (thin line from high to low)
            let wickPath = Path { path in
                path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
                path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
            }
            context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
            
            // Draw body (rectangle from open to close)
            let bodyRect = CGRect(
                x: x,
                y: Swift.min(openY, closeY), // Top of body
                width: actualCandleWidth,
                height: Swift.max(1, abs(closeY - openY)) // Height of body (minimum 1 for doji)
            )
            
            if candle.close >= candle.open {
                // Bullish candle - hollow with green outline
                context.stroke(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor),
                    lineWidth: 1
                )
                // Semi-transparent fill for better visibility
                context.fill(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor.opacity(0.3))
                )
            } else {
                // Bearish candle - solid red fill
                context.fill(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor)
                )
            }
        }
    }
}

////
////  TradingChartView.swift
////  traders_guild
////
////  Created by Al Hennessey on 14/11/2025.
////
//
////
////  TradingChartView.swift
////  traders_guild
////
////  Created by Al Hennessey on 14/11/2025.
////
//
//import SwiftUI
//
///// Main trading chart view that handles all chart rendering and interactions
///// Features centered scaling that keeps visible candles in view during zoom
//struct TradingChartView: View {
//    // MARK: - State Properties
//    
//    /// Gesture state manager that handles all transformations
//    @StateObject private var gestureState = ChartGestureState()
//    
//    /// Current drag translation for smooth panning feedback
//    @GestureState private var dragState: CGSize = .zero
//    
//    /// Current pinch scale for smooth scaling feedback
//    @GestureState private var pinchScale: CGFloat = 1.0
//    
//    /// Track if user is currently dragging on the Y-axis area for vertical scaling
//    @State private var isDraggingOnYAxis = false
//    
//    /// Starting Y position when beginning Y-axis drag
//    @State private var yAxisDragStart: CGFloat = 0
//    
//    /// The price scale value when starting Y-axis drag (for relative scaling)
//    @State private var initialPriceScale: CGFloat = 1.0
//    
//    /// Track the center of visible candles for centered scaling
//    @State private var visibleCandlesCenter: CGFloat = 0
//    
//    // MARK: - Chart Configuration
//    
//    /// Base width of each candle (before scaling)
//    private let baseCandleWidth: CGFloat = 12
//    
//    /// Spacing between candles
//    private let candleSpacing: CGFloat = 4
//    
//    /// Edge padding to prevent endless scrolling
//    /// User can scroll slightly beyond data bounds but not infinitely
//    private let edgePadding: CGFloat = 100
//    
//    /// Width of the Y-axis interaction area
//    private let yAxisWidth: CGFloat = 60
//    
//    /// Chart view model that manages candlestick data
//    @StateObject private var chartData = ChartDataManager()
//    
//    // MARK: - Sensitivity Configuration
//    
//    /// Dampening factor for pinch gesture (lower = less sensitive)
//    private let pinchSensitivity: CGFloat = 0.5
//    
//    /// Dampening factor for Y-axis drag (lower = less sensitive)
//    private let yAxisSensitivity: CGFloat = 0.3
//    
//    // MARK: - Computed Properties
//    
//    /// Actual width of each candle including current scale
//    /// This combines base width with both stored scale and active pinch gesture
//    private var actualCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale * pinchScale
//    }
//    
//    /// Total width per candle including spacing
//    private var totalCandleWidth: CGFloat {
//        actualCandleWidth + candleSpacing
//    }
//    
//    /// Calculate the center index of currently visible candles
//    /// This is used for centered scaling to keep visible candles in view
//    private func calculateVisibleCenter(in width: CGFloat) -> CGFloat {
//        let totalOffset = gestureState.panOffset.width + dragState.width
//        let visibleStartIndex = -totalOffset / totalCandleWidth
//        let visibleCount = width / totalCandleWidth
//        return visibleStartIndex + (visibleCount / 2)
//    }
//    
//    // MARK: - Body
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Black background for professional trading chart appearance
//                Color.black
//                    .ignoresSafeArea()
//                
//                // Main chart canvas where all drawing happens
//                Canvas { context, size in
//                    drawChart(
//                        context: context,
//                        size: size,
//                        geometry: geometry
//                    )
//                }
//                // Apply gestures to the canvas
//                .gesture(dragGesture(in: geometry.size))
//                .simultaneousGesture(pinchGesture(in: geometry.size))
//                
//                // Fixed Y-axis overlay (stays on right side)
//                yAxisOverlay(geometry: geometry)
//                
//                // Fixed X-axis overlay (stays at bottom)
//                xAxisOverlay(geometry: geometry)
//                
//                // Y-axis interaction overlay for vertical scaling
//                // This is an invisible area on the right side of the chart
//                HStack {
//                    Spacer()
//                    Color.clear
//                        .frame(width: yAxisWidth)
//                        .contentShape(Rectangle()) // Ensure full height is tappable
//                        .gesture(yAxisDragGesture)
//                }
//                
//                // Price indicator overlay showing current/latest price
//                PriceIndicatorView(
//                    currentPrice: chartData.currentPrice,
//                    priceScale: gestureState.priceScale,
//                    verticalOffset: gestureState.verticalPanOffset + dragState.height,
//                    chartHeight: geometry.size.height,
//                    priceRange: chartData.priceRange
//                )
//            }
//        }
//        .onAppear {
//            // Start generating real-time data when view appears
//            chartData.startDataGeneration()
//        }
//    }
//    
//    // MARK: - Gestures
//    
//    /// Drag gesture for panning the chart in all directions
//    /// This allows users to explore historical data and adjust vertical position
//    private func dragGesture(in size: CGSize) -> some Gesture {
//        DragGesture(minimumDistance: 0)
//            .updating($dragState) { value, state, _ in
//                // Only update if not dragging on Y-axis (for scaling)
//                if !isDraggingOnYAxis {
//                    // Reverse vertical direction for natural feel (drag up = chart moves up)
//                    state = CGSize(width: value.translation.width, height: -value.translation.height)
//                }
//            }
//            .onEnded { value in
//                // Apply the final translation with limits
//                if !isDraggingOnYAxis {
//                    // Reverse vertical direction for natural feel
//                    let adjustedTranslation = CGSize(width: value.translation.width, height: -value.translation.height)
//                    gestureState.applyPan(
//                        translation: adjustedTranslation,
//                        chartWidth: size.width,
//                        candleCount: chartData.candles.count,
//                        candleWidth: totalCandleWidth
//                    )
//                }
//            }
//    }
//    
//    /// Pinch gesture that ONLY affects horizontal scale (candle width)
//    /// This scales around the center of visible candles to keep them in view
//    /// Now with reduced sensitivity for better control
//    private func pinchGesture(in size: CGSize) -> some Gesture {
//        MagnificationGesture()
//            .updating($pinchScale) { value, state, _ in
//                // Apply dampening to make it less sensitive
//                let dampened = 1.0 + (value - 1.0) * pinchSensitivity
//                state = dampened
//            }
//            .onChanged { value in
//                // Apply dampening
//                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
//                
//                // Calculate the center of visible candles before scaling
//                let centerIndex = calculateVisibleCenter(in: size.width)
//                
//                // Store the position of this center candle before scaling
//                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
//                let oldPosition = centerIndex * (oldCandleWidth + candleSpacing)
//                
//                // Apply the scale (clamped to reasonable limits)
//                let newScale = gestureState.candleWidthScale * dampenedValue
//                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
//                
//                // Calculate new position after scaling
//                let newCandleWidth = baseCandleWidth * clampedScale
//                let newPosition = centerIndex * (newCandleWidth + candleSpacing)
//                
//                // Adjust pan offset to keep the center candle in the same screen position
//                // This creates the effect of scaling around the visible center
//                let offsetAdjustment = oldPosition - newPosition
//                gestureState.panOffset.width += offsetAdjustment
//                
//                // Apply the new scale
//                gestureState.candleWidthScale = clampedScale
//            }
//            .onEnded { value in
//                // Finalize the scale when gesture ends
//                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
//                let centerIndex = calculateVisibleCenter(in: size.width)
//                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
//                let oldPosition = centerIndex * (oldCandleWidth + candleSpacing)
//                
//                let newScale = gestureState.candleWidthScale * dampenedValue
//                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
//                
//                let newCandleWidth = baseCandleWidth * clampedScale
//                let newPosition = centerIndex * (newCandleWidth + candleSpacing)
//                
//                let offsetAdjustment = oldPosition - newPosition
//                gestureState.panOffset.width += offsetAdjustment
//                gestureState.candleWidthScale = clampedScale
//            }
//    }
//    
//    /// Drag gesture on the Y-axis area for vertical scaling
//    /// This allows users to compress/expand the price range
//    /// Now with reduced sensitivity
//    private var yAxisDragGesture: some Gesture {
//        DragGesture()
//            .onChanged { value in
//                if !isDraggingOnYAxis {
//                    // First touch - record starting position and current scale
//                    isDraggingOnYAxis = true
//                    yAxisDragStart = value.startLocation.y
//                    initialPriceScale = gestureState.priceScale
//                }
//                
//                // Calculate how far user has dragged
//                let dragDistance = value.location.y - yAxisDragStart
//                
//                // Apply dampened scale factor (less sensitive)
//                // Positive drag (down) = zoom out, negative drag (up) = zoom in
//                let scaleFactor = 1.0 - (dragDistance / 500.0) * yAxisSensitivity
//                
//                // Apply the scale with limits
//                let newScale = initialPriceScale * scaleFactor
//                gestureState.priceScale = Swift.min(3.0, Swift.max(0.5, newScale))
//            }
//            .onEnded { _ in
//                isDraggingOnYAxis = false
//            }
//    }
//    
//    // MARK: - Fixed Axis Overlays
//    
//    /// Y-axis overlay that stays fixed on the right side
//    /// Only moves vertically with vertical pan
//    @ViewBuilder
//    private func yAxisOverlay(geometry: GeometryProxy) -> some View {
//        HStack {
//            Spacer()
//            
//            Canvas { context, size in
//                let priceRange = chartData.priceRange
//                let scaledHeight = geometry.size.height * gestureState.priceScale
//                let priceStep = (priceRange.max - priceRange.min) / 10
//                
//                // Only apply vertical offset, no horizontal movement
//                let totalVerticalOffset = gestureState.verticalPanOffset + dragState.height
//                
//                for i in 0...10 {
//                    let price = priceRange.min + (priceStep * Double(i))
//                    
//                    // Calculate Y position with scale and offset
//                    let y = size.height - (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
//                    
//                    // Only draw labels that are visible on screen
//                    if y >= -20 && y <= size.height + 20 {
//                        // Draw price label
//                        context.draw(
//                            Text(String(format: "%.2f", price))
//                                .font(.system(size: 10))
//                                .foregroundColor(.gray),
//                            at: CGPoint(x: 30, y: y) // Fixed X position
//                        )
//                    }
//                }
//            }
//            .frame(width: yAxisWidth)
//            .background(Color.black.opacity(0.8))
//        }
//        .allowsHitTesting(false) // Let touches pass through to the gesture area below
//    }
//    
//    /// X-axis overlay that stays fixed at the bottom
//    /// Only moves horizontally with horizontal pan
//    /// Time labels smoothly slide with the candles
//    @ViewBuilder
//    private func xAxisOverlay(geometry: GeometryProxy) -> some View {
//        VStack {
//            Spacer()
//            
//            Canvas { context, size in
//                // Only apply horizontal offset, no vertical movement
//                let totalOffset = gestureState.panOffset.width + dragState.width
//                
//                // Draw time labels for every 5th candle
//                // These will smoothly slide with the horizontal pan
//                let labelStride = 5
//                for i in stride(from: 0, to: chartData.candles.count, by: labelStride) {
//                    let x = CGFloat(i) * totalCandleWidth + totalOffset
//                    
//                    // Only draw if visible on screen (but calculation stays smooth)
//                    if x >= -50 && x <= size.width + 50 {
//                        let candle = chartData.candles[i]
//                        
//                        // Format time label
//                        let formatter = DateFormatter()
//                        formatter.dateFormat = "HH:mm"
//                        let timeText = formatter.string(from: candle.timestamp)
//                        
//                        // Draw time label at fixed Y position
//                        context.draw(
//                            Text(timeText)
//                                .font(.system(size: 10))
//                                .foregroundColor(.gray),
//                            at: CGPoint(x: x + actualCandleWidth / 2, y: 10) // Fixed Y position
//                        )
//                    }
//                }
//            }
//            .frame(height: 20)
//            .background(Color.black.opacity(0.8))
//            .padding(.bottom, geometry.size.height * 0.11 + 10) // Raise above bottom sheet (11% + padding)
//        }
//        .allowsHitTesting(false)
//    }
//    
//    // MARK: - Chart Drawing
//    
//    /// Main chart drawing coordinator
//    /// Calls individual drawing methods for each chart component
//    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
//        // Create a drawing context with proper clipping
//        var drawingContext = context
//        
//        // Clip to chart bounds to prevent drawing outside
//        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))
//        
//        // Draw components in order (back to front)
//        drawGrid(context: drawingContext, size: size)
//        drawCandlesticks(context: drawingContext, size: size)
//    }
//    
//    /// Draw the background grid for visual reference
//    /// Grid lines help users gauge price levels and time intervals
//    private func drawGrid(context: GraphicsContext, size: CGSize) {
//        let gridPath = Path { path in
//            // Vertical grid lines (time-based)
//            // Space them based on current candle width for consistent appearance
//            let verticalSpacing = totalCandleWidth * 5 // Grid line every 5 candles
//            
//            // Calculate starting position to align with candles
//            let totalOffset = gestureState.panOffset.width + dragState.width
//            var x = totalOffset.truncatingRemainder(dividingBy: verticalSpacing)
//            if x > 0 { x -= verticalSpacing } // Ensure we start from the left
//            
//            // Draw vertical lines across the visible area
//            while x < size.width {
//                path.move(to: CGPoint(x: x, y: 0))
//                path.addLine(to: CGPoint(x: x, y: size.height))
//                x += verticalSpacing
//            }
//            
//            // Horizontal grid lines (price-based)
//            let totalVerticalOffset = gestureState.verticalPanOffset + dragState.height
//            let scaledHeight = size.height * gestureState.priceScale
//            let horizontalSpacing = scaledHeight / 10
//            
//            // Calculate starting Y with offset
//            var y = -totalVerticalOffset.truncatingRemainder(dividingBy: horizontalSpacing)
//            if y > 0 { y -= horizontalSpacing }
//            
//            while y < size.height {
//                path.move(to: CGPoint(x: 0, y: y))
//                path.addLine(to: CGPoint(x: size.width, y: y))
//                y += horizontalSpacing
//            }
//        }
//        
//        // Draw with subtle gray color for non-intrusive reference
//        context.stroke(gridPath, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
//    }
//    
//    /// Draw candlesticks - the main chart content
//    /// Each candle shows open, high, low, close prices
//    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
//        let priceRange = chartData.priceRange
//        let scaledHeight = size.height * gestureState.priceScale
//        
//        // Calculate total offset including current drag
//        let totalOffset = gestureState.panOffset.width + dragState.width
//        
//        // Determine visible candle range with buffer for smooth scrolling
//        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
//        let visibleEndIndex = Swift.min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
//        
//        // Draw each visible candle
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i < chartData.candles.count else { continue }
//            
//            let candle = chartData.candles[i]
//            let x = CGFloat(i) * totalCandleWidth + totalOffset
//            
//            // Skip if candle is outside visible area (performance optimization)
//            if x < -totalCandleWidth || x > size.width + totalCandleWidth {
//                continue
//            }
//            
//            // Calculate Y positions for OHLC values
//            let totalVerticalOffset = gestureState.verticalPanOffset + dragState.height
//            
//            // High price Y position (top of wick)
//            let highY = size.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
//            
//            // Low price Y position (bottom of wick)
//            let lowY = size.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
//            
//            // Open price Y position
//            let openY = size.height - (CGFloat(candle.open - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
//            
//            // Close price Y position
//            let closeY = size.height - (CGFloat(candle.close - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - totalVerticalOffset
//            
//            // Determine candle color based on price movement
//            let candleColor = candle.close >= candle.open ? Color.green : Color.red
//            
//            // Draw wick (thin line from high to low)
//            let wickPath = Path { path in
//                path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
//                path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
//            }
//            context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
//            
//            // Draw body (rectangle from open to close)
//            let bodyRect = CGRect(
//                x: x,
//                y: Swift.min(openY, closeY), // Top of body
//                width: actualCandleWidth,
//                height: Swift.max(1, abs(closeY - openY)) // Height of body (minimum 1 for doji)
//            )
//            
//            if candle.close >= candle.open {
//                // Bullish candle - hollow with green outline
//                context.stroke(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor),
//                    lineWidth: 1
//                )
//                // Semi-transparent fill for better visibility
//                context.fill(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor.opacity(0.3))
//                )
//            } else {
//                // Bearish candle - solid red fill
//                context.fill(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor)
//                )
//            }
//        }
//    }
//}

