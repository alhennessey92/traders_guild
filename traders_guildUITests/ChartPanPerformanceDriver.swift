import XCTest

/// Deterministic chart-pan driver for device profiling.
///
/// A person swiping twice does not produce two comparable measurements: pan
/// distance, start point and velocity all change how much the renderer does, so
/// a hand-driven A/B compares gestures as much as builds. This repeats one fixed
/// gesture pair on a normalised rectangle.
///
/// **Portable and test-only.** It contains no feature code and asserts nothing
/// about linked markers, so it cherry-picks onto the 1.2.1 baseline worktree
/// unchanged — which is the point, since a matched pair is only matched if both
/// halves are driven identically.
///
/// ## What it does *not* do
///
/// It does not launch the app. `launch()` relaunches, which throws away the
/// prepared chart position, the selected marker and any active thesis focus —
/// the very state the measurement is supposed to be about. It `activate()`s an
/// already-running, already-prepared app instead.
///
/// It does not decide whether performance is good. Frame timings come from
/// Instruments attached to the app; this only guarantees the gestures are
/// identical and tells the trace where to cut.
///
/// ## Preparing the device before a run
///
/// 1. Install and launch `co.tradersguild.app.linkeddev` (`DevProfile`), sign in
///    with the QA account, and open the guild, symbol and timeframe carrying the
///    dense seeded fixture.
/// 2. Put the chart where the measurement should happen — the markers visible,
///    and a thesis selected if focus is being measured. The driver preserves
///    whatever is on screen.
/// 3. Attach Instruments to the **app**, not to the test runner.
/// 4. Leave the app in the foreground. Do not attach a debugger: the
///    `LinkedDev Profile` scheme's Run action launches without one, which is why
///    it exists.
///
/// ## Running it
///
/// ```
/// xcodebuild test-without-building \
///   -project traders_guild.xcodeproj \
///   -scheme "traders_guild LinkedDev Profile" \
///   -configuration DevProfile \
///   -destination 'platform=iOS,name=<device name>' \
///   -only-testing:traders_guildUITests/ChartPanPerformanceDriver
/// ```
///
/// Build once first with `build-for-testing` and the same arguments. The scheme
/// includes this UI-test target in its test action; a scheme that lists only the
/// unit-test target cannot run this, and the command above will report that it
/// matched nothing.
///
/// Then cut the Instruments trace between the `TG_PROFILE_BEGIN` and
/// `TG_PROFILE_END` markers this prints, and compare the two builds over the
/// same number of pans.
final class ChartPanPerformanceDriver: XCTestCase {

    /// Explicit, so this drives the isolated build rather than whatever the test
    /// target happens to host. The two are different apps with different bundle
    /// ids, and picking the wrong one silently measures the wrong binary.
    private static let isolatedBundleID = "co.tradersguild.app.linkeddev"

    /// Enough repetitions to average out scheduler noise, few enough that the
    /// device does not thermally throttle partway and make the second half of
    /// the run incomparable to the first. Each is an out-and-back pair.
    private static let timedPanPairs = 10
    private static let warmUpPanPairs = 3

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Self.isolatedBundleID)

        // Activate, never launch. `launch()` would relaunch and discard the
        // prepared chart, which is the whole subject of the measurement.
        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 15),
            "\(Self.isolatedBundleID) must already be installed, running and prepared. "
                + "This driver activates it; it deliberately does not launch it."
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Proving we are actually on the chart

    /// Controls that exist on the chart and nowhere else in the app.
    ///
    /// Running foreground is not enough: the login screen, the guild picker and
    /// a loading spinner are all "foreground", and a run that panned an empty
    /// login view would produce a clean, fast, meaningless trace.
    private func chartControl() -> XCUIElement? {
        for label in ["Latest", "Markers", "Today"] {
            let button = app.buttons[label]
            if button.exists { return button }
            let text = app.staticTexts[label]
            if text.exists { return text }
        }
        return nil
    }

    private func requireChart() throws {
        guard let control = chartControl() else {
            let names = app.buttons.allElementsBoundByAccessibilityElement
                .map(\.label).filter { !$0.isEmpty }.prefix(12)
            XCTFail(
                "No chart control found, so this is not the chart — refusing to "
                    + "record a meaningless trace. Visible buttons: \(Array(names)). "
                    + "Prepare the app on the chart before running."
            )
            throw XCTSkip("unreachable; XCTFail above stops the run")
        }
        XCTAssertTrue(control.exists)
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - The gesture

    /// One pan out and back, always the same distance and duration.
    ///
    /// Out-and-back rather than one-directional on purpose. Ten pans all in the
    /// same direction walk the viewport off the seeded fixture, so the later
    /// repetitions render an empty chart and measure less work than the earlier
    /// ones — which shows up as a build getting faster over the run. Returning
    /// to the start keeps every repetition over the same dense markers.
    ///
    /// `press(forDuration:thenDragTo:withVelocity:)` rather than `swipe`, whose
    /// velocity is unspecified and varies between OS versions.
    private func performOnePanPair() {
        let window = app.windows.firstMatch
        // Normalised, so identical on any device the pair is measured on, and
        // well clear of every edge: a drag starting within a few points of one
        // is claimed by the system as back, Control Centre or the home gesture.
        let right = window.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.42))
        let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))

        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .init(600), thenHoldForDuration: 0)
        settle()
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .init(600), thenHoldForDuration: 0)
        settle()
    }

    /// Let the chart come to rest, so the next pan starts from a stop rather
    /// than from the tail of the previous one's deceleration.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.6)
    }

    // MARK: - The run

    func testRepeatedIdenticalChartPans() throws {
        try requireChart()
        attachScreenshot(named: "before-pans")

        // Warm-up is excluded deliberately: the first pans after activation pay
        // for texture upload and first-frame layout, which is real but is not
        // what the comparison is about. Paired, like the timed ones, so warm-up
        // leaves the viewport where it started.
        for _ in 0..<Self.warmUpPanPairs {
            performOnePanPair()
        }

        print("TG_PROFILE_BEGIN repeated-chart-pan pairs=\(Self.timedPanPairs)")
        for index in 0..<Self.timedPanPairs {
            print("TG_PROFILE_PAIR \(index)")
            performOnePanPair()
        }
        print("TG_PROFILE_END repeated-chart-pan")

        attachScreenshot(named: "after-pans")

        // Deliberately not asserting on elapsed time. Wall clock here is
        // dominated by this driver's own `settle()` sleeps, so an elapsed-time
        // check passes whether or not a single gesture reached the chart — it
        // would be asserting that sleeping works. Frame timings come from
        // Instruments; what this test owes the measurement is that the app is
        // still on the chart afterwards, which is evidence the gestures went
        // somewhere real rather than dismissing a sheet or backgrounding it.
        XCTAssertEqual(
            app.state, .runningForeground,
            "the app must survive the run; if it backgrounded, a gesture hit a system edge"
        )
        try requireChart()
    }
}
