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
            PatternOverlay(patternType: .honeycomb, hexSize: 16)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.012
            }
        }
    }
}

struct StaticAuthBackgroundView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 16)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1)) {
                patternOpacity = 0.04
            }
        }
    }
}

struct StaticMessagingBackgroundView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [AppColors.sheetBackground, AppColors.gradientBackgroundMid],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 16)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.02
            }
        }
    }
}

struct StaticPatternView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 16)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.02
            }
        }
    }
}
