import Foundation

/// One item in a meeting-kind template.
public struct ProgramItemSeed: Sendable, Hashable {
    public let kind: ItemKind
    /// Overrides `kind.defaultTitle` when the template wants something more specific.
    public let titleOverride: String?
    /// Whether this seeds an empty slot the wizard should prompt for and the readiness indicator
    /// should count as outstanding.
    public let needsFilling: Bool

    public init(_ kind: ItemKind, title: String? = nil, needsFilling: Bool = false) {
        self.kind = kind
        self.titleOverride = title
        self.needsFilling = needsFilling
    }

    public var title: String { titleOverride ?? kind.defaultTitle }
}

/// The starting item list for each kind of meeting.
///
/// Templates *seed* a meeting; they never constrain it.
///
/// Individual sustainings, releases and ordinances are deliberately absent — they're occasional,
/// so the wizard asks about them and inserts them at their canonical rank rather than seeding
/// empty slots you'd delete most weeks. The ward business *lead-in* is always seeded, because it
/// gets read every week: on a quiet week it simply says there is none.
public enum MeetingTemplates {

    public static func seed(for kind: MeetingKind) -> [ProgramItemSeed] {
        switch kind {
        case .regular:
            [
                .init(.welcome),
                .init(.announcements),
                .init(.openingHymn, needsFilling: true),
                .init(.invocation, needsFilling: true),
                .init(.wardBusiness),
                .init(.sacramentHymn, needsFilling: true),
                .init(.sacrament),
                .init(.speaker, title: "First Speaker", needsFilling: true),
                .init(.intermediateHymn, needsFilling: true),
                .init(.speaker, title: "Final Speaker", needsFilling: true),
                .init(.closingHymn, needsFilling: true),
                .init(.benediction, needsFilling: true),
            ]

        case .fastAndTestimony:
            // No assigned speakers: the conducting member bears a brief testimony and invites
            // the congregation. Business and ordinances are still conducted as usual.
            [
                .init(.welcome),
                .init(.announcements),
                .init(.openingHymn, needsFilling: true),
                .init(.invocation, needsFilling: true),
                .init(.wardBusiness),
                .init(.sacramentHymn, needsFilling: true),
                .init(.sacrament),
                .init(.testimonyInvitation),
                .init(.closingHymn, needsFilling: true),
                .init(.benediction, needsFilling: true),
            ]

        case .wardConference:
            // The bishop conducts; a member of the stake presidency presides, which is why
            // recognition is seeded rather than optional.
            [
                .init(.welcome),
                .init(.recognitions),
                .init(.announcements),
                .init(.openingHymn, needsFilling: true),
                .init(.invocation, needsFilling: true),
                .init(.wardBusiness),
                .init(.sustaining, title: "Sustaining of Ward Officers", needsFilling: true),
                .init(.sacramentHymn, needsFilling: true),
                .init(.sacrament),
                .init(.speaker, title: "First Speaker", needsFilling: true),
                .init(.speaker, title: "Second Speaker", needsFilling: true),
                .init(.closingHymn, needsFilling: true),
                .init(.benediction, needsFilling: true),
            ]

        case .specialProgram:
            // A fixed frame around a freeform middle, for a Primary presentation or a Christmas
            // or Easter program.
            [
                .init(.welcome),
                .init(.announcements),
                .init(.openingHymn, needsFilling: true),
                .init(.invocation, needsFilling: true),
                .init(.wardBusiness),
                .init(.sacramentHymn, needsFilling: true),
                .init(.sacrament),
                .init(.presentation, needsFilling: true),
                .init(.closingHymn, needsFilling: true),
                .init(.benediction, needsFilling: true),
            ]
        }
    }

    /// The index at which a newly added item of `kind` should land, given the items already
    /// present in order. Falls at the end when nothing outranks it.
    public static func insertionIndex(for kind: ItemKind, in existing: [ItemKind]) -> Int {
        let rank = kind.canonicalRank
        // Insert after the last item that ranks at or below the new one, so several items of the
        // same kind stack in the order they were added.
        for index in existing.indices.reversed() where existing[index].canonicalRank <= rank {
            return index + 1
        }
        return 0
    }
}
