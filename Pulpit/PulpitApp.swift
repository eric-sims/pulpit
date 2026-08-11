import PulpitKit
import SwiftData
import SwiftUI

@main
struct PulpitApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Meeting.self,
            ProgramItem.self,
            ItemEntry.self,
            Assignment.self,
            Person.self,
            Announcement.self,
            ScriptTemplate.self,
        ])
        // Local-only for now. Every model is already shaped for CloudKit, so enabling sync later
        // is a change to this configuration rather than a migration.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        // Before the container opens, which is the only point where this is fixable at all: a
        // store from a build before Person had its inverses can hold references to deleted
        // people, and reading one traps. See StoreRepair.
        StoreRepair.clearDanglingPersonReferences(at: configuration.url)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the meeting store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { SeedData.seedIfNeeded(in: modelContainer.mainContext) }
        }
        .modelContainer(modelContainer)
    }
}

/// The unit name, kept in preferences rather than on each meeting so it doesn't need retyping.
/// Meetings still store their own copy, so an imported meeting from another ward stays correct.
enum Preferences {
    static let unitNameKey = "unitName"
}

struct RootView: View {
    @State private var inbox = ImportInbox()

    var body: some View {
        tabs
            .environment(inbox)
            // A .pulpitplan opened from Messages, AirDrop or Files lands here and goes through
            // the same preview as one picked from the file browser.
            .onOpenURL { inbox.accept($0) }
            .sheet(isPresented: $inbox.isShowingPreview) {
                if let pending = inbox.pending {
                    ImportPreviewView(result: pending)
                }
            }
            .alert("Couldn't Open File", isPresented: .constant(inbox.errorMessage != nil)) {
                Button("OK") { inbox.errorMessage = nil }
            } message: {
                Text(inbox.errorMessage ?? "")
            }
    }

    private var tabs: some View {
        TabView {
            Tab("Meetings", systemImage: "list.bullet.rectangle.portrait.fill") {
                MeetingListView()
            }
            Tab("Roster", systemImage: "person.2.fill") {
                RosterView()
            }
            Tab("Scripts", systemImage: "quote.bubble.fill") {
                ScriptLibraryView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        // Gives iPad a sidebar without a second layout to maintain.
        .tabViewStyle(.sidebarAdaptable)
    }
}
