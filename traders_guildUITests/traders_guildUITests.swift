//
//  traders_guildUITests.swift
//  traders_guildUITests
//
//  Created by Al Hennessey on 16/07/2025.
//

import XCTest

final class traders_guildUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testSignupHappyPath() throws {
        throw XCTSkip("Requires full iOS simulator + backend test environment configuration.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testLoginByEmail() throws {
        throw XCTSkip("Requires seeded backend user + simulator environment.")
    }

    @MainActor
    func testLoginByUsername() throws {
        throw XCTSkip("Requires seeded backend user + simulator environment.")
    }

    @MainActor
    func testForgotRequestAndResetCompletion() throws {
        throw XCTSkip("Requires email reset link fixture and deep-link harness.")
    }

    @MainActor
    func testGuildPickerDisplaysBackendOwnerDataAndSolidBottomBar() throws {
        throw XCTSkip("Requires mocked guild data injection in UI test runtime.")
    }

    @MainActor
    func testNoAuthTestViewRoutes() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertFalse(app.otherElements["TestView"].exists)
    }
}
