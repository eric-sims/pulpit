import Foundation
import SacramentKit
import SwiftData

/// The boundary between what's stored and what travels.
///
/// Kept as an explicit translation rather than making the `@Model` types `Codable` directly: the
/// persistence schema is free to change shape, and the wire format isn't.
enum InterchangeMapper {

    // MARK: - Export

    static func dto(for person: Person) -> PersonDTO {
        PersonDTO(
            id: person.id,
            fullName: person.fullName,
            preferredName: person.preferredName,
            title: person.title,
            phoneticSpelling: person.phoneticSpelling,
            pronouns: person.pronounsRaw
        )
    }

    static func dto(for assignment: Assignment) -> AssignmentDTO {
        AssignmentDTO(
            id: assignment.id,
            role: assignment.role,
            person: assignment.person.map(dto(for:)),
            displayNameOverride: assignment.displayNameOverride,
            topic: assignment.topic,
            callingText: assignment.callingText,
            officeText: assignment.officeText,
            status: assignment.status,
            statusNote: assignment.statusNote,
            order: assignment.order
        )
    }

    static func dto(for item: ProgramItem) -> ProgramItemDTO {
        ProgramItemDTO(
            id: item.id,
            order: item.order,
            kind: item.kind,
            title: item.title,
            notes: item.notes,
            status: item.status,
            hymnBook: item.hymnBookRaw.map { HymnBook(tolerant: $0) },
            hymnNumber: item.hymnNumber,
            scriptOverride: item.scriptOverride,
            needsFilling: item.needsFilling,
            assignments: item.orderedAssignments.map(dto(for:)),
            entries: item.orderedEntries.map {
                ItemEntryDTO(id: $0.id, order: $0.order, text: $0.text, isChecked: $0.isChecked)
            },
            detail: item.parentsText.map { ItemDetailDTO(parents: $0) }
        )
    }

    static func dto(for meeting: Meeting) -> MeetingDTO {
        MeetingDTO(
            id: meeting.id,
            date: meeting.date,
            kind: meeting.kind,
            unitName: meeting.unitName,
            theme: meeting.theme,
            notes: meeting.notes,
            presiding: meeting.presiding.map(dto(for:)),
            conducting: meeting.conducting.map(dto(for:)),
            chorister: meeting.chorister.map(dto(for:)),
            organist: meeting.organist.map(dto(for:)),
            items: meeting.orderedItems.map(dto(for:))
        )
    }

    /// Everything, for the backup file. Storage is local-only, so this is the only real backup.
    static func library(
        meetings: [Meeting],
        announcements: [Announcement],
        templates: [ScriptTemplate]
    ) -> LibraryDocument {
        LibraryDocument(
            meetings: meetings.map(dto(for:)),
            announcements: announcements.map {
                AnnouncementDTO(id: $0.id, title: $0.title, body: $0.body, lastUsedAt: $0.lastUsedAt)
            },
            scriptTemplates: templates.compactMap { template in
                template.kind.map {
                    ScriptTemplateDTO(
                        kind: $0,
                        body: template.body,
                        isUserModified: template.isUserModified,
                        seedVersion: template.seedVersion
                    )
                }
            }
        )
    }

    // MARK: - Import

    /// How one incoming person should be handled, decided in the import preview rather than here.
    struct PersonDecision {
        let incoming: PersonDTO
        /// An existing roster entry to link to, or nil to add this person to the roster.
        var linkTo: Person?
    }

    /// Writes an imported meeting into the store.
    ///
    /// Every id is regenerated. Two copies of the same meeting should be two meetings, not a silent
    /// overwrite of whatever happened to share an identifier — and a file that's been round-tripped
    /// between two people would otherwise collide with itself.
    @discardableResult
    static func importMeeting(
        _ dto: MeetingDTO,
        decisions: [UUID: PersonDecision],
        into context: ModelContext
    ) -> Meeting {
        var resolved: [UUID: Person] = [:]

        func person(for incoming: PersonDTO?) -> Person? {
            guard let incoming else { return nil }
            if let already = resolved[incoming.id] { return already }

            let result: Person
            if let linked = decisions[incoming.id]?.linkTo {
                result = linked
            } else {
                result = Person(
                    fullName: incoming.fullName,
                    preferredName: incoming.preferredName,
                    title: incoming.title,
                    phoneticSpelling: incoming.phoneticSpelling,
                    pronouns: incoming.pronounSet
                )
                context.insert(result)
            }
            resolved[incoming.id] = result
            return result
        }

        let meeting = Meeting(date: dto.date, kind: dto.meetingKind, unitName: dto.unitName)
        meeting.theme = dto.theme
        meeting.notes = dto.notes
        meeting.presiding = person(for: dto.presiding)
        meeting.conducting = person(for: dto.conducting)
        meeting.chorister = person(for: dto.chorister)
        meeting.organist = person(for: dto.organist)
        context.insert(meeting)

        for (index, itemDTO) in dto.items.sorted(by: { $0.order < $1.order }).enumerated() {
            let item = ProgramItem(
                kind: itemDTO.itemKind,
                title: itemDTO.title,
                order: index,
                needsFilling: itemDTO.needsFilling
            )
            item.notes = itemDTO.notes
            item.status = itemDTO.itemStatus
            item.hymnBookRaw = itemDTO.hymnBook
            item.hymnNumber = itemDTO.hymnNumber
            item.scriptOverride = itemDTO.scriptOverride
            item.parentsText = itemDTO.detail?.parents
            item.meeting = meeting
            context.insert(item)

            for assignmentDTO in itemDTO.assignments.sorted(by: { $0.order < $1.order }) {
                let assignment = Assignment(
                    role: assignmentDTO.assignmentRole,
                    person: person(for: assignmentDTO.person),
                    order: assignmentDTO.order
                )
                assignment.displayNameOverride = assignmentDTO.displayNameOverride
                assignment.topic = assignmentDTO.topic
                assignment.callingText = assignmentDTO.callingText
                assignment.officeText = assignmentDTO.officeText
                assignment.status = assignmentDTO.assignmentStatus
                assignment.statusNote = assignmentDTO.statusNote
                assignment.item = item
                context.insert(assignment)
            }

            for entryDTO in itemDTO.entries.sorted(by: { $0.order < $1.order }) {
                let entry = ItemEntry(text: entryDTO.text, order: entryDTO.order)
                entry.isChecked = entryDTO.isChecked
                entry.item = item
                context.insert(entry)
            }
        }

        return meeting
    }
}
