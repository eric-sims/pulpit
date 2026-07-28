import Foundation

// The wire format, kept deliberately separate from the persistence models.
//
// The SwiftData schema will drift as the app grows; this format must not. Every type here decodes
// defensively — each field is optional or defaulted, so a file written by an older or newer
// version still imports. Enum-shaped fields travel as raw strings and are mapped at the app
// boundary, which means an item kind this version has never heard of survives a round trip
// instead of being silently rewritten.

/// A person, as they travel between copies of the app.
///
/// Note what is absent: roster notes. Private observations about ward members never leave the
/// device, regardless of the export's privacy setting.
public struct PersonDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var fullName: String
    public var preferredName: String?
    public var phoneticSpelling: String?
    public var pronouns: String

    public init(
        id: UUID = UUID(),
        fullName: String,
        preferredName: String? = nil,
        phoneticSpelling: String? = nil,
        pronouns: String = PronounSet.they.rawValue
    ) {
        self.id = id
        self.fullName = fullName
        self.preferredName = preferredName
        self.phoneticSpelling = phoneticSpelling
        self.pronouns = pronouns
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName)
        phoneticSpelling = try container.decodeIfPresent(String.self, forKey: .phoneticSpelling)
        pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
            ?? PronounSet.they.rawValue
    }

    public var pronounSet: PronounSet { PronounSet(tolerant: pronouns) }

    public var scriptPerson: ScriptPerson {
        ScriptPerson(
            fullName: fullName,
            preferredName: preferredName,
            phoneticSpelling: phoneticSpelling,
            pronouns: pronounSet
        )
    }
}

public struct AssignmentDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var role: String
    public var person: PersonDTO?
    /// For visitors and missionaries, who don't belong in a ward roster.
    public var displayNameOverride: String?
    public var topic: String?
    public var status: String
    /// Private: stripped when private notes are excluded from an export.
    public var statusNote: String?
    public var order: Int

    public init(
        id: UUID = UUID(),
        role: AssignmentRole,
        person: PersonDTO? = nil,
        displayNameOverride: String? = nil,
        topic: String? = nil,
        status: AssignmentStatus = .unassigned,
        statusNote: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.role = role.rawValue
        self.person = person
        self.displayNameOverride = displayNameOverride
        self.topic = topic
        self.status = status.rawValue
        self.statusNote = statusNote
        self.order = order
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? AssignmentRole.subject.rawValue
        person = try container.decodeIfPresent(PersonDTO.self, forKey: .person)
        displayNameOverride = try container.decodeIfPresent(String.self, forKey: .displayNameOverride)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? AssignmentStatus.unassigned.rawValue
        statusNote = try container.decodeIfPresent(String.self, forKey: .statusNote)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    public var assignmentRole: AssignmentRole { AssignmentRole(tolerant: role) }
    public var assignmentStatus: AssignmentStatus { AssignmentStatus(tolerant: status) }

    /// The name to show, preferring an explicit override over the linked person.
    public var displayName: String? {
        displayNameOverride ?? person?.fullName
    }
}

/// An individually checkable line within an item — the announcements case.
public struct ItemEntryDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var order: Int
    public var text: String
    public var isChecked: Bool

    public init(id: UUID = UUID(), order: Int = 0, text: String, isChecked: Bool = false) {
        self.id = id
        self.order = order
        self.text = text
        self.isChecked = isChecked
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
    }
}

/// Kind-specific fields. Everything optional — a speaker item populates none of it.
public struct ItemDetailDTO: Codable, Sendable, Hashable {
    public var calling: String?
    public var office: String?
    public var parents: String?

    public init(calling: String? = nil, office: String? = nil, parents: String? = nil) {
        self.calling = calling
        self.office = office
        self.parents = parents
    }

    public var isEmpty: Bool {
        calling == nil && office == nil && parents == nil
    }
}

