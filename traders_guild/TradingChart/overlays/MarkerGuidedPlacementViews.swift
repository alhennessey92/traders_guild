//
//  MarkerGuidedPlacementViews.swift
//  traders_guild
//
//  The guided creation panel inside the chart bottom sheet (v1.5 avatar
//  prototype). Every field binds to `MarkerPlacementState`; nothing here owns
//  a draft.
//

import SwiftUI

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
    var viewportAnchorProvider: (() -> (time: Date, price: Double)?)?

    @State private var pendingChange: PendingChange?
    @State private var showRelationshipPicker = false
    /// The optional title field, revealed on request — or already, when the
    /// draft has a title.
    @State private var showsTitleField = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A type change waiting on the author, and where it goes once confirmed.
    private struct PendingChange: Identifiable {
        let change: MarkerGuidedIntentChange
        let leavesGuidedFlow: Bool
        var id: UUID { change.id }
    }

    var body: some View {
        Group {
            switch placementState.guidedStep {
            case .chooseType?:
                ScrollView(showsIndicators: false) { typeChooser.padding(.bottom, 24) }
            case .details?:
                ScrollView(showsIndicators: false) { details.padding(.bottom, 24) }
                    .scrollDismissesKeyboard(.interactively)
            case .context?:
                contextEditor
            case .review?:
                ScrollView(showsIndicators: false) { review.padding(.bottom, 24) }
            case nil:
                EmptyView()
            }
        }
        .alert(item: $pendingChange) { pending in
            Alert(
                title: Text("Switch to \(pending.change.targetIntent.displayName)?"),
                message: Text("This removes context \(pending.change.targetIntent.displayName) can't carry: \(pending.change.incompatibleSummary)."),
                primaryButton: .destructive(Text("Remove and Switch")) {
                    placementState.applyGuidedIntentChange(pending.change)
                    if pending.leavesGuidedFlow {
                        placementState.endGuidedFlow()
                    } else {
                        placementState.backToDetails()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showRelationshipPicker) {
            if let context = placementState.linkSession.context {
                MarkerLinkRelationshipPicker(
                    parentSummary: context.bannerSentence,
                    parentIntent: context.parentIntent,
                    onSelect: { relationship in
                        showRelationshipPicker = false
                        placementState.changeLinkRelationship(relationship)
                    },
                    onCancel: { showRelationshipPicker = false }
                )
                .presentationDetents([.height(580), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            showsTitleField = !placementState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: Type changes

    /// Guided types go back to Details; other types leave for the legacy panel.
    /// Either way nothing is removed without the author agreeing.
    private func choose(_ intent: RLMarkerIntent, leavesGuidedFlow: Bool) {
        if let change = placementState.requestGuidedIntentChange(to: intent) {
            pendingChange = PendingChange(change: change, leavesGuidedFlow: leavesGuidedFlow)
            HapticFeedback.light.trigger()
            return
        }
        if leavesGuidedFlow {
            placementState.endGuidedFlow()
        } else {
            placementState.backToDetails()
        }
    }

    // MARK: Header

    /// "Step 1 of 2 · Posting to Alpha Traders", then the step's question.
    private var stepHeader: some View {
        MarkerGuidedStepHeader(
            stepNumber: placementState.guidedStepNumber,
            prompt: placementState.guidedStepPrompt ?? "",
            destination: placementState.isGuidedEdit
                ? "Editing your marker"
                : MarkerGuidedFormat.destination(guildName),
            intent: placementState.intent,
            author: authorBadgeIdentity
        )
    }

    // MARK: Change type

    /// "Change type" returns to the creation hierarchy — Post to the chart,
    /// Plan a trade, other types — keeping the draft and any response.
    /// Setup is reached here, never from the social selector.
    private var typeChooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader
            responseSection
            Text("Your text\(placementState.linkSession.isActive ? " and response" : "") will be kept.")
                .font(.footnote)
                .foregroundColor(AppColors.greyText)
                .fixedSize(horizontal: false, vertical: true)
            MarkerGuidedEntryCard(
                author: author,
                intent: placementState.isSocialDetails ? placementState.intent : .analysis,
                title: "Post to the chart",
                subtitle: "Share analysis or ask the guild a question",
                identifier: "guided.postToChart",
                isCurrent: placementState.isSocialDetails
            ) {
                choose(placementState.isSocialDetails ? placementState.intent : .analysis, leavesGuidedFlow: false)
            }
            MarkerGuidedEntryCard(
                author: author,
                intent: .setup,
                title: "Plan a trade",
                subtitle: "Entry, stop and target. Tracked Setups count toward your accuracy and reputation.",
                identifier: "guided.planTrade",
                isCurrent: placementState.intent == .setup
            ) {
                choose(.setup, leavesGuidedFlow: false)
            }
            DisclosureGroup {
                VStack(spacing: 8) {
                    ForEach(MarkerGuidedFlowEntry.otherIntents, id: \.self) { intent in
                        MarkerGuidedTypeRow(intent: intent, subtitle: intent.subtitle, isCurrent: false) {
                            choose(intent, leavesGuidedFlow: true)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                MarkerGuidedSectionTitle("Other marker types")
            }
            .tint(AppColors.greyText)
            .padding(.top, 4)
        }
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader
            responseSection
            editRelationship
            if placementState.isSocialDetails {
                // An edit keeps its type: no selector.
                if !placementState.isGuidedEdit {
                    socialTypePicker
                }
                socialFields
            } else {
                setupFields
            }
            responseTimeframe
            optionalExtras
        }
    }

    /// Analysis · Question — the social selector — with one line saying
    /// what the chosen type is for. Setup is structured and is not in it.
    private var socialTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkerGuidedTypePicker(
                intents: MarkerGuidedFlowEntry.socialIntents,
                selected: placementState.intent,
                stacks: dynamicTypeSize.isAccessibilitySize
            ) { intent in
                choose(intent, leavesGuidedFlow: false)
            }
            Text(MarkerGuidedFormat.typeDescription(placementState.intent))
                .font(.footnote)
                .foregroundColor(AppColors.greyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var socialFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkerGuidedTextField(
                placeholder: placementState.intent == .question
                    ? "Ask a clear question about this chart"
                    : "Describe what you see and why it matters",
                text: $placementState.note,
                axis: .vertical
            )
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

    private var setupFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            if placementState.isGuidedEditLocked {
                MarkerGuidedLockedSetupCard(placementState: placementState)
            } else {
                MarkerGuidedSetupLevelsCard(placementState: placementState)
                trackingControls
            }

            MarkerGuidedTextField(
                placeholder: "Why this trade? (optional)",
                text: $placementState.note,
                axis: .vertical
            )
            .accessibilityIdentifier("guided.text")
        }
    }

    @ViewBuilder
    private var trackingControls: some View {
        Toggle(isOn: $placementState.trackingEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Track this Setup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Counts toward your accuracy and reputation")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
        }
        .tint(RLComponentType.levelEntry.color)

        if placementState.trackingEnabled {
            MarkerTrackedSetupCard(placementState: placementState)
        } else {
            MarkerUntrackedSetupNotice()
        }
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

    /// Title and chart context: available, never in the way.
    private var optionalExtras: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitleField {
                MarkerGuidedTextField(placeholder: "Title", text: $placementState.title, axis: .horizontal)
                    .accessibilityIdentifier("guided.title")
            }
            MarkerGuidedSectionTitle("Optional")
                .padding(.top, 4)
            if !showsTitleField {
                MarkerGuidedOptionalRow(
                    icon: "textformat",
                    title: "Add a title",
                    detail: nil,
                    identifier: "guided.addTitle",
                    trailingSymbol: "plus"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsTitleField = true }
                }
            }
            // A locked Setup's context cannot change (the server refuses it).
            if !placementState.isGuidedEditLocked {
                MarkerGuidedOptionalRow(
                    icon: "plus.viewfinder",
                    title: placementState.isGuidedEdit ? "Chart context" : "Add chart context",
                    detail: MarkerGuidedFormat.contextSummary(placementState.components)
                        ?? "Indicators, drawings, levels or timeframes",
                    identifier: "guided.addContext"
                ) {
                    placementState.openContext()
                }
            }
            // An edit keeps its type.
            if !placementState.isGuidedEdit {
                Button {
                    placementState.openTypeChooser()
                } label: {
                    Label("Change type", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.accentColor)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("guided.changeType")
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
                onChangeRelationship: { showRelationshipPicker = true },
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
            MarkerResponseTimeframeControl(
                timeframe: timeframe,
                isLoading: placementState.isChangingResponseTimeframe,
                onSelect: onSelectTimeframe
            )
        }
    }

    // MARK: Context

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader
            Text(placementState.isGuidedEdit
                 ? "Optional. Nothing changes until you save."
                 : "Optional. Anything you add stays with your draft.")
                .font(.footnote)
                .foregroundColor(AppColors.greyText)
            UnifiedComponentsHostView(
                adapter: MarkerComponentsAdapter(
                    placementState: placementState,
                    activeChartIndicators: activeChartIndicators,
                    activeChartDrawings: activeChartDrawings,
                    currentChartTimeframe: currentChartTimeframe,
                    onSelectTimeframeAction: onSelectTimeframe,
                    onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                    showsMirrorButtons: true,
                    viewportAnchorProvider: viewportAnchorProvider
                )
            )
        }
    }

    // MARK: Review

    /// The post as the guild will read it, then where it goes.
    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
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
                }

                if let summary = MarkerGuidedFormat.contextSummary(placementState.components) {
                    MarkerGuidedReviewLine(icon: "plus.viewfinder", text: summary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MarkerGuidedCardBackground())

            if placementState.isGuidedEdit {
                editChanges
            }

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
    let onPost: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            switch placementState.guidedStep {
            case .chooseType?:
                backButton("Back")
                Spacer()
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
                primaryButton(
                    "Review",
                    enabled: placementState.canContinueToReview,
                    identifier: "guided.review"
                ) {
                    placementState.continueToReview()
                }
            case .context?:
                Spacer()
                primaryButton("Done", enabled: true, identifier: "guided.contextDone") {
                    placementState.backToDetails()
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
        // The sheet's bottom bar has a fixed height, like a tab bar: its text
        // stops growing at the first accessibility size, and a long press
        // shows the control in the Large Content Viewer instead.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func backButton(_ title: String) -> some View {
        Button {
            placementState.backToDetails()
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
    var cancellingNeedsConfirmation: Bool { isGuidedFlowActive && hasMaterialEdits }
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
    /// The social selector on Details. Setup is structured and reached from
    /// its own entry, or from Change type.
    static let socialIntents: [RLMarkerIntent] = [.analysis, .question]
    /// Kept on their existing flows behind "Other marker types".
    static let otherIntents: [RLMarkerIntent] = [.alert, .poll, .news, .reaction, .personal]
}

/// One of the Add tab's two starting points: the viewer's face with the type
/// badge, what it is, and a chevron. "Post to the chart" starts Analysis;
/// "Plan a trade" starts Setup.
struct MarkerGuidedEntryCard: View {
    let author: MarkerAvatarIdentity
    let intent: RLMarkerIntent
    let title: String
    let subtitle: String
    let identifier: String
    /// In Change type, the draft's current kind: a checkmark, and selected.
    var isCurrent: Bool = false
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // At accessibility sizes the face sits above the words, which
                // then get the card's width.
                let content = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 14))
                content {
                    UnifiedMarkerBadge(intent: intent, sizeToken: .large, avatar: author)
                        .frame(width: 52, height: 52)
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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(intent.color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(intent.color.opacity(0.40), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}

/// "Post to the chart": the viewer's face, starting Analysis.
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

/// "Step 1 of 2 · Posting to Alpha Traders" over the step's question, beside
/// the author's face. Read by VoiceOver as one heading.
struct MarkerGuidedStepHeader: View {
    let stepNumber: Int?
    let prompt: String
    let destination: String
    let intent: RLMarkerIntent
    let author: MarkerAvatarIdentity
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stepLine: String {
        guard let stepNumber else { return destination }
        return "Step \(stepNumber) of 2 · \(destination)"
    }

    var body: some View {
        // At accessibility sizes the face sits above the words, which then
        // get the sheet's full width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            UnifiedMarkerBadge(intent: intent, sizeToken: .large, avatar: author)
            VStack(alignment: .leading, spacing: 3) {
                Text(stepLine)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(prompt)
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prompt). \(stepLine)")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("guided.stepHeader")
    }
}

/// The social selector, Analysis · Question, as one segmented control.
/// Stacks at accessibility text sizes, where segments in a row would break
/// words.
struct MarkerGuidedTypePicker: View {
    let intents: [RLMarkerIntent]
    let selected: RLMarkerIntent
    let stacks: Bool
    let onSelect: (RLMarkerIntent) -> Void

    var body: some View {
        let layout = stacks
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 4))
        layout {
            ForEach(intents, id: \.self) { intent in
                let isSelected = intent == selected
                Button {
                    onSelect(intent)
                } label: {
                    Label(intent.displayName, systemImage: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(isSelected ? .white : AppColors.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? intent.color : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("guided.intent.\(intent.rawValue)")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.whiteText.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.whiteText.opacity(0.09), lineWidth: 1))
        )
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
        VStack(spacing: 10) {
            HStack {
                Text("Levels")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                Spacer()
                MarkerSetupSidePill(side: placementState.setupSide)
            }
            MarkerGuidedValueRow(
                title: "Entry",
                value: MarkerGuidedFormat.displayPrice(placementState.guidedSetupEntryPrice),
                detail: placementState.isGuidedEdit ? "Set when posted" : "Latest price when you post",
                tint: RLComponentType.levelEntry.color
            )
            MarkerGuidedLevelField(title: "Take Profit", type: .levelTp, placementState: placementState)
            MarkerGuidedLevelField(title: "Stop Loss", type: .levelSl, placementState: placementState)
            MarkerGuidedValueRow(
                title: "Risk : Reward",
                value: MarkerGuidedFormat.riskReward(placementState.guidedSetupRiskReward),
                detail: nil,
                tint: AppColors.greyText
            )
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
        TextField(placeholder, text: $text, axis: axis)
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

    var body: some View {
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
            TextField("0.0", value: placementState.levelPriceBinding(for: type), formatter: MarkerGuidedFormat.priceFormatter)
                .textFieldStyle(.plain)
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
