import SwiftUI
import UIKit

/// UITextView provides an explicit selection/offset round trip on iOS 17 as
/// well as newer systems. Recreating a destination does not recreate its cursor.
struct MarkerWorkspaceTextInput: View {
    let placeholder: String
    @Binding var text: String
    @ObservedObject var placementState: MarkerPlacementState
    let fieldID: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkerWorkspaceTextEditor(text: $text, selection: Binding(
                get: { placementState.workspace.textSelections[fieldID] ?? NSRange(location: text.utf16.count, length: 0) },
                set: { placementState.workspace.textSelections[fieldID] = $0 }
            ), offset: Binding(
                get: { placementState.workspace.textOffsets[fieldID] ?? .zero },
                set: { placementState.workspace.textOffsets[fieldID] = $0 }
            ), placeholder: placeholder, onFocus: { placementState.isTextInputFocused = $0 })
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

private struct MarkerWorkspaceTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var offset: CGPoint
    let placeholder: String
    let onFocus: (Bool) -> Void

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
        if view.text != text { view.text = text }
        view.textColor = UIColor(AppColors.primaryForeground)
        view.tintColor = UIColor(AppColors.accentColor)
        let length = text.utf16.count
        let location = min(selection.location, length)
        let range = NSRange(location: location, length: min(selection.length, length - location))
        if view.selectedRange != range { view.selectedRange = range }
        if !view.isFirstResponder && view.contentOffset != offset { view.setContentOffset(offset, animated: false) }
        context.coordinator.updating = false
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
            guard !updating else { return }
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

    var body: some View {
        MarkerWorkspaceLineEditor(text: $text, selection: Binding(
            get: { placementState.workspace.textSelections[fieldID] ?? NSRange(location: text.utf16.count, length: 0) },
            set: { placementState.workspace.textSelections[fieldID] = $0 }
        ), placeholder: placeholder, fieldID: fieldID, keyboard: keyboard, label: label ?? placeholder,
           trailing: trailing, onFocus: { placementState.isTextInputFocused = $0 })
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
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        view.delegate = context.coordinator
        view.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ view: UITextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        if view.text != text { view.text = text }
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
        func textFieldDidBeginEditing(_ view: UITextField) { parent.onFocus(true) }
        func textFieldDidEndEditing(_ view: UITextField) { parent.onFocus(false) }
    }
}
