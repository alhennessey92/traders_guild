import SwiftUI
import UIKit

struct DismissKeyboardOnTapBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func dismissKeyboardOnTapBackground() -> some View {
        background(DismissKeyboardOnTapBackground())
    }

    func dismissKeyboardOnTapAndDragBackground(minimumVerticalTranslation: CGFloat = 14) -> some View {
        dismissKeyboardOnTapBackground()
            .simultaneousGesture(
                DragGesture(minimumDistance: minimumVerticalTranslation)
                    .onChanged { value in
                        guard value.translation.height > minimumVerticalTranslation,
                              abs(value.translation.height) > abs(value.translation.width) else { return }
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    },
                including: .subviews
            )
    }

    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
