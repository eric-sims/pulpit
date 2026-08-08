import Testing
@testable import PulpitKit

@Suite("Shipped script defaults")
struct DefaultScriptsTests {

    private func fullContext(people: [ScriptPerson]) -> ScriptContext {
        ScriptContext(
            people: people,
            officiators: [ScriptPerson(fullName: "David Larsen", pronouns: .he)],
            calling: "Elders Quorum President",
            office: "elder",
            family: "Nielsen",
            unitName: "Highland 4th Ward"
        )
    }

    /// A typo in a token name would otherwise ship silently and only surface at a pulpit.
    @Test("Every shipped script renders cleanly for every pronoun set", arguments: PronounSet.allCases)
    func allScriptsRenderCleanly(pronouns: PronounSet) {
        for kind in ScriptKind.allCases {
            let context = fullContext(people: [ScriptPerson(fullName: "John Smith", pronouns: pronouns)])
            let output = ScriptRenderer.render(DefaultScripts.body(for: kind), context: context)

            #expect(output.issues.isEmpty, "\(kind.rawValue) produced \(output.issues)")
            #expect(!output.plainText.contains("{{"), "\(kind.rawValue) left an unresolved placeholder")
        }
    }

    @Test("Every shipped script renders cleanly for several people")
    func allScriptsRenderForGroups() {
        let context = fullContext(people: [
            ScriptPerson(fullName: "John Smith", pronouns: .he),
            ScriptPerson(fullName: "Jane Doe", pronouns: .she),
        ])
        for kind in ScriptKind.allCases {
            let output = ScriptRenderer.render(DefaultScripts.body(for: kind), context: context)
            #expect(output.issues.isEmpty, "\(kind.rawValue) produced \(output.issues)")
        }
    }

    @Test("Sustaining reads a preamble, then one line per person, then a single vote")
    func sustainingWording() {
        let context = ScriptContext(
            subjects: [
                ScriptSubject(
                    person: ScriptPerson(fullName: "Jane Doe", pronouns: .she),
                    calling: "Relief Society President"
                ),
                ScriptSubject(
                    person: ScriptPerson(fullName: "John Smith", pronouns: .he),
                    calling: "Sunday School Teacher"
                ),
            ],
            unitName: "Cold Spring Ranch 3rd Ward"
        )
        let text = ScriptRenderer.render(DefaultScripts.body(for: .sustaining), context: context).plainText

        #expect(text.hasPrefix("The following members have been called to the positions indicated."))
        #expect(text.contains("Please stand as your names are read"))
        // Each person keeps their own calling and their own verb agreement.
        #expect(text.contains("Sister Jane Doe has been called as Relief Society President."))
        #expect(text.contains("Brother John Smith has been called as Sunday School Teacher."))
        // One vote covers them all.
        #expect(text.components(separatedBy: "All in favor").count == 2)
        #expect(text.contains("Any opposed may also manifest it."))
    }

    @Test("A release asks for a vote of thanks, not a sustaining vote")
    func releaseWording() {
        let context = ScriptContext(
            subjects: [
                ScriptSubject(
                    person: ScriptPerson(fullName: "John Smith", pronouns: .he),
                    calling: "Ward Clerk"
                )
            ]
        )
        let text = ScriptRenderer.render(DefaultScripts.body(for: .release), context: context).plainText

        #expect(text.contains("vote of thanks for their service"))
        #expect(text.contains("Brother John Smith has been released as Ward Clerk."))
        #expect(text.contains("Those who wish to express their appreciation"))
        #expect(!text.contains("sustain"))
    }

    @Test("A missing calling doesn't leave a dangling clause")
    func missingCallingReadsCleanly() {
        let context = ScriptContext(subjects: [
            ScriptSubject(person: ScriptPerson(fullName: "Jane Doe", pronouns: .she))
        ])
        let text = ScriptRenderer.render(DefaultScripts.body(for: .sustaining), context: context).plainText

        #expect(text.contains("Sister Jane Doe has been called."))
        #expect(!text.contains("called as."))
    }

    @Test("A missing office doesn't leave a dangling clause")
    func missingOfficeReadsCleanly() {
        let context = ScriptContext(people: [ScriptPerson(fullName: "Sam Hale", pronouns: .he)])
        let text = ScriptRenderer.render(DefaultScripts.body(for: .ordinationProposal), context: context).plainText

        #expect(text.contains("be ordained."))
        #expect(!text.contains("ordained ."))
    }

    @Test("Ward business says there is none when there is none")
    func wardBusinessQuietWeek() {
        let quiet = ScriptRenderer.render(
            DefaultScripts.body(for: .wardBusiness),
            context: ScriptContext(unitName: "Cold Spring Ranch 3rd Ward")
        )

        #expect(quiet.plainText == "There is no ward business.")
        #expect(quiet.isValid)
    }

