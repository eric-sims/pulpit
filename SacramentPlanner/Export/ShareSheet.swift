import SwiftUI
import UIKit

/// The system share sheet, for handing an exported file to Messages, Mail, Files or anything else.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A file on disk waiting to be shared. Identifiable so it can drive `.sheet(item:)`.
struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
