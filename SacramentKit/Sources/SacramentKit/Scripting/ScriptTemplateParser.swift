import Foundation

/// The parsed shape of a template.
indirect enum ScriptNode: Sendable, Hashable {
    case text(String)
    case token(String)
    case conditional(condition: String, then: [ScriptNode], otherwise: [ScriptNode])
    /// Repeats its body once per subject, with tokens inside scoped to that one person.
    case each([ScriptNode])
}

/// Turns template source into nodes.
///
/// Hand-written rather than pulled from a dependency: the grammar is four constructs wide, and the
/// wording it produces gets read aloud in front of a congregation. Worth owning outright.
///
/// Grammar:
/// ```
/// {{tokenName}}
/// {{#if condition}} … {{else}} … {{/if}}
/// {{#each}} … {{/each}}
/// ```
enum ScriptTemplateParser {
    private enum Lexeme: Sendable, Hashable {
        case literal(String)
        case directive(String)
    }

    static func parse(_ template: String) -> (nodes: [ScriptNode], issues: [ScriptIssue]) {
        var issues: [ScriptIssue] = []
        let lexemes = lex(template, issues: &issues)
        var remaining = lexemes[...]
        let (nodes, terminator) = parseNodes(&remaining, issues: &issues)

        // A stray block terminator at top level ended the parse early.
        switch terminator {
        case "else": issues.append(.unexpectedElse)
        case "/if": issues.append(.unexpectedEndIf)
        case "/each": issues.append(.unexpectedEndEach)
        default: break
        }
        return (nodes, issues)
    }

    // MARK: - Lexing

    private static func lex(_ template: String, issues: inout [ScriptIssue]) -> [Lexeme] {
        var lexemes: [Lexeme] = []
        var literal = ""
        var index = template.startIndex

        while index < template.endIndex {
            guard let open = template.range(of: "{{", range: index..<template.endIndex) else {
                literal += template[index...]
                break
            }
            literal += template[index..<open.lowerBound]

            guard let close = template.range(of: "}}", range: open.upperBound..<template.endIndex) else {
                // Unterminated: keep the raw text so the defect is visible in the rendered script.
                issues.append(.unterminatedDirective)
                literal += template[open.lowerBound...]
                index = template.endIndex
                break
            }

            if !literal.isEmpty {
                lexemes.append(.literal(literal))
                literal = ""
            }
            let body = template[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            lexemes.append(.directive(body))
            index = close.upperBound
        }

        if !literal.isEmpty {
            lexemes.append(.literal(literal))
        }
        return lexemes
    }

    // MARK: - Parsing

    /// Consumes lexemes until a terminating directive (`else`, `/if`) or the end of input.
    /// Returns the nodes parsed and which terminator stopped it, if any.
    private static func parseNodes(
        _ lexemes: inout ArraySlice<Lexeme>,
        issues: inout [ScriptIssue]
    ) -> (nodes: [ScriptNode], terminator: String?) {
        var nodes: [ScriptNode] = []

        while let lexeme = lexemes.first {
            lexemes = lexemes.dropFirst()

            switch lexeme {
            case .literal(let text):
                nodes.append(.text(text))

            case .directive(let body):
                if body == "else" || body == "/if" || body == "/each" {
                    return (nodes, body)
                }
                if body == "#each" {
                    let (bodyNodes, terminator) = parseNodes(&lexemes, issues: &issues)
                    if terminator != "/each" {
                        issues.append(.unclosedEach)
                    }
                    nodes.append(.each(bodyNodes))
                } else if body.hasPrefix("#if") {
                    let condition = String(body.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    let (thenNodes, thenTerminator) = parseNodes(&lexemes, issues: &issues)
                    var elseNodes: [ScriptNode] = []

                    switch thenTerminator {
                    case "else":
                        let (parsed, elseTerminator) = parseNodes(&lexemes, issues: &issues)
                        elseNodes = parsed
                        if elseTerminator != "/if" {
                            issues.append(.unclosedConditional(condition))
                        }
                    case "/if":
                        break
                    default:
                        issues.append(.unclosedConditional(condition))
                    }

                    nodes.append(.conditional(condition: condition, then: thenNodes, otherwise: elseNodes))
                } else {
                    nodes.append(.token(body))
                }
            }
        }
        return (nodes, nil)
    }
}
