import Testing
@testable import SacramentKit

// The pronoun and plurality behavior here is the whole reason the engine exists. If any of these
// break, someone gets misgendered from a pulpit.

private func person(_ name: String, _ pronouns: PronounSet) -> ScriptPerson {
    ScriptPerson(fullName: name, pronouns: pronouns)
}

@Suite("Pronoun and plurality inflection")
struct InflectionTests {
    let template = "{{names}} {{has}} been called as {{calling}}. All who can support {{object}} may do so by the uplifted hand."

    @Test("A brother reads with masculine pronouns and singular agreement")
    func masculineSingular() {
        let context = ScriptContext(people: [person("John Smith", .he)], calling: "Elders Quorum President")
        let output = ScriptRenderer.render(template, context: context)

        #expect(output.plainText == "Brother John Smith has been called as Elders Quorum President. All who can support him may do so by the uplifted hand.")
        #expect(output.isValid)
    }

    @Test("A sister reads with feminine pronouns")
    func feminineSingular() {
        let context = ScriptContext(people: [person("Jane Doe", .she)], calling: "Relief Society President")
        let output = ScriptRenderer.render(template, context: context)

        #expect(output.plainText.contains("Sister Jane Doe has been called"))
        #expect(output.plainText.contains("support her may do so"))
    }

    @Test("Several people are referred to collectively, not individually")
    func collectiveForm() {
        // `they` is never a personal option — it's how the engine refers to a group.
        let context = ScriptContext(
            people: [person("John Smith", .he), person("Jane Doe", .she), person("Sam Hale", .he)],
            calling: "Primary Teachers"
        )
        let output = ScriptRenderer.render(template, context: context)

        #expect(output.plainText.contains("have been called"))
        #expect(output.plainText.contains("support them may do so"))
        #expect(context.effectivePronouns == .they)
    }

    @Test("Two people join with 'and' and take plural agreement")
    func twoPeople() {
        let context = ScriptContext(
            people: [person("John Smith", .he), person("Jane Doe", .she)],
            calling: "Primary Teachers"
        )
        let output = ScriptRenderer.render(template, context: context)

        #expect(output.plainText.hasPrefix("Brother John Smith and Sister Jane Doe have been called"))
        #expect(output.plainText.contains("support them"))
    }

    @Test("Three or more people take an Oxford comma")
    func threePeople() {
        let context = ScriptContext(people: [
            person("A One", .he), person("B Two", .he), person("C Three", .he),
        ])
        let output = ScriptRenderer.render("{{names}}", context: context)

        #expect(output.plainText == "Brother A One, Brother B Two, and Brother C Three")
    }

    @Test("The honorific phrase agrees with the group's makeup")
    func honorificPhrase() {
        #expect(ScriptContext(people: [person("A", .he)]).honorificPhrase == "Brother")
        #expect(ScriptContext(people: [person("A", .she)]).honorificPhrase == "Sister")
        #expect(ScriptContext(people: [person("A", .he), person("B", .he)]).honorificPhrase == "brothers")
        #expect(ScriptContext(people: [person("A", .she), person("B", .she)]).honorificPhrase == "sisters")
        #expect(ScriptContext(people: [person("A", .he), person("B", .she)]).honorificPhrase == "brothers and sisters")
    }

    @Test("A person is Brother or Sister, and nothing else is offered")
    func onlyTwoFormsOfAddress() {
        #expect(PronounSet.selectableCases == [.he, .she])
        #expect(PronounSet.he.formLabel == "Brother")
        #expect(PronounSet.she.formLabel == "Sister")
        // An unset or unrecognized value produces a normal singular sentence rather than the
        // collective form.
        #expect(PronounSet(tolerant: nil) == .he)
        #expect(PronounSet(tolerant: "nonsense") == .he)
        #expect(ScriptPerson(fullName: "Pat Quinn").pronouns == .he)
    }
}

