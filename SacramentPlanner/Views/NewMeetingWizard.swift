import SacramentKit
import SwiftData
import SwiftUI

/// The prompted setup flow: one question per screen.
///
/// Every step is skippable and leaves a *visibly empty* slot rather than silently dropping it —
/// an unanswered question should still show up on the outline as something outstanding. Once the
/// meeting is created the wizard never runs again for it; you edit the outline directly.
struct NewMeetingWizard: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.unitNameKey) private var unitName = ""

    @State private var date = Self.nextSunday()
    @State private var kind: MeetingKind = .regular
    @State private var meeting: Meeting?
    @State private var step = 0

    private var steps: [WizardStep] {
        var result: [WizardStep] = [.leadership, .music, .prayers]
        if kind.hasAssignedSpeakers { result.append(.speakers) }
        result += [.business, .ordinances, .announcements, .review]
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if let meeting {
                    stepContent(for: steps[step], meeting: meeting)
                } else {
                    BasicsStep(date: $date, kind: $kind, unitName: $unitName)
                }
            }
            .navigationTitle(meeting == nil ? "New Meeting" : steps[step].title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if meeting == nil {
                        Button("Start") { start() }
                    } else if step == steps.count - 1 {
                        Button("Done") { dismiss() }
                    } else {
                        Button(currentStepIsSkippable ? "Skip" : "Next") { step += 1 }
                    }
                }
                if meeting != nil, step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { step -= 1 }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if meeting != nil {
                    ProgressView(value: Double(step + 1), total: Double(steps.count))
                        .progressViewStyle(.linear)
                        .padding()
                        .background(.bar)
                }
            }
        }
        .interactiveDismissDisabled(meeting != nil)
    }

    private var currentStepIsSkippable: Bool {
        guard let meeting else { return false }
        return steps[step].isSkippable(for: meeting)
    }

    @ViewBuilder
    private func stepContent(for step: WizardStep, meeting: Meeting) -> some View {
        switch step {
        case .leadership: LeadershipStep(meeting: meeting)
        case .music: MusicStep(meeting: meeting)
        case .prayers: PrayersStep(meeting: meeting)
        case .speakers: SpeakersStep(meeting: meeting)
        case .business: BusinessStep(meeting: meeting)
        case .ordinances: OrdinancesStep(meeting: meeting)
        case .announcements: AnnouncementsStep(meeting: meeting)
        case .review: ReviewStep(meeting: meeting)
        }
    }

    private func start() {
        meeting = MeetingFactory.makeMeeting(kind: kind, date: date, unitName: unitName, in: context)
    }

    private func cancel() {
        if let meeting {
            context.delete(meeting)
        }
        dismiss()
    }

    /// Defaults to the coming Sunday, which is the meeting you're almost always planning.
    static func nextSunday() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.component(.weekday, from: today) == 1 { return today }
        return calendar.nextDate(
            after: today,
            matching: DateComponents(weekday: 1),
            matchingPolicy: .nextTime
        ) ?? today
    }
}

enum WizardStep {
    case leadership, music, prayers, speakers, business, ordinances, announcements, review

    var title: String {
        switch self {
        case .leadership: "Who is presiding?"
        case .music: "What are the songs?"
        case .prayers: "Who is praying?"
        case .speakers: "Who is speaking?"
        case .business: "Any ward business?"
        case .ordinances: "Any blessings?"
        case .announcements: "Any announcements?"
        case .review: "Review"
        }
    }

    /// A step only offers to be skipped while it's still empty.
    ///
    /// Occasional things say "Skip"; the weekly essentials say "Next" even when blank, so leaving
    /// one empty reads as a decision rather than an accident. And once you've put something into
    /// a step, "Skip" is simply the wrong word for the button that moves you on.
    func isSkippable(for meeting: Meeting) -> Bool {
        switch self {
        case .business:
            !meeting.orderedItems.contains { $0.kind.isBusiness || $0.kind == .stakeBusiness }
        case .ordinances:
            !meeting.orderedItems.contains { $0.kind.isOrdinance }
        case .announcements:
            meeting.orderedItems.first { $0.kind == .announcements }?.orderedEntries.isEmpty ?? true
        default:
            false
        }
    }
}

// MARK: - Steps

