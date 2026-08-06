import Foundation
import Testing
@testable import SacramentKit

// Whole seconds only: the format encodes dates as ISO 8601 without fractional seconds, so a date
// carrying microseconds would fail a round-trip comparison for reasons that have nothing to do
// with the format being wrong.
private let fixedDate = Date(timeIntervalSince1970: 1_785_000_000)

private func sampleMeeting() -> MeetingDTO {
    let bishop = PersonDTO(fullName: "David Larsen", title: "Bishop", pronouns: PronounSet.he.rawValue)
    let speaker = PersonDTO(fullName: "Jane Doe", phoneticSpelling: "DOH", pronouns: PronounSet.she.rawValue)

    return MeetingDTO(
        date: fixedDate,
        kind: .regular,
        unitName: "Highland 4th Ward",
        theme: "Temple worship",
        notes: "Confirm the organist arrived.",
        presiding: bishop,
        conducting: bishop,
        items: [
            ProgramItemDTO(
                order: 0,
                kind: .announcements,
                entries: [
                    ItemEntryDTO(order: 0, text: "Temple trip Saturday", isChecked: true),
                    ItemEntryDTO(order: 1, text: "Ministering interviews"),
                ]
            ),
            ProgramItemDTO(
                order: 1,
                kind: .openingHymn,
                hymnBook: .hymns1985,
                hymnNumber: 2,
                needsFilling: true
            ),
            ProgramItemDTO(
                order: 2,
                kind: .release,
                status: .completed,
                assignments: [
                    AssignmentDTO(
                        role: .subject,
                        person: bishop,
                        callingText: "Ward Clerk",
                        status: .confirmed
                    )
                ],
                detail: ItemDetailDTO(calling: "Ward Clerk")
            ),
            ProgramItemDTO(
                order: 3,
                kind: .speaker,
                notes: "Has asked to go second.",
                assignments: [
                    AssignmentDTO(
                        role: .speaker,
                        person: speaker,
                        topic: "Covenants",
                        status: .invited,
                        statusNote: "Texted Tuesday, no reply yet"
                    )
                ]
            ),
            ProgramItemDTO(order: 4, kind: .sacrament),
        ]
    )
}

@Suite("Interchange round trip")
struct InterchangeRoundTripTests {

    @Test("A meeting survives an encode and decode unchanged")
    func roundTripFidelity() throws {
        let original = sampleMeeting()
        let data = try Interchange.encode(meeting: original, includePrivateNotes: true, exportedAt: fixedDate)
        let result = try Interchange.decodeMeeting(data)

        #expect(result.document.meeting == original)
        #expect(result.document.formatVersion == Interchange.currentFormatVersion)
        #expect(result.document.includesPrivateNotes)
    }

    @Test("Hymn references resolve back to catalog entries")
    func hymnReferencesResolve() throws {
        let data = try Interchange.encode(meeting: sampleMeeting(), includePrivateNotes: true)
        let meeting = try Interchange.decodeMeeting(data).document.meeting
        let hymnItem = meeting.items.first { $0.itemKind == .openingHymn }

        #expect(hymnItem?.hymn?.title == "The Spirit of God")
    }

    @Test("Encoded output is stable, so files stay diffable")
    func stableEncoding() throws {
        let meeting = sampleMeeting()
        let first = try Interchange.encode(meeting: meeting, includePrivateNotes: true, exportedAt: fixedDate)
        let second = try Interchange.encode(meeting: meeting, includePrivateNotes: true, exportedAt: fixedDate)

        #expect(first == second)
    }

    @Test("Filenames are readable and safe")
    func filename() {
        var meeting = sampleMeeting()
        meeting.unitName = "Bad/Name:Here"
        let name = Interchange.suggestedFilename(for: meeting)

        #expect(name.hasSuffix(".sacramentplan"))
        #expect(name.contains("Sacrament Meeting"))
        #expect(!name.contains("/"))
    }

    @Test("A library of meetings round-trips")
    func libraryRoundTrip() throws {
        let library = LibraryDocument(
            meetings: [sampleMeeting()],
            announcements: [AnnouncementDTO(title: "Temple trip", body: "Saturday at 8am")],
            scriptTemplates: [ScriptTemplateDTO(kind: .sustaining, body: DefaultScripts.body(for: .sustaining))],
            exportedAt: fixedDate
        )
        let decoded = try Interchange.decodeLibrary(Interchange.encode(library: library)).document

        #expect(decoded == library)
    }
}

