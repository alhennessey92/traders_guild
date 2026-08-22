import SwiftUI

// MARK: - Tutorial Overlay View

/// Full-screen overlay that dims the app and highlights specific UI elements
/// with a spotlight cutout. Displays a glassmorphic tooltip card with step info
/// and navigation controls (Back / Next / Skip).
///
/// Presented via a transparent `UIWindow` so it sits above
/// the `.sheet()` bottom panel and covers the entire screen.
struct TutorialOverlayView: View {
    @ObservedObject var tutorialManager: TutorialManager

    // MARK: - Animation State

    @State private var pulseScale: CGFloat = 1.0
    @State private var cardHeight: CGFloat = 0

    // MARK: - Constants

    private let spotlightPadding: CGFloat = 16
    private let cardSpotlightGap: CGFloat = 28
    private let screenEdgePadding: CGFloat = 16

    // MARK: - Body

    var body: some View {
        let step = tutorialManager.currentStep
        let spotlightRect = tutorialManager.currentSpotlightRect
        let screen = PlatformScreen.bounds
        let visible = tutorialManager.showSpotlight

        ZStack {
            // MARK: Layer 1 — Dimming mask with spotlight cutout
            dimmingLayer(spotlightRect: spotlightRect)

            // MARK: Layer 2 — Spotlight border ring (always present, opacity-controlled)
            if let rect = spotlightRect {
                spotlightRing(rect: rect)
                    .opacity(visible ? 1 : 0)
            }

            // MARK: Layer 3 — Tooltip card (always present, opacity-controlled)
            cardContent(step: step, spotlightRect: spotlightRect, screen: screen)
                .opacity(visible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - Card Content (positioned)

    /// Whether this step shows a bottom-sheet spotlight but the card should show an icon
    /// (conceptual info steps that happen to spotlight the sheet area).
    private func isSheetInfoStep(_ step: TutorialStep) -> Bool {
        step.requiredSheetTab != nil
    }

    @ViewBuilder
    private func cardContent(step: TutorialStep, spotlightRect: CGRect?, screen: CGRect) -> some View {
        let cardWidth = min(screen.width - 48, 360.0)
        let showIcon = spotlightRect == nil || isSheetInfoStep(step) || step == .chart

        if spotlightRect == nil {
            if step.spotlightKey == nil {
                // Centered info card — no spotlight, use Spacer-based centering
                VStack(spacing: 0) {
                    Spacer()
                    cardBody(step: step, showIcon: showIcon, cardWidth: cardWidth)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            // Spotlight card — position absolutely relative to the spotlight rect
            cardBody(step: step, showIcon: showIcon, cardWidth: cardWidth)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { cardHeight = geo.size.height }
                            .onChange(of: step) { _, _ in
                                DispatchQueue.main.async {
                                    cardHeight = geo.size.height
                                }
                            }
                    }
                )
                .position(
                    x: screen.midX,
                    y: cardYPosition(step: step, spotlightRect: spotlightRect!, screen: screen)
                )
        }
    }

    // MARK: - Card Y Position (absolute)

    /// Calculates the Y center position for the tooltip card so it sits
    /// below or above the spotlight with proper spacing, clamped to screen bounds.
    private func cardYPosition(step: TutorialStep, spotlightRect: CGRect, screen: CGRect) -> CGFloat {
        let spotlightTop = spotlightRect.minY - spotlightPadding / 2
        let estimatedCardHeight = max(cardHeight, 200) // fallback estimate
        let halfCard = estimatedCardHeight / 2
        let safeTop = screen.minY + screenEdgePadding + 50 // account for status bar
        let safeBottom = screen.maxY - screenEdgePadding - 30 // account for home indicator
        let gap = cardSpotlightGap + step.extraCardGap

        // Full-width spotlight steps extend to screen bottom — always place card above
        if step.fullWidthSpotlight {
            let adjustedTop = spotlightTop - step.spotlightExtraTopPadding
            let aboveY = adjustedTop - gap - halfCard
            return max(aboveY, safeTop + halfCard)
        }

        let spotlightBottom = spotlightRect.maxY + spotlightPadding / 2

        // Try to place below the spotlight first
        let belowY = spotlightBottom + gap + halfCard
        if belowY + halfCard <= safeBottom {
            return belowY
        }

        // If it doesn't fit below, try above
        let aboveY = spotlightTop - gap - halfCard
        if aboveY - halfCard >= safeTop {
            return aboveY
        }

        // If neither fits perfectly, pick the side with more space and clamp
        let spaceBelow = safeBottom - spotlightBottom
        let spaceAbove = spotlightTop - safeTop

        if spaceBelow >= spaceAbove {
            return min(belowY, safeBottom - halfCard)
        } else {
            return max(aboveY, safeTop + halfCard)
        }
    }

    // MARK: - Card Body

    private func cardBody(step: TutorialStep, showIcon: Bool, cardWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            stepProgressHeader(step: step)

            if showIcon {
                iconCircle(step: step)
            }

            Text(step.title)
                .font(.headline.bold())
                .foregroundColor(AppColors.whiteText)
                .multilineTextAlignment(.center)

            Text(step.message)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            navigationButtons(step: step)
        }
        .padding(20)
        .frame(width: cardWidth)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppColors.surfaceWhite15, AppColors.surfaceWhite00],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppColors.surfaceBlack20, radius: 15, x: 0, y: 8)
    }

