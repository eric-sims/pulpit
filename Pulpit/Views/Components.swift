import PulpitKit
import SwiftData
import SwiftUI

// MARK: - Buttons

/// A label for a full-width button, with the text centered on the button itself.
///
/// `Label` lays the icon and title out as one unit and centers *that*, which leaves the text
/// sitting right of centre by half the icon's width — small, but it reads as a misalignment on a
/// wide button. Pinning the icon to the leading edge lets the text center on the button.
struct WideButtonLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .accessibilityLabel(title)
    }
}

// MARK: - People

/// A labelled slot that opens the roster picker.
struct PersonRow: View {
    let label: String
    @Binding var person: Person?
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            LabeledContent(label) {
                if let person {
                    Text(person.addressedName).foregroundStyle(.primary)
                } else {
                    Text("Choose").foregroundStyle(.secondary)
                }
            }
            // Without this the row only responds where its text is, and the gap in the middle —
            // the largest part of the row — does nothing.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPicking) {
            PersonPickerView(selection: $person)
        }
    }
}

// Each of these is deliberately a *single* Form row.
//
// An earlier version bundled the name button, the text fields and the status picker into one view
// with a multi-view body. It looked right and was completely untappable below the first row —
// the nested rows never received touches. Composing siblings at the call site avoids that whole
// class of problem.

/// The name slot for one assignment. One row, one job.
struct AssignmentNameRow: View {
    @Bindable var assignment: Assignment
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            LabeledContent(assignment.role.displayName) {
                if let name = assignment.displayName, !name.isEmpty {
                    Text(name).foregroundStyle(.primary)
                } else {
                    Text("Choose").foregroundStyle(.secondary)
                }
            }
            // Without this the row only responds where its text is, and the gap in the middle —
            // the largest part of the row — does nothing.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPicking) {
            PersonPickerView(
                selection: $assignment.person,
                oneOffName: $assignment.displayNameOverride
            )
        }
    }
}

struct AssignmentCallingRow: View {
    @Bindable var assignment: Assignment

    var body: some View {
        TextField("Calling", text: Binding(
            get: { assignment.callingText ?? "" },
            set: { assignment.callingText = $0.isEmpty ? nil : $0 }
        ))
    }
}

struct AssignmentOfficeRow: View {
    @Bindable var assignment: Assignment

    var body: some View {
        TextField("Office (deacon, elder…)", text: Binding(
            get: { assignment.officeText ?? "" },
            set: { assignment.officeText = $0.isEmpty ? nil : $0 }
        ))
    }
}

struct AssignmentTopicRow: View {
    @Bindable var assignment: Assignment

    var body: some View {
        TextField("Topic", text: Binding(
            get: { assignment.topic ?? "" },
            set: { assignment.topic = $0.isEmpty ? nil : $0 }
        ))
    }
}

struct AssignmentStatusRow: View {
    @Bindable var assignment: Assignment

