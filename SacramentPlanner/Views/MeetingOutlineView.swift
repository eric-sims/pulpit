import SacramentKit
import SwiftData
import SwiftUI

/// The meeting as a directly editable outline. This is where you land after the wizard, and it's
/// what you edit forever after — the wizard never runs again for a meeting that already exists.
struct MeetingOutlineView: View {
    @Bindable var meeting: Meeting
    @Environment(\.modelContext) private var context
    @State private var isAddingItem = false
    @State private var editingItem: ProgramItem?
    @State private var isConducting = false
    @State private var isExporting = false

    var body: some View {
        List {
            Section {
                Button {
                    isConducting = true
                } label: {
                    WideButtonLabel(title: "Conduct This Meeting", systemImage: "music.note.list")
                        .font(.headline)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Type", value: meeting.kind.displayName)
                DatePicker("Date", selection: $meeting.date, displayedComponents: .date)
                PersonRow(label: "Presiding", person: $meeting.presiding)
                PersonRow(label: "Conducting", person: $meeting.conducting)
            }

            if !meeting.isReady {
                Section("Outstanding") {
                    ForEach(meeting.incompleteItems) { item in
                        Button { editingItem = item } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(item.title, systemImage: "square.dashed")
                                    .foregroundStyle(.orange)
                                if let reason = item.incompleteReason {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(meeting.unconfirmedAssignments) { assignment in
                        HStack {
                            Label(assignment.displayName ?? "", systemImage: "questionmark.circle")
                            Spacer()
                            StatusChip(status: assignment.status)
                        }
                    }
                }
            }

            Section("Program") {
                ForEach(meeting.orderedItems) { item in
                    Button { editingItem = item } label: {
                        OutlineRow(item: item).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .deleteDisabled(!item.kind.isDeletable)
                }
                .onMove { MeetingFactory.move(in: meeting, from: $0, to: $1) }
                .onDelete(perform: delete)
            }

            Section {
                Button("Add an item", systemImage: "plus") { isAddingItem = true }
            }
        }
        .navigationTitle(meeting.date.formatted(.dateTime.month().day().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export", systemImage: "square.and.arrow.up") { isExporting = true }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $isExporting) {
            ExportView(meeting: meeting)
        }
        .sheet(isPresented: $isAddingItem) {
            AddItemSheet(meeting: meeting)
        }
        .sheet(item: $editingItem) { item in
            ItemDetailView(item: item, meeting: meeting)
        }
        .fullScreenCover(isPresented: $isConducting) {
            ConductingView(meeting: meeting)
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = meeting.orderedItems
        for index in offsets where items[index].kind.isDeletable {
            MeetingFactory.deleteItem(items[index], from: meeting, in: context)
        }
    }
}

/// Adds an item, grouped so the occasional things are findable without scrolling past the weekly
/// ones. New items land at their canonical position in the Handbook order.
struct AddItemSheet: View {
    let meeting: Meeting
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let groups: [(String, [ItemKind])] = [
        ("Business", [.wardBusiness, .release, .sustaining, .ordinationProposal, .newMemberWelcome, .movingInRecord, .stakeBusiness]),
        ("Ordinances", [.babyBlessing, .confirmation]),
        ("Music", [.intermediateHymn, .musicalNumber]),
        ("Program", [.speaker, .presentation, .recognitions, .custom]),
    ]

    /// Business kinds are one-per-meeting: a second sustaining item would repeat the preamble and
    /// call for a second vote. Ordinances, speakers and music can repeat freely.
    private func isAlreadyPresent(_ kind: ItemKind) -> Bool {
        guard kind.isBusiness || kind == .wardBusiness || kind == .stakeBusiness else { return false }
        return meeting.orderedItems.contains { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1, id: \.self) { kind in
                            Button(kind.defaultTitle) { add(kind) }
                                .disabled(isAlreadyPresent(kind))
                        }
                    }
                }
            }
            .navigationTitle("Add an Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func add(_ kind: ItemKind) {
        let item = MeetingFactory.addItem(kind, to: meeting, in: context)
        for role in kind.assignableRoles {
            MeetingFactory.addAssignment(role: role, to: item, in: context)
        }
        dismiss()
    }
}
