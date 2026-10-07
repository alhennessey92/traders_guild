import XCTest

/// P1 evidence on the real MainView chart sheet (fixture draft, no account or
/// backend). Every display frame the app records the sheet's top edge, the
/// presenting controller's identity, the selected detent, the workspace screen
/// and whether the collapsed bar is showing (`-MarkerSheetTrace`). Ordinary
/// navigation must leave the sheet exactly where it is: no movement, no new
/// controller (a re-presentation), no dismissal, no dock.
final class MarkerWorkspaceShellUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }

    private struct Trace: Decodable {
        let now: Double
        /// How many times the chart's and MainView's bodies have run.
        var chartRenders: Int? = nil
        var shellRenders: Int? = nil
        let samples: [Sample]
    }
    private struct Sample: Decodable {
        let t: Double
        let top: Int
        let ctl: Int
        let sel: String
        let route: String
        let mode: String
        let dock: Bool
        let chart: Int
    }

    private func launch(setup: Bool = false, filledNote: Bool = true) {
        app = XCUIApplication()
        var arguments = ["-MarkerMainViewSheetFixture", "-TGAvatarMarkersExperiment", "YES", "-MarkerSheetTrace"]
        if setup { arguments.append("-MarkerMainViewSetupFixture") }
        if filledNote { arguments.append("-MarkerMainViewFilledNote") }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["mainFixture.geometry"].waitForExistence(timeout: 20))
        settle(1.2)
    }

    private func settle(_ seconds: TimeInterval = 0.9) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private func trace() -> Trace {
        let element = app.descendants(matching: .any)["sheetTrace"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let json = element.value as? String ?? "{}"
        guard let data = json.data(using: .utf8), let trace = try? JSONDecoder().decode(Trace.self, from: data) else {
            XCTFail("unreadable trace: \(json.prefix(200))")
            return Trace(now: 0, samples: [])
        }
        return trace
    }

    /// Samples from just before `mark` until now.
    private func segment(since mark: Double, _ name: String) -> [Sample] {
        let all = trace()
        let attachment = XCTAttachment(string: (app.descendants(matching: .any)["sheetTrace"].value as? String) ?? "")
        attachment.name = "trace-\(name).json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let before = all.samples.last { $0.t < mark }
        return (before.map { [$0] } ?? []) + all.samples.filter { $0.t >= mark }
    }

    private func screenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Brings a control on screen before a measured segment, as a user
    /// would: raise the sheet by its grabber, then scroll.
    private func reveal(_ id: String) {
        let button = app.buttons[id]
        app.revealInMarkerWorkspace(button)
        XCTAssertTrue(button.isHittable, "\(id) revealed")
        settle(0.6)
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id, file: file, line: line)
        XCTAssertTrue(button.isHittable, "\(id) hittable", file: file, line: line)
        button.tap()
    }

    /// The sheet stayed put through the whole segment. A tap on sheet content
    /// lets the native sheet track the touch by up to 2pt, so ±3pt is
    /// "unmoved"; the rejected drop was hundreds of points.
    private func assertStatic(_ samples: [Sample], _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(samples.isEmpty, "\(name): no samples", file: file, line: line)
        let controllers = Set(samples.map(\.ctl))
        XCTAssertEqual(controllers.count, 1, "\(name): presenting controller changed \(controllers)", file: file, line: line)
        XCTAssertFalse(samples.contains { $0.top < 0 }, "\(name): sheet left the window", file: file, line: line)
        let tops = samples.map(\.top)
        XCTAssertLessThanOrEqual((tops.max() ?? 0) - (tops.min() ?? 0), 3, "\(name): sheet moved \(tops)", file: file, line: line)
        XCTAssertFalse(samples.contains { $0.dock }, "\(name): dock appeared", file: file, line: line)
        XCTAssertEqual(Set(samples.map(\.sel)).count, 1, "\(name): selection changed \(Set(samples.map(\.sel)))", file: file, line: line)
    }

    // MARK: Ordinary navigation never moves the sheet

    func testAnalysisQuestionSwitchingNeverMovesTheSheet() {
        launch()
        let mark = trace().now
        for id in ["guided.intent.question", "guided.intent.analysis", "guided.intent.question", "guided.intent.analysis"] {
            tap(id)
            settle(0.6)
        }
        let samples = segment(since: mark, "analysis-question")
        assertStatic(samples, "Analysis↔Question")
        XCTAssertEqual(samples.last?.route, "details-analysis")
        screenshot("p1-details-analysis")
    }

    func testDetailsReviewBackNeverMovesTheSheet() {
        launch()
        let mark = trace().now
        tap("guided.review")
        XCTAssertTrue(app.buttons["guided.post"].waitForExistence(timeout: 5))
        settle()
        screenshot("p1-review")
        tap("guided.back")
        XCTAssertTrue(app.buttons["guided.review"].waitForExistence(timeout: 5))
        settle()
        tap("guided.review")
        settle()
        tap("guided.back")
        settle()
        let samples = segment(since: mark, "details-review-back")
        assertStatic(samples, "Details→Review→Back")
        XCTAssertTrue(samples.contains { $0.route == "review-analysis" })
        XCTAssertEqual(samples.last?.route, "details-analysis")
    }

    func testContextIndicatorSettingsAndBackNeverMoveTheSheet() {
        launch()
        reveal("guided.addContext")
        let mark = trace().now
        tap("guided.addContext")
        settle(0.6)
        screenshot("p5-context")
        tap("workspace.indicator.EMA")
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        settle(0.6)
        screenshot("p1-indicator-settings")
        tap("guided.back") // Cancel the unsaved settings.
        settle(0.6)
        tap("guided.contextDone") // Add context → Details.
        settle()
        let samples = segment(since: mark, "context-indicator")
        assertStatic(samples, "Details→Context→Indicator→Settings→Back")
        for route in ["context-analysis", "indicatorSettings-analysis"] {
            XCTAssertTrue(samples.contains { $0.route == route }, "visited \(route)")
        }
        XCTAssertEqual(samples.last?.route, "details-analysis")
    }

    func testSetupDetailsReviewBackNeverMovesTheSheet() {
        launch(setup: true)
        XCTAssertTrue(app.buttons["guided.review"].waitForExistence(timeout: 5))
        screenshot("p1-setup-details")
        let mark = trace().now
        tap("guided.review")
        XCTAssertTrue(app.buttons["guided.post"].waitForExistence(timeout: 5))
        settle()
        screenshot("p1-setup-review")
        tap("guided.back")
        settle()
        let samples = segment(since: mark, "setup-review-back")
        assertStatic(samples, "Setup Details→Review→Back")
        XCTAssertTrue(samples.contains { $0.route == "review-setup" })
        XCTAssertEqual(samples.last?.route, "details-setup")
    }

    // MARK: The chart redraws only for draft edits (P2)

    /// MainView's body runs: it owns the draft, so each draft announcement
    /// rebuilds the shell and the chart in it. (The fixture has no guild, so
    /// no chart view is built; the shell is what is counted.)
    private func shellRenders() -> Int {
        settle(0.4) // the trace republishes at least every 0.25s
        return trace().shellRenders ?? -1
    }

    /// Moving around the workspace and scrolling it belong to the workspace
    /// session, so the shell and chart behind the sheet never redraw for
    /// them. Typing the post's own text is a draft edit and still does.
    func testTheChartRedrawsOnlyForDraftEdits() {
        launch()
        reveal("guided.addContext")
        let start = shellRenders()
        XCTAssertGreaterThan(start, 0, "the trace counts MainView renders")
        tap("guided.review")
        settle(0.6)
        tap("guided.back")
        settle(0.6)
        tap("guided.addContext")
        settle(0.6)
        tap("workspace.category.Momentum")
        settle(0.6)
        tap("workspace.tab.timeframes")
        settle(0.6)
        tap("workspace.tab.indicators")
        settle(0.6)
        tap("workspace.indicator.RSI")
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        settle(0.6)
        tap("guided.back")
        settle(0.6)
        tap("guided.contextDone")
        let navigation = shellRenders() - start

        let beforeScroll = shellRenders()
        app.scrollMarkerWorkspace()
        let scrolling = shellRenders() - beforeScroll

        let field = app.textViews["guided.text"]
        app.revealInMarkerWorkspace(field)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        settle(1.2)
        let before = field.value as? String ?? ""
        let beforeTyping = shellRenders()
        field.typeText("abcdef")
        let typing = shellRenders() - beforeTyping
        let after = field.value as? String ?? ""

        let summary = "MainView renders: navigation \(navigation), scrolling \(scrolling), typing 6 characters \(typing) (since launch \(start))"
        let note = XCTAttachment(string: summary + "\nbefore: \(before)\nafter: \(after)")
        note.name = "shell-renders.txt"
        note.lifetime = .keepAlways
        add(note)
        XCTAssertEqual(after.count, before.count + 6, "typed into the post")
        XCTAssertEqual(navigation, 0, summary)
        XCTAssertEqual(scrolling, 0, summary)
        XCTAssertGreaterThan(typing, 0, "the post's text is the draft's: \(summary)")
    }

    // MARK: Explicit moves keep one presentation and exact state

    func testCollapseAndResumeReturnToTheSameScreenAndValue() {
        launch()
        reveal("guided.addContext")
        tap("guided.addContext")
        tap("workspace.indicator.EMA")
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.65)
        let value = slider.value as? String
        settle()
        let mark = trace().now
        tap("guided.showChart")
        XCTAssertTrue(app.buttons["guided.compactDock"].waitForExistence(timeout: 5))
        settle()
        screenshot("p1-collapsed-dock")
        tap("guided.compactDock")
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        settle()
        XCTAssertEqual(slider.value as? String, value, "unsaved setting kept")
        let samples = segment(since: mark, "collapse-resume")
        XCTAssertEqual(Set(samples.map(\.ctl)).count, 1, "one presentation throughout")
        XCTAssertFalse(samples.contains { $0.top < 0 })
        XCTAssertTrue(samples.contains { $0.dock }, "the dock showed while collapsed")
        XCTAssertEqual(samples.first?.top ?? 0, samples.last?.top ?? -99, accuracy: 1, "resumed at the same height")
        XCTAssertEqual(samples.last?.route, "indicatorSettings-analysis")
        XCTAssertFalse(samples.last?.dock ?? true)
    }

    /// A scrolled screen is exactly where it was after collapse and resume.
    func testCollapseAndResumeKeepTheScrollPosition() {
        launch()
        reveal("guided.addContext")
        tap("guided.addContext")
        // The last Trend tile, below the fold at the opening height.
        let last = app.buttons["workspace.indicator.SAR"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        for _ in 0..<8 where !last.isHittable { app.scrollMarkerWorkspace() }
        XCTAssertTrue(last.isHittable, "scrolled to the end of the catalogue")
        settle()
        let before = last.frame.minY
        screenshot("p1-scrolled-before-collapse")
        tap("guided.showChart")
        XCTAssertTrue(app.buttons["guided.compactDock"].waitForExistence(timeout: 5))
        settle()
        tap("guided.compactDock")
        settle(1.2)
        screenshot("p1-scrolled-after-resume")
        XCTAssertTrue(last.isHittable, "still on screen after resume")
        XCTAssertEqual(last.frame.minY, before, accuracy: 4, "same scroll position")
    }

    // MARK: Keyboard

    /// Typing, twice in one session (the first keyboard loads cold, the
    /// second warm): the sheet keeps the height it was at and the keyboard
    /// carries it up as one piece, the content sitting on the keyboard and
    /// the chart visible above; the selected height never changes, the chart
    /// layer never resizes, and putting the keyboard away returns the sheet
    /// exactly where typing began.
    func testTypingLiftsTheSheetOntoTheKeyboardAndReturns() throws {
        launch()
        let field = app.textViews["guided.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // On a compact phone the small opening height does not reach the
        // text (a P3 layout item); the user raises the sheet first.
        let startsSmall = field.isHittable
        if !startsSmall { app.raiseMarkerSheet(); settle() }
        XCTAssertTrue(field.isHittable)
        let keyboard = app.keyboards.firstMatch
        let screenHeight = Int(app.frame.height)
        var risenTops: [Int] = []
        for cycle in 1...2 {
            // Each cycle from where the sheet is now.
            let rest = trace().samples.last
            let restTop = rest?.top ?? 0
            let mark = trace().now
            field.tap()
            guard keyboard.waitForExistence(timeout: 5) else {
                throw XCTSkip("no software keyboard on this simulator")
            }
            settle(1.2)
            // With a hardware keyboard connected the simulator shows only a
            // shortcut bar (or nothing): there is no lift to measure.
            guard keyboard.frame.height >= 150, keyboard.frame.minY < app.frame.maxY - 1 else {
                throw XCTSkip("hardware keyboard: no software keyboard on screen (height \(Int(keyboard.frame.height)))")
            }
            if cycle == 1 { screenshot("p1-typing") }
            let entry = segment(since: mark, "typing-entry-\(cycle)")
            XCTAssertEqual(Set(entry.map(\.ctl)).count, 1, "one presentation")
            // From tall, iOS 18 reports a height of its own while the keyboard
            // pins the sheet to the top; from the small opening it never does.
            let entryHeights = Set(entry.map(\.sel)).subtracting(startsSmall ? [] : ["(id: Unknown)"])
            XCTAssertEqual(entryHeights, [rest?.sel ?? ""], "the selected height never changes")
            XCTAssertEqual(Set(entry.map(\.chart)).count, 1, "the chart behind the sheet never moves \(Set(entry.map(\.chart)))")
            let tops = entry.map(\.top)
            let risen = tops.last ?? 0
            if startsSmall { XCTAssertLessThan(risen, restTop, "the sheet rose with the keyboard") }
            XCTAssertLessThanOrEqual(tops.max() ?? 0, restTop + 3, "no drop before rising \(tops)")
            XCTAssertTrue(zip(tops, tops.dropFirst()).allSatisfy { $1 <= $0 + 3 }, "one rising motion \(tops)")
            if startsSmall {
                // Lifted as one piece: the same height now sits on the keyboard.
                let heightAbove = Int(keyboard.frame.minY) - risen
                XCTAssertEqual(heightAbove, screenHeight - restTop, accuracy: 40, "kept its height, on the keyboard")
                XCTAssertGreaterThan(risen, 150, "the chart stays visible above the sheet")
            }
            risenTops.append(risen)
            XCTAssertLessThan(app.buttons["guided.review"].frame.maxY, keyboard.frame.minY + 1, "footer above the keyboard")
            XCTAssertFalse(app.buttons["Done"].exists && app.toolbars.count > 0, "no Done bar on a text keyboard")
            field.typeText(cycle == 1 ? " Buyers stepped in." : " Holding.")
            let exitMark = trace().now
            app.dismissKeyboardInMarkerWorkspace()
            settle(1.2)
            let exit = segment(since: exitMark, "typing-exit-\(cycle)")
            XCTAssertFalse(keyboard.exists, "keyboard put away")
            XCTAssertEqual(Set(exit.map(\.ctl)).count, 1)
            if startsSmall {
                XCTAssertEqual(exit.last?.sel, rest?.sel, "the height typing began at")
            } else {
                // From the tallest height iOS 18 settles a sheet at medium as
                // the keyboard goes (iOS 26 keeps it tall); either is one motion.
                XCTAssertTrue(["tall", "working"].contains(exit.last?.sel ?? ""), "an offered height: \(exit.last?.sel ?? "")")
            }
            XCTAssertEqual(Set(exit.map(\.chart)).count, 1, "nor on the way back \(Set(exit.map(\.chart)))")
            let exitTops = exit.map(\.top)
            if startsSmall {
                XCTAssertEqual(exitTops.last ?? 0, restTop, accuracy: 3, "back to where typing began")
            }
            XCTAssertTrue(zip(exitTops, exitTops.dropFirst()).allSatisfy { $1 >= $0 - 3 }, "one settling motion \(exitTops)")
        }
        if startsSmall { XCTAssertEqual(risenTops[0], risenTops[1], accuracy: 2, "the same lift both times") }
        let text = field.value as? String ?? ""
        XCTAssertTrue(text.contains("Buyers stepped in.") && text.contains("Holding."), text)
    }

    /// A new post opens small, with no keyboard, so its marker shows on the
    /// chart above the sheet (owner decision, 6 Oct 2026).
    func testANewPostOpensSmallWithoutTheKeyboard() {
        launch(filledNote: false)
        settle(1.5)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "no keyboard until the text is tapped")
        let samples = segment(since: 0, "opens-small")
        XCTAssertEqual(samples.last?.sel, "browse", "opens at the small height")
        XCTAssertEqual(Set(samples.map(\.ctl)).count, 1, "one presentation")
        screenshot("p1-opens-small")
    }

    func testASetupOpensSmallWithoutTheKeyboard() {
        launch(setup: true, filledNote: false)
        settle(1.5)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertEqual(trace().samples.last?.sel, "browse")
        XCTAssertEqual(trace().samples.last?.mode, "authoring")
    }
}
