import XCTest

/// The app under test.
///
/// Addressed by bundle id because this test bundle has **no host application** — it drives
/// whatever build of Pulpit is currently installed on the booted simulator. That's what
/// keeps the harness outside the app's own Xcode project.
let app = XCUIApplication(bundleIdentifier: "com.ericsims.pulpit")

extension XCTestCase {

    /// A screenshot that survives into the .xcresult, where `driver.sh` exports it by this name.
    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The whole accessibility tree, as text.
    ///
    /// The debugging workhorse. SwiftUI's element shapes are rarely what you'd guess — see the
    /// Gotchas in SKILL.md — and one look at the tree settles it faster than any amount of
    /// guessing at queries.
    func dumpHierarchy(_ name: String = "hierarchy") {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for an element, then taps it, failing with a useful name rather than "element not found".
    func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "never found \(what)")
        element.tap()
    }

    /// Flips a `Toggle`.
    ///
    /// A Toggle in a Form exposes one element spanning the entire row, so the obvious
    /// `switch.tap()` lands on the label and does nothing at all — silently. The control sits at
    /// the trailing edge.
    func flip(_ toggle: XCUIElement, _ what: String, timeout: TimeInterval = 15) {
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout), "never found \(what)")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Walks the new-meeting wizard forward until `title` is showing.
    ///
    /// The number of steps varies with the meeting kind (a fast and testimony meeting has no
    /// speakers step), and the confirmation button reads "Skip" or "Next" depending on whether the
    /// step has anything in it. Matching on the destination beats counting taps.
    func advanceWizard(to title: String, limit: Int = 10) {
        let destination = app.navigationBars[title]
        for _ in 0..<limit {
            if destination.exists { return }
            let next = app.buttons["Next"].exists ? app.buttons["Next"] : app.buttons["Skip"]
            tap(next, "Next/Skip on the way to \(title)")
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "never reached \(title)")
    }

    /// Scrolls down until `element` is on screen, returning whether it ever showed up.
    ///
    /// A SwiftUI `List` is lazy, so an element that has never been scrolled into view is genuinely
    /// absent from the accessibility tree — `exists` is false for a row that is merely below the
    /// fold. Anything asserting presence *or absence* in a long list has to sweep it.
    @discardableResult
    func scroll(to element: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Whether `label` shows up anywhere in a lazily rendered list, sweeping it top to bottom.
    /// The honest way to assert a chip or badge is *absent* from a whole screen.
    func appearsWhileScrolling(_ label: String, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if app.staticTexts[label].exists { return true }
            app.swipeUp()
        }
        return app.staticTexts[label].exists
    }

    /// Opens the first meeting from the Meetings list.
    ///
    /// Not `app.cells.firstMatch` — in a SwiftUI List that resolves to the *section header*
    /// ("Upcoming"), and tapping it does nothing. The row is a Button whose label is every line of
    /// the row run together: "Sunday, Aug 9, 2026, Regular, 10 to fill".
    func openFirstMeeting() {
        XCTAssertTrue(app.navigationBars["Meetings"].waitForExistence(timeout: 15), "not on the Meetings list")
        // The readiness badge is the one part of the label that's always there.
        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'to fill' OR label CONTAINS 'unconfirmed' OR label CONTAINS 'Ready'")
        ).firstMatch
        tap(row, "the first meeting row")
    }
}
