import Foundation
import PulpitKit
import SwiftData

enum MeetingFactory {

    /// Builds a meeting from its kind's template.
    ///
    /// The template seeds the item list; it never constrains it. Items can be added, removed and
    /// reordered afterwards, including during the meeting itself.
    @discardableResult
    static func makeMeeting(
        kind: MeetingKind,
        date: Date,
        unitName: String,
        in context: ModelContext
    ) -> Meeting {
        let meeting = Meeting(date: date, kind: kind, unitName: unitName)
        context.insert(meeting)

        for (index, seed) in MeetingTemplates.seed(for: kind).enumerated() {
            let item = ProgramItem(
                kind: seed.kind,
                title: seed.title,
                order: index,
                needsFilling: seed.needsFilling
            )
            item.meeting = meeting
            context.insert(item)

            // Seed one empty assignment per role the item takes, so the slot is visible rather
            // than something you have to know to add.
            if seed.needsFilling {
                for (roleIndex, role) in seed.kind.assignableRoles.enumerated()
                where role != .subject {
                    let assignment = Assignment(role: role, order: roleIndex)
                    assignment.item = item
                    context.insert(assignment)
                }
            }
        }
        return meeting
    }

    /// Adds an item at its canonical position in the Handbook order.
    @discardableResult
    static func addItem(
        _ kind: ItemKind,
        to meeting: Meeting,
        title: String? = nil,
        in context: ModelContext
    ) -> ProgramItem {
        let existing = meeting.orderedItems
        let index = MeetingTemplates.insertionIndex(for: kind, in: existing.map(\.kind))

        let item = ProgramItem(kind: kind, title: title, order: index)
        item.meeting = meeting
        context.insert(item)

        for (offset, existingItem) in existing.enumerated() where offset >= index {
            existingItem.order = offset + 1
        }
        meeting.updatedAt = Date()
        return item
    }

    static func deleteItem(_ item: ProgramItem, from meeting: Meeting, in context: ModelContext) {
        guard item.kind.isDeletable else { return }
        context.delete(item)
        meeting.items?.removeAll { $0.id == item.id }
        meeting.normalizeOrder()
    }

    /// Moves items within the outline, then renumbers.
    static func move(in meeting: Meeting, from source: IndexSet, to destination: Int) {
        var items = meeting.orderedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
        meeting.updatedAt = Date()
    }

    @discardableResult
    static func addAssignment(
        role: AssignmentRole,
        to item: ProgramItem,
        in context: ModelContext
    ) -> Assignment {
        let assignment = Assignment(role: role, order: item.orderedAssignments.count)
        assignment.item = item
        context.insert(assignment)
        return assignment
    }

    @discardableResult
    static func addEntry(text: String, to item: ProgramItem, in context: ModelContext) -> ItemEntry {
        let entry = ItemEntry(text: text, order: item.orderedEntries.count)
        entry.item = item
        context.insert(entry)
        return entry
    }
}
