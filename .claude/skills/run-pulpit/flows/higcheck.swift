import XCTest

/// Walks the screens touched by the HIG / Liquid Glass pass and photographs each one.
///
/// Not an assertion-heavy flow — the point is the screenshots. What it does assert is the handful
/// of things that would silently regress: that the toolbars still expose the buttons under the
/// names the rest of the suite taps, and that the hymn book switch survived being moved out of the
/// navigation bar.
final class Flow: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testScreensAfterTheHIGPass() {
        app.launch()

        // 1. Tab bar — filled symbols, glass tab bar over the list.
        XCTAssertTrue(app.navigationBars["Meetings"].waitForExistence(timeout: 15), "not on Meetings")
        shot("01-meetings-tab")

        // 2. Wizard, first screen: Cancel leading, prominent Start trailing.
        tap(app.buttons["Plan a Meeting"].firstMatch, "Plan a Meeting")
        shot("02-wizard-basics")

        // 3. Wizard, a later step: Back and Cancel both leading with a gap, prominent Next.
        tap(app.buttons["Start"], "Start")
        XCTAssertTrue(app.navigationBars["Who is presiding?"].waitForExistence(timeout: 15),
                      "wizard didn't start")
        tap(app.buttons["Next"], "Next")
        XCTAssertTrue(app.navigationBars["What are the songs?"].waitForExistence(timeout: 15),
                      "no music step")
        XCTAssertTrue(app.buttons["Back"].exists, "the wizard lost its Back button")
        shot("03-wizard-music-step")

        // 4. Hymn picker — the book switch and sacrament filter now sit under the navigation bar
        //    rather than inside it.
        tap(app.buttons.containing(.staticText, identifier: "Hymn").firstMatch, "a hymn slot")
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 15),
                      "the hymnbook picker didn't survive the move out of the toolbar")
        shot("04-hymn-picker")
        // Both the wizard and this sheet have a Cancel, so scope it to the sheet's own bar.
        tap(app.navigationBars["Opening Hymn"].buttons["Cancel"], "Cancel out of the hymn picker")

        // 5. Out through the wizard to the outline.
        advanceWizard(to: "Review", limit: 8)
        tap(app.buttons["Done"], "Done")
        openFirstMeeting()
        XCTAssertTrue(app.buttons["Export"].waitForExistence(timeout: 15), "no Export button")
        XCTAssertTrue(app.buttons["Edit"].exists, "no Edit button")
        shot("05-outline")

        // 6. Conducting — pinned bars with no painted background, prominent Done, ellipsis menu.
        tap(app.buttons.containing(.staticText, identifier: "Conduct This Meeting").firstMatch,
            "Conduct This Meeting")
        XCTAssertTrue(app.staticTexts["Now"].waitForExistence(timeout: 15), "no pinned Now bar")
        shot("06-conducting")

        // 7. The options menu, in title case.
        tap(app.buttons["Options"], "Options menu")
        XCTAssertTrue(app.buttons["Larger Text"].waitForExistence(timeout: 15),
                      "options menu didn't open")
        shot("07-conducting-menu")
    }
}
