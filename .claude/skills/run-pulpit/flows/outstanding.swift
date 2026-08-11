import XCTest

/// Plans a meeting from scratch, adds a baby blessing, and checks how it reports as outstanding.
///
/// The reference flow: it covers the wizard, the roster picker's one-off name path, a Form
/// toggle, the meeting outline, and a sheet — most of the app's interaction vocabulary. Copy it
/// as the starting point for a new flow.
final class Flow: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testBabyBlessingIsOutstandingUntilTheFamilyConfirms() {
        app.launch()

        tap(app.buttons["Plan a Meeting"].firstMatch, "Plan a Meeting")
        tap(app.buttons["Start"], "Start")
        advanceWizard(to: "Any blessings?")

        // Add a blessing and name someone to officiate, via the one-off name path.
        tap(app.buttons["Add Blessing of a Child"], "Add Blessing of a Child")
        tap(app.buttons.containing(.staticText, identifier: "Officiating").firstMatch, "Officiating row")
        let search = app.searchFields.firstMatch
        tap(search, "roster search field")
        search.typeText("Mark Nielsen")
        // The label has curly quotes around the name, so match on the tail of it.
        tap(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Just This Once'")).firstMatch,
            "use just this once")

        let family = app.textFields["Family"]
        tap(family, "Family field")
        family.typeText("Nielsen")

        let confirmed = app.switches["Family Confirmed"]
        XCTAssertTrue(confirmed.waitForExistence(timeout: 5), "no Family Confirmed toggle")
        XCTAssertEqual(confirmed.value as? String, "0", "toggle should start off")
        shot("01-ordinances-step")

        // Out through the review step.
        advanceWizard(to: "Review", limit: 5)
        scroll(to: app.staticTexts["Still to fill"], swipes: 6)
        shot("02-wizard-review")
        XCTAssertTrue(app.staticTexts["Family hasn't confirmed the date"].waitForExistence(timeout: 5),
                      "review step didn't say why the blessing is outstanding")
        tap(app.buttons["Done"], "Done")

        // The meeting outline.
        openFirstMeeting()
        XCTAssertTrue(app.staticTexts["Outstanding"].waitForExistence(timeout: 15), "no Outstanding section")

        let reason = app.staticTexts["Family hasn't confirmed the date"]
        XCTAssertTrue(scroll(to: reason, swipes: 4), "no reason under the outstanding blessing")
        shot("03-outline-outstanding")

        // An ordinance carries no assignment status, so nothing should be waiting on the
        // officiator. Sweeping matters here: the list is lazy.
        XCTAssertFalse(appearsWhileScrolling("Not asked"), "officiator still shows a Not asked chip")

        // Tapping an outstanding row opens the item it refers to.
        for _ in 0..<12 where !reason.isHittable { app.swipeDown() }
        reason.tap()
        XCTAssertTrue(app.navigationBars["Blessing of a Child"].waitForExistence(timeout: 15),
                      "tapping the outstanding row didn't open the item editor")
        shot("04-item-editor")

        // Confirming should clear it out of Outstanding.
        flip(app.switches["Family Confirmed"], "Family Confirmed")
        XCTAssertEqual(app.switches["Family Confirmed"].value as? String, "1", "toggle didn't flip")
        app.navigationBars["Blessing of a Child"].buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Outstanding"].waitForExistence(timeout: 15), "didn't return to the outline")
        shot("05-outline-after-confirming")
        XCTAssertFalse(app.staticTexts["Family hasn't confirmed the date"].exists,
                       "still outstanding after the family confirmed")
    }
}
