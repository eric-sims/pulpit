import Foundation
import PulpitKit
import SwiftUI

/// Holds a file waiting to be reviewed, so a `.pulpitplan` arriving from anywhere — the file
/// picker, Messages, AirDrop, Files — lands in the same preview before anything is written.
@Observable
@MainActor
final class ImportInbox {
    var pending: ImportResult<MeetingDocument>?
    var errorMessage: String?

    var isShowingPreview: Bool {
        get { pending != nil }
        set { if !newValue { pending = nil } }
    }

    /// Whether the failure alert is up.
    ///
    /// Settable, like `isShowingPreview`: SwiftUI records a dismissal by writing `false` back, so
    /// deriving this read-only from `errorMessage` would drop that write and leave the last error
    /// set for the rest of the session. Nothing user-visible turned on it — SwiftUI re-presents
    /// whenever the binding reads true and the alert isn't up — but the state should follow the
    /// alert rather than the OK button having to clear it by hand.
    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    func accept(_ url: URL) {
        // Files handed over by another app live outside the sandbox until asked for.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            pending = try Interchange.decodeMeeting(data)
        } catch let failure as Interchange.Failure {
            errorMessage = failure.description
        } catch {
            errorMessage = "That file couldn't be read. (\(error.localizedDescription))"
        }
    }
}
