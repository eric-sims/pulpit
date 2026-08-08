import Foundation

/// Representative sample data for previewing a template as you edit it.
///
/// The template editor shows the rendered result live, which is the only practical way to tell
/// whether wording reads correctly — you can't evaluate `{{names}} {{has}} been called` by
/// looking at it.
public enum ScriptPreview {

    /// A context with plausible values for the given script, using a sister by default so the
    /// preview exercises gendered wording rather than the neutral fallback.
    public static func sampleContext(for kind: ScriptKind, pronouns: PronounSet = .she) -> ScriptContext {
        let subject = ScriptPerson(fullName: "Jane Doe", pronouns: pronouns)
        let officiator = ScriptPerson(fullName: "David Larsen", pronouns: .he)

        switch kind {
        case .babyBlessing:
            return ScriptContext(
                officiators: [ScriptPerson(fullName: "Mark Nielsen", pronouns: .he)],
                family: "Nielsen",
                unitName: sampleUnitName
            )
        case .confirmation:
            return ScriptContext(
                people: [subject],
                officiators: [officiator],
                unitName: sampleUnitName
            )
        case .ordinationProposal:
            return ScriptContext(
                people: [ScriptPerson(fullName: "Samuel Hale", pronouns: .he)],
                office: "elder",
                unitName: sampleUnitName
            )
        case .sustaining, .release:
            // Two subjects with different callings, because that's the case the wording is built
            // for and the one a single-person preview would hide.
            return ScriptContext(
                subjects: [
                    ScriptSubject(person: subject, calling: "Relief Society President"),
                    ScriptSubject(
                        person: ScriptPerson(fullName: "John Smith", pronouns: .he),
                        calling: "Sunday School Teacher"
                    ),
                ],
                unitName: sampleUnitName
            )
        case .recognition:
            return ScriptContext(
                people: [ScriptPerson(fullName: "Paul Weeks", title: "President", pronouns: .he)],
                unitName: sampleUnitName
            )
        case .newMemberWelcome, .movingInRecord:
            return ScriptContext(people: [subject], unitName: sampleUnitName)
        case .stakeBusiness:
            return ScriptContext(
                people: [ScriptPerson(fullName: "Paul Weeks", title: "President", pronouns: .he)],
                unitName: sampleUnitName
            )
        case .wardBusiness:
            // Previewed as a week with business to present; the other branch is what shows on a
            // quiet week.
            return ScriptContext(unitName: sampleUnitName, flags: ["hasWardBusiness"])
        case .welcome, .sacramentTransition, .testimonyInvitation:
            return ScriptContext(unitName: sampleUnitName)
        }
    }

    public static let sampleUnitName = "Cold Spring Ranch 3rd Ward"

    /// Renders a template against sample data, for the editor's live preview.
    public static func preview(
        _ body: String,
        for kind: ScriptKind,
        pronouns: PronounSet = .she
    ) -> ScriptRendering {
        ScriptRenderer.render(body, context: sampleContext(for: kind, pronouns: pronouns))
    }
}
