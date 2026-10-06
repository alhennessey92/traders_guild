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
        XCTAssertLessThanOrEqual(grabber.frame.minY, oldTop + 2, "large-text content remains expandable or is already near the tall cap")
        XCTAssertTrue(app.otherElements["guided.intentPicker"].waitForExistence(timeout: 5))
        screenshot("expanded-largest-text")
    }
    func testEmptyTitleAndScrolledSectionSurviveChartMode() throws {
        launch("analysisEmpty", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let addTitle = app.buttons["guided.addTitle"]
        // The sheet opens small (6 Oct 2026): raise it, then scroll.
        app.revealInMarkerWorkspace(addTitle)
        XCTAssertTrue(addTitle.isHittable)
        addTitle.tap()
        let title = app.textFields["guided.title"]
        app.revealInMarkerWorkspace(title, scrolls: 4)
        XCTAssertTrue(title.exists && title.isHittable)
        let oldTop = title.frame.minY
        let oldValue = title.value as? String
        screenshot("empty-title-scrolled-before-chart")
        app.buttons["guided.showChart"].tap()
        let resume = app.buttons["guided.compactDock"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5) && title.isHittable, "the intentionally opened empty field stays open and visible")
        XCTAssertEqual(title.value as? String, oldValue)
        XCTAssertEqual(title.frame.minY, oldTop, accuracy: 16, "the same scrolled section resumes")
        XCTAssertFalse(app.buttons["guided.addTitle"].exists)
        screenshot("empty-title-scrolled-after-resume")
    }

    func testUserExpansionSurvivesReviewBackAndChartResume() throws {
        launch("analysisDetails")
        let grabber = app.buttons["Sheet Grabber"]
        let workingTop = grabber.frame.minY
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        XCTAssertLessThan(grabber.frame.minY, workingTop - 50)
        let tallTop = grabber.frame.minY
        app.buttons["guided.review"].tap()
        XCTAssertTrue(app.buttons["guided.post"].waitForExistence(timeout: 5))
        XCTAssertEqual(grabber.frame.minY, tallTop, accuracy: 4)
        app.buttons["guided.back"].tap()
        XCTAssertTrue(app.buttons["guided.review"].waitForExistence(timeout: 5))
        XCTAssertEqual(grabber.frame.minY, tallTop, accuracy: 4)
        app.buttons["guided.showChart"].tap()
        app.buttons["guided.compactDock"].tap()
        XCTAssertTrue(app.buttons["guided.review"].waitForExistence(timeout: 5))
        XCTAssertEqual(grabber.frame.minY, tallTop, accuracy: 4)
        screenshot("retained-user-expansion")
    }

}
