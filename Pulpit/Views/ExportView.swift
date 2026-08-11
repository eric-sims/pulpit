import PulpitKit
import SwiftData
import SwiftUI

/// Export options for one meeting.
///
/// The two outputs are deliberately separate buttons rather than one button and a format picker.
/// They answer different questions — "give me something to read" and "give this meeting to a
/// counselor" — and choosing between them shouldn't require a dialog.
struct ExportView: View {
    let meeting: Meeting

    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [ScriptTemplate]

    /// Off by default. Conducting notes can carry things that shouldn't leave your phone, and
    /// sharing a meeting is not consent to hand those over.
    @State private var includePrivateNotes = false
    @State private var exported: ExportedFile?
    @State private var isWorking = false
    @State private var errorMessage: String?

    /// Whether the failure alert is up. Settable, so the `false` SwiftUI writes on dismissal
    /// clears the error instead of being dropped. See `ImportInbox.isShowingError`.
    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var hasPrivateNotes: Bool {
        if let notes = meeting.notes, !notes.isEmpty { return true }
        return meeting.orderedItems.contains { item in
            (item.notes?.isEmpty == false)
                || item.orderedAssignments.contains { $0.statusNote?.isEmpty == false }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        Task { await exportPDF() }
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("Your conducting sheet: every item, the full scripts, names with pronunciations. Not the congregation's program.")
                }

                Section {
                    Button {
                        shareInterchange()
                    } label: {
                        Label("Share to Another App User", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("A .pulpitplan file they can import. Send it however you like — Messages, Mail, AirDrop.")
                }

                if hasPrivateNotes {
                    Section {
                        Toggle("Include Private Notes", isOn: $includePrivateNotes)
                    } footer: {
                        Text("This meeting has private notes. They're left out unless you say otherwise. Notes about people in your roster never travel at all.")
                    }
                }

                if isWorking {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Preparing…").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
            .sheet(item: $exported) { file in
                ShareSheet(url: file.url)
            }
            .alert("Export Failed", isPresented: isShowingError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

    private func exportPDF() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let url = try await ExportService.conductingSheetPDF(
                for: meeting,
                templates: templates,
                includePrivateNotes: includePrivateNotes
            )
            exported = ExportedFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shareInterchange() {
        do {
            let url = try ExportService.interchangeFile(
                for: meeting,
                includePrivateNotes: includePrivateNotes
            )
            exported = ExportedFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
