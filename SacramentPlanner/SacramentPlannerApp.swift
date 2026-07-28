import SacramentKit
import SwiftData
import SwiftUI

@main
struct SacramentPlannerApp: App {
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
    var body: some View {
        TabView {
            Tab("Meetings", systemImage: "list.bullet.rectangle.portrait") {
                MeetingListView()
            }
            Tab("Roster", systemImage: "person.2") {
                RosterView()
            }
            Tab("Scripts", systemImage: "text.quote") {
                ScriptLibraryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        // Gives iPad a sidebar without a second layout to maintain.
        .tabViewStyle(.sidebarAdaptable)
    }
}
