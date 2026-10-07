import SwiftUI
import UIKit

/// UITextView provides an explicit selection/offset round trip on iOS 17 as
/// well as newer systems. Recreating a destination does not recreate its cursor.
struct MarkerWorkspaceTextInput: View {
    let placeholder: String
    @Binding var text: String
    @ObservedObject var placementState: MarkerPlacementState
    let fieldID: String
    @Environment(\.markerSheetDetents) private var sheetDetents

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkerWorkspaceTextEditor(text: $text, selection: Binding(
                get: { placementState.workspace.textSelections[fieldID] ?? NSRange(location: text.utf16.count, length: 0) },
                set: { placementState.workspace.textSelections[fieldID] = $0 }
            ), offset: Binding(
                get: { placementState.workspace.textOffsets[fieldID] ?? .zero },
                set: { placementState.workspace.textOffsets[fieldID] = $0 }
            ), placeholder: placeholder, onFocus: { placementState.isTextInputFocused = $0 },
               sheetDetents: sheetDetents)
            if text.isEmpty {
                Text(placeholder).font(.subheadline).foregroundColor(AppColors.greyText)
                    .padding(.horizontal, 5).padding(.top, 8).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.standardSearchFieldFill))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.standardSearchFieldStroke, lineWidth: 1))
    }
}

struct MarkerWorkspaceTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var offset: CGPoint
    let placeholder: String
    let onFocus: (Bool) -> Void
    /// Settles the sheet at its current height before the keyboard rises.
    var sheetDetents: MarkerSheetDetentController? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = placeholder
        view.delegate = context.coordinator
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        updateDraft(in: view)
        view.textColor = UIColor(AppColors.primaryForeground)
        view.tintColor = UIColor(AppColors.accentColor)
        context.coordinator.updating = false
    }
    /// UIKit owns text and cursor while an input method is composing.
    func updateDraft(in view: UITextView) {
        guard view.markedTextRange == nil else { return }
        if view.text != text { view.text = text }
        let length = text.utf16.count
        let location = min(selection.location, length)
        let range = NSRange(location: location, length: min(selection.length, length - location))
        if view.selectedRange != range { view.selectedRange = range }
        if !view.isFirstResponder && view.contentOffset != offset { view.setContentOffset(offset, animated: false) }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(180, max(86, size.height)))
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkerWorkspaceTextEditor
        var updating = false
        init(_ parent: MarkerWorkspaceTextEditor) { self.parent = parent }
        func textViewShouldBeginEditing(_ view: UITextView) -> Bool {
            guard let sheet = parent.sheetDetents else { return true }
            // Focus may wait for the sheet to settle. The tap that asked for
            // it is gone by then, so the remembered cursor (or the end) is
            // restored; UIKit would otherwise put it at the start.
            let wanted = parent.selection
            return sheet.shouldBeginEditing { [weak self, weak view] in
                guard let self, let view, view.becomeFirstResponder() else { return }
                let length = view.text.utf16.count
                let location = min(wanted.location, length)
                view.selectedRange = NSRange(location: location, length: min(wanted.length, length - location))
                self.parent.selection = view.selectedRange
            }
        }
        func textViewDidChange(_ view: UITextView) {
            guard !updating else { return }
            parent.text = view.text
            parent.selection = view.selectedRange
        }
        func textViewDidChangeSelection(_ view: UITextView) {
            guard !updating, view.isFirstResponder else { return }
            parent.selection = view.selectedRange
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Only the author's own scrolling is kept: a layout pass during a
            // sheet resize must not publish to the draft (it redraws the chart).
            guard !updating, scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else { return }
            parent.offset = scrollView.contentOffset
        }
        func textViewDidBeginEditing(_ view: UITextView) { parent.onFocus(true) }
        func textViewDidEndEditing(_ view: UITextView) { parent.onFocus(false) }
    }
}

/// Single-line editors also keep their cursor in the session, including URLs,
/// titles and an unfinished decimal. The text is staged by the caller.
struct MarkerWorkspaceLineInput: View {
    let placeholder: String
    @Binding var text: String
    @ObservedObject var placementState: MarkerPlacementState
    let fieldID: String
    var keyboard: UIKeyboardType = .default
    var label: String? = nil
    var trailing = false
    @Environment(\.markerSheetDetents) private var sheetDetents

