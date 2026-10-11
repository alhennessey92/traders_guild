//
//  MarkerGuidedPlacementViews.swift
//  traders_guild
//
//  The guided creation panel inside the chart bottom sheet (v1.5 avatar
//  prototype). Every field binds to `MarkerPlacementState`; nothing here owns
//  a draft.
//

import SwiftUI

/// The collapsed workspace: one capsule at the app's standard dock height,
/// naming the draft and the screen Resume returns to.
struct MarkerGuidedCompactDock: View {
    @ObservedObject var placementState: MarkerPlacementState
    let onResume: () -> Void

    private var taskTitle: String {
        if placementState.isGuidedEdit { return "Editing \(placementState.intent.displayName)" }
        if placementState.linkSession.isActive { return "Responding with \(placementState.intent.displayName)" }
        return "New \(placementState.intent.displayName)"
    }

    private var progress: String {
        if placementState.guidedStep == .review { return "Review ready" }
        // Reopening returns to this exact screen, so say which it is.
        if placementState.guidedStep == .context { return "\(placementState.workspaceDestination.title) · kept as you left it" }
        if placementState.isGuidedEdit && placementState.hasMaterialEdits { return "Unsaved changes" }
        if let requirement = placementState.guidedNextStepPrompt { return requirement }
        return "Draft kept"
    }

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        Button(action: onResume) {
            HStack(spacing: 10) {
                Image(systemName: MarkerIntentBadge.style(intent: placementState.intent)?.symbol ?? placementState.intent.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MarkerIntentBadge.accentColor(for: placementState.intent))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(MarkerIntentBadge.accentColor(for: placementState.intent).opacity(0.16)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(taskTitle)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    Text(progress)
                        .font(.caption2)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(MarkerIntentBadge.accentColor(for: placementState.intent)))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 7)
            .frame(height: 50)
            .background(Capsule().fill(AppColors.chartSheetMainTabUnselectedBackground))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityShowsLargeContentViewer()
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(taskTitle). \(progress). Continue editing")
        .accessibilityAction { onResume() }
        .accessibilityIdentifier("guided.compactDock")
    }
}

// MARK: - Panel

/// The guided panel, shown in place of the legacy placement tabs while
/// `placementState.guidedStep` is set.
///
/// One step at a time, in reading order: who is posting and where, what the
/// step asks for, the one required input, then optional extras. The bottom
/// bar carries the single primary action and, while it is unavailable, the
/// reason in plain words.
struct MarkerGuidedPlacementPanel: View {
    @ObservedObject var placementState: MarkerPlacementState
    /// The author: the viewer, who is placing it.
    let author: MarkerAvatarIdentity
    /// "@name", as the guild sees it on the post.
    var authorHandle: String? = nil
    let guildName: String?
    let currentChartTimeframe: RLChartTimeframe?
    var activeChartIndicators: [IndicatorPayload] = []
    var activeChartDrawings: [ChartDrawing] = []
    var onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    var onBeginInteractiveDrawing: (() -> Void)?
    var onShowChart: (() -> Void)? = nil
    var viewportAnchorProvider: (() -> (time: Date, price: Double)?)?
    /// Also post a new marker to the guild's Discord (Review), when the
    /// guild has a usable channel.
    var discordGuildId: UUID? = nil
    var loadDiscordChannels: (() async -> Void)? = nil

    @State private var pendingChange: PendingChange?
    /// The optional title field, revealed on request — or already, when the
    /// draft has a title.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The depth of the screen last shown: a deeper one enters from the
    /// trailing side, a shallower one from the leading side.
    @State private var shownDepth = 0

    /// A change waiting on the author: a type change that would remove
    /// context, or a Setup side change that would move their levels. One
    /// alert serves both (an alert declared inside the screen's scroll view
    /// never presents).
    private enum PendingChange: Identifiable {
        case intent(MarkerGuidedIntentChange)
        case side(MarkerSetupSideChange)

        var id: UUID {
            switch self {
            case .intent(let change): return change.id
            case .side(let change): return change.id
            }
        }
    }

