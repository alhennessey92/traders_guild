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

    // MARK: Choose type

    private var typeChooser: some View {
        VStack(alignment: .leading, spacing: 14) {
            responseSection
            MarkerPostToChartCard(author: author) {
                choose(placementState.isSocialDetails ? placementState.intent : .analysis, leavesGuidedFlow: false)
            }
            MarkerGuidedSectionTitle("Structured")
            MarkerGuidedTypeRow(
                intent: .setup,
                subtitle: "Direction, entry, stop and target, tracked for accuracy",
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
        }
    }

    // MARK: Details

    @ViewBuilder
    private var details: some View {
        if placementState.isSocialDetails {
            socialDetails
        } else {
            setupDetails
        }
    }

    private var socialDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            authorHeader(title: "Post to the chart")
            responseSection

            // Side by side, or stacked at accessibility text sizes, where two
            // chips in a row break their words mid-letter.
            let chipLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            chipLayout {
                ForEach([RLMarkerIntent.analysis, .question], id: \.self) { intent in
                    MarkerGuidedIntentChip(intent: intent, isSelected: placementState.intent == intent) {
                        if let change = placementState.requestGuidedIntentChange(to: intent) {
                            pendingChange = PendingChange(change: change, leavesGuidedFlow: false)
                        }
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
            }

            MarkerGuidedTextField(
                placeholder: "Title (optional)",
                text: $placementState.title,
                axis: .horizontal
            )
            MarkerGuidedTextField(
                placeholder: placementState.intent == .question
                    ? "Ask the guild a question"
                    : "What are you seeing?",
                text: $placementState.note,
                axis: .vertical
            )
            contributionHint

            contextRow
            changeTypeButton
        }
    }

    @ViewBuilder
    private var contributionHint: some View {
        if placementState.intent == .question {
            let remaining = max(0, MarkerPlacementRequirements.minimumContextCharacters - placementState.trimmedQuestionNote.count)
            MarkerGuidedHint(
                isMet: remaining == 0,
                text: remaining == 0 ? "Ready to review" : "\(remaining) more character\(remaining == 1 ? "" : "s") needed"
            )
        } else {
            let hasText = !placementState.trimmedQuestionNote.isEmpty
            MarkerGuidedHint(isMet: hasText, text: hasText ? "Ready to review" : "Write something to post")
        }
    }

    private var setupDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            authorHeader(title: "Setup")
            responseSection

            VStack(spacing: 10) {
                HStack {
                    Text("Side")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                    Spacer()
                    MarkerSetupSidePill(side: placementState.setupSide)
                }
                MarkerGuidedValueRow(
                    title: "Entry",
                    value: MarkerGuidedFormat.price(placementState.guidedSetupEntryPrice),
                    detail: "Latest price when you post",
                    tint: RLComponentType.levelEntry.color
                )
                MarkerGuidedLevelField(title: "Take Profit", type: .levelTp, placementState: placementState)
                MarkerGuidedLevelField(title: "Stop Loss", type: .levelSl, placementState: placementState)
                MarkerGuidedValueRow(
                    title: "Risk : Reward",
                    value: MarkerGuidedFormat.riskReward(placementState.guidedSetupRiskReward),
                    detail: nil,
                    tint: AppColors.primaryForeground
                )
                Text("You can also drag the Entry, TP and SL lines on the chart.")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(MarkerGuidedCardBackground())

            Toggle(isOn: $placementState.trackingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracked Setup")
                        .font(.subheadline)
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Auto-monitor entry, SL & TP transitions")
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

            ForEach(["setup_levels_required", "setup_direction_required"], id: \.self) { id in
                if let item = placementState.placementChecklistItems.first(where: { $0.id == id }) {
                    MarkerGuidedHint(isMet: item.isComplete, text: item.title)
                }
            }

            MarkerGuidedTextField(placeholder: "Title (optional)", text: $placementState.title, axis: .horizontal)
            MarkerGuidedTextField(placeholder: "Thesis (optional)", text: $placementState.note, axis: .vertical)

            contextRow
            changeTypeButton
        }
    }

    private func authorHeader(title: String) -> some View {
        HStack(spacing: 12) {
            UnifiedMarkerBadge(
                intent: placementState.intent,
                sizeToken: .large,
                avatar: authorBadgeIdentity
            )
            // The viewer's own face beside the step title: decoration, not
            // something to stop on.
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(MarkerGuidedFormat.destination(guildName))
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer(minLength: 0)
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
            if let timeframe = currentChartTimeframe, let onSelectTimeframe {
                MarkerResponseTimeframeControl(
                    timeframe: timeframe,
                    isLoading: placementState.isChangingResponseTimeframe,
                    onSelect: onSelectTimeframe
                )
            }
        }
    }

    private var contextRow: some View {
        Button {
            placementState.openContext()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(MarkerGuidedFormat.contextSummary(placementState.components) ?? "Indicators, drawings, timeframes — optional")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(MarkerGuidedCardBackground())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("guided.addContext")
    }

    private var changeTypeButton: some View {
        Button {
            placementState.openTypeChooser()
        } label: {
            Label("Change type", systemImage: "arrow.left.arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("guided.changeType")
    }

    // MARK: Context

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add context to your \(placementState.intent.displayName.lowercased())")
                .font(.headline.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
            Text("Optional. Everything here stays with your draft.")
                .font(.caption)
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

    private var review: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    UnifiedMarkerBadge(intent: placementState.intent, sizeToken: .large, avatar: authorBadgeIdentity)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(placementState.intent.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundColor(placementState.intent.color)
                        Text(MarkerGuidedFormat.destination(guildName))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.primaryForeground)
                    }
                    Spacer(minLength: 0)
                }

                if let context = placementState.linkSession.context {
                    MarkerGuidedReviewLine(icon: context.relationship.icon, text: context.bannerSentence)
                }

                let title = placementState.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
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

                MarkerGuidedReviewLine(
                    icon: "plus.viewfinder",
                    text: MarkerGuidedFormat.contextSummary(placementState.components) ?? "No extra context"
                )
                MarkerGuidedReviewLine(
                    icon: "clock",
                    text: currentChartTimeframe.map { "\($0.displayName) chart" } ?? "Current chart timeframe"
                )
            }
            .padding(14)
            .background(MarkerGuidedCardBackground())

            submissionStatus
        }
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
            MarkerGuidedValueRow(title: "Entry", value: MarkerGuidedFormat.price(placementState.guidedSetupEntryPrice),
                                 detail: "Latest price when you post", tint: RLComponentType.levelEntry.color)
            MarkerGuidedValueRow(title: "Take Profit", value: MarkerGuidedFormat.price(placementState.componentPrice(.levelTp)),
                                 detail: nil, tint: RLComponentType.levelTp.color)
            MarkerGuidedValueRow(title: "Stop Loss", value: MarkerGuidedFormat.price(placementState.componentPrice(.levelSl)),
                                 detail: nil, tint: RLComponentType.levelSl.color)
            if placementState.trackingEnabled {
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
                Text("Posting…")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
            }
        case .failed(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.statusNegative)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't post")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("\(message) Your draft is saved.")
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

/// Back / Review / Post for the guided panel, in the sheet's bottom bar.
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
                if placementState.guidedTrackedSetupLevelsNeedAdjusting {
                    Text("Put Entry between your stop and target")
                        .font(.caption)
                        .foregroundColor(AppColors.statusWarning)
                        .lineLimit(2)
                } else if let unmet = placementState.firstUnmetRequirementTitle {
                    Text(unmet)
                        .font(.caption)
                        .foregroundColor(AppColors.statusWarning)
                        .lineLimit(2)
                }
                Spacer()
                primaryButton(
                    "Review",
                    enabled: placementState.isValid && !placementState.guidedTrackedSetupLevelsNeedAdjusting,
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
                primaryButton(
                    placementState.submissionPhase.isFailed ? "Retry" : "Post",
                    enabled: placementState.canPostGuidedDraft,
                    identifier: "guided.post"
                ) {
                    onPost()
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
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer()
        // The draft being posted is frozen until the server answers.
        .disabled(placementState.isGuidedSubmissionInFlight)
        .opacity(placementState.isGuidedSubmissionInFlight ? 0.4 : 1)
        .accessibilityIdentifier("guided.back")
    }

    private func primaryButton(_ title: String, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(placementState.intent.color.opacity(enabled ? 0.95 : 0.35))
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
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Discard this draft?",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive, action: onDiscard)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your text, context and levels will be lost.")
        }
    }
}

