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
    @EnvironmentObject var RLAppState: RLAppState
    
    //@EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0
    @State private var fadeIn: Bool = false
    @State private var opacity: Double = 1.0
    @State private var hasStartedDismiss: Bool = false
    @State private var pendingDismissWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            // Solid black base to fully block content behind
            AppColors.systemBlack
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

            // If session was already restored before this view appeared, dismiss immediately
            if RLAppState.isSessionRestored {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissIfNeeded()
                }
            }

            // Failsafe: never leave users trapped on transition if chart-ready signal is missed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                guard !hasStartedDismiss else { return }
                guard RLAppState.isAuthenticated else { return }
                guard RLAppState.currentGuild != nil else { return }
                dismissIfNeeded()
            }
        }
        // Watch for chart ready - this is the main case for authenticated users with a guild
        .onChange(of: RLAppState.isChartReady) { oldValue, newValue in
            if newValue {
                dismissIfNeeded()
            }
        }
        // Watch for session restored - handles login screen and guild selector cases
        .onChange(of: RLAppState.isSessionRestored) { oldValue, newValue in
            if newValue {
                // Small delay then check what to do
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismissIfNeeded()
                }
            }
        }
        // Watch for guild changes (in case it loads after session restore)
        .onChange(of: RLAppState.currentGuild) { oldValue, newValue in
            if RLAppState.isSessionRestored && RLAppState.isAuthenticated {
                dismissIfNeeded()
            }
        }
        .onDisappear {
            pendingDismissWorkItem?.cancel()
        }
    }
    
    /// Check current state and dismiss if appropriate
    private func dismissIfNeeded() {
        guard !hasStartedDismiss else { return }
        guard RLAppState.isSessionRestored else { return }
        
        // Case 1: Not authenticated - dismiss to show login
        if !RLAppState.isAuthenticated {
            dismissTransitionWhenReady()
            return
        }
        
        // Case 2: Authenticated but no guild - dismiss to show guild selector
        if RLAppState.currentGuild == nil {
            dismissTransitionWhenReady()
            return
        }
        
        // Case 3: Authenticated with guild - only dismiss when chart is ready
        if RLAppState.isChartReady {
            dismissTransitionWhenReady()
            return
        }
        
        // Otherwise, keep waiting (chart still loading)
    }

    private func dismissTransitionWhenReady() {
        guard !hasStartedDismiss else { return }

        let remaining = RLAppState.transitionMinimumRemaining()
        guard remaining > 0 else {
            dismissTransition()
            return
        }

        pendingDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            dismissIfNeeded()
        }
        pendingDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
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
            RLAppState.finishTransition()
        }
    }
}
