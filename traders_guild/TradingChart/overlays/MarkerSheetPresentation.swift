import SwiftUI
import UIKit

// MARK: - Vocabulary

/// The chart sheet's detents under the v1.5 experiment.
///
/// A native sheet whose *selected* detent leaves its detent set falls back to
/// another detent. The earlier policy gave the working state a measured
/// `.height` per screen and per intent, so ordinary navigation replaced the
/// selected identity and the sheet visibly dropped and re-rose. Every value
/// here is fixed for the life of an authoring session; navigation inside the
/// workspace never touches the sheet.
///
/// Typing uses the sheet's native keyboard expansion. Changing the sheet's
/// height around the keyboard was measured (P1 frame traces) to put the sheet
/// a frame out of place: UIKit applies such a change in a pass of its own,
/// outside the keyboard's animation. The native expansion is one smooth
/// motion each way and returns to the same detent.
enum MarkerSheetDetents {
    static let dock: PresentationDetent = .fraction(0.11)
    static let browse: PresentationDetent = .fraction(0.35)
    static let working: PresentationDetent = .fraction(0.5)
    static let tall: PresentationDetent = .fraction(0.9)
    /// Every surface that is not authoring, and the whole sheet with the
    /// experiment off. Identical to the established set.
    static let standard: Set<PresentationDetent> = [dock, browse, working, tall]
}

/// Heights chosen once when an authoring session starts. Starting points,
/// tuned from device and accessibility evidence; never changed mid-session.
struct MarkerSheetDetentMetrics: Equatable {
    /// The chart-tool and collapsed height, excluding the bottom safe area.
    var tool: CGFloat
    /// Short screens and accessibility text open a Setup tall.
    var prefersTallSetup: Bool

    static let standard = MarkerSheetDetentMetrics(tool: 140, prefersTallSetup: false)

    static func make(availableHeight: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Self {
        let height = availableHeight.isFinite && availableHeight > 100 ? availableHeight : 700
        let accessibility = dynamicTypeSize.isAccessibilitySize
        let tool: CGFloat = accessibility ? 184 : (dynamicTypeSize >= .xxLarge ? 156 : 140)
        return MarkerSheetDetentMetrics(tool: tool, prefersTallSetup: accessibility || height < 640)
    }

    var toolDetent: PresentationDetent { .height(tool) }
    /// Working and tall are the same identities the Add tab and a marker
    /// detail use, so entering the workspace from either moves nothing.
    var authoring: Set<PresentationDetent> { [toolDetent, MarkerSheetDetents.working, MarkerSheetDetents.tall] }
}

// MARK: - Sequencing

struct MarkerSheetDetentState: Equatable {
    var detents: Set<PresentationDetent>
    var selection: PresentationDetent
}

/// The only safe route between two detent states: grow the set to their
/// union, move the selection, then shrink to the target set. Each step changes
/// the set or the selection, never both, so whichever UIKit applies first the
/// selection is always a member, and a selection change always animates
/// (removing the selected detent instead makes UIKit snap).
enum MarkerSheetDetentSequencer {
    static func steps(from current: MarkerSheetDetentState, to target: MarkerSheetDetentState) -> [MarkerSheetDetentState] {
        var target = target
        if !target.detents.contains(target.selection) { target.detents.insert(target.selection) }
        var state = current
        var steps: [MarkerSheetDetentState] = []
        if !state.detents.contains(state.selection) {
            state.detents.insert(state.selection)
            steps.append(state)
        }
        let union = state.detents.union(target.detents)
        if union != state.detents {
            state.detents = union
            steps.append(state)
        }
        if state.selection != target.selection {
            state.selection = target.selection
            steps.append(state)
        }
        if state.detents != target.detents {
            state.detents = target.detents
            steps.append(state)
        }
        return steps
    }
}

// MARK: - Controller

/// Owns which detents the chart sheet offers and every programmatic move of
/// its selection while the experiment is on. The selection itself stays in
/// the host's state (the user drags it); all other writes go through here.
@MainActor
final class MarkerSheetDetentController: ObservableObject {
    enum Mode: String, Equatable { case standard, authoring }

