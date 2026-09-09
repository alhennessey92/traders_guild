import XCTest

/// What VoiceOver would actually reach in the linked-marker surfaces.
///
/// This does not replace driving VoiceOver by hand — it cannot prove how the
/// rotor moves or how speech sounds. What it does prove is the part that
/// silently regresses: that the elements exist, carry labels rather than raw
/// glyph names, and that relationship is spoken as a word instead of being
/// carried by colour. That claim has been made in review notes for a while
/// without anything checking it.
///
/// Runs against the DEBUG fixture gallery (`-MarkerLinkFixtures`), so it needs
/// no backend, no account and no seeded data, and it contains no credentials.
final class MarkerLinkAccessibilityTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-MarkerLinkFixtures"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Every relationship this build understands must be reachable as a word.
    ///
    /// The design deliberately encodes relationship four ways — dash pattern,
    /// ring, badge and text — precisely so it never depends on hue. If the text
    /// disappears, the feature stops working for colour-blind users and in
    /// bright sunlight, and nothing else in the suite would notice.
    func testRelationshipIsSpokenAsAWordNotCarriedByColour() throws {
        let gallery = app.descendants(matching: .any)
        XCTAssertTrue(
            gallery.firstMatch.waitForExistence(timeout: 10),
            "the fixture gallery must come up; it is DEBUG-only, so check the configuration"
        )

        for word in ["Supports", "Challenges", "Builds on"] {
            let matches = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", word)
            )
            XCTAssertGreaterThan(
                matches.count, 0,
                "\"\(word)\" must appear as text somewhere in the linked-marker surfaces"
            )
        }
    }

    /// No element a user can *act on* may be labelled with a symbol name.
    ///
    /// Deliberately scoped to interactive elements. An earlier version of this
    /// test asserted that no image anywhere carried a raw SF Symbol name, and
    /// it failed — but not for the reason it looked like. XCUITest's descendant
    /// enumeration is not VoiceOver's element order: a row using
    /// `accessibilityElement(children: .combine)` still exposes its child images
    /// to this query, while VoiceOver stops only on the combined element. The
    /// strict version was therefore measuring a surface no user reaches, and
    /// "fixing" the app to satisfy it would have been changing production code
    /// to make a test pass.
    ///
    /// What remains is the part that is genuinely user-visible and genuinely
    /// verifiable here: anything focusable and actionable must read as prose.
    ///
    /// Known and deliberately not asserted: `UnifiedMarkerBadge` renders intent
    /// symbols (`waveform.path.ecg.magnifyingglass` and friends) with no label
    /// of their own. That is app-wide chrome that predates linked markers, not
    /// something this feature introduced, and it is recorded in the tree
    /// snapshot below rather than silently swallowed.
    func testNoActionableElementIsLabelledWithASymbolName() throws {
        XCTAssertTrue(app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 10))

        let offenders = app.buttons.allElementsBoundByAccessibilityElement
            .map(\.label)
            .filter { label in
                !label.isEmpty
                    && label.contains(".")
                    && !label.contains(" ")
                    && label == label.lowercased()
            }

        XCTAssertTrue(
            offenders.isEmpty,
            "actionable elements reading as SF Symbol names: \(offenders.sorted())"
        )
    }

    /// A tappable row must say it is tappable. Rows that cannot be opened —
    /// the marker being read, and unavailable tombstones — must not, or
    /// VoiceOver offers a destination that does not exist.
    func testOnlyOpenableRowsAdvertiseThemselvesAsButtons() throws {
        XCTAssertTrue(app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 10))

        // The unavailable copy is fixed wording, so it is safe to assert on.
        let unavailable = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "unavailable marker")
        )
        for index in 0..<unavailable.count {
            let element = unavailable.element(boundBy: index)
            guard element.exists else { continue }
            XCTAssertFalse(
                element.isHittable && element.elementType == .button,
                "a marker that is gone must not be offered as a destination"
            )
        }
    }

    /// A snapshot of what VoiceOver would encounter, attached to the result
    /// bundle. Not an assertion — a record, so a future reviewer can see what
    /// changed without re-deriving it.
    func testCaptureAccessibilityTreeForReview() throws {
        XCTAssertTrue(app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 10))

        let labels = app.descendants(matching: .any)
            .allElementsBoundByAccessibilityElement
            .map { "\($0.elementType.rawValue)\t\($0.label)" }
            .filter { !$0.hasSuffix("\t") }
            .sorted()

        // Raw symbol names are called out rather than left for a reader to spot.
        let rawSymbolNames = labels.filter { line in
            guard let label = line.split(separator: "\t").last.map(String.init) else { return false }
            return label.contains(".") && !label.contains(" ") && label == label.lowercased()
        }
        let report = """
        # Elements VoiceOver could encounter in the linked-marker fixtures
        # Format: <elementType>\t<label>
        # Raw SF Symbol names found: \(rawSymbolNames.count)
        \(rawSymbolNames.joined(separator: "\n"))

        # Full tree
        \(labels.joined(separator: "\n"))
        """
        let attachment = XCTAttachment(string: report)
        attachment.name = "marker-link-accessibility-tree"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertGreaterThan(
            labels.count, 0,
            "an empty tree means the gallery did not render, not that it is accessible"
        )
    }
}
