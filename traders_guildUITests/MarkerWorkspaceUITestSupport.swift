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
        guard element.waitForExistence(timeout: 5), !isRevealedInMarkerWorkspace(element) else { return }
        raiseMarkerSheet()
        for _ in 0..<scrolls where !isRevealedInMarkerWorkspace(element) { scrollMarkerWorkspace() }
    }

    /// Hittable, and — for the sheet's content — clear of the footer bar,
    /// which is drawn over the scrolling content: XCUITest can call a tile
    /// half under it "hittable" while a tap at its centre lands on the footer
    /// (iPhone SE, 10 Oct 2026).
    func isRevealedInMarkerWorkspace(_ element: XCUIElement) -> Bool {
        guard element.isHittable else { return false }
        let footerIDs = ["guided.back", "guided.review", "guided.contextDone", "guided.post", "guided.save"]
        guard !footerIDs.contains(element.identifier) else { return true }
        let footerTop = footerIDs.map { buttons[$0] }.filter { $0.exists }.map(\.frame.minY).min()
        guard let footerTop else { return true }
        // The bar's padding sits above its buttons.
        return element.frame.maxY <= footerTop - 12
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
