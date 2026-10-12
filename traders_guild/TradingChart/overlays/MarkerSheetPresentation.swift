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
/// Typing: UIKit throws a sheet that offers several detents up to its largest
/// when the keyboard appears (the "large jump" of round 3), but lifts a sheet
/// offering a single detent as one piece, that height sitting on the
/// keyboard. So while a workspace field has focus the sheet offers only the
/// height it is already at; nothing moves until the keyboard carries it.
/// Changing the height itself around the keyboard was measured (P1 traces)
/// to put the sheet a frame out of place, so the height never changes.
enum MarkerSheetDetents {
    static let dock: PresentationDetent = .fraction(0.11)
    static let browse: PresentationDetent = .fraction(0.35)
    static let working: PresentationDetent = .fraction(0.5)
    static let tall: PresentationDetent = .fraction(0.9)
    /// The whole sheet, with the experiment on or off. The established set.
    static let standard: Set<PresentationDetent> = [dock, browse, working, tall]
    /// A compact-height phone (SE class): the small height leaves too little
    /// to write in there.
    static var isCompactHeight: Bool { UIScreen.main.bounds.height < 700 }
    /// Where a marker workspace opens: small, so the marker shows above it;
    /// on a compact-height phone, the working height (the chart keeps the
    /// draft in view in the strip above).
    static var workspaceStart: PresentationDetent { isCompactHeight ? working : browse }
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
    private var completions: [() -> Void] = []
    private var isDraining = false
    private var applying = false

