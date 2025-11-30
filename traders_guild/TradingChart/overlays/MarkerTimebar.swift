//
//  MarkerTimebar.swift
//  traders_guild
//
//  FIXED v3 - Time indicator now positioned prominently above bottom sheet
//  Styled to match price indicator (yellow) but in blue
//

import SwiftUI

// MARK: - X-Axis Time Indicator (Matches Y-Axis Price Indicator Style)

/// Time indicator for marker placement - styled like the yellow price indicator
/// Shows a vertical dashed line with a time label box at the bottom
struct MarkerXAxisTimeIndicator: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartHeight: CGFloat
    
    /// Position from bottom - INCREASED to stay visible above sheets
    private let bottomOffset: CGFloat = 55
    
    var body: some View {
        ZStack {
            // Time label box - styled like price indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue)
                .frame(width: 85, height: 24)
                .overlay(
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(timestamp.chartTimeLabel)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                )
                .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 2)
                .position(x: xPosition, y: chartHeight - bottomOffset)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Full Width Time Bar (Alternative)

/// Full-width time selection bar - use if you want more visual prominence
struct MarkerPlacementTimeBar: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    
    /// INCREASED from 70 to 130 to stay visible above bottom sheets
    private let barBottomOffset: CGFloat = 130
    
    var body: some View {
        ZStack {
            // Semi-transparent bar background
            Rectangle()
                .fill(Color.blue.opacity(0.15))
                .frame(height: 40)
            
            // Highlighted section under selected candle
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.4))
                .frame(width: 75, height: 40)
                .position(x: xPosition, y: 20)
            
            // Time label
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                Text(timestamp.chartTimeLabel)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.blue)
                    .shadow(color: .blue.opacity(0.5), radius: 6, x: 0, y: 2)
            )
            .position(x: xPosition, y: 20)
        }
        .frame(width: chartWidth, height: 40)
        .position(x: chartWidth / 2, y: chartHeight - barBottomOffset)
        .allowsHitTesting(false)
    }
}

// MARK: - Simple Time Pill (Minimal)

struct MarkerPlacementTimeIndicator: View {
    let timestamp: Date
    let xPosition: CGFloat
    let chartHeight: CGFloat
    
