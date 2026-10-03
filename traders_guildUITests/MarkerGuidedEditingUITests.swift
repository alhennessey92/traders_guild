import XCTest

/// v1.5 guided editing in the real guided sheet, on the backend-free harness
/// (`-MarkerGuidedCreationFixture edit… -TGAvatarMarkersExperiment YES`; no
/// account, network or credentials). The fixture transport answers updates
/// as chart-service does. This does not cover the live chart, sheet detents
/// or the keyboard over the real sheet.
final class MarkerGuidedEditingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments += ["-MarkerGuidedCreationFixture", scenario, "-TGAvatarMarkersExperiment", "YES"] + extra
        app.launch()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
                .waitForExistence(timeout: 15)
        )
    }

    private func text(_ fragment: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testAnEditIsTitledAsOneAndOffersNoTypeOrLinkChange() throws {
        launch("editAnalysis")
        XCTAssertTrue(app.staticTexts["Edit Analysis"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["guided.intent.analysis"].exists, "no type selector in an edit")
        XCTAssertFalse(app.buttons["guided.changeType"].exists, "no Change type in an edit")
        XCTAssertTrue(text("Supports sam's BTC breakout").exists, "the fixed relationship is shown")
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Change relationship")).firstMatch.exists)

        let review = app.buttons["guided.review"]
        XCTAssertFalse(review.isEnabled, "nothing changed yet")
        XCTAssertEqual(app.staticTexts["guided.nextStep"].label, "Make a change to review it")
        attachScreenshot("edit-analysis-untouched")

        let field = app.textViews["guided.text"].exists ? app.textViews["guided.text"] : app.textFields["guided.text"]
        field.tap()
        field.typeText(" Still holding.")
        XCTAssertTrue(review.isEnabled)
        review.tap()
        XCTAssertTrue(text("Check your changes").waitForExistence(timeout: 5))
        XCTAssertTrue(text("Text edited").exists, "Review lists what changes")
        XCTAssertTrue(text("Text edited").isHittable, "and leads with it, in view at half height")
        XCTAssertTrue(app.buttons["guided.save"].exists && app.buttons["guided.save"].label == "Save changes")
        XCTAssertFalse(app.buttons["guided.post"].exists, "no Post in an edit")
        XCTAssertFalse(text("will see this on the chart").exists, "no new-post wording")
        attachScreenshot("edit-analysis-review")
    }

    func testAnActiveSetupShowsItsLevelsLockedAndOffersOnlyTitleAndThesis() throws {
        launch("editSetupActive")
        XCTAssertTrue(app.otherElements["guided.lockedSetup"].waitForExistence(timeout: 5)
                      || text("Levels locked").exists)
        XCTAssertTrue(text("is active").exists, "the lock is explained")
        XCTAssertFalse(app.textFields["Take Profit"].exists, "no level fields")
        XCTAssertFalse(app.switches.firstMatch.exists, "no tracking switch")
        XCTAssertFalse(app.buttons["guided.addContext"].exists, "no context editing")
        app.buttons["guided.next"].tap()
        XCTAssertTrue(app.buttons["guided.addTitle"].waitForExistence(timeout: 5) || app.textFields["guided.title"].exists,
                      "the title and thesis are editable")
        XCTAssertFalse(app.buttons["guided.addContext"].exists, "still no context editing")
        attachScreenshot("edit-setup-active-locked")
    }

    func testAFailedSaveKeepsTheChangesAndOffersRetry() throws {
        launch("editFailedSave")
        XCTAssertTrue(text("Couldn't save").waitForExistence(timeout: 5))
        XCTAssertTrue(text("Your changes are kept").exists)
        let save = app.buttons["guided.save"]
        XCTAssertEqual(save.label, "Retry")
        XCTAssertTrue(save.isEnabled)
        attachScreenshot("edit-failed-save")
        save.tap()
        XCTAssertTrue(text("No share prompt, no new marker").waitForExistence(timeout: 5), "Retry saves")
        XCTAssertTrue(text("creates: 0").exists, "nothing was created")
    }

    func testRetrySucceedsWithoutCreatingOrSharing() throws {
        launch("editRetrySuccess")
        XCTAssertTrue(text("No share prompt, no new marker").waitForExistence(timeout: 5))
        XCTAssertTrue(text("Update #2").exists)
        XCTAssertTrue(text("creates: 0").exists)
        XCTAssertFalse(text("share prompt handoff").exists)
    }

    func testDiscardingAnEditedDraftSaysTheMarkerIsKept() throws {
        launch("editDiscard")
        XCTAssertTrue(app.staticTexts["Discard your changes?"].waitForExistence(timeout: 5))
        XCTAssertTrue(text("The marker stays as it was").exists)
        // On iOS 26 the dialog is a popover: Keep Editing (the cancel role)
        // is a tap outside it rather than a button, as for a new draft.
        XCTAssertTrue(app.buttons["Discard Changes"].exists)
        attachScreenshot("edit-discard")
    }

    func testLargestTextKeepsSaveReachable() throws {
        launch("editAnalysisReview", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let save = app.buttons["guided.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(save.frame.height, 68, "Save fits the fixed bar")
        XCTAssertTrue(save.isHittable)
        attachScreenshot("ax-xxxl-edit-review")
    }
}
