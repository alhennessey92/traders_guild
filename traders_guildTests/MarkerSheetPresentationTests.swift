import SwiftUI
import UIKit
import Testing
@testable import traders_guild

/// The detent rules that keep the chart sheet presented through ordinary
/// workspace navigation (v1.5 workspace, P1):
/// R1 the selected detent is always one the sheet offers;
/// R2 detent identities never change: the workspace uses the app's own set;
/// R3 navigation never moves the selection;
/// R4 only explicit moves (open, collapse/resume, a user drag) do.
@MainActor
struct MarkerSheetPresentationTests {
    private func state(_ detents: Set<PresentationDetent>, _ selection: PresentationDetent) -> MarkerSheetDetentState {
        MarkerSheetDetentState(detents: detents, selection: selection)
    }

    /// Every step keeps the selection inside the set, and each changes only
    /// the set or the selection, so a selection change always animates.
    private func assertSafe(_ start: MarkerSheetDetentState, _ steps: [MarkerSheetDetentState],
                            reach target: MarkerSheetDetentState, sourceLocation: SourceLocation = #_sourceLocation) {
        var previous = start
        for (index, step) in steps.enumerated() {
            #expect(step.detents.contains(step.selection), "R1 at step \(index)", sourceLocation: sourceLocation)
            let setChanged = step.detents != previous.detents
            let selectionChanged = step.selection != previous.selection
            #expect(!(setChanged && selectionChanged), "one change per step at \(index)", sourceLocation: sourceLocation)
            if selectionChanged {
                #expect(previous.detents.contains(step.selection), "selection moves within offered detents", sourceLocation: sourceLocation)
            }
            previous = step
        }
        #expect((steps.last ?? start) == target, sourceLocation: sourceLocation)
    }

    @Test
    func sequencerKeepsTheSelectionOfferedForEveryTransition() {
        let standard = MarkerSheetDetents.standard
        let custom: Set<PresentationDetent> = [.height(140), MarkerSheetDetents.working]
        let cases: [(MarkerSheetDetentState, MarkerSheetDetentState)] = [
            (state(standard, MarkerSheetDetents.working), state(standard, MarkerSheetDetents.browse)),
            (state(standard, MarkerSheetDetents.browse), state(standard, MarkerSheetDetents.dock)),
            (state(standard, MarkerSheetDetents.dock), state(standard, MarkerSheetDetents.tall)),
            (state(custom, .height(140)), state(standard, MarkerSheetDetents.dock)),
            (state(standard, MarkerSheetDetents.tall), state(custom, MarkerSheetDetents.working)),
        ]
        for (start, target) in cases {
            assertSafe(start, MarkerSheetDetentSequencer.steps(from: start, to: target), reach: target)
        }
    }

    @Test
    func reachingTheSameStateTakesNoSteps() {
        let current = state(MarkerSheetDetents.standard, MarkerSheetDetents.working)
        #expect(MarkerSheetDetentSequencer.steps(from: current, to: current).isEmpty)
    }

    @Test
    func anUnofferedCurrentSelectionIsRepairedBeforeAnythingMoves() {
        let broken = state([MarkerSheetDetents.working], MarkerSheetDetents.dock)
        let target = state(MarkerSheetDetents.standard, MarkerSheetDetents.browse)
        let steps = MarkerSheetDetentSequencer.steps(from: broken, to: target)
        #expect(steps.first?.detents.contains(MarkerSheetDetents.dock) == true)
        for step in steps { #expect(step.detents.contains(step.selection)) }
        #expect(steps.last == target)
    }

    @Test
    func theWorkspaceUsesTheAppsOwnHeightsAndOpensSmall() {
        #expect(MarkerSheetDetents.standard == [.fraction(0.11), .fraction(0.35), .fraction(0.5), .fraction(0.9)])
        #expect(MarkerSheetDetents.workspaceStart == (MarkerSheetDetents.isCompactHeight ? .fraction(0.5) : .fraction(0.35)))
    }
}

/// The controller drives a real binding; each step is applied on its own
/// main-queue turn.
@MainActor
@Suite(.serialized)
struct MarkerSheetDetentControllerTests {
    private final class Box { var selection: PresentationDetent = MarkerSheetDetents.working }
    /// Each test's own keyboard: never the app-wide notification center.
    private let keyboardCenter = NotificationCenter()

