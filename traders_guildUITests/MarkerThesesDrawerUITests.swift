import XCTest

/// The drawer's Theses tab and threaded Live Feed (owner, 12 Oct), through the
/// backend-free fixture: what each shows, and what a tap would open.
final class MarkerThesesDrawerUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ tab: String) {
        app = XCUIApplication()
        app.launchArguments = ["-DrawerThesesFixture", tab, "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["thesesFixture.lastAction"].waitForExistence(timeout: 15))
    }

    private var lastAction: String { app.staticTexts["thesesFixture.lastAction"].label }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testThesesShowEachDebateWithItsStanceAndOpenWhatIsTapped() {
        launch("theses")
        let busy = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Range low holds")).firstMatch
        XCTAssertTrue(busy.waitForExistence(timeout: 5))
        XCTAssertTrue(busy.label.contains("Supports 2"), busy.label)
        XCTAssertTrue(busy.label.contains("Challenges 1"), busy.label)
        XCTAssertTrue(busy.label.contains("Builds on 1"), busy.label)
        XCTAssertTrue(app.staticTexts["4 replies"].exists)
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Breakout or fakeout")).firstMatch.exists,
                      "a thesis known only from its replies still appears")
        capture("theses")

        busy.tap()
        XCTAssertTrue(lastAction.contains("thesis @alex"), lastAction)

        let reply = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Next leg 66.2k")).firstMatch
        XCTAssertTrue(reply.exists)
        reply.tap()
        XCTAssertTrue(lastAction.contains("reply @mk"), lastAction)

        let preview = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Breakout or fakeout")).firstMatch
        preview.tap()
        XCTAssertTrue(lastAction.contains("thesis @jo (preview)"), lastAction)
    }

    func testTheLiveFeedTucksRepliesUnderTheMarkerTheyAnswer() {
        launch("feed")
        // The feed's list item shows an Analysis by its text.
        let thesis = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Third test of the range low")).firstMatch
        XCTAssertTrue(thesis.waitForExistence(timeout: 5))
        let replies = ["Volume agrees — absorption at the low", "What does funding say?",
                       "Funding resets every bounce here", "Next leg 66.2k if the range holds"]
        var lastY = thesis.frame.minY
        for text in replies {
            let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            XCTAssertTrue(row.exists, text)
            XCTAssertGreaterThan(row.frame.minY, lastY, "\(text) sits beneath the thread, oldest first")
            lastY = row.frame.minY
        }
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "@sam → @jo")).firstMatch.exists,
                      "a reply to a reply names whom it answers")
        capture("feed-top")

        let orphan = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Breakout or fakeout")).firstMatch
        var swipes = 0
        while !(orphan.exists && orphan.isHittable) && swipes < 5 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        capture("feed-orphans")
        XCTAssertTrue(orphan.isHittable, "a reply whose thesis is not in the feed says what it answers")
        orphan.tap()
        XCTAssertTrue(lastAction.contains("parent of @"), lastAction)
    }
}