    var body: some View {
        MarkerWorkspaceLineEditor(text: $text, selection: Binding(
            get: { placementState.workspace.textSelections[fieldID] ?? NSRange(location: text.utf16.count, length: 0) },
            set: { placementState.workspace.textSelections[fieldID] = $0 }
        ), placeholder: placeholder, fieldID: fieldID, keyboard: keyboard, label: label ?? placeholder,
           trailing: trailing, onFocus: { placementState.isTextInputFocused = $0 }, sheetDetents: sheetDetents)
        .padding(.horizontal, 12).frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.standardSearchFieldFill))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.standardSearchFieldStroke, lineWidth: 1))
    }
}

private struct MarkerWorkspaceLineEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let placeholder: String
    let fieldID: String
    let keyboard: UIKeyboardType
    let label: String
    let trailing: Bool
    let onFocus: (Bool) -> Void
    var sheetDetents: MarkerSheetDetentController? = nil
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        view.delegate = context.coordinator
        view.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // No keyboard bar, number pads included (owner, 7 Oct): every
        // keyboard goes by dragging the content down, or by moving on
        // (Review, Adjust on chart, showing the chart).
        return view
    }
    func updateUIView(_ view: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        if view.markedTextRange == nil, view.text != text { view.text = text }
        view.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(AppColors.greyText)])
        view.textColor = UIColor(AppColors.primaryForeground)
        view.tintColor = UIColor(AppColors.accentColor)
        view.keyboardType = keyboard
        view.textAlignment = trailing ? .right : .left
        if keyboard == .URL || keyboard == .decimalPad { view.autocapitalizationType = .none; view.autocorrectionType = .no }
        view.accessibilityLabel = label
        view.accessibilityIdentifier = fieldID
        let length = text.utf16.count
        let start = min(selection.location, length)
        let end = min(start + selection.length, length)
        if let a = view.position(from: view.beginningOfDocument, offset: start),
           let b = view.position(from: view.beginningOfDocument, offset: end),
           let range = view.textRange(from: a, to: b), view.markedTextRange == nil {
            let current = view.selectedTextRange
            if current.map({ view.offset(from: view.beginningOfDocument, to: $0.start) != start || view.offset(from: view.beginningOfDocument, to: $0.end) != end }) ?? true {
                view.selectedTextRange = range
            }
        }
        context.coordinator.updating = false
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MarkerWorkspaceLineEditor
        var updating = false
        init(_ parent: MarkerWorkspaceLineEditor) { self.parent = parent }
        @objc func changed(_ view: UITextField) {
            guard !updating else { return }
            parent.text = view.text ?? ""
            saveSelection(view)
        }
        private func saveSelection(_ view: UITextField) {
            guard let range = view.selectedTextRange else { return }
            parent.selection = NSRange(location: view.offset(from: view.beginningOfDocument, to: range.start),
                                       length: view.offset(from: range.start, to: range.end))
        }
        func textFieldDidChangeSelection(_ view: UITextField) {
            guard !updating, view.isFirstResponder else { return }
            saveSelection(view)
        }
        func textFieldShouldBeginEditing(_ view: UITextField) -> Bool {
            guard let sheet = parent.sheetDetents else { return true }
            // Focus may wait for the sheet to settle: restore the remembered
            // cursor (or the end), as the text view does.
            let wanted = parent.selection
            return sheet.shouldBeginEditing { [weak self, weak view] in
                guard let self, let view, view.becomeFirstResponder() else { return }
                let length = (view.text ?? "").utf16.count
                let start = min(wanted.location, length)
                let end = min(start + wanted.length, length)
                if let a = view.position(from: view.beginningOfDocument, offset: start),
                   let b = view.position(from: view.beginningOfDocument, offset: end) {
                    view.selectedTextRange = view.textRange(from: a, to: b)
                }
                self.saveSelection(view)
            }
        }
        func textFieldDidBeginEditing(_ view: UITextField) {
            parent.onFocus(true)
            // A price is replaced far more often than corrected: select it,
            // so typing replaces it wherever the field was tapped (its text
            // is right-aligned, so a tap on its left put the cursor first).
            guard parent.keyboard == .decimalPad || parent.keyboard == .numberPad else { return }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, view.isFirstResponder else { return }
                view.selectedTextRange = view.textRange(from: view.beginningOfDocument, to: view.endOfDocument)
                self.saveSelection(view)
            }
        }
        func textFieldDidEndEditing(_ view: UITextField) { parent.onFocus(false) }
    }
}