public struct ProgramItemDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var order: Int
    /// The raw kind string, preserved verbatim so an unrecognized kind survives a round trip.
    public var kind: String
    public var title: String
    /// Private: stripped when private notes are excluded from an export.
    public var notes: String?
    public var status: String
    public var hymnBook: String?
    public var hymnNumber: Int?
    public var scriptOverride: String?
    public var assignments: [AssignmentDTO]
    public var entries: [ItemEntryDTO]
    public var detail: ItemDetailDTO?

    public init(
        id: UUID = UUID(),
        order: Int = 0,
        kind: ItemKind,
        title: String? = nil,
        notes: String? = nil,
        status: ItemStatus = .pending,
        hymnBook: HymnBook? = nil,
        hymnNumber: Int? = nil,
        scriptOverride: String? = nil,
        assignments: [AssignmentDTO] = [],
        entries: [ItemEntryDTO] = [],
        detail: ItemDetailDTO? = nil
    ) {
        self.id = id
        self.order = order
        self.kind = kind.rawValue
        self.title = title ?? kind.defaultTitle
        self.notes = notes
        self.status = status.rawValue
        self.hymnBook = hymnBook?.rawValue
        self.hymnNumber = hymnNumber
        self.scriptOverride = scriptOverride
        self.assignments = assignments
        self.entries = entries
        self.detail = detail
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ItemKind.custom.rawValue
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ItemStatus.pending.rawValue
        hymnBook = try container.decodeIfPresent(String.self, forKey: .hymnBook)
        hymnNumber = try container.decodeIfPresent(Int.self, forKey: .hymnNumber)
        scriptOverride = try container.decodeIfPresent(String.self, forKey: .scriptOverride)
        assignments = try container.decodeIfPresent([AssignmentDTO].self, forKey: .assignments) ?? []
        entries = try container.decodeIfPresent([ItemEntryDTO].self, forKey: .entries) ?? []
        detail = try container.decodeIfPresent(ItemDetailDTO.self, forKey: .detail)
    }

    public var itemKind: ItemKind { ItemKind(tolerant: kind) }
    public var itemStatus: ItemStatus { ItemStatus(tolerant: status) }

    /// True when this version doesn't recognize the item's kind. Such an item imports as a
    /// custom item, keeping its title and raw kind so nothing is lost.
    public var isUnrecognizedKind: Bool {
        ItemKind(rawValue: kind) == nil
    }

    public var hymn: Hymn? {
        guard let hymnNumber else { return nil }
        return HymnCatalog.shared.hymn(book: HymnBook(tolerant: hymnBook), number: hymnNumber)
    }
}

public struct MeetingDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var date: Date
    public var kind: String
    public var unitName: String
    public var theme: String?
    /// Private: stripped when private notes are excluded from an export.
    public var notes: String?
    public var presiding: PersonDTO?
    public var conducting: PersonDTO?
    public var chorister: PersonDTO?
    public var organist: PersonDTO?
    public var items: [ProgramItemDTO]

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: MeetingKind,
        unitName: String = "",
        theme: String? = nil,
        notes: String? = nil,
        presiding: PersonDTO? = nil,
        conducting: PersonDTO? = nil,
        chorister: PersonDTO? = nil,
        organist: PersonDTO? = nil,
        items: [ProgramItemDTO] = []
    ) {
        self.id = id
        self.date = date
        self.kind = kind.rawValue
        self.unitName = unitName
        self.theme = theme
        self.notes = notes
        self.presiding = presiding
        self.conducting = conducting
        self.chorister = chorister
        self.organist = organist
        self.items = items
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? MeetingKind.regular.rawValue
        unitName = try container.decodeIfPresent(String.self, forKey: .unitName) ?? ""
        theme = try container.decodeIfPresent(String.self, forKey: .theme)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        presiding = try container.decodeIfPresent(PersonDTO.self, forKey: .presiding)
        conducting = try container.decodeIfPresent(PersonDTO.self, forKey: .conducting)
        chorister = try container.decodeIfPresent(PersonDTO.self, forKey: .chorister)
        organist = try container.decodeIfPresent(PersonDTO.self, forKey: .organist)
        items = try container.decodeIfPresent([ProgramItemDTO].self, forKey: .items) ?? []
    }

    public var meetingKind: MeetingKind { MeetingKind(tolerant: kind) }

    /// Everyone named anywhere in the meeting, deduplicated by id — what the import preview
    /// matches against your existing roster.
    public var referencedPeople: [PersonDTO] {
        var seen: Set<UUID> = []
        var result: [PersonDTO] = []
        let candidates = [presiding, conducting, chorister, organist].compactMap(\.self)
            + items.flatMap { $0.assignments.compactMap(\.person) }
        for person in candidates where seen.insert(person.id).inserted {
            result.append(person)
        }
        return result
    }
}

public struct AnnouncementDTO: Codable, Sendable, Hashable {
    public var id: UUID
    public var title: String
    public var body: String
    public var lastUsedAt: Date?

    public init(id: UUID = UUID(), title: String, body: String, lastUsedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.lastUsedAt = lastUsedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    }
}

public struct ScriptTemplateDTO: Codable, Sendable, Hashable {
    public var kind: String
    public var body: String
    public var isUserModified: Bool
    public var seedVersion: Int

    public init(kind: ScriptKind, body: String, isUserModified: Bool = false, seedVersion: Int = 0) {
        self.kind = kind.rawValue
        self.body = body
        self.isUserModified = isUserModified
        self.seedVersion = seedVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        isUserModified = try container.decodeIfPresent(Bool.self, forKey: .isUserModified) ?? false
        seedVersion = try container.decodeIfPresent(Int.self, forKey: .seedVersion) ?? 0
    }

    public var scriptKind: ScriptKind? { ScriptKind(tolerant: kind) }
}
