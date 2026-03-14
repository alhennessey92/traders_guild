import Foundation
import Testing
@testable import traders_guild

@MainActor
struct MarkerDrawingWorkflowTests {
    @Test
    func trendlineWorkflowTransitionsThroughPlacementAndEdit() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        state.startDrawingWorkflow(tool: .trendline)
        #expect(state.activeTool == .draw)
        #expect(state.activeSubTool == MarkerToolOption.drawTrendline.rawValue)
        #expect(state.drawingInteractionPhase == .placingFirstPoint)
        #expect(state.toolbarInstructionText == "Trendline: drag to 1st point, tap to set")
        #expect(state.drawingSession.tool == .trendline)
        #expect(state.drawingSession.isPanLocked)

        state.setDrawingFirstPoint(time: now, price: 1.2345)
        #expect(state.drawingInteractionPhase == .placingSecondPoint)
        #expect(state.pendingDrawingFirstPoint?.time == now)
        #expect(state.toolbarInstructionText == "Trendline: drag to 2nd point, tap to set")

        let draftId = state.addDrawingOverlayComponent(
            .drawingTrendline,
            payload: .drawingTrendline(
                TrendlinePayload(
                    startTime: now,
                    startPrice: 1.2345,
                    endTime: now.addingTimeInterval(60),
                    endPrice: 1.2355
                )
            )
        )
        #expect(draftId != nil)

        state.beginDrawingCommit()
        #expect(state.drawingInteractionPhase == .committing)
        #expect(state.toolbarInstructionText == "Saving...")

        if let draftId {
            state.beginEditingDrawing(draftId, tool: .trendline)
        }
        #expect(state.drawingInteractionPhase == .editing)
        #expect(state.activeDrawingWorkflowTool == .trendline)
        #expect(state.toolbarInstructionText == "Trendline: drag handles, tap chart to save")
        #expect(!state.drawingSession.isPanLocked)