@Suite("Private notes never leave by accident")
struct InterchangePrivacyTests {

    @Test("Export strips private notes by default")
    func defaultsToRedacted() throws {
        let data = try Interchange.encode(meeting: sampleMeeting())
        let result = try Interchange.decodeMeeting(data)
        let meeting = result.document.meeting

        #expect(meeting.notes == nil)
        #expect(meeting.items.allSatisfy { $0.notes == nil })
        #expect(meeting.items.flatMap(\.assignments).allSatisfy { $0.statusNote == nil })
        #expect(result.document.includesPrivateNotes == false)
        #expect(result.notes.contains(.privateNotesExcluded))
    }

    @Test("Titles and per-person callings survive the trip")
    func lateAddedFieldsRoundTrip() throws {
        let data = try Interchange.encode(meeting: sampleMeeting(), includePrivateNotes: true)
        let meeting = try Interchange.decodeMeeting(data).document.meeting

        let release = meeting.items.first { $0.itemKind == .release }
        let subject = release?.assignments.first

        // Without this the recipient sees an empty meeting that claims to be ready.
        #expect(meeting.items.first { $0.itemKind == .openingHymn }?.needsFilling == true)
        #expect(subject?.callingText == "Ward Clerk")
        #expect(subject?.person?.title == "Bishop")
        // And the title is what a script would address them by.
        #expect(subject?.person?.scriptPerson.addressedName == "Bishop David Larsen")
    }

    @Test("Redaction keeps everything that isn't private")
    func redactionIsSurgical() throws {
        let data = try Interchange.encode(meeting: sampleMeeting())
        let meeting = try Interchange.decodeMeeting(data).document.meeting

        #expect(meeting.theme == "Temple worship")
        #expect(meeting.unitName == "Highland 4th Ward")
        #expect(meeting.items.count == 5)
        let speaker = meeting.items.first { $0.itemKind == .speaker }?.assignments.first
        #expect(speaker?.person?.fullName == "Jane Doe")
        #expect(speaker?.topic == "Covenants")
        #expect(speaker?.assignmentStatus == .invited)
    }

    @Test("Roster notes have no field in the wire format at all")
    func personNotesAreNotRepresentable() throws {
        let data = try Interchange.encode(meeting: sampleMeeting(), includePrivateNotes: true)
        let json = String(decoding: data, as: UTF8.self)

        // Phonetic spelling travels — it's a reading aid. Private roster notes have nowhere to go.
        #expect(json.contains("phoneticSpelling"))
        #expect(!json.contains("\"personNotes\""))
    }
}

@Suite("Importing files this version didn't write")
struct InterchangeCompatibilityTests {

    private func decode(_ json: String) throws -> ImportResult<MeetingDocument> {
        try Interchange.decodeMeeting(Data(json.utf8))
    }

    @Test("An unknown item kind imports as a custom item with its title and raw kind intact")
    func unknownItemKind() throws {
        let result = try decode("""
        {
          "formatVersion": 1,
          "meeting": {
            "date": "2026-08-02T10:00:00Z",
            "kind": "regular",
            "items": [
              { "kind": "choirFestival", "title": "Stake Choir Festival", "order": 0 }
            ]
          }
        }
        """)
        let item = result.document.meeting.items[0]

        #expect(item.itemKind == .custom)
        #expect(item.isUnrecognizedKind)
        #expect(item.title == "Stake Choir Festival")
        #expect(item.kind == "choirFestival")
        #expect(result.notes.contains(.unrecognizedItemKinds(["choirFestival"])))
    }

    @Test("Re-exporting an unfamiliar item preserves its original kind")
    func unknownKindSurvivesReexport() throws {
        let imported = try decode("""
        {
          "formatVersion": 1,
          "meeting": {
            "date": "2026-08-02T10:00:00Z", "kind": "regular",
            "items": [{ "kind": "choirFestival", "title": "Stake Choir Festival" }]
          }
        }
        """)
        let reencoded = try Interchange.encode(
            meeting: imported.document.meeting,
            includePrivateNotes: true
        )
        let again = try Interchange.decodeMeeting(reencoded)

        #expect(again.document.meeting.items[0].kind == "choirFestival")
    }

