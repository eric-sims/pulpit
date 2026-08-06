import Foundation
import SacramentKit
import SwiftUI

/// Holds a file waiting to be reviewed, so a `.sacramentplan` arriving from anywhere — the file
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
