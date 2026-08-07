import SacramentKit
import SwiftData
import SwiftUI

struct RosterView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.fullName) private var people: [Person]
    @State private var isAdding = false
    @State private var editing: Person?
    @State private var query = ""

    private var results: [Person] {
        guard !query.isEmpty else { return people }
        return people.filter { $0.fullName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    ContentUnavailableView {
                        Label("No One Yet", systemImage: "person.2")
                    } description: {
                        Text("People are added as you assign them, or you can add them here.")
                    } actions: {
                        Button("Add Someone") { isAdding = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(results) { person in
                            Button { editing = person } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.addressedName).foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        Text(person.pronouns.formLabel)
                                        if let phonetic = person.phoneticSpelling, !phonetic.isEmpty {
                                            Text("·")
                                            Text(phonetic)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(results[index]) }
                        }
                    }
                    .searchable(text: $query, prompt: "Search")
                }
            }
            .navigationTitle("Roster")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "person.badge.plus") { isAdding = true }
                }
            }
            .sheet(isPresented: $isAdding) { PersonEditorView() }
            .sheet(item: $editing) { PersonEditorView(person: $0) }
        }
    }
}

/// The saved wording, with a live preview so you can tell whether an edit reads correctly —
/// which you can't do by staring at `{{names}} {{has}} been called`.
struct ScriptLibraryView: View {
    @Query private var templates: [ScriptTemplate]

    private var ordered: [ScriptTemplate] {
        ScriptKind.allCases.compactMap { kind in templates.first { $0.kind == kind } }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Drafts of customary practice, not quotations from the Handbook. Edit anything that doesn't match how you conduct.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(ordered) { template in
                    NavigationLink(destination: ScriptTemplateEditor(template: template)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.kind?.displayName ?? "Script")
                            if template.isUserModified {
                                Text("Edited by you")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scripts")
        }
    }
}

struct ScriptTemplateEditor: View {
    @Bindable var template: ScriptTemplate
    @State private var pronouns: PronounSet = .she

    private var preview: ScriptRendering? {
        guard let kind = template.kind else { return nil }
        return ScriptPreview.preview(template.body, for: kind, pronouns: pronouns)
    }

    var body: some View {
        Form {
            if let kind = template.kind {
                Section { Text(kind.guidance).font(.footnote).foregroundStyle(.secondary) }
            }

            Section("Wording") {
                TextField("Script", text: $template.body, axis: .vertical)
                    .font(.callout.monospaced())
                    .lineLimit(8...)
                    .onChange(of: template.body) { template.isUserModified = true }
            }

            Section {
                Picker("Sample person", selection: $pronouns) {
                    ForEach(PronounSet.selectableCases, id: \.self) { set in
                        Text(set.formLabel).tag(set)
                    }
                }
                .pickerStyle(.segmented)
                if let preview {
                    ScriptPreviewText(rendering: preview)
                }
            } header: {
                Text("Preview")
            } footer: {
                Text("Switch the sample person to check the wording reads correctly for a brother and for a sister.")
            }

            Section("Placeholders") {
                ForEach(ScriptRenderer.availableTokens) { token in
                    LabeledContent(token.token, value: token.summary).font(.caption)
                }
            }

            if template.isUserModified {
                Section {
                    Button("Restore the shipped wording", systemImage: "arrow.uturn.backward", role: .destructive) {
                        guard let kind = template.kind else { return }
                        template.body = DefaultScripts.body(for: kind)
                        template.seedVersion = DefaultScripts.currentSeedVersion
                        template.isUserModified = false
                    }
                }
            }
        }
        .navigationTitle(template.kind?.displayName ?? "Script")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    @AppStorage(Preferences.unitNameKey) private var unitName = ""
    @Query(sort: \Meeting.date) private var meetings: [Meeting]
    @Query private var announcements: [Announcement]
    @Query private var templates: [ScriptTemplate]

    @State private var exported: ExportedFile?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ward or branch", text: $unitName)
                } header: {
                    Text("Your unit")
                } footer: {
                    Text("Used in scripts that name the ward. Each meeting keeps its own copy, so an imported meeting from another ward stays correct.")
                }

                Section {
                    Button("Export All Meetings", systemImage: "arrow.down.doc") { exportBackup() }
                        .disabled(meetings.isEmpty)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Everything in one file: \(meetings.count) meeting\(meetings.count == 1 ? "" : "s"), your announcements and your scripts. Meetings live only on this device, so this is your only copy off it.")
                }

                Section {
                    LabeledContent("Hymns (1985)", value: "341")
                    LabeledContent("Hymns—For Home and Church", value: "\(HymnCatalog.shared.hymns(in: .homeAndChurch).count)")
                    LabeledContent("Verified", value: HymnCatalog.shared.verifiedOn)
                } header: {
                    Text("Hymn catalog")
                } footer: {
                    Text("Titles, numbers and sections only. No lyrics or music.")
                }

                Section {
                    LabeledContent("App version", value: AppVersion.displayVersion)
                    if let commit = AppVersion.commit {
                        LabeledContent("Commit", value: commit)
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("The build running on this device. Worth quoting if you report a problem — press and hold to copy.")
                }
                .textSelection(.enabled)
            }
            .navigationTitle("Settings")
            .sheet(item: $exported) { ShareSheet(url: $0.url) }
            .alert("Export Failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func exportBackup() {
        do {
            exported = ExportedFile(
                url: try ExportService.backupFile(
                    meetings: meetings,
                    announcements: announcements,
                    templates: templates
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
