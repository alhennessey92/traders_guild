//
//  MarkerGuidedPostTypeViews.swift
//  traders_guild
//
//  v1.5 Post types beyond Analysis and Question: a poll's choices and an
//  alert's severity, on Details and on Review. Each is the type's own small
//  setting under the one text field every Post shares.
//

import SwiftUI

// MARK: - Keyboard

private struct MarkerWorkspaceKeyboardScrollRoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// How far the keyboard (and the bar riding on it) covers the workspace's
    /// content, which keeps its size while typing: room to scroll every row
    /// into view without the content collapsing.
    var markerWorkspaceKeyboardScrollRoom: CGFloat {
        get { self[MarkerWorkspaceKeyboardScrollRoomKey.self] }
        set { self[MarkerWorkspaceKeyboardScrollRoomKey.self] = newValue }
    }
}

/// How far the keyboard covers this view: its own bottom edge in the window
/// against the keyboard's final frame. Placed behind content that ignores the
/// keyboard, so its frame (the sheet's full height) never depends on what it
/// reports, and the report cannot feed back into its own layout.
struct MarkerKeyboardOverlapReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> Reader {
        let view = Reader()
        view.onChange = onChange
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: Reader, context: Context) {
        view.onChange = onChange
    }

    final class Reader: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var keyboardScreenFrame: CGRect = .zero
        private var reported: CGFloat = -1
        private var observers: [NSObjectProtocol] = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    guard let self else { return }
                    keyboardScreenFrame = name == UIResponder.keyboardWillHideNotification ? .zero
                        : (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero)
                    report()
                })
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let window else { return }
            var overlap: CGFloat = 0
            if keyboardScreenFrame != .zero {
                let keyboard = window.convert(keyboardScreenFrame, from: window.screen.coordinateSpace)
                // A floating or undocked keyboard covers nothing at the bottom.
                if keyboard.maxY >= window.bounds.maxY - 1, keyboard.width >= window.bounds.width * 0.9 {
                    overlap = max(0, convert(bounds, to: window).maxY - keyboard.minY)
                }
            }
            overlap = overlap.rounded()
            guard overlap != reported else { return }
            reported = overlap
            let value = overlap
            DispatchQueue.main.async { [weak self] in self?.onChange?(value) }
        }
    }
}

/// Watches the sheet's own position while it holds its height on the
/// keyboard, and reports the author pulling it up or down. The sheet's own
/// drag is used rather than a gesture of ours: a gesture competed with it, and
/// only registered once the finger had reversed. Runs only while armed.
struct MarkerSheetDriftWatcher: UIViewRepresentable {
    let isArmed: Bool
    let onDrift: (_ up: Bool) -> Void

    func makeUIView(context: Context) -> Watcher {
        let view = Watcher()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: Watcher, context: Context) {
        view.onDrift = onDrift
        view.setArmed(isArmed)
    }

    static func dismantleUIView(_ view: Watcher, coordinator: ()) {
        view.setArmed(false)
    }

    final class Watcher: UIView {
        /// A pull past this, either way, is deliberate.
        static let threshold: CGFloat = 10
        var onDrift: ((Bool) -> Void)?
        private var link: CADisplayLink?
        private var restTop: CGFloat?

        func setArmed(_ armed: Bool) {
            if armed, link == nil {
                restTop = nil
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common)
                self.link = link
            } else if !armed {
                link?.invalidate()
                link = nil
                restTop = nil
            }
        }

        @objc private func tick() {
            guard let window,
                  let sheet = MarkerSheetTraceProbe.presentedController(from: self)?.view else { return }
            let top = sheet.convert(sheet.bounds, to: window).minY
            guard let rest = restTop else { restTop = top; return }
            let moved = top - rest
            guard abs(moved) > Self.threshold else { return }
            setArmed(false)
            let up = moved < 0
            DispatchQueue.main.async { [weak self] in self?.onDrift?(up) }
        }
    }
}

// MARK: - Draft colour

extension MarkerPlacementState {
    /// The draft's colour in the sheet (buttons, its name, the dock): an
    /// alert's follows its urgency once chosen.
    var draftAccentColor: Color {
        MarkerIntentBadge.accentColor(for: intent, alertSeverity: intent == .alert ? alertSeverity : nil)
    }

    /// Text on that colour: dark on Severe's yellow.
    var draftOnAccentColor: Color {
        MarkerIntentBadge.onAccentForeground(for: intent, alertSeverity: intent == .alert ? alertSeverity : nil)
    }
}

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
    /// An alert's urgency, once chosen: its icon and palette.
    var alertSeverity: MarkerAlertSeverity? = nil

    /// The marker as it was before it wore a face: a glass disc with the
    /// type's own multi-colour SF Symbol (owner, 11 Oct). Selection fades the
    /// whole disc; nothing animates one colour into another.
    var body: some View {
        Group {
            if intent == .alert && alertSeverity == nil {
                // No urgency yet: the shield in amber, rather than the legacy
                // grey that reads as disabled.
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(MarkerVisualSpec.glassTint(for: .alert))
                    Circle().stroke(MarkerIntentBadge.alertAccent.opacity(0.4), lineWidth: MarkerVisualSpec.glassStrokeWidth)
                    Image(systemName: "exclamationmark.shield.fill")
                        .symbolRenderingMode(.palette)
                        .font(.system(size: MarkerVisualSpec.iconSize(for: size, intent: .alert), weight: .bold))
                        .foregroundStyle(MarkerVisualSpec.iconBaseColor,
                                         MarkerIntentBadge.alertAccent.opacity(0.9),
                                         MarkerIntentBadge.alertAccent.opacity(0.6))
                }
                .clipShape(Circle())
            } else {
                UnifiedMarkerBadge(intent: intent, alertSeverity: intent == .alert ? alertSeverity : nil, size: size)
            }
        }
        .opacity(emphasised ? 1 : 0.55)
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
