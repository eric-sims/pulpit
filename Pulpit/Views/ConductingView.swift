import PulpitKit
import SwiftData
import SwiftUI

/// The view you actually stand at a pulpit with.
///
/// Deliberately not a mode of the outline editor. Planning is data entry; conducting is a
/// heads-up display you glance at one-handed while a congregation watches. They share a model and
/// nothing else.
///
/// Design rules this view holds to:
/// - Nothing is gesture-only. Every action has a visible control, because discovering a swipe
///   mid-meeting is not a thing anyone should have to do.
/// - The screen never sleeps.
/// - The current item is always identifiable, whether or not it's scrolled into view.
struct ConductingView: View {
    @Bindable var meeting: Meeting

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var templates: [ScriptTemplate]

    @AppStorage("conducting.fontScale") private var fontScale = 1.0
    @AppStorage("conducting.chapelMode") private var chapelMode = true

    /// The device's Dynamic Type multiplier, as a plain number.
    ///
    /// This view sizes its text in points so the in-meeting stepper can push it well past what
    /// you'd want elsewhere on your phone. Sizing in points also means it would otherwise ignore
    /// the system text size completely — so every size here is multiplied by this as well, and
    /// someone running Larger Text still gets larger text.
    @ScaledMetric(relativeTo: .body) private var typeScale = 1.0

    @State private var activeItemID: UUID?
    @State private var isAddingItem = false
    @State private var isConfirmingReset = false

    /// The pulpit stepper and the system text size, combined.
    private var textScale: Double { fontScale * typeScale }

    private var items: [ProgramItem] { meeting.orderedItems }