    @Test("Ward business presents it when the meeting has some")
    func wardBusinessBusyWeek() {
        let busy = ScriptRenderer.render(
            DefaultScripts.body(for: .wardBusiness),
            context: ScriptContext(unitName: "Cold Spring Ranch 3rd Ward", flags: ["hasWardBusiness"])
        )

        #expect(busy.plainText != "There is no ward business.")
        #expect(busy.isValid)
    }

    @Test("Stake business turns the time over by name")
    func stakeBusinessWording() {
        let context = ScriptContext(
            people: [ScriptPerson(fullName: "Paul Weeks", title: "President", pronouns: .he)]
        )
        let text = ScriptRenderer.render(DefaultScripts.body(for: .stakeBusiness), context: context).plainText

        #expect(text == "I will now turn the time over to President Paul Weeks for some stake business.")
    }

    @Test("A stake officer is addressed by title rather than Brother")
    func presidingOfficerTitle() {
        let context = ScriptContext(
            people: [ScriptPerson(fullName: "Paul Weeks", title: "President", pronouns: .he)]
        )
        let text = ScriptRenderer.render(DefaultScripts.body(for: .recognition), context: context).plainText

        #expect(text.contains("President Paul Weeks"))
        #expect(!text.contains("Brother Paul Weeks"))
        #expect(text.contains("He is presiding"))
    }

    @Test("Records of membership use different wording for one person versus several")
    func movingInRecordBranches() {
        func text(_ subjects: [ScriptSubject]) -> String {
            ScriptRenderer.render(
                DefaultScripts.body(for: .movingInRecord),
                context: ScriptContext(subjects: subjects, unitName: "Cold Spring Ranch 3rd Ward")
            ).plainText
        }
        let one = ScriptSubject(person: ScriptPerson(fullName: "Jane Doe", pronouns: .she))
        let two = ScriptSubject(person: ScriptPerson(fullName: "John Smith", pronouns: .he))

        let singular = text([one])
        #expect(singular.hasPrefix("We have received the membership record of Sister Jane Doe."))
        #expect(singular.contains("We welcome her to the Cold Spring Ranch 3rd Ward."))

        let plural = text([one, two])
        #expect(plural.hasPrefix("We have received the membership records of the following members."))
        // The names are listed rather than left as a stage direction — the app knows them.
        #expect(plural.contains("Sister Jane Doe"))
        #expect(plural.contains("Brother John Smith"))
        #expect(plural.contains("welcoming these people into the ward by the uplifted hand"))
    }

    @Test("Ordination supplies the right indefinite article")
    func ordinationArticle() {
        func proposal(office: String) -> String {
            ScriptRenderer.render(
                DefaultScripts.body(for: .ordinationProposal),
                context: ScriptContext(people: [ScriptPerson(fullName: "Sam Hale", pronouns: .he)], office: office)
            ).plainText
        }

        #expect(proposal(office: "deacon").contains("be ordained a deacon"))
        #expect(proposal(office: "elder").contains("be ordained an elder"))
        #expect(proposal(office: "high priest").contains("be ordained a high priest"))
    }

    @Test("A baby blessing names the officiator and invites the family forward")
    func blessingNamesOfficiatorAndFamily() {
        let context = ScriptContext(
            officiators: [ScriptPerson(fullName: "Mark Nielsen", pronouns: .he)],
            family: "Nielsen"
        )
        let output = ScriptRenderer.render(DefaultScripts.body(for: .babyBlessing), context: context)

        #expect(output.plainText.hasPrefix("The blessing will be given by Brother Mark Nielsen."))
        #expect(output.plainText.contains(
            "We will now invite the Nielsen family and those that have been asked to participate to come forward for the baby blessing."
        ))
    }

    @Test("A blessing with no family recorded still reads cleanly")
    func blessingWithoutFamily() {
        let context = ScriptContext(
            officiators: [ScriptPerson(fullName: "Mark Nielsen", pronouns: .he)]
        )
        let output = ScriptRenderer.render(DefaultScripts.body(for: .babyBlessing), context: context)

        #expect(output.plainText.contains(
            "We will now invite the family and those that have been asked to participate to come forward for the baby blessing."
        ))
    }

    @Test("Records of membership inflect singular and plural")
    func movingInRecordPlurality() {
        func text(_ people: [ScriptPerson]) -> String {
            ScriptRenderer.render(
                DefaultScripts.body(for: .movingInRecord),
                context: ScriptContext(people: people, unitName: "Highland 4th Ward")
            ).plainText
        }

        #expect(text([ScriptPerson(fullName: "John Smith", pronouns: .he)]).contains("the membership record of"))
        #expect(text([
            ScriptPerson(fullName: "John Smith", pronouns: .he),
            ScriptPerson(fullName: "Jane Doe", pronouns: .she),
        ]).contains("the membership records of"))
    }

    @Test("Every script kind has a shipped default and guidance")
    func completeCoverage() {
        for kind in ScriptKind.allCases {
            #expect(!DefaultScripts.body(for: kind).isEmpty)
            #expect(!kind.guidance.isEmpty)
        }
        #expect(DefaultScripts.all.count == ScriptKind.allCases.count)
    }
}
