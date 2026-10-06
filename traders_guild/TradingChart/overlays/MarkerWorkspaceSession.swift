import SwiftUI

/// The workspace's own state: the screens the author has opened, in order,
/// and what they have half done there (staged editor values, cursor, scroll).
///
/// It lives apart from the draft. `MarkerPlacementState` publishes to the
/// chart, so anything written there redraws it; moving between screens,
/// moving the cursor, scrolling and typing an indicator's period are not
/// draft edits and are published here instead. The session has the draft's
/// lifetime: `prepareGuidedFlow`, `prepareGuidedEdit` and `endGuidedFlow`
/// replace its state with a fresh one.
@MainActor
final class MarkerWorkspaceSession: ObservableObject {
    @Published var state = MarkerWorkspaceState()
}

/// Redraws its content when the workspace session changes. A view that reads
/// `placementState.workspace`, or anything derived from it (the destination,
/// `guidedStep`, the next-step prompt), wraps its body in this. The draft no
/// longer announces those changes, and the chart must not hear them.
struct MarkerWorkspaceObserving<Content: View>: View {
    @ObservedObject var session: MarkerWorkspaceSession
    @ViewBuilder var content: () -> Content

    var body: some View { content() }
}