    /// A workspace field has focus and the sheet offers only its current height.
    private(set) var isTyping = false
    /// The keyboard has settled with the sheet holding its height on it: a
    /// pull on the sheet now means the author wants it moved (see
    /// `MarkerSheetDriftWatcher`).
    @Published private(set) var watchesTypingDrift = false
    /// The height typing began at, restored after the keyboard if UIKit
    /// reported a height of its own meanwhile.
    private var typingDetent: PresentationDetent?
    /// A docked software keyboard is on screen (any field, any height),
    /// until it has fully gone: its way down counts.
    private var keyboardShown = false
    /// Collapse was asked for with the keyboard up: done once it has gone.
    private var collapsesAfterKeyboard = false
    private var collapseFallback: DispatchWorkItem?
    /// Puts the keyboard away; tests replace it.
    var resignKeyboard: () -> Void = {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    /// The last selection that was one of the offered heights.
    private var lastOfferedSelection: PresentationDetent = MarkerSheetDetents.dock
    private var typingTimeout: DispatchWorkItem?
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    /// `notificationCenter` is injectable so tests simulate the keyboard privately.
    init(notificationCenter: NotificationCenter = .default) {
        center = notificationCenter
        observers.append(center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            MainActor.assumeIsolated { self?.keyboardWillChange(to: frame) }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.keyboardDidHide() }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.keyboardDidShow() }
        })
    }

    deinit { observers.forEach(center.removeObserver) }

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
        cancelPendingCollapse()
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
        isTyping = false
        cancelTypingTimeout()
        cancelPendingCollapse()
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: planned.selection))
    }

    /// Show the chart: the workspace's capsule at the dock.
    func collapse() {
        guard mode == .authoring else { return }
        rememberResume(typingDetent ?? planned.selection)
        if keyboardShown {
            // Moving the sheet while the keyboard animates snaps (measured),
            // and UIKit's own heights meanwhile would undo it: the keyboard
            // goes first, riding the sheet down, then the sheet collapses.
            guard !collapsesAfterKeyboard else { return }
            collapsesAfterKeyboard = true
            resignKeyboard()
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.finishPendingCollapse() }
            }
            collapseFallback = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
            return
        }
        isTyping = false
        typingDetent = nil
        cancelTypingTimeout()
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: MarkerSheetDetents.dock))
    }

    func resume() {
        guard mode == .authoring else { return }
        cancelPendingCollapse()
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: resumeDetent))
    }

    /// The keyboard has gone (or never reported going): collapse now.
    private func finishPendingCollapse() {
        guard collapsesAfterKeyboard else { return }
        cancelPendingCollapse()
        keyboardShown = false
        let started = typingDetent
        endTyping()
        restoreOfferedSelection(preferring: started)
        collapse()
    }

    private func cancelPendingCollapse() {
        collapsesAfterKeyboard = false
        collapseFallback?.cancel()
        collapseFallback = nil
    }

    /// The native selection changed: a user drag, or one of our own steps.
    func selectionChanged(to detent: PresentationDetent) {
        guard !applying else { return }
        if detents.contains(detent) {
            lastOfferedSelection = detent
            if mode == .authoring { rememberResume(detent) }
            // Pulled down to the dock while typing: the keyboard goes first,
            // then the sheet settles there, rather than springing back.
            if mode == .authoring, keyboardShown, detent == MarkerSheetDetents.dock, !collapsesAfterKeyboard {
                collapse()
            }
            return
        }
        // iOS 18 reports a height of its own while the keyboard pins a sheet
        // to the top: UIKit's to manage until the keyboard has gone.
        if keyboardShown || isTyping { return }
        // Something else wrote a height the sheet does not offer: take the
        // selection straight back to an offered one; never offer the foreign.
        restoreOfferedSelection()
    }

    private func restoreOfferedSelection(preferring preferred: PresentationDetent? = nil) {
        guard !detents.contains(currentSelection) else { return }
        let candidates = [preferred, mode == .authoring ? resumeDetent : nil, lastOfferedSelection, MarkerSheetDetents.dock]
        guard let target = candidates.compactMap({ $0 }).first(where: { detents.contains($0) }) else { return }
        queue.removeAll()
        apply(MarkerSheetDetentState(detents: detents, selection: target))
    }

    private func rememberResume(_ detent: PresentationDetent) {
        if detent != MarkerSheetDetents.dock, detents.contains(detent) { resumeDetent = detent }
    }

    // MARK: Typing

    /// A workspace text input is about to take focus. Returns true to let it
    /// focus now; false while the sheet first narrows to the height it is at
    /// (nothing moves), after which `focus` is called.
    func shouldBeginEditing(focus: @escaping () -> Void) -> Bool {
        // A hardware keyboard raises no software keyboard: its shortcut bar
        // is undocked (handled below) or nothing comes, and the timeout
        // offers every height again. Narrowing first is invisible either way.
        guard mode == .authoring, !isTyping else { return true }
        let current = planned.selection
        // At the dock nothing types; at the tallest height there is nothing
        // taller to jump to, so iOS keeps it (narrowing there makes iOS 18
        // report a height of its own and bounce on the way back).
        guard current != MarkerSheetDetents.dock, current != MarkerSheetDetents.tall else { return true }
        isTyping = true
        typingDetent = current
        go(to: MarkerSheetDetentState(detents: [current], selection: current), then: focus)
        // A floating or hardware keyboard never docks: offer the rest again.
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.endTyping() }
        }
        typingTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        return false
    }

    private func keyboardWillChange(to screenFrame: CGRect) {
        let screen = UIScreen.main.bounds
        let onScreen = screenFrame.height > 1 && screenFrame.minY < screen.maxY - 1
        // Leaving the screen still counts as shown until it has gone.
        if onScreen { keyboardShown = Self.isDocked(screenFrame, screen: screen) }
        guard isTyping else { return }
        if Self.isDocked(screenFrame, screen: screen) {
            cancelTypingTimeout()
        } else if onScreen {
            // Undocked or floating while on screen: no lift to protect.
            endTyping()
        }
    }

    /// The keyboard is up and the sheet sits on it: from here a pull on the
    /// sheet is the author's.
    private func keyboardDidShow() {
        guard mode == .authoring, isTyping, keyboardShown, detents.count == 1 else { return }
        watchesTypingDrift = true
    }

    /// The author pulled the sheet while it held its height on the keyboard
    /// (owner, on device, 12 Oct 2026: it could not be pulled up to see more,
    /// and sprang back when pulled down). Up takes it to the top, where typing
    /// offers every height, as typing from the top always has; down puts the
    /// keyboard away and it settles where typing began. Offering every height
    /// without the move made UIKit re-place the lifted sheet: a visible jump.
    func typingDrift(up: Bool) {
        watchesTypingDrift = false
        if up { raiseWhileTyping() } else { lowerWhileTyping() }
    }

    func raiseWhileTyping() {
        guard mode == .authoring, isTyping, keyboardShown,
              planned.selection != MarkerSheetDetents.tall else { return }
        watchesTypingDrift = false
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: MarkerSheetDetents.tall))
    }

    func lowerWhileTyping() {
        guard mode == .authoring, keyboardShown, !collapsesAfterKeyboard else { return }
        watchesTypingDrift = false
        resignKeyboard()
    }

    private func keyboardDidHide() {
        if collapsesAfterKeyboard { finishPendingCollapse(); return }
        keyboardShown = false
        let started = typingDetent
        endTyping()
        restoreOfferedSelection(preferring: started)
    }

    /// After the keyboard has gone (never during its animation), the sheet
    /// offers every height again; it stays where it is.
    private func endTyping() {
        watchesTypingDrift = false
        guard isTyping else { return }
        isTyping = false
        cancelTypingTimeout()
        let started = typingDetent
        typingDetent = nil
        guard mode == .authoring else { return }
        // A height UIKit reported meanwhile goes back to an offered one first.
        restoreOfferedSelection(preferring: started)
        go(to: MarkerSheetDetentState(detents: MarkerSheetDetents.standard, selection: planned.selection))
    }

    private func cancelTypingTimeout() {
        typingTimeout?.cancel()
        typingTimeout = nil
    }

    /// A full-width software keyboard attached to the bottom. A hardware
    /// keyboard's shortcut bar is too short to count.
    static func isDocked(_ frame: CGRect, screen: CGRect) -> Bool {
        guard frame.height >= 150, frame.minY < screen.maxY - 1 else { return false }
        return frame.width >= screen.width * 0.9 && frame.maxY >= screen.maxY - 1
    }

    // MARK: Applying

    private func go(to target: MarkerSheetDetentState, then completion: (() -> Void)? = nil) {
        queue.append(contentsOf: MarkerSheetDetentSequencer.steps(from: planned, to: target))
        if let completion { completions.append(completion) }
        drain()
    }

    /// One step per main-queue turn, so SwiftUI hands each to UIKit before
    /// the next; completions run a turn after the last.
    private func drain() {
        guard !isDraining else { return }
        guard !queue.isEmpty else {
            let pending = completions
            completions = []
            if !pending.isEmpty { DispatchQueue.main.async { pending.forEach { $0() } } }
            return
        }
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
        if step.detents.contains(step.selection) { lastOfferedSelection = step.selection }
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
                .environment(\.markerSheetDetents, controller)
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

private struct MarkerSheetDetentsKey: EnvironmentKey {
    static let defaultValue: MarkerSheetDetentController? = nil
}

extension EnvironmentValues {
    /// Lets a workspace text input settle the sheet before the keyboard
    /// rises. Nil outside the experiment's chart sheet.
    var markerSheetDetents: MarkerSheetDetentController? {
        get { self[MarkerSheetDetentsKey.self] }
        set { self[MarkerSheetDetentsKey.self] = newValue }
    }
}