@Suite("Template syntax")
struct TemplateSyntaxTests {
    @Test("Conditionals pick the branch matching plurality")
    func conditionalBranches() {
        let template = "{{#if plural}}these members{{else}}this member{{/if}}"

        #expect(ScriptRenderer.render(template, context: ScriptContext(people: [person("A", .he)])).plainText == "this member")
        #expect(ScriptRenderer.render(template, context: ScriptContext(people: [person("A", .he), person("B", .she)])).plainText == "these members")
    }

    @Test("A conditional with no else branch renders nothing when false")
    func conditionalWithoutElse() {
        let output = ScriptRenderer.render(
            "Released{{#if hasCalling}} as {{calling}}{{/if}}.",
            context: ScriptContext(people: [person("A", .he)])
        )
        #expect(output.plainText == "Released.")
        #expect(output.isValid)
    }

    @Test("Capitalized tokens capitalize their value")
    func capitalization() {
        let context = ScriptContext(people: [person("Jane Doe", .she)])
        #expect(ScriptRenderer.render("{{Subject}} served faithfully.", context: context).plainText == "She served faithfully.")
        #expect(ScriptRenderer.render("{{subject}} served faithfully.", context: context).plainText == "she served faithfully.")
    }

    @Test("An empty honorific doesn't leave a doubled space")
    func whitespaceCleanup() {
        let context = ScriptContext(people: [person("Alex Reed", .they)])
        let output = ScriptRenderer.render("We thank {{brotherSister}} {{plainNames}} for {{possessive}} service.", context: context)

        #expect(output.plainText == "We thank Alex Reed for their service.")
    }

    @Test("Space before punctuation is removed when a token resolves empty")
    func punctuationSpacing() {
        let context = ScriptContext(people: [person("Alex Reed", .they)])
        let output = ScriptRenderer.render("Thank you {{brotherSister}} .", context: context)

        #expect(output.plainText == "Thank you.")
    }

