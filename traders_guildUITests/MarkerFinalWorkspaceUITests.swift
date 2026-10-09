import XCTest

/// Functional Phase A checks on the same native sheet/panel and in-memory
/// submitter. They do not require authentication, a backend or a physical phone.
final class MarkerFinalWorkspaceUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ scenario: String) {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", scenario, "-MarkerGuidedSheetFixture", "YES", "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch.waitForExistence(timeout: 15))
    }
    private func tap(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        // The sheet opens small (6 Oct 2026): raise it, then scroll.
        app.revealInMarkerWorkspace(button)
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testExactlyTwoAvatarEntries() {
        launch("entry")
        XCTAssertTrue(app.buttons["guided.postToChart"].exists)
        XCTAssertTrue(app.buttons["guided.planTrade"].exists)
        XCTAssertTrue(app.buttons["guided.planTrade"].label.contains("Setup"))
        XCTAssertFalse(app.buttons["guided.otherTypes"].exists)
        XCTAssertFalse(app.buttons["guided.changeType"].exists)
        capture("final-two-entries")
        tap("guided.postToChart")
        XCTAssertTrue(app.buttons["guided.intent.analysis"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["guided.intent.question"].exists)
        XCTAssertFalse(app.buttons["guided.intent.setup"].exists)
    }

    func testUnsavedNestedIndicatorCollapseResumeAndCancel() {
        launch("analysisDetails")
        tap("guided.addContext")
        tap("workspace.indicator.EMA")
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.65)
        let before = slider.value as? String
        let sheetTop = app.buttons["Sheet Grabber"].frame.minY
        capture("final-indicator-unsaved")
        tap("guided.showChart")
        tap("guided.compactDock")
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(slider.value as? String, before)
        XCTAssertEqual(app.buttons["Sheet Grabber"].frame.minY, sheetTop, accuracy: 8)
        XCTAssertEqual(app.buttons["guided.back"].label, "Cancel")
        XCTAssertEqual(app.navigationBars.count, 0, "embedded editor has no second navigation sheet")
        capture("final-indicator-resumed")
        tap("guided.back")
        XCTAssertTrue(app.buttons["workspace.indicator.EMA"].exists, "back on the Indicators tab")
        tap("guided.contextDone")
        tap("guided.review")
        tap("guided.post")
        let sent = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"components\"")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5))
        XCTAssertFalse(sent.label.contains("\"indicator\""), "Cancel never attached the pending indicator")
    }

    func testNestedIndicatorDoneCommitsToDraftAndPost() {
        launch("analysisDetails")
        tap("guided.addContext")
        tap("workspace.category.Momentum")
        tap("workspace.indicator.RSI")
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.4)
        tap("guided.contextDone") // Settings → removable summary.
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "RSI")).firstMatch.exists)
        tap("guided.contextDone")
        tap("guided.review")
        tap("guided.post")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"indicator\"")).firstMatch.waitForExistence(timeout: 5))
    }

    func testUnfinishedSourceLinkResumesWithoutCreatingPlaceholder() {
        launch("analysisDetails")
        tap("guided.addContext")
        tap("workspace.tab.notes")
        tap("workspace.source.add")
        let field = app.textFields.containing(NSPredicate(format: "label == %@", "https://example.com/source")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["guided.contextDone"].isEnabled)
        field.tap(); field.typeText("https://example.com/research")
        XCTAssertTrue(app.buttons["guided.contextDone"].isEnabled)
        tap("guided.showChart")
        tap("guided.compactDock")
        XCTAssertEqual(field.value as? String, "https://example.com/research")
        capture("final-source-resumed")
        tap("guided.back") // Cancel the pending link.
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "https://example.com/research")).firstMatch.exists)
        tap("guided.contextDone")
        tap("guided.review")
        tap("guided.post")
        let sent = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"components\"")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5))
        XCTAssertFalse(sent.label.contains("link.url"))
    }

    func testLevelChartHandoffResumesNumericEditorAndCancelDoneStayInternal() throws {
        launch("context")
        let level = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "workspace.edit.")).firstMatch
        XCTAssertTrue(level.waitForExistence(timeout: 5)); level.tap()
        // A level goes straight to the chart, with its handle: the sheet is
        // the tool's bar, and Options opens its typed price.
        XCTAssertTrue(app.otherElements["workspace.toolBar"].waitForExistence(timeout: 5))
        tap("workspace.tool.options")
        let field = app.textFields["workspace.levelEditor.Price"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let original = try XCTUnwrap(field.value as? String)
        func setPrice(_ value: String) {
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count) + value)
        }
        setPrice("63820.00")
        tap("workspace.level.adjust")
        XCTAssertTrue(app.otherElements["workspace.toolBar"].waitForExistence(timeout: 5))
        tap("workspace.tool.options")
        XCTAssertEqual(field.value as? String, "63820.00")
        XCTAssertTrue(app.buttons["workspace.level.adjust"].exists)
        XCTAssertEqual(app.buttons["guided.back"].label, "Cancel")
        XCTAssertEqual(app.navigationBars.count, 0)
        capture("final-level-chart-handoff-resumed")
        tap("guided.back")
        XCTAssertTrue(level.waitForExistence(timeout: 5)); level.tap()
        tap("workspace.tool.options")
        XCTAssertEqual(field.value as? String, original, "Cancel restores the selected original level")
        setPrice("63840.00")
        tap("guided.contextDone")
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        tap("guided.contextDone"); tap("guided.review"); tap("guided.post")
        let sent = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"components\"")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5))
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sent.label.utf8)) as? [String: Any])
        let components = try XCTUnwrap(request["components"] as? [[String: Any]])
        let support = try XCTUnwrap(components.first { $0["component_type"] as? String == "level.support" })
        let payload = try XCTUnwrap(support["payload"] as? [String: Any])
        XCTAssertEqual(payload["price"] as? Double, 63840)
        XCTAssertEqual(payload["label"] as? String, "Range low")
    }

    /// Owner, 8 Oct: a new support or resistance is a line on the chart with
    /// a drag handle, not a number in the sheet.
    func testNewLevelIsALineOnTheChartAndCancelTakesItOff() {
        launch("context")
        tap("workspace.tab.drawings")
        let resistanceChip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                              "workspace.edit.", "Resistance")).firstMatch
        XCTAssertFalse(resistanceChip.exists)
        tap("workspace.level.resistance")
        XCTAssertTrue(app.otherElements["workspace.toolBar"].waitForExistence(timeout: 5), "straight to the chart")
        XCTAssertTrue(app.buttons["workspace.tool.options"].label.contains("Resistance"))
        capture("final-level-new-on-chart")
        tap("workspace.tool.cancel")
        XCTAssertTrue(app.buttons["workspace.level.resistance"].waitForExistence(timeout: 5))
        XCTAssertFalse(resistanceChip.exists, "Cancel takes a new level off")
        tap("workspace.level.resistance")
        XCTAssertTrue(app.otherElements["workspace.toolBar"].waitForExistence(timeout: 5))
        tap("workspace.tool.done")
        XCTAssertTrue(resistanceChip.waitForExistence(timeout: 5), "Done keeps it on the marker")
    }

    /// Owner, 9 Oct: linking the first timeframe pushed the tiles down while
    /// the chosen one filled, and unlinking the last pulled them back up.
    func testLinkingTheFirstTimeframeMovesNothing() {
        launch("analysisDetails")
        tap("guided.addContext")
        tap("workspace.tab.timeframes")
        XCTAssertTrue(app.descendants(matching: .any)["workspace.attached.empty"].waitForExistence(timeout: 5))
        let tile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND isEnabled == true", "workspace.timeframe.")).element(boundBy: 0)
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        let before = tile.frame.minY
        tile.tap()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 0.6)
        XCTAssertTrue(tile.label.contains("linked"), tile.label)
        XCTAssertEqual(tile.frame.minY, before, accuracy: 0.5, "the tile stays where it was")
        capture("final-first-timeframe-linked")
        tile.tap()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 0.6)
        XCTAssertEqual(tile.frame.minY, before, accuracy: 0.5, "and unlinking the last moves nothing either")
        XCTAssertTrue(app.descendants(matching: .any)["workspace.attached.empty"].exists)
    }

    func testQuestionContextExcludesUnsupportedSourceAndLevels() {
        launch("questionShort")
        XCTAssertFalse(app.buttons["guided.review"].isEnabled)
        tap("guided.addContext")
        XCTAssertTrue(app.buttons["workspace.tab.indicators"].exists)
        XCTAssertTrue(app.buttons["workspace.indicator.EMA"].exists)
        tap("workspace.tab.notes")
        XCTAssertTrue(app.buttons["workspace.note.add"].exists)
        XCTAssertFalse(app.buttons["workspace.source.add"].exists, "a Question carries no source")
        tap("workspace.tab.drawings")
        XCTAssertFalse(app.buttons["workspace.level.support"].exists, "nor support")
        XCTAssertFalse(app.buttons["workspace.level.resistance"].exists, "nor resistance")
        capture("final-question-context")
    }

    func testSetupIsOneScrollingDetailsAndReviewReturnsThere() {
        launch("setupTracked")
        XCTAssertTrue(app.textFields["Take Profit"].exists)
        XCTAssertTrue(app.textFields["Stop Loss"].exists)
        XCTAssertTrue(app.textViews["guided.text"].exists)
        XCTAssertFalse(app.buttons["guided.next"].exists)
        XCTAssertFalse(app.buttons["guided.changeType"].exists)
        capture("final-setup-details")
        tap("guided.review")
        tap("guided.back")
        XCTAssertTrue(app.textFields["Take Profit"].exists)
        XCTAssertTrue(app.textViews["guided.text"].exists)
    }

    func testResponseConversionsKeepRelationshipAndStayInDetails() {
        launch("responseDetails")
        tap("guided.convertResponse")
        XCTAssertTrue(app.textFields["Take Profit"].exists)
        XCTAssertTrue(app.buttons["guided.convertResponse"].label.contains("Return to post"))
        tap("guided.convertResponse")
        // The backend-free fixture may have no seeded Setup levels; when it
        // does, the normal incompatible-component confirmation is explicit.
        if app.alerts.firstMatch.exists { app.alerts.buttons["Remove and Switch"].tap() }
        XCTAssertFalse(app.buttons["guided.compactDock"].exists, "conversion stays in Details")
        for _ in 0..<5 {
            if app.buttons["guided.intent.analysis"].exists { break }
            app.swipeDown()
        }
        XCTAssertTrue(app.buttons["guided.intent.analysis"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["marker.response.timeframe"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Challenges")).firstMatch.exists
                      || app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Challenges")).firstMatch.exists)
    }

    func testActualMainViewKeyboardStaysWithinAvailableWindowAndResumes() {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerMainViewSheetFixture", "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        let geometry = app.staticTexts["mainFixture.geometry"]
        XCTAssertTrue(geometry.waitForExistence(timeout: 15))
        let field = app.textViews["guided.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Range low holds.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let header = app.buttons["guided.showChart"]
        XCTAssertTrue(header.isHittable)
        XCTAssertGreaterThanOrEqual(header.frame.minY, 0)
        XCTAssertLessThan(header.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("final-mainview-keyboard")
        tap("guided.showChart")
        tap("guided.compactDock")
        XCTAssertEqual(field.value as? String, "Range low holds.")
        capture("final-mainview-resumed")
    }
}
