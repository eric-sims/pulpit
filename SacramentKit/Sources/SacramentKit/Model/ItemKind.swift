import Foundation

/// One part of a meeting program, following the order in the General Handbook (29.2).
///
/// Every meeting is an *ordered list* of these rather than a fixed set of named fields. That's
/// what lets a ward conference, a Primary program, and an unplanned baby blessing inserted at
/// 11:04am all live in the same model.
public enum ItemKind: String, Codable, CaseIterable, Sendable, Hashable {
    // Opening
    case welcome
    case recognitions
    case announcements
    case openingHymn
    case invocation

    // Business
    /// The lead-in to ward business, which is read every week — including the weeks when it
    /// amounts to "there is no ward business."
    case wardBusiness
    case release
    case sustaining
    case ordinationProposal
    case newMemberWelcome
    case movingInRecord
    /// Occasional: the time is turned over to someone from the stake.
    case stakeBusiness

    // Ordinances performed in the meeting
    case babyBlessing
    case confirmation

    // The sacrament
    case sacramentHymn
    case sacrament

    // The body of the meeting
    case speaker
    case intermediateHymn
    case musicalNumber
    case testimonyInvitation
    case presentation

    // Closing
    case closingHymn
    case benediction

    /// Anything the app doesn't recognize, including items imported from a future version.
    case custom

    // MARK: - Display

    public var defaultTitle: String {
        switch self {
        case .welcome: "Welcome"
        case .recognitions: "Recognition of Presiding Authority"
        case .announcements: "Announcements"
        case .openingHymn: "Opening Hymn"
        case .invocation: "Invocation"
        case .wardBusiness: "Ward Business"
        case .release: "Release"
        case .sustaining: "Sustaining"
        case .ordinationProposal: "Proposal for Ordination"
        case .newMemberWelcome: "New Members"
        case .movingInRecord: "Records of Membership Received"
        case .stakeBusiness: "Stake Business"
        case .babyBlessing: "Blessing of a Child"
        case .confirmation: "Confirmation"
        case .sacramentHymn: "Sacrament Hymn"
        case .sacrament: "Administration of the Sacrament"
        case .speaker: "Speaker"
        case .intermediateHymn: "Intermediate Hymn"
        case .musicalNumber: "Musical Number"
        case .testimonyInvitation: "Bearing of Testimonies"
        case .presentation: "Program"
        case .closingHymn: "Closing Hymn"
        case .benediction: "Benediction"
        case .custom: "Item"
        }
    }

    // MARK: - Grouping

    /// Actual ward business: the things that need presenting and a vote.
    ///
    /// Deliberately excludes `.wardBusiness` itself — that's the lead-in, and whether it says
    /// "there is no ward business" depends on whether any of *these* are present.
    public var isBusiness: Bool {
        switch self {
        case .release, .sustaining, .ordinationProposal, .newMemberWelcome, .movingInRecord: true
        default: false
        }
    }

    /// Ordinances performed during the meeting. The app records only what's needed to announce
    /// them correctly — it is not a membership record.
    public var isOrdinance: Bool {
        switch self {
        case .babyBlessing, .confirmation: true
        default: false
        }
    }

    public var isHymn: Bool {
        switch self {
        case .openingHymn, .sacramentHymn, .intermediateHymn, .closingHymn: true
        default: false
        }
    }

    public var isPrayer: Bool {
        switch self {
        case .invocation, .benediction: true
        default: false
        }
    }

    // MARK: - Behavior

    /// The sacrament itself cannot be removed from a meeting.
    public var isDeletable: Bool {
        self != .sacrament
    }

    /// Only a hymn item may carry a hymn number, and only a sacrament hymn slot is validated
    /// against the sacrament section of the hymnbook.
    public var requiresSacramentHymn: Bool {
        self == .sacramentHymn
    }

    /// Items whose body is a list of individually checkable lines rather than a single script.
    /// Announcements are the driving case — you may read four of six.
    public var supportsEntries: Bool {
        switch self {
        case .announcements, .recognitions, .presentation: true
        default: false
        }
    }

    /// Which roles can be assigned to this item. An empty set means the item takes no people.
    public var assignableRoles: [AssignmentRole] {
        switch self {
        case .invocation: [.invocation]
        case .benediction: [.benediction]
        case .speaker: [.speaker]
        case .musicalNumber, .intermediateHymn: [.musician]
        case .babyBlessing, .confirmation: [.officiator, .subject]
        case .ordinationProposal, .release, .sustaining: [.subject]
        case .newMemberWelcome, .movingInRecord, .stakeBusiness: [.subject]
        case .presentation: [.musician, .speaker]
        default: []
        }
    }

    /// Whether each person in this item carries their own calling. One sustaining commonly covers
    /// several people in several different callings, read in turn before a single vote.
    public var takesCallingPerPerson: Bool {
        self == .sustaining || self == .release
    }

    /// The script template that supplies this item's default wording, if any.
    public var scriptKind: ScriptKind? {
        switch self {
        case .welcome: .welcome
        case .recognitions: .recognition
        case .wardBusiness: .wardBusiness
        case .stakeBusiness: .stakeBusiness
        case .sustaining: .sustaining
        case .release: .release
        case .ordinationProposal: .ordinationProposal
        case .newMemberWelcome: .newMemberWelcome
        case .movingInRecord: .movingInRecord
        case .babyBlessing: .babyBlessing
        case .confirmation: .confirmation
        case .sacrament: .sacramentTransition
        case .testimonyInvitation: .testimonyInvitation
        default: nil
        }
    }

    /// Where this kind sits in the Handbook's order, used to drop a newly added item into a
    /// sensible position.
    ///
    /// A heuristic for insertion, never a constraint — every item is freely reorderable, and some
    /// placements genuinely vary by ward. An intermediate hymn belongs *between* speakers, which
    /// a single rank can't express, and ordinances get moved either side of the sacrament
    /// depending on local practice.
    public var canonicalRank: Int {
        switch self {
        case .welcome: 10
        case .recognitions: 20
        case .announcements: 30
        case .openingHymn: 40
        case .invocation: 50
        // Ward business, releases before new sustainings.
        case .wardBusiness: 55
        case .release: 60
        case .sustaining: 61
        case .ordinationProposal: 62
        case .newMemberWelcome: 63
        case .movingInRecord: 64
        case .stakeBusiness: 66
        // Ordinances performed in the meeting.
        case .confirmation: 70
        case .babyBlessing: 71
        case .sacramentHymn: 80
        case .sacrament: 90
        case .speaker: 100
        case .testimonyInvitation: 100
        case .presentation: 100
        case .custom: 105
        case .intermediateHymn: 110
        case .musicalNumber: 111
        case .closingHymn: 120
        case .benediction: 130
        }
    }

    /// Unknown values decode to `.custom`. The interchange layer preserves the original raw
    /// string alongside, so re-exporting an imported file doesn't destroy information.
    ///
    /// This is also how items from before prelude and postlude were removed still load: they
    /// arrive as custom items keeping the titles they were saved with.
    public init(tolerant raw: String?) {
        self = raw.flatMap(ItemKind.init(rawValue:)) ?? .custom
    }
}
