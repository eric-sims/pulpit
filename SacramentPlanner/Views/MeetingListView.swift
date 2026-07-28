import SacramentKit
import SwiftData
import SwiftUI

struct MeetingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @State private var isCreatingMeeting = false

    private var upcoming: [Meeting] {
        // Everything from the start of today onwards, oldest first, so the next meeting is first.
        let today = Calendar.current.startOfDay(for: Date())
        return meetings.filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    private var past: [Meeting] {
        let today = Calendar.current.startOfDay(for: Date())
        return meetings.filter { $0.date < today }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    ContentUnavailableView {
                        Label("No Meetings Yet", systemImage: "list.bullet.rectangle.portrait")
                    } description: {
                        Text("Plan a sacrament meeting and it will appear here.")
                    } actions: {
                        Button("Plan a Meeting") { isCreatingMeeting = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { MeetingRow(meeting: $0) }
                                    .onDelete { delete(upcoming, at: $0) }
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { MeetingRow(meeting: $0) }
                                    .onDelete { delete(past, at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meetings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Plan a Meeting", systemImage: "plus") { isCreatingMeeting = true }
                }
            }
            .sheet(isPresented: $isCreatingMeeting) {
                NewMeetingWizard()
            }
        }
    }

    private func delete(_ source: [Meeting], at offsets: IndexSet) {
        for index in offsets {
            context.delete(source[index])
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        NavigationLink(destination: MeetingOutlineView(meeting: meeting)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.date, format: .dateTime.weekday(.wide).month().day().year())
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(meeting.kind.shortName)
                    if let theme = meeting.theme, !theme.isEmpty {
                        Text("·")
                        Text(theme)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                ReadinessBadge(meeting: meeting)
            }
            .padding(.vertical, 2)
        }
    }
}

/// A one-glance answer to "is this meeting ready?", which is the question you actually have on a
/// Saturday night.
struct ReadinessBadge: View {
    let meeting: Meeting

    private var incompleteCount: Int { meeting.incompleteItems.count }
    private var unconfirmedCount: Int { meeting.unconfirmedAssignments.count }

    var body: some View {
        if meeting.isReady {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            HStack(spacing: 10) {
                if incompleteCount > 0 {
                    Label("\(incompleteCount) to fill", systemImage: "square.dashed")
                }
                if unconfirmedCount > 0 {
                    Label("\(unconfirmedCount) unconfirmed", systemImage: "questionmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}
