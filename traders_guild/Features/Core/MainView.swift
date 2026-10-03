//
//  MainView.swift
//  traders_guild
//
//  UPDATED VERSION - Integrated RLMessagingManager and RLRightDrawerViewModel
//  for live backend messaging (chatrooms and DMs).
//

import SwiftUI
import UIKit

// MARK: - Constants
enum LayoutConstants {
    static let drawerWidthRatio: CGFloat = 0.9
    static let drawerDismissThreshold: CGFloat = 100
    static let overlayOpacity: CGFloat = 0.4
    static let cornerRadius: CGFloat = 33
    static let shadowRadius: CGFloat = 8
}

enum AnimationConstants {
    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
}

/// Applies `changes` with every implicit animation suppressed.
///
/// Used for teardown that the user should never watch — closing the drawer and
/// its sheet stack after a guild is created, for instance. Those views are not
/// the destination and animating them out just shows the user a stack they
/// thought they had already left.
@MainActor
func withoutAnimation(_ changes: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, changes)
}

private enum MarkerAuthorProfileRoute: Identifiable {
    case currentUser
    case guildMember(RLGuildMemberDTO)

    var id: String {
        switch self {
        case .currentUser:
            return "current-user"
        case .guildMember(let member):
            return "member-\(member.userId.uuidString)"
        }
    }
}

private struct PendingMarkerNavigationConsumptionKey: Equatable {
    let requestId: UUID?
    let currentGuildId: UUID?
    let isChartReady: Bool
    let isTransitionVisible: Bool
    let isInteractionUnlocked: Bool
}

private struct PendingNotificationMarkerNavigation: Identifiable {
    let id = UUID()
    let guildId: UUID
    let payload: MarkerSharePayloadV1
    let shareOnOpen: Bool
}

/// Pure policy for the root's single SwiftUI sheet slot. Keeping pending work
/// in the decision is essential: it lets the persistent chart sheet finish
/// dismissing before the next presentation begins.
enum GuildArrivalPresentationPolicy {
    static func reservesSheetSlot(
        hasPendingCelebration: Bool,
        hasPresentedCelebration: Bool,
        hasPendingWelcome: Bool,
        hasPresentedWelcome: Bool,
        hasPendingProfile: Bool
    ) -> Bool {
        hasPendingCelebration
            || hasPresentedCelebration
            || hasPendingWelcome
            || hasPresentedWelcome
            || hasPendingProfile
    }

    static func canPresentProfile(
        hasPendingProfile: Bool,
        hasPendingWelcome: Bool,
        hasPresentedWelcome: Bool,
        hasPendingCelebration: Bool,
        hasPresentedCelebration: Bool
    ) -> Bool {
        hasPendingProfile
            && !hasPendingWelcome
            && !hasPresentedWelcome
            && !hasPendingCelebration
            && !hasPresentedCelebration
    }
}

// MARK: - Main View
struct MainView: View {
    // MARK: - Properties
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager       // NEW: chatrooms/DMs

    @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
    @StateObject private var rightDrawerViewModel = RLRightDrawerViewModel()  // NEW: Uses RLAppState

    /// The chart's persistent bottom sheet.
    ///
    /// Extracted from the `.sheet` closure: built inline it exceeded the
    /// type-checker's practical limit once the linked-marker callback joined
    /// the other three.
    private var chartBottomSheet: ChartBottomSheet {
        ChartBottomSheet(
            controlViewModel: chartControlVM,
            chartViewModel: chartViewModel,
            placementState: placementState,
            markerOverlayState: markerOverlayState,
            timeframePanelManager: timeframePanelManager,
            selectedDetent: $selectedDetent,
            selectedView: $chartSheetTab,
            guidedDiscardConfirmation: $showDiscardGuidedDraftConfirmation,
            onNavigateToMarker: { marker in
                leftDrawerViewModel.requestNavigationToMarker(marker)
            },
            onPlaceMarker: {
                NotificationCenter.default.post(name: .placeMarkerRequested, object: nil)
            },
            onViewingAuthorTap: { marker in
                if marker.author.userId == rlAppState.currentUser?.id {
                    markerAuthorProfileDetent = .fraction(0.6)
                    selectedViewingMarkerAuthorRoute = .currentUser
                } else {
                    selectedViewingMarkerAuthorRoute = .guildMember(marker.author)
                }
            },
            onNavigateToLinkedMarker: { target in
                navigateToLinkedMarker(target)
            }
        )
    }

    /// Travel to a thesis node that is not on the current chart.
    ///
    /// Links are same-guild and same-symbol by contract, so only the timeframe
    /// and the loaded history window can differ — the helper already handles
    /// both, and no symbol needs resolving. A named method rather than an
    /// inline closure because the sheet's construction expression is already at
    /// the type-checker's practical limit.
    @discardableResult
    private func navigateToLinkedMarker(_ target: MarkerNavigationTarget) -> Bool {
        let helper = MarkerNavigationHelper(
            chartViewModel: chartViewModel,
            gestureState: chartGestureState
        )
        return helper.navigateToMarker(target, resolvedSymbol: nil)
    }

    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    @Environment(\.scenePhase) private var scenePhase
    /// Matches `ThemeManager` / `ChartBottomSheet` — forces the chart sheet subtree to rebuild on theme change (`.sheet` often skips `ObservableObject` updates).
    @AppStorage("appTheme") private var appThemeStorage: AppTheme = .midGrey

    // MARK: - Chart State
    @StateObject private var chartControlVM = ChartControlViewModel()
    @StateObject private var chartDataManager = ChartDataManager()
    @StateObject private var chartViewModel: ChartViewModel
    /// Held, not observed — see [ChartStateOwner]. Reading `chartGestureState` here is fine; what
    /// must not happen is MainView subscribing to it, because pan publishes at frame rate.
    @StateObject private var chartStateOwner = ChartStateOwner()
    @StateObject private var indicatorPanelViewportStore = IndicatorPanelViewportStore()
    @StateObject private var placementState = MarkerPlacementState()
    @State private var showDiscardGuidedDraftConfirmation = false
    @StateObject private var markerOverlayState = MarkerOverlayState()

    private var chartGestureState: ChartGestureState { chartStateOwner.gestureState }

    @State private var fadeIn: Bool = false

    // MARK: - Walkthrough State
    /// Which presentation of the walkthrough is up, if any. First run and the
    /// Settings replay differ only in what happens afterwards.
    private enum WalkthroughPresentation: String, Identifiable {
        case firstRun
        case replay
        var id: String { rawValue }
    }
    @State private var walkthroughPresentation: WalkthroughPresentation?
    /// Holds the chart sheet down while the walkthrough (or the biometric offer
    /// that follows it) owns the single sheet slot — same idea as
    /// `guildArrivalReservesSheetSlot`.
    @State private var walkthroughSlotReserved: Bool = false
    /// Set by the sheet's buttons before it dismisses; nil on a swipe-down.
    @State private var walkthroughOutcome: WalkthroughOutcome?
    /// The outcome whose follow-up is waiting for the biometric offer to clear.
    @State private var pendingWalkthroughCTA: WalkthroughOutcome?
    @State private var didScheduleWalkthrough: Bool = false
    /// The chart sheet's tab, lifted out of `ChartBottomSheet` so the
    /// walkthrough's "Place your first marker" can land on the Markers tab.
    @State private var chartSheetTab: ChartBottomSheet.ChartView = .symbol

    // MARK: - Drawer State Management
    @State private var showLeftDrawer: Bool = false
    @State private var showRightDrawer: Bool = false
    @State private var isRightDrawerSearchFocused: Bool = false
    @State private var showOverlay: Bool = false
    @State private var leftDragTranslation: CGFloat = 0
    @State private var rightDragTranslation: CGFloat = 0
    
