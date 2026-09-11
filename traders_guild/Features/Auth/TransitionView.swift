//
//  TransitionView.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/09/2025.
//
//  The full-screen brand transition: launch and session restore, the end of
//  signup and onboarding, and every guild operation. One composition for all
//  of them — see `GuildTransitionPresentation` for what each one says.
//
//  Dismissal here is driven by app state (session restored, chart ready, the
//  request-scoped failsafe) and is deliberately untouched by presentation
//  changes.

import SwiftUI

struct TransitionView: View {
    /// Immutable for this view lifetime. SwiftUI replaces the view when a new
    /// request arrives, so callbacks owned by the outgoing view can never
    /// retarget themselves to the newer transition.
    let request: GuildTransitionRequest

    @EnvironmentObject var RLAppState: RLAppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            // One entrance. The launch overlay used to breathe at 1.1x for as
            // long as it was up, which on a slow chart load is several seconds
            // of a logo pulsing at the user; it now fades in once and holds.
            withAnimation(.easeIn(duration: 1.0)) {
                fadeIn = true
                opacity = 1
            }

            // The ring is the only continuous motion, and it is progress, not
            // decoration. Under Reduce Motion it is drawn but does not turn.
            if presentation.animatesRing {
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

    private var presentation: GuildTransitionPresentation {
        GuildTransitionPresentation(request: request, reduceMotion: reduceMotion)
    }

    /// The ring's colour: the guild's crest colour during an operation, the
    /// brand accent at launch.
    private var ringTint: Color {
        switch presentation.badge {
        case .appLogo: return AppColors.accentColor
        case .guildCrest: return GuildCrestCatalog.color(for: request.guild?.crestColor)
        }
    }

    /// One composition for every transition: a badge inside a progress ring,
    /// then the title and, for a guild operation, the guild's name.
    private var transitionContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppColors.whiteText.opacity(0.12), lineWidth: 3)
                    .frame(width: 88, height: 88)

                Circle()
                    .trim(from: 0.08, to: 0.76)
                    .stroke(ringTint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(ringRotation))

                transitionBadge
            }

            VStack(spacing: 6) {
                Text(presentation.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppColors.whiteText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                if let subtitle = presentation.subtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.greyText)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 24)
        }
        .opacity(opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    @ViewBuilder
    private var transitionBadge: some View {
        switch presentation.badge {
        case .appLogo:
            // The App Store icon, at a size that sits inside the ring with the
            // same breathing room the 72pt crest has. No shadow: it is on the
            // auth gradient, not a card, and a drop shadow inside a ring reads
            // as a smudge.
            AppLogoMark(size: 60, showsStroke: true, showsShadow: false)
        case .guildCrest:
            transitionCrest
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
