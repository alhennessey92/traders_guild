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
        #expect(MarkerSheetDetents.workspaceStart == .fraction(0.35))
    }
}

/// The controller drives a real binding; each step is applied on its own
/// main-queue turn.
@MainActor
@Suite(.serialized)
struct MarkerSheetDetentControllerTests {
    private final class Box { var selection: PresentationDetent = MarkerSheetDetents.working }

    private func controller() -> (MarkerSheetDetentController, Box) {
        let box = Box()
        let controller = MarkerSheetDetentController()
        controller.reduceMotion = true
        controller.attach(Binding(get: { box.selection }, set: { box.selection = $0 }))
        return (controller, box)
    }

    private func settle() async {
        for _ in 0..<12 { await Task.yield(); try? await Task.sleep(nanoseconds: 5_000_000) }
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
}