    private var activeItem: ProgramItem? {
        items.first { $0.id == activeItemID } ?? items.first { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(items) { item in
                        row(for: item, proxy: proxy)
                            .id(item.id)
                    }
                }
                .listStyle(.plain)
                .scrollEdgeEffectStyle(.hard, for: [.top, .bottom])
                .safeAreaInset(edge: .top) { pinnedActiveBar(proxy: proxy) }
                .safeAreaInset(edge: .bottom) { progressBar }
                .onAppear { beginConducting(proxy: proxy) }
            }
            .navigationTitle(meeting.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isAddingItem) { AddItemSheet(meeting: meeting) }
            .confirmationDialog(
                "Clear every check and start this meeting again?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("Start Over", role: .destructive) { resetProgress() }
            }
        }
        .preferredColorScheme(chapelMode ? .dark : nil)
        // A phone that sleeps mid-meeting is worse than no phone at all.
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in
            // Don't hold the device awake once the app is no longer in front.
            UIApplication.shared.isIdleTimerDisabled = (phase == .active)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: ProgramItem, proxy: ScrollViewProxy) -> some View {
        let isActive = item.id == activeItem?.id

        VStack(alignment: .leading, spacing: 0) {
            ConductingRowHeader(
                item: item,
                isActive: isActive,
                textScale: textScale,
                onToggle: { toggle(item, proxy: proxy) }
            )
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { activeItemID = item.id } }

            if isActive {
                ConductingRowDetail(
                    item: item,
                    meeting: meeting,
                    templates: templates,
                    textScale: textScale,
                    onComplete: { complete(item, proxy: proxy) },
                    onSkip: { skip(item, proxy: proxy) }
                )
                .padding(.top, 12)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(isActive ? Color.accentColor.opacity(0.10) : Color.clear)
    }

    // MARK: - Chrome

    /// Always-present marker for where you are in the meeting, with a jump back to it.
    ///
    /// This was going to appear only when the active row scrolled out of view, but
    /// `onScrollVisibilityChange` doesn't fire for rows inside a `List`, and a bar that silently
    /// fails to appear is worse than one that's occasionally redundant. Standing at a pulpit, the
    /// current item should never be more than a glance away.
    @ViewBuilder
    private func pinnedActiveBar(proxy: ScrollViewProxy) -> some View {
        if let item = activeItem {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.system(size: 17 * textScale, weight: .semibold))
                        .lineLimit(2)
                        // Without this a long title breaks mid-word at accessibility sizes —
                        // "Welco / me" — because one word no longer fits the column.
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                Button("Go") {
                    withAnimation {
                        activeItemID = item.id
                        proxy.scrollTo(item.id, anchor: .top)
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .accessibilityLabel("Scroll to the current item")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }

    /// Both pinned bars sit on Liquid Glass: they're custom controls floating over the content
    /// layer, and they're the two most important functional elements on this screen. A scroll edge
    /// effect alone left the script text legible *through* them at accessibility text sizes.
    private var progressBar: some View {
        let resolved = items.filter(\.status.isResolved).count
        return HStack {
            // Both counters stay on one line and let the track take the slack; wrapped, they
            // doubled the height of the bar at accessibility text sizes.
            Text("\(resolved) of \(items.count)")
                .font(.caption)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            ProgressView(value: Double(resolved), total: Double(max(items.count, 1)))
            if let started = meeting.conductingStartedAt {
                TimelineView(.periodic(from: started, by: 30)) { _ in
                    Text(elapsed(since: started))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                // A stepper *on top of* Dynamic Type: at a pulpit you want this bigger than you
                // want the rest of your phone. `typeScale` still applies underneath, so the
                // system text size is respected either way.
                Button("Larger Text", systemImage: "textformat.size.larger") {
                    fontScale = min(fontScale + 0.15, 2.0)
                }
                Button("Smaller Text", systemImage: "textformat.size.smaller") {
                    fontScale = max(fontScale - 0.15, 0.85)
                }
                Toggle("Chapel Mode", systemImage: "moon", isOn: $chapelMode)
                Divider()
                Button("Add Item", systemImage: "plus") { isAddingItem = true }
                Button("Start Over", systemImage: "arrow.counterclockwise", role: .destructive) {
                    isConfirmingReset = true
                }
            } label: {
                Label("Options", systemImage: "ellipsis")
            }
        }
        // "Done" is a text label and the menu is a symbol; without a gap between them the two read
        // as one control. See HIG > Toolbars > Item groupings.
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Actions

    private func beginConducting(proxy: ScrollViewProxy) {
        if meeting.conductingStartedAt == nil {
            meeting.conductingStartedAt = Date()
        }
        let next = items.first { $0.status == .pending } ?? items.first
        activeItemID = next?.id
        if let next {
            DispatchQueue.main.async { proxy.scrollTo(next.id, anchor: .top) }
        }
    }

    private func toggle(_ item: ProgramItem, proxy: ScrollViewProxy) {
        if item.status.isResolved {
            item.status = .pending
            item.resolvedAt = nil
            withAnimation { activeItemID = item.id }
        } else {
            complete(item, proxy: proxy)
        }
    }

    private func complete(_ item: ProgramItem, proxy: ScrollViewProxy) {
        item.status = .completed
        item.resolvedAt = Date()
        advance(past: item, proxy: proxy)
    }

    private func skip(_ item: ProgramItem, proxy: ScrollViewProxy) {
        item.status = .skipped
        item.resolvedAt = Date()
        advance(past: item, proxy: proxy)
    }

    /// Moves to the next unresolved item after this one, wrapping to anything left behind.
    private func advance(past item: ProgramItem, proxy: ScrollViewProxy) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let next = items[items.index(after: index)...].first { $0.status == .pending }
            ?? items.first { $0.status == .pending }

        withAnimation {
            activeItemID = next?.id
            if let next {
                proxy.scrollTo(next.id, anchor: .top)
            }
        }
    }

    private func resetProgress() {
        for item in items {
            item.status = .pending
            item.resolvedAt = nil
            for entry in item.orderedEntries { entry.isChecked = false }
        }
        meeting.conductingStartedAt = Date()
        activeItemID = items.first?.id
    }

    private func elapsed(since start: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(start) / 60))
        return "\(minutes) min"
    }
}

// MARK: - Row header

private struct ConductingRowHeader: View {
    let item: ProgramItem
    let isActive: Bool
    let textScale: Double
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: symbol)
                    .font(.system(size: 26 * textScale))
                    .foregroundStyle(tint)
                    // A 26pt glyph is a 26pt target. The minimum is 44.
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.status == .completed ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 19 * textScale, weight: isActive ? .bold : .medium))
                    .strikethrough(item.status == .skipped)
                    .foregroundStyle(item.status.isResolved && !isActive ? .secondary : .primary)

                if let detail = detailText {
                    Text(detail)
                        .font(.system(size: 15 * textScale))
                        .foregroundStyle(.secondary)
                }
                if item.status == .skipped {
                    Text("Skipped")
                        .font(.system(size: 13 * textScale))
                        .foregroundStyle(.orange)
                }
            }
            // Centres the title against the 44pt tap target without pinning the two to a shared
            // baseline, which the taller target would otherwise drag out of line.
            .frame(minHeight: 44, alignment: .center)
            Spacer(minLength: 0)
        }
    }

    private var symbol: String {
        switch item.status {
        case .completed: "checkmark.circle.fill"
        case .skipped: "minus.circle.fill"
        case .pending: "circle"
        }
    }

    private var tint: Color {
        switch item.status {
        case .completed: .green
        case .skipped: .orange
        case .pending: isActive ? .accentColor : .secondary
        }
    }

    private var detailText: String? {
        if let hymn = item.hymn { return hymn.displayLabel }
        let names = item.orderedAssignments.compactMap(\.displayName).filter { !$0.isEmpty }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

// MARK: - Expanded detail

private struct ConductingRowDetail: View {
    let item: ProgramItem
    let meeting: Meeting
    let templates: [ScriptTemplate]
    let textScale: Double
    let onComplete: () -> Void
    let onSkip: () -> Void

    @Environment(\.modelContext) private var context

    private var rendering: ScriptRendering? {
        ScriptComposer.render(item, in: meeting, templates: templates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if item.kind.supportsEntries, !item.orderedEntries.isEmpty {
                entryChecklist
            }

            if let rendering {
                Text(rendering.attributedString)
                    .font(.system(size: 20 * textScale))
                    .lineSpacing(5 * textScale)
                    .textSelection(.enabled)
            }

            let pronunciations = ScriptComposer.pronunciationNotes(for: item)
            if !pronunciations.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(pronunciations, id: \.name) { note in
                        Text("\(note.name) — \(note.phonetic)")
                            .font(.system(size: 15 * textScale, design: .serif))
                            .italic()
                    }
                }
                .foregroundStyle(.secondary)
            }

            if let notes = item.notes, !notes.isEmpty {
                Label(notes, systemImage: "note.text")
                    .font(.system(size: 15 * textScale))
                    .foregroundStyle(.secondary)
            }

            if item.kind == .sacrament {
                Label(
                    "Nothing else happens during the administration and passing — no announcements, no music, no other business.",
                    systemImage: "hand.raised"
                )
                .font(.system(size: 14 * textScale))
                .foregroundStyle(.secondary)
            }

            // Visible controls, not swipes: mid-meeting is the worst time to hunt for a gesture.
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    WideButtonLabel(title: "Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSkip) {
                    WideButtonLabel(title: "Skip", systemImage: "arrow.turn.down.right")
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 17 * textScale))
            .controlSize(.large)
        }
    }

    /// Announcements check off one at a time, and the block only finishes when all of them have.
    private var entryChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(item.orderedEntries) { entry in
                Button {
                    entry.isChecked.toggle()
                    if item.orderedEntries.allSatisfy(\.isChecked) {
                        onComplete()
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: entry.isChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22 * textScale))
                            .foregroundStyle(entry.isChecked ? .green : .secondary)
                        Text(entry.text)
                            .font(.system(size: 18 * textScale))
                            .strikethrough(entry.isChecked)
                            .foregroundStyle(entry.isChecked ? .secondary : .primary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.text)
                .accessibilityAddTraits(entry.isChecked ? .isSelected : [])
            }
        }
    }
}
