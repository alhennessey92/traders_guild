import XCTest

/// Native-sheet fixtures reuse the production panel, dock, bar and detent
/// policy. They contain no signed-in chart and post to in-memory transport.
final class MarkerGuidedSheetJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ scenario: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", scenario,
                               "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["guided.showChart"].waitForExistence(timeout: 15))
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "native-fixture-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var textField: XCUIElement {
        app.textViews["guided.text"].exists ? app.textViews["guided.text"] : app.textFields["guided.text"]
    }

    func testAnalysisDraftResumesThroughContextReviewAndPost() throws {
        launch("analysisEmpty")
        screenshot("compose-empty")
        textField.tap()
        textField.typeText("Range low is holding.")
        screenshot("compose-keyboard")
        app.buttons["guided.showChart"].tap()
        let resume = app.buttons["guided.compactDock"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertTrue(resume.label.contains("Continue editing"))
        XCTAssertFalse(app.buttons["guided.post"].exists)
        XCTAssertFalse(app.buttons["guided.review"].exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        screenshot("compact-draft")
        resume.tap()
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        XCTAssertEqual(textField.value as? String, "Range low is holding.")
        app.buttons["guided.addTitle"].tap()
        let title = app.textFields["guided.title"]
        title.tap()
        title.typeText("Range low")
        app.buttons["guided.showChart"].tap()
        resume.tap()
        app.buttons["guided.addContext"].tap()
        XCTAssertTrue(app.buttons["guided.contextDone"].waitForExistence(timeout: 5))
        screenshot("optional-context")
        app.buttons["guided.contextDone"].tap()
        XCTAssertEqual(app.textFields["guided.title"].value as? String, "Range low")
        XCTAssertEqual(textField.value as? String, "Range low is holding.")
        app.buttons["guided.review"].tap()
        let post = app.buttons["guided.post"]
        XCTAssertTrue(post.waitForExistence(timeout: 5) && post.isEnabled)
        screenshot("review")
        app.buttons["guided.showChart"].tap()
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertTrue(resume.label.contains("Review ready"))
        XCTAssertFalse(post.exists, "the dock never offers submission")
        resume.tap()
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "share prompt handoff")).firstMatch.waitForExistence(timeout: 5))
        screenshot("post-transport-and-share-handoff")
    }

    func testExistingContextSurvivesTheSideTripAndPost() throws {
        launch("context")
        app.buttons["guided.contextDone"].tap()
        app.buttons["guided.review"].tap()
        XCTAssertTrue(app.buttons["guided.post"].waitForExistence(timeout: 5))
        app.buttons["guided.post"].tap()
        let request = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "level.support")).firstMatch
        XCTAssertTrue(request.waitForExistence(timeout: 5), "the recorded request keeps optional chart context")
        screenshot("context-post-request")
    }

    func testLargeTextCanExpandAndResume() throws {
        launch("analysisDetails", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let showChart = app.buttons["guided.showChart"]
        if !showChart.isHittable { app.swipeUp() }
        XCTAssertTrue(showChart.isHittable)
        showChart.tap()
        let resume = app.buttons["guided.compactDock"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5) && resume.isHittable)
        screenshot("compact-largest-text")
        resume.tap()
        let grabber = app.buttons["Sheet Grabber"]
        let oldTop = grabber.frame.minY
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
        XCTAssertLessThan(grabber.frame.minY, oldTop - 50, "the user can expand beyond the working height")
        XCTAssertTrue(app.buttons["guided.intentPicker"].waitForExistence(timeout: 5))
        screenshot("expanded-largest-text")
    }
}
