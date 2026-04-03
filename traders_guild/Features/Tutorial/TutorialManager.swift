import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let startTutorial = Notification.Name("startTutorial")
    static let tutorialSwitchSheetTab = Notification.Name("tutorialSwitchSheetTab")
}

// MARK: - Tutorial Manager

/// Drives the in-app guided tour: step progression, drawer control,
/// transition sequencing, and persistence via `RLAppState`.
@MainActor
final class TutorialManager: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published var showSpotlight: Bool = false
    @Published var isTransitioning: Bool = false

    /// Resolved spotlight frames in global coordinate space.
    /// Updated via `.onPreferenceChange(SpotlightFrameKey.self)` in MainView.
    @Published var spotlightFrames: [String: CGRect] = [:]

    // MARK: - Drawer Control Closures

    var openLeftDrawer: (() -> Void)?
    var closeLeftDrawer: (() -> Void)?
    var openRightDrawer: (() -> Void)?
    var closeRightDrawer: (() -> Void)?
    var closeAllDrawers: (() -> Void)?

    // MARK: - Sheet Control Closures

    /// Expands the bottom sheet and switches to the given tab name.
    var expandSheetToTab: ((String) -> Void)?
    /// Collapses the bottom sheet back to the minimized detent.
    var collapseSheet: (() -> Void)?

    // MARK: - App State Reference

    private weak var appState: RLAppState?

    // MARK: - Current Drawer Tracking

    private var currentDrawerState: TutorialStep.RequiredDrawer = .center

    // MARK: - Computed: Current Spotlight Rect

    /// Returns the resolved frame for the current step's spotlight target, if any.
    var currentSpotlightRect: CGRect? {
        guard let key = currentStep.spotlightKey else { return nil }
        return spotlightFrames[key]
    }

    // MARK: - Configure

    func configure(
        openLeftDrawer: @escaping () -> Void,
        closeLeftDrawer: @escaping () -> Void,
        openRightDrawer: @escaping () -> Void,
        closeRightDrawer: @escaping () -> Void,
        closeAllDrawers: @escaping () -> Void,
        expandSheetToTab: @escaping (String) -> Void,
        collapseSheet: @escaping () -> Void,
        appState: RLAppState
    ) {
        self.openLeftDrawer = openLeftDrawer
        self.closeLeftDrawer = closeLeftDrawer
        self.openRightDrawer = openRightDrawer
        self.closeRightDrawer = closeRightDrawer
        self.closeAllDrawers = closeAllDrawers
        self.expandSheetToTab = expandSheetToTab
        self.collapseSheet = collapseSheet
        self.appState = appState
    }

    // MARK: - Start / Stop

    func startTutorial(fromBeginning: Bool) {
        guard let userId = appState?.currentUser?.id else { return }

        if fromBeginning {
            currentStep = .welcome
        } else if let savedStep = appState?.getTutorialProgress(for: userId),
                  let step = TutorialStep(rawValue: savedStep) {
            currentStep = step
        } else {
            currentStep = .welcome
        }

        currentDrawerState = .center
        showSpotlight = false
        isActive = true

        // Delay showing spotlight slightly so the overlay has time to render
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            transitionToStep(to: currentStep)
        }
    }

    func skipTutorial() {
        guard let userId = appState?.currentUser?.id else { return }
        appState?.saveTutorialProgress(step: currentStep.rawValue, for: userId)
        showSpotlight = false
        isActive = false
        collapseSheet?()
        closeAllDrawers?()
        currentDrawerState = .center
    }

    func completeTutorial() {
        guard let userId = appState?.currentUser?.id else { return }
        appState?.markTutorialCompleted(for: userId)
        showSpotlight = false
        isActive = false
        collapseSheet?()
        closeAllDrawers?()
        currentDrawerState = .center
    }

    // MARK: - Navigation

    func nextStep() {
        guard !isTransitioning else { return }

        if currentStep == .complete {
            completeTutorial()
            return
        }

        guard let nextIndex = TutorialStep.allCases.firstIndex(of: currentStep)
                .map({ TutorialStep.allCases.index(after: $0) }),
              nextIndex < TutorialStep.allCases.endIndex else {
            completeTutorial()
            return
        }

        let target = TutorialStep.allCases[nextIndex]
        transitionToStep(to: target)
    }

    func previousStep() {
        guard !isTransitioning else { return }

        guard let currentIndex = TutorialStep.allCases.firstIndex(of: currentStep),
              currentIndex > TutorialStep.allCases.startIndex else { return }

        let prevIndex = TutorialStep.allCases.index(before: currentIndex)
        let target = TutorialStep.allCases[prevIndex]
        transitionToStep(to: target)
    }

    // MARK: - Transition Sequencing

    private func transitionToStep(to targetStep: TutorialStep) {
        let required = targetStep.requiredDrawer
        let requiredTab = targetStep.requiredSheetTab
        let needsFadeOut = showSpotlight

        isTransitioning = true

        // Phase 1: Fade out current content (if visible)
        if needsFadeOut {
            withAnimation(.easeOut(duration: 0.3)) {
                showSpotlight = false
            }
        }

        Task {
            // Wait for fade-out to complete
            if needsFadeOut {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }

            // Phase 2: Swap content while invisible
            currentStep = targetStep
            persistProgress()

            // Phase 3: Handle drawer/sheet changes while invisible
            if required == currentDrawerState {
                // Same drawer — just handle sheet tab
                if let tab = requiredTab {
                    expandSheetToTab?(tab)
                    try? await Task.sleep(nanoseconds: 350_000_000)
                } else {
                    collapseSheet?()
                }
            } else {
                // Different drawer — close current, open new

                // Collapse sheet when leaving center for a drawer step
                if required != .center {
                    collapseSheet?()
                }

                switch (currentDrawerState, required) {
                case (.leftOpen, .rightOpen):
                    closeLeftDrawer?()
                case (.rightOpen, .leftOpen):
                    closeRightDrawer?()
                case (.leftOpen, .center):
                    closeLeftDrawer?()
                case (.rightOpen, .center):
                    closeRightDrawer?()
                case (.center, _):
                    break
                default:
                    break
                }

                let closeDelay: UInt64 = (currentDrawerState != .center && required != .center) ? 400_000_000 : 0
                if closeDelay > 0 {
                    try? await Task.sleep(nanoseconds: closeDelay)
                }

                switch required {
                case .leftOpen:
                    openLeftDrawer?()
                case .rightOpen:
                    openRightDrawer?()
                case .center:
                    break
                }

                currentDrawerState = required

                // Wait for drawer spring animation to settle
                try? await Task.sleep(nanoseconds: 700_000_000)

                // Expand sheet to required tab after drawer settles
                if let tab = requiredTab {
                    expandSheetToTab?(tab)
                    try? await Task.sleep(nanoseconds: 400_000_000)
                } else {
                    collapseSheet?()
                }
            }

            if targetStep.spotlightKey != nil {
                await waitForSpotlightFrame(for: targetStep)
            }

            // Phase 4: Fade in new content
            withAnimation(.easeIn(duration: 0.35)) {
                showSpotlight = true
            }
            isTransitioning = false
        }
    }

    private func waitForSpotlightFrame(for step: TutorialStep) async {
        guard step.spotlightKey != nil else { return }

        let maxAttempts = 18
        for _ in 0..<maxAttempts {
            if currentStep == step, currentSpotlightRect != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 90_000_000)
        }
    }

    // MARK: - Persistence

    private func persistProgress() {
        guard let userId = appState?.currentUser?.id else { return }
        appState?.saveTutorialProgress(step: currentStep.rawValue, for: userId)
    }
}
