import XCTest

/// Proves the conducting view honours Dynamic Type.
///
/// It sizes its text in points so the in-meeting stepper can push past normal limits, which used
/// to mean it ignored the system text size outright. Run this against a meeting that already
/// exists — `driver.sh flow higcheck` leaves one behind — and compare `02-conducting-ax5` with
/// `01-conducting-default`: the same screen at two system text sizes.
final class Flow: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func openConducting() {
        openFirstMeeting()
        tap(app.buttons.containing(.staticText, identifier: "Conduct This Meeting").firstMatch,
            "Conduct This Meeting")
        XCTAssertTrue(app.staticTexts["Now"].waitForExistence(timeout: 15), "conducting didn't open")
    }

    func testConductingViewScalesWithTheSystemTextSize() {
        // Default size, for comparison.
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openConducting()
        let defaultHeight = app.staticTexts["Welcome"].firstMatch.frame.height
        shot("01-conducting-default")
        app.terminate()

        // Accessibility Extra Extra Extra Large — the largest the system offers.
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        openConducting()
        let largeHeight = app.staticTexts["Welcome"].firstMatch.frame.height
        shot("02-conducting-ax5")

        XCTAssertGreaterThan(
            largeHeight, defaultHeight,
            "conducting text did not grow with the system text size (\(defaultHeight) → \(largeHeight))"
        )
    }
}