// MARK: - Entry hierarchy pieces

/// Which types the entry hierarchy leads to.
enum MarkerGuidedFlowEntry {
    /// Kept on their existing flows behind "Other marker types".
    static let otherIntents: [RLMarkerIntent] = [.alert, .poll, .news, .reaction, .personal]
}

/// The prominent "Post to the chart" card: the viewer's face, starting Analysis.
struct MarkerPostToChartCard: View {
    let author: MarkerAvatarIdentity
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                UnifiedMarkerBadge(intent: .analysis, sizeToken: .large, avatar: author)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Post to the chart")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Share analysis or ask the guild a question")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(RLMarkerIntent.analysis.color.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(RLMarkerIntent.analysis.color.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("guided.postToChart")
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

struct MarkerGuidedIntentChip: View {
    let intent: RLMarkerIntent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(intent.displayName, systemImage: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
                .font(.footnote.weight(.semibold))
                .foregroundColor(isSelected ? .white : AppColors.primaryForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? intent.color.opacity(0.9) : AppColors.whiteText.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("guided.intent.\(intent.rawValue)")
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

struct MarkerGuidedHint: View {
    let isMet: Bool
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(isMet ? AppColors.statusPositive : AppColors.statusWarning)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(isMet ? AppColors.greyText : AppColors.statusWarning)
            Spacer(minLength: 0)
        }
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
