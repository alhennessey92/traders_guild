import XCTest

/// v1.5 Stage 5: the same chart work, driven identically, on the baseline and
/// prototype builds of the isolated DEV app on a physical iPhone.
///
/// **Portable and test-only**, like `ChartPanPerformanceDriver`: no feature
/// code, nothing about avatars. The identical file is built into both the
/// baseline (`72b6f2b`) and the prototype, so the two halves of a comparison
/// are driven the same way. It measures hitches (`XCTHitchMetric`, iOS 26),
/// CPU, memory and wall clock with XCTest metrics, and prints `TG_PROFILE_*`
/// markers for any Instruments trace recorded beside it.
///
/// ## A run
///
/// One `xcodebuild test-without-building` invocation runs all three tests in
/// order. `test1` launches the app with the run's launch arguments
/// (`TG_PERF_LAUNCH_ARGS`, space-separated) and opens
/// `TG_PERF_MARKER_URL` (`tradersguild-linkeddev://marker/<id>`), which
/// navigates to a seeded parent marker with responses; `test2` reuses that
/// app. Pass both as `TEST_RUNNER_…` environment variables.
///
/// `test0` signs a disposable local-DEV QA account in
/// when the app is on the sign-in screen, reading the account from
/// `TG_QA_EMAIL` / `TG_QA_PASSWORD` (pass them as `TEST_RUNNER_…` to
/// `xcodebuild`). The password is placed on the pasteboard and pasted, so it
/// is never typed into the activity log, and the pasteboard is cleared after.
final class MarkerAvatarPerformanceDriver: XCTestCase {

    private static let bundleID = "co.tradersguild.app.linkeddev"
    private static let guildName = "Stage4 QA 658f08"
    private static let iterations = 5
    private static let pansPerIteration = 2

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Self.bundleID)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Helpers

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func chartControl() -> XCUIElement? {
        for label in ["Latest", "Markers", "Today"] {
            let button = app.buttons[label]
            if button.exists { return button }
        }
        return nil
    }

    private func requireChart(timeout: TimeInterval = 20) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if chartControl() != nil { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        attachScreenshot("not-on-chart")
        XCTFail("not on the chart; prepare the app before running")
        throw XCTSkip("unreachable")
    }

    /// One fixed out-and-back pan, normalised so it is identical on any device.
    private func panPair() {
        let window = app.windows.firstMatch
        let right = window.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.42))
        let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .init(600), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.6)
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .init(600), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func measurePans(_ phase: String) {
        let options = XCTMeasureOptions()
        options.iterationCount = Self.iterations
        print("TG_PROFILE_BEGIN \(phase)")
        var metrics: [XCTMetric] = [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()]
        if #available(iOS 26.0, *) {
            metrics.insert(XCTHitchMetric(application: app), at: 0)
        }
        measure(metrics: metrics, options: options) {
            for _ in 0..<Self.pansPerIteration { panPair() }
        }
        print("TG_PROFILE_END \(phase)")
    }

    // MARK: Sign-in (once per install)

    func test0_signInIfNeeded() throws {
        app.launch()
        let emailEntry = app.buttons["Sign in with Email"]
        guard emailEntry.waitForExistence(timeout: 8) else {
            attachScreenshot("already-signed-in")
            return
        }
        let env = ProcessInfo.processInfo.environment
        guard let email = env["TG_QA_EMAIL"], let password = env["TG_QA_PASSWORD"] else {
            XCTFail("TG_QA_EMAIL / TG_QA_PASSWORD are required to sign in")
            return
        }
        emailEntry.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(email)
        let secure = app.secureTextFields.firstMatch
        XCTAssertTrue(secure.exists)
        UIPasteboard.general.string = password
        secure.tap()
        secure.press(forDuration: 1.0)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        UIPasteboard.general.string = ""
        app.buttons["Sign In"].tap()
        let enter = app.buttons["Enter \(Self.guildName)"]
        if enter.waitForExistence(timeout: 15) { enter.tap() }
        try requireChart(timeout: 30)
        attachScreenshot("signed-in")
    }

    // MARK: Measurements

    /// The app was launched onto a seeded parent: selected, with its thesis
    /// (responses, connectors, rings) on screen.
    func test1_pansWithSelectedThesis() throws {
        let env = ProcessInfo.processInfo.environment
        app.launchArguments = (env["TG_PERF_LAUNCH_ARGS"] ?? "")
            .split(separator: " ").map(String.init)
        app.launch()
        try requireChart(timeout: 30)
        if let link = env["TG_PERF_MARKER_URL"].flatMap(URL.init(string:)) {
            app.open(link)
        }
        // Navigation, candle and marker load, avatar loads.
        Thread.sleep(forTimeInterval: 8)
        try requireChart()
        attachScreenshot("selected-before")
        for _ in 0..<2 { panPair() }  // warm-up, excluded
        measurePans("pans-selected-thesis")
        attachScreenshot("selected-after")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// The same region with nothing selected.
    func test2_pansUnselected() throws {
        app.activate()
        try requireChart()
        let close = app.buttons["Close"]
        if close.exists { close.tap(); Thread.sleep(forTimeInterval: 1.0) }
        attachScreenshot("unselected-before")
        for _ in 0..<2 { panPair() }
        measurePans("pans-unselected")
        attachScreenshot("unselected-after")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
