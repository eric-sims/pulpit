import Foundation
import SQLite3
import SwiftData

/// Cleanup for stores written before `Person` declared its inverse relationships.
///
/// Without an inverse, deleting someone from the roster didn't clear the assignments and meetings
/// that pointed at them — those kept a reference to a row that was no longer in the store. Reading
/// one doesn't return nil, it traps:
///
///     Fatal error: This model instance was invalidated because its backing data could no longer
///     be found the store. PersistentIdentifier(… /Person/p1)
///
/// The meeting list reads every assignment on the first screen to draw its readiness badges, so an
/// affected store crashed the app on launch, every launch, with no way back in.
///
/// `Person` now declares the inverses, so no new dangling references can be written. Clearing the
/// ones already on disk has to happen here, in SQL, before the container opens. Going through
/// SwiftData doesn't work: assigning nil to the relationship makes it maintain the new inverse,
/// which materializes the very row that isn't there and trips the same trap the repair exists to
/// avoid. Reading is safe, writing is not, so there's no repair to be had from inside the graph.
enum StoreRepair {
    /// Clears references to people who are no longer in the store.
    ///
    /// The names on those references are unrecoverable — that they can't be read is the whole
    /// problem — so the affected slots go back to being unfilled.
    static func clearDanglingPersonReferences(at storeURL: URL) {
        // Every to-one from another entity to Person. The FK lives on the referring row, which is
        // what makes this expressible as plain SQL.
        let references = [
            ("ZASSIGNMENT", "ZPERSON"),
            ("ZMEETING", "ZPRESIDING"),
            ("ZMEETING", "ZCONDUCTING"),
            ("ZMEETING", "ZCHORISTER"),
            ("ZMEETING", "ZORGANIST"),
        ]

        var db: OpaquePointer?
        // No SQLITE_OPEN_CREATE: on a first run there's no store yet and nothing to repair.
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }
        defer { sqlite3_close(db) }

        for (table, column) in references {
            // A store from a build that predates one of these columns simply fails the statement,
            // which is the same as having nothing to fix.
            let sql = """
                UPDATE \(table) SET \(column) = NULL
                 WHERE \(column) IS NOT NULL
                   AND \(column) NOT IN (SELECT Z_PK FROM ZPERSON);
                """
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }
}