    @Published private(set) var detents: Set<PresentationDetent> = MarkerSheetDetents.standard
    @Published private(set) var mode: Mode = .standard
    private(set) var metrics: MarkerSheetDetentMetrics = .standard
    /// Where Resume returns to: the last working or tall choice.
    private(set) var resumeDetent: PresentationDetent = MarkerSheetDetents.working
    private(set) var availableHeight: CGFloat = 0
    var reduceMotion = false

    private var selection: Binding<PresentationDetent>?
    private var queue: [MarkerSheetDetentState] = []
    private var isDraining = false
    private var applying = false

    func attach(_ binding: Binding<PresentationDetent>) { selection = binding }

    func setAvailableHeight(_ height: CGFloat) {
        guard height.isFinite, height > 100 else { return }
        availableHeight = height.rounded()
    }

    var currentSelection: PresentationDetent { selection?.wrappedValue ?? MarkerSheetDetents.dock }
    var toolDetent: PresentationDetent { metrics.toolDetent }
    var isAuthoring: Bool { mode == .authoring }

    func isCollapsed(_ selection: PresentationDetent) -> Bool {
        mode == .authoring && selection == metrics.toolDetent
    }

    private var planned: MarkerSheetDetentState {
        queue.last ?? MarkerSheetDetentState(detents: detents, selection: currentSelection)
    }

    // MARK: Authoring

    /// Placement under the guided flow began: the session's heights are fixed
    /// now. A working or tall choice already made (Add at half height, a
    /// marker detail) is kept, so entering is a no-op for UIKit.
    func enterAuthoring(intent: RLMarkerIntent, dynamicTypeSize: DynamicTypeSize, select: PresentationDetent? = nil) {
        if mode == .standard {
            metrics = .make(availableHeight: availableHeight, dynamicTypeSize: dynamicTypeSize)
        }
        mode = .authoring
        let current = planned.selection
        let target: PresentationDetent
        if let select {
            target = select
        } else if intent == .setup && metrics.prefersTallSetup {
            target = MarkerSheetDetents.tall
        } else if current == MarkerSheetDetents.working || current == MarkerSheetDetents.tall {
            target = current
        } else {
            target = MarkerSheetDetents.working
        }
        resumeDetent = target == metrics.toolDetent ? MarkerSheetDetents.working : target
        go(to: MarkerSheetDetentState(detents: metrics.authoring, selection: target))
    }

    /// A response turned into a Setup on a short screen: grow, never shrink.
    func preferTall() {
        guard mode == .authoring, planned.selection == MarkerSheetDetents.working else { return }
        resumeDetent = MarkerSheetDetents.tall
        go(to: MarkerSheetDetentState(detents: metrics.authoring, selection: MarkerSheetDetents.tall))
    }

    func leaveAuthoring() {
        guard mode != .standard else { return }
        mode = .standard
        let current = planned.selection
        let target = MarkerSheetDetents.standard.contains(current) ? current : MarkerSheetDetents.dock
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: target))
    }

    /// Show the chart: the collapsed workspace, or a chart tool's bar.
    func collapse() {
        guard mode == .authoring else { return }
        rememberResume(planned.selection)
        go(to: MarkerSheetDetentState(detents: metrics.authoring, selection: metrics.toolDetent))
    }

    func resume() {
        guard mode == .authoring else { return }
        go(to: MarkerSheetDetentState(detents: metrics.authoring, selection: resumeDetent))
    }

    /// The native selection changed: a user drag, or one of our own steps.
    func selectionChanged(to detent: PresentationDetent) {
        guard !applying else { return }
        if detents.contains(detent) {
            if mode == .authoring { rememberResume(detent) }
            return
        }
        // Something outside this controller wrote a detent the sheet does not
        // offer (an older code path setting the dock). Map it, never drop.
        switch mode {
        case .standard:
            go(to: MarkerSheetDetentState(detents: detents, selection: MarkerSheetDetents.dock))
        case .authoring:
            let target = detent == MarkerSheetDetents.dock ? metrics.toolDetent : resumeDetent
            go(to: MarkerSheetDetentState(detents: metrics.authoring, selection: target))
        }
    }

    private func rememberResume(_ detent: PresentationDetent) {
        if detent == MarkerSheetDetents.working || detent == MarkerSheetDetents.tall { resumeDetent = detent }
    }

    // MARK: Applying

    private func go(to target: MarkerSheetDetentState) {
        queue.append(contentsOf: MarkerSheetDetentSequencer.steps(from: planned, to: target))
        drain()
    }

    /// One step per main-queue turn, so SwiftUI hands each to UIKit before
    /// the next.
    private func drain() {
        guard !isDraining, !queue.isEmpty else { return }
        isDraining = true
        apply(queue.removeFirst())
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isDraining = false
            self.drain()
        }
    }

    private func apply(_ step: MarkerSheetDetentState) {
        applying = true
        defer { applying = false }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            if detents != step.detents { detents = step.detents }
            if let selection, selection.wrappedValue != step.selection { selection.wrappedValue = step.selection }
        }
    }
}

