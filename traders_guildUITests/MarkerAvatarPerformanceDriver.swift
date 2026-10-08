import XCTest

/// v1.5 Stage 5: the same chart work, driven identically, on the baseline and
/// prototype builds of the isolated DEV app on a physical iPhone.
///
/// **Portable and test-only**, like `ChartPanPerformanceDriver`: no feature
/// code, nothing about avatars. The identical file is built into both the
/// baseline (`72b6f2b`) and the prototype, so both halves of a comparison are
/// driven the same way.
///
/// ## A run
///
/// One `xcodebuild test-without-building` invocation runs the tests in name
/// order. Every launch — including the sign-in check — applies the run's
/// launch arguments (`TG_PERF_LAUNCH_ARGS`, space-separated), so the
/// experiment gate is the intended one from the first frame of the run.
///
/// 1. `test0` checks, in the drawer, that the run's disposable local-DEV QA
///    account (`TG_QA_USERNAME`) is the one signed in. It never types
///    credentials (XCTest's redaction of a secure field proved unreliable on
///    the phone): a signed-out app, or one signed in to another local account,
///    fails the run with a request to sign in or out by hand.
/// 2. `test1` measures the **launch and load** as one phase window,
///    `first-launch-and-load`: a fresh process (parked away from the seeded
///    1h chart) opens the seeded parent (`TG_PERF_MARKER_URL`) and settles. It
///    runs outside `measure`, and no test launches the app inside `measure`:
///    - XCTest runs every measure block once more than `iterationCount` and
///      discards the first run, so a cold launch inside `measure` lands in the
///      discarded run;
///    - on the phone, launches inside a `measure` block with the app CPU and
///      memory metrics did not keep the refresh token they were issued (the
///      server's rotation record shows each next launch presenting an older
///      one), and the first launch more than 30 s later was signed out.
///      Every launch outside `measure` kept its token.
///    Measure runs skip `test0`, so this is the first launch after the
///    orchestrator rotates the avatar URLs: **cold** on a cold run, a **fresh
///    process with the URL cache in place** on a warm run. Its evidence is
///    the phase window: the frames pass's trace, the server's avatar
///    requests, the screenshot.
/// 3. `test2` revisits: away to a second parent (`TG_PERF_OTHER_URL`) and
///    back, in the same process — the in-process warm path. (Its measure
///    block also runs twice, so its window holds two revisits.)
/// 4. `test3_…_1…5` and `test4_…_1…5` each measure one fixed out-and-back
///    pan, with the parent's thesis selected, then with nothing selected. A
///    pan does not land where it began (each fling's length varies; on the
///    simulator single pans ended up to 15 of 64 columns either side), and
///    the error adds up from pan to pan until the chart is off the markers.
///    So each test first re-anchors (away to
///    the second parent and back, which re-centres the chart on the parent;
///    `test4` then closes the selection) and only then measures. The anchor
///    stays outside `measure`: XCTest's app CPU metric covers the whole
///    measure block whatever `startMeasuring` says. Each test asserts the
///    selection state, attaches the anchored and the panned view, and checks
///    both against the first anchored view (`TG_DRIFT`): a bounded sideways
///    shift, a clean match, and as much on screen. An anchored view that
///    fails stops the run: the pan would not start on the seeded markers. A
///    panned view that fails is only reported: fling length varies (one
///    simulator pan in about 30 overshot to the latest-candle edge), the
///    next test re-anchors, and the count of such pans is part of the run's
///    summary.
/// 5. `test5` parks the app on BTC/USD away from the seeded 1h chart (opening
///    the seeded parent first, so the symbol tab is there whatever symbol the
///    app was on), so the next run's launch shows none of the seeded markers
///    before its own measured load.
///
/// Each phase prints `TG_PHASE <begin|end> <name> <ISO-8601 UTC>` so server
/// requests and the system trace's frames and hitches can be attributed to
/// phases, and screenshots are attached. XCTest metrics: CPU, memory, clock.
final class MarkerAvatarPerformanceDriver: XCTestCase {

