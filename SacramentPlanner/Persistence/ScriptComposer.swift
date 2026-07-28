import Foundation
import SacramentKit
import SwiftData

/// Turns a stored program item into the words you read from the pulpit.
enum ScriptComposer {

    /// The wording for an item: a per-instance override if one exists, otherwise the saved
    /// template, otherwise the shipped default.
    static func templateBody(
        for item: ProgramItem,
        templates: [ScriptTemplate]
    ) -> String? {
        if let override = item.scriptOverride, !override.isEmpty { return override }
        guard let scriptKind = item.kind.scriptKind else { return nil }
        if let stored = templates.first(where: { $0.kind == scriptKind }) {
            return stored.body
        }
        return DefaultScripts.body(for: scriptKind)
    }

    /// Assembles what the template can refer to from the item's people and details.
    static func context(for item: ProgramItem, in meeting: Meeting) -> ScriptContext {
        let assignments = item.orderedAssignments

        // People the item is *about*, each carrying their own calling — a single sustaining
        // commonly covers several callings read in turn before one vote.
        let subjects = assignments
            .filter { $0.role == .subject }
            .compactMap(\.scriptSubject)

        let officiators = assignments
            .filter { $0.role == .officiator }
            .compactMap(\.scriptSubject?.person)

        // The ward business lead-in has to know something no single item can see: whether the
        // meeting has any actual business today. That's what decides between presenting it and
        // saying there is none.
        var flags: Set<String> = []
        if meeting.orderedItems.contains(where: { $0.kind.isBusiness }) {
            flags.insert("hasWardBusiness")
        }

        return ScriptContext(
            subjects: subjects,
            officiators: officiators,
            parents: item.parentsText,
            unitName: meeting.unitName,
            flags: flags
        )
    }

    /// Renders an item's script, or nil when the item has no spoken wording.
    static func render(
        _ item: ProgramItem,
        in meeting: Meeting,
        templates: [ScriptTemplate]
    ) -> ScriptRendering? {
        guard let body = templateBody(for: item, templates: templates) else { return nil }
        return ScriptRenderer.render(body, context: context(for: item, in: meeting))
    }

    /// Names in an item that carry a pronunciation note, shown alongside the script as a reading
    /// aid rather than spoken as part of it.
    static func pronunciationNotes(for item: ProgramItem) -> [(name: String, phonetic: String)] {
        item.orderedAssignments.compactMap { assignment in
            guard let person = assignment.person,
                  let phonetic = person.phoneticSpelling,
                  !phonetic.isEmpty
            else { return nil }
            return (person.fullName, phonetic)
        }
    }
}
