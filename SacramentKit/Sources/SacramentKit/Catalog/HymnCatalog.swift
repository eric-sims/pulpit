import Foundation

/// The bundled hymn reference data.
///
/// Deliberately *not* stored in SwiftData. Reference data doesn't belong in the user's store:
/// keeping it out means no seeding step on first launch, no migration when a new batch of hymns is
/// released, and updating the catalog is a file replacement plus a version bump.
///
/// To add a newly released batch: append entries to `Resources/hymns.json`, raise
/// `catalogVersion`, and update `HymnCatalogTests.expectedCounts`.
public struct HymnCatalog: Sendable {
    public let catalogVersion: Int
    public let verifiedOn: String
    public let hymns: [Hymn]

    private let byID: [String: Hymn]

    public init(hymns: [Hymn], catalogVersion: Int = 0, verifiedOn: String = "") {
        self.hymns = hymns
        self.catalogVersion = catalogVersion
        self.verifiedOn = verifiedOn
        self.byID = Dictionary(hymns.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Loading

    private struct CatalogFile: Decodable {
        let catalogVersion: Int
        let verifiedOn: String
        let hymns: [Hymn]
    }

    public enum LoadError: Error, CustomStringConvertible {
        case resourceMissing

        public var description: String {
            switch self {
            case .resourceMissing: "hymns.json is missing from the SacramentKit bundle."
            }
        }
    }

    public static func load() throws -> HymnCatalog {
        guard let url = Bundle.module.url(forResource: "hymns", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        let file = try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url))
        return HymnCatalog(
            hymns: file.hymns,
            catalogVersion: file.catalogVersion,
            verifiedOn: file.verifiedOn
        )
    }

    /// The bundled catalog, loaded once.
    ///
    /// Traps on failure by design: a missing or malformed bundled resource is a build defect, not
    /// a runtime condition worth degrading for.
    public static let shared: HymnCatalog = {
        do {
            return try load()
        } catch {
            preconditionFailure("Bundled hymn catalog failed to load: \(error)")
        }
    }()

    // MARK: - Lookup

    public func hymn(book: HymnBook, number: Int) -> Hymn? {
        byID["\(book.rawValue)-\(number)"]
    }

    public func hymns(in book: HymnBook) -> [Hymn] {
        hymns.filter { $0.book == book }
    }

    /// Hymns published in the sacrament section, for the sacrament-slot picker.
    public var sacramentHymns: [Hymn] {
        hymns.filter { $0.sacramentSuitability == .yes }
    }

    /// Matches a number typed on its own, or any word in the title.
    ///
    /// Number matches rank above title matches, because when you type "169" you mean the hymn, not
    /// every hymn with 169 somewhere in its name.
    public func search(_ query: String, in book: HymnBook? = nil) -> [Hymn] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pool = book.map { hymns(in: $0) } ?? hymns
        guard !trimmed.isEmpty else { return pool }

        if let number = Int(trimmed) {
            let exact = pool.filter { $0.number == number }
            let prefixed = pool.filter { $0.number != number && String($0.number).hasPrefix(trimmed) }
            return exact + prefixed
        }

        let needle = trimmed.lowercased()
        let starts = pool.filter { $0.title.lowercased().hasPrefix(needle) }
        let contains = pool.filter {
            !$0.title.lowercased().hasPrefix(needle) && $0.title.lowercased().contains(needle)
        }
        return starts + contains
    }
}
