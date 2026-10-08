import XCTest

/// P3 visual evidence: each Post, Review and response screen as the owner
/// will see it on device, at the height the workspace opens at and raised.
/// Screenshots are attached to the result bundle; the assertions only prove
/// each screen is the one named.
final class MarkerWorkspaceVisualReviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchMain(setup: Bool = false) {
        app = XCUIApplication()
        var arguments = ["-MarkerMainViewSheetFixture", "-TGAvatarMarkersExperiment", "YES", "-MarkerMainViewFilledNote"]
        if setup { arguments.append("-MarkerMainViewSetupFixture") }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["mainFixture.geometry"].waitForExistence(timeout: 20))
        settle(1.2)
    }

    private func launchHarness(_ scenario: String) {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", scenario, "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
            .waitForExistence(timeout: 15))
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

    private func header() -> String { app.staticTexts["guided.stepHeader"].label }

    private func tap(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        app.revealInMarkerWorkspace(button)
        button.tap()
        settle()
    }

    func testPostScreens() {
        launchMain()
        XCTAssertEqual(header(), "New Analysis")
        shot("p3-analysis-small")
        tap("guided.intent.question")
        shot("p3-question-small")
        tap("guided.intent.analysis")
        app.raiseMarkerSheet()
        settle()
        shot("p3-analysis-raised")
        tap("guided.review")
        XCTAssertEqual(header(), "Review")
        shot("p3-review")
    }

    func testSetupScreens() {
        launchMain(setup: true)
        XCTAssertEqual(header(), "New Setup")
        shot("p3-setup-small")
        app.raiseMarkerSheet()
        settle()
        shot("p3-setup-raised")
        tap("guided.review")
        shot("p3-setup-review")
    }

    func testContextScreens() {
        launchHarness("context")
        XCTAssertTrue(app.buttons["workspace.tab.indicators"].waitForExistence(timeout: 5))
        shot("p5-context-indicators-small")
        app.raiseMarkerSheet()
        settle()
        shot("p5-context-indicators")
        tap("workspace.category.Momentum")
        shot("p5-context-momentum")
        tap("workspace.tab.drawings")
        shot("p5-context-drawings")
        tap("workspace.tab.timeframes")
        shot("p5-context-timeframes")
        tap("workspace.tab.notes")
        shot("p5-context-notes")
    }

    // MARK: P6: the largest accessibility text size

    private func launchHarnessLargeText(_ scenario: String) {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", scenario, "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
            .waitForExistence(timeout: 15))
        settle(1.2)
    }

    func testLargestTextSizeScreens() {
        for (scenario, name) in [("entry", "add"), ("analysisDetails", "details"), ("context", "context"),
                                 ("setupTracked", "setup"), ("editSetupArmedReview", "edit-review")] {
            launchHarnessLargeText(scenario)
            app.raiseMarkerSheet()
            settle()
            shot("p6-ax-\(name)")
            app.terminate()
        }
    }

    // MARK: P6: the drawing editor

    func testDrawingEditor() {
        launchHarness("context")
        app.raiseMarkerSheet()
        settle()
        tap("workspace.tab.drawings")
        tap("workspace.drawing.horizontalLine")
        // The workspace hands over to the chart; its bar's label returns.
        let options = app.buttons["workspace.tool.options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        shot("p6-drawing-toolbar")
        options.tap()
        settle(1.2)
        app.raiseMarkerSheet()
        settle()
        XCTAssertTrue(app.buttons["workspace.drawing.adjust"].waitForExistence(timeout: 5))
        shot("p6-drawing-editor")
        if app.buttons["workspace.drawing.style.dotted"].exists {
            tap("workspace.drawing.style.dotted")
            tap("workspace.drawing.colour.Violet")
            shot("p6-drawing-editor-styled")
        }
    }

    // MARK: P6: the Light Grey theme

    func testLightGreyThemeScreens() {
        for (scenario, name) in [("entry", "add"), ("analysisDetails", "details"), ("analysisReview", "review"),
                                 ("context", "context"), ("setupTracked", "setup"), ("responseDetails", "response")] {
            app = XCUIApplication()
            app.launchArguments = ["-MarkerGuidedCreationFixture", scenario, "-MarkerGuidedSheetFixture", "YES",
                                   "-TGAvatarMarkersExperiment", "YES", "-appTheme", "lightGrey"]
            app.launch()
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
                .waitForExistence(timeout: 15))
            settle(1.2)
            app.raiseMarkerSheet()
            settle()
            shot("p6-light-\(name)")
            app.terminate()
        }
    }

    func testResponseScreens() {
        launchHarness("responseDetails")
        XCTAssertTrue(app.otherElements["guided.responseBanner"].waitForExistence(timeout: 5))
        shot("p3-response-small")
        tap("guided.convertResponse")
        XCTAssertTrue(app.textFields["Take Profit"].waitForExistence(timeout: 5))
        settle()
        shot("p3-response-setup")
    }
}