    @Test("Unknown fields are ignored rather than fatal")
    func unknownFieldsIgnored() throws {
        let result = try decode("""
        {
          "formatVersion": 1,
          "somethingFromTheFuture": { "nested": [1, 2, 3] },
          "meeting": {
            "date": "2026-08-02T10:00:00Z",
            "kind": "regular",
            "attendanceCount": 214,
            "items": [{ "kind": "speaker", "title": "First Speaker", "livestreamURL": "https://example.com" }]
          }
        }
        """)

        #expect(result.document.meeting.items[0].itemKind == .speaker)
        #expect(result.document.meeting.items[0].title == "First Speaker")
    }

    @Test("A newer format version imports with a note rather than an error")
    func newerFormatVersion() throws {
        let result = try decode("""
        {
          "formatVersion": 99,
          "meeting": { "date": "2026-08-02T10:00:00Z", "kind": "regular", "items": [] }
        }
        """)

        #expect(result.notes.contains(.newerFormatVersion(found: 99, supported: 1)))
        #expect(result.document.meeting.items.isEmpty)
    }

    @Test("Missing fields fall back to sensible defaults")
    func missingFieldsDefault() throws {
        let result = try decode("""
        { "meeting": { "items": [{ "kind": "speaker" }] } }
        """)
        let meeting = result.document.meeting

        #expect(meeting.meetingKind == .regular)
        #expect(meeting.unitName == "")
        #expect(meeting.items[0].itemStatus == .pending)
        #expect(meeting.items[0].assignments.isEmpty)
        #expect(meeting.items[0].entries.isEmpty)
    }

    @Test("An unknown form of address falls back to a normal singular sentence")
    func unknownPronounValue() throws {
        let result = try decode("""
        {
          "meeting": {
            "date": "2026-08-02T10:00:00Z", "kind": "regular",
            "items": [{
              "kind": "speaker",
              "assignments": [{ "role": "speaker", "person": { "fullName": "Pat Quinn", "pronouns": "xe" } }]
            }]
          }
        }
        """)
        let person = result.document.meeting.items[0].assignments[0].person

        #expect(person?.pronounSet == .he)
    }

    @Test("A file that isn't a plan fails clearly")
    func rejectsGarbage() {
        #expect(throws: Interchange.Failure.self) {
            _ = try Interchange.decodeMeeting(Data("not json at all".utf8))
        }
        #expect(throws: Interchange.Failure.self) {
            _ = try Interchange.decodeMeeting(Data(#"{"unrelated": true}"#.utf8))
        }
    }
}

@Suite("Matching incoming people against the roster")
struct RosterMatcherTests {
    private let existingID = UUID()

    @Test("A matching id is definitive")
    func matchByID() {
        let incoming = PersonDTO(id: existingID, fullName: "Renamed Person")
        let matches = RosterMatcher.match(
            incoming: [incoming],
            against: [(id: existingID, fullName: "David Larsen")]
        )

        #expect(matches[0].suggestedExistingID == existingID)
        #expect(!matches[0].isNewToRoster)
    }

    @Test("Names match regardless of case and spacing")
    func matchByName() {
        let matches = RosterMatcher.match(
            incoming: [PersonDTO(fullName: "  david   LARSEN ")],
            against: [(id: existingID, fullName: "David Larsen")]
        )

        #expect(matches[0].suggestedExistingID == existingID)
        #expect(matches[0].isExactNameMatch)
    }

    @Test("Someone genuinely new is flagged as new")
    func newPerson() {
        let matches = RosterMatcher.match(
            incoming: [PersonDTO(fullName: "Someone Else")],
            against: [(id: existingID, fullName: "David Larsen")]
        )

        #expect(matches[0].isNewToRoster)
        #expect(matches[0].suggestedExistingID == nil)
    }

    @Test("Every person named in a meeting is offered for matching, without duplicates")
    func collectsReferencedPeople() {
        let people = sampleMeeting().referencedPeople

        #expect(people.count == 2)
        #expect(Set(people.map(\.fullName)) == ["David Larsen", "Jane Doe"])
    }
}
