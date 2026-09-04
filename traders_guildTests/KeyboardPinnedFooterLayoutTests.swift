import Foundation
import SwiftUI
import Testing
import UIKit
@testable import traders_guild

/// Where `keyboardPinnedBottomInset` actually puts its footer.
///
/// The reported symptom was the create-guild form clipping at the bottom when
/// it is at its tallest (private guild, three join questions). Reading the
/// source could not settle it, because it turns on a `GeometryReader` question:
/// does the reader's own frame already exclude the home-indicator inset, or
/// does it span the window and merely *report* it?
///
/// Measured, in a real `UIWindow` with a real safe area, it was the former —
/// `reader=(0, 54, 393, 764)` in an 852pt window with a 34pt bottom inset. Two
/// bugs followed, and these tests pin both fixes. Probes are
/// `UIViewRepresentable`s carrying tags, so the frames come from UIKit rather
/// than from preferences, which would need the run loop pumped.
@MainActor
struct KeyboardPinnedFooterLayoutTests {

    private enum Tag {
        static let footer = 7102
        static let reader = 7103
        static let reportedInset = 7104
    }

    private static let footerContentHeight: CGFloat = 60
    private static let windowSize = CGSize(width: 393, height: 852)
    private static let bottomSafeArea: CGFloat = 34

    private struct TaggedProbe: UIViewRepresentable {
        let tag: Int
        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.tag = tag
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            return view
        }
        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    /// Hosts `view` in a window with a notched phone's bottom inset and lays it
    /// out. The inset is forced rather than inherited so the numbers below hold
    /// on any simulator.
    private func layOut<V: View>(_ view: V) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.windowSize))
        let host = UIHostingController(rootView: view)
        host.additionalSafeAreaInsets = UIEdgeInsets(
            top: 0, left: 0, bottom: Self.bottomSafeArea, right: 0
        )
        window.rootViewController = host
        window.isHidden = false
        window.layoutIfNeeded()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return window
    }

    private func frame(of tag: Int, in window: UIWindow) throws -> CGRect {
        let probe = try #require(window.viewWithTag(tag), "probe \(tag) was not laid out")
        return probe.convert(probe.bounds, to: window)
    }

    // MARK: - The footer's position

    private struct FooterHarness: View {
        var body: some View {
            Color.clear
                .keyboardPinnedBottomInset {
                    Color.clear
                        .frame(height: KeyboardPinnedFooterLayoutTests.footerContentHeight)
                        .background(TaggedProbe(tag: Tag.footer))
                }
        }
    }

    /// The footer rests on the home indicator rather than floating above it.
    ///
    /// `footerBottomPadding` is the home-indicator inset. Applied inside a
    /// container that had already been inset by the same amount, it was counted
    /// twice: the button hovered 68pt off the bottom of an 852pt screen with
    /// the sheet colour showing beneath it, and the content lost the same 34pt.
    @Test
    func footerRestsOnTheHomeIndicatorRatherThanFloatingAboveIt() throws {
        let window = layOut(FooterHarness())
        let footer = try frame(of: Tag.footer, in: window)
        let gap = window.bounds.maxY - footer.maxY

        #expect(
            abs(gap - Self.bottomSafeArea) < 1,
            """
            Footer bottom is \(gap)pt above the window bottom; expected \
            \(Self.bottomSafeArea), the home-indicator inset. A larger gap \
            means the inset is being applied twice.
            """
        )
    }

    // MARK: - The keyboard signal

    /// A keyboard notification yields the height it covers.
    ///
    /// This replaced `proxy.safeAreaInsets.bottom`, which the container tests
    /// above showed always answers 0 once the reader spans the container: a
    /// view that ignores a safe area is handed the region and told the inset is
    /// zero. The branch that lifts the content clear of the keyboard was
    /// therefore unreachable, whatever the two `resolve` tests suggested.
    @Test
    func keyboardNotificationReportsTheCoveredHeight() {
        let screen = UIScreen.main.bounds
        let covered: CGFloat = 336
        let note = Notification(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: CGRect(
                    x: 0,
                    y: screen.height - covered,
                    width: screen.width,
                    height: covered
                )
            ]
        )

        #expect(
            KeyboardPinnedBottomInsetWindowInsets.keyboardInset(from: note) == covered
        )
    }

    /// A keyboard leaving the screen is zero, not a negative inset.
    @Test
    func keyboardNotificationClampsAnOffScreenFrameToZero() {
        let screen = UIScreen.main.bounds
        let note = Notification(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: CGRect(
                    x: 0, y: screen.height, width: screen.width, height: 336
                )
            ]
        )

        #expect(KeyboardPinnedBottomInsetWindowInsets.keyboardInset(from: note) == 0)
    }

    /// …and the resolved layout actually switches on it.
    @Test
    func standardFooterDropsItsInsetAndLiftsContentWhileTheKeyboardIsUp() {
        let down = KeyboardPinnedFooterLayout.resolve(
            mode: .standard,
            geometryBottomInset: 34,
            hardwareBottomInset: 34
        )
        #expect(down.footerBottomPadding == 34)
        #expect(down.contentBottomPadding == 0)

        let up = KeyboardPinnedFooterLayout.resolve(
            mode: .standard,
            geometryBottomInset: 336,
            hardwareBottomInset: 34
        )
        #expect(up.footerBottomPadding == 0)
        #expect(up.contentBottomPadding == 20)
    }

    // MARK: - What the container reports

    private struct ReaderHarness: View {
        var body: some View {
            Color.clear
                .keyboardPinnedBottomInset { EmptyView() }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .background(TaggedProbe(tag: Tag.reader))
                            .overlay(alignment: .bottom) {
                                // Height *is* the measurement: whatever the
                                // proxy reports as the bottom inset.
                                Color.clear
                                    .frame(height: max(proxy.safeAreaInsets.bottom, 0))
                                    .background(TaggedProbe(tag: Tag.reportedInset))
                            }
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                )
        }
    }

    /// The container reaches the screen edge and reports the inset it spans.
    ///
    /// This is what makes the keyboard branch reachable at all. While the
    /// reader was laid out inside the safe area it reported a bottom inset of
    /// zero, so `keyboardVisible` — `geometryBottomInset > hardwareInset + 1` —
    /// was false whether or not a keyboard was up, and a form at its tallest
    /// ran its last field under the pinned footer.
    @Test
    func containerSpansToTheScreenEdgeAndReportsItsInset() throws {
        let window = layOut(ReaderHarness())
        let reader = try frame(of: Tag.reader, in: window)
        let reported = try frame(of: Tag.reportedInset, in: window)

        #expect(
            abs(reader.maxY - window.bounds.maxY) < 1,
            "Container stops \(window.bounds.maxY - reader.maxY)pt short of the screen."
        )
        // And it reports *zero* while doing so — which is exactly why the
        // keyboard height comes from a notification rather than this proxy.
        #expect(
            reported.height < 1,
            """
            Container reports a bottom inset of \(reported.height). If this \
            ever becomes non-zero, `keyboardInset` could read the proxy again.
            """
        )
    }
}
