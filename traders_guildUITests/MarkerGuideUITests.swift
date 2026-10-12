import XCTest

/// "How markers work" (owner, 12 Oct): opens from Markers ▸ Add, shows the
/// example and every part of the key, and closes back to Add.
final class MarkerGuideUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTheGuideOpensFromAddAndExplainsEveryPart() {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", "entry", "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        let link = app.buttons["guided.markerGuide"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        app.revealInMarkerWorkspace(link)
        link.tap()

        XCTAssertTrue(app.descendants(matching: .any)["markerGuide"].firstMatch.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.containing(.staticText, identifier: "Face").firstMatch
        XCTAssertTrue(app.staticTexts["How markers work"].exists)
        capture("guide-top")

        for heading in ["WHAT IT IS", "CONTEXT ARCS", "ALERTS", "SETUPS", "REPLIES"] {
            let text = app.staticTexts[heading]
            var swipes = 0
            while !(text.exists && text.isHittable) && swipes < 8 {
                scroll.swipeUp(velocity: .slow)
                swipes += 1
            }
            XCTAssertTrue(text.exists, heading)
            capture("guide-\(heading.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }

        app.buttons["markerGuide.close"].tap()
        XCTAssertTrue(link.waitForExistence(timeout: 5))
    }
}
