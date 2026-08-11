import XCTest

/// Hands the app two files it can't read, one after the other.
///
/// This is the only coverage of the import failure path: a file arriving by document type, the
/// decode failing, the alert naming the reason, and the app still being usable afterwards. Two
/// files rather than one because the interesting state is what a *second* failure does with the
/// error left over from the first.
///
/// Worth knowing what this does **not** prove. It was written to guard the presentation binding
/// behind these alerts, and it doesn't: swapping `$inbox.isShowingError` back for a read-only
/// `.constant(inbox.errorMessage != nil)` leaves this test passing. SwiftUI re-presents whenever
/// the binding reads true and the alert isn't currently up, so the dropped write never surfaces
/// here. The writable binding is still the right construction — it's the documented contract, and
/// it clears the error instead of leaving it set forever — but it isn't load-bearing for anything
/// this flow can see.
final class Flow: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Writes a file the importer will refuse: not JSON, so `Interchange.decodeMeeting` throws
    /// and `ImportInbox` records the failure.
    private func writeUnreadablePlan(_ name: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try Data("this is not a meeting plan".utf8).write(to: url)
        return url
    }

    private func dismissImportError(_ occasion: String) {
        let alert = app.alerts["Couldn't Open File"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30),
                      "a malformed plan raised no alert (\(occasion))")
        tap(alert.buttons["OK"], "OK (\(occasion))")
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10),
                      "the alert would not dismiss (\(occasion))")
    }

    func testEveryUnreadableFileReportsItsOwnError() throws {
        app.launch()

        // Routes through the system by document type, the same path as AirDrop or Messages.
        XCUIDevice.shared.system.open(try writeUnreadablePlan("broken-first.pulpitplan"))
        dismissImportError("first file")
        shot("01-import-error")

        // The error has to have been cleared for this one to show at all.
        XCUIDevice.shared.system.open(try writeUnreadablePlan("broken-second.pulpitplan"))
        dismissImportError("second file")
        shot("02-second-import-error")

        XCTAssertTrue(app.navigationBars["Meetings"].waitForExistence(timeout: 10),
                      "didn't land back on the meetings list")
    }
}
