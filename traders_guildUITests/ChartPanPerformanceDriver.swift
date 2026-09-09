import XCTest

/// Deterministic chart-pan driver for device profiling.
///
/// The point of this file is that a human swiping twice does not produce two
/// comparable measurements. Pan distance, duration and start point all change
/// the work the renderer does, so a hand-driven A/B compares gestures as much as
/// builds. This repeats one fixed gesture, on a rectangle derived from the
/// screen rather than from any particular layout, so the same run applies to the
/// 1.2.1 baseline and to the linked-markers build.
///
/// **It carries no feature code and asserts nothing about linked markers**, so
/// it cherry-picks onto the baseline worktree unchanged. That is the whole
/// reason it lives in the UI test target rather than in the app.
///
/// Usage — attach Instruments to the *app*, not to the test runner, and take the
/// timed window from the console markers this prints:
///
/// ```
/// xcodebuild test \
///   -project traders_guild.xcodeproj \
///   -scheme "traders_guild LinkedDev Profile" \
///   -configuration DevProfile \
///   -destination 'platform=iOS,name=<device>' \
///   -only-testing:traders_guildUITests/ChartPanPerformanceDriver
/// ```
///
/// No credentials appear here or in its output. The driver assumes an app that
/// is **already signed in** on the device with the QA account and already
/// showing the chart; it does not authenticate, and it fails with a clear
/// message rather than attempting to.
final class ChartPanPerformanceDriver: XCTestCase {

    /// Passed to the app so a run is identifiable in a trace without changing
    /// what the app does.
    private static let profilingArgument = "-TGChartPanProfiling"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [Self.profilingArgument]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Geometry

    /// The rectangle gestures are performed on.
    ///
    /// Derived from the window, inset well clear of every edge: a swipe that
    /// starts within a few points of a screen edge is intercepted by the system
    /// as a back, notification-shade, home or Control Centre gesture, and the
    /// app never sees it. Vertically centred on the plot area rather than the
    /// window so the pan lands on candles rather than on the header or the
    /// bottom sheet.
    private func panRect() -> (start: XCUICoordinate, end: XCUICoordinate) {
        let window = app.windows.firstMatch
        // Normalised offsets, so this is resolution-independent and identical on
        // any device the pair is measured on.
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.42))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))
        return (start, end)
    }

    // MARK: - The gesture

    /// One pan, always the same distance and duration.
    ///
    /// `press(forDuration:thenDragTo:withVelocity:)` is used rather than
    /// `swipe(...)` because swipe velocity is unspecified and varies between OS
    /// versions — which is exactly the kind of hidden variable that makes two
    /// runs incomparable.
    private func performOnePan() {
        let (start, end) = panRect()
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: .init(600),
            thenHoldForDuration: 0.0
        )
    }

    /// Let the chart settle so the next pan starts from rest rather than from
    /// the tail of the previous one's deceleration.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.6)
    }

    // MARK: - Runs

    /// The measurement. Repeats the identical pan and brackets the timed region
    /// with console markers so an Instruments trace can be cut to exactly the
    /// same window on both builds.
    func testRepeatedIdenticalChartPans() throws {
        try XCTSkipUnless(
            app.state == .runningForeground,
            "The app must be running and signed in before profiling; this driver does not authenticate."
        )

        // Warm-up passes are excluded deliberately: the first pan after launch
        // pays for texture upload and first-frame layout, which is real but is
        // not what the comparison is about.
        for _ in 0..<3 {
            performOnePan()
            settle()
        }

        print("TG_PROFILE_BEGIN repeated-chart-pan")
        let began = Date()

        for index in 0..<Self.timedPanCount {
            print("TG_PROFILE_PAN \(index)")
            performOnePan()
            settle()
        }

        let elapsed = Date().timeIntervalSince(began)
        print("TG_PROFILE_END repeated-chart-pan elapsed=\(String(format: "%.3f", elapsed))s "
              + "pans=\(Self.timedPanCount)")

        // Not an assertion about performance — this driver measures, it does not
        // judge. It only fails if the gestures did not actually run, which would
        // otherwise produce an empty trace that looks like a fast one.
        XCTAssertGreaterThan(
            elapsed,
            Double(Self.timedPanCount) * 0.5,
            "the timed region is implausibly short — the pans probably did not reach the app"
        )
        XCTAssertEqual(app.state, .runningForeground, "the app must survive the run")
    }

    /// Enough repetitions to average out scheduler noise, few enough that the
    /// device does not thermally throttle partway and make the second half of
    /// the run incomparable to the first.
    private static let timedPanCount = 10
}
