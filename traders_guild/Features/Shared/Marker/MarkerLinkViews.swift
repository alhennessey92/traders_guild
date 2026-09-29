//
//  MarkerLinkViews.swift
//  traders_guild
//
//  The linked-marker UI: the relationship picker, the "this answers that" row,
//  the thesis disclosure and its thread list, and the placement banner.
//
//  Every one of these is reachable and readable without touching the chart
//  canvas, which is the accessible path to the feature — Canvas-drawn glyphs
//  carry no accessibility elements.
//

import SwiftUI

// MARK: - Capability + scope observer

/// Keeps the chart's link capability and the thesis cache's scope in step with
/// app state.
///
/// Bundled into one modifier because both of the chart shell's modifier chains
/// are already at the type-checker's practical limit; adding bare `.onChange`
/// calls there fails to compile.
struct MarkerLinkCapabilityObserver: ViewModifier {
    @ObservedObject var appState: RLAppState
    @ObservedObject var chartViewModel: ChartViewModel

    func body(content: Content) -> some View {
        content
            .onAppear {
                apply(enabled: appState.runtimeFlags.linkedMarkersEnabled)
                applyScope()
            }
            .onChange(of: appState.runtimeFlags.linkedMarkersEnabled) { _, enabled in
                apply(enabled: enabled)
            }
            .onChange(of: appState.currentGuild?.id) { _, _ in
                applyScope()
            }
            // Membership, not just guild identity. A role can change inside one
            // guild — promoted, demoted, or the membership arriving after the
            // guild switch — and observing only the guild id leaves the previous
            // guild's moderation offering Delete on markers this viewer cannot
            // remove. The membership id moves whenever the (guild, member) pair
            // does, so it catches the switch as well.
            .onChange(of: appState.currentMembership?.id) { _, _ in
                applyModeration()
            }
            .onChange(of: appState.canModerate) { _, _ in
                applyModeration()
            }
    }

    /// Push the viewer's current moderation standing at the manager.
    ///
    /// Cheap and idempotent, so it is safe to call from every path that could
    /// have changed it.
    private func applyModeration() {
        chartViewModel.markerManager?.viewerCanModerate = appState.canModerate
    }

    private func apply(enabled: Bool) {
        let manager = chartViewModel.markerManager
        let wasEnabled = manager?.linkedMarkersEnabled ?? false
        manager?.linkedMarkersEnabled = enabled
        manager?.viewerCanModerate = appState.canModerate
        // Held weakly by the manager: the store belongs to the session, not to
        // the chart, which is the whole reason a thesis survives a timeframe
        // change.
        manager?.threadStore = appState.markerThreadStore

        // Anything cached across a capability flip predates the server's
        // current answer — a thesis read while the feature was off, or one that
        // is now off-limits — so it is dropped rather than shown again.
        if wasEnabled != enabled {
            appState.markerThreadStore.invalidateAll(reason: .capabilityChanged)
        }
    }

    /// Re-scoping clears the cache, so one guild's thesis can never be read in
    /// another, and a signed-out account leaves nothing behind.
    private func applyScope() {
        // Moderation is per guild, so switching guilds can gain or lose it.
        applyModeration()
        appState.markerThreadStore.activate(
            accountId: appState.currentUser?.id,
            guildId: appState.currentGuild?.id
        )
    }
}

// MARK: - Relationship picker

/// Support / Challenge / Build on, with one line of explanation each.
struct MarkerLinkRelationshipPicker: View {
    let parentSummary: String?
    let parentIntent: RLMarkerIntent?
    let onSelect: (MarkerLinkRelationship) -> Void
    let onCancel: () -> Void

