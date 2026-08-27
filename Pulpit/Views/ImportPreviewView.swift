import PulpitKit
import SwiftData
import SwiftUI

/// Shows what a file contains before any of it is written.
///
/// Person matching is *suggested*, never automatic. Two people in a ward genuinely can share a
/// name, and silently merging them corrupts the roster in a way that's tedious to unpick — so
/// every match is a switch you can turn off.
struct ImportPreviewView: View {
    let result: ImportResult<MeetingDocument>

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var roster: [Person]

    /// Incoming person id → the roster entry to link to. Absent means "add as someone new".
    @State private var links: [UUID: Person] = [:]
    @State private var didPrepare = false

    private var meeting: MeetingDTO { result.document.meeting }
    private var incomingPeople: [PersonDTO] { meeting.referencedPeople }

    var body: some View {
        NavigationStack {
            List {
                Section("Meeting") {
                    LabeledContent("Date", value: meeting.date.formatted(.dateTime.weekday(.wide).month().day().year()))
                    LabeledContent("Type", value: meeting.meetingKind.displayName)
                    if !meeting.unitName.isEmpty {
                        LabeledContent("Ward", value: meeting.unitName)
                    }
                    LabeledContent("Items", value: "\(meeting.items.count)")
                }

                if !result.notes.isEmpty {
                    Section("Worth Knowing") {
                        ForEach(Array(result.notes.enumerated()), id: \.offset) { _, note in
                            Label(note.message, systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !incomingPeople.isEmpty {
                    Section {
                        ForEach(incomingPeople, id: \.id) { person in
                            PersonLinkRow(
                                incoming: person,
                                roster: roster,
                                linked: Binding(
                                    get: { links[person.id] },
                                    set: { links[person.id] = $0 }
                                )
                            )
                        }
                    } header: {
                        Text("People")
                    } footer: {
                        Text("Matches are suggested by name. Turn one off to add that person to your roster separately instead.")
                    }
                }

                Section("Program") {
                    ForEach(meeting.items.sorted(by: { $0.order < $1.order }), id: \.id) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            if item.isUnrecognizedKind {
                                Text("Unfamiliar type — will import as a custom item")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .templeCanvas()
            .navigationTitle("Import Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { performImport() }
                        .buttonStyle(.glassProminent)
                }
            }
            .onAppear(perform: prepareSuggestions)
        }
    }

    /// Pre-selects the matches the roster matcher is confident about, leaving them visible and
    /// switchable rather than applied behind your back.
    private func prepareSuggestions() {
        guard !didPrepare else { return }
        didPrepare = true

        let matches = RosterMatcher.match(
            incoming: incomingPeople,
            against: roster.map { (id: $0.id, fullName: $0.fullName) }
        )
        for match in matches {
            if let suggestedID = match.suggestedExistingID,
               let person = roster.first(where: { $0.id == suggestedID }) {
                links[match.incoming.id] = person
            }
        }
    }

    private func performImport() {
        let decisions = incomingPeople.reduce(into: [UUID: InterchangeMapper.PersonDecision]()) { result, person in
            result[person.id] = .init(incoming: person, linkTo: links[person.id])
        }
        InterchangeMapper.importMeeting(meeting, decisions: decisions, into: context)
        dismiss()
    }
}

private struct PersonLinkRow: View {
    let incoming: PersonDTO
    let roster: [Person]
    @Binding var linked: Person?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(incoming.fullName)
                Spacer()
                if linked == nil {
                    Text("New")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }
            if let match = suggestion {
                Toggle(isOn: Binding(
                    get: { linked?.id == match.id },
                    set: { linked = $0 ? match : nil }
                )) {
                    Text("Same as \(match.addressedName) in your roster")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The roster entry this person looks like, if any.
    private var suggestion: Person? {
        linked ?? roster.first {
            RosterMatcher.normalize($0.fullName) == RosterMatcher.normalize(incoming.fullName)
        }
    }
}
