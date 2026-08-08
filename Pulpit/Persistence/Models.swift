import Foundation
import PulpitKit
import SwiftData

// Every stored property here is optional or has a default, and every relationship is optional.
// That's CloudKit's requirement, not SwiftData's — paying it now is what makes turning on sync
// later a change to the ModelConfiguration rather than a migration.
//
// Enum-shaped values are stored as raw strings so an unfamiliar value from an imported file
// degrades to a sensible default instead of failing to load.

@Model
final class Person {
    var id: UUID = UUID()
    var fullName: String = ""
    var preferredName: String?
    /// An explicit form of address that outranks Brother/Sister — "President", "Bishop", "Elder".
    var title: String?
    /// A reading aid for names you'd otherwise mangle. Never spoken as part of a script.
    var phoneticSpelling: String?
    var pronounsRaw: String = PronounSet.he.rawValue
    /// Private. Never leaves the device: the interchange format has no field for it.
    var notes: String?
    var isActive: Bool = true
    var createdAt: Date = Date()

    // Nothing reads these — they exist so that deleting someone from the roster clears every
    // reference to them. A to-one relationship with no inverse isn't maintained on delete: the
    // reference is left pointing at a row that's gone, and reading it later traps rather than
    // returning nil. CloudKit requires the inverses too, for the same reason the rest of this
    // file is shaped the way it is.
    @Relationship(deleteRule: .nullify, inverse: \Assignment.person)
    var assignments: [Assignment]?

    @Relationship(deleteRule: .nullify, inverse: \Meeting.presiding)
    var presidingAt: [Meeting]?

    @Relationship(deleteRule: .nullify, inverse: \Meeting.conducting)
    var conductingAt: [Meeting]?

    @Relationship(deleteRule: .nullify, inverse: \Meeting.chorister)
    var choristerAt: [Meeting]?

    @Relationship(deleteRule: .nullify, inverse: \Meeting.organist)
    var organistAt: [Meeting]?

    init(
        fullName: String = "",
        preferredName: String? = nil,
        title: String? = nil,
        phoneticSpelling: String? = nil,
        pronouns: PronounSet = .he
    ) {
        self.fullName = fullName
        self.preferredName = preferredName
        self.title = title
        self.phoneticSpelling = phoneticSpelling
        self.pronounsRaw = pronouns.rawValue
    }

    var pronouns: PronounSet {
        get { PronounSet(tolerant: pronounsRaw) }
        set { pronounsRaw = newValue.rawValue }
    }

    var scriptPerson: ScriptPerson {
        ScriptPerson(
            fullName: fullName,
            preferredName: preferredName,
            title: title,
            phoneticSpelling: phoneticSpelling,
            pronouns: pronouns
        )
    }

    /// "President Paul Weeks" — how the name would be read aloud.
    var addressedName: String { scriptPerson.addressedName }
}

@Model
final class Assignment {
    var id: UUID = UUID()
    var roleRaw: String = AssignmentRole.subject.rawValue
    var person: Person?
    /// For visitors and full-time missionaries, who don't belong in a ward roster.
    var displayNameOverride: String?
    var topic: String?
    /// The calling lives here rather than on the item: one sustaining commonly covers several
    /// people in several different callings, read in turn before a single vote.
    var callingText: String?
    var officeText: String?
    var statusRaw: String = AssignmentStatus.unassigned.rawValue
    /// Private. Stripped from shared exports.
    var statusNote: String?
    var order: Int = 0
    var item: ProgramItem?

    init(role: AssignmentRole = .subject, person: Person? = nil, order: Int = 0) {
        self.roleRaw = role.rawValue
        self.person = person
        self.order = order
    }

    var role: AssignmentRole {
        get { AssignmentRole(tolerant: roleRaw) }
        set { roleRaw = newValue.rawValue }
    }

    var status: AssignmentStatus {
        get { AssignmentStatus(tolerant: statusRaw) }
        set { statusRaw = newValue.rawValue }
    }

    /// The name to show, preferring an explicit override over the linked roster entry.
    var displayName: String? {
        if let displayNameOverride, !displayNameOverride.isEmpty { return displayNameOverride }
        return person?.fullName
    }

    var isFilled: Bool { displayName?.isEmpty == false }

    /// Whether this assignment is still waiting on you before Sunday.
    ///
    /// Kinds that don't track status never qualify — an ordinance would otherwise sit at "Not
    /// asked" forever, since its editor offers no status to change.
    var needsFollowUp: Bool {
        guard item?.kind.tracksAssignmentStatus ?? true else { return false }
        return isFilled && status.needsFollowUp
    }

    var scriptSubject: ScriptSubject? {
        let scriptPerson: ScriptPerson
        if let person {
            scriptPerson = person.scriptPerson
        } else if let displayNameOverride, !displayNameOverride.isEmpty {
            scriptPerson = ScriptPerson(fullName: displayNameOverride)
        } else {
            return nil
        }
        return ScriptSubject(person: scriptPerson, calling: callingText, office: officeText)
    }
}

/// An individually checkable line within an item. Announcements are the driving case — you may
/// read four of six, and the block shouldn't look finished until every line is done.
@Model
final class ItemEntry {
    var id: UUID = UUID()
    var order: Int = 0
    var text: String = ""
    var isChecked: Bool = false
    /// Set when this line came from the reusable announcement library.
    var announcementID: UUID?
    var item: ProgramItem?

    init(text: String = "", order: Int = 0) {
        self.text = text
        self.order = order
    }
}

