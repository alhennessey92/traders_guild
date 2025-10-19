//
//  StaticBackgroundView.swift
//  traders_guild
//
//  Created by Al Hennessey on 18/10/2025.
//
import SwiftUI
// MARK: - Static Background View
/// Background view that is completely isolated from animations
struct StaticBackgroundView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundMid],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 18)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.025
            }
        }
    }
}

struct StaticPatternView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 18)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.025
            }
        }
    }
}
