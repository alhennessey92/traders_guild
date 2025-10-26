//
//  TransitionView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
//  Handle transition from the end of the signup process to the rootview

import SwiftUI

struct TransitionView: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0
    @State private var fadeIn: Bool = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Use matching gradient for smooth transition
            StaticAuthBackgroundView()
            
            VStack {
                VStack {
                    Text("Welcome to")
                        .font(.title2)
                        .foregroundColor(AppColors.greyText)
                    
                    Text("Traders Guild")
                        .font(AppFonts.title(size: 40))
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.whiteText)
                }
                .multilineTextAlignment(.center)
                .scaleEffect(scale)
                .onAppear {
                    // Fade in
                    withAnimation(.easeIn(duration: 1.0)) {
                        fadeIn = true
                        opacity = 1
                    }

                    // Pulsing animation
                    withAnimation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.1
                    }

                    // Start fading out after 1.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            fadeIn = false
                            opacity = 0
                        }

                        // Finish transition during fade for smooth crossfade
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            appState.finishTransition()
                        }
                    }
                }
                .opacity(opacity)
            }
            .opacity(fadeIn ? 1 : 0)
        }
    }
}

#Preview {
    TransitionView()
        .environmentObject(AppState())
}
