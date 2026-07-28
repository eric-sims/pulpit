import Foundation

/// A run of rendered script text, flagged for whether it should be emphasized.
///
/// The engine emphasizes resolved *names* and nothing else, so the conducting view can make the
/// one thing you must not misread stand out without the app knowing anything about typography.
public struct ScriptSegment: Sendable, Hashable {
    public var text: String
    public var isEmphasized: Bool

    public init(text: String, isEmphasized: Bool) {
        self.text = text
        self.isEmphasized = isEmphasized
    }
}

/// Something wrong with a template, surfaced rather than swallowed.
///
/// A malformed template must never crash and must never silently drop wording — at a pulpit, a
/// visible defect is far better than an invisible omission. Unknown tokens render as their own
/// literal `{{token}}` text so you can see exactly what went wrong.
public enum ScriptIssue: Sendable, Hashable {
    case unknownToken(String)
    case unclosedConditional(String)
    case unclosedEach
    case unexpectedElse
    case unexpectedEndIf
    case unexpectedEndEach
    case unterminatedDirective

    public var message: String {
        switch self {
        case .unknownToken(let name):
            "Unknown placeholder “\(name)”."
        case .unclosedConditional(let condition):
            "Missing {{/if}} for the condition “\(condition)”."
        case .unclosedEach:
            "Missing {{/each}} for an {{#each}} block."
        case .unexpectedElse:
            "An {{else}} appears outside of an {{#if}} block."
        case .unexpectedEndIf:
            "A {{/if}} appears without a matching {{#if}}."
        case .unexpectedEndEach:
            "A {{/each}} appears without a matching {{#each}}."
        case .unterminatedDirective:
            "A placeholder is missing its closing }}."
        }
    }
}

/// The result of rendering a template against a context.
public struct ScriptRendering: Sendable, Hashable {
    public var segments: [ScriptSegment]
    public var issues: [ScriptIssue]

    public init(segments: [ScriptSegment], issues: [ScriptIssue] = []) {
        self.segments = segments
        self.issues = issues
    }

    public var plainText: String {
        segments.map(\.text).joined()
    }

    public var isValid: Bool {
        issues.isEmpty
    }

    /// Convenience for SwiftUI, with names strongly emphasized.
    public var attributedString: AttributedString {
        var result = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            if segment.isEmphasized {
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(piece)
        }
        return result
    }
}