private struct BasicsStep: View {
    @Binding var date: Date
    @Binding var kind: MeetingKind
    @Binding var unitName: String

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Meeting type", selection: $kind) {
                    ForEach(MeetingKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
            }
            Section("Ward") {
                TextField("Ward or branch name", text: $unitName)
            }
            Section {
                Text(kind.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LeadershipStep: View {
    @Bindable var meeting: Meeting

    var body: some View {
        Form {
            Section {
                PersonRow(label: "Presiding", person: $meeting.presiding)
                PersonRow(label: "Conducting", person: $meeting.conducting)
            } footer: {
                Text(meeting.kind == .wardConference
                     ? "In ward conference the bishop conducts while a member of the stake presidency presides."
                     : "The bishop presides. He may ask a counselor to conduct.")
            }
            Section("Music") {
                PersonRow(label: "Chorister", person: $meeting.chorister)
                PersonRow(label: "Organist", person: $meeting.organist)
            }
            Section("Theme") {
                TextField("Optional", text: Binding(
                    get: { meeting.theme ?? "" },
                    set: { meeting.theme = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }
}

/// Every hymn in the meeting on one page — they're chosen together, so they're picked together.
private struct MusicStep: View {
    let meeting: Meeting

    private var items: [ProgramItem] {
        meeting.orderedItems.filter(\.kind.isHymn)
    }

    var body: some View {
        Form {
            if items.isEmpty {
                ContentUnavailableView("No music slots", systemImage: "music.note")
            }
            ForEach(items) { item in
                Section(item.title) {
                    HymnSlotRow(item: item)
                }
            }
        }
    }
}

private struct PrayersStep: View {
    let meeting: Meeting

    private var items: [ProgramItem] {
        meeting.orderedItems.filter(\.kind.isPrayer)
    }

    var body: some View {
        Form {
            ForEach(items) { item in
                Section(item.title) {
                    ForEach(item.orderedAssignments) { assignment in
                        AssignmentNameRow(assignment: assignment)
                        if assignment.isFilled {
                            AssignmentStatusRow(assignment: assignment)
                        }
                    }
                }
            }
        }
    }
}

private struct SpeakersStep: View {
    @Environment(\.modelContext) private var context
    let meeting: Meeting

    private var items: [ProgramItem] {
        meeting.orderedItems.filter { $0.kind == .speaker }
    }

    var body: some View {
        Form {
            ForEach(items) { item in
                Section(item.title) {
                    ForEach(item.orderedAssignments) { assignment in
                        AssignmentNameRow(assignment: assignment)
                        AssignmentTopicRow(assignment: assignment)
                        if assignment.isFilled {
                            AssignmentStatusRow(assignment: assignment)
                        }
                    }
                }
            }
            Section {
                Button("Add another speaker", systemImage: "plus") {
                    let item = MeetingFactory.addItem(.speaker, to: meeting, in: context)
                    item.needsFilling = true
                    MeetingFactory.addAssignment(role: .speaker, to: item, in: context)
                }
            }
        }
    }
}

private struct BusinessStep: View {
    let meeting: Meeting

    /// One section per kind, each either an "add" button or the item itself. There's no way to
    /// end up with two releases, so there's no ambiguity about what a second "Add release" would
    /// have meant — several people in one release is the only thing it could be, and that's what
    /// "Add another person" does.
    private let kinds: [ItemKind] = [
        .release, .sustaining, .ordinationProposal, .newMemberWelcome, .movingInRecord, .stakeBusiness,
    ]

    var body: some View {
        Form {
            Section {
                Text("Most weeks there are none, and the meeting will simply say so.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(kinds, id: \.self) { kind in
                BusinessKindSection(meeting: meeting, kind: kind)
            }
        }
    }
}

private struct OrdinancesStep: View {
    @Environment(\.modelContext) private var context
    let meeting: Meeting

    private var items: [ProgramItem] {
        meeting.orderedItems.filter(\.kind.isOrdinance)
    }

    var body: some View {
        Form {
            Section {
                Text("Only what's needed to announce it correctly. The clerk's records remain the official ones.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            // Unlike ward business, these genuinely repeat: two children blessed in one meeting
            // are two separate events with two officiators. So each gets its own item, and each
            // item can be removed on its own.
            ForEach(items) { item in
                Section(item.title) {
                    OrdinanceItemEditor(item: item)
                    Button("Remove this \(item.kind.defaultTitle.lowercased())", systemImage: "trash", role: .destructive) {
                        MeetingFactory.deleteItem(item, from: meeting, in: context)
                    }
                    .font(.footnote)
                }
            }
            Section {
                ForEach([ItemKind.babyBlessing, .confirmation], id: \.self) { kind in
                    Button("Add \(kind.defaultTitle.lowercased())", systemImage: "plus") {
                        let item = MeetingFactory.addItem(kind, to: meeting, in: context)
                        if kind == .confirmation {
                            MeetingFactory.addAssignment(role: .subject, to: item, in: context)
                        }
                        MeetingFactory.addAssignment(role: .officiator, to: item, in: context)
                    }
                }
            }
        }
    }
}

private struct AnnouncementsStep: View {
    let meeting: Meeting

    private var item: ProgramItem? {
        meeting.orderedItems.first { $0.kind == .announcements }
    }

    var body: some View {
        Form {
            if let item {
                AnnouncementsEditor(item: item)
            } else {
                ContentUnavailableView("No announcements slot", systemImage: "megaphone")
            }
        }
    }
}

private struct ReviewStep: View {
    let meeting: Meeting

    var body: some View {
        List {
            Section {
                ReadinessBadge(meeting: meeting)
            }
            Section("Program") {
                ForEach(meeting.orderedItems) { item in
                    OutlineRow(item: item)
                }
            }
            if !meeting.incompleteItems.isEmpty {
                Section("Still to fill") {
                    ForEach(meeting.incompleteItems) { item in
                        Text(item.title)
                    }
                }
            }
        }
    }
}

private extension MeetingKind {
    var blurb: String {
        switch self {
        case .regular:
            "The standard weekly meeting with assigned speakers."
        case .fastAndTestimony:
            "No assigned speakers. The congregation is invited to bear testimony."
        case .wardConference:
            "The bishop conducts, a member of the stake presidency presides, and ward officers are sustained."
        case .specialProgram:
            "A Primary presentation, Christmas or Easter program: a fixed frame around a freeform middle."
        }
    }
}
