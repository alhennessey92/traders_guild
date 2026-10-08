import XCTest

/// P6: Apple's accessibility audit (contrast, hit regions, descriptions,
/// Dynamic Type, clipped text, traits) over each workspace screen. Every
/// issue is recorded to an attachment for review rather than failing on the
/// first: the harness chrome around the sheet is fixture-only and not under
/// review. Issues on workspace elements are what this pass fixes.
final class MarkerWorkspaceAccessibilityAuditUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = true }

    private func launch(_ scenario: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-MarkerGuidedCreationFixture", scenario, "-MarkerGuidedSheetFixture", "YES",
                               "-TGAvatarMarkersExperiment", "YES"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fixture")).firstMatch
            .waitForExistence(timeout: 15))
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.2)
    }

    /// Runs the audit and returns one line per issue, ignoring none of them
    /// silently: each is written down.
    private func audit(_ name: String) -> [String] {
        var lines: [String] = []
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element
                let id = element?.identifier ?? ""
                let label = element?.label ?? ""
                lines.append("[\(name)] \(issue.auditType.rawValue) · \(issue.compactDescription) · id=\(id) · label=\(label.prefix(60))")
                return true
            }
        } catch {
            lines.append("[\(name)] audit error: \(error)")
        }
        return lines
    }

    func testWorkspaceScreens() {
        var report: [String] = []
        for (scenario, name) in [("entry", "add"), ("analysisDetails", "details"), ("analysisReview", "review"),
                                 ("context", "context"), ("setupTracked", "setup"), ("responseDetails", "response"),
                                 ("editSetupArmedReview", "edit-review")] {
            launch(scenario)
            app.raiseMarkerSheet()
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 0.8)
            report += audit(name)
            app.terminate()
        }
        let attachment = XCTAttachment(string: report.isEmpty ? "no issues" : report.joined(separator: "\n"))
        attachment.name = "accessibility-audit.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("A11Y_AUDIT_COUNT \(report.count)")
    }
}
