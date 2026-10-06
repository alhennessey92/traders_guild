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
                    .foregroundColor(placementState.intent.color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(placementState.intent.color.opacity(0.16)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(taskTitle)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    Text(progress)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(placementState.intent.color))
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
    let guildName: String?
    let currentChartTimeframe: RLChartTimeframe?
    var activeChartIndicators: [IndicatorPayload] = []
    var activeChartDrawings: [ChartDrawing] = []
    var onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    var onBeginInteractiveDrawing: (() -> Void)?
    var onShowChart: (() -> Void)? = nil
    var viewportAnchorProvider: (() -> (time: Date, price: Double)?)?

    @State private var pendingChange: PendingChange?
    /// The optional title field, revealed on request — or already, when the
    /// draft has a title.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The depth of the screen last shown: a deeper one enters from the
    /// trailing side, a shallower one from the leading side.
    @State private var shownDepth = 0

    /// A type change waiting on the author, and where it goes once confirmed.
    private struct PendingChange: Identifiable {
        let change: MarkerGuidedIntentChange
        var id: UUID { change.id }
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
            Alert(
                title: Text("Switch to \(pending.change.targetIntent.displayName)?"),
                message: Text("This removes context \(pending.change.targetIntent.displayName) can't carry: \(pending.change.incompatibleSummary)."),
                primaryButton: .destructive(Text("Remove and Switch")) {
                    placementState.applyGuidedIntentChange(pending.change)
                    placementState.backToDetails()
                },
                secondaryButton: .cancel()
            )
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
            pendingChange = PendingChange(change: change)
            HapticFeedback.light.trigger()
            return
        }
        placementState.backToDetails()
    }

    // MARK: Header

    private var taskHeader: some View {
        HStack(spacing: 10) {
            UnifiedMarkerBadge(intent: placementState.intent, sizeToken: .medium, avatar: authorBadgeIdentity)
                .accessibilityHidden(true)
                // Analysis ↔ Question recolours the face's ring in place.
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: placementState.intent)
            VStack(alignment: .leading, spacing: 2) {
                Text(placementState.guidedToolbarTitle ?? "New marker").font(.subheadline.weight(.bold))
                Text(placementState.isGuidedEdit ? "Editing your marker" : MarkerGuidedFormat.destination(guildName))
                    .font(.caption).foregroundColor(AppColors.greyText)
            }
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

    private func stepTitle(_ destination: MarkerWorkspaceDestination) -> String {
        switch destination {
        case .details: return placementState.intent == .setup ? "Setup details" : "Post details"
        case .review: return "Review"
        default: return destination.title
        }
    }

    private func stepHeader(_ destination: MarkerWorkspaceDestination) -> some View {
        Text(stepTitle(destination))
            .font(.title3.weight(.bold)).foregroundColor(AppColors.primaryForeground)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("guided.stepHeader")
    }

    // MARK: Details

    /// Analysis/Question compose in one section. Setup keeps separate levels
    /// and optional reasoning sections.
    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepHeader(.details).id("heading")
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
            MarkerWorkspaceTextInput(placeholder: placementState.intent == .question
                                     ? "Your question about this chart" : "What you see and why it matters",
                                     text: $placementState.note, placementState: placementState, fieldID: "socialText")
            .accessibilityIdentifier("guided.text")
            if placementState.intent == .question {
                questionCounter
            }
        }
    }

    /// Counts toward the 10 characters a question needs; gone once met.
    @ViewBuilder
    private var questionCounter: some View {
        let remaining = max(0, MarkerPlacementRequirements.minimumContextCharacters - placementState.trimmedQuestionNote.count)
        if remaining > 0 {
            Text("\(remaining) more character\(remaining == 1 ? "" : "s") needed")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .padding(.leading, 4)
        }
    }

    private var setupLevels: some View {
        VStack(alignment: .leading, spacing: 12) {
            if placementState.isGuidedEditLocked {
                MarkerGuidedLockedSetupCard(placementState: placementState)
            } else {
                MarkerGuidedSetupLevelsCard(placementState: placementState)
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
                Text(MarkerGuidedFormat.trackingSummary(
                    tracked: placementState.trackingEnabled,
                    gain: placementState.estimatedTrackingRepGain,
                    loss: placementState.estimatedTrackingRepLoss
                ))
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(RLComponentType.levelEntry.color)
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
        VStack(alignment: .leading, spacing: 8) {
            if placementState.workspace.showsTitle {
                MarkerWorkspaceLineInput(placeholder: "Title", text: $placementState.title, placementState: placementState, fieldID: "guided.title")
                    .accessibilityIdentifier("guided.title")
            }
            let rowLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            rowLayout {
                if !placementState.workspace.showsTitle {
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
                Button(placementState.intent == .setup ? "Return to post" : "Respond with a Setup") {
                    choose(placementState.intent == .setup ? .analysis : .setup)
                }
                .frame(minHeight: 44).accessibilityIdentifier("guided.convertResponse")
            }
        }
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
            MarkerLinkPlacementBanner(
                context: context,
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
            stepHeader(destination)
            Text(placementState.isGuidedEdit
                 ? "Optional. Nothing changes until you save."
                 : "Optional. Anything you add stays with your draft.")
                .font(.footnote)
                .foregroundColor(AppColors.greyText)
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
            stepHeader(.review)
            // An edit leads with what saving changes, so it is in view at
            // half height; the post as it will read follows.
            if placementState.isGuidedEdit {
                editChanges
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    UnifiedMarkerBadge(intent: placementState.intent, sizeToken: .medium, avatar: authorBadgeIdentity)
                        .accessibilityHidden(true)
                    MarkerGuidedIntentTag(intent: placementState.intent)
                    if let timeframe = currentChartTimeframe {
                        Text("\(timeframe.displayName) chart")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.greyText)
                            .accessibilityLabel("\(timeframe.displayName) chart")
                    }
                    Spacer(minLength: 0)
                }

                if let context = placementState.linkSession.context {
                    MarkerGuidedReviewLine(icon: context.relationship.icon, text: context.bannerSentence)
                } else if placementState.isGuidedEdit, let sentence = placementState.guidedEditOriginal?.linkSentence {
                    MarkerGuidedReviewLine(icon: "arrow.triangle.branch", text: sentence)
                }

                let title = placementState.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let text = placementState.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(AppColors.primaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
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

            Text(placementState.isGuidedEdit
                 ? MarkerGuidedFormat.editAudience(guildName)
                 : MarkerGuidedFormat.audience(guildName))
                .font(.footnote)
                .foregroundColor(AppColors.greyText)
                .fixedSize(horizontal: false, vertical: true)

            submissionStatus
        }
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
                    .foregroundColor(AppColors.greyText)
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
                    .foregroundColor(AppColors.greyText)
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
                        .foregroundColor(AppColors.greyText)
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
                        .foregroundColor(isProblem ? AppColors.statusWarning : AppColors.greyText)
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
                primaryButton("Done", enabled: placementState.workspaceCanCommit, identifier: "guided.contextDone") {
                    placementState.commitWorkspaceEditor()
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
                .padding(.vertical, 10)
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
    private func primaryButton(_ title: String, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(enabled ? .white : AppColors.greyText)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(enabled ? placementState.intent.color : AppColors.whiteText.opacity(0.06))
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
    /// Social Details offers Analysis and Question.
    static let socialIntents: [RLMarkerIntent] = [.analysis, .question]
    static let createIntents: [RLMarkerIntent] = [.analysis, .setup]
}

/// Two starting points with a type, purpose and chevron: "Post to the chart"
/// starts Analysis, "Setup" starts a structured trade.
struct MarkerGuidedEntryCard: View {
    let author: MarkerAvatarIdentity
    let intent: RLMarkerIntent
    let title: String
    let subtitle: String
    let identifier: String
    /// Optional selected styling for reusable cards.
    var isCurrent: Bool = false
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // At accessibility sizes the icon sits above the words, which
                // then get the card's width.
                let content = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 14))
                content {
                    UnifiedMarkerBadge(intent: intent, sizeToken: .medium, avatar: author)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isCurrent ? "checkmark" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isCurrent ? intent.color : AppColors.greyText)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(MarkerGuidedCardBackground())
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// "Post to the chart" starts Analysis.
struct MarkerGuidedCreateEntries: View {
    let author: MarkerAvatarIdentity
    let onSelect: (RLMarkerIntent) -> Void
    var body: some View {
        VStack(spacing: 10) {
            MarkerPostToChartCard(author: author) { onSelect(.analysis) }
            MarkerGuidedEntryCard(author: author, intent: .setup, title: "Setup",
                                 subtitle: "Entry, stop and target · optional tracking", identifier: "guided.planTrade") {
                onSelect(.setup)
            }
        }
    }
}

struct MarkerPostToChartCard: View {
    let author: MarkerAvatarIdentity
    let action: () -> Void

    var body: some View {
        MarkerGuidedEntryCard(
            author: author,
            intent: .analysis,
            title: "Post to the chart",
            subtitle: "Share analysis or ask the guild a question",
            identifier: "guided.postToChart",
            action: action
        )
    }
}

struct MarkerGuidedSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundColor(AppColors.greyText)
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
                        .foregroundColor(AppColors.greyText)
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

/// The two social choices share one writing surface.
struct MarkerGuidedTypePicker: View {
    let intents: [RLMarkerIntent]
    let selected: RLMarkerIntent
    let onSelect: (RLMarkerIntent) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(intents, id: \.self) { intent in
                Button { onSelect(intent) } label: {
                    Text(intent.displayName).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(selected == intent ? intent.color.opacity(0.2) : AppColors.whiteText.opacity(0.06)))
                }
                .buttonStyle(.plain).foregroundColor(AppColors.primaryForeground)
                .accessibilityAddTraits(selected == intent ? .isSelected : [])
                .accessibilityIdentifier("guided.intent.\(intent.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Type: \(selected.displayName)")
        .accessibilityIdentifier("guided.intentPicker")
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
                            .foregroundColor(AppColors.greyText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: trailingSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
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

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                MarkerSetupSidePill(side: placementState.setupSide)
                Spacer()
                Text(MarkerGuidedFormat.riskReward(placementState.guidedSetupRiskReward))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .accessibilityLabel("Risk to reward, \(MarkerGuidedFormat.riskReward(placementState.guidedSetupRiskReward))")
            }
            MarkerGuidedValueRow(
                title: "Entry",
                value: MarkerGuidedFormat.displayPrice(placementState.guidedSetupEntryPrice),
                detail: placementState.isGuidedEdit ? "Set when posted" : "Latest price when you post",
                tint: RLComponentType.levelEntry.color
            )
            MarkerGuidedLevelField(title: "Take Profit", type: .levelTp, placementState: placementState)
            MarkerGuidedLevelField(title: "Stop Loss", type: .levelSl, placementState: placementState)
            Text(placementState.isGuidedEdit ? "Type a new take profit or stop loss." : "Drag the lines on the chart, or type a price.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(MarkerGuidedCardBackground())
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
                    .foregroundColor(AppColors.greyText)
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
struct MarkerGuidedIntentTag: View {
    let intent: RLMarkerIntent

    var body: some View {
        Label(intent.displayName, systemImage: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
            .font(.caption.weight(.bold))
            .foregroundColor(intent.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(intent.color.opacity(0.15)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(intent.displayName)
    }
}

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
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tint)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
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
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(type.color)
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
            case nil: return ("Set TP and SL", AppColors.greyText)
            }
        }()
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// Says plainly that an untracked Setup carries nothing at stake.
struct MarkerUntrackedSetupNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: RLTrackingState.draft.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.greyText)
                .accessibilityHidden(true)
            Text("Untracked: this Setup won't be monitored and doesn't count toward accuracy or reputation.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)
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
                .foregroundColor(AppColors.greyText)
                .frame(width: 16)
                // Decorative: the text says it. Without this VoiceOver reads
                // symbol names such as "plus.viewfinder".
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
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
