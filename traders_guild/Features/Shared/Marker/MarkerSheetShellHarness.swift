#if DEBUG || TG_ISOLATED_DEV
import SwiftUI

/// Real ChartBottomSheet, Add view, tab controls, and presentation observer.
/// No user/guild/symbol is configured: loaders stop at their existing guards.
/// The chart VM is never initialized/configured for network or realtime work.
struct MarkerSheetShellHarness: View {
    @StateObject private var appState: RLAppState
    @StateObject private var chart: ChartViewModel
    @StateObject private var controls = ChartControlViewModel()
    @StateObject private var draft = MarkerPlacementState()
    @StateObject private var overlay = MarkerOverlayState()
    @StateObject private var timeframes = TimeframePanelManager()
    @StateObject private var sheetDetents = MarkerSheetDetentController()
    @State private var manager: MarkerManager
    @State private var selectedView: ChartBottomSheet.ChartView = .markers
    @State private var primaryTab: MarkerSheetPrimaryTab = .add
    @State private var selectedDetent: PresentationDetent = MarkerSheetDetents.working

    init() {
        let state = RLAppState(restoreSessionOnInit: false)
        let data = ChartDataManager()
        let model = ChartViewModel(appState: state, dataManager: data, api: RealAPIService())
        let viewer = MarkerLinkFixtures.member(9, username: "you")
        let manager = MarkerManager(userId: viewer.userId, guildId: MarkerLinkFixtures.uuid(2), currentUserMember: viewer)
        let candle = MarkerLinkFixtures.candles()[5]
        manager.markers = MarkerLinkFixtures.positioned([
            MarkerLinkFixtures.marker(1, author: "sam", intent: .analysis, candle: candle.timestamp,
                                      price: candle.close, title: "Fixture analysis")
        ])
        model.markerManager = manager
        _manager = State(initialValue: manager)
        _appState = StateObject(wrappedValue: state)
        _chart = StateObject(wrappedValue: model)
    }

    /// The surface on screen, in the words the shell test checks.
    private var route: String {
        if controls.isMarkerPlacementMode {
            return draft.isGuidedFlowActive ? "\(draft.workspaceDestination.rawValue)-\(draft.intent.rawValue)" : "placement"
        }
        if let viewed = chart.selectedMarkerForSheet?.id { return "view-\(viewed)" }
        return selectedView == .markers && primaryTab == .add ? "add" : selectedView.rawValue
    }
    private var isAuthoring: Bool {
        MarkerAvatarExperiment.isEnabled && controls.isMarkerPlacementMode && draft.isGuidedFlowActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fixture · real chart sheet · no account/backend")
            Text("\(route) · supported: \(sheetDetents.detents.contains(selectedDetent)) · mode: \(sheetDetents.mode.rawValue)")
                .accessibilityIdentifier("shell.policy")
            HStack(spacing: 12) {
                Button("Add") {
                    controls.cancelMarkerPlacement()
                    draft.endGuidedFlow()
                    chart.selectedMarkerForSheet = nil
                    selectedView = .markers
                    primaryTab = .add
                }.accessibilityIdentifier("shell.add")
                Button("Guide") { beginDraft() }.accessibilityIdentifier("shell.guide")
                Button("Legacy") {
                    draft.endGuidedFlow()
                }.accessibilityIdentifier("shell.legacy")
                Button("View") {
                    controls.cancelMarkerPlacement()
                    chart.selectedMarkerForSheet = manager.markers.first
                }.accessibilityIdentifier("shell.view")
                Button("Clear") { chart.selectedMarkerForSheet = nil }.accessibilityIdentifier("shell.clear")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundColor(AppColors.primaryForeground)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .onAppear { sheetDetents.attach($selectedDetent) }
        .onChange(of: isAuthoring) { _, authoring in
            if authoring { sheetDetents.enterAuthoring() }
            else { sheetDetents.leaveAuthoring() }
        }
        .sheet(isPresented: .constant(true)) {
            ChartBottomSheet(controlViewModel: controls, chartViewModel: chart,
                placementState: draft, markerOverlayState: overlay, timeframePanelManager: timeframes,
                sheetDetents: sheetDetents, selectedDetent: $selectedDetent,
                selectedView: $selectedView, markerPrimaryTab: $primaryTab)
                .environmentObject(appState)
                .modifier(MarkerSheetGeometryObserver(selection: selectedDetent, session: draft.workspaceSession,
                                                       route: { route }, mode: sheetDetents.mode.rawValue))
                .modifier(MarkerSheetDetentHost(controller: sheetDetents, selection: $selectedDetent, enabled: MarkerAvatarExperiment.isEnabled))
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.sheetBackground)
                .presentationBackgroundInteraction(.enabled)
                .presentationContentInteraction(.resizes)
                .interactiveDismissDisabled()
        }
    }

    private func beginDraft() {
        chart.selectedMarkerForSheet = nil
        let candle = MarkerLinkFixtures.candles()[5]
        draft.prepareGuidedFlow()
        draft.reset(to: .analysis, anchorTime: candle.timestamp, anchorPrice: candle.close)
        draft.captureDraftBaseline()
        controls.startMarkerPlacement(intent: .analysis)
    }
}
#endif
