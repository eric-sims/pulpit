import Foundation

/// A hymn as placed in a specific slot of a meeting.
public struct HymnPlacement: Sendable, Hashable {
    public let itemKind: ItemKind
    public let hymn: Hymn

    public init(itemKind: ItemKind, hymn: Hymn) {
        self.itemKind = itemKind
        self.hymn = hymn
    }
}

/// Something worth flagging about a meeting's music. Advisory only — never blocking.
public enum HymnWarning: Sendable, Hashable, Identifiable {
    /// A hymn published outside the sacrament section has been placed in the sacrament slot.
    case notASacramentHymn(Hymn)
    /// The same hymn appears more than once in one meeting.
    case duplicate(Hymn)

    public var id: String {
        switch self {
        case .notASacramentHymn(let hymn): "sacrament-\(hymn.id)"
        case .duplicate(let hymn): "duplicate-\(hymn.id)"
        }
    }

    public var message: String {
        switch self {
        case .notASacramentHymn(let hymn):
            "“\(hymn.title)” isn't in the sacrament section of the hymnbook."
        case .duplicate(let hymn):
            "“\(hymn.title)” is used twice in this meeting."
        }
    }
}

public enum HymnValidator {

    /// Advisory warnings for a meeting's hymn choices.
    ///
    /// Note what is *not* flagged: a hymn whose sacrament suitability is `.unknown`. The new
    /// hymnbook hasn't published its topical sections yet, and warning on absent data would train
    /// you to ignore warnings — which is worse than not warning at all.
    public static func warnings(for placements: [HymnPlacement]) -> [HymnWarning] {
        var warnings: [HymnWarning] = []

        for placement in placements
        where placement.itemKind.requiresSacramentHymn && placement.hymn.sacramentSuitability == .no {
            warnings.append(.notASacramentHymn(placement.hymn))
        }

        var seen: Set<String> = []
        var alreadyReported: Set<String> = []
        for placement in placements {
            let id = placement.hymn.id
            if seen.contains(id), !alreadyReported.contains(id) {
                warnings.append(.duplicate(placement.hymn))
                alreadyReported.insert(id)
            }
            seen.insert(id)
        }

        return warnings
    }
}
