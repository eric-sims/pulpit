import PulpitKit
import SwiftData
import SwiftUI

/// Picks someone from the roster, adds a new person, or records a one-off name.
///
/// The one-off path matters: visiting speakers and full-time missionaries shouldn't accumulate in
/// a ward roster you have to maintain.
struct PersonPickerView: View {
    @Binding var selection: Person?
    var oneOffName: Binding<String?>?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.fullName) private var people: [Person]

    @State private var query = ""
    @State private var isAddingPerson = false

    private var results: [Person] {
        guard !query.isEmpty else { return people.filter(\.isActive) }
        return people.filter {
            $0.isActive && $0.fullName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if selection != nil || oneOffName?.wrappedValue != nil {
                    Section {
                        Button("Clear", systemImage: "xmark.circle", role: .destructive) {
                            selection = nil
                            oneOffName?.wrappedValue = nil
                            dismiss()
                        }
                    }
                }

                if let oneOffName, !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button {
                            oneOffName.wrappedValue = query.trimmingCharacters(in: .whitespacesAndNewlines)
                            selection = nil
                            dismiss()
                        } label: {
                            Label("Use “\(query)” Just This Once", systemImage: "person.badge.clock")
                        }
                    } footer: {
                        Text("For visitors and missionaries, without adding them to the roster.")
                    }
                }

                Section {
                    ForEach(results) { person in
                        Button {
                            selection = person
                            oneOffName?.wrappedValue = nil
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(person.addressedName).foregroundStyle(.primary)
                                    if let phonetic = person.phoneticSpelling, !phonetic.isEmpty {
                                        Text(phonetic)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if person.id == selection?.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Roster")
                }

                Section {
                    Button("Add Someone New", systemImage: "person.badge.plus") {
                        isAddingPerson = true
                    }
                }
            }
            .searchable(text: $query, prompt: "Search the roster")
            .navigationTitle("Choose a Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .sheet(isPresented: $isAddingPerson) {
                PersonEditorView(initialName: query) { person in
                    selection = person
                    oneOffName?.wrappedValue = nil
                    dismiss()
                }
            }
        }
    }
}

/// Creates or edits a roster entry.
struct PersonEditorView: View {
    var person: Person?
    var initialName: String = ""
    var onSave: ((Person) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var title = ""
    @State private var phonetic = ""
    @State private var pronouns: PronounSet = .he
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $fullName)
                    Picker("Address as", selection: $pronouns) {
                        ForEach(PronounSet.selectableCases, id: \.self) { set in
                            Text(set.formLabel).tag(set)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Decides whether a sustaining reads “Brother Smith … support him” or “Sister Smith … support her”.")
                }

                Section {
                    TextField("Title", text: $title)
                } header: {
                    Text("Form of Address")
                } footer: {
                    Text("“President”, “Bishop”, “Elder”. Overrides Brother or Sister. Leave blank for most people.")
                }

                Section {
                    TextField("How to say it", text: $phonetic)
                } header: {
                    Text("Pronunciation")
                } footer: {
                    Text("Shown beside the name while you conduct. Never read aloud as part of a script.")
                }

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                } footer: {
                    Text("Private. Notes on people never leave this device — shared files have no field for them.")
                }
            }
            .navigationTitle(person == nil ? "New Person" : "Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                        .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let person {
            fullName = person.fullName
            title = person.title ?? ""
            phonetic = person.phoneticSpelling ?? ""
            pronouns = person.pronouns
            notes = person.notes ?? ""
        } else if fullName.isEmpty {
            fullName = initialName
        }
    }

    private func save() {
        let target = person ?? Person()
        target.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.title = title.isEmpty ? nil : title
        target.phoneticSpelling = phonetic.isEmpty ? nil : phonetic
        target.pronouns = pronouns
        target.notes = notes.isEmpty ? nil : notes
        if person == nil { context.insert(target) }
        onSave?(target)
        dismiss()
    }
}
