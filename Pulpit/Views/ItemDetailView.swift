import PulpitKit
import SwiftData
import SwiftUI

/// The per-kind editor for one program item, plus a live preview of how its script will read.
struct ItemDetailView: View {
    @Bindable var item: ProgramItem
    let meeting: Meeting

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [ScriptTemplate]
    @State private var isEditingScript = false

    private var rendering: ScriptRendering? {
        ScriptComposer.render(item, in: meeting, templates: templates)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $item.title)
                }

                if item.kind.isHymn {
                    Section("Hymn") { HymnSlotRow(item: item) }
                }

                if !item.kind.assignableRoles.isEmpty {
                    Section("People") {
                        peopleEditor
                    }
                }

                if item.kind.supportsEntries {
                    AnnouncementsEditor(item: item)
                }

                if let rendering {
                    Section {
                        ScriptPreviewText(rendering: rendering)
                        Button(item.scriptOverride == nil ? "Reword just this one" : "Edit wording",
                               systemImage: "pencil") {
                            isEditingScript = true
                        }
                        if item.scriptOverride != nil {
                            Button("Revert to the saved script", systemImage: "arrow.uturn.backward", role: .destructive) {
                                item.scriptOverride = nil
                            }
                        }
                    } header: {
                        Text("Script")
                    } footer: {
                        if item.scriptOverride != nil {
                            Text("Reworded for this meeting only. The saved template is unchanged.")
                        }
                    }
                }

                let notes = ScriptComposer.pronunciationNotes(for: item)
                if !notes.isEmpty {
                    Section("Pronunciation") {
                        ForEach(notes, id: \.name) { note in
                            LabeledContent(note.name, value: note.phonetic)
                        }
                    }
                }

                Section {
                    TextField("Notes", text: Binding(
                        get: { item.notes ?? "" },
                        set: { item.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                } header: {
                    Text("Private notes")
                } footer: {
                    Text("For you. Excluded from shared files unless you say otherwise.")
                }
            }
            .navigationTitle(item.kind.defaultTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isEditingScript) {
                ScriptOverrideEditor(item: item, meeting: meeting, templates: templates)
            }
        }
    }

    @ViewBuilder
    private var peopleEditor: some View {
        switch item.kind {
        case .babyBlessing, .confirmation:
            OrdinanceItemEditor(item: item)
        case .sustaining, .release, .ordinationProposal, .newMemberWelcome, .movingInRecord:
            BusinessItemEditor(item: item)
        default:
            ForEach(item.orderedAssignments) { assignment in
                AssignmentNameRow(assignment: assignment)
                if item.kind == .speaker {
                    AssignmentTopicRow(assignment: assignment)
                }
                if assignment.isFilled {
                    AssignmentStatusRow(assignment: assignment)
                }
            }
            Button("Add another person", systemImage: "plus") {
                let role = item.kind.assignableRoles.first ?? .subject
                MeetingFactory.addAssignment(role: role, to: item, in: context)
            }
            .font(.footnote)
        }
    }
}

/// Renders a script with names emphasized, and shows any template defects rather than hiding them.
struct ScriptPreviewText: View {
    let rendering: ScriptRendering

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rendering.attributedString)
                .font(.callout)
            ForEach(Array(rendering.issues.enumerated()), id: \.offset) { _, issue in
                Label(issue.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// Edits the wording for one item without touching the saved template.
struct ScriptOverrideEditor: View {
    @Bindable var item: ProgramItem
    let meeting: Meeting
    let templates: [ScriptTemplate]

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private var preview: ScriptRendering {
        ScriptRenderer.render(draft, context: ScriptComposer.context(for: item, in: meeting))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wording") {
                    TextField("Script", text: $draft, axis: .vertical)
                        .font(.callout.monospaced())
                        .lineLimit(6...)
                }
                Section("Preview") {
                    ScriptPreviewText(rendering: preview)
                }
                Section("Placeholders") {
                    ForEach(ScriptRenderer.availableTokens) { token in
                        LabeledContent(token.token, value: token.summary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Reword")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.scriptOverride = draft
                        dismiss()
                    }
                }
            }
            .onAppear {
                draft = ScriptComposer.templateBody(for: item, templates: templates) ?? ""
            }
        }
    }
}
