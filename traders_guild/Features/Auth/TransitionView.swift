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
    /// Immutable for this view lifetime. SwiftUI replaces the view when a new
    /// request arrives, so callbacks owned by the outgoing view can never
    /// retarget themselves to the newer transition.
    let request: GuildTransitionRequest

    @EnvironmentObject var RLAppState: RLAppState
    
    //@EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 1.0
    @State private var fadeIn: Bool = false
    @State private var opacity: Double = 1.0
    @State private var ringRotation: Double = 0
    @State private var hasStartedDismiss: Bool = false
    @State private var pendingDismissWorkItem: DispatchWorkItem?
    @State private var failsafeWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            // Solid black base to fully block content behind
            AppColors.systemBlack
                .ignoresSafeArea()
            
            // Use matching gradient for smooth transition
            StaticAuthBackgroundView()
            
            transitionContent
            .opacity(fadeIn ? 1 : 0)
        }
        .onAppear {
            let requestID = request.id

            // Fade in
            withAnimation(.easeIn(duration: 1.0)) {
                fadeIn = true
                opacity = 1
            }

            if request.action == .launch {
                // Preserve the launch animation exactly as it was.
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                }
            } else {
                withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }

            // If session was already restored before this view appeared, dismiss immediately
            if RLAppState.isSessionRestored {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissIfNeeded(requestID: requestID)
                }
            }

            // Failsafe: never leave users trapped on transition if the
            // request-scoped chart-ready signal is missed. This intentionally
            // bypasses chart readiness after seven seconds while retaining the
            // request, authentication, landing-guild and minimum-time guards
            // in app state.
            let failsafe = DispatchWorkItem {
                guard !hasStartedDismiss else { return }
                guard RLAppState.canFinishTransitionAfterFailsafe(requestID: requestID) else {
                    return
                }
                dismissTransition(requestID: requestID)
            }
            failsafeWorkItem = failsafe
            DispatchQueue.main.asyncAfter(deadline: .now() + 7.0, execute: failsafe)
        }
        // Watch for chart ready - this is the main case for authenticated users with a guild
        .onChange(of: RLAppState.isChartReady) { oldValue, newValue in
            if newValue {
                dismissIfNeeded(requestID: request.id)
            }
        }
        // Watch for session restored - handles login screen and guild selector cases
        .onChange(of: RLAppState.isSessionRestored) { oldValue, newValue in
            if newValue {
                // Small delay then check what to do
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismissIfNeeded(requestID: request.id)
                }
            }
        }
        // Watch for guild changes (in case it loads after session restore)
        .onChange(of: RLAppState.currentGuild) { oldValue, newValue in
            if RLAppState.isSessionRestored && RLAppState.isAuthenticated {
                dismissIfNeeded(requestID: request.id)
            }
        }
        .onDisappear {
            pendingDismissWorkItem?.cancel()
            failsafeWorkItem?.cancel()
        }
    }

    @ViewBuilder
    private var transitionContent: some View {
        if request.action == .launch {
            VStack {
                Text(request.headline)
                    .font(.title2)
                    .foregroundColor(AppColors.greyText)

                Text(request.subject)
                    .font(AppFonts.title(size: 40))
                    .fontWeight(.heavy)
                    .foregroundColor(AppColors.whiteText)
            }
            .multilineTextAlignment(.center)
            .scaleEffect(scale)
            .opacity(opacity)
        } else {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 3)
                        .frame(width: 88, height: 88)

                    Circle()
                        .trim(from: 0.08, to: 0.76)
                        .stroke(
                            GuildCrestCatalog.color(for: request.guild?.crestColor),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(ringRotation))

                    transitionCrest
                }

                VStack(spacing: 6) {
                    Text(request.headline)
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppColors.whiteText)

                    Text(request.subject)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                }
                .padding(.horizontal, 24)
            }
            .opacity(opacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(request.headline) \(request.subject)")
        }
    }

    @ViewBuilder
    private var transitionCrest: some View {
        if let identity = request.guild, identity.usesInitialFallback {
            let tint = GuildCrestCatalog.color(for: identity.crestColor)
            Text(String(identity.fallbackInitial))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .frame(width: 72, height: 72)
                .background(Circle().fill(tint.opacity(0.20)))
                .accessibilityHidden(true)
        } else {
            GuildCrestView(
                imageUrl: request.guild?.imageURL,
                crestSymbol: request.guild?.crestSymbol,
                crestColor: request.guild?.crestColor,
                fallbackInitial: request.guild?.fallbackInitial ?? "G",
                size: 72
            )
        }
    }
    
    /// Check current state and dismiss if appropriate
    private func dismissIfNeeded(requestID: UUID) {
        guard !hasStartedDismiss else { return }
        guard RLAppState.transitionRequest.id == requestID else { return }
        guard RLAppState.isSessionRestored else { return }
        
        // Case 1: Not authenticated - dismiss to show login
        if !RLAppState.isAuthenticated {
            dismissTransitionWhenReady(requestID: requestID)
            return
        }
        
        // Case 2: Authenticated but no guild - dismiss to show guild selector
        if RLAppState.currentGuild == nil {
            dismissTransitionWhenReady(requestID: requestID)
            return
        }
        
        // Case 3: Authenticated with guild - only dismiss when chart is ready
        if RLAppState.isChartReady {
            dismissTransitionWhenReady(requestID: requestID)
            return
        }
        
        // Otherwise, keep waiting (chart still loading)
    }

    private func dismissTransitionWhenReady(requestID: UUID) {
        guard !hasStartedDismiss else { return }
        guard RLAppState.transitionRequest.id == requestID else { return }

        let remaining = RLAppState.transitionMinimumRemaining()
        guard remaining > 0 else {
            dismissTransition(requestID: requestID)
            return
        }

        pendingDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            dismissIfNeeded(requestID: requestID)
        }
        pendingDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
    }
    
    private func dismissTransition(requestID: UUID) {
        guard !hasStartedDismiss else { return }
        guard RLAppState.transitionRequest.id == requestID else { return }
        hasStartedDismiss = true
        
        // Start fading out
        withAnimation(.easeOut(duration: 0.8)) {
            fadeIn = false
            opacity = 0
        }
        
        // Finish transition during fade for smooth crossfade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            _ = RLAppState.finishTransition(requestID: requestID)
        }
    }
}
