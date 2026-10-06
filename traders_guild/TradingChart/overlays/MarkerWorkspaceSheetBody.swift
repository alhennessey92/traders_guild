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

    init(placementState: MarkerPlacementState, isCollapsed: Bool,
         onResume: @escaping () -> Void, @ViewBuilder panel: () -> Panel) {
        self.placementState = placementState
        self.isCollapsed = isCollapsed
        self.onResume = onResume
        self.panel = panel()
    }

    private var frozen: Bool { isCollapsed || holdsFrozenSize }

    var body: some View {
        GeometryReader { proxy in
            let resume = placementState.workspace.resumeSize
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
                    collapsedBar
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
        .onChange(of: isCollapsed) { _, value in MarkerSheetTrace.shared.dockVisible = value }
    }

    private func release() {
        releaseWork?.cancel()
        releaseWork = nil
        holdsFrozenSize = false
    }

    /// The size the hidden workspace keeps while collapsed: its last
    /// expanded size.
    private func record(_ size: CGSize) {
        guard !frozen, size.height > 100,
              placementState.workspace.resumeSize != size else { return }
        placementState.workspace.resumeSize = size
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
/// bar: what to do on the chart, and Cancel or Done. Both return to the
/// workspace screen the tool was opened from.
struct MarkerWorkspaceChartToolBar: View {
    @ObservedObject var placementState: MarkerPlacementState
    let onFinish: () -> Void

    private var isLevel: Bool { placementState.workspaceDestination == .levelEditor }

    private var title: String {
        if isLevel, let type = placementState.workspace.selectedLevel { return type.displayName }
        return placementState.activeDrawingWorkflowTool?.title ?? placementState.workspaceDestination.title
    }

    private var instruction: String {
        if let text = placementState.toolbarInstructionText { return text }
        return isLevel ? "Drag the level on the chart." : "Adjust it on the chart."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isLevel ? "arrow.up.and.down" : "hand.draw")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(placementState.intent.color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(placementState.intent.color.opacity(0.14)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(instruction)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if isLevel {
                    Text(MarkerGuidedFormat.displayPrice(Double(placementState.workspace.editorText)))
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .accessibilityLabel("Price \(MarkerGuidedFormat.displayPrice(Double(placementState.workspace.editorText)))")
                }
            }
            HStack(spacing: 10) {
                Button {
                    placementState.cancelWorkspaceEditor()
                    onFinish()
                } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workspace.tool.cancel")
                Button(action: onFinish) {
                    Label("Options", systemImage: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show options")
                .accessibilityIdentifier("workspace.tool.options")
                Spacer(minLength: 8)
                let enabled = placementState.workspaceCanCommit
                Button {
                    if placementState.commitWorkspaceEditor() { onFinish() }
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(enabled ? .white : AppColors.greyText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(enabled ? placementState.intent.color : AppColors.whiteText.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityIdentifier("workspace.tool.done")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.toolBar")
    }
}
