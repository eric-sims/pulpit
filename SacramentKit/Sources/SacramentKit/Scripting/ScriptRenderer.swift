import Foundation

/// Documentation for one placeholder, so the template editor can offer an insertable palette
/// instead of expecting you to remember the vocabulary.
public struct ScriptTokenDoc: Sendable, Hashable, Identifiable {
    public let token: String
    public let summary: String
    public var id: String { token }
}

/// Expands a script template against a context.
///
/// The three things that actually make this hard, and which the tests hammer on:
/// pronoun inflection, singular-versus-plural agreement, and name-list formatting.
public enum ScriptRenderer {

    public static func render(_ template: String, context: ScriptContext) -> ScriptRendering {
        let (nodes, parseIssues) = ScriptTemplateParser.parse(template)
        var issues = parseIssues
        var characters: [(character: Character, emphasized: Bool)] = []
        emit(nodes, context: context, into: &characters, issues: &issues)
        return ScriptRendering(segments: coalesce(normalize(characters)), issues: issues)
    }

    // MARK: - Emission

    private static func emit(
        _ nodes: [ScriptNode],
        context: ScriptContext,
        into characters: inout [(character: Character, emphasized: Bool)],
        issues: inout [ScriptIssue]
    ) {
        for node in nodes {
            switch node {
            case .text(let text):
                characters.append(contentsOf: text.map { ($0, false) })

            case .token(let name):
                if let (value, emphasized) = resolve(name, context: context) {
                    characters.append(contentsOf: value.map { ($0, emphasized) })
                } else {
                    // Render the placeholder verbatim so the defect is visible on the page.
                    issues.append(.unknownToken(name))
                    characters.append(contentsOf: "{{\(name)}}".map { ($0, false) })
                }

            case .each(let body):
                // Each pass renders against a context narrowed to one subject, so {{names}},
                // {{calling}} and verb agreement inside the block all refer to that person alone.
                for subject in context.subjects {
                    emit(body, context: context.scoped(to: subject), into: &characters, issues: &issues)
                }

            case .conditional(let condition, let then, let otherwise):
                switch evaluate(condition, context: context) {
                case .some(true):
                    emit(then, context: context, into: &characters, issues: &issues)
                case .some(false):
                    emit(otherwise, context: context, into: &characters, issues: &issues)
                case .none:
                    issues.append(.unknownToken("#if \(condition)"))
                    emit(otherwise, context: context, into: &characters, issues: &issues)
                }
            }
        }
    }

    // MARK: - Tokens

    /// Returns the resolved text and whether it should be emphasized, or nil if unrecognized.
    private static func resolve(_ name: String, context: ScriptContext) -> (String, Bool)? {
        // User-authored templates may invent their own placeholders; those win on an exact match.
        if let extra = context.extras[name] {
            return (extra, false)
        }

        let pronouns = context.effectivePronouns
        let plural = context.isPlural

        let resolved: (String, Bool)?
        switch name.lowercased() {
        case "names":
            resolved = (context.formattedNames, true)
        case "plainnames":
            resolved = (context.plainNames, true)
        case "officiators":
            resolved = (context.formattedOfficiators, true)
        case "calling":
            resolved = (context.calling ?? "", false)
        case "office":
            resolved = (context.office ?? "", false)
        case "officewitharticle":
            resolved = (context.officeWithArticle, false)
        case "parents":
            resolved = (context.parents ?? "", true)
        case "unit":
            resolved = (context.unitName, false)
        case "brothersister":
            resolved = (context.honorificPhrase, false)
        // `effectivePronouns` already collapses to they/them for several people, so these need
        // no plurality check of their own.
        case "subject":
            resolved = (pronouns.subject, false)
        case "object":
            resolved = (pronouns.object, false)
        case "possessive":
            resolved = (pronouns.possessive, false)
        case "reflexive":
            resolved = (pronouns.reflexive, false)
        case "has":
            resolved = (plural ? "have" : "has", false)
        case "is":
            resolved = (plural ? "are" : "is", false)
        case "was":
            resolved = (plural ? "were" : "was", false)
        default:
            resolved = nil
        }

        guard let (value, emphasized) = resolved else { return nil }
        // {{Subject}} capitalizes for a sentence start; {{subject}} doesn't.
        if name.first?.isUppercase == true {
            return (capitalizingFirstLetter(value), emphasized)
        }
        return (value, emphasized)
    }

    private static func capitalizingFirstLetter(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }

