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
    /// Seeds the fixture draft as a Setup instead of an Analysis.
    static var seedsSetup: Bool {
        #if DEBUG || TG_ISOLATED_DEV
        enabled && ProcessInfo.processInfo.arguments.contains("-MarkerMainViewSetupFixture")
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
    /// Lays the fixture's draft over the chart's own seeding. A filled note
    /// (`-MarkerMainViewFilledNote`) makes Review available without typing.
    @MainActor
    static func seed(_ state: MarkerPlacementState, intent: RLMarkerIntent) {
        #if DEBUG || TG_ISOLATED_DEV
        state.reset(to: intent, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: 63920)
        if intent == .setup {
            state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 65000, label: "TP")))
            state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 63000, label: "SL")))
            state.trackingEnabled = true
            state.recordSetupLevelSeed()
        }
        if ProcessInfo.processInfo.arguments.contains("-MarkerMainViewFilledNote") {
            state.note = intent == .setup ? "Reclaim of the range low." : "Range low holds into the open."
        }
        state.captureDraftBaseline()
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
            let controller = MarkerSheetTraceProbe.presentedController(from: self)
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

/// Fixture and trace instrumentation only. Production builds have neither
/// switch, so no probe is mounted and nothing is sampled.
struct MarkerSheetGeometryObserver: ViewModifier {
    let selection: PresentationDetent
    /// Workspace navigation publishes through its session, not the host, so
    /// the route is read whenever the session changes.
    @ObservedObject var session: MarkerWorkspaceSession
    var route: () -> String = { "" }
    var mode: String = ""
    @State private var geometry = MarkerSheetGeometry()

    private var showsReadout: Bool { MarkerMainViewSheetFixture.enabled }