        state.commitDrawingAndExit()
        #expect(state.drawingInteractionPhase == .idle)
        #expect(state.pendingDrawingFirstPoint == nil)
        #expect(state.editingDrawingId == nil)
        #expect(state.activeTool == nil)
        #expect(state.activeSubTool == nil)
    }

    @Test
    func quickAddZoneEquivalentEntersEditingAndCanExit() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        state.startDrawingWorkflow(tool: .zone)
        let draftId = state.addDrawingOverlayComponent(
            .drawingZone,
            payload: .drawingZone(
                ZonePayload(
                    topPrice: 1.12,
                    bottomPrice: 1.1,
                    startTime: now,
                    endTime: now.addingTimeInterval(120)
                )
            )
        )
        #expect(draftId != nil)

        if let draftId {
            state.beginEditingDrawing(draftId, tool: .zone)
        }
        #expect(state.drawingInteractionPhase == .editing)
        #expect(state.activeDrawingWorkflowTool == .zone)

        state.commitDrawingAndExit()
        #expect(state.drawingInteractionPhase == .idle)
        #expect(state.editingDrawingId == nil)
        #expect(state.activeTool == nil)
    }

    @Test
    func discardActiveDrawingRemovesDraftAndResetsWorkflow() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let draftId = state.addDrawingOverlayComponent(
            .drawingTrendline,
            payload: .drawingTrendline(
                TrendlinePayload(
                    startTime: now,
                    startPrice: 2.0,
                    endTime: now.addingTimeInterval(60),
                    endPrice: 2.2
                )
            )
        )
        #expect(draftId != nil)

        if let draftId {
            state.beginEditingDrawing(draftId, tool: .trendline)
            #expect(state.components.contains(where: { $0.id == draftId }))
        }

        state.discardActiveDrawingAndExit()
        #expect(state.drawingInteractionPhase == .idle)
        #expect(state.editingDrawingId == nil)
        #expect(state.activeTool == nil)
        if let draftId {
            #expect(!state.components.contains(where: { $0.id == draftId }))
        }
    }

    @Test
    func toolbarGuidanceUpdatesForAnnotationEditing() {
        let state = MarkerPlacementState()

        state.upsertComponent(.textNote, payload: .note(NotePayload(text: "Watch liquidity")))
        let noteId = state.component(.textNote)?.id
        #expect(noteId != nil)

        if let noteId {
            state.beginEditingDrawing(noteId, tool: .note)
        }
        #expect(state.toolbarInstructionText == "Note: drag to place, tap chart to save")

        state.beginDrawingCommit()
        #expect(state.toolbarInstructionText == "Saving...")

        state.upsertComponent(.reactionEmoji, payload: .reactionEmoji(EmojiPayload(emoji: ":)")))
        let emojiId = state.component(.reactionEmoji)?.id
        #expect(emojiId != nil)

        if let emojiId {
            state.beginEditingDrawing(emojiId, tool: .emoji)
        }
        #expect(state.toolbarInstructionText == "Emoji: drag to place, tap chart to save")
    }

    @Test
    func supportWorkflowUsesImmediatePlacementEditing() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.reset(to: .analysis, anchorTime: now, anchorPrice: 1.201)

        let draftId = state.activateImmediateHorizontalDrawing(tool: .support)
        #expect(draftId != nil)
        #expect(state.activeTool == .levels)
        #expect(state.activeSubTool == MarkerToolOption.levelSupport.rawValue)
        #expect(state.drawingInteractionPhase == .editing)
        #expect(state.toolbarInstructionText == "Support: drag handle, tap chart to save")
        #expect(!MarkerDrawingToolRegistry.definition(for: .support).requiresGuidePlacement)
        #expect(!state.drawingSession.isPanLocked)

        if let draftId {
            state.upsertComponent(
                .levelSupport,
                payload: .levelSupport(
                    LevelPayload(
                        price: 1.201,
                        label: "Demand",
                        colorHex: "#38BDF8",
                        lineStyle: .dotted
                    )
                )
            )
            state.beginEditingDrawing(draftId, tool: .support)
            #expect(state.toolbarInstructionText == "Demand: drag handle, tap chart to save")
            #expect(state.activeDrawingWorkflowTool == .support)
            #expect(state.drawingSession.editingDraftId == draftId)

            state.setDrawingLineStyle(.solid, for: draftId)
            if case let .levelSupport(payload)? = state.components.first(where: { $0.id == draftId })?.payload {
                #expect(payload.lineStyle == .solid)
                #expect(payload.colorHex == "#38BDF8")
            } else {
                Issue.record("Expected level.support payload")
            }
        }
    }

    @Test
    func horizontalLineWorkflowUsesPersistedLabelInstruction() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.reset(to: .analysis, anchorTime: now, anchorPrice: 1.2450)

        let draftId = state.activateImmediateHorizontalDrawing(tool: .horizontalLine)
        #expect(draftId != nil)
        #expect(state.activeTool == .draw)
        #expect(state.activeSubTool == MarkerToolOption.drawHorizontalLine.rawValue)
        #expect(state.drawingInteractionPhase == .editing)
        #expect(state.toolbarInstructionText == "Line: drag handle, tap chart to save")
        #expect(!MarkerDrawingToolRegistry.definition(for: .horizontalLine).requiresGuidePlacement)
        #expect(!state.drawingSession.isPanLocked)

        if let draftId {
            state.updateComponent(
                id: draftId,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: 1.2450,
                        label: "Liquidity Sweep"
                    )
                )
            )
            state.beginEditingDrawing(draftId, tool: .horizontalLine)
        }

        #expect(state.drawingInteractionPhase == .editing)
        #expect(state.activeDrawingWorkflowTool == .horizontalLine)
        #expect(state.toolbarInstructionText == "Liquidity Sweep: drag handle, tap chart to save")

        if let draftId {
            state.setHorizontalLineLabel("Breakout", for: draftId)
            if case let .drawingHorizontalLine(payload)? = state.components.first(where: { $0.id == draftId })?.payload {
                #expect(payload.label == "Breakout")
                #expect(payload.price == 1.2450)
            } else {
                Issue.record("Expected drawing.horizontal_line payload")
            }
        }

        state.commitDrawingAndExit()
        #expect(state.drawingInteractionPhase == .idle)
        #expect(state.editingDrawingId == nil)
        #expect(state.pendingDrawingFirstPoint == nil)
        #expect(state.activeTool == nil)
        #expect(state.activeSubTool == nil)
    }
}