    private func controller() -> (MarkerSheetDetentController, Box) {
        let box = Box()
        let controller = MarkerSheetDetentController(notificationCenter: keyboardCenter)
        controller.reduceMotion = true
        controller.attach(Binding(get: { box.selection }, set: { box.selection = $0 }))
        return (controller, box)
    }

    private func settle() async {
        for _ in 0..<12 { await Task.yield(); try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    private func keyboard(docked: Bool) {
        let screen = UIScreen.main.bounds
        let frame = CGRect(x: 0, y: docked ? screen.height - 336 : screen.height, width: screen.width, height: 336)
        keyboardCenter.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: frame])
        if !docked { keyboardCenter.post(name: UIResponder.keyboardDidHideNotification, object: nil) }
    }

    @Test
    func openingAMarkerStartsSmallWhereverTheSheetWas() async {
        for start in [MarkerSheetDetents.dock, MarkerSheetDetents.working, MarkerSheetDetents.tall] {
            let (sheet, box) = controller()
            box.selection = start
            sheet.enterAuthoring()
            await settle()
            #expect(box.selection == MarkerSheetDetents.browse, "from \(start)")
            #expect(sheet.detents == MarkerSheetDetents.standard, "the set never changes")
            #expect(sheet.mode == .authoring)
        }
    }

    @Test
    func collapseIsTheDockAndResumeReturnsToTheLastHeight() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = MarkerSheetDetents.tall
        sheet.selectionChanged(to: MarkerSheetDetents.tall)
        sheet.collapse()
        await settle()
        #expect(box.selection == MarkerSheetDetents.dock)
        #expect(sheet.isCollapsed(box.selection))
        sheet.resume()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
    }

