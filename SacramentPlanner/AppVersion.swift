import Foundation

/// Which build of the app this is, for the Settings screen and for anyone reporting a problem.
///
/// Nothing here is typed by hand. Xcode already stamps `MARKETING_VERSION` and
/// `CURRENT_PROJECT_VERSION` into the built Info.plist as `CFBundleShortVersionString` and
/// `CFBundleVersion` — the same pair the App Store and TestFlight show — so reading them back
/// through `Bundle.main` means the screen can't drift from the build that's running. Bumping the
/// version is then a change to build settings, which is where the App Store reads it from too.
///
/// The commit is the one piece Xcode doesn't know: it's written into the bundle as GitCommit.txt
/// by the "Stamp git commit" build phase. A build made without that phase, or from a source drop
/// with no git history, simply has no commit to show.
enum AppVersion {
    /// The public version, e.g. "0.1". `MARKETING_VERSION` in build settings.
    static let marketing = infoString("CFBundleShortVersionString") ?? "unknown"

    /// The build, e.g. "1". `CURRENT_PROJECT_VERSION`, and what tells two TestFlight uploads of
    /// the same version apart.
    static let build = infoString("CFBundleVersion") ?? "unknown"

    /// Short commit hash, suffixed "-dirty" when the tree had uncommitted changes at build time.
    /// `nil` when the stamping phase didn't run.
    static let commit = stampedCommit()

    /// "0.1 (1)" — the form Apple uses wherever it prints a version.
    static var displayVersion: String { "\(marketing) (\(build))" }

    private static func infoString(_ key: String) -> String? {
        nonEmpty(Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    private static func stampedCommit() -> String? {
        guard let url = Bundle.main.url(forResource: "GitCommit", withExtension: "txt") else { return nil }
        return nonEmpty(try? String(contentsOf: url, encoding: .utf8))
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
