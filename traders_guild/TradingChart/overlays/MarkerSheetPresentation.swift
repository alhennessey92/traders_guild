import SwiftUI
import UIKit

/// Identifies the actual sheet routes, including transitions that share the
/// legacy detents. Draft data and API contracts remain outside presentation.
enum MarkerSheetSurface: Equatable {
    case add
    case guided(MarkerGuidedStep, RLMarkerIntent)
    case legacy(String)

    static func resolve(experiment: Bool, placing: Bool, step: MarkerGuidedStep?, intent: RLMarkerIntent,
                        view: String, primaryAdd: Bool, viewedMarker: UUID?) -> Self {
        guard experiment else { return .legacy("experiment-off") }
        if placing {
            if let step { return .guided(step, intent) }
            return .legacy("placement")
        }
        if let viewedMarker { return .legacy("view-\(viewedMarker)") }
        return view == "Markers" && primaryAdd ? .add : .legacy(view)
    }

    var measurementID: String {
        switch self {
        case .add: return "add"
        case let .guided(step, intent): return "\(step)-\(intent.rawValue)"
        case let .legacy(route): return route
        }
    }
}

struct MarkerSheetPresentationPolicy: Equatable {
    let surface: MarkerSheetSurface
    let workingHeight: CGFloat

    var compact: PresentationDetent {
        if case .guided = surface { return .fraction(0.18) }
        return .fraction(0.11)
    }
    var tall: PresentationDetent { .fraction(0.9) }
    var working: PresentationDetent {
        if case let .legacy(route) = surface { return .fraction(route == "placement" ? 0.35 : 0.5) }
        return .height(workingHeight)
    }
    var detents: Set<PresentationDetent> {
        if case .legacy = surface { return [.fraction(0.11), .fraction(0.35), .fraction(0.5), tall] }
        return [compact, working, tall]
    }

    /// Used by both MainView and the real-shell fixture. Keep supported user
    /// choices; map the old dock to the new dock, and obsolete working states
    /// to the new working state. No selected detent survives outside the set.
    func normalized(_ selection: PresentationDetent, from previous: Self?) -> PresentationDetent {
        if detents.contains(selection) { return selection }
        if selection == previous?.compact || selection == .fraction(0.11) { return compact }
        return working
    }
}

@MainActor
final class MarkerSheetPresentationModel: ObservableObject {
    @Published private(set) var availableHeight: CGFloat = 600
    @Published private(set) var contentHeights: [String: CGFloat] = [:]
    private var captures: [String: CGFloat] = [:]

    func setAvailableHeight(_ height: CGFloat) {
        guard height.isFinite, height > 100, abs(height - availableHeight) > 2 else { return }
        availableHeight = height.rounded()
    }

    /// Capture once per structure/width/text-size revision, not per keystroke.
    /// Review gets a fresh snapshot on entry; title/disclosure expansion can
    /// request a new revision without a second draft or continuous resizing.
    func capture(_ measurement: MarkerSheetContentMeasurement, surface: MarkerSheetSurface, chrome: CGFloat) {
        let captureKey = "\(surface.measurementID)|\(measurement.revision)|\(measurement.width.rounded())"
        guard measurement.height.isFinite, measurement.height > 1 else { return }
        let height = captures[captureKey] ?? (ceil(measurement.height) + chrome)
        captures[captureKey] = height
        guard contentHeights[surface.measurementID] != height else { return }
        contentHeights[surface.measurementID] = height
    }

    func resetGuidedCaptures() {
        captures = captures.filter { $0.key.hasPrefix("add|") }
        contentHeights = contentHeights.filter { $0.key == "add" }
    }

    func policy(for surface: MarkerSheetSurface) -> MarkerSheetPresentationPolicy {
        let fallback: CGFloat
        switch surface {
        case .add: fallback = 360
        case .guided(.context, _): fallback = availableHeight * 0.72
        case .guided(.details, .setup): fallback = 440
        case .guided(.review, .setup): fallback = 400
        case .guided: fallback = 340
        case .legacy: fallback = 0
        }
        let fitted = contentHeights[surface.measurementID] ?? fallback
        return MarkerSheetPresentationPolicy(surface: surface, workingHeight: min(max(160, fitted), availableHeight * 0.9))
    }
}

struct MarkerSheetPresentationObserver: ViewModifier {
    let policy: MarkerSheetPresentationPolicy
    let enabled: Bool
    @Binding var selection: PresentationDetent