    /// One workspace: the header stays put, and only the screen below it
    /// changes. Moving between screens never touches the sheet itself.
    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            taskHeader
            ZStack(alignment: .top) {
                screen(placementState.workspaceDestination)
                    .id(placementState.workspaceDestination)
                    .transition(screenTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.28),
                       value: placementState.workspaceDestination)
        }
        .onChange(of: placementState.workspaceDestination) { _, destination in
            shownDepth = placementState.workspaceDepth
            announce(destination)
        }
        .alert(item: $pendingChange) { pending in
            switch pending {
            case .intent(let change):
                return Alert(
                    title: Text("Switch to \(change.targetIntent.displayName)?"),
                    message: Text("This removes context \(change.targetIntent.displayName) can't carry: \(change.incompatibleSummary)."),
                    primaryButton: .destructive(Text("Remove and Switch")) {
                        placementState.applyGuidedIntentChange(change)
                        placementState.backToDetails()
                    },
                    secondaryButton: .cancel()
                )
            case .side(let change):
                return Alert(
                    title: Text("Switch to \(change.direction.title)?"),
                    message: Text(change.summary),
                    primaryButton: .default(Text("Flip levels")) { placementState.applySetupSideChange(change) },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            placementState.workspace.showsTitle = placementState.workspace.showsTitle || !placementState.title.isEmpty
            shownDepth = placementState.workspaceDepth
        }
    }

    // MARK: Screens

    /// The screen arriving slides a short way in from the side it leads to;
    /// the screen being left fades where it is, so its direction never
    /// matters. Reduce Motion crossfades.
    private var screenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let deeper = placementState.workspaceDepth >= shownDepth
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: deeper ? 28 : -28)),
                           removal: .opacity)
    }

    /// Each screen scrolls on its own and remembers where it was.
    private func screen(_ destination: MarkerWorkspaceDestination) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                switch destination {
                case .details: details
                case .review: review
                default: contextEditor(destination)
                }
            }
            .padding(.bottom, 12)
            .scrollTargetLayout()
        }
        .scrollPosition(id: Binding(
            get: { placementState.workspace.scrollAnchors[destination] },
            set: { placementState.workspace.scrollAnchors[destination] = $0 }
        ))
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("guided.screen")
    }

    /// VoiceOver hears the new screen's name once it has settled.
    private func announce(_ destination: MarkerWorkspaceDestination) {
        let title = stepTitle(destination)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIAccessibility.post(notification: .screenChanged, argument: title)
        }
    }

    // MARK: Type changes

    /// Guided types go back to Details; other types leave for the legacy panel.
    /// Either way nothing is removed without the author agreeing.
    private func choose(_ intent: RLMarkerIntent) {
        if let change = placementState.requestGuidedIntentChange(to: intent) {
            pendingChange = .intent(change)
            HapticFeedback.light.trigger()
            return
        }
        placementState.backToDetails()
    }

    // MARK: Header

    /// The task's face and the screen's name. The header never moves: only
    /// its title changes, cross-fading as the screen below slides, the way a
    /// navigation bar does. Each screen therefore starts with its content.
    private var taskHeader: some View {
        let destination = placementState.workspaceDestination
        return HStack(spacing: 12) {
            UnifiedMarkerBadge(intent: placementState.intent, alertSeverity: draftAlertSeverity,
                               sizeToken: .medium, avatar: authorBadgeIdentity)
                // One element with a name: hiding the badge's parts left
                // its picture and glyph exposed to the audit unlabelled.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Your marker, \(placementState.intent.displayName)")
                // Analysis ↔ Question recolours the face's ring in place.
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: placementState.intent)
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle(destination))
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("guided.stepHeader")
                Text(headerSubtitle(destination))
                    .font(.caption).foregroundColor(AppColors.overlayPanelSecondaryText)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: destination)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityShowsLargeContentViewer()
            Spacer(minLength: 0)
            if let onShowChart {
                Button { dismissKeyboard(); onShowChart() } label: {
                    Image(systemName: "chart.xyaxis.line").frame(width: 44, height: 44)
                        .background(Circle().fill(AppColors.whiteText.opacity(0.06)))
                }.buttonStyle(.plain).disabled(placementState.isGuidedSubmissionInFlight)
                    .accessibilityLabel("Show chart").accessibilityIdentifier("guided.showChart")
            }
        }.foregroundColor(AppColors.primaryForeground)
    }

    private var taskTitle: String { placementState.guidedToolbarTitle ?? "New marker" }

    /// Details is the task itself ("New Analysis"); every other screen is
    /// named, with the task beneath it.
    private func headerTitle(_ destination: MarkerWorkspaceDestination) -> String {
        switch destination {
        case .details: return taskTitle
        case .review: return placementState.isGuidedEdit ? "Review changes" : "Review"
        default: return destination.title
        }
    }

    private func headerSubtitle(_ destination: MarkerWorkspaceDestination) -> String {
        guard destination == .details else { return taskTitle }
        return placementState.isGuidedEdit ? "Editing your marker" : MarkerGuidedFormat.destination(guildName)
    }

    /// What VoiceOver hears on arriving at a screen.
    private func stepTitle(_ destination: MarkerWorkspaceDestination) -> String {
        switch destination {
        case .details: return placementState.intent == .setup ? "Setup details" : "Post details"
        default: return headerTitle(destination)
        }
    }

    // MARK: Details

    /// Analysis/Question compose in one section. Setup keeps separate levels
    /// and optional reasoning sections.
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            responseSection.id("response")
            editRelationship.id("relationship")
            if placementState.isSocialDetails {
                // An edit keeps its type: no selector.
                if !placementState.isGuidedEdit {
                    socialTypePicker.id("type")
                }
                socialFields.id("text")
                responseTimeframe.id("timeframe")
                optionalExtras.id("extras")
            } else {
                setupLevels.id("levels")
                MarkerWorkspaceTextInput(placeholder: "Your reasoning (optional)", text: $placementState.note,
                                         placementState: placementState, fieldID: "reasoning")
                    .id("text").accessibilityIdentifier("guided.text")
                responseTimeframe.id("timeframe")
                optionalExtras.id("extras")
            }
        }
    }

    private var socialTypePicker: some View {
        MarkerGuidedTypePicker(
            intents: MarkerGuidedFlowEntry.socialIntents,
            selected: placementState.intent
        ) { choose($0) }
    }

    private var socialFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkerWorkspaceTextInput(placeholder: socialPlaceholder,
                                     text: $placementState.note, placementState: placementState, fieldID: "socialText")
            .accessibilityIdentifier("guided.text")
            switch placementState.intent {
            case .question:
                minimumCounter(placementState.trimmedQuestionNote.count)
            case .poll:
                pollQuestionCounter
                MarkerGuidedPollChoicesEditor(placementState: placementState)
                    .padding(.top, 4)
            case .alert:
                minimumCounter(placementState.trimmedAlertDescription.count)
                MarkerGuidedAlertSeverityPicker(selected: placementState.alertSeverity) { severity in
                    placementState.alertSeverity = severity
                }
                .padding(.top, 4)
            default:
                EmptyView()
            }
        }
    }

    private var socialPlaceholder: String {
        switch placementState.intent {
        case .question: return "Your question about this chart"
        case .poll: return "Ask the guild something to vote on"
        case .alert: return "What should the guild watch, and why?"
        default: return "What you see and why it matters"
        }
    }

    /// Counts toward the 10 characters a question or an alert needs; gone
    /// once met.
    @ViewBuilder
    private func minimumCounter(_ count: Int) -> some View {
        let remaining = max(0, MarkerPlacementRequirements.minimumContextCharacters - count)
        if remaining > 0 {
            Text("\(remaining) more character\(remaining == 1 ? "" : "s") needed")
                .font(.caption)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .padding(.leading, 4)
        }
    }

    /// A poll's question is its title on the server: say so as the limit
    /// nears, and by how much it is over.
    @ViewBuilder
    private var pollQuestionCounter: some View {
        let limit = MarkerPlacementRequirements.maximumPollQuestionCharacters
        let left = limit - placementState.trimmedPollQuestion.count
        if left < 0 {
            Text("\(-left) character\(left == -1 ? "" : "s") over the limit")
                .font(.caption)
                .foregroundColor(AppColors.statusWarning)
                .padding(.leading, 4)
        } else if left <= 30 {
            Text("\(left) character\(left == 1 ? "" : "s") left")
                .font(.caption)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .padding(.leading, 4)
        }
    }

    private var setupLevels: some View {
        VStack(alignment: .leading, spacing: 12) {
            if placementState.isGuidedEditLocked {
                MarkerGuidedLockedSetupCard(placementState: placementState)
            } else {
                // The chart shows the levels as draggable lines; the workspace
                // steps aside for them.
                MarkerGuidedSetupLevelsCard(placementState: placementState, onAdjustOnChart: onShowChart) { change in
                    pendingChange = .side(change)
                }
                trackingControls
            }
        }
    }

    @ViewBuilder
    private var trackingControls: some View {
        Toggle(isOn: $placementState.trackingEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Track this Setup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                if let reason = placementState.trackingUnavailableReason {
                    // Why not, in place of what tracking would earn.
                    Label(reason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(AppColors.statusWarning)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(MarkerGuidedFormat.trackingSummary(
                        tracked: placementState.trackingEnabled,
                        gain: placementState.estimatedTrackingRepGain,
                        loss: placementState.estimatedTrackingRepLoss
                    ))
                    .font(.caption)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(RLComponentType.levelEntry.color)
        .disabled(placementState.trackingUnavailableReason != nil)
        .accessibilityIdentifier("guided.tracking")
    }

    /// An edited response's relationship, fixed: shown, not changeable.
    @ViewBuilder
    private var editRelationship: some View {
        if placementState.isGuidedEdit, let sentence = placementState.guidedEditOriginal?.linkSentence {
            MarkerGuidedReviewLine(icon: "arrow.triangle.branch", text: sentence)
                .padding(.horizontal, 2)
                .accessibilityIdentifier("guided.editRelationship")
        }
    }

    /// Title and chart context: one compact row, available, never in the way.
    private var optionalExtras: some View {
        // A poll's question is its title on the server, so it has no other.
        let offersTitle = placementState.intent != .poll
        return VStack(alignment: .leading, spacing: 8) {
            if offersTitle && placementState.workspace.showsTitle {
                MarkerWorkspaceLineInput(placeholder: "Title", text: $placementState.title, placementState: placementState, fieldID: "guided.title")
                    .accessibilityIdentifier("guided.title")
            }
            let rowLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            rowLayout {
                if offersTitle && !placementState.workspace.showsTitle {
                    MarkerGuidedExtraChip(icon: "plus", title: "Title", identifier: "guided.addTitle") {
                        withAnimation(.easeInOut(duration: 0.2)) { placementState.workspace.showsTitle = true }
                    }
                }
                // A locked Setup's context cannot change (the server refuses it).
                if !placementState.isGuidedEditLocked {
                    MarkerGuidedExtraChip(
                        icon: "plus.viewfinder",
                        title: MarkerGuidedFormat.contextSummary(placementState.components) ?? "Add context",
                        identifier: "guided.addContext"
                    ) {
                        placementState.openContext()
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
            }
            if placementState.linkSession.isActive && !placementState.isGuidedEdit {
                Button {
                    choose(placementState.intent == .setup ? .analysis : .setup)
                } label: {
                    Text(placementState.intent == .setup ? "Return to post" : "Respond with a Setup")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("guided.convertResponse")
            }
        }
    }

    /// An alert draft's chosen severity, for its badge; nil for every other type.
    private var draftAlertSeverity: MarkerAlertSeverity? {
        placementState.intent == .alert ? placementState.alertSeverity : nil
    }

    /// The viewer's face, with the Setup badge following tracking.
    private var authorBadgeIdentity: MarkerAvatarIdentity {
        var identity = author
        if placementState.intent == .setup {
            identity.setupStatus = placementState.trackingEnabled ? .armed : .untracked
        }
        return identity
    }

    /// What this answers, at the top: the relationship and the parent.
    @ViewBuilder
    private var responseSection: some View {
        if let context = placementState.linkSession.context {
            MarkerWorkspaceResponseBanner(
                context: context,
                author: authorBadgeIdentity,
                intent: placementState.intent,
                failureMessage: placementState.linkSession.lastFailureMessage,
                onChangeRelationship: { placementState.openWorkspace(.relationship) },
                onRemove: { placementState.removeLink() }
            )
            .disabled(placementState.isChangingResponseTimeframe)
        }
    }

    /// Where a response is placed, after what it says: it starts on the
    /// chart's timeframe, so the writing comes first.
    @ViewBuilder
    private var responseTimeframe: some View {
        if placementState.linkSession.context != nil,
           let timeframe = currentChartTimeframe, let onSelectTimeframe {
            MarkerGuidedOptionalRow(icon: "clock", title: "Response timeframe", detail: timeframe.displayName,
                                    identifier: "marker.response.timeframe") {
                placementState.openWorkspace(.responseTimeframe)
            }.disabled(placementState.isChangingResponseTimeframe)

        }
    }

    // MARK: Context

    private func contextEditor(_ destination: MarkerWorkspaceDestination) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The Add context screen says this in its "On this marker" row.
            if ![MarkerWorkspaceDestination.context, .indicators, .drawings, .timeframes].contains(destination) {
                Text(placementState.isGuidedEdit
                     ? "Optional. Nothing changes until you save."
                     : "Optional. Anything you add stays with your draft.")
                    .font(.footnote)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
            }
            MarkerWorkspaceContent(placementState: placementState, currentChartTimeframe: currentChartTimeframe,
                                   activeChartIndicators: activeChartIndicators, activeChartDrawings: activeChartDrawings,
                                   onSelectTimeframe: onSelectTimeframe, onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                                   destination: destination)
        }
    }

    // MARK: Review

    /// The post as the guild will read it, then where it goes.
    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            // An edit leads with what saving changes, so it is in view at
            // the small height; the post as it will read follows.
            if placementState.isGuidedEdit {
                editChanges
            }
            reviewPreview

            Text(placementState.isGuidedEdit
                 ? MarkerGuidedFormat.editAudience(guildName)
                 : MarkerGuidedFormat.audience(guildName))
                .font(.footnote)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // A new post can go to the guild's Discord as well; an edit has
            // already been posted.
            if !placementState.isGuidedEdit {
                MarkerDiscordOptInSection(placementState: placementState, guildId: discordGuildId)
                    .accessibilityIdentifier("guided.discord")
            }

            submissionStatus
        }
        .task { await loadDiscordChannels?() }
    }

    /// Laid out as a member reads the marker when they tap it: the face, who
    /// and what, how it relates, then the title and the words. Framed, so it
    /// reads as the preview it is.
    private var reviewPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                UnifiedMarkerBadge(intent: placementState.intent, alertSeverity: draftAlertSeverity,
                                   sizeToken: .large, avatar: authorBadgeIdentity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(authorHandle ?? "You")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    let metaLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                        : AnyLayout(HStackLayout(spacing: 6))
                    metaLayout {
                        Text(placementState.intent.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundColor(MarkerIntentBadge.accentColor(for: placementState.intent))
                        Text(reviewMetaLine)
                            .font(.caption)
                            .foregroundColor(AppColors.overlayPanelSecondaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }

            if let context = placementState.linkSession.context {
                MarkerGuidedReviewLine(icon: context.relationship.icon, text: context.bannerSentence)
            } else if placementState.isGuidedEdit, let sentence = placementState.guidedEditOriginal?.linkSentence {
                MarkerGuidedReviewLine(icon: "arrow.triangle.branch", text: sentence)
            }

            if placementState.intent == .alert, let severity = placementState.alertSeverity {
                MarkerGuidedAlertSeverityPill(severity: severity)
            }

            // A poll's question is its title on the server; it has no other.
            let title = placementState.intent == .poll
                ? "" : placementState.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = placementState.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty || !text.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !title.isEmpty {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .foregroundColor(AppColors.primaryForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if placementState.intent == .poll {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(placementState.validPollOptions.enumerated()), id: \.offset) { _, choice in
                        MarkerGuidedPollChoiceRow(text: choice)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Choices")
            }

            if placementState.intent == .setup {
                setupReview
            } else if let anchor = placementState.anchorDraft,
                      let time = anchor.payload.anchorTime {
                MarkerGuidedReviewLine(
                    icon: "mappin.and.ellipse",
                    text: "At \(MarkerGuidedFormat.displayPrice(anchor.payload.levelPrice)) · \(time.formatted(date: .abbreviated, time: .shortened))"
                )
            }

            if let summary = MarkerGuidedFormat.contextSummary(placementState.components) {
                MarkerGuidedReviewLine(icon: "plus.viewfinder", text: summary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MarkerGuidedCardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided.reviewPreview")
    }

    /// "5 Minutes chart · now", as a member sees "· 2 hr. ago".
    private var reviewMetaLine: String {
        var parts: [String] = []
        if let timeframe = currentChartTimeframe { parts.append("\(timeframe.displayName) chart") }
        parts.append(placementState.isGuidedEdit ? "edited now" : "now")
        return parts.joined(separator: " · ")
    }

    /// What saving changes, line by line.
    private var editChanges: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkerGuidedSectionTitle("What changes")
            ForEach(placementState.guidedEditChangeLines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(AppColors.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.footnote)
                        .foregroundColor(AppColors.primaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("guided.editChanges")
    }

    private var setupReview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MarkerSetupSidePill(side: placementState.setupSide)
                Spacer()
                Text(MarkerGuidedFormat.riskReward(placementState.guidedSetupRiskReward))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
            }
            MarkerGuidedValueRow(title: "Entry", value: MarkerGuidedFormat.displayPrice(placementState.guidedSetupEntryPrice),
                                 detail: placementState.isGuidedEdit ? "Set when posted" : "Latest price when you post",
                                 tint: RLComponentType.levelEntry.color)
            MarkerGuidedValueRow(title: "Take Profit", value: MarkerGuidedFormat.displayPrice(placementState.componentPrice(.levelTp)),
                                 detail: nil, tint: RLComponentType.levelTp.color)
            MarkerGuidedValueRow(title: "Stop Loss", value: MarkerGuidedFormat.displayPrice(placementState.componentPrice(.levelSl)),
                                 detail: nil, tint: RLComponentType.levelSl.color)
            if placementState.isGuidedEditLocked, let state = placementState.guidedEditOriginal?.trackingState {
                MarkerGuidedReviewLine(icon: "lock.fill", text: "Tracking: \(state.displayName). Levels unchanged.")
            } else if placementState.trackingEnabled {
                MarkerGuidedReviewLine(icon: "scope", text: "Tracked: counts toward accuracy and reputation")
            } else {
                MarkerUntrackedSetupNotice()
            }
        }
    }

    @ViewBuilder
    private var submissionStatus: some View {
        switch placementState.submissionPhase {
        case .idle:
            EmptyView()
        case .submitting:
            HStack(spacing: 8) {
                ProgressView()
                Text(placementState.isGuidedEdit ? "Saving…" : "Posting…")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
            }
        case .failed(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.statusNegative)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(placementState.isGuidedEdit ? "Couldn't save" : "Couldn't post")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(placementState.isGuidedEdit ? "\(message) Your changes are kept." : "\(message) Your draft is saved.")
                        .font(.caption)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                    if placementState.guidedTrackedSetupLevelsNeedAdjusting {
                        Button("Adjust levels") {
                            placementState.backToDetails()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(RLMarkerIntent.setup.color)
                        .padding(.top, 4)
                        .accessibilityIdentifier("guided.adjustLevels")
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(AppColors.statusNegative.opacity(0.12))
            )
            // A container of its own, so its identifier does not overwrite the
            // Adjust levels button's.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("guided.submissionFailed")
        }
    }
}

// MARK: - Response banner

/// What a response answers, drawn as the chart draws it: the parent's face,
/// tethered in the relationship's colour to yours. Your face wears the ring
/// of what you are posting, so turning the response into a Setup shows here
/// as well as on the chart.
struct MarkerWorkspaceResponseBanner: View {
    let context: MarkerLinkContext
    let author: MarkerAvatarIdentity
    let intent: RLMarkerIntent
    let failureMessage: String?
    let onChangeRelationship: () -> Void
    let onRemove: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { context.relationship.accentColor }

    private var detail: String {
        context.parentTimeframe.map { "Parent on \($0.displayName) · Shared with the guild" } ?? "Shared with the guild"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                tether
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.bannerSentence)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(action: onChangeRelationship) {
                    Text("Change")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change relationship")
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .frame(width: 30, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove link")
            }
            if let failureMessage {
                Text("\(failureMessage). Your response is still here — try again.")
                    .font(.caption2)
                    .foregroundColor(AppColors.statusNegative)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.30), lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided.responseBanner")
    }

    /// Parent → relationship → you, as the chart's branch tether.
    private var tether: some View {
        HStack(spacing: 0) {
            UnifiedMarkerBadge(intent: context.parentIntent ?? .analysis, sizeToken: .small,
                               avatar: context.parentAvatar ?? .none)
            ZStack {
                Capsule().fill(accent).frame(width: 24, height: 2)
                Image(systemName: context.relationship.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(accent))
            }
            UnifiedMarkerBadge(intent: intent, sizeToken: .small, avatar: author)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: intent)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Bottom bar

/// The guided panel's one primary action, in the sheet's bottom bar: Review on
/// Details, Post on Review, Done in context. While Review is unavailable the
/// bar says what is missing.
struct MarkerGuidedPlacementBar: View {
    @ObservedObject var placementState: MarkerPlacementState
    var onShowChart: (() -> Void)? = nil
    let onPost: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        HStack(spacing: 10) {
            if let onShowChart {
                Button {
                    dismissKeyboard()
                    onShowChart()
                } label: {
                    Label("Chart", systemImage: "chart.xyaxis.line")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.accentColor)
                .accessibilityLabel("Show chart")
                .accessibilityIdentifier("guided.showChart")
            }
            switch placementState.guidedStep {
            case .details?:
                if let prompt = placementState.guidedNextStepPrompt {
                    // Amber only for levels that are set but wrong; a step
                    // not yet taken is just the next step.
                    let isProblem = placementState.intent == .setup
                        && (placementState.setupSide == .inconsistent || placementState.setupSide == .invalidPrice)
                    Text(prompt)
                        .font(.footnote)
                        .foregroundColor(isProblem ? AppColors.statusWarning : AppColors.overlayPanelSecondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .accessibilityIdentifier("guided.nextStep")
                }
                Spacer(minLength: 8)
                primaryButton("Review", enabled: placementState.canContinueToReview, identifier: "guided.review") {
                    placementState.continueToReview()
                }

            case .context?:
                backButton(placementState.workspaceDestination.isEditor ? "Cancel" : "Back")
                Spacer()
                // An indicator's title follows its period field as it is typed.
                if let draft = placementState.workspace.indicatorDraft,
                   placementState.workspaceDestination == .indicatorSettings {
                    MarkerIndicatorDraftObserver(draft: draft) { contextCommitButton }
                } else {
                    contextCommitButton
                }
            case .review?:
                backButton("Edit")
                Spacer()
                if placementState.isGuidedEdit {
                    primaryButton(
                        placementState.submissionPhase.isFailed ? "Retry" : "Save changes",
                        enabled: placementState.canSaveGuidedEdit,
                        identifier: "guided.save"
                    ) {
                        onPost()
                    }
                } else {
                    primaryButton(
                        placementState.submissionPhase.isFailed ? "Retry" : "Post",
                        enabled: placementState.canPostGuidedDraft,
                        identifier: "guided.post"
                    ) {
                        onPost()
                    }
                }
            case nil:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 68)
        // The footer stays put; only its actions change with the screen.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: placementState.workspaceDestination)
        // The sheet's bottom bar has a fixed height, like a tab bar: its text
        // stops growing at the first accessibility size, and a long press
        // shows the control in the Large Content Viewer instead.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func backButton(_ title: String) -> some View {
        Button {
            placementState.goBack()
        } label: {
            Label(title, systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .padding(.trailing, 8)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer()
        // The draft being posted is frozen until the server answers.
        .disabled(placementState.isGuidedSubmissionInFlight)
        .opacity(placementState.isGuidedSubmissionInFlight ? 0.4 : 1)
        .accessibilityIdentifier("guided.back")
    }

    /// Filled in the type's colour when it can be pressed; a quiet outline
    /// when it cannot, so "not yet" never looks like "go".
    private var contextCommitButton: some View {
        primaryButton(placementState.workspaceCommitTitle, enabled: placementState.workspaceCanCommit,
                      identifier: "guided.contextDone") {
            placementState.commitWorkspaceEditor()
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(.subheadline.weight(.bold))
                .foregroundColor(enabled ? .white : AppColors.greyText)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(enabled ? MarkerIntentBadge.accentColor(for: placementState.intent) : AppColors.whiteText.opacity(0.06))
                        .overlay(Capsule().stroke(AppColors.whiteText.opacity(enabled ? 0 : 0.14), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer()
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}

extension MarkerPlacementSubmissionPhase {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - Cancelling

extension MarkerPlacementState {
    /// Closing now would throw away something the author did in the guided
    /// flow. The legacy flow, and an untouched draft, close without asking.
    var cancellingNeedsConfirmation: Bool { isGuidedFlowActive && (hasMaterialEdits || hasWorkspaceEdits) }
}

/// "Discard this draft?" — Discard or Keep Editing.
struct MarkerGuidedDiscardConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    /// An edit's changes, rather than a new draft.
    var isEditing: Bool = false
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            isEditing ? "Discard your changes?" : "Discard this draft?",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(isEditing ? "Discard Changes" : "Discard Draft", role: .destructive, action: onDiscard)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text(isEditing ? "The marker stays as it was." : "Your text, context and levels will be lost.")
        }
    }
}

// MARK: - Entry hierarchy pieces

/// Which types the entry hierarchy leads to.
enum MarkerGuidedFlowEntry {
    /// Post's Details offers four types on one writing surface, each with
    /// its own small setting: a poll's choices, an alert's severity.
    static let socialIntents: [RLMarkerIntent] = [.analysis, .question, .poll, .alert]
    static let createIntents: [RLMarkerIntent] = [.analysis, .setup]
}

/// Markers ▸ Add. Posting to the chart is what most people come to do, so it
/// leads: a card in the colours of the post it makes, with one large button.
/// Planning a trade sits below as the deliberate second choice, with what it
/// involves. Both fit at the working height on a large phone.
struct MarkerGuidedCreateEntries: View {
    let author: MarkerAvatarIdentity
    let onSelect: (RLMarkerIntent) -> Void

    var body: some View {
        if MarkerSheetDetents.isCompactHeight {
            // A compact-height phone: both must fit at the working height,
            // so posting is one prominent row and Setup the row beneath.
            VStack(spacing: 10) {
                MarkerPostToChartRow(author: author) { onSelect(.analysis) }
                MarkerPlanTradeCard(author: author, compact: true) { onSelect(.setup) }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                MarkerPostToChartCard(author: author) { onSelect(.analysis) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Or plan a trade")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .accessibilityAddTraits(.isHeader)
                    MarkerPlanTradeCard(author: author) { onSelect(.setup) }
                }
            }
        }
    }
}

/// The hero folded into one row for compact-height phones: still the
/// filled, leading action.
struct MarkerPostToChartRow: View {
    let author: MarkerAvatarIdentity
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                UnifiedMarkerBadge(intent: .analysis, sizeToken: .medium, avatar: author)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Post to the chart")
                        .font(.headline.weight(.bold))
                    Text("Analysis, question, poll or alert")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.white)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(RLMarkerIntent.analysis.color))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Starts a post at the middle of the chart")
        .accessibilityIdentifier("guided.postToChart")
    }
}

/// The hero: your face, the two kinds of post, and one clear button.
struct MarkerPostToChartCard: View {
    let author: MarkerAvatarIdentity
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                UnifiedMarkerBadge(intent: .analysis, sizeToken: .medium, avatar: author)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        ForEach(MarkerGuidedFlowEntry.socialIntents, id: \.self) { kind($0) }
                    }
                    .padding(.bottom, 2)
                    Text("Analysis, question, poll or alert")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Share what you see, ask or poll the guild, or flag an area. Your face marks the spot.")
                        .font(.footnote)
                        .foregroundColor(AppColors.primaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            Button(action: action) {
                HStack(spacing: 8) {
                    Text("Post to the chart")
                        .font(.headline.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .accessibilityHidden(true)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(RLMarkerIntent.analysis.color))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityShowsLargeContentViewer()
            .accessibilityHint("Starts a post at the middle of the chart")
            .accessibilityIdentifier("guided.postToChart")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [RLMarkerIntent.analysis.color.opacity(0.22), RLMarkerIntent.question.color.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(RLMarkerIntent.analysis.color.opacity(0.35), lineWidth: 1))
    }

    /// A kind of post, as its small badge.
    private func kind(_ intent: RLMarkerIntent) -> some View {
        Image(systemName: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(MarkerIntentBadge.accentColor(for: intent)))
            .accessibilityHidden(true)
    }
}

/// The deliberate second choice: a Setup, with what it involves and why
/// tracking it is worth it.
struct MarkerPlanTradeCard: View {
    let author: MarkerAvatarIdentity
    /// One line of description, for compact-height phones.
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                UnifiedMarkerBadge(intent: .setup, sizeToken: .medium, avatar: author)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(compact ? "Entry, stop and target · trackable"
                         : "Entry, Take Profit and Stop Loss on the chart. Track it to build your accuracy and reputation.")
                        .font(.caption)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .lineLimit(compact ? 1 : nil)
                        .fixedSize(horizontal: false, vertical: !compact)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(MarkerGuidedCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("guided.planTrade")
    }
}

struct MarkerGuidedSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundColor(AppColors.overlayPanelSecondaryText)
    }
}

struct MarkerGuidedTypeRow: View {
    let intent: RLMarkerIntent
    let subtitle: String
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                UnifiedMarkerBadge(intent: intent, sizeToken: .medium)
                VStack(alignment: .leading, spacing: 2) {
                    Text(intent.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(intent.color)
                        // Spoken as the row's selected trait instead.
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .background(MarkerGuidedCardBackground())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

// MARK: - Small parts

/// The Post types share one writing surface.
struct MarkerGuidedTypePicker: View {
    let intents: [RLMarkerIntent]
    let selected: RLMarkerIntent
    let onSelect: (RLMarkerIntent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Each type wears its marker badge: the glyph and colour its ring has
    /// on the chart. The chosen one fills, as the face's ring recolours.
    /// Four fit side by side as tiles, badge over name; at accessibility
    /// sizes they stack as capsules, so no name breaks.
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(intents, id: \.self) { intent in
                        option(intent) { capsule(intent) }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(intents, id: \.self) { intent in
                        option(intent) { tile(intent) }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Type: \(selected.displayName)")
        .accessibilityIdentifier("guided.intentPicker")
    }

    private func option<Label: View>(_ intent: RLMarkerIntent, @ViewBuilder label: () -> Label) -> some View {
        let isSelected = selected == intent
        return Button { onSelect(intent) } label: { label() }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(intent.displayName)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("guided.intent.\(intent.rawValue)")
    }

    private func badge(_ intent: RLMarkerIntent, isSelected: Bool) -> some View {
        let color = MarkerIntentBadge.accentColor(for: intent)
        return Image(systemName: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(isSelected ? color : color.opacity(0.45)))
            .accessibilityHidden(true)
    }

    private func tile(_ intent: RLMarkerIntent) -> some View {
        let isSelected = selected == intent
        let color = MarkerIntentBadge.accentColor(for: intent)
        return VStack(spacing: 5) {
            badge(intent, isSelected: isSelected)
            Text(intent.displayName)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? color.opacity(0.18) : AppColors.whiteText.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? color.opacity(0.75) : Color.clear, lineWidth: 1.5))
        .padding(.vertical, 2)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private func capsule(_ intent: RLMarkerIntent) -> some View {
        let isSelected = selected == intent
        let color = MarkerIntentBadge.accentColor(for: intent)
        return HStack(spacing: 8) {
            badge(intent, isSelected: isSelected)
            Text(intent.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.leading, 7)
        .padding(.trailing, 16)
        .frame(minHeight: 40)
        .background(Capsule().fill(isSelected ? color.opacity(0.18) : AppColors.whiteText.opacity(0.05)))
        .overlay(Capsule().stroke(isSelected ? color.opacity(0.75) : Color.clear, lineWidth: 1.5))
        .padding(.vertical, 2)
        .contentShape(Capsule())
    }
}

/// An optional extra on Details: an icon, what it adds, and a chevron.
struct MarkerGuidedOptionalRow: View {
    let icon: String
    let title: String
    let detail: String?
    let identifier: String
    /// A chevron for a row that opens a step; a plus for one that adds a
    /// field in place.
    var trailingSymbol: String = "chevron.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accentColor)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(AppColors.overlayPanelSecondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: trailingSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(MarkerGuidedCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// A Setup's levels in one card: direction, Entry, the two editable exits and
/// the ratio, with how to move them.
struct MarkerGuidedSetupLevelsCard: View {
    @ObservedObject var placementState: MarkerPlacementState
    /// Collapses the workspace so the lines can be dragged; nil where the
    /// chart has no lines to drag.
    var onAdjustOnChart: (() -> Void)? = nil
    /// A side change that moves the author's levels, for the panel to confirm.
    var onConfirmSideChange: (MarkerSetupSideChange) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The trade ticket: the side, then each level marked with its line on
    /// the chart, then risk to reward. Colour marks the lines; the words stay
    /// readable on every sheet.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let topRow = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
            topRow {
                MarkerSetupDirectionPicker(selected: placementState.setupDirection) { direction in
                    if let change = placementState.requestSetupDirection(direction) {
                        onConfirmSideChange(change)
                        HapticFeedback.light.trigger()
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                MarkerSetupRiskRewardView(ratio: placementState.guidedSetupRiskReward)
            }
            if let problem = sideProblem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MarkerGuidedValueRow(
                title: "Entry",
                value: MarkerGuidedFormat.displayPrice(placementState.guidedSetupEntryPrice),
                detail: placementState.isGuidedEdit ? "Set when posted" : "Latest price when you post",
                tint: RLComponentType.levelEntry.color
            )
            MarkerGuidedLevelField(title: "Take Profit", type: .levelTp, placementState: placementState)
            MarkerGuidedLevelField(title: "Stop Loss", type: .levelSl, placementState: placementState)
            if let onAdjustOnChart {
                Button {
                    dismissKeyboard()
                    if placementState.beginSetupAdjust() { onAdjustOnChart() }
                } label: {
                    Label("Adjust on chart", systemImage: "arrow.up.and.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                        .overlay(Capsule().stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityHint("Shows the chart, where Take Profit and Stop Loss can be dragged")
                .accessibilityIdentifier("guided.setup.adjust")
            }
        }
        .padding(12)
        .background(MarkerGuidedCardBackground())
    }

    /// Levels that describe no side say so, next to the control that fixes them.
    private var sideProblem: String? {
        switch placementState.setupSide {
        case .inconsistent?: return "Take Profit and Stop Loss are on the same side. Choose Long or Short."
        case .invalidPrice?: return "A level is not a valid price."
        default: return nil
        }
    }
}

/// Long | Short. The chosen side fills in its colour; with levels that
/// describe no side, neither is chosen.
struct MarkerSetupDirectionPicker: View {
    let selected: MarkerSetupDirection?
    let onSelect: (MarkerSetupDirection) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MarkerSetupDirection.allCases) { direction in
                let isSelected = selected == direction
                let color = direction == .long ? AppColors.statusPositive : AppColors.statusNegative
                Button { onSelect(direction) } label: {
                    Label(direction.title, systemImage: direction.icon)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(isSelected ? color.opacity(0.28) : Color.clear))
                        .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("guided.setup.\(direction.rawValue)")
            }
        }
        .padding(3)
        .background(Capsule().fill(AppColors.whiteText.opacity(0.07)))
        .padding(.vertical, 2)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selected)
        // A control, like the footer: it stops growing at the first
        // accessibility size and shows the Large Content Viewer.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityShowsLargeContentViewer()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Side")
    }
}

/// "R:R 1 : 2.40" over a bar split risk | reward, as the chart's red and
/// green fills are.
struct MarkerSetupRiskRewardView: View {
    let ratio: Double?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(MarkerGuidedFormat.riskReward(ratio))
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
            if let ratio, ratio.isFinite, ratio > 0 {
                let risk = 1 / (1 + ratio)
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        Capsule().fill(AppColors.statusNegative).frame(width: max(3, (proxy.size.width - 2) * risk))
                        Capsule().fill(AppColors.statusPositive)
                    }
                }
                .frame(width: 84, height: 4)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Risk to reward, \(MarkerGuidedFormat.riskReward(ratio))")
    }
}

/// A tracked Setup past ARMED, in an edit: its levels and tracking shown,
/// read-only, with why. Nothing here invites a change the server refuses.
struct MarkerGuidedLockedSetupCard: View {
    @ObservedObject var placementState: MarkerPlacementState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Levels locked", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Spacer()
                MarkerSetupSidePill(side: placementState.setupSide)
            }
            MarkerGuidedValueRow(title: "Entry", value: MarkerGuidedFormat.displayPrice(placementState.guidedSetupEntryPrice),
                                 detail: nil, tint: RLComponentType.levelEntry.color)
            MarkerGuidedValueRow(title: "Take Profit", value: MarkerGuidedFormat.displayPrice(placementState.componentPrice(.levelTp)),
                                 detail: nil, tint: RLComponentType.levelTp.color)
            MarkerGuidedValueRow(title: "Stop Loss", value: MarkerGuidedFormat.displayPrice(placementState.componentPrice(.levelSl)),
                                 detail: nil, tint: RLComponentType.levelSl.color)
            if let explanation = placementState.guidedEditLockExplanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(MarkerGuidedCardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided.lockedSetup")
    }
}

/// A compact optional extra: "+ Title", "Chart context".
struct MarkerGuidedExtraChip: View {
    let icon: String
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    Capsule()
                        .fill(AppColors.whiteText.opacity(0.06))
                        .overlay(Capsule().stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

/// The type, in its colour, at the top of the review.
struct MarkerGuidedTextField: View {
    let placeholder: String
    @Binding var text: String
    let axis: Axis

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(AppColors.greyText), axis: axis)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundColor(AppColors.primaryForeground)
            .lineLimit(axis == .vertical ? 3...8 : 1...1)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.standardSearchFieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.standardSearchFieldStroke, lineWidth: 1)
                    )
            )
    }
}

struct MarkerGuidedValueRow: View {
    let title: String
    let value: String
    let detail: String?
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            VStack(alignment: .leading, spacing: 1) {
                MarkerSetupLineLabel(title: title, color: tint)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                        .padding(.leading, 22)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            Text(value)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
        }
        // "Entry, Latest price when you post, 63,920" — one stop, not three.
        .accessibilityElement(children: .combine)
    }
}

/// A level price field on the shared binding the General tab uses.
struct MarkerGuidedLevelField: View {
    let title: String
    let type: RLComponentType
    @ObservedObject var placementState: MarkerPlacementState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout())
        layout {
            MarkerSetupLineLabel(title: title, color: type.color, dashed: true)
                .accessibilityHidden(true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            MarkerWorkspaceLineInput(placeholder: "0.0", text: Binding(
                get: { placementState.workspace.levelInputs[type] ?? String(placementState.guidedLevelPriceBinding(for: type).wrappedValue) },
                set: { input in
                    placementState.workspace.levelInputs[type] = input
                    if let price = Double(input), price.isFinite, price > 0 {
                        placementState.guidedLevelPriceBinding(for: type).wrappedValue = price
                    }
                }
            ), placementState: placementState, fieldID: "guided.level.\(type.rawValue)", keyboard: .decimalPad, label: title, trailing: true)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.whiteText.opacity(0.07)))
                .frame(
                    minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 140,
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 140
                )
                // The field speaks its own name; the title beside it is
                // hidden so VoiceOver does not stop on both.
                .accessibilityLabel(title)
        }
    }
}

struct MarkerSetupSidePill: View {
    let side: MarkerSetupSide?

    var body: some View {
        let (text, color): (String, Color) = {
            switch side {
            case .long?: return ("LONG", AppColors.statusPositive)
            case .short?: return ("SHORT", AppColors.statusNegative)
            case .inconsistent?: return ("TP / SL same side", AppColors.statusWarning)
            case .invalidPrice?: return ("Check your prices", AppColors.statusWarning)
            case nil: return ("Set TP and SL", AppColors.overlayPanelSecondaryText)
            }
        }()
        let filled = side == .long || side == .short
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundColor(filled ? AppColors.primaryForeground : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(filled ? 0.28 : 0.15)))
            .overlay(Capsule().stroke(filled ? color : Color.clear, lineWidth: 1.2))
    }
}

/// A level's name beside a short stroke of its line on the chart: Entry is
/// solid, Take Profit and Stop Loss dashed, each in its own colour.
struct MarkerSetupLineLabel: View {
    let title: String
    let color: Color
    var dashed = false

    var body: some View {
        HStack(spacing: 8) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1.5))
                path.addLine(to: CGPoint(x: 14, y: 1.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: dashed ? [4, 3] : []))
            .frame(width: 14, height: 3)
            .accessibilityHidden(true)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
        }
    }
}

