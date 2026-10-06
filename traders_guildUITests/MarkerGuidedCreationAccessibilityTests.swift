import XCTest

/// What VoiceOver and large-text users meet in v1.5 guided creation.
///
/// Like `MarkerLinkAccessibilityTests`, this cannot prove how speech sounds or
/// how the rotor moves; it proves the parts that silently regress: controls
/// exist with prose labels, price fields say what they are, the selected type
/// is named by the type menu, and at the largest accessibility text size the
/// layout keeps every control reachable.
///
/// Runs against the backend-free guided-creation harness
/// (`-MarkerGuidedCreationFixture <scenario> -TGAvatarMarkersExperiment YES`),
/// which exists in isolated DEV builds only, so it needs no account, data or
/// network and contains no credentials. Theme and text-size runs attach
/// screenshots to the result bundle as review evidence.
final class MarkerGuidedCreationAccessibilityTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func launch(_ scenario: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments += ["-MarkerGuidedCreationFixture", scenario, "-TGAvatarMarkersExperiment", "YES"] + extra
        app.launch()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
                .waitForExistence(timeout: 15),
            "the guided harness must come up; it is isolated-DEV only, so check the configuration"
        )
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func attachTree(_ name: String) {
        let labels = app.descendants(matching: .any)
            .allElementsBoundByAccessibilityElement
            .map { element -> String in
                let traits = element.isSelected ? " [selected]" : ""
                let enabled = element.isEnabled ? "" : " [dimmed]"
                return "\(element.elementType.rawValue)\t\(element.label)\(traits)\(enabled)"
            }
            .filter { !$0.contains("\t ") && !$0.hasSuffix("\t") }
        let attachment = XCTAttachment(string: labels.joined(separator: "\n"))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var symbolNamedButtons: [String] {
        app.buttons.allElementsBoundByAccessibilityElement
            .map(\.label)
            .filter { !$0.isEmpty && $0.contains(".") && !$0.contains(" ") && $0 == $0.lowercased() }
    }

    // MARK: VoiceOver

    func testDetailsControlsSpeakProseAndExposeTheSelectedType() throws {
        launch("analysisDetails")
        let picker = app.otherElements["guided.intentPicker"]
        XCTAssertTrue(picker.exists)
        XCTAssertTrue(app.buttons["guided.intent.analysis"].isSelected)
        XCTAssertTrue(app.buttons["guided.review"].exists)
        XCTAssertTrue(symbolNamedButtons.isEmpty, "buttons reading as SF Symbol names: \(symbolNamedButtons)")
        let question = app.buttons["guided.intent.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap()
        XCTAssertTrue(app.buttons["guided.intent.question"].isSelected)
        attachTree("tree-analysisDetails")
    }

    func testSetupPriceFieldsSayWhatTheyAre() throws {
        launch("setupTracked")
        XCTAssertTrue(app.textFields["Take Profit"].waitForExistence(timeout: 5), "the TP field is labelled")
        XCTAssertTrue(app.textFields["Stop Loss"].exists, "the SL field is labelled")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Entry")).firstMatch.exists,
            "the Entry row is read as text"
        )
        XCTAssertTrue(symbolNamedButtons.isEmpty, "buttons reading as SF Symbol names: \(symbolNamedButtons)")
        attachTree("tree-setupTracked")
    }

    /// Review's summary lines carry decorative icons. VoiceOver must hear the
    /// line, not the symbol's name.
    ///
    /// Asserted on the combined line, which is where VoiceOver stops. As
    /// `MarkerLinkAccessibilityTests` records, XCUITest also enumerates the
    /// children of a combined element, so a raw image query would count icons
    /// VoiceOver never reaches; those children are hidden and excluded from the
    /// spoken label, which is what this checks.
    func testReviewLinesDoNotSpeakSymbolNames() throws {
        launch("setupMarketMoved")
        XCTAssertTrue(app.buttons["guided.adjustLevels"].waitForExistence(timeout: 5))
        for (spoken, symbol) in [
            ("Tracked: counts toward accuracy and reputation", "scope"),
            ("Challenges sam's BTC breakout", "relationship icon"),
        ] {
            let line = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", spoken)).firstMatch
            XCTAssertTrue(line.exists, "\(spoken) is reachable")
            XCTAssertEqual(line.label, spoken, "the line speaks its text only, not \(symbol)")
        }
        let failure = app.staticTexts["Couldn't post"]
        XCTAssertTrue(failure.exists)
        XCTAssertFalse(failure.label.contains("Warning"), "the warning glyph is not spoken separately")
    }

    /// The step is announced as a heading that says where the author is and
    /// what is asked, and a disabled Review always says why.
    func testDetailsNamesTheStepAndWhatIsMissing() throws {
        launch("analysisEmpty")
        let header = app.staticTexts["guided.stepHeader"].exists
            ? app.staticTexts["guided.stepHeader"]
            : app.otherElements["guided.stepHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("Write analysis"), header.label)
        XCTAssertTrue(header.label.contains("Step 1 of 2"), header.label)

        let review = app.buttons["guided.review"]
        XCTAssertFalse(review.isEnabled, "nothing written yet")
        XCTAssertEqual(app.staticTexts["guided.nextStep"].label, "Write your analysis to continue")

        let text = app.textViews["guided.text"].exists ? app.textViews["guided.text"] : app.textFields["guided.text"]
        text.tap()
        text.typeText("Range low is holding.")
        XCTAssertTrue(review.isEnabled, "writing enables Review")
        XCTAssertFalse(app.staticTexts["guided.nextStep"].exists, "nothing left to ask for")
        review.tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "will see this on the chart")).firstMatch
                .waitForExistence(timeout: 5),
            "Review says who will see the post"
        )
        attachTree("tree-analysisEmpty-to-review")
    }

    func testSetupStaysOutOfTheSocialSelector() throws {
        launch("analysisDetails")
        XCTAssertTrue(app.buttons["guided.intent.analysis"].exists)
        XCTAssertTrue(app.buttons["guided.intent.question"].exists)
        XCTAssertFalse(app.buttons["guided.intent.setup"].exists)
        XCTAssertFalse(app.buttons["guided.changeType"].exists)
    }

    func testResponseConvertsWithinDetails() throws {
        launch("responseDetails")
        let convert = app.buttons["guided.convertResponse"]
        // The sheet opens small (6 Oct 2026): raise it, then scroll.
        app.revealInMarkerWorkspace(convert)
        XCTAssertTrue(convert.isHittable)
        convert.tap()
        XCTAssertTrue(app.textFields["Take Profit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["marker.response.timeframe"].exists)
    }

    func testSetupHasLevelsAndReasoningInOneDetails() throws {
        launch("setupTracked")
        XCTAssertFalse(app.buttons["guided.next"].exists)
        XCTAssertTrue(app.textFields["Take Profit"].exists)
        XCTAssertTrue(app.textFields["Stop Loss"].exists)
        XCTAssertTrue(app.textViews["guided.text"].exists)
        XCTAssertTrue(app.buttons["guided.review"].isEnabled)
        attachScreenshot("final-setup-details")
    }

    func testAnalysisWorkingHeightKeepsOptionalControlsReachable() throws {
        launch("analysisEmpty")
        let text = app.textViews["guided.text"].exists ? app.textViews["guided.text"] : app.textFields["guided.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        for element in [app.buttons["guided.intentPicker"], text, app.buttons["guided.addTitle"],
                        app.buttons["guided.addContext"]] {
            XCTAssertTrue(element.isHittable, "\(element) is on screen")
        }
        attachScreenshot("working-sheet-analysis")
    }

    /// Optional extras stay out of the way until asked for.
    func testTheTitleIsAddedOnRequest() throws {
        launch("analysisEmpty")
        XCTAssertFalse(app.textFields["guided.title"].exists, "no title field until asked")
        app.buttons["guided.addTitle"].tap()
        XCTAssertTrue(app.textFields["guided.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["guided.addTitle"].exists)
    }

    func testAMovedMarketExplainsAndOffersTheWayBack() throws {
        launch("setupMarketMoved")
        let adjust = app.buttons["guided.adjustLevels"]
        XCTAssertTrue(adjust.waitForExistence(timeout: 5))
        XCTAssertEqual(adjust.label, "Adjust levels")
        XCTAssertFalse(app.buttons["guided.post"].isEnabled, "Retry is unavailable until the levels are fixed")
        attachTree("tree-setupMarketMoved")
        // Tapping scrolls it into view if needed; reaching Details proves it is
        // reachable and does what it says.
        adjust.tap()
        XCTAssertTrue(
            app.textFields["Stop Loss"].waitForExistence(timeout: 5),
            "Adjust levels returns to the editable levels"
        )
    }

    // MARK: Dynamic Type

    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    func testLargestTextKeepsTheTypeMenuReachable() throws {
        launch("analysisDetails", extra: Self.largestText)
        let picker = app.otherElements["guided.intentPicker"]
        if !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.waitForExistence(timeout: 5) && picker.isHittable)
        XCTAssertTrue(app.buttons["guided.intent.question"].waitForExistence(timeout: 5))
        attachScreenshot("ax-xxxl-type-menu")
    }

    func testLargestTextKeepsPostReachable() throws {
        launch("setupReview", extra: Self.largestText)
        let post = app.buttons["guided.post"]
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        // The real sheet's bottom bar is 68 pt; the capped button must fit it.
        XCTAssertLessThanOrEqual(post.frame.height, 68, "Post fits the fixed bar: \(post.frame)")
        attachScreenshot("ax-xxxl-setupReview")
        attachTree("tree-ax-xxxl-setupReview")
        post.tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "share prompt handoff")).firstMatch
                .waitForExistence(timeout: 5),
            "Post is reachable at the largest text size and posts"
        )
    }

    // MARK: Themes

    func testThemesRenderTheGuidedSheet() throws {
        for theme in ["dark", "midGrey", "lightGrey"] {
            for scenario in ["analysisEmpty", "setupTracked", "analysisReview"] {
                launch(scenario, extra: ["-appTheme", theme])
                attachScreenshot("theme-\(theme)-\(scenario)")
                app.terminate()
            }
        }
    }
}
