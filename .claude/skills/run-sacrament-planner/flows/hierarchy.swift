import XCTest

/// Launches the app and dumps the accessibility tree of the first screen.
///
/// Start here whenever a query isn't matching. Add navigation before the dump to inspect a screen
/// further in — `dumpHierarchy()` can be called as many times as you like, each with its own name.
final class Flow: XCTestCase {

    func testDumpFirstScreen() {
        app.launch()
        XCTAssertTrue(app.navigationBars["Meetings"].waitForExistence(timeout: 30), "app never came up")
        shot("00-launch")
        dumpHierarchy("00-launch-tree")
    }
}