@Model
final class ProgramItem {
    var id: UUID = UUID()
    var order: Int = 0
    var kindRaw: String = ItemKind.custom.rawValue
    var title: String = ""
    /// Private. Stripped from shared exports.
    var notes: String?
    var statusRaw: String = ItemStatus.pending.rawValue
    var resolvedAt: Date?
    var hymnBookRaw: String?
    var hymnNumber: Int?
    /// Per-instance wording, edited without disturbing the saved template.
    var scriptOverride: String?
    /// The family's surname, for a blessing of a child.
    var familyName: String?
    /// Whether the family has confirmed the blessing will take place at this meeting.
    var familyConfirmed: Bool = false
    /// Seeded slots the wizard should ask about and the readiness indicator should count.
    var needsFilling: Bool = false
    var meeting: Meeting?

    @Relationship(deleteRule: .cascade, inverse: \Assignment.item)
    var assignments: [Assignment]?

    @Relationship(deleteRule: .cascade, inverse: \ItemEntry.item)
    var entries: [ItemEntry]?

    init(kind: ItemKind = .custom, title: String? = nil, order: Int = 0, needsFilling: Bool = false) {
        self.kindRaw = kind.rawValue
        self.title = title ?? kind.defaultTitle
        self.order = order
        self.needsFilling = needsFilling
        self.assignments = []
        self.entries = []
    }

    var kind: ItemKind {
        get { ItemKind(tolerant: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(tolerant: statusRaw) }
        set { statusRaw = newValue.rawValue }
    }

    var orderedAssignments: [Assignment] {
        (assignments ?? []).sorted { $0.order < $1.order }
    }

    var orderedEntries: [ItemEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }

    var hymn: Hymn? {
        guard let hymnNumber else { return nil }
        return HymnCatalog.shared.hymn(book: HymnBook(tolerant: hymnBookRaw), number: hymnNumber)
    }

    func setHymn(_ hymn: Hymn?) {
        hymnBookRaw = hymn?.book.rawValue
        hymnNumber = hymn?.number
    }

    /// Whether this item still has something outstanding.
    ///
    /// Business items are checked whether or not the template seeded them: a sustaining with a
    /// name but no calling reads "has been called." from the pulpit, which is grammatical enough
    /// to slip past you. Better to surface it here than to discover it mid-meeting.
    var isIncomplete: Bool {
        if kind == .sustaining || kind == .release {
            let subjects = orderedAssignments.filter { $0.role == .subject && $0.isFilled }
            if subjects.contains(where: { ($0.callingText ?? "").isEmpty }) { return true }
        }
        if kind == .ordinationProposal {
            let subjects = orderedAssignments.filter { $0.role == .subject && $0.isFilled }
            if subjects.contains(where: { ($0.officeText ?? "").isEmpty }) { return true }
        }
        // A blessing is outstanding until the family says it's happening this Sunday. It stands in
        // for the assignment status an ordinance doesn't carry, and it's the one detail that
        // genuinely still moves late in the week.
        if kind == .babyBlessing && !familyConfirmed { return true }
        guard needsFilling else { return false }
        if kind.isHymn { return hymn == nil }
        if !kind.assignableRoles.isEmpty { return !orderedAssignments.contains(where: \.isFilled) }
        return false
    }

    /// Why this item is outstanding, for the cases where the title alone wouldn't say.
    var incompleteReason: String? {
        guard isIncomplete else { return nil }
        if kind == .babyBlessing && !familyConfirmed { return "Family hasn't confirmed the date" }
        return nil
    }
}

@Model
final class Meeting {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = MeetingKind.regular.rawValue
    var unitName: String = ""
    var theme: String?
    /// Private. Stripped from shared exports.
    var notes: String?
    var presiding: Person?
    var conducting: Person?
    var chorister: Person?
    var organist: Person?
    /// Set when conducting mode is entered, for the elapsed-time readout.
    var conductingStartedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ProgramItem.meeting)
    var items: [ProgramItem]?

    init(date: Date = Date(), kind: MeetingKind = .regular, unitName: String = "") {
        self.date = date
        self.kindRaw = kind.rawValue
        self.unitName = unitName
        self.items = []
    }

    var kind: MeetingKind {
        get { MeetingKind(tolerant: kindRaw) }
        set { kindRaw = newValue.rawValue }
    }

    var orderedItems: [ProgramItem] {
        (items ?? []).sorted { $0.order < $1.order }
    }

    /// Slots still to fill before Sunday.
    var incompleteItems: [ProgramItem] {
        orderedItems.filter(\.isIncomplete)
    }

    /// Assignments asked for but not yet confirmed.
    var unconfirmedAssignments: [Assignment] {
        orderedItems
            .flatMap(\.orderedAssignments)
            .filter(\.needsFollowUp)
    }

    var isReady: Bool {
        incompleteItems.isEmpty && unconfirmedAssignments.isEmpty
    }

    /// Renumbers items 0..<n after a reorder or an insertion.
    func normalizeOrder() {
        for (index, item) in orderedItems.enumerated() {
            item.order = index
        }
        updatedAt = Date()
    }
}

@Model
final class Announcement {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var isLibraryItem: Bool = true
    var lastUsedAt: Date?

    init(title: String = "", body: String = "") {
        self.title = title
        self.body = body
    }
}

@Model
final class ScriptTemplate {
    var id: UUID = UUID()
    var kindRaw: String = ""
    var body: String = ""
    /// Once you've edited a template, a future update to the shipped defaults leaves it alone.
    var isUserModified: Bool = false
    var seedVersion: Int = 0

    init(kind: ScriptKind, body: String, seedVersion: Int) {
        self.kindRaw = kind.rawValue
        self.body = body
        self.seedVersion = seedVersion
    }

    var kind: ScriptKind? { ScriptKind(tolerant: kindRaw) }

    /// True when the shipped wording has moved on and this template hasn't been edited.
    var isOutOfDate: Bool {
        !isUserModified && seedVersion < DefaultScripts.currentSeedVersion
    }
}
