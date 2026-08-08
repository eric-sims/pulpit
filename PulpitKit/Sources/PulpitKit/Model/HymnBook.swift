import Foundation

/// Which book a hymn number refers to.
///
/// The two books have separate numbering, so a hymn reference is only meaningful as a
/// (book, number) pair. *Hymns—For Home and Church* numbers start at 1001, with seasonal music
/// in a separate 1201+ range.
public enum HymnBook: String, Codable, CaseIterable, Sendable, Hashable {
    case hymns1985
    case homeAndChurch

    public var displayName: String {
        switch self {
        case .hymns1985: "Hymns (1985)"
        case .homeAndChurch: "Hymns—For Home and Church"
        }
    }

    public var shortName: String {
        switch self {
        case .hymns1985: "Hymns"
        case .homeAndChurch: "H&C"
        }
    }

    public init(tolerant raw: String?) {
        self = raw.flatMap(HymnBook.init(rawValue:)) ?? .hymns1985
    }
}

/// Whether a hymn belongs in the sacrament slot.
///
/// Three-valued on purpose. The 1985 hymnbook publishes a sacrament section, so membership is
/// knowable either way. *Hymns—For Home and Church* is still a rolling release with no topical
/// sections published, so for those hymns the answer is genuinely unknown — and the app must not
/// warn on data it doesn't have.
public enum SacramentSuitability: String, Codable, CaseIterable, Sendable, Hashable {
    case yes
    case no
    case unknown

    public init(tolerant raw: String?) {
        self = raw.flatMap(SacramentSuitability.init(rawValue:)) ?? .unknown
    }
}

/// A single hymn. Reference data only — title, number, and classification.
///
/// No lyrics and no music: the 1985 hymnbook and the *Home and Church* arrangements are
/// copyrighted. Titles, numbers, and section membership are facts and are all this app needs.
public struct Hymn: Codable, Sendable, Hashable, Identifiable {
    public let book: HymnBook
    public let number: Int
    public let title: String
    /// Section slugs from the hymnbook's own organization, e.g. "sacrament", "christmas".
    /// Empty for hymns in a book that hasn't published its sections yet.
    public let sections: [String]
    public let sacramentSuitability: SacramentSuitability
    /// Release date for rolling-release hymns, absent for the 1985 book.
    public let released: String?

    public var id: String { "\(book.rawValue)-\(number)" }

    public init(
        book: HymnBook,
        number: Int,
        title: String,
        sections: [String] = [],
        sacramentSuitability: SacramentSuitability = .unknown,
        released: String? = nil
    ) {
        self.book = book
        self.number = number
        self.title = title
        self.sections = sections
        self.sacramentSuitability = sacramentSuitability
        self.released = released
    }

    /// "169 — As Now We Take the Sacrament"
    public var displayLabel: String {
        "\(number) — \(title)"
    }

    /// "Hymns 169" — how you'd write it on a program.
    public var citation: String {
        "\(book.shortName) \(number)"
    }
}
