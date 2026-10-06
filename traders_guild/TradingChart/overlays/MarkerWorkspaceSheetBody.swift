import SwiftUI

/// The authoring workspace inside the chart sheet. Owns no draft.
///
/// At the collapsed height the whole workspace stays mounted at its last
/// size, hidden, under either the active chart tool's bar or the resume dock.
/// Reopening restores the same screen with nothing re-laid out, and no
/// scroll, cursor or editor state is lost.
struct MarkerWorkspaceSheetBody<Panel: View>: View {
    @ObservedObject var placementState: MarkerPlacementState
    let isCollapsed: Bool
    let onResume: () -> Void
    let panel: Panel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Still at the collapsed-time size while the sheet grows back, so the
    /// workspace is revealed as it was rather than re-laid out (a scroll
    /// view resized through small heights loses its position).
    @State private var holdsFrozenSize = false
    @State private var releaseWork: DispatchWorkItem?
    /// The last expanded size, kept here and never published: writing it to
    /// the draft on every frame of a sheet resize redrew the whole chart each
    /// frame (the drag stutter reported in round 3).
    @State private var expandedSize = CGSize(width: 320, height: 400)

    init(placementState: MarkerPlacementState, isCollapsed: Bool,
         onResume: @escaping () -> Void, @ViewBuilder panel: () -> Panel) {
        self.placementState = placementState
        self.isCollapsed = isCollapsed
        self.onResume = onResume
        self.panel = panel()
    }

    private var frozen: Bool { isCollapsed || holdsFrozenSize }

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        GeometryReader { proxy in
            let resume = expandedSize
            ZStack(alignment: .top) {
                panel
                    .frame(width: frozen ? resume.width : proxy.size.width,
                           height: frozen ? resume.height : proxy.size.height)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        $0.opacity(isCollapsed ? 0 : 1)
                    }
                    .allowsHitTesting(!isCollapsed)
                    .accessibilityHidden(isCollapsed)
                if isCollapsed {
                    // Placed exactly as the app's own dock bar: 50pt controls
                    // in a 68pt bar at the bottom of the sheet.
                    collapsedBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)
                        .frame(height: 68)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        .transition(.opacity.animation(reduceMotion ? nil : .easeInOut(duration: 0.18)))
                }
            }
            .onAppear { record(proxy.size) }
            .onChange(of: proxy.size) { _, size in
                if holdsFrozenSize, !isCollapsed, size.height >= resume.height - 2 { release() }
                record(size)
            }
            .onChange(of: isCollapsed) { _, collapsed in
                if collapsed {
                    releaseWork?.cancel()
                    holdsFrozenSize = true
                } else {
                    // Grown back (or never will be, if the resumed height is
                    // smaller): let the workspace follow the sheet again.
                    let work = DispatchWorkItem { release() }
                    releaseWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
                }
            }
        }
        .clipped()
        .onAppear { MarkerSheetTrace.shared.dockVisible = isCollapsed }
        .onChange(of: isCollapsed) { _, value in
            MarkerSheetTrace.shared.dockVisible = value
            // Dragging the sheet back up from a Setup adjustment keeps the
            // levels where they were moved, as Done does.
            if !value { placementState.finishSetupAdjust() }
        }
    }

    private func release() {
        releaseWork?.cancel()
        releaseWork = nil
        holdsFrozenSize = false
    }

    /// The size the hidden workspace keeps while collapsed: its last
    /// expanded size.
    private func record(_ size: CGSize) {
        guard !frozen, size.height > 100, expandedSize != size else { return }
        expandedSize = size
    }

    @ViewBuilder
    private var collapsedBar: some View {
        if placementState.isWorkspaceChartToolActive {
            MarkerWorkspaceChartToolBar(placementState: placementState, onFinish: onResume)
        } else {
            MarkerGuidedCompactDock(placementState: placementState, onResume: onResume)
        }
    }
}

/// While a drawing or level is being worked on the chart, the sheet is this
/// capsule at the dock height, leaving the chart to the tool: what is being
/// worked, Cancel and Done. Its label opens the tool's options.
struct MarkerWorkspaceChartToolBar: View {
    @ObservedObject var placementState: MarkerPlacementState
    let onFinish: () -> Void

    private var isLevel: Bool { placementState.workspaceDestination == .levelEditor }
    /// A Setup's Take Profit and Stop Loss, moved on the chart.
    private var isSetup: Bool { placementState.isAdjustingSetupOnChart }
    /// Shows a value (a price, the Setup's levels) rather than an instruction.
    private var showsValue: Bool { isLevel || isSetup }

    private var title: String {
        if isSetup { return "Take Profit and Stop Loss" }
        if isLevel, let type = placementState.workspace.selectedLevel { return type.displayName }
        return placementState.activeDrawingWorkflowTool?.title ?? placementState.workspaceDestination.title
    }

    private var instruction: String {
        if isSetup { return "Drag the lines on the chart" }
        if let text = placementState.toolbarInstructionText { return text }
        return isLevel ? "Drag the level on the chart" : "Adjust it on the chart"
    }

    /// The live value (the Setup's levels, a level's price) or what to do.
    private var subtitle: String {
        if isSetup { return placementState.setupAdjustReadout }
        if isLevel { return MarkerGuidedFormat.displayPrice(Double(placementState.workspace.editorText)) }
        return instruction
    }

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        let canCommit = isSetup || placementState.workspaceCanCommit
        HStack(spacing: 8) {
            Button {
                // Back to the ticket with the levels where they were moved.
                if isSetup { placementState.finishSetupAdjust() }
                onFinish()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: showsValue ? "arrow.up.and.down" : "hand.draw")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(placementState.intent.color)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(placementState.intent.color.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.footnote.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(showsValue ? .system(.caption, design: .monospaced).weight(.semibold) : .caption2)
                            .foregroundColor(showsValue ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle). Show options")
            .accessibilityIdentifier("workspace.tool.options")
            Button {
                if isSetup { placementState.cancelSetupAdjust() } else { placementState.cancelWorkspaceEditor() }
                onFinish()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.whiteText.opacity(0.1)))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("workspace.tool.cancel")
            Button {
                if isSetup {
                    placementState.finishSetupAdjust()
                    onFinish()
                } else if placementState.commitWorkspaceEditor() {
                    onFinish()
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(canCommit ? .white : AppColors.greyText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(canCommit ? placementState.intent.color : AppColors.whiteText.opacity(0.06)))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canCommit)
            .accessibilityLabel("Done")
            .accessibilityIdentifier("workspace.tool.done")
        }
        .padding(.leading, 7)
        .padding(.trailing, 3)
        .frame(height: 50)
        .background(Capsule().fill(AppColors.chartSheetMainTabUnselectedBackground))
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityShowsLargeContentViewer()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.toolBar")
    }
}
