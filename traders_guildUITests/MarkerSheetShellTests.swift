import XCTest

/// Backend-free real ChartBottomSheet composition, not a replica of Add.
final class MarkerSheetShellTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerSheetShellFixture", "-TGAvatarMarkersExperiment", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["guided.postToChart"].waitForExistence(timeout: 15))
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "real-shell-fixture-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func supported(_ route: String) {
        let label = app.staticTexts["shell.policy"].label
        XCTAssertTrue(label.contains(route), label)
        XCTAssertTrue(label.contains("supported: true"), label)
    }
    private func restoreAdd() {
        app.buttons["shell.add"].tap()
        XCTAssertTrue(app.buttons["guided.postToChart"].waitForExistence(timeout: 5))
        supported("add")
    }

    func testRealAddFitsAndItsTabTransitionsStaySupported() throws {
        launch()
        for element in [app.buttons["guided.postToChart"], app.buttons["guided.planTrade"]] {
            if element.exists { XCTAssertTrue(element.isHittable, "\(element) fits without scrolling") }
        }
        supported("add")
        shot("add")
        for (tab, route) in [("symbol", "Symbol"), ("chat", "Chat"), ("components", "Components")] {
            app.buttons["chartSheet.tab.\(tab)"].tap()
            supported(route)
            shot("add-to-\(tab)")
            restoreAdd()
        }
    }

    func testRealShellSelectionClearAndGuidedLegacyExit() throws {
        launch()
        app.buttons["shell.view"].tap()
        supported("view-")
        shot("viewed-marker")
        app.buttons["shell.clear"].tap()
        supported("add")
        XCTAssertTrue(app.buttons["guided.postToChart"].waitForExistence(timeout: 5))
        app.buttons["shell.guide"].tap()
        supported("details-analysis")
        // The type selector is a group of the two type buttons.
        XCTAssertTrue(app.buttons["guided.intent.analysis"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["guided.intent.question"].exists)
        shot("guided-compose")
        app.buttons["shell.legacy"].tap()
        supported("placement")
        restoreAdd()
        shot("returned-add")
    }
}