    @Test
    func draggingDownToTheDockIsACollapseThatResumesToTheLastHeight() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = MarkerSheetDetents.working
        sheet.selectionChanged(to: MarkerSheetDetents.working)
        box.selection = MarkerSheetDetents.dock
        sheet.selectionChanged(to: MarkerSheetDetents.dock)
        #expect(sheet.isCollapsed(box.selection))
        sheet.resume()
        await settle()
        #expect(box.selection == MarkerSheetDetents.working)
    }

    @Test
    func leavingKeepsTheSheetWhereItIs() async {
        for height in [MarkerSheetDetents.dock, MarkerSheetDetents.browse, MarkerSheetDetents.tall] {
            let (sheet, box) = controller()
            sheet.enterAuthoring()
            await settle()
            box.selection = height
            sheet.selectionChanged(to: height)
            sheet.leaveAuthoring()
            await settle()
            #expect(sheet.mode == .standard)
            #expect(box.selection == height)
            #expect(sheet.detents == MarkerSheetDetents.standard)
            #expect(!sheet.isCollapsed(box.selection), "a standard dock is not a workspace collapse")
        }
    }

    @Test
    func aStrayUnofferedWriteIsMappedNotLeftToUIKit() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = .height(222)
        sheet.selectionChanged(to: .height(222))
        await settle()
        #expect(box.selection == MarkerSheetDetents.browse, "back to where Resume goes")
        #expect(sheet.detents.contains(box.selection))
    }

    @Test
    func preferTallGrowsButNeverExpandsTheDock() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        sheet.preferTall()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
        sheet.collapse()
        await settle()
        sheet.preferTall()
        await settle()
        #expect(box.selection == MarkerSheetDetents.dock, "a collapsed sheet stays collapsed")
    }

    // MARK: Typing

    @Test
    func typingNarrowsToTheHeightItIsAtThenFocusesAndRestoresAfterTheKeyboard() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        var focused = false
        #expect(!sheet.shouldBeginEditing { focused = true }, "focus waits for the sheet to settle")
        await settle()
        #expect(focused)
        #expect(sheet.detents == [MarkerSheetDetents.browse], "only the height it is at")
        #expect(box.selection == MarkerSheetDetents.browse, "nothing moved")
        #expect(sheet.shouldBeginEditing { }, "a second field focuses at once")
        keyboard(docked: true)
        await settle()
        #expect(sheet.detents == [MarkerSheetDetents.browse], "held while the keyboard is up")
        keyboard(docked: false)
        await settle()
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.browse, "and it stays where it is")
    }

    /// Owner, on device, 12 Oct 2026: typing from a small height held the
    /// sheet there; it could not be pulled up to see more.
    @Test
    func draggingTheHeaderUpWhileTypingTakesTheSheetToTheTop() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        keyboard(docked: true)
        await settle()
        #expect(sheet.detents == [MarkerSheetDetents.browse], "held while the keyboard is up")
        sheet.raiseWhileTyping()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
        #expect(sheet.detents == MarkerSheetDetents.standard, "every height, as typing from the top")
        keyboard(docked: false)
        await settle()
        #expect(!sheet.isTyping)
        #expect(box.selection == MarkerSheetDetents.tall, "it stays where the author took it")
    }

    @Test
    func aPullIsWatchedForOnlyWhileTheSheetHoldsOnTheKeyboard() async {
        let (sheet, _) = controller()
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        #expect(!sheet.watchesTypingDrift, "not while the keyboard rises")
        keyboard(docked: true)
        keyboardCenter.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        await settle()
        #expect(sheet.watchesTypingDrift)
        sheet.typingDrift(up: true)
        await settle()
        #expect(!sheet.watchesTypingDrift, "once, then it is the move's")
        keyboard(docked: false)
        await settle()
        #expect(!sheet.watchesTypingDrift)
    }

    @Test
    func draggingTheHeaderDownWhileTypingPutsTheKeyboardAway() async {
        let (sheet, box) = controller()
        var resigned = 0
        sheet.resignKeyboard = { resigned += 1 }
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        sheet.lowerWhileTyping()
        #expect(resigned == 0, "no keyboard yet, nothing to put away")
        keyboard(docked: true)
        await settle()
        sheet.lowerWhileTyping()
        #expect(resigned == 1)
        keyboard(docked: false)
        await settle()
        #expect(!sheet.isTyping)
        #expect(box.selection == MarkerSheetDetents.browse, "where typing began")
    }

    @Test
    func withoutADockedKeyboardEveryHeightComesBack() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await settle()
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.browse)
    }

    @Test
    func atTheDockFocusIsImmediate() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        sheet.collapse()
        await settle()
        #expect(sheet.shouldBeginEditing { }, "nothing to settle at the dock")
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.dock)
    }

    @Test
    func anUndockedKeyboardOffersEveryHeightAgain() async {
        let (sheet, _) = controller()
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        // A hardware keyboard's shortcut bar: full width, short, on screen.
        let screen = UIScreen.main.bounds
        keyboardCenter.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: screen.height - 55, width: screen.width, height: 55)])
        await settle()
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
    }

    @Test
    func collapsingWhileTypingPutsTheKeyboardAwayThenCollapses() async {
        let (sheet, box) = controller()
        var resigned = 0
        sheet.resignKeyboard = { resigned += 1 }
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        keyboard(docked: true)
        await settle()
        sheet.collapse()
        await settle()
        #expect(resigned == 1)
        #expect(box.selection == MarkerSheetDetents.browse, "nothing moves under the keyboard")
        #expect(sheet.detents == [MarkerSheetDetents.browse])
        // On its way down iOS may report a height of its own: not a restore.
        let screen = UIScreen.main.bounds
        keyboardCenter.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: screen.height, width: screen.width, height: 336)])
        box.selection = .height(400)
        sheet.selectionChanged(to: .height(400))
        await settle()
        #expect(box.selection == .height(400), "left to UIKit until the keyboard has gone")
        keyboardCenter.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        await settle()
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.dock)
        sheet.resume()
        await settle()
        #expect(box.selection == MarkerSheetDetents.browse, "resumes where typing began")
    }

    @Test
    func aCollapseWaitingOnTheKeyboardStillHappensIfItNeverReportsGoing() async {
        let (sheet, box) = controller()
        sheet.resignKeyboard = { }
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        keyboard(docked: true)
        await settle()
        sheet.collapse()
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        await settle()
        #expect(box.selection == MarkerSheetDetents.dock)
        #expect(sheet.detents == MarkerSheetDetents.standard)
    }

    @Test
    func resumingBeforeTheKeyboardHasGoneCancelsTheCollapse() async {
        let (sheet, box) = controller()
        sheet.resignKeyboard = { }
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        keyboard(docked: true)
        await settle()
        sheet.collapse()
        sheet.resume()
        keyboard(docked: false)
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        await settle()
        #expect(box.selection == MarkerSheetDetents.browse)
        #expect(sheet.detents == MarkerSheetDetents.standard)
    }

    @Test
    func collapsingWithoutAKeyboardIsImmediate() async {
        let (sheet, box) = controller()
        var resigned = 0
        sheet.resignKeyboard = { resigned += 1 }
        sheet.enterAuthoring()
        await settle()
        _ = sheet.shouldBeginEditing { }
        await settle()
        sheet.collapse()
        await settle()
        #expect(resigned == 0)
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.dock)
    }

    @Test
    func atTheTallestHeightTypingFocusesAtOnce() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = MarkerSheetDetents.tall
        sheet.selectionChanged(to: MarkerSheetDetents.tall)
        #expect(sheet.shouldBeginEditing { }, "nothing taller to jump to")
        #expect(!sheet.isTyping)
        #expect(sheet.detents == MarkerSheetDetents.standard)
    }

    @Test
    func aHeightUIKitReportsWhileTypingIsLeftAloneThenTheStartIsRestored() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = MarkerSheetDetents.working
        sheet.selectionChanged(to: MarkerSheetDetents.working)
        _ = sheet.shouldBeginEditing { }
        await settle()
        keyboard(docked: true)
        box.selection = .height(812)
        sheet.selectionChanged(to: .height(812))
        await settle()
        #expect(sheet.detents == [MarkerSheetDetents.working], "not repaired mid-typing")
        keyboard(docked: false)
        await settle()
        #expect(box.selection == MarkerSheetDetents.working, "back to where typing began")
        #expect(sheet.detents == MarkerSheetDetents.standard, "no foreign height ever offered")
    }

    @Test
    func atTheTopAHeightUIKitReportsIsLeftAloneUntilTheKeyboardGoes() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring()
        await settle()
        box.selection = MarkerSheetDetents.tall
        sheet.selectionChanged(to: MarkerSheetDetents.tall)
        #expect(sheet.shouldBeginEditing { })
        keyboard(docked: true)
        box.selection = .height(812)
        sheet.selectionChanged(to: .height(812))
        await settle()
        #expect(box.selection == .height(812), "UIKit's while the keyboard is up")
        #expect(sheet.detents == MarkerSheetDetents.standard, "nothing foreign offered")
        keyboard(docked: false)
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
        #expect(sheet.detents == MarkerSheetDetents.standard)
    }

    @Test
    func onlyFullWidthBottomAttachedKeyboardsAreDocked() {
        let screen = CGRect(x: 0, y: 0, width: 393, height: 852)
        #expect(MarkerSheetDetentController.isDocked(CGRect(x: 0, y: 516, width: 393, height: 336), screen: screen))
        #expect(!MarkerSheetDetentController.isDocked(CGRect(x: 80, y: 400, width: 220, height: 200), screen: screen))
        #expect(!MarkerSheetDetentController.isDocked(CGRect(x: 0, y: 852, width: 393, height: 336), screen: screen))
        #expect(!MarkerSheetDetentController.isDocked(CGRect(x: 0, y: 797, width: 393, height: 55), screen: screen))
    }
}