    var body: some View {
        Picker("Status", selection: $assignment.status) {
            ForEach(AssignmentStatus.allCases, id: \.self) { status in
                Text(status.displayName).tag(status)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// A colour-coded chip for an assignment's status, for the outline and conducting views.
struct StatusChip: View {
    let status: AssignmentStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch status {
        case .confirmed: .green
        case .invited: .orange
        case .declined: .red
        case .unassigned: .secondary
        }
    }
}

// MARK: - Hymns

/// A hymn slot: shows the choice, opens the picker, and surfaces any advisory warning.
struct HymnSlotRow: View {
    @Bindable var item: ProgramItem
    @State private var isPicking = false

    private var warnings: [HymnWarning] {
        guard let hymn = item.hymn else { return [] }
        return HymnValidator.warnings(for: [HymnPlacement(itemKind: item.kind, hymn: hymn)])
    }

    var body: some View {
        Button {
            isPicking = true
        } label: {
            LabeledContent("Hymn") {
                if let hymn = item.hymn {
                    Text(hymn.displayLabel).foregroundStyle(.primary)
                } else {
                    Text("Choose").foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPicking) {
            HymnPickerView(item: item)
        }

        ForEach(warnings) { warning in
            Label(warning.message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Item editors

/// The people in one business item.
///
/// There is exactly **one item per kind of business** in a meeting, holding as many people as it
/// needs. That's not an arbitrary choice: a sustaining reads one preamble, then each name and
/// calling in turn, then takes a single vote. Two separate sustaining items would repeat the
/// preamble and call for two votes, which isn't how it's done.
struct BusinessItemEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: ProgramItem

    var body: some View {
        ForEach(item.orderedAssignments) { assignment in
            AssignmentNameRow(assignment: assignment)
            if item.kind.takesCallingPerPerson {
                AssignmentCallingRow(assignment: assignment)
            }
            if item.kind == .ordinationProposal {
                AssignmentOfficeRow(assignment: assignment)
            }
            if assignment.isFilled {
                AssignmentStatusRow(assignment: assignment)
            }
            if item.orderedAssignments.count > 1 {
                Button("Remove \(assignment.displayName ?? "this person")", systemImage: "minus.circle", role: .destructive) {
                    context.delete(assignment)
                }
                .font(.footnote)
            }
        }
        Button("Add another person", systemImage: "plus") {
            MeetingFactory.addAssignment(role: .subject, to: item, in: context)
        }
        .font(.footnote)
    }
}

/// One kind of business in the wizard: either an "add" button, or the item with everything
/// needed to edit and remove it.
struct BusinessKindSection: View {
    let meeting: Meeting
    let kind: ItemKind
    @Environment(\.modelContext) private var context

    private var item: ProgramItem? {
        meeting.orderedItems.first { $0.kind == kind }
    }

    var body: some View {
        if let item {
            Section(kind.defaultTitle) {
                BusinessItemEditor(item: item)
                Button("Remove this \(kind.defaultTitle.lowercased())", systemImage: "trash", role: .destructive) {
                    MeetingFactory.deleteItem(item, from: meeting, in: context)
                }
                .font(.footnote)
            }
        } else {
            Button("Add \(kind.defaultTitle.lowercased())", systemImage: "plus") {
                let created = MeetingFactory.addItem(kind, to: meeting, in: context)
                MeetingFactory.addAssignment(role: .subject, to: created, in: context)
            }
        }
    }
}

struct OrdinanceItemEditor: View {
    @Bindable var item: ProgramItem

    var body: some View {
        ForEach(item.orderedAssignments) { assignment in
            AssignmentNameRow(assignment: assignment)
        }
        if item.kind == .babyBlessing {
            TextField("Family", text: Binding(
                get: { item.familyName ?? "" },
                set: { item.familyName = $0.isEmpty ? nil : $0 }
            ))
            Toggle("Family confirmed", isOn: $item.familyConfirmed)
        }
    }
}

/// Announcements as individually checkable lines, because you may read four of six.
struct AnnouncementsEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: ProgramItem
    @State private var draft = ""

    var body: some View {
        Section {
            ForEach(item.orderedEntries) { entry in
                @Bindable var entry = entry
                TextField("Announcement", text: $entry.text, axis: .vertical)
            }
            .onDelete { offsets in
                let entries = item.orderedEntries
                for index in offsets { context.delete(entries[index]) }
            }

            HStack {
                TextField("Add an announcement", text: $draft, axis: .vertical)
                Button("Add", systemImage: "plus.circle.fill") { add() }
                    .labelStyle(.iconOnly)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } footer: {
            Text("Each line is checked off separately during the meeting.")
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        MeetingFactory.addEntry(text: text, to: item, in: context)
        draft = ""
    }
}

// MARK: - Outline

/// One line of the program, as it reads on the outline.
struct OutlineRow: View {
    let item: ProgramItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                if let detail = detailText {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                let unconfirmed = item.orderedAssignments.filter(\.needsFollowUp)
                if !unconfirmed.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(unconfirmed) { StatusChip(status: $0.status) }
                    }
                }
            }
            Spacer()
            if item.isIncomplete {
                Image(systemName: "square.dashed")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Not yet filled in")
            }
        }
    }

    private var detailText: String? {
        if let hymn = item.hymn { return hymn.displayLabel }
        let names = item.orderedAssignments.compactMap(\.displayName).filter { !$0.isEmpty }
        if !names.isEmpty { return names.joined(separator: ", ") }
        if item.kind == .announcements {
            let count = item.orderedEntries.count
            return count > 0 ? "\(count) announcement\(count == 1 ? "" : "s")" : nil
        }
        return nil
    }
}
