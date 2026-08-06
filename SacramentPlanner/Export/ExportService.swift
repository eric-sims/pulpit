import Foundation
import SacramentKit
import UIKit
import WebKit

/// Turns a meeting into a file on disk, ready to hand to the share sheet.
@MainActor
enum ExportService {

    enum Failure: LocalizedError {
        case pdfRenderingFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .pdfRenderingFailed(let detail): "The PDF couldn't be created. (\(detail))"
            case .writeFailed(let detail): "The file couldn't be saved. (\(detail))"
            }
        }
    }

    // MARK: - PDF

    /// Renders the conducting sheet to a PDF and returns its location in a temporary directory.
    ///
    /// A `WKWebView` is held off-screen just long enough to lay out and print. It has to be in a
    /// window to render at all, so it's added at zero opacity and removed as soon as it's done.
    static func conductingSheetPDF(
        for meeting: Meeting,
        templates: [ScriptTemplate],
        includePrivateNotes: Bool
    ) async throws -> URL {
        let html = ConductingSheetHTML.document(
            for: meeting,
            templates: templates,
            includePrivateNotes: includePrivateNotes
        )

        let webView = WKWebView(frame: CGRect(origin: .zero, size: PagePDFRenderer.paper.size))
        webView.isOpaque = false
        webView.alpha = 0

        let host = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        host?.addSubview(webView)
        defer { webView.removeFromSuperview() }

        try await load(html, into: webView)

        // Deliberately *not* WKWebView.pdf(configuration:). That captures a single rectangular
        // slice of the content, so anything past the first page — or past the right edge — is
        // silently dropped. UIPrintPageRenderer reflows the content to the printable width and
        // paginates it properly, which is what a document of variable-length scripts needs.
        let data = PagePDFRenderer(formatter: webView.viewPrintFormatter()).render()
        guard !data.isEmpty else {
            throw Failure.pdfRenderingFailed("no pages were produced")
        }

        return try write(data, named: filename(for: meeting, extension: "pdf"))
    }

    /// Waits for the web view to finish loading before printing, so the PDF isn't blank.
    private static func load(_ html: String, into webView: WKWebView) async throws {
        let delegate = LoadWaiter()
        webView.navigationDelegate = delegate
        webView.loadHTMLString(html, baseURL: nil)
        try await delegate.wait()
        webView.navigationDelegate = nil
        // One run-loop turn for layout to settle before asking WebKit to paginate.
        try? await Task.sleep(for: .milliseconds(120))
    }

    // MARK: - Interchange

    /// Writes the `.sacramentplan` file for sharing with another user of the app.
    static func interchangeFile(
        for meeting: Meeting,
        includePrivateNotes: Bool
    ) throws -> URL {
        let dto = InterchangeMapper.dto(for: meeting)
        let data = try Interchange.encode(meeting: dto, includePrivateNotes: includePrivateNotes)
        return try write(data, named: Interchange.suggestedFilename(for: dto))
    }

    /// Writes the whole library. With storage local-only, this is the real backup.
    static func backupFile(
        meetings: [Meeting],
        announcements: [Announcement],
        templates: [ScriptTemplate]
    ) throws -> URL {
        let library = InterchangeMapper.library(
            meetings: meetings,
            announcements: announcements,
            templates: templates
        )
        let data = try Interchange.encode(library: library)
        let stamp = Date().formatted(.iso8601.year().month().day())
        return try write(data, named: "Sacrament Planner Backup \(stamp).\(Interchange.fileExtension)")
    }

    // MARK: - Files

    private static func filename(for meeting: Meeting, extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let base = "\(formatter.string(from: meeting.date)) \(meeting.kind.displayName)"
        return "\(Interchange.sanitized(base)).\(ext)"
    }

    /// Each export goes in its own subdirectory so two exports with the same name don't collide
    /// while both are still being shared.
    private static func write(_ data: Data, named name: String) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: name)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw Failure.writeFailed(error.localizedDescription)
        }
    }
}

/// Paginates a print formatter onto US Letter pages.
///
/// `paperRect` and `printableRect` are read-only on `UIPrintPageRenderer`, so they're overridden
/// rather than set — which avoids the usual KVC trick for the same job.
/// `nonisolated` because the project defaults types to the main actor, and these overrides have
/// to match the non-isolated declarations they're overriding.
private nonisolated final class PagePDFRenderer: UIPrintPageRenderer {
    static let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 40

    override var paperRect: CGRect { Self.paper }
    override var printableRect: CGRect { Self.paper.insetBy(dx: Self.margin, dy: Self.margin) }

    init(formatter: UIViewPrintFormatter) {
        super.init()
        addPrintFormatter(formatter, startingAtPageAt: 0)
    }

    func render() -> Data {
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paperRect, nil)
        prepare(forDrawingPages: NSRange(location: 0, length: numberOfPages))
        for page in 0..<numberOfPages {
            UIGraphicsBeginPDFPage()
            drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

/// Bridges `WKNavigationDelegate` callbacks into async/await.
private final class LoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished = false
    private var failure: Error?

    func wait() async throws {
        if finished { return }
        if let failure { throw failure }
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finished = true
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        failure = error
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        failure = error
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
