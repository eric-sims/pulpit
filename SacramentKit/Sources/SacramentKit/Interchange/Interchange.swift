import Foundation

/// Reading and writing the `.sacramentplan` interchange format.
///
/// The importer is deliberately forgiving. A file from a newer version of the app still imports —
/// every DTO decodes field by field with defaults — and anything the current version can't make
/// sense of is reported as a note rather than thrown as an error. The only genuine failure is a
/// file that isn't this format at all.
public enum Interchange {

    public static let currentFormatVersion = 1
    public static let fileExtension = "sacramentplan"
    /// Reverse-DNS identifier for the custom `UTType` the app declares.
    public static let typeIdentifier = "com.ericsims.sacramentplanner.plan"
    public static let generator = "SacramentPlanner/1"

    public enum Failure: Error, CustomStringConvertible {
        case notAPlanFile(underlying: String)

        public var description: String {
            switch self {
            case .notAPlanFile(let underlying):
                "This doesn't look like a sacrament meeting plan. (\(underlying))"
            }
        }
    }

    // MARK: - Coders

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Stable key order keeps exported files diffable and makes round-trip tests meaningful.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Encoding

    /// Encodes a single meeting for sharing.
    ///
    /// `includePrivateNotes` defaults to false: sharing a meeting shouldn't quietly hand over
    /// notes you wrote for yourself.
    public static func encode(
        meeting: MeetingDTO,
        includePrivateNotes: Bool = false,
        exportedAt: Date = Date()
    ) throws -> Data {
        var document = MeetingDocument(
            meeting: meeting,
            exportedAt: exportedAt,
            includesPrivateNotes: includePrivateNotes
        )
        if !includePrivateNotes {
            document = document.redactingPrivateNotes()
        }
        return try makeEncoder().encode(document)
    }

    public static func encode(library: LibraryDocument) throws -> Data {
        try makeEncoder().encode(library)
    }

    // MARK: - Decoding

    public static func decodeMeeting(_ data: Data) throws -> ImportResult<MeetingDocument> {
        let document: MeetingDocument
        do {
            document = try makeDecoder().decode(MeetingDocument.self, from: data)
        } catch {
            throw Failure.notAPlanFile(underlying: String(describing: error))
        }
        return ImportResult(document: document, notes: notes(for: document))
    }

    public static func decodeLibrary(_ data: Data) throws -> ImportResult<LibraryDocument> {
        let document: LibraryDocument
        do {
            document = try makeDecoder().decode(LibraryDocument.self, from: data)
        } catch {
            throw Failure.notAPlanFile(underlying: String(describing: error))
        }
        var notes: [ImportNote] = []
        if document.formatVersion > currentFormatVersion {
            notes.append(.newerFormatVersion(found: document.formatVersion, supported: currentFormatVersion))
        }
        let unrecognized = unrecognizedKinds(in: document.meetings)
        if !unrecognized.isEmpty {
            notes.append(.unrecognizedItemKinds(unrecognized))
        }
        return ImportResult(document: document, notes: notes)
    }

    private static func notes(for document: MeetingDocument) -> [ImportNote] {
        var notes: [ImportNote] = []
        if document.formatVersion > currentFormatVersion {
            notes.append(.newerFormatVersion(found: document.formatVersion, supported: currentFormatVersion))
        }
        let unrecognized = unrecognizedKinds(in: [document.meeting])
        if !unrecognized.isEmpty {
            notes.append(.unrecognizedItemKinds(unrecognized))
        }
        if !document.includesPrivateNotes {
            notes.append(.privateNotesExcluded)
        }
        return notes
    }

    private static func unrecognizedKinds(in meetings: [MeetingDTO]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for meeting in meetings {
            for item in meeting.items where item.isUnrecognizedKind {
                if seen.insert(item.kind).inserted { ordered.append(item.kind) }
            }
        }
        return ordered
    }

    // MARK: - Filenames

    /// "2026-08-02 Sacrament Meeting.sacramentplan"
    public static func suggestedFilename(for meeting: MeetingDTO) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let name = "\(formatter.string(from: meeting.date)) \(meeting.meetingKind.displayName)"
        return "\(sanitized(name)).\(fileExtension)"
    }

    static func sanitized(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "-")
    }
}

// MARK: - Roster matching

/// A person in a file, paired with the best guess at who they already are in your roster.
///
/// Matching is *suggested*, never automatic: two people in a ward genuinely can share a name, and
/// silently merging them would corrupt the roster in a way that's tedious to unpick.
public struct PersonMatch: Sendable, Hashable, Identifiable {
    public let incoming: PersonDTO
    /// The id of an existing roster entry that appears to be the same person.
    public let suggestedExistingID: UUID?
    public let isExactNameMatch: Bool

    public var id: UUID { incoming.id }
    public var isNewToRoster: Bool { suggestedExistingID == nil }

    public init(incoming: PersonDTO, suggestedExistingID: UUID?, isExactNameMatch: Bool) {
        self.incoming = incoming
        self.suggestedExistingID = suggestedExistingID
        self.isExactNameMatch = isExactNameMatch
    }
}

public enum RosterMatcher {
    /// Pairs each person in an incoming meeting with an existing roster entry where one looks
    /// like the same person. An id match is definitive; otherwise names are compared
    /// case- and whitespace-insensitively.
    public static func match(
        incoming: [PersonDTO],
        against existing: [(id: UUID, fullName: String)]
    ) -> [PersonMatch] {
        let byID = Dictionary(existing.map { ($0.id, $0.fullName) }, uniquingKeysWith: { first, _ in first })
        var byName: [String: UUID] = [:]
        for entry in existing {
            byName[normalize(entry.fullName)] = byName[normalize(entry.fullName)] ?? entry.id
        }

        return incoming.map { person in
            if byID[person.id] != nil {
                return PersonMatch(incoming: person, suggestedExistingID: person.id, isExactNameMatch: true)
            }
            if let matched = byName[normalize(person.fullName)] {
                return PersonMatch(incoming: person, suggestedExistingID: matched, isExactNameMatch: true)
            }
            return PersonMatch(incoming: person, suggestedExistingID: nil, isExactNameMatch: false)
        }
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