    func body(content: Content) -> some View {
        content
            .background {
                if showsReadout {
                    MarkerSheetGeometryProbe(onMeasure: { value in
                        geometry = value
                        print("[MarkerSheetGeometry] selected:\(selection) \(value.summary)")
                    }, selectionID: "\(selection)").allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .modifier(MarkerSheetTraceModifier(selection: selection, route: route(), mode: mode))
            .overlay(alignment: .topTrailing) {
                if showsReadout {
                    Text("selected:\(selection) \(geometry.summary)")
                        .font(.system(size: 7, design: .monospaced)).foregroundStyle(.yellow)
                        .padding(2).background(.black.opacity(0.8))
                        .accessibilityIdentifier("mainFixture.geometry")
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: - Frame trace (fixture-only)

/// Records the sheet's on-screen top edge every display frame, with the
/// presenting controller's identity, the selected detent, the workspace route
/// and whether the collapsed bar is showing. A UI test reads it back to prove
/// that ordinary navigation never drops, hides or re-presents the sheet.
/// Enabled only by `-MarkerSheetTrace` in DEBUG or isolated-DEV builds.
@MainActor
final class MarkerSheetTrace: NSObject, ObservableObject {
    static let shared = MarkerSheetTrace()
    static let isEnabled: Bool = {
        #if DEBUG || TG_ISOLATED_DEV
        ProcessInfo.processInfo.arguments.contains("-MarkerSheetTrace")
        #else
        false
        #endif
    }()

    struct Sample: Codable, Equatable {
        var t: Double
        var top: Int
        var ctl: Int
        var sel: String
        var route: String
        var mode: String
        var dock: Bool
        /// The chart layer's on-screen height behind the sheet (-1: none).
        var chart: Int
    }

    @Published private(set) var json = "{}"
    /// How many times the chart view's body has run (trace builds only).
    private(set) var chartRenders = 0
    /// How many times MainView's body has run. It owns the draft, so every
    /// draft announcement rebuilds the whole shell, chart included.
    private(set) var shellRenders = 0
    var selection = ""
    var route = ""
    var mode = ""
    var dockVisible = false

    private var samples: [Sample] = []
    private var controllers: [ObjectIdentifier] = []
    private weak var probe: UIView?
    /// The chart layer, registered by its own probe, to show it never moves.
    weak var chartProbe: UIView?
    private var link: CADisplayLink?
    private let start = CACurrentMediaTime()
    private var lastPublish: CFTimeInterval = 0
    private var dirty = false

    /// Called from the chart's body: counts its redraws while tracing.
    static func noteChartRender() {
        guard isEnabled else { return }
        shared.chartRenders += 1
    }

    static func noteShellRender() {
        guard isEnabled else { return }
        shared.shellRenders += 1
    }

    func attach(_ view: UIView) {
        probe = view
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        var top = -1
        var controllerIndex = -1
        if let probe, let window = probe.window,
           let controller = MarkerSheetTraceProbe.presentedController(from: probe) {
            let layer = controller.view.layer.presentation() ?? controller.view.layer
            let windowLayer = window.layer.presentation() ?? window.layer
            top = Int(layer.convert(layer.bounds, to: windowLayer).minY.rounded())
            let id = ObjectIdentifier(controller)
            if let index = controllers.firstIndex(of: id) { controllerIndex = index } else {
                controllers.append(id)
                controllerIndex = controllers.count - 1
            }
        }
        let sample = Sample(t: ((now - start) * 1000).rounded() / 1000, top: top, ctl: controllerIndex,
                            sel: selection, route: route, mode: mode, dock: dockVisible,
                            chart: chartHeight())
        if let last = samples.last, last.top == sample.top, last.ctl == sample.ctl, last.sel == sample.sel,
           last.route == sample.route, last.mode == sample.mode, last.dock == sample.dock, last.chart == sample.chart {
            // Unchanged: only the reader's "now" advances.
        } else {
            samples.append(sample)
            if samples.count > 600 { samples.removeFirst(samples.count - 600) }
            dirty = true
        }
        if (dirty && now - lastPublish > 0.1) || now - lastPublish > 0.25 {
            lastPublish = now
            dirty = false
            let payload = Payload(now: ((now - start) * 1000).rounded() / 1000, chartRenders: chartRenders, shellRenders: shellRenders, samples: samples)
            if let data = try? JSONEncoder().encode(payload) {
                json = String(decoding: data, as: UTF8.self)
            }
        }
    }

    /// The chart layer's laid-out height (animated, but in its own space):
    /// a keyboard squashing the layout changes it; iOS's own card-stack
    /// scaling of the screen behind a full-height sheet does not.
    private func chartHeight() -> Int {
        guard let chartProbe, chartProbe.window != nil else { return -1 }
        let layer = chartProbe.layer.presentation() ?? chartProbe.layer
        return Int(layer.bounds.height.rounded())
    }

    private struct Payload: Codable {
        let now: Double
        let chartRenders: Int
        let shellRenders: Int
        let samples: [Sample]
    }
}

/// Mounts the display-link probe inside the sheet and exposes the trace to
/// UI tests as an accessibility value.
private struct MarkerSheetTraceModifier: ViewModifier {
    let selection: PresentationDetent
    let route: String
    let mode: String

    func body(content: Content) -> some View {
        if MarkerSheetTrace.isEnabled {
            content
                .background { MarkerSheetTraceProbe().allowsHitTesting(false).accessibilityHidden(true) }
                .overlay(alignment: .bottomLeading) { MarkerSheetTraceReadout() }
                .onAppear { update() }
                .onChange(of: "\(selection)|\(route)|\(mode)") { _, _ in update() }
        } else {
            content
        }
    }

    private func update() {
        let trace = MarkerSheetTrace.shared
        trace.selection = Self.label(selection)
        trace.route = route
        trace.mode = mode
    }

    static func label(_ detent: PresentationDetent) -> String {
        switch detent {
        case MarkerSheetDetents.dock: return "dock"
        case MarkerSheetDetents.browse: return "browse"
        case MarkerSheetDetents.working: return "working"
        case MarkerSheetDetents.tall: return "tall"
        default: return "\(detent)".replacingOccurrences(of: "PresentationDetent", with: "")
        }
    }
}

private struct MarkerSheetTraceReadout: View {
    @ObservedObject private var trace = MarkerSheetTrace.shared
    var body: some View {
        Color.clear
            .frame(width: 2, height: 2)
            .accessibilityElement()
            .accessibilityLabel("Sheet trace")
            .accessibilityValue(trace.json)
            .accessibilityIdentifier("sheetTrace")
    }
}

struct MarkerSheetTraceProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = TraceView()
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}

    final class TraceView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { MainActor.assumeIsolated { MarkerSheetTrace.shared.attach(self) } }
        }
    }

    /// The sheet's own presented controller: the outermost parent of the
    /// controller that hosts this view.
    static func presentedController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        var controller: UIViewController?
        while let next = responder {
            if let candidate = next as? UIViewController { controller = candidate; break }
            responder = next.next
        }
        while let parent = controller?.parent { controller = parent }
        return controller
    }
}

/// Registers the chart layer (behind the sheet) with the frame trace.
struct MarkerChartLayerProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { MainActor.assumeIsolated { MarkerSheetTrace.shared.chartProbe = self } }
        }
    }
}
