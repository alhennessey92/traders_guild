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
    private let bottomOffset: CGFloat = 115
    
    var body: some View {
        ZStack {
            // Time label box - styled like price indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue)
                .frame(width: 65, height: 24)
                .overlay(
                    HStack(spacing: 4) {
//                        Image(systemName: "clock")
//                            .font(.system(size: 10, weight: .semibold))
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

