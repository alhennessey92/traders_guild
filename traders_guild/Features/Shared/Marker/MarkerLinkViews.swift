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
    }

    private func apply(enabled: Bool) {
        let manager = chartViewModel.markerManager
        let wasEnabled = manager?.linkedMarkersEnabled ?? false
        manager?.linkedMarkersEnabled = enabled
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
    let onSelect: (MarkerLinkRelationship) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Respond with a marker")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)
                if let parentSummary {
                    Text(parentSummary)
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)
                }
            }

            ForEach(MarkerLinkRelationship.allCases, id: \.self) { relationship in
                Button {
                    onSelect(relationship)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: relationship.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(relationship.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(relationship.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.primaryForeground)
                            Text(relationship.pickerSubtitle)
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(relationship.accentColor.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(relationship.accentColor.opacity(0.30), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(relationship.displayName). \(relationship.pickerSubtitle)")
            }

            Button("Cancel", action: onCancel)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(16)
    }
}

// MARK: - "This answers that" row

/// The relationship line shown directly under a marker's hero panel.
struct MarkerLinkRelationshipRow: View {
    let relationship: MarkerLinkRelationshipValue?
    let preview: RLMarkerLinkPreviewDTO?
    /// Nil disables tapping — a tombstone, or a preview that cannot navigate.
    let onOpenParent: (() -> Void)?

    private var isUnavailable: Bool {
        preview?.isUnavailable ?? false
    }

    private var accent: Color {
        relationship?.accentColor ?? AppColors.greyText
    }

    /// "Supports Alex's BTC breakout", or a truthful fallback when the parent
    /// is gone. Never invents a name for a marker it cannot see.
    private var sentence: String {
        let name = relationship?.displayName ?? "Linked to"
        guard !isUnavailable else { return "\(name) a removed marker" }
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(sentence)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if isUnavailable {
                        Text("The marker this answers is no longer available")
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

    private var relationship: MarkerLinkRelationshipValue? {
        row.node.relationship
    }

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
            } else {
                UnifiedMarkerBadge(
                    intent: row.node.intentEnum ?? .analysis,
                    size: 26
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                if row.node.isUnavailable {
                    Text("Removed marker")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.greyText)
                } else {
                    Text(row.node.titleDisplayText ?? "Marker")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                    if let author = row.node.authorDisplayText {
                        Text(author)
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            if let relationship {
                Text(relationship.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(relationship.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(relationship.accentColor.opacity(0.14))
                    )
            }

            if row.node.directResponseCount > 0 {
                Text("\(row.node.directResponseCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.greyText)
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

    /// Relationship is spoken, never carried by colour alone.
    private var accessibilityText: String {
        if row.node.isUnavailable {
            return "Removed marker, depth \(row.depth)"
        }
        var parts: [String] = []
        if let relationship { parts.append(relationship.displayName) }
        if let title = row.node.titleDisplayText { parts.append(title) }
        if let author = row.node.authorDisplayText { parts.append("by \(author)") }
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

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.bannerSentence)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(2)
                    Text("Shared with the guild")
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
