import SwiftUI
import UIKit
import Testing
@testable import traders_guild

/// The detent rules that keep the chart sheet presented through ordinary
/// workspace navigation (v1.5 workspace, P1):
/// R1 the selected detent is always one the sheet offers;
/// R2 no detent changes height during a session;
/// R3 navigation never moves the selection;
/// R4 only explicit moves (entry/exit, collapse/resume, a user drag) do.
@MainActor
struct MarkerSheetPresentationTests {
    private let metrics = MarkerSheetDetentMetrics.make(availableHeight: 780, dynamicTypeSize: .large)

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
        let authoring = metrics.authoring
        let cases: [(MarkerSheetDetentState, MarkerSheetDetentState)] = [
            (state(standard, MarkerSheetDetents.working), state(authoring, MarkerSheetDetents.working)),
            (state(standard, MarkerSheetDetents.browse), state(authoring, MarkerSheetDetents.working)),
            (state(standard, MarkerSheetDetents.dock), state(authoring, MarkerSheetDetents.tall)),
            (state(authoring, MarkerSheetDetents.working), state(authoring, metrics.toolDetent)),
            (state(authoring, metrics.toolDetent), state(authoring, MarkerSheetDetents.tall)),
            (state(authoring, metrics.toolDetent), state(standard, MarkerSheetDetents.dock)),
            (state(authoring, MarkerSheetDetents.tall), state(standard, MarkerSheetDetents.tall)),
        ]
        for (start, target) in cases {
            assertSafe(start, MarkerSheetDetentSequencer.steps(from: start, to: target), reach: target)
        }
    }

    @Test
    func enteringFromHalfHeightOnlyChangesWhatIsOffered() {
        // From the Add tab or a marker detail at half height, the workspace
        // takes over without the selection ever changing.
        let steps = MarkerSheetDetentSequencer.steps(from: state(MarkerSheetDetents.standard, MarkerSheetDetents.working),
                                                     to: state(metrics.authoring, MarkerSheetDetents.working))
        #expect(!steps.isEmpty)
        #expect(steps.allSatisfy { $0.selection == MarkerSheetDetents.working })
    }

    @Test
    func reachingTheSameStateTakesNoSteps() {
        let current = state(metrics.authoring, MarkerSheetDetents.working)
        #expect(MarkerSheetDetentSequencer.steps(from: current, to: current).isEmpty)
    }

    @Test
    func anUnofferedCurrentSelectionIsRepairedBeforeAnythingMoves() {
        let broken = state(metrics.authoring, MarkerSheetDetents.dock)
        let target = state(metrics.authoring, metrics.toolDetent)
        let steps = MarkerSheetDetentSequencer.steps(from: broken, to: target)
        #expect(steps.first?.detents.contains(MarkerSheetDetents.dock) == true)
        for step in steps { #expect(step.detents.contains(step.selection)) }
        #expect(steps.last == target)
    }

    @Test
    func authoringDetentsAreFixedHeightsSharingTheStandardWorkingAndTall() {
        #expect(metrics.authoring == [metrics.toolDetent, MarkerSheetDetents.working, MarkerSheetDetents.tall])
        #expect(MarkerSheetDetents.standard.contains(MarkerSheetDetents.working))
        #expect(MarkerSheetDetents.standard.contains(MarkerSheetDetents.tall))
        #expect(metrics.toolDetent == .height(metrics.tool))
        #expect(metrics == MarkerSheetDetentMetrics.make(availableHeight: 780, dynamicTypeSize: .large))
        #expect(MarkerSheetDetents.standard == [.fraction(0.11), .fraction(0.35), .fraction(0.5), .fraction(0.9)])
    }

    @Test
    func metricsGrowForLargerTextAndShortScreensOpenSetupTall() {
        let accessible = MarkerSheetDetentMetrics.make(availableHeight: 780, dynamicTypeSize: .accessibility3)
        #expect(accessible.tool > metrics.tool)
        #expect(accessible.prefersTallSetup)
        #expect(!metrics.prefersTallSetup)
        #expect(MarkerSheetDetentMetrics.make(availableHeight: 600, dynamicTypeSize: .large).prefersTallSetup)
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
        controller.setAvailableHeight(780)
        controller.attach(Binding(get: { box.selection }, set: { box.selection = $0 }))
        return (controller, box)
    }

    private func settle() async {
        for _ in 0..<12 { await Task.yield(); try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    @Test
    func enteringFromHalfHeightKeepsTheSheetWhereItIs() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        #expect(box.selection == MarkerSheetDetents.working)
        #expect(sheet.detents == sheet.metrics.authoring)
        #expect(sheet.mode == .authoring)
    }

    @Test
    func collapseAndResumeReturnToTheLastExpandedChoice() async {
        let (sheet, box) = controller()
        box.selection = MarkerSheetDetents.tall
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        sheet.collapse()
        await settle()
        #expect(box.selection == sheet.toolDetent)
        #expect(sheet.isCollapsed(box.selection))
        sheet.resume()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
    }

    @Test
    func aUserDragIsRememberedAsTheResumeChoice() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        box.selection = MarkerSheetDetents.tall
        sheet.selectionChanged(to: MarkerSheetDetents.tall)
        sheet.collapse()
        await settle()
        sheet.resume()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
    }

    @Test
    func leavingAuthoringFromAToolLandsOnTheDock() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        sheet.collapse()
        await settle()
        sheet.leaveAuthoring()
        await settle()
        #expect(sheet.mode == .standard)
        #expect(sheet.detents == MarkerSheetDetents.standard)
        #expect(box.selection == MarkerSheetDetents.dock)
    }

    @Test
    func leavingAuthoringAtHalfHeightStaysThere() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        sheet.leaveAuthoring()
        await settle()
        #expect(box.selection == MarkerSheetDetents.working)
    }

    @Test
    func aStrayDockWriteDuringAuthoringBecomesACollapse() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        box.selection = MarkerSheetDetents.dock
        sheet.selectionChanged(to: MarkerSheetDetents.dock)
        await settle()
        #expect(box.selection == sheet.toolDetent)
        #expect(sheet.detents.contains(box.selection))
    }

    @Test
    func heightsAreFixedForTheSession() async {
        let (sheet, _) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        let fixed = sheet.metrics
        sheet.setAvailableHeight(500)
        sheet.enterAuthoring(intent: .setup, dynamicTypeSize: .accessibility2)
        await settle()
        #expect(sheet.metrics == fixed, "R2: a session keeps its identities")
    }

    @Test
    func setupOnAShortScreenOpensTall() async {
        let (sheet, box) = controller()
        sheet.setAvailableHeight(600)
        sheet.enterAuthoring(intent: .setup, dynamicTypeSize: .large)
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
    }

    @Test
    func preferTallGrowsFromHalfHeightButNeverShrinks() async {
        let (sheet, box) = controller()
        sheet.enterAuthoring(intent: .analysis, dynamicTypeSize: .large)
        await settle()
        sheet.preferTall()
        await settle()
        #expect(box.selection == MarkerSheetDetents.tall)
        sheet.collapse()
        await settle()
        sheet.preferTall()
        await settle()
        #expect(box.selection == sheet.toolDetent, "a collapsed sheet stays collapsed")
    }
}
