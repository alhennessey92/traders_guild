//
//  MarkerGuidedPostTypeViews.swift
//  traders_guild
//
//  v1.5 Post types beyond Analysis and Question: a poll's choices and an
//  alert's severity, on Details and on Review. Each is the type's own small
//  setting under the one text field every Post shares.
//

import SwiftUI

// MARK: - Type glyph

/// A Post type's badge on the sheet: the glyph its face wears on the chart,
/// on a circle, and an alert's on a shield (owner, 11 Oct: the crest look).
/// Selection fades the shape's opacity; its colour never animates. An
/// alert's theme-aware amber faded through clear when it did, so the shape
/// vanished and came back between selections.
struct MarkerIntentGlyph: View {
    let intent: RLMarkerIntent
    var size: CGFloat = 26
    var emphasised = true

    var body: some View {
        let color = MarkerIntentBadge.accentColor(for: intent)
        ZStack {
            if intent == .alert {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.98))
                    .foregroundColor(color)
                    .opacity(emphasised ? 1 : 0.45)
                Image(systemName: "exclamationmark")
                    .font(.system(size: size * 0.40, weight: .heavy))
                    .foregroundColor(.white)
                    .offset(y: -size * 0.04)
            } else {
                Circle()
                    .fill(color)
                    .opacity(emphasised ? 1 : 0.45)
                Image(systemName: MarkerIntentBadge.style(intent: intent)?.symbol ?? intent.icon)
                    // The bars are wide for their height: smaller, so they
                    // sit inside the circle as the other glyphs do.
                    .font(.system(size: size * (intent == .poll ? 0.36 : 0.46), weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Alert severity

/// How urgent an alert is, in the four words the server and older apps use
/// (the note carries the chosen one at its front when it is sent).
struct MarkerGuidedAlertSeverityPicker: View {
    let selected: MarkerAlertSeverity?
    let onSelect: (MarkerAlertSeverity) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Mildest first, as the eye reads left to right.
    static let order: [MarkerAlertSeverity] = [.mild, .moderate, .severe, .critical]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkerGuidedSectionTitle("How urgent?")
            MarkerChipFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Self.order, id: \.self) { severity in
                    chip(severity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selected.map { "Urgency: \($0.displayLabel)" } ?? "Urgency: not chosen")
        .accessibilityIdentifier("guided.severityPicker")
    }

    private func chip(_ severity: MarkerAlertSeverity) -> some View {
        let isSelected = selected == severity
        return Button { onSelect(severity) } label: {
            HStack(spacing: 6) {
                Image(systemName: severity.markerIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(severity.color)
                    .accessibilityHidden(true)
                Text(severity.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(Capsule().fill(isSelected ? severity.color.opacity(0.24) : AppColors.whiteText.opacity(0.05)))
            .overlay(Capsule().stroke(isSelected ? severity.color.opacity(0.85) : Color.clear, lineWidth: 1.5))
            .padding(.vertical, 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(severity.displayLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("guided.severity.\(severity.rawValue)")
    }
}

/// The chosen severity, as Review and the view sheet show it.
struct MarkerGuidedAlertSeverityPill: View {
    let severity: MarkerAlertSeverity

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: severity.markerIcon)
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            Text(severity.displayLabel)
                .font(.caption.weight(.bold))
        }
        .foregroundColor(severity.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(severity.color.opacity(0.16)))
        .overlay(Capsule().stroke(severity.color.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Urgency: \(severity.displayLabel)")
        .accessibilityIdentifier("guided.severityPill")
    }
}

// MARK: - Poll choices

/// A poll's two to four choices under its question. Once posted they are
/// fixed (the server keeps them, votes and all), so an edit shows them read
/// only.
struct MarkerGuidedPollChoicesEditor: View {
    @ObservedObject var placementState: MarkerPlacementState

    private var isLocked: Bool { placementState.isGuidedEdit }
    private var maxChoices: Int { MarkerPlacementRequirements.maximumPollChoices }
    private var maxCharacters: Int { MarkerPlacementRequirements.maximumPollChoiceCharacters }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkerGuidedSectionTitle("Choices")
            if isLocked {
                ForEach(Array(placementState.validPollOptions.enumerated()), id: \.offset) { _, choice in
                    MarkerGuidedPollChoiceRow(text: choice)
                }
                Text("Choices can't change once a poll is posted.")
                    .font(.caption)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(placementState.pollOptions.indices), id: \.self) { index in
                    choiceField(index)
                }
                if placementState.pollOptions.count < maxChoices {
                    Button {
                        placementState.pollOptions.append("")
                    } label: {
                        Label("Add a choice", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.intentPollPurple)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("guided.poll.addChoice")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guided.pollChoices")
    }

    private func choiceField(_ index: Int) -> some View {
        let text = Binding<String>(
            get: { placementState.pollOptions.indices.contains(index) ? placementState.pollOptions[index] : "" },
            set: { newValue in
                guard placementState.pollOptions.indices.contains(index) else { return }
                placementState.pollOptions[index] = newValue
            }
        )
        let length = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                MarkerWorkspaceLineInput(
                    placeholder: "Choice \(index + 1)",
                    text: text,
                    placementState: placementState,
                    fieldID: "guided.pollChoice.\(index)"
                )
                .accessibilityIdentifier("guided.poll.choice.\(index)")
                // Two choices is the least a poll can have.
                if placementState.pollOptions.count > 2 {
                    Button {
                        guard placementState.pollOptions.indices.contains(index) else { return }
                        placementState.pollOptions.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.overlayPanelSecondaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove choice \(index + 1)")
                    .accessibilityIdentifier("guided.poll.remove.\(index)")
                }
            }
            if length > maxCharacters {
                Text("\(length - maxCharacters) over the \(maxCharacters)-character limit")
                    .font(.caption)
                    .foregroundColor(AppColors.statusWarning)
                    .padding(.leading, 4)
            }
        }
    }
}

/// A choice as the guild will see it before voting.
struct MarkerGuidedPollChoiceRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.intentPollPurple)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.intentPollPurple.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.intentPollPurple.opacity(0.25), lineWidth: 1))
    }
}