    private let indicatorBottomOffset: CGFloat = 120
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            
            Text(timestamp.chartTimeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .position(x: xPosition, y: chartHeight - indicatorBottomOffset)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("X-Axis Indicator") {
    ZStack {
        Color.black
        MarkerXAxisTimeIndicator(
            timestamp: Date(),
            xPosition: 200,
            chartHeight: 600
        )
    }
}

#Preview("Time Bar") {
    ZStack {
        Color.black
        MarkerPlacementTimeBar(
            timestamp: Date(),
            xPosition: 200,
            chartWidth: 400,
            chartHeight: 600
        )
    }
}


////
////  MarkerTimebar.swift
////  traders_guild
////
////  IMPROVED v2 - Better visibility and positioning for marker placement time indicator
////  Now positioned more prominently and styled to match the price indicator aesthetic
////
//
//import SwiftUI
//
//// MARK: - Marker Placement Time Bar (Full Width)
//
///// Full-width time selection bar that stays visible above the bottom sheet
///// Styled to match the yellow price indicator but in blue for time
//struct MarkerPlacementTimeBar: View {
//    let timestamp: Date
//    let xPosition: CGFloat
//    let chartWidth: CGFloat
//    let chartHeight: CGFloat
//    
//    /// Height from bottom where the bar appears - INCREASED to stay visible above sheets
//    private let barBottomOffset: CGFloat = 120
//    
//    var body: some View {
//        ZStack {
//            // Semi-transparent bar background spanning full width
//            Rectangle()
//                .fill(Color.blue.opacity(0.12))
//                .frame(height: 44)
//            
//            // Highlighted section under the selected candle
//            RoundedRectangle(cornerRadius: 6)
//                .fill(Color.blue.opacity(0.35))
//                .frame(width: 70, height: 44)
//                .position(x: xPosition, y: 22)
//            
//            // Time label centered on selected candle - styled like price indicator
//            HStack(spacing: 6) {
//                Image(systemName: "clock.fill")
//                    .font(.system(size: 13, weight: .semibold))
//                Text(timestamp.chartTimeLabel)
//                    .font(.system(size: 15, weight: .bold, design: .monospaced))
//            }
//            .foregroundColor(.white)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
//            .background(
//                Capsule()
//                    .fill(Color.blue)
//                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 2)
//            )
//            .position(x: xPosition, y: 22)
//        }
//        .frame(width: chartWidth, height: 44)
//        .position(x: chartWidth / 2, y: chartHeight - barBottomOffset)
//        .allowsHitTesting(false)
//    }
//}
//
//// MARK: - X-Axis Time Indicator (Matches Y-Axis Price Indicator Style)
//
///// X-axis time indicator styled to match the yellow price indicator
///// Shows as a vertical line with a time label at the bottom
///// This is an alternative/complement to the full-width bar
//struct MarkerXAxisTimeIndicator: View {
//    let timestamp: Date
//    let xPosition: CGFloat
//    let chartHeight: CGFloat
//    
//    /// How far from the bottom of the chart to position the time box
//    private let bottomOffset: CGFloat = 85
//    
//    var body: some View {
//        ZStack {
//            // Vertical line from indicator to bottom of chart area
//            Path { path in
//                path.move(to: CGPoint(x: xPosition, y: chartHeight - bottomOffset - 14))
//                path.addLine(to: CGPoint(x: xPosition, y: chartHeight - 20))
//            }
//            .stroke(
//                Color.blue.opacity(0.8),
//                style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
//            )
//            
//            // Time label box - matches price indicator styling
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.blue)
//                .frame(width: 80, height: 24)
//                .overlay(
//                    Text(timestamp.chartTimeLabel)
//                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
//                        .foregroundColor(.white)
//                )
//                .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 2)
//                .position(x: xPosition, y: chartHeight - bottomOffset)
//        }
//        .allowsHitTesting(false)
//    }
//}
//
//// MARK: - Combined Time/Price Crosshair for Placement
//
///// Shows both time (X) and price (Y) indicators during marker placement
///// Creates a subtle crosshair effect without blocking the view
//struct MarkerPlacementCrosshair: View {
//    let timestamp: Date
//    let price: Double
//    let xPosition: CGFloat
//    let yPosition: CGFloat
//    let chartWidth: CGFloat
//    let chartHeight: CGFloat
//    let formatPrice: (Double) -> String
//    
//    var body: some View {
//        ZStack {
//            // Horizontal price line (from left to marker position)
//            Path { path in
//                path.move(to: CGPoint(x: 0, y: yPosition))
//                path.addLine(to: CGPoint(x: xPosition - 25, y: yPosition))
//            }
//            .stroke(
//                Color.blue.opacity(0.5),
//                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
//            )
//            
//            // Horizontal price line (from marker to right edge)
//            Path { path in
//                path.move(to: CGPoint(x: xPosition + 25, y: yPosition))
//                path.addLine(to: CGPoint(x: chartWidth - 70, y: yPosition))
//            }
//            .stroke(
//                Color.blue.opacity(0.5),
//                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
//            )
//            
//            // Price label on Y-axis (right side)
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.blue)
//                .frame(width: 70, height: 22)
//                .overlay(
//                    Text(formatPrice(price))
//                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                        .foregroundColor(.white)
//                )
//                .position(x: chartWidth - 35, y: yPosition)
//            
//            // Vertical time line (from marker to bottom)
//            Path { path in
//                path.move(to: CGPoint(x: xPosition, y: yPosition + 25))
//                path.addLine(to: CGPoint(x: xPosition, y: chartHeight - 50))
//            }
//            .stroke(
//                Color.blue.opacity(0.5),
//                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
//            )
//            
//            // Time label at bottom
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.blue)
//                .frame(width: 80, height: 22)
//                .overlay(
//                    Text(timestamp.chartTimeLabel)
//                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                        .foregroundColor(.white)
//                )
//                .position(x: xPosition, y: chartHeight - 35)
//        }
//        .allowsHitTesting(false)
//    }
//}
//
//// MARK: - Compact Floating Time Pill
//
///// Minimal time indicator that floats near the marker during placement
///// Less intrusive alternative to the full bar
//struct MarkerPlacementTimePill: View {
//    let timestamp: Date
//    let xPosition: CGFloat
//    let yPosition: CGFloat
//    let isBelow: Bool
//    
//    var body: some View {
//        VStack(spacing: 4) {
//            if !isBelow {
//                // Arrow pointing to marker
//                Image(systemName: "arrowtriangle.down.fill")
//                    .font(.system(size: 8))
//                    .foregroundColor(.blue)
//            }
//            
//            // Time pill
//            Text(timestamp.chartTimeLabel)
//                .font(.system(size: 12, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white)
//                .padding(.horizontal, 10)
//                .padding(.vertical, 5)
//                .background(
//                    Capsule()
//                        .fill(Color.blue)
//                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
//                )
//            
//            if isBelow {
//                // Arrow pointing to marker
//                Image(systemName: "arrowtriangle.up.fill")
//                    .font(.system(size: 8))
//                    .foregroundColor(.blue)
//            }
//        }
//        .position(x: xPosition, y: yPosition)
//        .allowsHitTesting(false)
//    }
//}
//
//// MARK: - Preview
//
//#Preview("Time Bar") {
//    ZStack {
//        Color.black
//        MarkerPlacementTimeBar(
//            timestamp: Date(),
//            xPosition: 200,
//            chartWidth: 400,
//            chartHeight: 600
//        )
//    }
//}
//
//#Preview("X-Axis Indicator") {
//    ZStack {
//        Color.black
//        MarkerXAxisTimeIndicator(
//            timestamp: Date(),
//            xPosition: 200,
//            chartHeight: 600
//        )
//    }
//}
//
//#Preview("Placement Crosshair") {
//    ZStack {
//        Color.black
//        MarkerPlacementCrosshair(
//            timestamp: Date(),
//            price: 1.0850,
//            xPosition: 200,
//            yPosition: 300,
//            chartWidth: 400,
//            chartHeight: 600,
//            formatPrice: { String(format: "%.5f", $0) }
//        )
//    }
//}
