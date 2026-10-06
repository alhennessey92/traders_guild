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
/// The workspace offers exactly these heights too (owner, 6 Oct 2026): it
/// opens small so the marker is visible on the chart, collapses to the same
/// capsule-sized dock as the rest of the app, and starting or finishing a
/// marker never changes what the sheet offers, only where it sits.
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
    /// The whole sheet, with the experiment on or off. The established set.
    static let standard: Set<PresentationDetent> = [dock, browse, working, tall]
    /// Where a marker workspace opens: small, so the marker shows above it.
    static let workspaceStart: PresentationDetent = browse
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
    /// Where Resume returns to: the last height above the dock.
    private(set) var resumeDetent: PresentationDetent = MarkerSheetDetents.workspaceStart
    var reduceMotion = false

    private var selection: Binding<PresentationDetent>?
    private var queue: [MarkerSheetDetentState] = []
    private var isDraining = false
    private var applying = false

    func attach(_ binding: Binding<PresentationDetent>) { selection = binding }

    var currentSelection: PresentationDetent { selection?.wrappedValue ?? MarkerSheetDetents.dock }
    var isAuthoring: Bool { mode == .authoring }

    /// The workspace at the dock: its capsule (resume, or a chart tool's bar).
    func isCollapsed(_ selection: PresentationDetent) -> Bool {
        mode == .authoring && selection == MarkerSheetDetents.dock
    }

    private var planned: MarkerSheetDetentState {
        queue.last ?? MarkerSheetDetentState(detents: detents, selection: currentSelection)
    }

    // MARK: Authoring

    /// Placement under the guided flow began. The workspace opens small, so
    /// the marker it is about is visible on the chart above it.
    func enterAuthoring(select: PresentationDetent = MarkerSheetDetents.workspaceStart) {
        mode = .authoring
        resumeDetent = select == MarkerSheetDetents.dock ? MarkerSheetDetents.workspaceStart : select
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: select))
    }

    /// A response turned into a Setup on a short screen: grow, never shrink.
    func preferTall() {
        let current = planned.selection
        guard mode == .authoring, current == MarkerSheetDetents.browse || current == MarkerSheetDetents.working else { return }
        resumeDetent = MarkerSheetDetents.tall
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: MarkerSheetDetents.tall))
    }

    /// The sheet keeps whatever height it is at; it already offers only the
    /// app's standard heights.
    func leaveAuthoring() {
        guard mode != .standard else { return }
        mode = .standard
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: planned.selection))
    }

    /// Show the chart: the workspace's capsule at the dock.
    func collapse() {
        guard mode == .authoring else { return }
        rememberResume(planned.selection)
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: MarkerSheetDetents.dock))
    }

    func resume() {
        guard mode == .authoring else { return }
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: resumeDetent))
    }

    /// The native selection changed: a user drag, or one of our own steps.
    func selectionChanged(to detent: PresentationDetent) {
        guard !applying else { return }
        if detents.contains(detent) {
            if mode == .authoring { rememberResume(detent) }
            return
        }
        // Something wrote a detent the sheet does not offer. Map it to the
        // nearest meaning, never let the sheet fall back on its own.
        let target = mode == .authoring ? resumeDetent : MarkerSheetDetents.dock
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: target))
    }

    private func rememberResume(_ detent: PresentationDetent) {
        if detent != MarkerSheetDetents.dock, detents.contains(detent) { resumeDetent = detent }
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

    func body(content: Content) -> some View {
        content
            .onAppear {
                controller.attach($selection)
                if isAuthoring { controller.enterAuthoring() }
            }
            .onChange(of: isAuthoring) { _, authoring in
                if authoring {
                    controller.enterAuthoring()
                } else {
                    controller.leaveAuthoring()
                }
            }
    }
}
