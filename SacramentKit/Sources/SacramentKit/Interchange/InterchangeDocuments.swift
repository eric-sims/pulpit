import Foundation

/// A single meeting, shared with another user of the app.
public struct MeetingDocument: Codable, Sendable, Hashable {
    public var formatVersion: Int
    public var generator: String
    public var exportedAt: Date
    /// Records whether the sender chose to include private notes, so the recipient knows what
    /// they're looking at.
    public var includesPrivateNotes: Bool
    public var meeting: MeetingDTO

    public init(
        meeting: MeetingDTO,
        formatVersion: Int = Interchange.currentFormatVersion,
        generator: String = Interchange.generator,
        exportedAt: Date = Date(),
        includesPrivateNotes: Bool = false
    ) {
        self.formatVersion = formatVersion
        self.generator = generator
        self.exportedAt = exportedAt
        self.includesPrivateNotes = includesPrivateNotes
        self.meeting = meeting
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        generator = try container.decodeIfPresent(String.self, forKey: .generator) ?? "unknown"
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        includesPrivateNotes = try container.decodeIfPresent(Bool.self, forKey: .includesPrivateNotes) ?? false
        meeting = try container.decode(MeetingDTO.self, forKey: .meeting)
    }

    /// A copy with everything private removed.
    ///
    /// Conducting notes can carry things that should not leave your phone — the circumstances
    /// behind a release, a note about someone's health. Export defaults to excluding them.
    public func redactingPrivateNotes() -> MeetingDocument {
        var copy = self
        copy.includesPrivateNotes = false
        copy.meeting.notes = nil
        copy.meeting.items = copy.meeting.items.map { item in
            var item = item
            item.notes = nil
            item.assignments = item.assignments.map { assignment in
                var assignment = assignment
                assignment.statusNote = nil
                return assignment
            }
            return item
        }
        return copy
    }
}

/// Every meeting, plus the roster-adjacent libraries. Doubles as the backup file, which matters
/// more than usual while storage is local-only.
public struct LibraryDocument: Codable, Sendable, Hashable {
    public var formatVersion: Int
    public var generator: String
    public var exportedAt: Date
    public var includesPrivateNotes: Bool
    public var meetings: [MeetingDTO]
    public var announcements: [AnnouncementDTO]
    public var scriptTemplates: [ScriptTemplateDTO]

    public init(
        meetings: [MeetingDTO] = [],
        announcements: [AnnouncementDTO] = [],
        scriptTemplates: [ScriptTemplateDTO] = [],
        formatVersion: Int = Interchange.currentFormatVersion,
        generator: String = Interchange.generator,
        exportedAt: Date = Date(),
        includesPrivateNotes: Bool = true
    ) {
        self.formatVersion = formatVersion
        self.generator = generator
        self.exportedAt = exportedAt
        self.includesPrivateNotes = includesPrivateNotes
        self.meetings = meetings
        self.announcements = announcements
        self.scriptTemplates = scriptTemplates
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        generator = try container.decodeIfPresent(String.self, forKey: .generator) ?? "unknown"
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        includesPrivateNotes = try container.decodeIfPresent(Bool.self, forKey: .includesPrivateNotes) ?? true
        meetings = try container.decodeIfPresent([MeetingDTO].self, forKey: .meetings) ?? []
        announcements = try container.decodeIfPresent([AnnouncementDTO].self, forKey: .announcements) ?? []
        scriptTemplates = try container.decodeIfPresent([ScriptTemplateDTO].self, forKey: .scriptTemplates) ?? []
    }
}

/// Something the importer noticed that's worth telling the user, without being a failure.
public enum ImportNote: Sendable, Hashable {
    /// The file came from a newer version of the app. It still imports — every field decodes
    /// defensively — but something in it may not be fully understood.
    case newerFormatVersion(found: Int, supported: Int)
    /// Item kinds this version doesn't recognize. They import as custom items with their titles
    /// and raw kinds intact.
    case unrecognizedItemKinds([String])
    /// The file was exported without private notes, so notes fields are empty by design.
    case privateNotesExcluded

    public var message: String {
        switch self {
        case .newerFormatVersion(let found, let supported):
            "This file was made by a newer version of the app (format \(found); this app reads \(supported)). It imported, but something in it may not be fully understood."
        case .unrecognizedItemKinds(let kinds):
            "\(kinds.count) item\(kinds.count == 1 ? "" : "s") of an unfamiliar type imported as custom items: \(kinds.joined(separator: ", "))."
        case .privateNotesExcluded:
            "This file was shared without private notes."
        }
    }
}

/// The outcome of reading a file: what was in it, plus anything worth mentioning before it's
/// committed to the store.
public struct ImportResult<Document: Sendable>: Sendable {
    public var document: Document
    public var notes: [ImportNote]

    public init(document: Document, notes: [ImportNote] = []) {
        self.document = document
        self.notes = notes
    }
}
