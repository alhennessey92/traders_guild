import XCTest

/// The v1.5 refined marker detail (General tab), on the backend-free viewing
/// fixture (`-MarkerViewingFixture <scenario>`), which needs no account,
/// network or credentials and writes no app state.
///
/// Proves what silently regresses: the reading order (author, then the post,
/// then the actions), that Respond and Share are reachable and labelled, that
/// the author face opens the profile, and that with the experiment off the
/// shipped layout is unchanged.
final class MarkerViewingRefinementTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, experiment: Bool = true, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments += ["-MarkerViewingFixture", scenario,
                                "-TGAvatarMarkersExperiment", experiment ? "YES" : "NO"] + extra
        app.launch()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
                .waitForExistence(timeout: 15),
            "the viewing fixture must come up; it is isolated-DEV only"
        )
    }

    private func lastTap() -> String {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "last tap:")).firstMatch.label
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTheRefinedLayoutReadsAuthorThenPostThenActions() throws {
        launch("analysis")
        let face = app.buttons["marker.authorFace"]
        let title = app.staticTexts["Higher lows into the open"]
        let respond = app.buttons["marker.respond"]
        let share = app.buttons["marker.share"]
        XCTAssertTrue(face.waitForExistence(timeout: 5))
        XCTAssertEqual(face.label, "@sam, view profile")
        XCTAssertTrue(title.exists, "the title is shown, not folded into General")
        XCTAssertTrue(respond.exists && share.exists)
        XCTAssertLessThan(face.frame.minY, title.frame.minY, "author before the post")
        XCTAssertLessThan(title.frame.maxY, respond.frame.minY, "the post before the actions")
        XCTAssertEqual(respond.frame.minY, share.frame.minY, accuracy: 0.5, "Respond and Share sit side by side")
        XCTAssertEqual(respond.frame.height, share.frame.height, accuracy: 0.5, "at one height")
        XCTAssertGreaterThanOrEqual(respond.frame.height, 44, "a full touch target")
        attachScreenshot("refined-analysis")

        face.tap()
        XCTAssertTrue(lastTap().hasSuffix("author"), lastTap())
        share.tap()
        XCTAssertTrue(lastTap().hasSuffix("share"), lastTap())
    }

    func testRespondStillOpensTheRelationshipPicker() throws {
        launch("response")
        XCTAssertTrue(
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Challenges")).firstMatch
                .waitForExistence(timeout: 5),
            "the relationship row is kept"
        )
        app.buttons["marker.respond"].tap()
        let supports = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Supports")).firstMatch
        XCTAssertTrue(supports.waitForExistence(timeout: 5), "Respond opens the existing picker")
        supports.tap()
        let deadline = Date().addingTimeInterval(5)
        while !lastTap().contains("respond") && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(lastTap().contains("respond supports"), lastTap())
    }

    func testTheAuthorKeepsEditAndDelete() throws {
        launch("own")
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Edit")).firstMatch
            .waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Delete Marker")).firstMatch.exists)
    }

    func testASetupKeepsItsLevelsAndTracking() throws {
        launch("setup")
        XCTAssertTrue(app.staticTexts["Long the range-low retest"].waitForExistence(timeout: 5))
        for text in ["TAKE PROFIT", "ENTRY", "STOP LOSS", "64,400", "63,920", "63,700"] {
            XCTAssertTrue(app.staticTexts[text].exists, "\(text) is shown")
        }
        XCTAssertTrue(app.staticTexts["Invalidated below the shelf."].exists, "the thesis is shown under the title")
    }

    func testWithTheExperimentOffTheShippedLayoutIsUnchanged() throws {
        launch("analysis", experiment: false)
        let respond = app.buttons["marker.respond"]
        XCTAssertTrue(respond.waitForExistence(timeout: 5))
        XCTAssertTrue(respond.label.contains("Respond with marker"), respond.label)
        XCTAssertFalse(app.buttons["marker.share"].exists)
        XCTAssertFalse(app.buttons["marker.authorFace"].exists)
        XCTAssertFalse(app.staticTexts["Higher lows into the open"].exists, "the title stays inside General")
        attachScreenshot("legacy-analysis")
    }

    func testLargestTextKeepsTheActionsReachable() throws {
        launch("analysis", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let respond = app.buttons["marker.respond"]
        XCTAssertTrue(respond.waitForExistence(timeout: 5))
        XCTAssertTrue(respond.isHittable || { app.swipeUp(); return respond.isHittable }())
        attachScreenshot("ax-xxxl-refined-analysis")
    }
}
