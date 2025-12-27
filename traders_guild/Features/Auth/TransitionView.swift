//
//  TransitionView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
//  Handle transition from the end of the signup process to the rootview
//  UPDATED: Now waits for chart to be ready before dismissing

import SwiftUI

struct TransitionView: View {
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0
    @State private var fadeIn: Bool = false
    @State private var opacity: Double = 1.0
    @State private var hasStartedDismiss: Bool = false

    var body: some View {
        ZStack {
            // Solid black base to fully block content behind
            Color.black
                .ignoresSafeArea()
            
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
                .opacity(opacity)
            }
            .opacity(fadeIn ? 1 : 0)
        }
        .onAppear {
            // Fade in
            withAnimation(.easeIn(duration: 1.0)) {
                fadeIn = true
                opacity = 1
            }

            // Pulsing animation - continues while loading
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.1
            }
        }
        // Watch for chart ready - this is the main case for authenticated users with a guild
        .onChange(of: appState.isChartReady) { oldValue, newValue in
            if newValue {
                dismissIfNeeded()
            }
        }
        // Watch for session restored - handles login screen and guild selector cases
        .onChange(of: appState.isSessionRestored) { oldValue, newValue in
            if newValue {
                // Small delay then check what to do
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismissIfNeeded()
                }
            }
        }
        // Watch for guild becoming available (in case it loads after session restore)
        .onChange(of: appState.currentGuild) { oldValue, newValue in
            // If we now have a guild but chart isn't ready yet, wait for chart
            // If we lost a guild, might need to dismiss to show selector
            if newValue == nil && appState.isSessionRestored && appState.isAuthenticated {
                dismissIfNeeded()
            }
        }
    }
    
    /// Check current state and dismiss if appropriate
    private func dismissIfNeeded() {
        guard !hasStartedDismiss else { return }
        guard appState.isSessionRestored else { return }
        
        // Case 1: Not authenticated - dismiss to show login
        if !appState.isAuthenticated {
            dismissTransition()
            return
        }
        
        // Case 2: Authenticated but no guild - dismiss to show guild selector
        if appState.currentGuild == nil {
            dismissTransition()
            return
        }
        
        // Case 3: Authenticated with guild - only dismiss when chart is ready
        if appState.isChartReady {
            dismissTransition()
            return
        }
        
        // Otherwise, keep waiting (chart still loading)
    }
    
    private func dismissTransition() {
        guard !hasStartedDismiss else { return }
        hasStartedDismiss = true
        
        // Start fading out
        withAnimation(.easeOut(duration: 0.8)) {
            fadeIn = false
            opacity = 0
        }
        
        // Finish transition during fade for smooth crossfade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            appState.finishTransition()
        }
    }
}

#Preview {
    TransitionView()
        .environmentObject(AppState())
}


////
////  TransitionView.swift
////  traders_guild
////
////  Created by Al Hennessey on 23/09/2025.
////
////  Handle transition from the end of the signup process to the rootview
//
//import SwiftUI
//
//struct TransitionView: View {
//    @EnvironmentObject var appState: AppState
//    @State private var scale: CGFloat = 1.0
//    @State private var fadeIn: Bool = false
//    @State private var opacity: Double = 1.0
//
//    var body: some View {
//        ZStack {
//            // Use matching gradient for smooth transition
//            StaticAuthBackgroundView()
//            
//            VStack {
//                VStack {
//                    Text("Welcome to")
//                        .font(.title2)
//                        .foregroundColor(AppColors.greyText)
//                    
//                    Text("Traders Guild")
//                        .font(AppFonts.title(size: 40))
//                        .fontWeight(.heavy)
//                        .foregroundColor(AppColors.whiteText)
//                }
//                .multilineTextAlignment(.center)
//                .scaleEffect(scale)
//                .onAppear {
//                    // Fade in
//                    withAnimation(.easeIn(duration: 1.0)) {
//                        fadeIn = true
//                        opacity = 1
//                    }
//
//                    // Pulsing animation
//                    withAnimation(
//                        .easeInOut(duration: 1.2)
//                        .repeatForever(autoreverses: true)
//                    ) {
//                        scale = 1.1
//                    }
//
//                    // Start fading out after 1.5 seconds
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                        withAnimation(.easeOut(duration: 1.0)) {
//                            fadeIn = false
//                            opacity = 0
//                        }
//
//                        // Finish transition during fade for smooth crossfade
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            appState.finishTransition()
//                        }
//                    }
//                }
//                .opacity(opacity)
//            }
//            .opacity(fadeIn ? 1 : 0)
//        }
//    }
//}
//
//#Preview {
//    TransitionView()
//        .environmentObject(AppState())
//}