    // MARK: - Bottom Sheet State
    @State private var showBottomSheet: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.11)
    
    // MARK: - Sheet Overlay State
    @State private var showSheetOverlay: Bool = false
    @State private var dismissRightSheetsSignal: Bool = false
    @State private var dismissLeftSheetsSignal: Bool = false
    @State private var pendingNotificationDrawerRoute: NotificationDrawerRoute? = nil
    @State private var pendingNotificationMarkerNavigation: PendingNotificationMarkerNavigation?
    
    // MARK: - Indicator Panel State
    @State private var rsiPanelHeight: CGFloat = 120
    @State private var macdPanelHeight: CGFloat = 140
    @State private var stochasticPanelHeight: CGFloat = 120
    @State private var cciPanelHeight: CGFloat = 120
    @State private var williamsRPanelHeight: CGFloat = 120
    @State private var atrPanelHeight: CGFloat = 120
    @State private var volumePanelHeight: CGFloat = 120
    @State private var rsiPanelExpandedHeight: CGFloat = 120
    @State private var macdPanelExpandedHeight: CGFloat = 140
    @State private var stochasticPanelExpandedHeight: CGFloat = 120
    @State private var cciPanelExpandedHeight: CGFloat = 120
    @State private var williamsRPanelExpandedHeight: CGFloat = 120
    @State private var atrPanelExpandedHeight: CGFloat = 120
    @State private var volumePanelExpandedHeight: CGFloat = 120

    // MARK: - Timeframe Panel State
    @StateObject private var timeframePanelManager = TimeframePanelManager()
    @State private var selectedViewingMarkerAuthorRoute: MarkerAuthorProfileRoute?
    @State private var markerAuthorProfileDetent: PresentationDetent = .fraction(0.6)
    /// Presented (above the persistent chart bottom sheet) after a guild-visible marker is placed.
    @State private var markerSharePromptContext: MarkerShareContext?
    @State private var showDiscordSetupReminder = false
    /// The guild whose celebration / welcome is actually on screen.
    ///
    /// Separate from the pending values on `RLAppState`, because presentation
    /// waits for the transition to lift: the app state says *which* guild, this
    /// says *now*.
    @State private var celebratedGuild: RLGuildDTO?
    @State private var welcomedGuild: RLGuildDTO?
    @State private var presentedCelebrationRequestID: UUID?
    @State private var presentedWelcomeRequestID: UUID?

    // MARK: - Computed Properties
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
    }

    /// Marker timestamp for timeframe panels — uses viewed marker or placement anchor
    private var activeMarkerTimestamp: Date {
        if let viewedMarker = chartViewModel.selectedMarkerForSheet {
            return viewedMarker.marker.candleTimestamp
        }
        return placementState.anchorDraft?.payload.anchorTime ?? Date()
    }

    private var pendingMarkerNavigationConsumptionKey: PendingMarkerNavigationConsumptionKey {
        PendingMarkerNavigationConsumptionKey(
            requestId: rlAppState.pendingMarkerNavigationRequest?.id,
            currentGuildId: rlAppState.currentGuild?.id,
            isChartReady: rlAppState.isChartReady,
            isTransitionVisible: rlAppState.showingTransition,
            isInteractionUnlocked: !rlAppState.shouldPresentBiometricAppLock
        )
    }

    private var pendingNotificationMarkerNavigationConsumptionKey: PendingMarkerNavigationConsumptionKey {
        PendingMarkerNavigationConsumptionKey(
            requestId: pendingNotificationMarkerNavigation?.id,
            currentGuildId: rlAppState.currentGuild?.id,
            isChartReady: rlAppState.isChartReady,
            isTransitionVisible: rlAppState.showingTransition,
            isInteractionUnlocked: !rlAppState.shouldPresentBiometricAppLock
        )
    }

    private var hasPendingCurrentUserProfile: Bool {
        rlAppState.openCurrentUserProfileRequest != nil
    }

    private var guildArrivalReservesSheetSlot: Bool {
        GuildArrivalPresentationPolicy.reservesSheetSlot(
            hasPendingCelebration: rlAppState.pendingGuildCelebration != nil,
            hasPresentedCelebration: celebratedGuild != nil,
            hasPendingWelcome: rlAppState.pendingGuildWelcome != nil,
            hasPresentedWelcome: welcomedGuild != nil,
            hasPendingProfile: hasPendingCurrentUserProfile
        )
    }

    /// Intent color for timeframe panels — uses viewed marker or placement intent
    private var activeMarkerIntentColor: Color {
        if let viewedMarker = chartViewModel.selectedMarkerForSheet {
            return viewedMarker.intent.color
        }
        return placementState.intent.color
    }

    // Main-chart viewport + bottom-axis crosshair derivation used to live here. Both now sit in
    // TimeframePanelContainer, their only consumer — computing them here forced MainView to observe
    // ChartGestureState, and so to re-evaluate the whole app shell on every frame of a chart pan.

    private var indicatorPanelHeights: [CGFloat] {
        chartViewModel.indicatorManager.activeIndicators.activePanelTypes.map(indicatorPanelHeight(for:))
    }

    private var timeframePanelHeights: [CGFloat] {
        timeframePanelManager.panels.map(\.currentHeight)
    }

    private var chartFloatingOverlayClearance: CGFloat {
        guard chartPanelsTotalHeight > 0 else { return 0 }
        return ChartPanelReserveCalculator.panelStackChartUniformGap
    }

    private var chartControlRowPanelReserve: CGFloat {
        chartPanelLayout.controlRowReserve
    }

    private var chartPanelLayout: CombinedChartPanelLayout {
        ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: timeframePanelHeights,
            indicatorPanelHeights: indicatorPanelHeights
        )
    }

    private var chartPanelsTotalHeight: CGFloat {
        chartPanelLayout.totalReserve
    }

    private var chartPanelsBottomLabelStripReserve: CGFloat {
        chartPanelLayout.bottomBoundaryLabelReserve
    }

    private var chartPanelsMainChartXAxisClearance: CGFloat {
        chartPanelLayout.mainChartXAxisClearance
    }

    private var bottomTimeframeAxisPanelIndex: Int? {
        guard case .timeframe(let index) = chartPanelLayout.bottomBoundaryOwner else { return nil }
        return index
    }

    private var activeTimeframePanelSource: TimeframePanelSource {
        if chartControlVM.isMarkerPlacementMode {
            return .markerPlacement
        }
        if chartViewModel.selectedMarkerForSheet != nil {
            return .markerViewing
        }
        return .chartDefaults
    }

    private var activeTimeframeLegendEntries: [ActiveIndicatorLegendEntry] {
        TimeframeLegendComposer.entries(from: timeframePanelManager.panels)
    }

    private var indicatorPanelFingerprint: String {
        chartViewModel.indicatorManager.activeIndicators.activePanelTypes
            .map(\.rawValue)
            .joined(separator: "|")
    }

    private var placementTimeframeFingerprint: String {
        placementState.timeframeLinkDrafts
            .compactMap { draft -> String? in
                guard case let .timeframeLink(payload) = draft.payload else { return nil }
                return payload.timeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .sorted()
            .joined(separator: "|")
    }

    private var viewingTimeframeFingerprint: String {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return "" }
        return marker.marker.components
            .compactMap { component -> String? in
                guard component.componentTypeEnum == .timeframeLink,
                      case let .timeframeLink(payload) = component.payload else {
                    return nil
                }
                return payload.timeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .sorted()
            .joined(separator: "|")
    }

    private func indicatorPanelHeight(for panelType: PanelIndicatorType) -> CGFloat {
        switch panelType {
        case .rsi:
            return rsiPanelHeight
        case .macd:
            return macdPanelHeight
        case .stochastic:
            return stochasticPanelHeight
        case .cci:
            return cciPanelHeight
        case .williamsR:
            return williamsRPanelHeight
        case .atr:
            return atrPanelHeight
        case .volume:
            return volumePanelHeight
        }
    }

    private func indicatorPanelExpandedHeight(for panelType: PanelIndicatorType) -> CGFloat {
        switch panelType {
        case .rsi:
            return rsiPanelExpandedHeight
        case .macd:
            return macdPanelExpandedHeight
        case .stochastic:
            return stochasticPanelExpandedHeight
        case .cci:
            return cciPanelExpandedHeight
        case .williamsR:
            return williamsRPanelExpandedHeight
        case .atr:
            return atrPanelExpandedHeight
        case .volume:
            return volumePanelExpandedHeight
        }
    }

    private func defaultIndicatorPanelHeight(for panelType: PanelIndicatorType) -> CGFloat {
        panelType == .macd ? 140 : 120
    }

    private func setIndicatorPanelPresentation(_ state: ChartPanelPresentationState, for panelType: PanelIndicatorType) {
        switch panelType {
        case .rsi:
            rsiPanelHeight = state.currentHeight
            rsiPanelExpandedHeight = state.expandedHeight
        case .macd:
            macdPanelHeight = state.currentHeight
            macdPanelExpandedHeight = state.expandedHeight
        case .stochastic:
            stochasticPanelHeight = state.currentHeight
            stochasticPanelExpandedHeight = state.expandedHeight
        case .cci:
            cciPanelHeight = state.currentHeight
            cciPanelExpandedHeight = state.expandedHeight
        case .williamsR:
            williamsRPanelHeight = state.currentHeight
            williamsRPanelExpandedHeight = state.expandedHeight
        case .atr:
            atrPanelHeight = state.currentHeight
            atrPanelExpandedHeight = state.expandedHeight
        case .volume:
            volumePanelHeight = state.currentHeight
            volumePanelExpandedHeight = state.expandedHeight
        }
    }

    private func maxPanelHeight(for totalPanels: Int) -> CGFloat {
        if totalPanels >= 3 {
            return 140
        }
        return totalPanels >= 2 ? IndicatorManager.maxPanelHeightWith2Panels : IndicatorManager.maxPanelHeight
    }

    private func clampIndicatorPanelHeights(totalPanels: Int) {
        let clampedMaxHeight = maxPanelHeight(for: totalPanels)

        for panelType in PanelIndicatorType.allCases {
            setIndicatorPanelPresentation(
                ChartPanelPresentationPolicy.clamped(
                    currentHeight: indicatorPanelHeight(for: panelType),
                    expandedHeight: indicatorPanelExpandedHeight(for: panelType),
                    minHeight: IndicatorManager.minPanelHeight,
                    maxHeight: clampedMaxHeight
                ),
                for: panelType
            )
        }
    }

    private func indicatorPanelTypes(from fingerprint: String) -> Set<PanelIndicatorType> {
        Set(
            fingerprint
                .split(separator: "|")
                .compactMap { PanelIndicatorType(rawValue: String($0)) }
        )
    }

    private func reconcileIndicatorPanelPresentation(oldFingerprint: String, newFingerprint: String) {
        let previouslyActive = indicatorPanelTypes(from: oldFingerprint)
        let currentlyActive = chartViewModel.indicatorManager.activeIndicators.activePanelTypes
        let totalPanels = timeframePanelManager.activePanelCount + currentlyActive.count
        let clampedMaxHeight = maxPanelHeight(for: totalPanels)

        for panelType in currentlyActive where !previouslyActive.contains(panelType) {
            indicatorPanelViewportStore.reset(panelType)
            guard ChartPanelReserveCalculator.isCollapsedPanelHeight(indicatorPanelHeight(for: panelType)) else {
                continue
            }
            setIndicatorPanelPresentation(
                ChartPanelPresentationPolicy.restoredActiveHeight(
                    currentHeight: indicatorPanelHeight(for: panelType),
                    expandedHeight: indicatorPanelExpandedHeight(for: panelType),
                    defaultHeight: defaultIndicatorPanelHeight(for: panelType),
                    minHeight: IndicatorManager.minPanelHeight,
                    maxHeight: clampedMaxHeight
                ),
                for: panelType
            )
        }

        clampChartPanelHeightsForCurrentMode()
    }

    private func clampChartPanelHeightsForCurrentMode() {
        let totalPanels =
            timeframePanelManager.activePanelCount
            + chartViewModel.indicatorManager.activeIndicators.activePanelTypes.count
        clampIndicatorPanelHeights(totalPanels: totalPanels)
        timeframePanelManager.clampPanels(for: activeTimeframePanelSource, totalPanels: totalPanels)
    }

    // MARK: - Initialization
    init() {
        let dataManager = ChartDataManager()
        _chartDataManager = StateObject(wrappedValue: dataManager)
        // ChartViewModel will be properly initialized in onAppear with rlAppState
        // For now, create a temporary app state without session side effects.
        _chartViewModel = StateObject(wrappedValue: ChartViewModel(
            appState: RLAppState(restoreSessionOnInit: false),
            dataManager: dataManager,
            api: RealAPIService()
        ))
    }
    
    // MARK: - Body
    var body: some View {
        if let user = rlAppState.currentUser,
           rlAppState.currentGuild != nil {
            ZStack {
                // MARK: - Main Content Layer
                mainContentStack
                    .disabled(showLeftDrawer || showRightDrawer)
                
                // MARK: - Chart Panels Overlay (Timeframe + Indicator)
                // Positioned ABOVE main content, BELOW bottom sheet
                // allowsHitTesting only on panels themselves (not the spacer above)
                // so chart controls beneath remain tappable
                // Visible in placement/viewing so linked panel indicators remain visible.
                if chartViewModel.indicatorManager.shouldShowAnyPanel || timeframePanelManager.hasActivePanels {
                    VStack(spacing: 0) {
                        Spacer()
                            .allowsHitTesting(false)

                        // Timeframe panels (above indicator panels)
                        TimeframePanelContainer(
                            timeframePanelManager: timeframePanelManager,
                            gestureState: chartGestureState,
                            chartData: chartViewModel.dataManager,
                            markerTimestamp: activeMarkerTimestamp,
                            intentColor: activeMarkerIntentColor,
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            mainChartTimeframeSeconds: chartViewModel.currentTimeframe.seconds,
                            showMarkerLine: chartViewModel.selectedMarkerForSheet != nil || placementState.anchorDraft != nil,
                            indicatorPanelCount: chartViewModel.indicatorManager.activeIndicators.activePanelTypes.count,
                            bottomAxisPanelIndex: bottomTimeframeAxisPanelIndex,
                            formatPrice: { chartViewModel.dataManager.formatPrice($0) }
                        )

                        // Indicator panels
                        IndicatorPanelContainer(
                            indicatorManager: chartViewModel.indicatorManager,
                            chartData: chartViewModel.dataManager,
                            gestureState: chartGestureState,
                            viewportStore: indicatorPanelViewportStore,
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            timeframe: chartViewModel.currentTimeframe,
                            timeframePanelCount: timeframePanelManager.activePanelCount,
                            rsiPanelHeight: $rsiPanelHeight,
                            macdPanelHeight: $macdPanelHeight,
                            stochasticPanelHeight: $stochasticPanelHeight,
                            cciPanelHeight: $cciPanelHeight,
                            williamsRPanelHeight: $williamsRPanelHeight,
                            atrPanelHeight: $atrPanelHeight,
                            volumePanelHeight: $volumePanelHeight,
                            rsiPanelExpandedHeight: $rsiPanelExpandedHeight,
                            macdPanelExpandedHeight: $macdPanelExpandedHeight,
                            stochasticPanelExpandedHeight: $stochasticPanelExpandedHeight,
                            cciPanelExpandedHeight: $cciPanelExpandedHeight,
                            williamsRPanelExpandedHeight: $williamsRPanelExpandedHeight,
                            atrPanelExpandedHeight: $atrPanelExpandedHeight,
                            volumePanelExpandedHeight: $volumePanelExpandedHeight
                        )
                        // Keep bottom-sheet clearance. Mask only while an expanded bottom panel
                        // owns the x-axis strip; keep transparent when collapsed so controls remain visible.
                        Rectangle()
                            .fill(chartPanelsBottomLabelStripReserve > 0 ? AppColors.xAxisBackground : Color.clear)
                            .frame(
                                height: 100
                                    + chartPanelsMainChartXAxisClearance
                                    + ChartPanelReserveCalculator.panelStackBottomVisualBreathingRoom
                            )
                            .allowsHitTesting(false)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // MARK: - Overlay Layer
                if showOverlay {
                    overlayView
                        .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
                        .animation(.easeOut(duration: 0.4), value: showRightDrawer)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dismissRightSheetsSignal = true
                                    if showLeftDrawer && value.translation.width < 0 {
                                        leftDragTranslation = value.translation.width
                                    } else if showRightDrawer && value.translation.width > 0 {
                                        rightDragTranslation = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
                                }
                        )
                }
                
                // MARK: - Drawer Layers
                leftDrawerView
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 1.5), value: fadeIn)
                
                rightDrawerView
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 1.5), value: fadeIn)
                
                // MARK: - Sheet Overlay Layer
                if showSheetOverlay {
                    sheetOverlayView
                        .opacity(showSheetOverlay ? 1 : 0)
                        .animation(.linear(duration: 0.05), value: showSheetOverlay)
                }

            }
            .ignoresSafeArea(.keyboard, edges: showRightDrawer ? .bottom : [])
            .ignoresSafeArea()
            .rlGlobalMessaging()          // RL: chatrooms/DMs sheets
            
            .observeMarkerNavigation(
                leftDrawerViewModel: leftDrawerViewModel,
                chartViewModel: chartViewModel,
                gestureState: chartGestureState,
                onCloseDrawer: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showLeftDrawer = false
                        showOverlay = false
                    }
                }
            )
            
            // MARK: - Bottom Sheet
            // Bottom sheet — stays visible during placement mode with swapped content
            // SwiftUI presents one sheet per view. The bottom sheet is always up, so any
            // other sheet on this view — the share prompt, an author profile — is refused
            // and queued ("Currently, only presenting a single sheet is supported", logged
            // hundreds of times), then shown only once this one goes away. Standing the
            // bottom sheet down for them is the same thing already done for the drawers.
            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !rlAppState.showingTransition && !walkthroughSlotReserved && markerSharePromptContext == nil && selectedViewingMarkerAuthorRoute == nil && !showDiscordSetupReminder && !guildArrivalReservesSheetSlot)) {
                chartBottomSheet
                .environmentObject(rlAppState)
                .id(appThemeStorage)
                .presentationDetents([.fraction(0.11), .fraction(0.35), .fraction(0.5), .fraction(0.9)],
                                      selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled(true)
                .presentationContentInteraction(.resizes)
                .presentationBackground {
                    ZStack {
                        Color.clear
                            .background(.ultraThinMaterial)
                        LinearGradient(
                            colors: [
                                AppColors.sheetBackground.opacity(0.7),
                                AppColors.drawerBackground.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        PatternOverlay(patternType: .honeycomb, hexSize: 16, strokeColor: AppColors.patternStroke)
                            .opacity(0.012)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) {
                    fadeIn = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        showBottomSheet = true
                    }
                }
                leftDrawerViewModel.configure(with: rlAppState)
                rightDrawerViewModel.configure(with: rlMessagingManager)
                rightDrawerViewModel.configurePresence(with: rlAppState)
                
                // Configure ChartViewModel with proper RLAppState and RealAPIService
                chartViewModel.configure(appState: rlAppState, api: rlAppState.realApi)
                timeframePanelManager.api = rlAppState.realApi

                print(rlAppState.currentUser?.displayUsername ?? "Username")
                print(rlAppState.currentGuild?.name ?? "Guild Name")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
            .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
            .onReceive(NotificationCenter.default.publisher(for: .presentWalkthrough)) { _ in
                guard walkthroughPresentation == nil else { return }
                // Dismiss any presented sheets first (profile, settings, etc.)
                dismissLeftSheetsSignal = true
                dismissRightSheetsSignal = true
                // Close all drawers
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    showRightDrawer = false
                    showOverlay = false
                    showSheetOverlay = false
                    leftDragTranslation = 0
                    rightDragTranslation = 0
                }
                // Stand the chart sheet down now so the slot is free once the
                // drawers and their sheets have gone.
                walkthroughSlotReserved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard walkthroughPresentation == nil else { return }
                    rlAppState.walkthroughWillPresent()
                    walkthroughPresentation = .replay
                }
            }
            
            .environmentObject(leftDrawerViewModel)
            .environmentObject(rightDrawerViewModel)
            .environmentObject(notificationNavigationManager)
            .task {
                // Reserve the sheet slot before the transition lifts, or the chart
                // sheet presents into the gap 0.5 s after appear and the
                // walkthrough is refused behind it.
                walkthroughSlotReserved = rlAppState.shouldAutoStartInitialTutorial(for: user.id)
                    && !rlAppState.hasTutorialCompleted(for: user.id)

                notificationNavigationManager.configure(
                    rlAppState: rlAppState,
                    messagingManager: rlMessagingManager,
                    rightDrawerViewModel: rightDrawerViewModel,
                    dismissOverlays: {
                        dismissKeyboard()
                        withAnimation(AnimationConstants.standard) {
                            showLeftDrawer = false
                            showRightDrawer = false
                            showOverlay = false
                            leftDragTranslation = 0
                            rightDragTranslation = 0
                        }
                    },
                    presentLeftDrawerRoute: { route in
                        dismissKeyboard()
                        pendingNotificationDrawerRoute = route
                        withAnimation(AnimationConstants.standard) {
                            showLeftDrawer = true
                            showRightDrawer = false
                            showOverlay = true
                            leftDragTranslation = 0
                            rightDragTranslation = 0
                        }
                    }
                )

                // Use rlAppState guild ID for all data loading
                guard let rlGuildId = rlAppState.currentGuild?.id else {
                    // No guild yet, so nothing below can run — but a pending tap
                    // still deserves its answer rather than being dropped.
                    await handlePendingPushNotificationTapIfNeeded()
                    return
                }
                let transitionRequestID = rlAppState.transitionRequest.id
                
                // leftDrawerViewModel uses rlGuildId for all data via rlAppState
                await leftDrawerViewModel.preloadData(for: rlGuildId, rlAppState: rlAppState)
                
                // NEW: rightDrawerViewModel now uses RLAppState for live messaging data
                await rightDrawerViewModel.preloadData(for: rlGuildId, appState: rlAppState)
                
                // Initialize chart with data
                await chartViewModel.initialize()
                syncTimeframePanelsForCurrentMode(
                    resetPlacementSource: true,
                    resetViewingSource: true
                )
                
                rlAppState.chartDidBecomeReady(
                    requestID: transitionRequestID,
                    guildID: rlGuildId
                )

                // Drained *after* the chart bootstrap, not before it.
                //
                // Marker navigation returns as soon as it spawns its own task, so
                // nothing here awaited it — and `initialize()` finishes by
                // replacing the whole candle array, wiping the historical window
                // the navigation had just fetched. On a cold start from a
                // notification that is a coin flip between landing on the marker
                // and landing on "now" with no explanation.
                await handlePendingPushNotificationTapIfNeeded()

                // First-run walkthrough for new accounts, once the transition
                // and any guild arrival sheets are out of the way.
                scheduleWalkthroughIfEligible(for: user.id)
            }
            .onChange(of: rlAppState.showingTransition) { _, isShowing in
                if !isShowing, let userId = rlAppState.currentUser?.id {
                    scheduleWalkthroughIfEligible(for: userId)
                }
            }
            .onChange(of: welcomedGuild) { _, guild in
                if guild == nil, let userId = rlAppState.currentUser?.id {
                    scheduleWalkthroughIfEligible(for: userId)
                }
            }
            .onChange(of: celebratedGuild) { _, guild in
                if guild == nil, let userId = rlAppState.currentUser?.id {
                    scheduleWalkthroughIfEligible(for: userId)
                }
            }
            .onChange(of: selectedViewingMarkerAuthorRoute?.id) { _, routeID in
                if routeID == nil, let userId = rlAppState.currentUser?.id {
                    scheduleWalkthroughIfEligible(for: userId)
                }
            }
            .onChange(of: rlAppState.showBiometricEnrollment) { _, isShowing in
                guard !isShowing else { return }
                // The biometric offer that followed the walkthrough has gone:
                // hand the slot back (and run the CTA that was waiting on it).
                if walkthroughSlotReserved, walkthroughPresentation == nil, pendingWalkthroughCTA != nil {
                    releaseWalkthroughSlot(outcome: pendingWalkthroughCTA ?? .skipped)
                } else if let userId = rlAppState.currentUser?.id {
                    scheduleWalkthroughIfEligible(for: userId)
                }
            }
            .onChange(of: rlAppState.currentGuild?.id) { oldValue, newValue in
                if let request = pendingNotificationMarkerNavigation,
                   newValue != request.guildId {
                    pendingNotificationMarkerNavigation = nil
                }
                if let guildId = newValue, oldValue != newValue {
                    let transitionRequestID = rlAppState.transitionRequest.id
                    Task {
                        leftDrawerViewModel.clearCache()
                        rightDrawerViewModel.clearCache()
                        
                        // Uses real rlAppState guild ID for all data
                        await leftDrawerViewModel.preloadData(for: guildId, rlAppState: rlAppState)
                        await rightDrawerViewModel.preloadData(for: guildId, appState: rlAppState)
                        
                        await chartViewModel.initialize()
                        syncTimeframePanelsForCurrentMode(
                            resetPlacementSource: true,
                            resetViewingSource: true
                        )
                        rlAppState.chartDidBecomeReady(
                            requestID: transitionRequestID,
                            guildID: guildId
                        )
                    }
                }
            }
            .modifier(
                MarkerLinkCapabilityObserver(
                    appState: rlAppState,
                    chartViewModel: chartViewModel
                )
            )
            .onChange(of: chartControlVM.isMarkerPlacementMode) { _, isPlacing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isPlacing {
                        // Show placement panel at compact height — maximize chart space
                        selectedDetent = .fraction(0.35)
                    } else {
                        // ...and put it back when the panel goes away. Raising the sheet on
                        // the way in without lowering it on the way out left it standing open
                        // after every place, edit and cancel, for the user to drag down by
                        // hand. Placing a marker also selects it, and that path collapses to
                        // the same detent, so the two agree.
                        selectedDetent = .fraction(0.11)
                    }
                }
                syncTimeframePanelsForCurrentMode(resetPlacementSource: isPlacing)
            }
            .onChange(of: chartViewModel.selectedMarkerForSheet?.id) { oldId, newId in
                chartControlVM.isMarkerViewingMode = (newId != nil)
                handleMarkerViewingSelectionChange(oldId: oldId, newId: newId)
                if newId != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDetent = .fraction(0.11)
                    }
                }
            }
            .onChange(of: chartViewModel.currentSymbol?.id) { _, _ in
                syncTimeframePanelsForCurrentMode()
            }
            .onChange(of: chartViewModel.chartTimeframeLinkManager.linkedTimeframes) { _, _ in
                syncChartDefaultTimeframePanels()
            }
            .onChange(of: indicatorPanelFingerprint) { oldValue, newValue in
                reconcileIndicatorPanelPresentation(oldFingerprint: oldValue, newFingerprint: newValue)
            }
            .onChange(of: placementTimeframeFingerprint) { _, _ in
                guard chartControlVM.isMarkerPlacementMode else { return }
                syncPlacementTimeframePanels()
            }
            .onChange(of: viewingTimeframeFingerprint) { _, _ in
                guard chartViewModel.selectedMarkerForSheet != nil else { return }
                syncViewingTimeframePanels()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    Task {
                        await rlAppState.realApi.refreshAccessTokenIfNeeded(thresholdSeconds: 120)
                        if rlAppState.accessToken != nil {
                            rlAppState.connectRealTimeService()
                        }
                        await leftDrawerViewModel.handleAppDidBecomeActive(rlAppState: rlAppState)
                        await chartViewModel.handleAppDidBecomeActive()
                        await timeframePanelManager.refreshPanels(for: activeTimeframePanelSource)
                        await rlAppState.refreshCurrentGuildReputation()
                    }
                case .inactive:
                    break
                case .background:
                    break
                @unknown default:
                    break
                }
            }
            .onChange(of: showRightDrawer) { _, isPresented in
                if !isPresented {
                    isRightDrawerSearchFocused = false
                }
            }
        } else {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Reconnecting...")
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                Task {
                    if rlAppState.currentUser != nil && rlAppState.currentGuild == nil {
                        await rlAppState.openGuildSelector()
                    } else if rlAppState.currentUser == nil {
                        rlAppState.logout()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components

    private var mainContentStack: some View {
        NavigationStack {
            ZStack {
                StaticBackgroundView()
                mainChartContentLayer
            }
            .toolbar {
                mainToolbarContent
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(ThemeManager.shared.currentTheme.colorScheme, for: .navigationBar)
            .tint(AppColors.primaryForeground)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                configureNavigationBarAppearance()
            }
            .sheet(item: $selectedViewingMarkerAuthorRoute) { route in
                switch route {
                case .currentUser:
                    UserProfileDetailView(selectedDetent: $markerAuthorProfileDetent)
                        .environmentObject(rlAppState)
                        .environmentObject(leftDrawerViewModel)
                case .guildMember(let member):
                    GuildUserDetailViewRL(member: member)
                        .environmentObject(rlAppState)
                }
            }
            .sheet(item: $markerSharePromptContext) { context in
                MarkerSharePromptSheet(context: context, appState: rlAppState)
            }
            // Created and joined guilds are celebrated here, and only once the
            // transition has lifted.
            //
            // The celebration used to be raised from inside the create form,
            // which lives inside the drawer's sheet — and creating a guild
            // selects it, which closes that drawer, taking the just-opened
            // celebration with it. That is the flash the user reported. It lives
            // on this view for the same reason the Discord prompt does: the
            // chart bottom sheet owns the presentation slot, and standing it
            // down (below) is the only thing that reliably frees it.
            .fullScreenCover(item: $celebratedGuild, onDismiss: {
                let requestID = presentedCelebrationRequestID
                presentedCelebrationRequestID = nil
                if let requestID,
                   let pending = rlAppState.pendingGuildCelebration,
                   pending.transitionRequestID == requestID {
                    rlAppState.pendingGuildCelebration = nil
                    NotificationCenter.default.post(
                        name: .guildCreationDidFinish,
                        object: nil,
                        userInfo: [GuildCreationNotification.guildIdKey: pending.guild.id]
                    )
                }
            }) { guild in
                GuildInviteHubView(
                    headline: "Your guild is live 🎉",
                    subheadline: "Now bring your community in. Share your guild on X, Discord, or with your contacts to get your first members.",
                    primaryButtonTitle: "Done",
                    onPrimaryAction: { celebratedGuild = nil },
                    shareMode: .guildVanity
                )
                .environmentObject(rlAppState)
                .id(guild.id)
            }
            .sheet(item: $welcomedGuild, onDismiss: {
                let requestID = presentedWelcomeRequestID
                presentedWelcomeRequestID = nil
                if let requestID,
                   rlAppState.pendingGuildWelcome?.transitionRequestID == requestID {
                    rlAppState.pendingGuildWelcome = nil
                }
                presentRequestedCurrentUserProfileIfReady()
            }) { guild in
                GuildJoinedSheet(
                    guild: guild,
                    onDismiss: { welcomedGuild = nil },
                    onViewGuild: {
                        welcomedGuild = nil
                        rlAppState.requestGuildProfileAfterWelcome(guildID: guild.id)
                    }
                )
                .environmentObject(rlAppState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $walkthroughPresentation, onDismiss: handleWalkthroughDismissed) { _ in
                WalkthroughSheetView { outcome in
                    walkthroughOutcome = outcome
                    walkthroughPresentation = nil
                }
                .environmentObject(rlAppState)
                .presentationDetents([.large])
                // The sheet is a floating card, so the presentation itself paints nothing and
                // the dimmed chart shows around it.
                .presentationBackground(.clear)
            }
            .onChange(of: rlAppState.showingTransition) { _, _ in
                presentPendingGuildSheetsIfReady()
            }
            .onChange(of: rlAppState.pendingGuildCelebration) { _, _ in
                presentPendingGuildSheetsIfReady()
            }
            .onChange(of: rlAppState.pendingGuildWelcome) { _, _ in
                presentPendingGuildSheetsIfReady()
            }
            .onChange(of: rlAppState.openCurrentUserProfileRequest) { _, _ in
                presentRequestedCurrentUserProfileIfReady()
            }
            .sheet(isPresented: $showDiscordSetupReminder) {
                DiscordSetupReminderSheet(
                    guild: rlAppState.currentGuild,
                    guildName: rlAppState.currentGuild?.name ?? "your guild"
                ) {
                    // Straight to the Discord section of guild settings, add
                    // form open. Opening the drawer alone left the owner to find
                    // Admin → Guild Settings → the bottom of a long scroll, which
                    // is the same as not helping.
                    withAnimation { showLeftDrawer = true }
                    pendingNotificationDrawerRoute = .guildDiscordSettings
                }
                // The one sheet in the app that a stray swipe must not answer.
                // `recordShown` is called before it presents, so a flick past it
                // costs the owner the ask for thirty days — and the ask is the
                // whole feature. "Not now" and "Connect a channel" both call
                // `dismiss()`, which this does not block.
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
            }
            .task(id: rlAppState.currentGuild?.id) {
                await maybeRemindAboutDiscord(trigger: "guild_changed")
            }
            .onReceive(NotificationCenter.default.publisher(for: .guildCreationDidFinish)) { note in
                guard let guildId = note.userInfo?[GuildCreationNotification.guildIdKey] as? UUID
                else { return }
                Task {
                    print("🎉 [Guild] creation flow finished — Discord prompt queued")
                    // The drawer is already gone: creating a guild selects it,
                    // and selecting bumps `closeSheetsToken`, which closes every
                    // modal on this view. The pair of hand-tuned 400ms sleeps
                    // that used to wait for covers nobody could observe went
                    // with it.
                    DiscordSetupReminder.endCreationDeferral(guildId: guildId)
                    // Just long enough for the celebration's cover to finish
                    // leaving, so the prompt is not presented into its dismissal.
                    try? await Task.sleep(for: DiscordSetupReminder.postCreationDelay)
                    await maybeRemindAboutDiscord(trigger: "after_creation")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .presentMarkerSharePrompt)) { note in
                if let context = note.userInfo?[MarkerSharePromptNotification.contextKey] as? MarkerShareContext {
                    markerSharePromptContext = context
                }
            }
            // Everything modal goes away when the shell re-points at another
            // guild. The transition covers the swap; without this it lifts to
            // reveal the sheet you joined *from*, still describing the guild
            // you have just left.
            .onChange(of: rlAppState.closeSheetsToken) { _, _ in
                dismissKeyboard()
                markerSharePromptContext = nil
                selectedViewingMarkerAuthorRoute = nil
                showDiscordSetupReminder = false
                celebratedGuild = nil
                welcomedGuild = nil
                walkthroughPresentation = nil
                // The tab used to be the sheet's own @State and reset every time
                // it re-presented; keep that behaviour across a guild switch.
                chartSheetTab = .symbol
                dismissLeftSheetsSignal = true
                dismissRightSheetsSignal = true
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    showRightDrawer = false
                    showOverlay = false
                    showSheetOverlay = false
                    leftDragTranslation = 0
                    rightDragTranslation = 0
                }
            }
        }
    }

    /// Show a queued guild celebration or welcome, once the shell is settled.
    ///
    /// Nothing modal may present while the transition is up: the overlay is
    /// mounted inside the root hierarchy, so a sheet presented over it covers
    /// it — and the arrival the sheet is meant to be is then revealed already
    /// open, which is the opposite of arriving.
    @MainActor
    private func presentPendingGuildSheetsIfReady() {
        guard !rlAppState.showingTransition else { return }
        if celebratedGuild == nil, let arrival = rlAppState.pendingGuildCelebration {
            guard arrival.transitionRequestID == rlAppState.transitionRequest.id,
                  arrival.guild.id == rlAppState.currentGuild?.id else {
                rlAppState.pendingGuildCelebration = nil
                return
            }
            presentedCelebrationRequestID = arrival.transitionRequestID
            celebratedGuild = arrival.guild
            return
        }
        // Never both at once, and the celebration wins — you cannot create and
        // join in the same breath, but a queued value could outlive its cover.
        if celebratedGuild == nil, welcomedGuild == nil,
           let arrival = rlAppState.pendingGuildWelcome {
            guard arrival.transitionRequestID == rlAppState.transitionRequest.id,
                  arrival.guild.id == rlAppState.currentGuild?.id else {
                rlAppState.pendingGuildWelcome = nil
                return
            }
            presentedWelcomeRequestID = arrival.transitionRequestID
            welcomedGuild = arrival.guild
        }
    }

    /// Route "View guild" to the same current-user profile sheet used by a
    /// marker-author tap, but only after the welcome sheet has fully dismissed.
    @MainActor
    private func presentRequestedCurrentUserProfileIfReady() {
        guard let request = rlAppState.openCurrentUserProfileRequest else { return }
        guard request.guildID == rlAppState.currentGuild?.id else {
            _ = rlAppState.consumeGuildProfileAfterWelcomeRequest(request.id)
            return
        }
        guard selectedViewingMarkerAuthorRoute == nil else { return }
        guard GuildArrivalPresentationPolicy.canPresentProfile(
            hasPendingProfile: true,
            hasPendingWelcome: rlAppState.pendingGuildWelcome != nil,
            hasPresentedWelcome: welcomedGuild != nil,
            hasPendingCelebration: rlAppState.pendingGuildCelebration != nil,
            hasPresentedCelebration: celebratedGuild != nil
        ) else { return }

        // SwiftUI must observe the welcome dismissal before a peer sheet claims
        // the slot. The token keeps the request reserved during this runloop hop.
        DispatchQueue.main.async {
            guard rlAppState.openCurrentUserProfileRequest == request,
                  rlAppState.currentGuild?.id == request.guildID,
                  welcomedGuild == nil,
                  rlAppState.pendingGuildWelcome == nil else { return }
            dismissKeyboard()
            markerAuthorProfileDetent = .fraction(0.6)
            selectedViewingMarkerAuthorRoute = .currentUser
            _ = rlAppState.consumeGuildProfileAfterWelcomeRequest(request.id)
        }
    }

    /// Whether something else already owns this view's single sheet slot.
    ///
    /// This deliberately reads **our own SwiftUI state** rather than sampling
    /// `rootViewController.presentedViewController`. The chart bottom sheet is
    /// presented essentially always (`showBottomSheet` is set once and never
    /// cleared), so a UIKit probe answered "yes, a sheet is up" every single
    /// time — while the bottom sheet, in turn, only stands down once
    /// `showDiscordSetupReminder` is already true. That was a deadlock: the
    /// prompt could never be shown, on any trigger.
    ///
    /// Setting `showDiscordSetupReminder` is what *makes* the slot free, exactly
    /// as `markerSharePromptContext` and `selectedViewingMarkerAuthorRoute` do
    /// — see the `.sheet` condition on the bottom sheet. So the only real
    /// conflicts are those two peers, an open drawer (whose own covers would be
    /// presented over us, and whose `.disabled` would make us inert anyway) and
    /// the guild transition.
    private var discordReminderSlotIsOccupied: Bool {
        showLeftDrawer
            || showRightDrawer
            || markerSharePromptContext != nil
            || selectedViewingMarkerAuthorRoute != nil
            || rlAppState.showingTransition
            || walkthroughSlotReserved
            // The prompt follows the celebration; it must never race it. Both
            // pending values count, not just what is on screen — the celebration
            // is claimed the moment the guild is created and presented later.
            || celebratedGuild != nil
            || welcomedGuild != nil
            || rlAppState.pendingGuildCelebration != nil
            || rlAppState.pendingGuildWelcome != nil
    }

    /// Ask the owner about Discord — after they create a guild, then rarely.
    ///
    /// Silent on every failure: an unreachable channel list is not a reason to
    /// interrupt somebody, and the reminder will come round again anyway.
    private func maybeRemindAboutDiscord(trigger: String) async {
        guard let guild = rlAppState.currentGuild else { return }
        guard guild.ownerId == rlAppState.currentUser?.id,
              !(guild.isOnboardingSystemGuild ?? false)
        else { return }

        // Creating a guild selects it, which trips this task while the invite
        // hub is still up. That run is handed to `.guildCreationDidFinish`.
        if DiscordSetupReminder.isDeferredForCreation(guildId: guild.id) {
            print("🔗 [Discord] reminder deferred (\(trigger)) — creation flow still open")
            return
        }
        if discordReminderSlotIsOccupied {
            print("🔗 [Discord] reminder skipped (\(trigger)) — the sheet slot is taken")
            return
        }

        guard let response = try? await rlAppState.realApi.getGuildDiscordChannels(
            guildId: guild.id
        ) else {
            print("🔗 [Discord] reminder skipped (\(trigger)) — channel list unavailable")
            return
        }

        guard DiscordSetupReminder.shouldRemind(
            guildId: guild.id,
            isOwner: true,
            hasChannel: response.channels.contains(where: \.canPost)
        ) else {
            print("🔗 [Discord] reminder not due (\(trigger)) for \(guild.name)")
            return
        }

        // Re-checked after the await: something may have claimed the slot while
        // the channel list was in flight, and this prompt must never be second.
        guard !discordReminderSlotIsOccupied else {
            print("🔗 [Discord] reminder skipped (\(trigger)) — slot taken mid-fetch")
            return
        }

        print("🔗 [Discord] showing setup reminder (\(trigger)) for \(guild.name)")
        DiscordSetupReminder.recordShown(guildId: guild.id)
        showDiscordSetupReminder = true
    }

    private var mainChartContentLayer: some View {
        VStack(spacing: 0) {
            if let user = rlAppState.currentUser,
               let guild = rlAppState.currentGuild {
                chartView(controlViewModel: chartControlVM, user: user, guild: guild)
            }
        }
        .opacity(fadeIn ? 1 : 0)
        .animation(.easeIn(duration: 1.5), value: fadeIn)
        .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
            if let symbol = notification.userInfo?["symbol"] as? RLTradingSymbolDTO {
                dismissKeyboard()
                chartViewModel.setSymbol(symbol)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showLeftDrawer = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSharedMarker)) { notification in
            Task {
                await handleOpenSharedMarker(notification.userInfo)
            }
        }
        .task(id: pendingMarkerNavigationConsumptionKey) {
            await consumePendingMarkerNavigationIfPossible()
        }
        .task(id: pendingNotificationMarkerNavigationConsumptionKey) {
            await consumePendingNotificationMarkerNavigationIfPossible()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
            Task {
                await handlePendingPushNotificationTapIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildWatchlistUpdated)) { _ in
            guard let guildId = rlAppState.currentGuild?.id else { return }
            Task {
                do {
                    async let guildTask = rlAppState.fetchGuildWatchlist(guildId: guildId)
                    async let globalTask = rlAppState.realApi.getGlobalSymbols(guildId: guildId, limit: 100)
                    let (guildWatchlist, globalSymbols) = try await (guildTask, globalTask)
                    await MainActor.run {
                        leftDrawerViewModel.guildTradingWatchlist = guildWatchlist.symbols.map { $0.symbol }
                        leftDrawerViewModel.globalTradingSymbols = globalSymbols.symbols
                    }
                } catch {
                    // Errors are surfaced via RLAppState.
                }
                await chartViewModel.reloadData()
            }
        }
    }

    @ToolbarContentBuilder
    private var mainToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            mainToolbarLeadingItem
        }
        ToolbarItem(placement: .principal) {
            mainToolbarPrincipalItem
        }
        mainToolbarTrailingContent
    }

    @ViewBuilder
    private var mainToolbarLeadingItem: some View {
        if chartControlVM.isMarkerPlacementMode {
            markerToolbarCloseButton(
                iconColor: .white,
                tintColor: AppColors.statusNegative55
            ) {
                // The guided flow asks before throwing away what the author
                // did; an untouched draft, and the legacy flow, close as before.
                if placementState.cancellingNeedsConfirmation {
                    showDiscardGuidedDraftConfirmation = true
                    return
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    chartControlVM.cancelMarkerPlacement()
                }
            }
            // A guided post in flight cannot be discarded out from under
            // itself; the legacy flow is unchanged. The confirmation itself is
            // presented by `ChartBottomSheet`: presented from here it would
            // pre-empt the chart sheet, which UIKit traps on.
            .disabled(placementState.isGuidedSubmissionInFlight)
        } else if chartControlVM.isMarkerViewingMode {
            markerToolbarCloseButton(
                iconColor: AppColors.whiteText.opacity(0.95),
                tintColor: AppColors.surfaceWhite18
            ) {
                closeMarkerViewingMode()
            }
        } else {
            if let guild = rlAppState.currentGuild,
               let imageUrl = guild.imageUrl, !imageUrl.isEmpty {
                // Uploaded guild image — circular avatar button.
                Button {
                    toggleLeftDrawerFromToolbar()
                } label: {
                    GuildCrestView(guild: guild, size: 32)
                }
                .buttonStyle(.plain)
            } else {
                // Symbol crest — plain white glyph in the standard toolbar button.
                ToolbarIconButton(
                    systemName: GuildCrestCatalog.sfSymbol(for: rlAppState.currentGuild?.crestSymbol),
                    backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                    fontType: .headline,
                    symbolRenderingMode: .monochrome,
                    foregroundStyle: AppColors.whiteText,
                    padding: 8
                ) {
                    toggleLeftDrawerFromToolbar()
                }
            }
        }
    }

    @ViewBuilder
    private var mainToolbarPrincipalItem: some View {
        if chartControlVM.isMarkerPlacementMode {
            Text(placementState.toolbarInstructionText ?? placementState.guidedToolbarTitle ?? placementState.editToolbarTitle() ?? "Place a Marker")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
        } else if chartControlVM.isMarkerViewingMode {
            markerViewingToolbarTitle
        } else {
            Text("TG")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(AppColors.chartLogo)
        }
    }

    @ToolbarContentBuilder
    private var mainToolbarTrailingContent: some ToolbarContent {
        if chartControlVM.isMarkerPlacementMode {
            if placementState.shouldShowDrawingDiscardAction {
                ToolbarItem(placement: .topBarTrailing) {
                    drawingDiscardToolbarButton
                }
            }
        } else if chartControlVM.isMarkerViewingMode {
            ToolbarItem(placement: .topBarTrailing) {
                markerViewingAuthorToolbarButton
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                rightDrawerToolbarButton
            }
        }
    }

    private var drawingDiscardToolbarButton: some View {
        Button {
            placementState.discardActiveDrawingAndExit()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.whiteText.opacity(0.95))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(AppColors.surfaceWhite12)
                        Circle()
                            .stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var rightDrawerToolbarButton: some View {
        ZStack(alignment: .topTrailing) {
            if rightDrawerViewModel.totalUnreadCount > 0 {
                ToolbarIconButton(
                    systemName: "message.badge.filled.fill",
                    backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                    fontType: .subheadline,
                    symbolRenderingMode: .palette,
                    foregroundStyles: [AppColors.accentColor, AppColors.whiteText],
                    padding: 8
                ) {
                    toggleRightDrawerFromToolbar()
                }
            } else {
                ToolbarIconButton(
                    systemName: "message.badge.filled.fill",
                    backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                    fontType: .subheadline,
                    symbolRenderingMode: .monochrome,
                    foregroundStyle: AppColors.whiteText,
                    padding: 8
                ) {
                    toggleRightDrawerFromToolbar()
                }
            }
        }
    }

    /// Presents the first-run walkthrough once the shell is quiet: the loading
    /// transition has lifted and no guild arrival sheet, author profile, share
    /// prompt, Discord reminder or biometric offer is up or pending. Re-evaluated
    /// from every `onChange` that clears one of those, and re-checked inside the
    /// delay because they can appear between scheduling and firing.
    private func scheduleWalkthroughIfEligible(for userId: UUID) {
        guard !didScheduleWalkthrough else { return }
        guard walkthroughPresentation == nil else { return }
        guard rlAppState.shouldAutoStartInitialTutorial(for: userId) else { return }
        guard !rlAppState.hasTutorialCompleted(for: userId) else { return }
        guard walkthroughSchedulerIsClear else { return }

        // The root fades the transition over 0.5 s; let it finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !didScheduleWalkthrough, walkthroughPresentation == nil else { return }
            guard rlAppState.currentUser?.id == userId else { return }
            guard rlAppState.shouldAutoStartInitialTutorial(for: userId) else { return }
            guard walkthroughSchedulerIsClear else { return }
            didScheduleWalkthrough = true
            rlAppState.markInitialTutorialAutoStartShown(for: userId)

            // A quiet view tree underneath: no drawer or drawer sheet competing
            // for the presentation.
            dismissLeftSheetsSignal = true
            dismissRightSheetsSignal = true
            withAnimation(AnimationConstants.standard) {
                showLeftDrawer = false
                showRightDrawer = false
                showOverlay = false
                showSheetOverlay = false
                leftDragTranslation = 0
                rightDragTranslation = 0
            }
            walkthroughSlotReserved = true
            rlAppState.walkthroughWillPresent()
            walkthroughPresentation = .firstRun
        }
    }

    private var walkthroughSchedulerIsClear: Bool {
        !rlAppState.showingTransition
            && !guildArrivalReservesSheetSlot
            && selectedViewingMarkerAuthorRoute == nil
            && markerSharePromptContext == nil
            && !showDiscordSetupReminder
            && !rlAppState.showBiometricEnrollment
    }

    /// The walkthrough sheet's onDismiss: runs for its buttons (which set
    /// `walkthroughOutcome` first) and for a swipe-down (which does not, and
    /// counts as a skip). Every outcome marks the walkthrough complete.
    private func handleWalkthroughDismissed() {
        let outcome = walkthroughOutcome ?? .skipped
        walkthroughOutcome = nil
        if let userId = rlAppState.currentUser?.id {
            rlAppState.markTutorialCompleted(for: userId)
        }
        let biometricFollows = rlAppState.walkthroughDidDismiss(outcome: outcome)
        guard biometricFollows else {
            releaseWalkthroughSlot(outcome: outcome)
            return
        }
        // Keep the chart sheet down until the biometric sheet has come and gone;
        // the follow-up runs then (see the showBiometricEnrollment onChange). The
        // offer presents 1.5 s after being scheduled, so a 4 s failsafe covers
        // it never appearing.
        pendingWalkthroughCTA = outcome
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if let pending = pendingWalkthroughCTA, !rlAppState.showBiometricEnrollment {
                releaseWalkthroughSlot(outcome: pending)
            }
        }
    }

    /// Hands the sheet slot back to the chart sheet — on the Markers tab at
    /// half height when the user asked to place their first marker, which is
    /// the type grid the walkthrough just described.
    private func releaseWalkthroughSlot(outcome: WalkthroughOutcome) {
        pendingWalkthroughCTA = nil
        if outcome == .placeFirstMarker {
            // Both are read when the sheet presents, so they must be set before
            // the reservation flips and the sheet condition becomes true.
            chartSheetTab = .markers
            selectedDetent = .fraction(0.5)
        }
        walkthroughSlotReserved = false
    }

    private func toggleLeftDrawerFromToolbar() {
        withAnimation(AnimationConstants.standard) {
            dismissKeyboard()
            selectedDetent = .fraction(0.11)
            showLeftDrawer.toggle()
            showRightDrawer = false
            showOverlay = showLeftDrawer
        }
    }

    private func toggleRightDrawerFromToolbar() {
        withAnimation(AnimationConstants.standard) {
            dismissKeyboard()
            selectedDetent = .fraction(0.11)
            showRightDrawer.toggle()
            showLeftDrawer = false
            showOverlay = showRightDrawer
        }
    }
    
    // UPDATED: Pass total indicator panel height for proper bottom controls positioning
    private func chartView(controlViewModel: ChartControlViewModel, user: RLUserDTO, guild: RLGuildDTO) -> some View {
        let currentMember: RLGuildMemberDTO
        if let membership = rlAppState.currentMembership {
            currentMember = RLGuildMemberDTO.fromCurrentUser(user: user, membership: membership)
        } else {
            currentMember = RLGuildMemberDTO(
                membershipId: UUID(),
                role: "member",
                reputation: 0,
                contributionScore: 0,
                dateJoined: Date(),
                accuracyRate: nil,
                mutedUntil: nil,
                suspendedUntil: nil,
                userId: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                isOnline: user.isOnline,
                globalReputation: user.globalReputation,
                isFriend: false,
                friendshipStatus: nil,
                isBlocked: false,
                isBlockedBy: false
            )
        }

        return TradingChartView(
            userId: user.id,
            username: user.username,
            guildId: guild.id,
            currentUserMember: currentMember,
            controlViewModel: controlViewModel,
            chartViewModel: chartViewModel,
            gestureState: chartGestureState,
            placementState: placementState,
            rsiPanelHeight: $rsiPanelHeight,
            activeTimeframeLegendEntries: activeTimeframeLegendEntries,
            indicatorPanelBottomPadding: chartPanelsTotalHeight,
            panelBottomBoundaryLabelReserve: chartPanelsBottomLabelStripReserve,
            floatingOverlayPanelClearance: chartFloatingOverlayClearance,
            chartControlRowPanelReserve: chartControlRowPanelReserve
        )
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = nil

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
    
    private var overlayView: some View {
        AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(AnimationConstants.standard) {
                    dismissKeyboard()
                    showLeftDrawer = false
                    showRightDrawer = false
                    leftDragTranslation = 0
                    rightDragTranslation = 0
                    dismissRightSheetsSignal = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
    }
    
    private var sheetOverlayView: some View {
        AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity * 0.8)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                dismissRightSheetsSignal = true
                dismissLeftSheetsSignal = true
            }
            .simultaneousGesture(DragGesture().onChanged { _ in
                dismissRightSheetsSignal = true
                dismissLeftSheetsSignal = true
            })
    }
    
    // FIXED: Using LeftDrawerMainView (correct name)
    private var leftDrawerView: some View {
        HStack(spacing: 0) {
            LeftDrawerMainView(
                sheetOverlayVisible: $showSheetOverlay,
                dismissSheetsSignal: $dismissLeftSheetsSignal,
                notificationRoute: $pendingNotificationDrawerRoute,
                onClose: {
                    dismissKeyboard()
                    withAnimation(AnimationConstants.standard) {
                        showLeftDrawer = false
                        leftDragTranslation = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOverlay = false
                    }
                },
                currentSymbolId: chartViewModel.currentSymbol?.id
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: CGFloat.infinity)
            .offset(x: leftDragTranslation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            leftDragTranslation = value.translation.width
                        }
                    }
                    .onEnded { value in
                        handleDrawerDragEnd(currentPosition: leftDragTranslation)
                    }
            )
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .offset(x: showLeftDrawer ? 0 : -drawerWidth)
        .animation(AnimationConstants.standard, value: showLeftDrawer)
    }
    
    // UPDATED: Using RLRightDrawerMainView for live messaging
    private var rightDrawerView: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            RLRightDrawerMainView(
                onClose: {
                    dismissKeyboard()
                    withAnimation(AnimationConstants.standard) {
                        showRightDrawer = false
                        isRightDrawerSearchFocused = false
                        rightDragTranslation = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOverlay = false
                    }
                },
                onSearchFocusChanged: { isFocused in
                    isRightDrawerSearchFocused = isFocused
                }
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
            .offset(x: rightDragTranslation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 {
                            rightDragTranslation = value.translation.width
                        }
                    }
                    .onEnded { value in
                        handleDrawerDragEnd(currentPosition: rightDragTranslation)
                    }
            )
        }
        .frame(maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .offset(x: showRightDrawer ? 0 : drawerWidth)
        .animation(AnimationConstants.standard, value: showRightDrawer)
    }
    
    // MARK: - Helper Functions
    
    private func handleDrawerDragEnd(currentPosition: CGFloat) {
        if showLeftDrawer {
            if currentPosition < -LayoutConstants.drawerDismissThreshold {
                dismissKeyboard()
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    leftDragTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                withAnimation(AnimationConstants.standard) {
                    leftDragTranslation = 0
                }
            }
        } else if showRightDrawer {
            if currentPosition > LayoutConstants.drawerDismissThreshold {
                dismissKeyboard()
                withAnimation(AnimationConstants.standard) {
                    showRightDrawer = false
                    rightDragTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                withAnimation(AnimationConstants.standard) {
                    rightDragTranslation = 0
                }
            }
        }
    }
    
    private func markerToolbarCloseButton(
        iconColor: Color,
        tintColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(tintColor)
                        Circle()
                            .stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
                .shadow(color: tintColor.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var markerViewingToolbarTitle: some View {
        if let marker = chartViewModel.selectedMarkerForSheet {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: marker.intent,
                    alertSeverity: marker.alertSeverity,
                    size: 30,
                    avatar: MarkerAvatarIdentity.forMarker(marker)
                )
                Text("\(marker.intent.displayName) Marker")
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                    .lineLimit(1)
            }
        } else {
            Text("Viewing Marker")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryForeground)
        }
    }

    @ViewBuilder
    private var markerViewingAuthorToolbarButton: some View {
        if let marker = chartViewModel.selectedMarkerForSheet {
            Button {
                if marker.author.userId == rlAppState.currentUser?.id {
                    markerAuthorProfileDetent = .fraction(0.6)
                    selectedViewingMarkerAuthorRoute = .currentUser
                } else {
                    selectedViewingMarkerAuthorRoute = .guildMember(marker.author)
                }
            } label: {
                UnifiedMemberAvatar(
                    username: marker.author.username,
                    avatarURL: marker.author.avatarUrl,
                    isOnline: marker.author.isOnline,
                    size: 28,
                    showOnlineIndicator: false
                )
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(AppColors.surfaceWhite12)
                        Circle().stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
                .shadow(color: AppColors.surfaceWhite12.opacity(0.35), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    private func closeMarkerViewingMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            chartViewModel.markerManager?.selectedMarker = nil
            chartControlVM.isMarkerViewingMode = false
        }
    }

    private func handleMarkerViewingSelectionChange(oldId: UUID?, newId: UUID?) {
        guard oldId != newId else { return }
        guard let marker = chartViewModel.selectedMarkerForSheet else {
            markerOverlayState.deactivateViewing(
                indicatorManager: chartViewModel.indicatorManager,
                candles: chartDataManager.candles
            )
            syncTimeframePanelsForCurrentMode()
            return
        }

        markerOverlayState.activateViewing(
            marker: marker,
            indicatorManager: chartViewModel.indicatorManager,
            candles: chartDataManager.candles
        )

        syncTimeframePanelsForCurrentMode(resetViewingSource: true)
    }

    private func syncTimeframePanelsForCurrentMode(
        resetPlacementSource: Bool = false,
        resetViewingSource: Bool = false
    ) {
        syncChartDefaultTimeframePanels()
        syncPlacementTimeframePanels(resetPresentationState: resetPlacementSource)
        syncViewingTimeframePanels(resetPresentationState: resetViewingSource)
        timeframePanelManager.setActiveSource(activeTimeframePanelSource)
        clampChartPanelHeightsForCurrentMode()
    }

    private func syncChartDefaultTimeframePanels() {
        syncTimeframePanels(
            source: .chartDefaults,
            backendValues: chartViewModel.chartTimeframeLinkManager.linkedTimeframes
        )
    }

    private func syncPlacementTimeframePanels(resetPresentationState: Bool = false) {
        let linkedValues = placementState.timeframeLinkDrafts.compactMap { draft -> String? in
            guard case .timeframeLink(let payload) = draft.payload else { return nil }
            return payload.timeframe
        }
        syncTimeframePanels(
            source: .markerPlacement,
            backendValues: linkedValues,
            resetPresentationState: resetPresentationState
        )
    }

    private func syncViewingTimeframePanels(resetPresentationState: Bool = false) {
        let linkedValues = chartViewModel.selectedMarkerForSheet?.marker.components.compactMap { component -> String? in
            guard component.componentTypeEnum == .timeframeLink,
                  case .timeframeLink(let payload) = component.payload else {
                return nil
            }
            return payload.timeframe
        } ?? []
        syncTimeframePanels(
            source: .markerViewing,
            backendValues: linkedValues,
            resetPresentationState: resetPresentationState
        )
    }

    private func syncTimeframePanels(
        source: TimeframePanelSource,
        backendValues: [String],
        resetPresentationState: Bool = false
    ) {
        timeframePanelManager.replacePanels(
            for: source,
            backendValues: backendValues,
            symbolId: chartViewModel.currentSymbol?.id,
            guildId: rlAppState.currentGuild?.id,
            resetPresentationState: resetPresentationState
        )
    }
    
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func consumePendingMarkerNavigationIfPossible() async {
        guard let request = rlAppState.pendingMarkerNavigationRequest,
              MarkerDeepLinkRoutingPolicy.canNavigate(
                requestGuildId: request.guildId,
                currentGuildId: rlAppState.currentGuild?.id,
                isChartReady: rlAppState.isChartReady,
                isTransitionVisible: rlAppState.showingTransition,
                isInteractionUnlocked: !rlAppState.shouldPresentBiometricAppLock
              ) else { return }

        let accepted = await openSharedMarker(
            request.payload,
            expectedRequestId: request.id
        )
        guard accepted else { return }
        rlAppState.acknowledgePendingMarkerNavigation(requestId: request.id)
    }

    private func consumePendingNotificationMarkerNavigationIfPossible() async {
        guard let request = pendingNotificationMarkerNavigation,
              MarkerDeepLinkRoutingPolicy.canNavigate(
                requestGuildId: request.guildId,
                currentGuildId: rlAppState.currentGuild?.id,
                isChartReady: rlAppState.isChartReady,
                isTransitionVisible: rlAppState.showingTransition,
                isInteractionUnlocked: !rlAppState.shouldPresentBiometricAppLock
              ) else { return }

        let opened = await openSharedMarker(
            request.payload,
            expectedNotificationRequestId: request.id
        )
        guard pendingNotificationMarkerNavigation?.id == request.id else { return }
        pendingNotificationMarkerNavigation = nil
        guard opened else {
            if rlAppState.currentGuild?.id == request.guildId {
                rlAppState.showError(
                    title: "Couldn’t Open Marker",
                    message: "That marker’s chart could not be loaded. Try again in a moment.",
                    severity: .warning,
                    style: .toast
                )
            }
            return
        }
        if request.shareOnOpen {
            await presentSharePromptForNavigatedMarker()
        }
    }

    private func handleOpenSharedMarker(_ userInfo: [AnyHashable: Any]?) async {
        guard let userInfo, let payload = MarkerSharePayloadV1(userInfo) else { return }
        // A newer notification replaces a destination still waiting for chart readiness.
        pendingNotificationMarkerNavigation = nil
        guard let guildId = userInfo[NotificationNavigationManager.markerGuildKey] as? UUID
                ?? rlAppState.currentGuild?.id else {
            rlAppState.showInfo("Guild not ready")
            return
        }
        switch switchToMarkerGuildIfNeeded(guildId) {
        case .ready:
            break
        case .notAMember:
            // Opening anyway searches the *current* guild for a marker that
            // lives in another one: candles load, no marker is found, and the
            // user is left on an unexplained chart. Say so instead.
            let copy = MarkerDeepLinkFailureCopy.terminalFailure(forHTTPStatus: 403)
            rlAppState.showError(
                title: copy?.title ?? "Marker Access Required",
                message: copy?.message ?? "Join the marker’s guild to view it.",
                severity: .warning,
                style: .toast
            )
            return
        }
        // Guild selection updates currentGuild immediately, while its chart initializes
        // later. Hold the marker until that exact guild's chart reports readiness.
        pendingNotificationMarkerNavigation = PendingNotificationMarkerNavigation(
            guildId: guildId,
            payload: payload,
            shareOnOpen: userInfo[NotificationNavigationManager.shareOnOpenKey] as? Bool == true
        )
    }

    /// Why a marker deep link did or did not get somewhere it could be opened.
    private enum MarkerGuildSwitchOutcome {
        /// Already in the right guild, or moved to it successfully.
        case ready
        /// The marker belongs to a guild this account has not joined.
        case notAMember
    }

    /// Move to the guild a marker lives in before going looking for it.
    ///
    /// Markers are guild-scoped and the chart only ever fetches the current guild's, but a
    /// result notification arrives whenever the market moves — frequently while its author
    /// is in a different guild. Navigating without this searched the wrong guild, came back
    /// with nothing, and told the author their own marker was unavailable.
    ///
    /// Reports non-membership rather than silently carrying on: the caller used to
    /// open the marker anyway, against whichever guild happened to be current, and
    /// the user landed on a chart with no marker and no explanation.
    private func switchToMarkerGuildIfNeeded(_ guildId: UUID) -> MarkerGuildSwitchOutcome {
        guard rlAppState.currentGuild?.id != guildId else { return .ready }
        guard rlAppState.userGuilds.contains(where: { $0.guild.id == guildId }) else {
            return .notAMember
        }

        rlAppState.selectGuild(id: guildId)
        return .ready
    }

    /// Raise the share sheet for a marker we were sent to by a result notification.
    ///
    /// Navigation selects the marker asynchronously — it has to load candles and centre —
    /// so this waits for the selection rather than firing into an empty chart. If it never
    /// arrives the user is simply left on the marker, which is where they asked to be.
    private func presentSharePromptForNavigatedMarker() async {
        for _ in 0..<40 {
            if chartViewModel.selectedMarkerForSheet != nil { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let marker = chartViewModel.selectedMarkerForSheet,
              MarkerShare.canShareWithinGuild(visibility: marker.visibility) else { return }

        let context = MarkerShareContext(
            marker: marker.marker,
            symbolTicker: chartViewModel.currentSymbol?.ticker,
            isNewPlacement: false,
            isCurrentUserMarker: marker.isCurrentUserMarker
                || marker.author.userId == rlAppState.currentUser?.id
        )
        NotificationCenter.default.post(
            name: .presentMarkerSharePrompt,
            object: nil,
            userInfo: [MarkerSharePromptNotification.contextKey: context]
        )
    }

    @discardableResult
    private func openSharedMarker(
        _ payload: MarkerSharePayloadV1,
        expectedRequestId: UUID? = nil,
        expectedNotificationRequestId: UUID? = nil
    ) async -> Bool {

        dismissKeyboard()
        withAnimation(AnimationConstants.standard) {
            showLeftDrawer = false
            showRightDrawer = false
            showOverlay = false
            leftDragTranslation = 0
            rightDragTranslation = 0
            selectedDetent = .fraction(0.11)
        }

        let resolvedSymbol: RLTradingSymbolDTO
        if let cached = chartViewModel.allAvailableSymbols.first(where: { $0.id == payload.symbolId }) {
            resolvedSymbol = cached
        } else {
            do {
                resolvedSymbol = try await rlAppState.realApi.getSymbol(symbolId: payload.symbolId)
            } catch {
                rlAppState.showError(error, title: "Unable to Open Marker", style: .toast)
                return false
            }
        }

        let helper = MarkerNavigationHelper(
            chartViewModel: chartViewModel,
            gestureState: chartGestureState
        )
        if let expectedRequestId,
           rlAppState.pendingMarkerNavigationRequest?.id != expectedRequestId {
            return false
        }
        if let expectedNotificationRequestId,
           (pendingNotificationMarkerNavigation?.id != expectedNotificationRequestId
            || pendingNotificationMarkerNavigation?.guildId != rlAppState.currentGuild?.id
            || !rlAppState.isChartReady || rlAppState.showingTransition) {
            return false
        }
        return helper.navigateToMarker(
            MarkerNavigationTarget(sharedPayload: payload),
            resolvedSymbol: resolvedSymbol
        )
    }

    private func handlePendingPushNotificationTapIfNeeded() async {
        guard let payload = PushNotificationManager.shared.consumePendingTapPayload() else { return }

        if let notificationId = payload.notificationId {
            await rlAppState.markNotificationsAsRead(ids: [notificationId])
            if leftDrawerViewModel.userNotifications.contains(where: { $0.id == notificationId }) {
                leftDrawerViewModel.markNotificationAsRead(notificationId: notificationId)
            }
            do {
                try await rlAppState.recordNotificationView(notificationId: notificationId)
            } catch {
                print("⚠️ Failed to record push notification view: \(error)")
            }
        }

        await notificationNavigationManager.navigate(to: payload)
    }
}

// MARK: - Drawer Side
enum DrawerSide { case left, right }





// //
// //  MainView.swift
// //  traders_guild
// //
// //  UPDATED VERSION - Fixes bottom controls overlap with multiple indicator panels
// //

// import SwiftUI
// //import SwiftTradingView

// // MARK: - Constants
// enum LayoutConstants {
//     static let drawerWidthRatio: CGFloat = 0.9
//     static let drawerDismissThreshold: CGFloat = 100
//     static let overlayOpacity: CGFloat = 0.4
//     static let cornerRadius: CGFloat = 33
//     static let shadowRadius: CGFloat = 8
// }

// enum AnimationConstants {
//     static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
//     static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
// }

// // MARK: - Main View
// struct MainView: View {
//     // MARK: - Properties
//     @EnvironmentObject var rlAppState: RLAppState
    
//     @EnvironmentObject var appState: AppState // TODO: remove
//     @EnvironmentObject var messagingManager: MessagingManager
//     @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
//     @StateObject private var rightDrawerViewModel = RightDrawerViewModel()
//     @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
//     // MARK: - Chart State
//     @StateObject private var chartControlVM = ChartControlViewModel()
//     @StateObject private var chartDataManager = ChartDataManager()
//     @StateObject private var chartViewModel: ChartViewModel
//     @StateObject private var chartGestureState = ChartGestureState()
    
//     @State private var fadeIn: Bool = false
    
//     // MARK: - Drawer State Management
//     @State private var showLeftDrawer: Bool = false
//     @State private var showRightDrawer: Bool = false
//     @State private var showOverlay: Bool = false
//     @State private var leftDragTranslation: CGFloat = 0
//     @State private var rightDragTranslation: CGFloat = 0
    
//     // MARK: - Bottom Sheet State
//     @State private var showBottomSheet: Bool = false
//     @State private var selectedDetent: PresentationDetent = .fraction(0.11)
    
//     // MARK: - Sheet Overlay State
//     @State private var showSheetOverlay: Bool = false
//     @State private var dismissRightSheetsSignal: Bool = false
//     @State private var dismissLeftSheetsSignal: Bool = false
    
//     // MARK: - Indicator Panel State
//     @State private var rsiPanelHeight: CGFloat = 120
//     @State private var macdPanelHeight: CGFloat = 140
//     @State private var stochasticPanelHeight: CGFloat = 120
//     @State private var cciPanelHeight: CGFloat = 120
//     @State private var williamsRPanelHeight: CGFloat = 120
//     @State private var atrPanelHeight: CGFloat = 120
//     @State private var volumePanelHeight: CGFloat = 120
    
//     // MARK: - Computed Properties
//     private var screenSize: CGSize {
//         UIScreen.main.bounds.size
//     }
    
//     private var drawerWidth: CGFloat {
//         screenSize.width * LayoutConstants.drawerWidthRatio
//     }
    
//     /// Calculate total height of active indicator panels for bottom padding
//     private var indicatorPanelsTotalHeight: CGFloat {
//         let activePanels = chartViewModel.indicatorManager.activeIndicators.activePanelTypes
//         guard !activePanels.isEmpty else { return 0 }
        
//         var totalHeight: CGFloat = 0
        
//         for panelType in activePanels {
//             switch panelType {
//             case .rsi:
//                 totalHeight += rsiPanelHeight + 22  // +22 for resize handle
//             case .macd:
//                 totalHeight += macdPanelHeight + 22
//             case .stochastic:
//                 totalHeight += stochasticPanelHeight + 22
//             case .cci:
//                 totalHeight += cciPanelHeight + 22
//             case .williamsR:
//                 totalHeight += williamsRPanelHeight + 22
//             case .atr:
//                 totalHeight += atrPanelHeight + 22
//             case .volume:
//                 totalHeight += volumePanelHeight + 22
//             }
//         }
        
//         // Add X-axis labels height
//         totalHeight += 22
        
//         return totalHeight
//     }
    
//     /// Bottom padding for controls that need to float above indicator panels
//     private var bottomControlsPadding: CGFloat {
//         // Base padding for minimized bottom sheet + indicator panels
//         return indicatorPanelsTotalHeight + 100
//     }
    
//     // MARK: - Initialization
//     init() {
//         let dataManager = ChartDataManager()
//         _chartDataManager = StateObject(wrappedValue: dataManager)
//         _chartViewModel = StateObject(wrappedValue: ChartViewModel(
//             appState: AppState(),
//             dataManager: dataManager,
//             api: MockAPIService()
//         ))
        
        
//     }
    
//     // MARK: - Body
//     var body: some View {
//         if let user = appState.currentUser,
//            let guild = appState.currentGuild {
//             ZStack {
//                 // MARK: - Main Content Layer
//                 mainContentStack
//                     .disabled(showLeftDrawer || showRightDrawer)
                
//                 // MARK: - Indicator Panels Overlay
//                 // Positioned ABOVE main content, BELOW bottom sheet
//                 if chartViewModel.indicatorManager.shouldShowAnyPanel {
//                     VStack {
//                         Spacer()
                        
//                         IndicatorPanelContainer(
//                             indicatorManager: chartViewModel.indicatorManager,
//                             chartData: chartViewModel.dataManager,
//                             gestureState: chartGestureState,
//                             baseCandleWidth: 12,
//                             candleSpacing: 4,
//                             timeframe: chartViewModel.currentTimeframe,
//                             rsiPanelHeight: $rsiPanelHeight,
//                             macdPanelHeight: $macdPanelHeight,
//                             stochasticPanelHeight: $stochasticPanelHeight,
//                             cciPanelHeight: $cciPanelHeight,
//                             williamsRPanelHeight: $williamsRPanelHeight,
//                             atrPanelHeight: $atrPanelHeight,
//                             volumePanelHeight: $volumePanelHeight
//                         )
                        
//                         // DYNAMIC bottom padding - accounts for minimized bottom sheet
//                         Color.clear
//                             .frame(height: 100)
//                     }
//                     .ignoresSafeArea(edges: .bottom)
//                 }
                
//                 // MARK: - Overlay Layer
//                 if showOverlay {
//                     overlayView
//                         .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
//                         .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
//                         .animation(.easeOut(duration: 0.4), value: showRightDrawer)
//                         .gesture(
//                             DragGesture()
//                                 .onChanged { value in
//                                     dismissRightSheetsSignal = true
//                                     if showLeftDrawer && value.translation.width < 0 {
//                                         leftDragTranslation = value.translation.width
//                                     } else if showRightDrawer && value.translation.width > 0 {
//                                         rightDragTranslation = value.translation.width
//                                     }
//                                 }
//                                 .onEnded { value in
//                                     handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
//                                 }
//                         )
//                 }
                
//                 // MARK: - Drawer Layers
//                 leftDrawerView
//                     .opacity(fadeIn ? 1 : 0)
//                     .animation(.easeIn(duration: 1.5), value: fadeIn)
                
//                 rightDrawerView
//                     .opacity(fadeIn ? 1 : 0)
//                     .animation(.easeIn(duration: 1.5), value: fadeIn)
                
//                 // MARK: - Sheet Overlay Layer
//                 if showSheetOverlay {
//                     sheetOverlayView
//                         .opacity(showSheetOverlay ? 1 : 0)
//                         .animation(.linear(duration: 0.05), value: showSheetOverlay)
//                 }
//             }
//             .ignoresSafeArea()
//             .globalMessaging()
            
//             .observeMarkerNavigation(
//                 leftDrawerViewModel: leftDrawerViewModel,
//                 chartViewModel: chartViewModel,
//                 gestureState: chartGestureState,
//                 onCloseDrawer: {
//                     withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                         showLeftDrawer = false
//                         showOverlay = false
//                     }
//                 }
//             )
            
//             // MARK: - Bottom Sheet
//             .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !rlAppState.showingTransition)) {
//                 ChartBottomSheet(
//                     controlViewModel: chartControlVM,
//                     chartViewModel: chartViewModel,
//                     selectedDetent: $selectedDetent
//                 )
//                 .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
//                                       selection: $selectedDetent)
//                 .presentationDragIndicator(.visible)
//                 .presentationBackgroundInteraction(.enabled)
//                 .interactiveDismissDisabled(true)
//                 .presentationContentInteraction(.resizes)
//                 .presentationBackground {
//                     ZStack {
//                         Color.clear
//                             .background(.ultraThinMaterial)
//                         AppColors.drawerBackground.opacity(0.4)
//                     }
//                 }
//             }
//             .onAppear {
//                 withAnimation(.easeIn(duration: 1.5)) {
//                     fadeIn = true
//                 }
                
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                     withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
//                         showBottomSheet = true
//                     }
//                 }
//                 print(rlAppState.currentUser?.displayUsername ?? "Username")
//                 print(rlAppState.currentGuild?.name ?? "Guild Name")
//             }
//             .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//             .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
            
//             .environmentObject(leftDrawerViewModel)
//             .environmentObject(rightDrawerViewModel)
//             .environmentObject(notificationNavigationManager)
//             .task {
//                 // Use rlAppState guild ID for announcements (real API), fallback to old guild.id for other data
//                 let rlGuildId = rlAppState.currentGuild?.id ?? guild.id
                
//                 // leftDrawerViewModel uses rlGuildId for announcements via rlAppState
//                 await leftDrawerViewModel.preloadData(for: rlGuildId, appState: appState, rlAppState: rlAppState)
//                 // rightDrawerViewModel still uses old guild.id (no announcements)
//                 await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
                
//                 notificationNavigationManager.configure(
//                     appState: appState,
//                     messagingManager: messagingManager,
//                     rightDrawerViewModel: rightDrawerViewModel
//                 )
                
//                 // Initialize chart with data
//                 await chartViewModel.initialize()
                
//                 rlAppState.chartDidBecomeReady()
//             }
//             .onChange(of: rlAppState.currentGuild?.id) { oldValue, newValue in
//                 if let guildId = newValue, oldValue != newValue {
//                     Task {
//                         leftDrawerViewModel.clearCache()
//                         rightDrawerViewModel.clearCache()
//                         // Uses real rlAppState guild ID for announcements
//                         await leftDrawerViewModel.preloadData(for: guildId, appState: appState, rlAppState: rlAppState)
//                         await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
//                         await chartViewModel.initialize()
//                         rlAppState.chartDidBecomeReady()
//                     }
//                 }
//             }
            
// //            .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
// //                if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
// //                    // Dismiss keyboard first
// //                    dismissKeyboard()
// //
// //                    // Update chart
// //                    chartViewModel.setSymbol(symbol)
// //
// //                    // Close drawer if open
// //                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
// //                        showLeftDrawer = false
// //                    }
// //                }
// //            }
//         } else {
//             VStack(spacing: 20) {
//                 ProgressView()
//                     .scaleEffect(1.5)
//                 Text("Reconnecting...")
//                     .foregroundColor(.secondary)
//             }
//             .frame(maxWidth: .infinity, maxHeight: .infinity)
//             .onAppear {
//                 Task {
//                     if rlAppState.currentUser != nil && rlAppState.currentGuild == nil {
//                         await rlAppState.openGuildSelector()
//                     } else if rlAppState.currentUser == nil {
//                         rlAppState.logout()
//                     }
//                 }
//             }
//         }
//     }
    
//     // MARK: - View Components
    
//     private var mainContentStack: some View {
//         NavigationStack {
//             ZStack {
//                 StaticBackgroundView()
                
//                 VStack(spacing: 0) {
//                     chartView(controlViewModel: chartControlVM)
//                 }
//                 .opacity(fadeIn ? 1 : 0)
//                 .animation(.easeIn(duration: 1.5), value: fadeIn)
//                 .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
//                     if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
//                         // Dismiss keyboard first
//                         dismissKeyboard()
                        
//                         // Update chart
//                         chartViewModel.setSymbol(symbol)
                        
//                         // Close drawer if open
//                         withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                             showLeftDrawer = false
//                         }
//                     }
//                 }
//             }
//             .toolbar {
//                 // Left Drawer Button
//                 ToolbarItem(placement: .topBarLeading) {
//                     ToolbarIconButton(
//                         systemName: "shield.pattern.checkered",
//                         backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                         fontType: .headline,
//                         symbolRenderingMode: .monochrome,
//                         foregroundStyle: AppColors.whiteText,
//                         padding: 8
//                     ) {
                        
//                         withAnimation(AnimationConstants.standard) {
//                             dismissKeyboard()
//                             selectedDetent = .fraction(0.11)
//                             showLeftDrawer.toggle()
//                             showRightDrawer = false
//                             showOverlay = showLeftDrawer
//                         }
//                     }
//                 }
                
//                 // App Title
//                 ToolbarItem(placement: .principal) {
//                     Text("TG")
//                         .font(.largeTitle)
//                         .fontWeight(.heavy)
//                         .foregroundColor(AppColors.fadedBackground)
//                 }
                
//                 // Right Drawer Button
//                 ToolbarItem(placement: .topBarTrailing) {
//                     ToolbarIconButton(
//                         systemName: "message.badge.filled.fill",
//                         backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                         fontType: .subheadline,
//                         symbolRenderingMode: .monochrome,
//                         foregroundStyle: AppColors.whiteText,
//                         padding: 8
//                     ) {
//                         withAnimation(AnimationConstants.standard) {
//                             dismissKeyboard()
//                             selectedDetent = .fraction(0.11)
//                             showRightDrawer.toggle()
//                             showLeftDrawer = false
//                             showOverlay = showRightDrawer
//                         }
//                     }
//                 }
//             }
//             .toolbarBackground(.hidden, for: .navigationBar)
//             .toolbarColorScheme(.dark, for: .navigationBar)
//             .tint(.white)
//             .navigationBarTitleDisplayMode(.inline)
//         }
//     }
    
//     // UPDATED: Pass total indicator panel height for proper bottom controls positioning
//     private func chartView(controlViewModel: ChartControlViewModel) -> some View {
//         TradingChartView(
//             controlViewModel: controlViewModel,
//             chartViewModel: chartViewModel,
//             gestureState: chartGestureState,
//             rsiPanelHeight: $rsiPanelHeight,
//             indicatorPanelBottomPadding: indicatorPanelsTotalHeight
//         )
//     }
    
//     private var overlayView: some View {
//         AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity)
//             .ignoresSafeArea()
//             .onTapGesture {
//                 withAnimation(AnimationConstants.standard) {
//                     dismissKeyboard()
//                     showLeftDrawer = false
//                     showRightDrawer = false
//                     leftDragTranslation = 0
//                     rightDragTranslation = 0
//                     dismissRightSheetsSignal = true
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             }
//     }
    
//     private var sheetOverlayView: some View {
//         AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity * 0.8)
//             .ignoresSafeArea()
//             .contentShape(Rectangle())
//             .onTapGesture {
//                 dismissRightSheetsSignal = true
//                 dismissLeftSheetsSignal = true
//             }
//             .simultaneousGesture(DragGesture().onChanged { _ in
//                 dismissRightSheetsSignal = true
//                 dismissLeftSheetsSignal = true
//             })
//     }
    
//     // FIXED: Using LeftDrawerMainView (correct name)
//     private var leftDrawerView: some View {
//         HStack(spacing: 0) {
//             LeftDrawerMainView(
//                 sheetOverlayVisible: $showSheetOverlay,
//                 dismissSheetsSignal: $dismissLeftSheetsSignal,
//                 onClose: {
//                     dismissKeyboard()
//                     withAnimation(AnimationConstants.standard) {
//                         showLeftDrawer = false
//                         leftDragTranslation = 0
//                     }
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                         showOverlay = false
//                     }
//                 },
//                 currentSymbolId: chartViewModel.currentSymbol?.id
//             )
// //            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal, currentSymbolId: chartViewModel.currentSymbol?.id) {
// //                dismissKeyboard()
// //                withAnimation(AnimationConstants.standard) {
// //                    showLeftDrawer = false
// //                    leftDragTranslation = 0
// //                }
// //                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
// //                    showOverlay = false
// //                }
// //            }
//             .frame(width: drawerWidth)
//             .frame(maxHeight: .infinity)
//             .offset(x: leftDragTranslation)
//             .gesture(
//                 DragGesture()
//                     .onChanged { value in
//                         if value.translation.width < 0 {
//                             leftDragTranslation = value.translation.width
//                         }
//                     }
//                     .onEnded { value in
//                         handleDrawerDragEnd(currentPosition: leftDragTranslation)
//                     }
//             )
//             Spacer(minLength: 0)
//         }
//         .frame(maxHeight: .infinity)
//         .offset(x: showLeftDrawer ? 0 : -drawerWidth)
//         .animation(AnimationConstants.standard, value: showLeftDrawer)
//     }
    
//     // FIXED: Using RightDrawerMainView (correct name)
//     private var rightDrawerView: some View {
//         HStack(spacing: 0) {
//             Spacer(minLength: 0)
//             RightDrawerMainView(
//                 onClose: {
//                     dismissKeyboard()
//                     withAnimation(AnimationConstants.standard) {
//                         showRightDrawer = false
//                         rightDragTranslation = 0
//                     }
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                         showOverlay = false
//                     }
//                 }
//             )
//             .frame(width: drawerWidth)
//             .frame(maxHeight: .infinity)
//             .offset(x: rightDragTranslation)
//             .gesture(
//                 DragGesture()
//                     .onChanged { value in
//                         if value.translation.width > 0 {
//                             rightDragTranslation = value.translation.width
//                         }
//                     }
//                     .onEnded { value in
//                         handleDrawerDragEnd(currentPosition: rightDragTranslation)
//                     }
//             )
//         }
//         .frame(maxHeight: .infinity)
//         .offset(x: showRightDrawer ? 0 : drawerWidth)
//         .animation(AnimationConstants.standard, value: showRightDrawer)
//     }
    
//     // MARK: - Helper Functions
    
//     private func handleDrawerDragEnd(currentPosition: CGFloat) {
//         if showLeftDrawer {
//             if currentPosition < -LayoutConstants.drawerDismissThreshold {
//                 dismissKeyboard()
//                 withAnimation(AnimationConstants.standard) {
//                     showLeftDrawer = false
//                     leftDragTranslation = 0
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             } else {
//                 withAnimation(AnimationConstants.standard) {
//                     leftDragTranslation = 0
//                 }
//             }
//         } else if showRightDrawer {
//             if currentPosition > LayoutConstants.drawerDismissThreshold {
//                 dismissKeyboard()
//                 withAnimation(AnimationConstants.standard) {
//                     showRightDrawer = false
//                     rightDragTranslation = 0
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             } else {
//                 withAnimation(AnimationConstants.standard) {
//                     rightDragTranslation = 0
//                 }
//             }
//         }
//     }
    
    
//     private func dismissKeyboard() {
//         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//     }
// }

// // MARK: - Drawer Side
// enum DrawerSide { case left, right }

enum ChartBottomSheetStateReducer {
    static func markerDetailTabAfterDetentChange(
        oldDetent: PresentationDetent,
        newDetent: PresentationDetent,
        isMarkerDetailActive: Bool,
        currentTab: MarkerViewingTab
    ) -> MarkerViewingTab {
        guard isMarkerDetailActive,
              currentTab == .chat,
              oldDetent != .fraction(0.11),
              newDetent == .fraction(0.11) else {
            return currentTab
        }

        return .general
    }
}

// MARK: - Chart Bottom Sheet (IMPROVED CHAT VERSION)
// When in chat mode, the tab bar is replaced with chat input + back button
struct ChartBottomSheet: View {
    /// Owned by MainView so the walkthrough can open the sheet on Markers.
    @Binding var selectedView: ChartView
    @ObservedObject var controlViewModel: ChartControlViewModel
    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var placementState: MarkerPlacementState
    @ObservedObject var markerOverlayState: MarkerOverlayState
    @ObservedObject var timeframePanelManager: TimeframePanelManager
    @Binding var selectedDetent: PresentationDetent
    /// The toolbar asked to discard an edited guided draft. The confirmation
    /// is presented from this sheet because the sheet is what is on screen: a
    /// dialog presented from `MainView` would pre-empt it, and UIKit traps.
    @Binding var guidedDiscardConfirmation: Bool
    @EnvironmentObject var rlAppState: RLAppState
    let onNavigateToMarker: ((RLTopMarkerDTO) -> Void)?
    let onPlaceMarker: (() -> Void)?
    var onViewingAuthorTap: ((ChartMarkerUI) -> Void)? = nil
    /// Travel to a thesis node that is not on the current chart. Owned by
    /// `MainView`, which holds the drawer view model that performs navigation.
    var onNavigateToLinkedMarker: ((MarkerNavigationTarget) -> Void)? = nil

    // Chat state - managed here since parent handles input
    @StateObject private var chartChatManager: ChartChatManager
    @StateObject private var chatSurfaceOverlayCoordinator = ChatSurfaceOverlayCoordinator()
    @State private var chatMessageText: String = ""
    @State private var chartReplyDraft: ChatReplyDraft? = nil
    @State private var isSendingChartMessage = false
    @State private var localChartSendScrollSignal = ChatLocalSendScrollSignal()
    @State private var markerDetailTab: MarkerViewingTab = .general
    @State private var placementIndicatorSnapshot = PlacementIndicatorSnapshot()

    init(
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel,
        placementState: MarkerPlacementState,
        markerOverlayState: MarkerOverlayState,
        timeframePanelManager: TimeframePanelManager,
        selectedDetent: Binding<PresentationDetent>,
        selectedView: Binding<ChartView>,
        guidedDiscardConfirmation: Binding<Bool> = .constant(false),
        onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil,
        onPlaceMarker: (() -> Void)? = nil,
        onViewingAuthorTap: ((ChartMarkerUI) -> Void)? = nil,
        onNavigateToLinkedMarker: ((MarkerNavigationTarget) -> Void)? = nil
    ) {
        self.onNavigateToLinkedMarker = onNavigateToLinkedMarker
        self.controlViewModel = controlViewModel
        self.chartViewModel = chartViewModel
        self.placementState = placementState
        self.markerOverlayState = markerOverlayState
        self.timeframePanelManager = timeframePanelManager
        self._selectedDetent = selectedDetent
        self._selectedView = selectedView
        self._guidedDiscardConfirmation = guidedDiscardConfirmation
        self.onNavigateToMarker = onNavigateToMarker
        self.onPlaceMarker = onPlaceMarker
        self.onViewingAuthorTap = onViewingAuthorTap
        // Initialize ChartChatManager with RealAPIService
        // We'll configure it with rlAppState in onAppear
        _chartChatManager = StateObject(wrappedValue: ChartChatManager(
            appState: nil,
            api: RealAPIService()
        ))
    }
    
    enum ChartView: String, CaseIterable {
        case symbol = "Symbol"
        case chat = "Chat"
        case components = "Components"
        case markers = "Markers"
        
        var icon: String {
            switch self {
            case .symbol: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .components: return "plus.viewfinder"
            case .markers: return "mappin.circle.fill"
            }
        }
    }
    
    private var isExpanded: Bool {
        selectedDetent != .fraction(0.11)
    }

    private var isMarkerDetailActive: Bool {
        chartViewModel.selectedMarkerForSheet != nil
    }

    private var shouldIgnoreKeyboardSafeArea: Bool {
        if isMarkerDetailActive && markerDetailTab == .chat { return false }
        if selectedView == .chat && isExpanded { return false }
        return true
    }

    private var chatActionPanelVisibility: Binding<Bool> {
        Binding(
            get: { chatSurfaceOverlayCoordinator.isComposerActionPanelVisible },
            set: { isVisible in
                chatSurfaceOverlayCoordinator.setComposerActionPanelVisible(isVisible)
            }
        )
    }

    var body: some View {
        Group {
            if selectedView == .chat && isExpanded && !controlViewModel.isMarkerPlacementMode && !isMarkerDetailActive {
                KeyboardAwareBottomInsetContainer(
                    showsDivider: true,
                    mode: .chat,
                    footerBackground: AnyView(ChatChromeBarBackground())
                ) {
                    sheetPrimaryContent
                } footer: {
                    chatInputFooter
                }
            } else {
                VStack(spacing: 0) {
                    sheetPrimaryContent
                    sheetBottomBar
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedView)
        .animation(.easeInOut(duration: 0.3), value: isMarkerDetailActive)
        .animation(nil, value: shouldIgnoreKeyboardSafeArea)
        .ignoresSafeArea(.keyboard, edges: shouldIgnoreKeyboardSafeArea ? .bottom : [])
        .environmentObject(chatSurfaceOverlayCoordinator)
        .modifier(MarkerGuidedDiscardConfirmation(isPresented: $guidedDiscardConfirmation) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                controlViewModel.cancelMarkerPlacement()
            }
        })
        .onAppear {
            chartChatManager.configure(with: rlAppState)
        }
        .onChange(of: chartViewModel.currentSymbol) {
            loadChatForCurrentSymbol()
        }
        .onChange(of: rlAppState.currentGuild?.id) {
            loadChatForCurrentSymbol()
        }
        .onChange(of: selectedView) { _, newView in
            chatSurfaceOverlayCoordinator.dismissAll()
            if newView == .chat {
                loadChatForCurrentSymbol()
            }
        }
        .onChange(of: chartViewModel.selectedMarkerForSheet?.id) { _, newId in
            chatSurfaceOverlayCoordinator.dismissAll()
            if newId != nil {
                markerDetailTab = .general
                // Keep sheet at closed state (0.11) — user drags up to expand
            }
        }
        .onChange(of: selectedDetent) { oldValue, newValue in
            handleSelectedDetentChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: controlViewModel.isMarkerPlacementMode) { _, isPlacing in
            handlePlacementIndicatorLifecycle(isPlacing: isPlacing)
        }
        .onChange(of: placementIndicatorFingerprint) { _, _ in
            guard controlViewModel.isMarkerPlacementMode else { return }
            applyPlacementIndicatorsToChart()
        }
        .onChange(of: viewingIndicatorFingerprint) { _, _ in
            refreshViewingIndicatorsIfNeeded()
        }
    }

    private func handleSelectedDetentChange(oldValue: PresentationDetent, newValue: PresentationDetent) {
        let updatedTab = ChartBottomSheetStateReducer.markerDetailTabAfterDetentChange(
            oldDetent: oldValue,
            newDetent: newValue,
            isMarkerDetailActive: isMarkerDetailActive,
            currentTab: markerDetailTab
        )

        guard updatedTab != markerDetailTab else { return }
        chatSurfaceOverlayCoordinator.dismissAll()
        withAnimation(.easeInOut(duration: 0.2)) {
            markerDetailTab = updatedTab
        }
    }

    @ViewBuilder
    private var sheetPrimaryContent: some View {
        if isExpanded {
            if controlViewModel.isMarkerPlacementMode {
                placementModeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isMarkerDetailActive,
                      let marker = chartViewModel.selectedMarkerForSheet,
                      let markerManager = chartViewModel.markerManager {
                markerDetailContent(marker: marker, markerManager: markerManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedView == .chat {
                chatContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedView == .components {
                componentsContent
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedView == .symbol {
                symbolAndSettingsContent
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedView {
                        case .markers:
                            markersContent
                        case .symbol, .components, .chat:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollDismissesKeyboard(.interactively)
            }
        } else {
            Spacer()
        }
    }

    @ViewBuilder
    private var sheetBottomBar: some View {
        if controlViewModel.isMarkerPlacementMode {
            if placementState.isGuidedFlowActive {
                MarkerGuidedPlacementBar(placementState: placementState) {
                    onPlaceMarker?()
                }
            } else {
                placementTabBar
            }
        } else if isMarkerDetailActive {
            if markerDetailTab == .chat {
                EmptyView()
            } else {
                markerDetailTabBar
            }
        } else {
            standardTabBar
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadChatForCurrentSymbol() {
        guard let symbol = chartViewModel.currentSymbol,
              let guildId = rlAppState.currentGuild?.id else {
            chartChatManager.closeChat()
            return
        }
        
        Task {
            await chartChatManager.updateForSymbol(
                symbol,
                guildId: guildId
            )
        }
    }
    
    // MARK: - Chat Input Footer (Replaces Tab Bar in Chat Mode)
    
    private var chatInputFooter: some View {
        ChatInputFooter(
            messageText: $chatMessageText,
            replyDraft: $chartReplyDraft,
            placeholder: "Message #\(chartChatManager.activeChartChat?.symbolTicker.lowercased() ?? "chat")...",
            isSending: isSendingChartMessage,
            onSend: { payload in
                await sendChartComposedMessage(payload)
            },
            allowsMarkerLinkAttachment: true,
            selectedDetent: $selectedDetent,
            expandedDetent: .fraction(0.9),
            leadingAccessory: AnyView(
                Button(action: {
                    chatSurfaceOverlayCoordinator.dismissAll()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedView = .symbol
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(AppColors.gradientBackgroundDark)
                        .clipShape(Circle())
                        .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
                }
            ),
            isActionPanelVisible: chatActionPanelVisibility
        )
    }

    // MARK: - Chat Message Sending
    
    private func sendChartComposedMessage(_ payload: ChatComposerPayload) async -> Bool {
        guard !isSendingChartMessage else { return false }
        isSendingChartMessage = true
        defer { isSendingChartMessage = false }

        guard payload.hasBodyContent else { return false }

        do {
            let uploadedAttachments = try await uploadChartAttachments(payload.attachments)
            try await chartChatManager.sendMessage(
                content: payload.encodedContent(),
                attachmentUrl: uploadedAttachments.first?.attachmentUrl,
                attachmentType: uploadedAttachments.first?.attachmentType,
                attachmentName: uploadedAttachments.first?.attachmentName,
                attachments: uploadedAttachments,
                replyToMessageId: payload.replyDraft?.messageId
            )
            HapticFeedback.light.trigger()
            chartReplyDraft = nil
            localChartSendScrollSignal.commit()
            return true
        } catch {
            rlAppState.showError(error, title: "Failed to Send Message", style: .toast)
            return false
        }
    }

    private func uploadChartAttachments(_ drafts: [ChatAttachmentDraft]) async throws -> [RLMessageAttachmentDTO] {
        guard !drafts.isEmpty else { return [] }
        guard let guildId = rlAppState.currentGuild?.id,
              let chatId = chartChatManager.activeChartChat?.id else {
            throw RLAppError.noGuildSelected
        }

        var uploads: [RLMessageAttachmentDTO] = []
        for attachment in drafts {
            let upload = try await rlAppState.realApi.uploadChartChatAttachment(
                guildId: guildId,
                chatId: chatId,
                fileData: attachment.data,
                filename: attachment.filename,
                mimeType: attachment.mimeType
            )
            uploads.append(
                RLMessageAttachmentDTO(
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
            )
        }
        return uploads
    }
    
    // MARK: - Standard Tab Bar
    
    
    // Helper to get current symbol as DTO for icon display
    private var currentSymbolDTO: RLTradingSymbolDTO? {
        return chartViewModel.currentSymbol
    }
    
    private var standardTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }
            
            HStack(spacing: 4) {
                // Symbol button - NOW WITH PROPER ICON
                RootBottomBarSymbolButton(
                    symbol: chartViewModel.currentSymbol?.ticker ?? "EURUSD",
                    symbolDTO: currentSymbolDTO,  // <-- ADD THIS LINE
                    backgroundColor: selectedView == .symbol ?
                        AppColors.chartSheetMainTabSelectedBackground :
                        AppColors.chartSheetMainTabUnselectedBackground,
                    foregroundColor: selectedView == .symbol ?
                        AppColors.chartSheetMainTabSelectedForeground :
                        AppColors.chartSheetMainTabUnselectedForeground
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedView = .symbol
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Chat button
                    RootBottomBarIconButton(
                        systemName: "message.fill",
                        backgroundColor: selectedView == .chat ?
                            AppColors.chartSheetMainTabSelectedBackground :
                            AppColors.chartSheetMainTabUnselectedBackground,
                        foregroundColor: selectedView == .chat ?
                            AppColors.chartSheetMainTabSelectedForeground :
                            AppColors.chartSheetMainTabUnselectedForeground
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .chat
                        }
                    }

                    
                    // Indicator button
                    RootBottomBarIconButton(
                        systemName: "plus.viewfinder",
                        fontSize: 25,
                        backgroundColor: selectedView == .components ?
                            AppColors.chartSheetMainTabSelectedBackground :
                            AppColors.chartSheetMainTabUnselectedBackground,
                        foregroundColor: selectedView == .components ?
                            AppColors.chartSheetMainTabSelectedForeground :
                            AppColors.chartSheetMainTabUnselectedForeground
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .components
                        }
                    }
                    
                    // Markers button
                    RootBottomBarIconButton(
                        systemName: "target",
                        fontSize: 25,
                        backgroundColor: selectedView == .markers ?
                            AppColors.chartSheetMarkersTabSelectedBackground :
                            AppColors.chartSheetMarkersTabUnselectedBackground,
                        foregroundColor: selectedView == .markers ?
                            AppColors.chartSheetMarkersTabSelectedForeground :
                            AppColors.chartSheetMarkersTabUnselectedForeground
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .markers
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard)
        .background(bottomTabBarContainerBackground)
    }

    // MARK: - Placement Tab Bar

    private var bottomBarSelectedBackground: Color {
        AppColors.placementBarSelectedFill
    }

    private var bottomBarUnselectedBackground: Color {
        AppColors.placementBarUnselectedFill
    }

    private var bottomBarSelectedForeground: Color {
        AppColors.placementBarSelectedForeground
    }

    private var bottomBarUnselectedForeground: Color {
        AppColors.placementBarUnselectedForeground
    }

    private var bottomTabBarContainerBackground: Color {
        switch ThemeManager.shared.currentTheme {
        case .lightGrey, .dark:
            return AppColors.sheetBackground
        case .midGrey:
            return .clear
        }
    }

    /// A dot on a placement tab button when that tab still has unmet required items.
    @ViewBuilder
    private func placementRequirementDot(count: Int) -> some View {
        if count > 0 {
            Circle()
                .fill(AppColors.statusWarning)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(bottomTabBarContainerBackground, lineWidth: 2))
                .offset(x: -3, y: 3)
        }
    }

    private var placementBottomBarActionColor: Color {
        guard placementState.intent == .alert else {
            return placementState.intent.color
        }
        return placementState.alertSeverity?.color ?? placementState.intent.color
    }

    private var placementBottomBarShowsMarkerColor: Bool {
        placementState.isValid || (placementState.intent == .alert && placementState.alertSeverity != nil)
    }

    private var placementTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }

            HStack(spacing: 4) {
                placementGeneralTabButton(
                    isSelected: placementState.selectedPlacementTab == .general
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        placementState.selectedPlacementTab = .general
                    }
                }
                .overlay(alignment: .topTrailing) {
                    placementRequirementDot(count: placementState.unmetRequiredCount(for: .general))
                }
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    ForEach(MarkerPlacementTab.allCases.filter { $0 != .general }, id: \.self) { tab in
                        RootBottomBarIconButton(
                            systemName: tab.icon,
                            fontSize: 21,
                            backgroundColor: placementState.selectedPlacementTab == tab ?
                                bottomBarSelectedBackground :
                                bottomBarUnselectedBackground,
                            foregroundColor: placementState.selectedPlacementTab == tab ?
                                bottomBarSelectedForeground :
                                bottomBarUnselectedForeground
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                placementState.selectedPlacementTab = tab
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            placementRequirementDot(count: placementState.unmetRequiredCount(for: tab))
                        }
                    }

                    Button {
                        if placementState.isValid {
                            onPlaceMarker?()
                        } else if let tab = placementState.unmetRequiredChecklistItems.first?.tab {
                            // A dead button that says nothing is the whole complaint. Send the
                            // user to the tab that can fix the first unmet requirement.
                            withAnimation(.easeInOut(duration: 0.25)) {
                                placementState.selectedPlacementTab = tab
                            }
                        }
                    } label: {
                        let actionColor = placementBottomBarActionColor
                        let showsMarkerColor = placementBottomBarShowsMarkerColor
                        let primaryOpacity: Double = placementState.isValid ? 0.96 : 0.58
                        let secondaryOpacity: Double = placementState.isValid ? 0.74 : 0.36
                        Image(systemName: "target")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(showsMarkerColor ? .white : AppColors.whiteText.opacity(0.55))
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .fill(
                                        showsMarkerColor
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [
                                                        actionColor.opacity(primaryOpacity),
                                                        actionColor.opacity(secondaryOpacity),
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            : AnyShapeStyle(bottomBarUnselectedBackground)
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        showsMarkerColor
                                            ? actionColor.opacity(placementState.isValid ? 0.72 : 0.48)
                                            : AppColors.whiteText.opacity(0.16),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: showsMarkerColor
                                    ? actionColor.opacity(placementState.isValid ? 0.22 : 0.14)
                                    : .clear,
                                radius: 6,
                                x: 0,
                                y: 1
                            )
                    }
                    .buttonStyle(.plain)
                    // Deliberately NOT .disabled: an invalid tap now navigates to the requirement
                    // that is blocking it. The dimmed fill still reads as "not ready".
                    .opacity(placementBottomBarShowsMarkerColor ? 1.0 : 0.55)
                    .accessibilityLabel(
                        placementState.isValid
                            ? (placementState.isEditingExistingMarker ? "Save" : "Place Marker")
                            : "Place Marker — \(placementState.unmetRequiredChecklistItems.first?.title ?? "not ready")"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard)
        .background(bottomTabBarContainerBackground)
    }
    
    
    // MARK: - Symbol Tab Content
    private var symbolAndSettingsContent: some View {
        ChartSheetSymbolView(
            chartViewModel: chartViewModel
        )
    }
    
    // MARK: - Components Tab Content
    private var componentsContent: some View {
        let latestCandle = chartViewModel.dataManager.candles.last
        return ChartComponentsContent(
            placementState: chartViewModel.chartComponentsPlacementState,
            indicatorManager: chartViewModel.indicatorManager,
            drawingManager: chartViewModel.chartDrawingManager,
            timeframeLinkManager: chartViewModel.chartTimeframeLinkManager,
            currentChartTimeframe: chartViewModel.currentTimeframe,
            onSelectTimeframe: { timeframe in
                if chartViewModel.currentTimeframe != timeframe {
                    chartViewModel.setTimeframe(timeframe)
                }
            },
            onRecalculate: {
                chartViewModel.recalculateIndicators()
            },
            onBeginInteractiveDrawing: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDetent = .fraction(0.11)
                }
            },
            symbolId: chartViewModel.currentSymbol?.id,
            anchorTime: latestCandle?.timestamp,
            anchorPrice: latestCandle?.close
        )
    }
    
    // MARK: - Markers Tab Content
    private var markersContent: some View {
        chartSheetMarkersView(
            chartViewModel: chartViewModel,
            controlViewModel: controlViewModel,
            placementState: placementState,
            onNavigateToMarker: onNavigateToMarker,
            onMarkerSelection: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDetent = .fraction(0.11)
                }
            }
        )
    }
    
    // MARK: - Placement Mode Content
    private var placementModeContent: some View {
        let liveChartIndicatorPayloads = MarkerPlacementIndicatorFactory.activePayloads(
            from: chartViewModel.indicatorManager.activeIndicators
        )
        let liveChartDrawings = chartViewModel.chartDrawingManager.activeDrawings
        let indicators = placementIndicatorSnapshot.didCapture
            ? placementIndicatorSnapshot.indicators
            : liveChartIndicatorPayloads
        let drawings = placementIndicatorSnapshot.didCapture
            ? placementIndicatorSnapshot.drawings
            : liveChartDrawings
        let viewportAnchorProvider: () -> (time: Date, price: Double)? = { [weak placementState] in
            guard let state = placementState,
                  let time = state.currentViewportAnchorTime,
                  let price = state.currentViewportAnchorPrice else {
                return nil
            }
            return (time: time, price: price)
        }
        return Group {
            if placementState.isGuidedFlowActive {
                // v1.5 guided creation — the same draft, a different view of it.
                MarkerGuidedPlacementPanel(
                    placementState: placementState,
                    author: guidedPlacementAuthor,
                    guildName: rlAppState.currentGuild?.name,
                    currentChartTimeframe: chartViewModel.currentTimeframe,
                    activeChartIndicators: indicators,
                    activeChartDrawings: drawings,
                    onSelectTimeframe: { timeframe in
                        selectPlacementTimeframe(timeframe)
                    },
                    onBeginInteractiveDrawing: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDetent = .fraction(0.11)
                        }
                    },
                    viewportAnchorProvider: viewportAnchorProvider
                )
            } else {
                MarkerPlacementPanel(
                    placementState: placementState,
                    activeChartIndicators: indicators,
                    activeChartDrawings: drawings,
                    currentChartTimeframe: chartViewModel.currentTimeframe,
                    onSelectTimeframe: { timeframe in
                        selectPlacementTimeframe(timeframe)
                    },
                    onBeginInteractiveDrawing: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDetent = .fraction(0.11)
                        }
                    },
                    viewportAnchorProvider: viewportAnchorProvider
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// The viewer, who is the author of whatever they are placing.
    private var guidedPlacementAuthor: MarkerAvatarIdentity {
        var identity = MarkerAvatarIdentity.forCurrentUser(
            username: rlAppState.currentUser?.username,
            avatarUrl: rlAppState.currentUser?.avatarUrl
        )
        identity.authorId = rlAppState.currentUser?.id
        return identity
    }

    private func selectPlacementTimeframe(_ timeframe: RLChartTimeframe) {
        guard let context = placementState.linkSession.context else {
            chartViewModel.setTimeframe(timeframe)
            return
        }
        guard !placementState.isChangingResponseTimeframe,
              chartViewModel.currentTimeframe != timeframe || placementState.responseTimeframeLoadFailed,
              let symbol = chartViewModel.currentSymbol,
              symbol.id == context.parentSymbolId,
              rlAppState.currentGuild?.id == context.parentGuildId else { return }

        let anchorTime = placementState.anchorDraft?.payload.anchorTime ?? context.parentCandleTimestamp
        let requestID = placementState.beginResponseTimeframeChange()
        Task { @MainActor in
            // Reuse the chart's awaited context-loading path, rather than
            // guessing when setTimeframe's asynchronous request has finished.
            let prepared = await chartViewModel.prepareChartContext(symbol: symbol, timeframe: timeframe, forceReload: true)
            guard placementState.responseTimeframeChangeID == requestID else { return }
            guard prepared,
                  chartViewModel.currentSymbol?.id == context.parentSymbolId,
                  chartViewModel.currentTimeframe == timeframe,
                  rlAppState.currentGuild?.id == context.parentGuildId else {
                placementState.finishResponseTimeframeChange(requestID, succeeded: false)
                return
            }

            if MarkerResponseAnchorResolver.index(
                for: anchorTime, candles: chartViewModel.dataManager.candles, timeframe: timeframe
            ) == nil {
                await chartViewModel.loadNavigationWindow(around: anchorTime, timeframe: timeframe)
            }
            guard placementState.responseTimeframeChangeID == requestID else { return }
            let ready = chartViewModel.currentTimeframe == timeframe
                && chartViewModel.currentSymbol?.id == context.parentSymbolId
                && rlAppState.currentGuild?.id == context.parentGuildId
                && MarkerResponseAnchorResolver.index(
                    for: anchorTime, candles: chartViewModel.dataManager.candles, timeframe: timeframe
                ) != nil
            placementState.finishResponseTimeframeChange(requestID, succeeded: ready)
            if ready { controlViewModel.focusResponseAnchorAction?() }
        }
    }

    // MARK: - Chat Tab Content
    private var chatContent: some View {
        ImprovedChartSheetChatView(
            chartViewModel: chartViewModel,
            chartChatManager: chartChatManager,
            selectedDetent: $selectedDetent,
            messageText: $chatMessageText,
            replyDraft: $chartReplyDraft,
            localSendScrollRevision: localChartSendScrollSignal.revision,
            onBackgroundTap: {
                chatSurfaceOverlayCoordinator.dismissAll()
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
        .environmentObject(rlAppState)
    }

    // MARK: - Marker Detail Mode

    @ViewBuilder
    private func markerDetailContent(marker: ChartMarkerUI, markerManager: MarkerManager) -> some View {
        switch markerDetailTab {
        case .general:
            MarkerViewingGeneralTab(
                marker: marker,
                markerManager: markerManager,
                onClose: clearSelectedMarker,
                symbolDTO: chartViewModel.currentSymbol,
                onAuthorTap: { onViewingAuthorTap?(marker) },
                canEditMarker: canEditSelectedMarker,
                onEditMarker: { liveMarker in
                    beginEditingSelectedMarker(liveMarker)
                },
                onShareMarker: shareSelectedMarker,
                threadStore: rlAppState.markerThreadStore,
                onRespondToMarker: { relationship in
                    beginRespondingToSelectedMarker(marker, relationship: relationship)
                },
                onOpenLinkedMarker: { preview in
                    openLinkedMarker(preview)
                }
            )
            .environmentObject(rlAppState)
        case .chat:
            EmbeddedMarkerChatTabView(
                marker: marker,
                markerManager: markerManager,
                selectedDetent: $selectedDetent,
                onExitChat: {
                    chatSurfaceOverlayCoordinator.dismissAll()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        markerDetailTab = .general
                    }
                }
            )
            .environmentObject(rlAppState)
        case .components:
            MarkerViewingComponentsTab(marker: marker)
        }
    }

    private func clearSelectedMarker() {
        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
        }
    }

    private func beginEditingSelectedMarker(_ sourceMarker: ChartMarkerUI? = nil) {
        let marker = resolvedMarkerForEditing(sourceMarker)
        guard let marker,
              isMarkerEditableForCurrentUser(marker) else {
            return
        }

        placementState.beginEditingMarker(marker)
        // With the avatar prototype on, an Analysis the guided flow posted as
        // text alone stays valid as text alone when edited.
        if MarkerAvatarExperiment.isEnabled {
            placementState.allowTextOnlyAnalysisEdit()
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
            controlViewModel.startMarkerPlacement(intent: marker.intent)
        }
    }

    /// Leave the detail sheet and start composing a response.
    ///
    /// Deliberately mirrors `beginEditingSelectedMarker`: seed placement state,
    /// clear the selection, enter placement mode. Every response starts as
    /// Analysis so an older Setup parent does not invoke Setup's latest-candle
    /// placement; the author can still choose another intent.
    private func beginRespondingToSelectedMarker(
        _ sourceMarker: ChartMarkerUI,
        relationship: MarkerLinkRelationship
    ) {
        let marker = chartViewModel.markerManager?.markers
            .first(where: { $0.id == sourceMarker.id }) ?? sourceMarker

        // A private marker has no audience to answer, and the server rejects a
        // link to one.
        guard marker.visibility == "guild",
              chartViewModel.markerManager?.linkedMarkersEnabled == true,
              marker.guildId == rlAppState.currentGuild?.id,
              marker.symbolId == chartViewModel.currentSymbol?.id else { return }

        placementState.beginRespondingTo(
            MarkerLinkContext(
                parentMarkerId: marker.id,
                parentGuildId: marker.guildId,
                parentSymbolId: marker.symbolId,
                parentCandleTimestamp: marker.candleTimestamp,
                parentAuthorDisplayText: marker.author.username,
                parentTitle: marker.title,
                parentIntent: marker.intent,
                parentTimeframe: RLChartTimeframe.fromBackendString(marker.timeframe),
                relationship: relationship
            )
        )

        // With the avatar prototype on, a response is composed in the guided
        // flow; it still starts as Analysis, and "Change type" can make it a
        // structured Setup without losing the link.
        if MarkerAvatarExperiment.isEnabled {
            placementState.prepareGuidedFlow()
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
            chartViewModel.selectedMarkerForSheet = nil
            controlViewModel.startMarkerPlacement(intent: .analysis)
            selectedDetent = .fraction(0.35)
        }
    }

    /// Jump to another marker in the same thesis.
    ///
    /// Already-loaded markers are selected in place, which re-focuses the
    /// thesis around them without dismissing the sheet. Anything else — another
    /// timeframe, or history not yet paged in — goes through the existing
    /// navigation helper, with the selection staged so it survives the reload.
    private func openLinkedMarker(_ preview: RLMarkerLinkPreviewDTO) {
        guard let markerId = preview.markerId,
              let markerManager = chartViewModel.markerManager else { return }

        if let loaded = markerManager.markers.first(where: { $0.id == markerId }) {
            HapticFeedback.selection.trigger()
            // Centre it as a glyph tap would; selecting alone left the target
            // wherever it sat, often off to one side or under the sheet.
            if let center = controlViewModel.centerOnMarkerAction {
                center(loaded)
            } else {
                markerManager.selectedMarker = loaded
            }
            return
        }

        guard let target = MarkerNavigationTarget(linkPreview: preview) else { return }
        // Staged so the selection survives the marker teardown that a symbol or
        // timeframe change performs.
        rlAppState.markerThreadStore.stagePendingNavigation(markerId: markerId)
        onNavigateToLinkedMarker?(target)
    }

    private func resolvedMarkerForEditing(_ sourceMarker: ChartMarkerUI?) -> ChartMarkerUI? {
        let candidate = sourceMarker ?? chartViewModel.selectedMarkerForSheet
        guard let candidate else { return nil }
        if let live = chartViewModel.markerManager?.markers.first(where: { $0.id == candidate.id }) {
            return live
        }
        return candidate
    }

    private func toggleSelectedMarkerLike() {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return }
        Task {
            await chartViewModel.markerManager?.toggleLike(markerId: marker.id)
        }
    }

    private var placementIndicatorFingerprint: String {
        placementState.indicatorDrafts
            .map { draft in
                switch draft.payload {
                case .indicator(let payload):
                    return indicatorPayloadFingerprint(payload)
                default:
                    return draft.id.uuidString
                }
            }
            .joined(separator: "||")
    }

    private var viewingIndicatorFingerprint: String {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return "" }
        return marker.components
            .filter { $0.componentTypeEnum == .indicator }
            .sorted { lhs, rhs in
                if lhs.ordering != rhs.ordering { return lhs.ordering < rhs.ordering }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { component in
                guard case let .indicator(payload) = component.payload else {
                    return component.id.uuidString
                }
                return "\(component.id.uuidString)|\(indicatorPayloadFingerprint(payload))"
            }
            .joined(separator: "||")
    }

    private func indicatorPayloadFingerprint(_ payload: IndicatorPayload) -> String {
        "\(payload.name)|\(indicatorSettingsFingerprint(payload.settings))"
    }

    private func indicatorSettingsFingerprint(_ settings: [String: AnyCodable]?) -> String {
        guard let settings, !settings.isEmpty else { return "no-settings" }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(settings),
              let encoded = String(data: data, encoding: .utf8) else {
            return "settings-encoding-failed"
        }
        return encoded
    }

    private var placementIndicatorComponents: [RLMarkerComponentDTO] {
        placementState.indicatorDrafts.compactMap { draft in
            guard case let .indicator(payload) = draft.payload else { return nil }
            return RLMarkerComponentDTO(
                id: draft.id,
                componentType: RLComponentType.indicator.rawValue,
                payload: .indicator(payload),
                ordering: 0
            )
        }
    }

    private func handlePlacementIndicatorLifecycle(isPlacing: Bool) {
        if isPlacing {
            if !placementIndicatorSnapshot.didCapture {
                chartViewModel.indicatorManager.saveSnapshot()
                placementIndicatorSnapshot.captureIfNeeded(
                    from: chartViewModel.indicatorManager.activeIndicators,
                    drawings: chartViewModel.chartDrawingManager.activeDrawings
                )
            }
            applyPlacementIndicatorsToChart()
            return
        }

        if placementIndicatorSnapshot.didCapture {
            chartViewModel.indicatorManager.restoreSnapshot()
            chartViewModel.indicatorManager.recalculateIndicators(candles: chartViewModel.dataManager.candles)
            placementIndicatorSnapshot.reset()
        }
    }

    private func applyPlacementIndicatorsToChart() {
        chartViewModel.indicatorManager.applyMarkerIndicators(placementIndicatorComponents)
        chartViewModel.indicatorManager.recalculateIndicators(candles: chartViewModel.dataManager.candles)
    }

    private func refreshViewingIndicatorsIfNeeded() {
        guard controlViewModel.isMarkerViewingMode,
              let marker = chartViewModel.selectedMarkerForSheet else {
            return
        }

        markerOverlayState.activateViewing(
            marker: marker,
            indicatorManager: chartViewModel.indicatorManager,
            candles: chartViewModel.dataManager.candles
        )
    }

    // MARK: - Marker Detail Tab Bar

    private var markerDetailTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }

            HStack(spacing: 4) {
                // General tab (left, gets more space via Spacer)
                if let marker = chartViewModel.selectedMarkerForSheet {
                    markerDetailGeneralTabButton(
                        marker: marker,
                        isSelected: markerDetailTab == .general
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            markerDetailTab = .general
                        }
                    }
                }

                Spacer()

                // Action buttons (right) — mirrors standardTabBar layout
                HStack(spacing: 6) {
                    ForEach(MarkerViewingTab.allCases, id: \.self) { tab in
                        if tab != .general {
                            RootBottomBarIconButton(
                                systemName: tab == .chat ? "message.fill" : tab.icon,
                                fontSize: 20,
                                backgroundColor: markerDetailTab == tab ?
                                    bottomBarSelectedBackground :
                                    bottomBarUnselectedBackground,
                                foregroundColor: markerDetailTab == tab ?
                                    bottomBarSelectedForeground :
                                    bottomBarUnselectedForeground
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    markerDetailTab = tab
                                }
                            }
                        }
                    }
                    markerLikeCapsuleButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard, edges: markerDetailTab == .chat ? [] : .bottom)
        .background(bottomTabBarContainerBackground)
    }

    private var canEditSelectedMarker: Bool {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return false }
        return isMarkerEditableForCurrentUser(marker)
    }

    private func isMarkerAuthoredByCurrentUser(_ marker: ChartMarkerUI) -> Bool {
        if marker.isCurrentUserMarker {
            return true
        }
        guard let currentUserId = rlAppState.currentUser?.id else { return false }
        return marker.author.userId == currentUserId
    }

    private func shareSelectedMarker() {
        guard let marker = chartViewModel.selectedMarkerForSheet,
              MarkerShare.canShareWithinGuild(visibility: marker.visibility) else {
            return
        }

        HapticFeedback.medium.trigger()
        let context = MarkerShareContext(
            marker: marker.marker,
            symbolTicker: chartViewModel.currentSymbol?.ticker,
            isNewPlacement: false,
            isCurrentUserMarker: isMarkerAuthoredByCurrentUser(marker)
        )
        NotificationCenter.default.post(
            name: .presentMarkerSharePrompt,
            object: nil,
            userInfo: [MarkerSharePromptNotification.contextKey: context]
        )
    }

    private func isMarkerEditableForCurrentUser(_ marker: ChartMarkerUI) -> Bool {
        if marker.canOpenEditFlow {
            return true
        }

        guard let currentUserId = rlAppState.currentUser?.id else {
            return false
        }
        return marker.author.userId == currentUserId
    }

    private var markerLikeCapsuleButton: some View {
        let isLiked = chartViewModel.selectedMarkerForSheet?.isLikedByCurrentUser ?? false
        let likeCount = chartViewModel.selectedMarkerForSheet?.likeCount ?? 0

        return Button(action: toggleSelectedMarkerLike) {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.headline)
                Text("\(likeCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
            }
            .foregroundColor(AppColors.onAccentForeground)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(isLiked ? AppColors.markerHeartBadge : AppColors.bearCandleRed.opacity(0.12))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isLiked ? AppColors.markerHeartTint : AppColors.bearCandleRed.opacity(0.6), lineWidth: isLiked ? 0.9 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var placementPreviewReactionEmoji: String? {
        guard case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload else {
            return nil
        }
        let trimmed = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func placementGeneralTabButton(
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: placementState.intent,
                    alertSeverity: placementState.intent == .alert ? placementState.alertSeverity : nil,
                    size: 40,
                    emoji: placementState.intent == .reaction ? placementPreviewReactionEmoji : nil
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(placementState.intent.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    Text("Marker")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(
                isSelected
                    ? bottomBarSelectedBackground
                    : bottomBarUnselectedBackground
            )
            .clipShape(Capsule())
            .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    private func markerDetailGeneralTabButton(
        marker: ChartMarkerUI,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: marker.intent,
                    alertSeverity: marker.alertSeverity,
                    size: 40,
                    emoji: marker.intent == .reaction ? marker.selectedEmoji : nil,
                    avatar: MarkerAvatarIdentity.forMarker(marker)
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(marker.intent.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    Text(markerAuthorHandle(marker))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(
                isSelected
                    ? bottomBarSelectedBackground
                    : bottomBarUnselectedBackground
            )
            .clipShape(Capsule())
            .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    private func markerAuthorHandle(_ marker: ChartMarkerUI) -> String {
        let username = marker.author.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return "@unknown" }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    private var placementAuthorHandle: String {
        let username = rlAppState.currentUser?.username
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !username.isEmpty else { return "@you" }
        return username.hasPrefix("@") ? username : "@\(username)"
    }
}



struct IndicatorItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        Button { } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 32)
                Text(title)
                    .foregroundColor(AppColors.primaryForeground)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .padding()
            .background(AppColors.symbolSheetGroupedPanelFill)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MarkerTypeItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 32)
            Text(title)
                .foregroundColor(AppColors.primaryForeground)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(AppColors.symbolSheetGroupedPanelFill)
        .cornerRadius(8)
    }
}

struct ChartControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isActive ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.surfaceWhite90)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isActive ?
                color :
                AppColors.panelFillEmphasis
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