/// Says plainly that an untracked Setup carries nothing at stake.
struct MarkerUntrackedSetupNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: RLTrackingState.draft.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .accessibilityHidden(true)
            Text("Untracked: this Setup won't be monitored and doesn't count toward accuracy or reputation.")
                .font(.caption)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.whiteText.opacity(0.06)))
        .accessibilityIdentifier("guided.untrackedSetup")
    }
}

struct MarkerGuidedReviewLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .frame(width: 16)
                // Decorative: the text says it. Without this VoiceOver reads
                // symbol names such as "plus.viewfinder".
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MarkerGuidedCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.whiteText.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1))
    }
}

// MARK: - Formatting

enum MarkerGuidedFormat {
    static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }()

    static func price(_ value: Double?) -> String {
        guard let value else { return "—" }
        return priceFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func riskReward(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "R:R —" }
        return String(format: "R:R 1 : %.2f", value)
    }

    /// Prices as the chart labels them: two decimals from 1,000 up, up to
    /// four below that, and six significant digits under 1. Display only; the
    /// level fields keep every digit they were given.
    static func displayPrice(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let magnitude = abs(value)
        if magnitude >= 1000 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        } else if magnitude >= 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 4
        } else {
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = 6
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// A price dragged on the chart, kept to the digits the chart labels it
    /// with (`displayPrice`), so the typed field shows 63,780.25 and not
    /// 63780.2493184.
    static func roundedPrice(_ value: Double) -> Double {
        guard value.isFinite, value != 0 else { return value }
        let magnitude = abs(value)
        let digits: Int
        if magnitude >= 1000 { digits = 2 }
        else if magnitude >= 1 { digits = 4 }
        else { digits = max(0, 6 - Int(floor(log10(magnitude))) - 1) }
        let scale = pow(10, Double(digits))
        return (value * scale).rounded() / scale
    }

    /// One line under the type picker saying what the type is for.
    static func typeDescription(_ intent: RLMarkerIntent) -> String {
        switch intent {
        case .analysis: return "Share what you see on the chart."
        case .question: return "Ask the guild for their view."
        case .setup: return "A trade idea with entry, stop and target."
        default: return intent.subtitle
        }
    }

    /// Who will see the post, under the review.
    static func audience(_ guildName: String?) -> String {
        guard let guildName, !guildName.isEmpty else { return "Your guild will see this on the chart." }
        return "Members of \(guildName) will see this on the chart."
    }

    /// The tracking switch's second line: what tracking means, with the
    /// reputation estimate when it is on.
    static func trackingSummary(tracked: Bool, gain: Int?, loss: Int?) -> String {
        guard tracked else { return "Off: not monitored, no effect on accuracy or reputation" }
        guard let gain, let loss else { return "Counts toward your accuracy and reputation" }
        return "Counts toward accuracy · reputation +\(gain) if TP, −\(loss) if SL"
    }

    /// Who will see an edit, under its review.
    static func editAudience(_ guildName: String?) -> String {
        guard let guildName, !guildName.isEmpty else { return "Saving updates your marker for your guild." }
        return "Saving updates your marker for members of \(guildName)."
    }

    static func destination(_ guildName: String?) -> String {
        guard let guildName, !guildName.isEmpty else { return "Posting to your guild" }
        return "Posting to \(guildName)"
    }

    /// "2 indicators · 1 drawing · 1 timeframe", or nil when there is no
    /// context. The anchor and a Setup's own levels are not context.
    static func contextSummary(_ components: [MarkerComponentDraft]) -> String? {
        var counts: [(String, String, Int)] = [
            ("indicator", "indicators", 0), ("drawing", "drawings", 0), ("level", "levels", 0),
            ("timeframe", "timeframes", 0), ("link", "links", 0), ("note", "notes", 0),
        ]
        func bump(_ index: Int) { counts[index].2 += 1 }
        for component in components {
            switch component.componentType {
            case .indicator: bump(0)
            case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .reactionEmoji: bump(1)
            case .levelSupport, .levelResistance: bump(2)
            case .timeframeLink: bump(3)
            case .linkURL: bump(4)
            case .textNote: bump(5)
            case .anchor, .levelEntry, .levelTp, .levelSl: break
            }
        }
        let parts = counts.filter { $0.2 > 0 }.map { "\($0.2) \($0.2 == 1 ? $0.0 : $0.1)" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Re-renders its content when an indicator draft's values change, so a
/// footer title built from them ("Add EMA 10") follows the field.
private struct MarkerIndicatorDraftObserver<Content: View>: View {
    @ObservedObject var draft: IndicatorSettingsDraft
    @ViewBuilder let content: () -> Content
    var body: some View { content() }
}