    /// Returns nil for an unrecognized condition, which is reported rather than guessed at.
    private static func evaluate(_ condition: String, context: ScriptContext) -> Bool? {
        // Flags supplied by the surrounding meeting win, so a template can test something the
        // item itself has no way of knowing.
        if context.flags.contains(condition) { return true }

        switch condition.lowercased() {
        case "plural": return context.isPlural
        case "singular": return !context.isPlural
        case "multiple": return context.people.count > 1
        case "hascalling": return !(context.calling ?? "").isEmpty
        case "hasoffice": return !(context.office ?? "").isEmpty
        case "hasofficiators": return !context.officiators.isEmpty
        case "hasparents": return !(context.parents ?? "").isEmpty
        case "hashonorific": return !context.honorificPhrase.isEmpty
        case "hasunit": return !context.unitName.isEmpty
        // Known flag names that simply aren't set read as false rather than as an error.
        case "haswardbusiness": return false
        default: return nil
        }
    }

    // MARK: - Whitespace

    /// Tidies the spacing that token substitution leaves behind.
    ///
    /// A template like `{{brotherSister}} {{names}}` produces a doubled space whenever the
    /// honorific resolves to nothing — which is exactly what happens for they/them. Rather than
    /// contorting every template with conditionals, the renderer cleans up after itself.
    private static func normalize(
        _ input: [(character: Character, emphasized: Bool)]
    ) -> [(character: Character, emphasized: Bool)] {
        var collapsed: [(character: Character, emphasized: Bool)] = []
        for entry in input {
            if entry.character == " " || entry.character == "\t" {
                if collapsed.last?.character == " " { continue }
                collapsed.append((" ", entry.emphasized))
            } else {
                collapsed.append(entry)
            }
        }

        let punctuation: Set<Character> = [",", ".", ";", ":", "!", "?"]
        var result: [(character: Character, emphasized: Bool)] = []
        for entry in collapsed {
            if entry.character == " ", result.last?.character == "\n" { continue }
            if punctuation.contains(entry.character) || entry.character == "\n",
               result.last?.character == " " {
                result.removeLast()
            }
            result.append(entry)
        }

        // Block constructs naturally leave extra blank lines — an {{#each}} body that starts and
        // ends with a newline stacks them up. More than one blank line is never intentional.
        var spaced: [(character: Character, emphasized: Bool)] = []
        var consecutiveNewlines = 0
        for entry in result {
            if entry.character == "\n" {
                consecutiveNewlines += 1
                if consecutiveNewlines > 2 { continue }
            } else {
                consecutiveNewlines = 0
            }
            spaced.append(entry)
        }

        var trimmed = spaced
        while let first = trimmed.first, first.character == " " || first.character == "\n" {
            trimmed.removeFirst()
        }
        while let last = trimmed.last, last.character == " " || last.character == "\n" {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func coalesce(
        _ input: [(character: Character, emphasized: Bool)]
    ) -> [ScriptSegment] {
        var segments: [ScriptSegment] = []
        for entry in input {
            if var last = segments.last, last.isEmphasized == entry.emphasized {
                last.text.append(entry.character)
                segments[segments.count - 1] = last
            } else {
                segments.append(ScriptSegment(text: String(entry.character), isEmphasized: entry.emphasized))
            }
        }
        return segments
    }

    // MARK: - Editor support

    public static let availableTokens: [ScriptTokenDoc] = [
        .init(token: "{{names}}", summary: "Names with Brother/Sister, joined for reading aloud"),
        .init(token: "{{plainNames}}", summary: "Names without an honorific"),
        .init(token: "{{officiators}}", summary: "Whoever performs the ordinance"),
        .init(token: "{{calling}}", summary: "The calling being filled or vacated"),
        .init(token: "{{office}}", summary: "Priesthood office, for ordinations"),
        .init(token: "{{officeWithArticle}}", summary: "“a deacon”, “an elder” — article included"),
        .init(token: "{{unit}}", summary: "Ward or branch name"),
        .init(token: "{{brotherSister}}", summary: "Brother, Sister, brothers and sisters"),
        .init(token: "{{subject}}", summary: "he / she / they"),
        .init(token: "{{object}}", summary: "him / her / them"),
        .init(token: "{{possessive}}", summary: "his / her / their"),
        .init(token: "{{reflexive}}", summary: "himself / herself / themselves"),
        .init(token: "{{has}}", summary: "has / have, agreeing with the subject"),
        .init(token: "{{is}}", summary: "is / are, agreeing with the subject"),
        .init(token: "{{was}}", summary: "was / were, agreeing with the subject"),
        .init(token: "{{#if plural}}…{{else}}…{{/if}}", summary: "Different wording for one person versus several"),
        .init(token: "{{#each}}…{{/each}}", summary: "Repeat a line per person, each with their own calling"),
    ]
}