// MARK: - Host

/// Applied to the chart sheet's content. With the experiment off the sheet
/// keeps exactly its established detents and the controller is unused.
struct MarkerSheetDetentHost: ViewModifier {
    @ObservedObject var controller: MarkerSheetDetentController
    @Binding var selection: PresentationDetent
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if enabled {
            content
                .presentationDetents(controller.detents, selection: $selection)
                .onAppear {
                    controller.attach($selection)
                    controller.reduceMotion = reduceMotion
                }
                .onChange(of: reduceMotion) { _, value in controller.reduceMotion = value }
                .onChange(of: selection) { _, value in controller.selectionChanged(to: value) }
        } else {
            content.presentationDetents(MarkerSheetDetents.standard, selection: $selection)
        }
    }
}

// MARK: - Authoring sync

/// Hands the sheet to the guided workspace while it is authoring and back
/// afterwards. Attaches the host's selection first, so every move goes
/// through the controller.
struct MarkerSheetAuthoringSync: ViewModifier {
    let controller: MarkerSheetDetentController
    @Binding var selection: PresentationDetent
    let isAuthoring: Bool
    let intent: RLMarkerIntent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .onAppear {
                controller.attach($selection)
                if isAuthoring { controller.enterAuthoring(intent: intent, dynamicTypeSize: dynamicTypeSize) }
            }
            .onChange(of: isAuthoring) { _, authoring in
                if authoring {
                    controller.enterAuthoring(intent: intent, dynamicTypeSize: dynamicTypeSize)
                } else {
                    controller.leaveAuthoring()
                }
            }
    }
}

// MARK: - Container height

/// Reads the presenting container and its window, even when MainView ignores
/// safe areas. Window bounds are specific to this presentation, not UIScreen.
private struct MarkerSheetContainerProbe: UIViewRepresentable {
    let onMeasure: (CGFloat) -> Void
    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onMeasure = onMeasure
        return view
    }
    func updateUIView(_ view: ProbeView, context: Context) { view.onMeasure = onMeasure }

    final class ProbeView: UIView {
        var onMeasure: ((CGFloat) -> Void)?
        private var lastHeight: CGFloat = 0
        override func didMoveToWindow() { super.didMoveToWindow(); reportHeight() }
        override func layoutSubviews() { super.layoutSubviews(); reportHeight() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); reportHeight() }
        private func reportHeight() {
            guard let window else { return }
            let safeHeight = window.bounds.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom
            let height = min(bounds.height, safeHeight)
            guard height > 100, abs(height - lastHeight) > 2 else { return }
            lastHeight = height
            DispatchQueue.main.async { [weak self] in self?.onMeasure?(height) }
        }
    }
}

struct MarkerSheetContainerMeasure: ViewModifier {
    let controller: MarkerSheetDetentController
    func body(content: Content) -> some View {
        content.background {
            MarkerSheetContainerProbe(onMeasure: { controller.setAvailableHeight($0) })
                .ignoresSafeArea(.keyboard)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