    // MARK: - Dimming Layer

    private func dimmingLayer(spotlightRect: CGRect?) -> some View {
        let step = tutorialManager.currentStep
        let screen = PlatformScreen.bounds

        return Color.black.opacity(0.75)
            .ignoresSafeArea()
            .reverseMask {
                if let rect = spotlightRect, tutorialManager.showSpotlight {
                    if step.fullWidthSpotlight {
                        let topEdge = rect.minY - spotlightPadding / 2 - step.spotlightExtraTopPadding
                        let bottomEdge = fullWidthBottomEdge(rect: rect, screen: screen)
                        let cutoutHeight = bottomEdge - topEdge
                        let cutoutCenterY = topEdge + cutoutHeight / 2

                        Rectangle()
                            .frame(width: screen.width, height: cutoutHeight)
                            .position(x: screen.midX, y: cutoutCenterY)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: rect.width + spotlightPadding, height: rect.height + spotlightPadding)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
    }

    /// Bottom edge for full-width spotlights. Uses the content's actual bottom
    /// unless it's within a small threshold of the screen bottom — in which case
    /// it extends to the screen edge to avoid a sliver of dimming over the home-indicator area.
    private func fullWidthBottomEdge(rect: CGRect, screen: CGRect) -> CGFloat {
        let contentBottom = rect.maxY + spotlightPadding / 2
        let gap = screen.maxY - contentBottom
        return gap < 40 ? screen.maxY : contentBottom
    }

    // MARK: - Spotlight Ring

    private func spotlightRing(rect: CGRect) -> some View {
        let step = tutorialManager.currentStep
        let screen = PlatformScreen.bounds

        let ringWidth: CGFloat
        let ringHeight: CGFloat
        let ringX: CGFloat
        let ringY: CGFloat

        if step.fullWidthSpotlight {
            let topEdge = rect.minY - spotlightPadding / 2 - step.spotlightExtraTopPadding
            let bottomEdge = fullWidthBottomEdge(rect: rect, screen: screen)
            ringWidth = screen.width
            ringHeight = bottomEdge - topEdge
            ringX = screen.midX
            ringY = topEdge + ringHeight / 2
        } else {
            ringWidth = rect.width + spotlightPadding
            ringHeight = rect.height + spotlightPadding
            ringX = rect.midX
            ringY = rect.midY
        }

        let cornerRadius: CGFloat = step.fullWidthSpotlight ? 0 : 16

        return RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AppColors.accentColor.opacity(0.8),
                lineWidth: 2
            )
            .frame(width: ringWidth, height: ringHeight)
            .position(x: ringX, y: ringY)
            .scaleEffect(pulseScale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.03
                }
            }
            .onDisappear {
                pulseScale = 1.0
            }
    }