    private var parentAccent: Color { parentIntent?.color ?? AppColors.accentColor }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RESPOND TO MARKER")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(AppColors.accentColor)
                        Text("Add to the thesis")
                            .font(.title3.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)
                    }
                    Spacer(minLength: 12)
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.primaryForeground)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppColors.whiteText.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close response choices")
                }

                HStack(spacing: 11) {
                    Image(systemName: "arrow.turn.up.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(parentAccent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(parentAccent.opacity(0.16)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IN REPLY TO\(parentIntent.map { " · \($0.displayName.uppercased())" } ?? "")")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.7)
                            .foregroundColor(parentAccent)
                        Text(parentSummary ?? "Selected marker")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.primaryForeground)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.chartPanelBackgroundInset)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(parentAccent.opacity(0.30), lineWidth: 1)
                        )
                )

                Text("How does your marker relate?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)

                ForEach(MarkerLinkRelationship.allCases, id: \.self) { relationship in
                    Button {
                        onSelect(relationship)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: relationship.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(relationship.accentColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(relationship.accentColor.opacity(0.18))
                                )
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(relationship.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(AppColors.primaryForeground)
                                Text(relationship.pickerSubtitle)
                                    .font(.caption)
                                    .foregroundColor(AppColors.greyText)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(relationship.accentColor)
                                .accessibilityHidden(true)
                        }
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.chartPanelBackgroundInset)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(relationship.accentColor.opacity(0.36), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("marker.respond.\(relationship.rawValue)")
                    .accessibilityLabel("\(relationship.displayName). \(relationship.pickerSubtitle)")
                }

                Text("Starts as Analysis. You can change the marker type during placement.")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(AppColors.sheetBackground)
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - "This answers that" row

/// The relationship line shown directly under a marker's hero panel.
struct MarkerLinkRelationshipRow: View {
    let relationship: MarkerLinkRelationshipValue?
    let preview: RLMarkerLinkPreviewDTO?
    /// The parent id is gone while the relationship survives — what
    /// `ON DELETE SET NULL` leaves behind when an ancestor is hard-deleted.
    /// There is nothing left to hydrate, so an absent preview here means gone
    /// rather than merely unfetched.
    var isDetached: Bool = false
    /// Nil disables tapping — a tombstone, or a preview that cannot navigate.
    let onOpenParent: (() -> Void)?

    private var isUnavailable: Bool {
        preview?.isUnavailable ?? isDetached
    }

    private var accent: Color {
        relationship?.accentColor ?? AppColors.greyText
    }

    /// "Supports Alex's BTC breakout", or a truthful fallback when the parent
    /// is gone. Never invents a name for a marker it cannot see.
    private var sentence: String {
        let name = relationship?.displayName ?? "Linked to"
        guard !isUnavailable else { return "\(name) an unavailable marker" }
        guard let subject = preview?.possessiveSummary else { return "\(name) another marker" }
        return "\(name) \(subject)"
    }

    private var canOpen: Bool {
        onOpenParent != nil && (preview?.canNavigate ?? false)
    }

    var body: some View {
        Button {
            onOpenParent?()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3, height: 30)

                Image(systemName: relationship?.icon ?? "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sentence)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if isUnavailable {
                        Text("The marker this answers isn't available to you")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    } else if canOpen, let rawTimeframe = preview?.timeframe,
                              let timeframe = RLChartTimeframe.fromBackendString(rawTimeframe) {
                        Text("Open parent on \(timeframe.displayName)")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    } else if preview == nil {
                        Text("Loading…")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    }
                }

                Spacer(minLength: 0)

                if canOpen {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.greyText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accent.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sentence)
        .accessibilityHint(canOpen ? "Opens the marker this responds to" : "")
    }
}

// MARK: - Thread row

/// One node in the thesis list.
struct MarkerThreadRowView: View {
    let row: MarkerThreadRow
    let onOpen: (() -> Void)?

    /// At accessibility sizes the trailing chip and count cannot share a line
    /// with the title without squeezing it to a few characters, so the row
    /// reflows into a column instead.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var relationship: MarkerLinkRelationshipValue? {
        row.node.relationship
    }

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    private var indent: CGFloat {
        // Capped at two levels: deeper nesting would eat the row's width on a
        // small screen without telling the reader anything more.
        CGFloat(min(row.depth, 2)) * 14
    }

    private var canOpen: Bool {
        onOpen != nil && row.node.canNavigate && !row.isRequested
    }

    var body: some View {
        HStack(spacing: 10) {
            if indent > 0 {
                Rectangle()
                    .fill(AppColors.surfaceGray40)
                    .frame(width: 1)
                    .padding(.leading, indent - 8)
            }

            if row.node.isUnavailable {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.greyText)
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
            } else {
                UnifiedMarkerBadge(
                    intent: row.node.intentEnum ?? .analysis,
                    size: 26
                )
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                if row.node.isUnavailable {
                    Text("Unavailable marker")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                } else {
                    Text(row.node.titleDisplayText ?? "Marker")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(isAccessibilitySize ? 3 : 1)
                    if let author = row.node.authorDisplayText {
                        Text(author)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                            .lineLimit(1)
                    }
                    if let raw = row.node.timeframe,
                       let timeframe = RLChartTimeframe.fromBackendString(raw) {
                        Text(timeframe.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.greyText)
                    }
                }
                if isAccessibilitySize {
                    trailingMetadata
                }
            }

            Spacer(minLength: 0)

            if !isAccessibilitySize {
                trailingMetadata
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(row.isRequested ? AppColors.whiteText.opacity(0.10) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { if canOpen { onOpen?() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(canOpen ? .isButton : [])
    }

    /// Relationship chip and response count, placed inline at normal sizes and
    /// beneath the title at accessibility sizes.
    @ViewBuilder
    private var trailingMetadata: some View {
        HStack(spacing: 6) {
            // Both of these carry meaning, so they use a text style that
            // scales with Dynamic Type. A fixed point size would leave the
            // relationship label at 10pt beside body text several times its
            // height at accessibility sizes.
            if let relationship {
                Text(relationship.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(relationship.accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(relationship.accentColor.opacity(0.14))
                    )
            }

            if row.node.directResponseCount > 0 {
                Text("\(row.node.directResponseCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.greyText)
            }
        }
    }

    /// Relationship is spoken, never carried by colour alone.
    private var accessibilityText: String {
        if row.node.isUnavailable {
            return "Unavailable marker, depth \(row.depth)"
        }
        var parts: [String] = []
        if let relationship { parts.append(relationship.displayName) }
        if let title = row.node.titleDisplayText { parts.append(title) }
        if let author = row.node.authorDisplayText { parts.append("by \(author)") }
        if let raw = row.node.timeframe, let timeframe = RLChartTimeframe.fromBackendString(raw) {
            parts.append("on \(timeframe.displayName)")
        }
        if row.isRequested { parts.append("current marker") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Placement banner

/// Shown while composing a response.
struct MarkerLinkPlacementBanner: View {
    let context: MarkerLinkContext
    let failureMessage: String?
    let onChangeRelationship: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: context.relationship.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(context.relationship.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.bannerSentence)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)
                    Text(context.parentTimeframe.map { "Parent on \($0.displayName) · Shared with the guild" } ?? "Shared with the guild")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)

                Button(action: onChangeRelationship) {
                    Text("Change")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(context.relationship.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change relationship")

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.greyText)
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(context.relationship.accentColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(context.relationship.accentColor.opacity(0.30), lineWidth: 1)
                )
        )
    }
}
