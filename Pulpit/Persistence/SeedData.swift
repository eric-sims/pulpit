import Foundation
import PulpitKit
import SwiftData

enum SeedData {

    /// Puts the shipped script wording into the store on first launch, and refreshes any template
    /// you haven't edited when the shipped defaults move on.
    ///
    /// Templates you *have* edited are never touched — `isUserModified` is the whole point of the
    /// flag. Those surface as "out of date" in the script library instead, so you can compare.
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ScriptTemplate>())) ?? []
        var byKind: [ScriptKind: ScriptTemplate] = [:]
        for template in existing {
            if let kind = template.kind { byKind[kind] = template }
        }

        for seed in DefaultScripts.all {
            if let template = byKind[seed.kind] {
                if !template.isUserModified, template.seedVersion < seed.seedVersion {
                    template.body = seed.body
                    template.seedVersion = seed.seedVersion
                }
            } else {
                context.insert(ScriptTemplate(kind: seed.kind, body: seed.body, seedVersion: seed.seedVersion))
            }
        }

        try? context.save()
    }
}