    @Test("An each block repeats once per subject, scoped to that person")
    func eachBlock() {
        let context = ScriptContext(subjects: [
            ScriptSubject(person: person("Jane Doe", .she), calling: "Relief Society President"),
            ScriptSubject(person: person("John Smith", .he), calling: "Ward Clerk"),
            ScriptSubject(person: person("Alex Reed", .they), calling: "Organist"),
        ])
        let output = ScriptRenderer.render("{{#each}}{{names}} {{has}} been called as {{calling}}.\n{{/each}}", context: context)

        #expect(output.plainText == """
        Sister Jane Doe has been called as Relief Society President.
        Brother John Smith has been called as Ward Clerk.
        Alex Reed have been called as Organist.
        """)
        #expect(output.isValid)
    }

    @Test("An each block over no subjects renders nothing")
    func emptyEachBlock() {
        let output = ScriptRenderer.render("Before {{#each}}{{names}}{{/each}}after", context: ScriptContext())

        #expect(output.plainText == "Before after")
    }

    @Test("An each block nests inside a conditional")
    func nestedEachInConditional() {
        let template = "{{#if multiple}}Several:{{#each}} {{names}}{{/each}}{{else}}Just {{names}}{{/if}}"

        let one = ScriptContext(people: [person("Jane Doe", .she)])
        #expect(ScriptRenderer.render(template, context: one).plainText == "Just Sister Jane Doe")

        let two = ScriptContext(people: [person("Jane Doe", .she), person("John Smith", .he)])
        #expect(ScriptRenderer.render(template, context: two).plainText == "Several: Sister Jane Doe Brother John Smith")
    }

    @Test("An unclosed each block is reported")
    func unclosedEach() {
        let output = ScriptRenderer.render("{{#each}}{{names}}", context: ScriptContext())
        #expect(output.issues.contains(.unclosedEach))
    }

    @Test("A stray each terminator is reported")
    func strayEndEach() {
        let output = ScriptRenderer.render("text {{/each}}", context: ScriptContext())
        #expect(output.issues.contains(.unexpectedEndEach))
    }

    @Test("Blank lines left by block constructs are collapsed to at most one")
    func blankLineCollapsing() {
        let context = ScriptContext(subjects: [
            ScriptSubject(person: person("Jane Doe", .she), calling: "Organist"),
            ScriptSubject(person: person("John Smith", .he), calling: "Ward Clerk"),
        ])
        let output = ScriptRenderer.render("""
        Preamble:

        {{#each}}
        {{names}} as {{calling}}.
        {{/each}}
        Closing.
        """, context: context)

        #expect(!output.plainText.contains("\n\n\n"))
        #expect(output.plainText == """
        Preamble:

        Sister Jane Doe as Organist.

        Brother John Smith as Ward Clerk.

        Closing.
        """)
    }

    @Test("An explicit title outranks the pronoun-derived honorific")
    func titleOverridesHonorific() {
        let context = ScriptContext(people: [
            ScriptPerson(fullName: "Paul Weeks", title: "President", pronouns: .he),
            ScriptPerson(fullName: "Jane Doe", pronouns: .she),
        ])

        #expect(ScriptRenderer.render("{{names}}", context: context).plainText
            == "President Paul Weeks and Sister Jane Doe")
        // The collective honorific stays pronoun-based: a stake president is still a brother.
        #expect(context.honorificPhrase == "brothers and sisters")
    }

    @Test("Extras satisfy placeholders a user invented")
    func userDefinedTokens() {
        let context = ScriptContext(extras: ["temple": "Provo City Center"])
        #expect(ScriptRenderer.render("The {{temple}} Temple", context: context).plainText == "The Provo City Center Temple")
    }
}

@Suite("Malformed templates fail visibly, never silently")
struct TemplateFailureTests {
    @Test("An unknown placeholder renders as itself and is reported")
    func unknownToken() {
        let output = ScriptRenderer.render("Called as {{nonsense}} today", context: ScriptContext())

        #expect(output.plainText == "Called as {{nonsense}} today")
        #expect(output.issues == [.unknownToken("nonsense")])
    }

    @Test("An unclosed conditional is reported")
    func unclosedConditional() {
        let output = ScriptRenderer.render("{{#if plural}}many", context: ScriptContext())
        #expect(output.issues.contains(.unclosedConditional("plural")))
    }

    @Test("A stray closing tag is reported")
    func strayEndIf() {
        let output = ScriptRenderer.render("text {{/if}}", context: ScriptContext())
        #expect(output.issues.contains(.unexpectedEndIf))
    }

    @Test("An unterminated placeholder keeps its raw text")
    func unterminatedDirective() {
        let output = ScriptRenderer.render("Called as {{calling", context: ScriptContext())

        #expect(output.issues.contains(.unterminatedDirective))
        #expect(output.plainText.contains("{{calling"))
    }

    @Test("An unknown condition is reported and takes the else branch")
    func unknownCondition() {
        let output = ScriptRenderer.render("{{#if wat}}yes{{else}}no{{/if}}", context: ScriptContext())

        #expect(output.plainText == "no")
        #expect(output.issues.contains(.unknownToken("#if wat")))
    }
}

@Suite("Emphasis")
struct EmphasisTests {
    @Test("Names are emphasized and surrounding wording is not")
    func namesAreEmphasized() {
        let context = ScriptContext(people: [person("John Smith", .he)])
        let output = ScriptRenderer.render("We thank {{names}} for serving.", context: context)

        let emphasized = output.segments.filter(\.isEmphasized).map(\.text).joined()
        #expect(emphasized == "Brother John Smith")
        #expect(output.plainText == "We thank Brother John Smith for serving.")
    }

    @Test("A script with no names produces a single unemphasized segment")
    func noEmphasis() {
        let output = ScriptRenderer.render("We will now partake of the sacrament.", context: ScriptContext())

        #expect(output.segments.count == 1)
        #expect(output.segments[0].isEmphasized == false)
    }
}
