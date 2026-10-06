import XCTest

/// P4: the Setup ticket on the real MainView sheet (fixture Setup: Entry at
/// the latest close, Take Profit 65,000, Stop Loss 63,000, set as the
/// author's own levels).
final class MarkerSetupTicketUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerMainViewSheetFixture", "-TGAvatarMarkersExperiment", "YES",
                               "-MarkerMainViewSetupFixture", "-MarkerSheetTrace"]
        app.launch()
        XCTAssertTrue(app.staticTexts["mainFixture.geometry"].waitForExistence(timeout: 20))
        settle(1.2)
    }

    private func settle(_ seconds: TimeInterval = 0.8) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        app.revealInMarkerWorkspace(button)
        XCTAssertTrue(button.isHittable, "\(id) hittable")
        button.tap()
        settle()
    }

    private func price(_ field: String) -> Double? {
        Double((app.textFields[field].value as? String ?? "").replacingOccurrences(of: ",", with: ""))
    }

    private func type(_ value: String, into field: String) {
        let input = app.textFields[field]
        // At the small height the level fields sit under the footer, which
        // XCUITest still counts as hittable: raise the sheet as a user would.
        app.raiseMarkerSheet()
        settle(0.6)
        app.revealInMarkerWorkspace(input)
        input.tap()
        settle(0.6)
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (input.value as? String ?? "").count + 2) + value)
        let done = app.buttons["workspace.keyboardDone"]
        if done.waitForExistence(timeout: 2) { done.tap() }
        settle()
    }

    /// The chart's suggested levels flip with the side at once; once the
    /// author has set a level, the side change says what moves and only
    /// "Flip levels" moves it.
    func testChangingSideFlipsSuggestedLevelsAndAsksForTheAuthorsOwn() {
        launch()
        XCTAssertTrue(app.buttons["guided.setup.long"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["guided.setup.long"].isSelected)
        shot("p4-setup-ticket")
        tap("guided.setup.short")
        XCTAssertFalse(app.alerts.firstMatch.exists, "the chart's suggestion flips without asking")
        XCTAssertEqual(price("Take Profit") ?? 0, 62_840, accuracy: 0.01)
        XCTAssertEqual(price("Stop Loss") ?? 0, 64_840, accuracy: 0.01)
        XCTAssertTrue(app.buttons["guided.setup.short"].isSelected)

        type("62500", into: "Take Profit")
        XCTAssertEqual(price("Take Profit") ?? 0, 62_500, accuracy: 0.01)
        tap("guided.setup.long")
        let alert = app.alerts["Switch to Long?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "the author's levels are never flipped silently")
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Take Profit 62,500.00 → 65,340.00")).firstMatch.exists)
        shot("p4-setup-side-confirm")
        alert.buttons["Cancel"].tap()
        settle()
        XCTAssertEqual(price("Take Profit") ?? 0, 62_500, accuracy: 0.01, "Cancel moves nothing")
        tap("guided.setup.long")
        app.alerts["Switch to Long?"].buttons["Flip levels"].tap()
        settle()
        XCTAssertEqual(price("Take Profit") ?? 0, 65_340, accuracy: 0.01)
        XCTAssertEqual(price("Stop Loss") ?? 0, 63_000, accuracy: 0.01)
        XCTAssertTrue(app.buttons["guided.setup.long"].isSelected)
    }

    /// Adjust on chart hands the sheet to the chart with a live readout; Cancel
    /// returns to the ticket with the levels as they were.
    func testAdjustOnChartShowsTheReadoutAndCancelKeepsTheLevels() {
        launch()
        let takeProfit = price("Take Profit")
        let stopLoss = price("Stop Loss")
        tap("guided.setup.adjust")
        let bar = app.otherElements["workspace.toolBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "the workspace steps aside to its tool bar")
        let readout = app.buttons["workspace.tool.options"].label
        XCTAssertTrue(readout.contains("Take Profit and Stop Loss"), readout)
        XCTAssertTrue(readout.contains("TP 65,000.00"), readout)
        shot("p4-setup-adjust-bar")
        app.buttons["workspace.tool.cancel"].tap()
        XCTAssertTrue(app.textFields["Take Profit"].waitForExistence(timeout: 5))
        settle()
        XCTAssertFalse(bar.exists)
        XCTAssertEqual(price("Take Profit"), takeProfit)
        XCTAssertEqual(price("Stop Loss"), stopLoss)
    }
}