    func body(content: Content) -> some View {
        content
            .onAppear { if enabled { selection = policy.normalized(selection, from: nil) } }
            .onChange(of: policy) { old, new in
                if enabled { selection = new.normalized(selection, from: old) }
            }
            .onChange(of: selection) { _, new in
                if enabled {
                    let supported = policy.normalized(new, from: nil)
                    if new != supported { selection = supported }
                }
            }
    }
}

struct MarkerSheetContentMeasurement: Equatable {
    let revision: String
    let height: CGFloat
    let width: CGFloat
}
private struct MarkerSheetContentPreference: PreferenceKey {
    static var defaultValue: MarkerSheetContentMeasurement? = nil
    static func reduce(value: inout MarkerSheetContentMeasurement?, nextValue: () -> MarkerSheetContentMeasurement?) {
        value = nextValue() ?? value
    }
}
struct MarkerSheetContentMeasure: ViewModifier {
    let revision: String
    let onMeasure: ((MarkerSheetContentMeasurement) -> Void)?
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(key: MarkerSheetContentPreference.self,
                    value: MarkerSheetContentMeasurement(revision: revision, height: proxy.size.height, width: proxy.size.width))
            }
        }
        .onPreferenceChange(MarkerSheetContentPreference.self) { if let value = $0 { onMeasure?(value) } }
    }
}
/// Reads the presenting container and its window, even when MainView ignores
/// safe areas. Window bounds are specific to this presentation, not UIScreen.
private struct MarkerSheetContainerProbe: UIViewRepresentable {
    let onMeasure: (CGFloat) -> Void
    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onMeasure = onMeasure
        return view
    }
    func updateUIView(_ view: ProbeView, context: Context) { view.onMeasure = onMeasure }

    final class ProbeView: UIView {
        var onMeasure: ((CGFloat) -> Void)?
        private var lastHeight: CGFloat = 0
        override func didMoveToWindow() { super.didMoveToWindow(); reportHeight() }
        override func layoutSubviews() { super.layoutSubviews(); reportHeight() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); reportHeight() }
        private func reportHeight() {
            guard let window else { return }
            let safeHeight = window.bounds.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom
            let height = min(bounds.height, safeHeight)
            guard height > 100, abs(height - lastHeight) > 2 else { return }
            lastHeight = height
            DispatchQueue.main.async { [weak self] in self?.onMeasure?(height) }
        }
    }
}
struct MarkerSheetContainerMeasure: ViewModifier {
    @ObservedObject var model: MarkerSheetPresentationModel
    func body(content: Content) -> some View {
        content.background {
            MarkerSheetContainerProbe(onMeasure: model.setAvailableHeight)
                .ignoresSafeArea(.keyboard)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// The same live panel remains mounted at its previous viewport while docked.
/// Retains optional-field UI and scroll state; owns no draft data.
struct MarkerGuidedRetainedPanel<Panel: View>: View {
    @ObservedObject var placementState: MarkerPlacementState
    let policy: MarkerSheetPresentationPolicy
    @Binding var selection: PresentationDetent
    let panel: Panel
    @State private var retainedSize = CGSize(width: 320, height: 400)
    @State private var retainedSelection: PresentationDetent?
    private var isCompact: Bool { selection == policy.compact }

    init(placementState: MarkerPlacementState, policy: MarkerSheetPresentationPolicy,
         selection: Binding<PresentationDetent>, @ViewBuilder panel: () -> Panel) {
        self.placementState = placementState
        self.policy = policy
        self._selection = selection
        self.panel = panel()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                panel.frame(width: isCompact ? retainedSize.width : proxy.size.width,
                            height: isCompact ? retainedSize.height : proxy.size.height)
                    .opacity(isCompact ? 0 : 1)
                    .allowsHitTesting(!isCompact)
                    .accessibilityHidden(isCompact)
                if isCompact {
                    MarkerGuidedCompactDock(placementState: placementState) {
                        selection = policy.normalized(retainedSelection ?? policy.working, from: policy)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .onAppear {
                if !isCompact { retainedSize = proxy.size; retainedSelection = selection }
            }
            .onChange(of: proxy.size) { _, size in if !isCompact { retainedSize = size } }
            .onChange(of: selection) { _, new in if !isCompact { retainedSelection = new } }
        }
        .clipped()
    }
}
