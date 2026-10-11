import XCTest

/// Poll and Alert on the Post screen (owner, 11 Oct), through the in-memory
/// submitter: what each type asks for, and what it sends. No account, backend
/// or phone needed.
final class MarkerPollAlertUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchOnPost() {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", "entry", "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
            .waitForExistence(timeout: 15))
        tap("guided.postToChart")
    }

    private func tap(_ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        // The sheet opens small: raise it, then scroll.
        app.revealInMarkerWorkspace(button)
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }

    private func type(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        app.revealInMarkerWorkspace(element)
        element.tap()
        element.typeText(text)
        app.dismissKeyboardInMarkerWorkspace()
    }

    private var sentRequest: String {
        let sent = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "\"components\"")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5))
        return sent.label
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testThePostScreenOffersFourTypesAndNoSetup() {
        launchOnPost()
        for intent in ["analysis", "question", "poll", "alert"] {
            XCTAssertTrue(app.buttons["guided.intent.\(intent)"].waitForExistence(timeout: 5), intent)
            XCTAssertTrue(app.buttons["guided.intent.\(intent)"].isHittable, intent)
        }
        XCTAssertFalse(app.buttons["guided.intent.setup"].exists)
        capture("post-four-types")
    }

    func testAPollAsksForTwoChoicesAndSendsItsQuestionAsTheTitle() {
        launchOnPost()
        tap("guided.intent.poll")
        XCTAssertTrue(app.buttons["guided.intent.poll"].isSelected)
        XCTAssertFalse(app.buttons["guided.addTitle"].exists, "a poll's question is its title")
        type("Which target gets hit first?", into: app.textViews["guided.text"])

        let review = app.buttons["guided.review"]
        XCTAssertFalse(review.isEnabled, "two choices are needed")
        type("Range high", into: app.textFields["guided.poll.choice.0"])
        type("Range low", into: app.textFields["guided.poll.choice.1"])
        tap("guided.poll.addChoice")
        XCTAssertTrue(app.textFields["guided.poll.choice.2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["guided.poll.remove.2"].exists)
        capture("poll-details")

        tap("guided.review")
        XCTAssertTrue(app.staticTexts["Range high"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Range low"].exists)
        capture("poll-review")
        tap("guided.post")

        let json = sentRequest
        XCTAssertTrue(json.contains("\"poll\""), json)
        XCTAssertTrue(json.contains("poll_options"), json)
        XCTAssertTrue(json.contains("Range high") && json.contains("Range low"), json)
        XCTAssertTrue(json.contains("Which target gets hit first?"), json)
    }

    func testAnAlertAsksHowUrgentAndSendsItAtTheFrontOfItsNote() {
        launchOnPost()
        tap("guided.intent.alert")
        type("Liquidity sweep under the Asia lows", into: app.textViews["guided.text"])
        XCTAssertFalse(app.buttons["guided.review"].isEnabled, "a severity is needed")

        tap("guided.severity.Moderate")
        XCTAssertTrue(app.buttons["guided.severity.Moderate"].isSelected)
        capture("alert-details")

        tap("guided.review")
        XCTAssertTrue(app.descendants(matching: .any)["guided.severityPill"].waitForExistence(timeout: 5))
        capture("alert-review")
        tap("guided.post")

        let json = sentRequest
        XCTAssertTrue(json.contains("\"alert\""), json)
        XCTAssertTrue(json.contains("[Warning] Liquidity sweep under the Asia lows"), json)
    }

    func testSwitchingTypeKeepsTheText() {
        launchOnPost()
        type("Range low is holding for now", into: app.textViews["guided.text"])
        for intent in ["poll", "alert", "question", "analysis"] {
            tap("guided.intent.\(intent)")
            XCTAssertEqual(app.textViews["guided.text"].value as? String, "Range low is holding for now", intent)
        }
    }
}
