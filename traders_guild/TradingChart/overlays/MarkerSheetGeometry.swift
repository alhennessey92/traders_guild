import SwiftUI
import UIKit

/// DEV switch has no shipping entry point. Does not create or restore an account.
enum MarkerMainViewSheetFixture {
    static var enabled: Bool {
        #if DEBUG || TG_ISOLATED_DEV
        ProcessInfo.processInfo.arguments.contains("-MarkerMainViewSheetFixture")
        #else
        false
        #endif
    }
    static var anyMarkerFixture: Bool {
        #if DEBUG || TG_ISOLATED_DEV
        let arguments = ProcessInfo.processInfo.arguments
        return ["-MarkerMainViewSheetFixture", "-MarkerSheetShellFixture", "-MarkerGuidedCreationFixture", "-MarkerViewingFixture", "-MarkerLinkFixtures"].contains { arguments.contains($0) }
        #else
        return false
        #endif
    }
    static var user: RLUserDTO? {
        guard enabled else { return nil }
        return RLUserDTO(id: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!, email: "fixture@example.invalid", username: "fixture",
            displayName: "Fixture", avatarUrl: nil, globalReputation: 0, isOnline: false, isVerified: true,
            isSuperuser: false, lastSeenAt: nil, createdAt: .distantPast, updatedAt: .distantPast,
            dateOfBirth: nil, status: "active", authProvider: nil)
    }
}

struct MarkerSheetGeometry: Equatable {
    var sheetFrame: CGRect = .zero
    var contentFrame: CGRect = .zero
    var keyboardFrame: CGRect = .zero
    var windowFrame: CGRect = .zero
    var safeAreaInsets: UIEdgeInsets = .zero
    var nativeSelection: String = "none"
    var keyboardOverlap: CGFloat {
        let intersection = windowFrame.intersection(keyboardFrame)
        // Floating keyboards do not reduce the whole sheet's viewport.
        guard !intersection.isNull, intersection.width >= windowFrame.width * 0.9,
              intersection.maxY >= windowFrame.maxY - 1 else { return 0 }
        return intersection.height
    }
    var keyboardWorkingBudget: CGFloat {
        max(160, windowFrame.height - keyboardOverlap - safeAreaInsets.top - safeAreaInsets.bottom - 12)
    }
    var visibleSheetHeight: CGFloat {
        let bottom = keyboardOverlap > 0 ? min(sheetFrame.maxY, keyboardFrame.minY) : sheetFrame.maxY
        return max(0, bottom - sheetFrame.minY)
    }
    var summary: String {
        "sheetTop:\(Int(sheetFrame.minY)) visible:\(Int(visibleSheetHeight)) content:\(Int(contentFrame.height)) keyboardTop:\(Int(keyboardFrame.minY)) overlap:\(Int(keyboardOverlap)) native:\(nativeSelection)"
    }
}

/// The probe lives inside the actual SwiftUI sheet. Keyboard frames are
/// converted to its window; no global screen-height subtraction.
struct MarkerSheetGeometryProbe: UIViewRepresentable {
    let onMeasure: (MarkerSheetGeometry) -> Void
    let selectionID: String
    func makeUIView(context: Context) -> Probe {
        let probe = Probe(); probe.onMeasure = onMeasure; probe.isUserInteractionEnabled = false
        return probe
    }
    func updateUIView(_ view: Probe, context: Context) {
        view.onMeasure = onMeasure
        view.updateSelection(selectionID)
    }
    final class Probe: UIView {
        var onMeasure: ((MarkerSheetGeometry) -> Void)?
        private var keyboardScreenFrame: CGRect = .zero
        private var last: MarkerSheetGeometry?
        private var settledSample: DispatchWorkItem?
        private var lastLayoutSize: CGSize = .zero
        private var selectionID = ""
        private var observers: [NSObjectProtocol] = []
        override init(frame: CGRect) {
            super.init(frame: frame)
            for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    guard let self else { return }
                    keyboardScreenFrame = name == UIResponder.keyboardWillHideNotification ? .zero
                        : (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero)
                    sample()
                    let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
                    scheduleSettledSample(after: duration + 0.08)
                })
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        deinit { settledSample?.cancel(); observers.forEach(NotificationCenter.default.removeObserver) }
        override func didMoveToWindow() { super.didMoveToWindow(); sample(); scheduleSettledSample(after: 0.4) }
        override func layoutSubviews() {
            super.layoutSubviews(); sample()
            if bounds.size != lastLayoutSize {
                lastLayoutSize = bounds.size
                scheduleSettledSample(after: 0.3)
            }
        }
        func updateSelection(_ value: String) {
            guard selectionID != value else { return }
            selectionID = value
            scheduleSettledSample(after: 0.3)
        }
        /// One coalesced sample after native layout/keyboard animation settles.
        /// Translation need not trigger another UIView layout callback.
        private func scheduleSettledSample(after delay: TimeInterval) {
            settledSample?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.sample() }
            settledSample = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); sample() }
        private func sample() {
            guard let window else { return }
            var responder: UIResponder? = self
            var controller: UIViewController?
            while let next = responder {
                if let candidate = next as? UIViewController { controller = candidate; break }
                responder = next.next
            }
            while let parent = controller?.parent { controller = parent }
            let keyboard = keyboardScreenFrame == .zero ? CGRect.zero
                : window.convert(keyboardScreenFrame, from: window.screen.coordinateSpace)
            let value = MarkerSheetGeometry(
                sheetFrame: controller.map { $0.view.convert($0.view.bounds, to: window) } ?? convert(bounds, to: window),
                contentFrame: convert(bounds, to: window), keyboardFrame: keyboard,
                windowFrame: window.bounds, safeAreaInsets: window.safeAreaInsets,
                nativeSelection: controller?.sheetPresentationController?.selectedDetentIdentifier?.rawValue ?? "none")
            guard value != last else { return }; last = value
            DispatchQueue.main.async { [weak self] in self?.onMeasure?(value) }
        }
    }
}
struct MarkerSheetGeometryObserver: ViewModifier {
    @ObservedObject var model: MarkerSheetPresentationModel
    let selection: PresentationDetent
    var enabled: Bool = true
    func body(content: Content) -> some View {
        content.background {
            if enabled {
                MarkerSheetGeometryProbe(onMeasure: { value in
                    model.updateGeometry(value, selection: selection)
                    if MarkerMainViewSheetFixture.enabled {
                        print("[MarkerSheetGeometry] selected:\(selection) \(value.summary)")
                    }
                }, selectionID: "\(selection)").allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if MarkerMainViewSheetFixture.enabled {
                Text("selected:\(selection) \(model.geometry.summary)")
                    .font(.system(size: 7, design: .monospaced)).foregroundStyle(.yellow)
                    .padding(2).background(.black.opacity(0.8))
                    .accessibilityIdentifier("mainFixture.geometry")
                    .allowsHitTesting(false)
            }
        }
    }
}
