import XCTest

/// Moving around the v1.5 marker workspace the way a user does. The sheet
/// opens small (owner decision, 6 Oct 2026), so controls lower in a screen
/// start below the fold: raise the sheet by its grabber, then scroll.
extension XCUIApplication {
    /// Drags the chart sheet up to its tall height by the grabber.
    func raiseMarkerSheet() {
        let grabber = buttons["Sheet Grabber"].firstMatch
        guard grabber.exists else { return }
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)))
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "sheet raised")], timeout: 0.8)
    }

    /// A fast swipe on the workspace's own scroll view: it scrolls without
    /// activating a row (a slow press-and-drag can register as a tap) and,
    /// unlike a swipe on a content element, never makes XCUITest scroll that
    /// element back into view first.
    func scrollMarkerWorkspace() {
        let scroll = scrollViews["guided.screen"].firstMatch
        guard scroll.waitForExistence(timeout: 2) else { return }
        scroll.swipeUp(velocity: .fast)
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "scrolled")], timeout: 0.5)
    }

    /// Brings an element on screen: raise the sheet once, then scroll.
    func revealInMarkerWorkspace(_ element: XCUIElement, scrolls: Int = 5) {
        guard element.waitForExistence(timeout: 5), !element.isHittable else { return }
        raiseMarkerSheet()
        for _ in 0..<scrolls where !element.isHittable { scrollMarkerWorkspace() }
    }

    /// Puts the keyboard away as a user does: dragging the workspace's
    /// content down (it dismisses interactively; no keyboard carries a Done
    /// bar).
    func dismissKeyboardInMarkerWorkspace() {
        let scroll = scrollViews["guided.screen"].firstMatch
        for _ in 0..<3 where keyboards.firstMatch.exists {
            scroll.swipeDown(velocity: .fast)
            _ = keyboards.firstMatch.waitForNonExistence(timeout: 1.5)
        }
    }
}
