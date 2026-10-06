import Combine
import Foundation
import SwiftUI
import Testing
@testable import traders_guild

/// The workspace session owns navigation, cursor, scroll and editor staging.
/// The chart observes the draft, so none of these may be announced there:
/// only real draft edits redraw the chart.
@MainActor
struct MarkerWorkspaceSessionTests {
    private func draft(_ intent: RLMarkerIntent = .analysis) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.reset(to: intent, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: 100)
        state.note = "A"
        state.captureDraftBaseline()
        return state
    }

    /// Counts what an observer of the object would hear.
    private final class Heard {
        var count = 0
        var subscription: AnyCancellable?
    }

    private func listen<Object: ObservableObject>(to object: Object) -> Heard
    where Object.ObjectWillChangePublisher == ObservableObjectPublisher {
        let heard = Heard()
        heard.subscription = object.objectWillChange.sink { heard.count += 1 }
        return heard
    }

    @Test
    func movingAroundAndStagingEditsNeverRedrawTheChart() {
        let state = draft()
        let chart = listen(to: state)
        state.openContext()
        state.openWorkspace(.indicators)
        state.beginWorkspaceIndicator(IndicatorCatalogItem(type: .rsi))
        state.workspace.indicatorDraft?.intValues["period"] = "21"
        state.goBack()
        state.goBack()
        state.beginWorkspaceText(.noteEditor)
        state.workspace.editorText = "Range low holds"
        state.goBack()
        state.goBack()
        #expect(state.continueToReview())
        state.goBack()
        #expect(state.guidedStep == .details)
        #expect(chart.count == 0, "navigation and staged editor values are the workspace's")
        state.note = "A real edit"
        #expect(chart.count > 0, "a real draft edit still redraws the chart")
    }

    @Test
    func cursorAndScrollMemoryIsAnnouncedToNobody() {
        let state = draft()
        let chart = listen(to: state)
        let workspace = listen(to: state.workspaceSession)
        state.workspace.textSelections["guided.text"] = NSRange(location: 1, length: 0)
        state.workspace.textOffsets["guided.text"] = CGPoint(x: 0, y: 40)
        state.workspace.scrollAnchors[.details] = "title"
        #expect(chart.count == 0)
        #expect(workspace.count == 0, "read back only when a screen is rebuilt")
        #expect(state.workspace.textSelections["guided.text"] == NSRange(location: 1, length: 0))
        #expect(state.workspace.textOffsets["guided.text"] == CGPoint(x: 0, y: 40))
        #expect(state.workspace.scrollAnchors[.details] == "title")
        state.openContext()
        #expect(workspace.count > 0, "navigation is announced to the workspace's own views")
        #expect(chart.count == 0)
    }

    @Test
    func aScreenOpenedFromReviewReturnsToReview() {
        let state = draft()
        #expect(state.continueToReview())
        state.openContext()
        #expect(state.guidedStep == .context)
        state.beginWorkspaceText(.noteEditor)
        state.workspace.editorText = "Watch the range low"
        #expect(state.commitWorkspaceEditor())
        #expect(state.workspaceDestination == .context)
        state.goBack()
        #expect(state.guidedStep == .review, "back where the edit began")
        state.goBack()
        #expect(state.guidedStep == .details)
        #expect(state.component(.textNote) != nil, "the note was kept")
    }

    @Test
    func depthFollowsTheOneStack() {
        let state = draft()
        #expect(state.workspaceDepth == 0)
        state.openContext()
        #expect(state.workspaceDepth == 1)
        state.openWorkspace(.indicators)
        #expect(state.workspaceDepth == 2)
        state.openWorkspace(.indicators)
        #expect(state.workspaceDepth == 2, "the same screen is never stacked twice")
        state.goBack()
        state.goBack()
        #expect(state.workspaceDepth == 0)
        #expect(state.workspaceDestination == .details)
    }

    @Test
    func eachDraftStartsWithAFreshWorkspace() {
        let state = draft()
        state.openContext()
        state.workspace.textSelections["guided.text"] = NSRange(location: 3, length: 0)
        state.endGuidedFlow()
        #expect(state.guidedStep == nil)
        #expect(!state.isGuidedFlowActive)
        #expect(state.workspace.path == [.details])
        state.prepareGuidedFlow()
        #expect(state.guidedStep == .details)
        #expect(state.workspace.textSelections.isEmpty, "no cursor carried into a new draft")
    }

    @Test
    func typeChangesAndRefusedLevelsReturnStraightToDetails() {
        let state = draft()
        #expect(state.continueToReview())
        state.backToDetails()
        #expect(state.workspace.path == [.details])
        state.openContext()
        state.openWorkspace(.timeframes)
        state.openTypeChooser()
        #expect(state.workspace.path == [.details])
    }
}