    // MARK: - Step Progress Header

    private func stepProgressHeader(step: TutorialStep) -> some View {
        VStack(spacing: 8) {
            Text("Step \(step.stepNumber) of \(TutorialStep.totalSteps)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.greyText)

            GeometryReader { barGeometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.symbolDetailCardFill)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accentColor)
                        .frame(
                            width: barGeometry.size.width * CGFloat(step.stepNumber) / CGFloat(TutorialStep.totalSteps),
                            height: 3
                        )
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Icon Circle

    private func iconCircle(step: TutorialStep) -> some View {
        ZStack {
            Circle()
                .fill(step.accentColor.opacity(0.16))
                .frame(width: 68, height: 68)
            Image(systemName: step.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(step.accentColor)
        }
    }

    // MARK: - Navigation Buttons

    private func navigationButtons(step: TutorialStep) -> some View {
        HStack(spacing: 10) {
            if step != .welcome {
                Button {
                    tutorialManager.previousStep()
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.symbolDetailCardFill)
                        )
                }
            }

            Button {
                tutorialManager.nextStep()
            } label: {
                Text(step == .complete ? "Finish" : "Next")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppColors.gradientBackgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.whiteText)
                    )
            }

            if step != .complete {
                Button {
                    tutorialManager.skipTutorial()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.symbolDetailCardFill)
                        )
                }
            }
        }
        .disabled(tutorialManager.isTransitioning)
        .opacity(tutorialManager.isTransitioning ? 0.5 : 1.0)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    AppColors.sheetBackground.opacity(0.85),
                    AppColors.drawerBackground.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Tutorial Window Manager

#if canImport(UIKit)

/// Manages a transparent `UIWindow` that hosts the tutorial overlay.
/// This window sits above all other content, including `.sheet()` presentations,
/// ensuring the tutorial overlay covers the entire screen.
@MainActor
final class TutorialWindowManager {
    static let shared = TutorialWindowManager()

    private var overlayWindow: UIWindow?
    private var hostingController: UIHostingController<AnyView>?

    private init() {}

    func show(tutorialManager: TutorialManager) {
        guard overlayWindow == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let overlayView = TutorialOverlayView(tutorialManager: tutorialManager)
        let hostingController = UIHostingController(rootView: AnyView(overlayView))
        hostingController.view.backgroundColor = .clear

        let window = UIWindow(windowScene: scene)
        window.rootViewController = hostingController
        window.windowLevel = .alert + 1
        window.isHidden = false
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        self.overlayWindow = window
        self.hostingController = hostingController
    }

    func dismiss() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        hostingController = nil
    }
}

#else

/// macOS stand-in.
///
/// The iOS tutorial cannot be ported, only rewritten. It teaches touch gestures —
/// pinch to zoom, long-press for the crosshair, drag to pan — and its coach marks
/// point at iPhone chrome: the bottom sheet and the slide-over drawers. On macOS
/// none of that exists: zoom is the scroll wheel, the crosshair follows the
/// pointer, and the shell is sidebars, a top bar and a pane grid. A ported
/// tutorial would teach interactions the Mac app does not have.
///
/// So this is a no-op until there is a Mac shell to attach a Mac-native
/// onboarding to. That is sequencing, not a scope cut: the call sites and the
/// TutorialManager state machine are untouched, so a real implementation drops in
/// here without changing anything else.
@MainActor
final class TutorialWindowManager {
    static let shared = TutorialWindowManager()
    private init() {}

    func show(tutorialManager: TutorialManager) {}
    func dismiss() {}
}

#endif