    private static let bundleID = "co.tradersguild.app.linkeddev"
    private static let guildName = "Stage4 QA 658f08"
    /// The navigation bar title while the seeded Analysis parent is selected.
    private static let selectedTitle = "Analysis Marker"

    private var app: XCUIApplication!
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Self.bundleID)
        app.launchArguments = (env["TG_PERF_LAUNCH_ARGS"] ?? "")
            .split(separator: " ").map(String.init)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Helpers

    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func phase(_ edge: String, _ name: String) {
        print("TG_PHASE \(edge) \(name) \(Self.stamp.string(from: Date()))")
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func onChart() -> Bool {
        ["Latest", "Markers", "Today"].contains { app.buttons[$0].exists }
    }

    private func requireChart(timeout: TimeInterval = 20) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if onChart() { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        attachScreenshot("not-on-chart")
        XCTFail("not on the chart")
        throw XCTSkip("unreachable")
    }

    private var selectedTitle: XCUIElement { app.staticTexts[Self.selectedTitle] }

    /// The chart is on screen. Non-throwing, for use inside a measure block.
    private func waitForChart(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if onChart() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    /// The seeded parent is selected: its viewing title is on screen.
    private func requireSelected(timeout: TimeInterval = 15) {
        XCTAssertTrue(selectedTitle.waitForExistence(timeout: timeout),
                      "the seeded parent must be selected (\"\(Self.selectedTitle)\")")
    }

    /// Hands a link to the running app, as tapping it elsewhere would.
    /// Not `app.open(_:)`: that launches a new app process every time (the
    /// pid changed on every link, and the server saw a full app start), so a
    /// "revisit" was really a relaunch and every pan began just after one.
    private func open(_ key: String) {
        guard let link = env[key].flatMap(URL.init(string:)) else {
            XCTFail("\(key) is required")
            return
        }
        XCUIDevice.shared.system.open(link)
        // The system may ask before handing a custom-scheme link to an app.
        let confirm = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if confirm.waitForExistence(timeout: 1) { confirm.tap() }
    }

    /// No `XCTHitchMetric`: on the phone it competes with the run's system
    /// trace for the kernel trace session. With both, the metric read 0 hitches
    /// everywhere and the trace's frame data stopped when the first recorded
    /// measure began. Frames and hitches come from the trace instead
    /// (`hitches_by_phase.py`), for every window, the unmeasured first launch
    /// included.
    private func metrics() -> [XCTMetric] {
        [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()]
    }

    private func once() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        return options
    }

    /// The chart's fling decays by a fixed factor per frame and stops below
    /// 10 pt/s: from this driver's 600 pt/s swipe, about 2.6 s at 60 Hz and
    /// 1.3 s at 120 Hz. Each swipe waits it out, so the next one starts on a
    /// still chart.
    private static let flingSettle: TimeInterval = 3.5

    /// One fixed out-and-back pan, normalised so it is identical on any device.
    /// Older candles first: the newer direction is clipped at the latest-candle
    /// edge, which would leave the return swipe unbalanced.
    private func panPair() {
        let window = app.windows.firstMatch
        let right = window.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.42))
        let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: .init(600), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: Self.flingSettle)
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .init(600), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: Self.flingSettle)
    }

    private static let fingerprintColumns = 64
    private static let fingerprintRows = 48

    /// The chart body (below the header, above the time axis, left of the price
    /// axis) reduced to 64×48 grey levels: enough to tell whether the markers
    /// and branches are in view, not affected by the live price tag.
    private func chartFingerprint() -> [UInt8] {
        guard let image = app.screenshot().image.cgImage else { return [] }
        let body = CGRect(x: 0, y: Double(image.height) * 0.22,
                          width: Double(image.width) * 0.80, height: Double(image.height) * 0.58).integral
        guard let crop = image.cropping(to: body) else { return [] }
        let columns = Self.fingerprintColumns, rows = Self.fingerprintRows
        var grey = [UInt8](repeating: 0, count: columns * rows)
        grey.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: columns, height: rows, bitsPerComponent: 8,
                                          bytesPerRow: columns, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.interpolationQuality = .medium
            context.draw(crop, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        }
        return grey
    }

    /// The horizontal shift (in fingerprint columns) that best lines `view`
    /// up with `reference`, and the mean grey-level difference (0–255) left
    /// at that shift.
    private static func alignedDifference(_ reference: [UInt8], _ view: [UInt8]) -> (shift: Int, residual: Double) {
        let columns = fingerprintColumns, rows = fingerprintRows
        guard reference.count == columns * rows, view.count == reference.count else { return (0, .infinity) }
        var best = (shift: 0, residual: Double.infinity)
        for shift in -searchedShift...searchedShift {
            var total = 0, count = 0
            for row in 0..<rows {
                for column in max(0, -shift)..<min(columns, columns - shift) {
                    total += abs(Int(reference[row * columns + column]) - Int(view[row * columns + column + shift]))
                    count += 1
                }
            }
            let residual = Double(total) / Double(count)
            if residual < best.residual { best = (shift, residual) }
        }
        return best
    }

    /// How much is on screen: the standard deviation of the grey levels. The
    /// seeded view scores 16–24; the empty stretch the old pans drifted to,
    /// 1–4.
    private static func spread(_ fingerprint: [UInt8]) -> Double {
        guard !fingerprint.isEmpty else { return 0 }
        let mean = fingerprint.reduce(0.0) { $0 + Double($1) } / Double(fingerprint.count)
        let variance = fingerprint.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(fingerprint.count)
        return variance.squareRoot()
    }

    /// Up to 20 of 64 columns of sideways shift (a quarter of the chart: the
    /// simulator's single pans ended within 15, with the thesis and its
    /// branches in full view); a residual that only the same markers can
    /// reach; and at least 60% of the reference's spread.
    private static let searchedShift = 24
    private static let maximumShift = 20
    private static let maximumResidual = 10.0
    private static let minimumSpreadRatio = 0.6

    /// Logs a view against the first anchored view of the test and, when
    /// `enforced`, fails the test if it is not the seeded view.
    private func checkOnSeededView(_ view: [UInt8], reference: [UInt8], label: String, enforced: Bool) {
        let match = Self.alignedDifference(reference, view)
        let spreadRatio = Self.spread(view) / max(Self.spread(reference), 1)
        let onSeededView = abs(match.shift) <= Self.maximumShift && match.residual < Self.maximumResidual
            && spreadRatio >= Self.minimumSpreadRatio
        print("TG_DRIFT \(label) shift=\(match.shift) residual=\(String(format: "%.2f", match.residual)) spread=\(String(format: "%.2f", spreadRatio)) seeded=\(onSeededView)")
        guard enforced else { return }
        XCTAssertLessThanOrEqual(abs(match.shift), Self.maximumShift, "\(label): off the seeded markers")
        XCTAssertLessThan(match.residual, Self.maximumResidual, "\(label): not the seeded view")
        XCTAssertGreaterThanOrEqual(spreadRatio, Self.minimumSpreadRatio, "\(label): the markers are not on screen")
    }

    /// Re-centres the chart on the seeded parent: away to the second parent
    /// and back. On the simulator every anchored view matched the first to
    /// 0.35 grey levels with no shift, so every pan starts from the same view.
    private func anchorOnSeededParent(selected: Bool) {
        open("TG_PERF_OTHER_URL")
        Thread.sleep(forTimeInterval: 3)
        open("TG_PERF_MARKER_URL")
        requireSelected()
        Thread.sleep(forTimeInterval: 3)
        guard !selected else { return }
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "the selection's Close control")
        close.tap()
        // The deselect can take a moment (seen on the phone): wait for it.
        let deselected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: selectedTitle)
        XCTAssertEqual(XCTWaiter().wait(for: [deselected], timeout: 5), .completed, "nothing may be selected")
        Thread.sleep(forTimeInterval: 1)
    }

    /// The first anchored view of each state; every later view is checked
    /// against it. Static, because XCTest makes a new instance per test.
    private static var references: [String: [UInt8]] = [:]

    /// One measured pan from the anchored parent. The anchor runs before
    /// `measure`, not inside it with `startMeasuring`: the app CPU metric
    /// spans the whole block (an idle 8 s window measured straight after an
    /// anchor reported 10.8 s of CPU, the same window 12 s later 14.1 s).
    /// XCTest runs the block once more than `iterationCount` and discards the
    /// first run; that run stays still, so the recorded pan is the single pan
    /// from the anchor (a second pan would start wherever the first ended).
    private func measurePan(_ name: String, selected: Bool, index: Int) throws {
        app.activate()
        try requireChart()
        phase("begin", "\(name)-anchor")
        anchorOnSeededParent(selected: selected)
        phase("end", "\(name)-anchor")
        let anchored = chartFingerprint()
        let reference = Self.references[name] ?? anchored
        Self.references[name] = reference
        attachScreenshot("\(name)-\(index)-anchored")
        checkOnSeededView(anchored, reference: reference, label: "\(name) iteration=\(index) anchored", enforced: true)
        phase("begin", name)
        var runs = 0
        measure(metrics: metrics(), options: once()) {
            runs += 1
            guard runs > 1 else { return }  // XCTest's discarded first run
            panPair()
        }
        phase("end", name)
        XCTAssertEqual(runs, 2, "XCTest's discarded first run, then the recorded pan")
        attachScreenshot("\(name)-\(index)-panned")
        checkOnSeededView(chartFingerprint(), reference: reference, label: "\(name) iteration=\(index) panned", enforced: false)
        XCTAssertEqual(selectedTitle.exists, selected, selected ? "the thesis stays selected" : "nothing may be selected")
    }

    // MARK: 0 — sign-in, with the run's gate

    /// The left drawer's account card ("@username, Owner, …"). Only an
    /// on-screen one counts: the right drawer waits off-screen with its own.
    private func drawerAccountCard(timeout: TimeInterval = 10) -> XCUIElement? {
        let width = app.windows.firstMatch.frame.width
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "@"))
                .allElementsBoundByIndex
                .first { $0.frame.minX >= 0 && $0.frame.maxX <= width && $0.isHittable }
            if let card { return card }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    /// Opens the left drawer and reports whether its account card shows the
    /// run's account. Leaves the drawer open.
    private func drawerShowsRunAccount(_ username: String) throws -> Bool {
        // A selected marker replaces the drawer control with its Close.
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        let drawer = app.buttons["shield.pattern.checkered"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 10), "the guild drawer control")
        // Straight after sign-in the drawer can ignore a tap while the guild
        // loads (seen on the phone), so tap again if it has not opened.
        var card: XCUIElement?
        for _ in 0..<3 where card == nil {
            if drawer.isHittable { drawer.tap() }
            card = drawerAccountCard(timeout: 6)
        }
        guard let card else {
            attachScreenshot("0-drawer-without-account")
            XCTFail("the drawer's account card")
            return false
        }
        attachScreenshot("0-drawer-account")
        return card.label == "@\(username)" || card.label.hasPrefix("@\(username),")
    }

    func test0_signInIfNeeded() throws {
        phase("begin", "launch-signin-check")
        defer { phase("end", "launch-signin-check") }
        guard let username = env["TG_QA_USERNAME"] else {
            XCTFail("TG_QA_USERNAME is required")
            return
        }
        app.launch()
        // The welcome screen shows until session restore finishes, which on
        // the phone's first launch after an install can take several
        // seconds: only a sign-in screen that stays without the chart means
        // signed out.
        let deadline = Date().addingTimeInterval(30)
        while !onChart() && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        if onChart() {
            try requireChart(timeout: 30)
            // Another local account would see none of the seeded fixtures.
            // Logging out is left to a person (Settings → Logout): that list
            // also holds Delete Account, which automation must never risk.
            XCTAssertTrue(try drawerShowsRunAccount(username),
                          "the app is signed in to another account: log out of TG LinkedDev (Settings → Logout), then rerun")
            app.terminate()  // leave the drawer behind
            app.launch()
            try requireChart(timeout: 30)
            attachScreenshot("0-signed-in-launch")
            return
        }
        // The driver never types credentials: XCTest's log redaction of a
        // secure field proved unreliable on the phone (the password appeared
        // in the console log of one run). Sign the run's account in by hand.
        XCTFail("the app is signed out: sign in as @\(username) by hand, then rerun")
        return
    }

    // MARK: 1 — load: one launch (cold on a cold run, fresh-process warm on a warm run)

    func test1_launchAndLoadSeededThesis() throws {
        app.terminate()
        phase("begin", "first-launch-and-load")
        app.launch()  // parked away from the seeded chart
        XCTAssertTrue(waitForChart(timeout: 30), "the parked chart")
        XCTAssertFalse(selectedTitle.exists, "the run starts with nothing selected")
        Thread.sleep(forTimeInterval: 3)  // launch-time member and avatar loading
        open("TG_PERF_MARKER_URL")
        requireSelected()
        Thread.sleep(forTimeInterval: 6)  // markers, faces and thesis settle
        phase("end", "first-launch-and-load")
        attachScreenshot("1-first-load-selected")
    }

    // MARK: 2 — in-process revisit

    func test2_revisitInProcess() throws {
        app.activate()
        requireSelected()
        phase("begin", "revisit-in-process")
        measure(metrics: metrics(), options: once()) {
            open("TG_PERF_OTHER_URL")
            Thread.sleep(forTimeInterval: 4)
            open("TG_PERF_MARKER_URL")
            requireSelected()
            Thread.sleep(forTimeInterval: 4)
        }
        phase("end", "revisit-in-process")
        attachScreenshot("2-revisited-selected")
    }

    // MARK: 3, 4 — pans

    func test3_pansWithSelectedThesis_1() throws { try measurePan("pans-selected-thesis", selected: true, index: 1) }
    func test3_pansWithSelectedThesis_2() throws { try measurePan("pans-selected-thesis", selected: true, index: 2) }
    func test3_pansWithSelectedThesis_3() throws { try measurePan("pans-selected-thesis", selected: true, index: 3) }
    func test3_pansWithSelectedThesis_4() throws { try measurePan("pans-selected-thesis", selected: true, index: 4) }
    func test3_pansWithSelectedThesis_5() throws { try measurePan("pans-selected-thesis", selected: true, index: 5) }

    func test4_pansUnselected_1() throws { try measurePan("pans-unselected", selected: false, index: 1) }
    func test4_pansUnselected_2() throws { try measurePan("pans-unselected", selected: false, index: 2) }
    func test4_pansUnselected_3() throws { try measurePan("pans-unselected", selected: false, index: 3) }
    func test4_pansUnselected_4() throws { try measurePan("pans-unselected", selected: false, index: 4) }
    func test4_pansUnselected_5() throws { try measurePan("pans-unselected", selected: false, index: 5) }

    // MARK: 5 — park for the next run

    func test5_parkOnMarkerFreeTimeframe() throws {
        app.activate()
        try requireChart()
        open("TG_PERF_MARKER_URL")  // onto BTC/USD, whatever symbol the app was on
        requireSelected()
        Thread.sleep(forTimeInterval: 2)
        let close = app.buttons["Close"]  // the symbol tab only shows with nothing selected
        XCTAssertTrue(close.waitForExistence(timeout: 5), "the selection's Close control")
        close.tap()
        Thread.sleep(forTimeInterval: 1)
        let symbolTab = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "BTC/USD")).firstMatch
        XCTAssertTrue(symbolTab.waitForExistence(timeout: 5))
        symbolTab.tap()
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        let thirty = app.buttons["30m"]
        XCTAssertTrue(thirty.waitForExistence(timeout: 5), "the 30m timeframe control")
        thirty.tap()
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot("5-parked")
    }
}
