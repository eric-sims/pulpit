import Foundation

/// How a person is addressed and referred to in a script.
///
/// This exists for one reason: getting "All who can support **her**" wrong at a pulpit is the kind
/// of mistake the whole app is meant to prevent.
///
/// A person is Brother or Sister — those are the only two forms of address the meeting uses, and
/// `selectableCases` is what the roster offers. `they` is retained but never offered: it's how the
/// engine refers to **several people at once** ("All who can sustain them"), which is a plural,
/// not a third choice about any individual.
public enum PronounSet: String, Codable, CaseIterable, Sendable, Hashable {
    case he
    case she
    case they

    /// What the roster lets you pick. The collective form is not a personal option.
    public static let selectableCases: [PronounSet] = [.he, .she]

    /// How this person is addressed: "Brother" or "Sister".
    public var formLabel: String {
        switch self {
        case .he: "Brother"
        case .she: "Sister"
        case .they: "Group"
        }
    }

    public var displayName: String {
        switch self {
        case .he: "he/him"
        case .she: "she/her"
        case .they: "they/them"
        }
    }

    /// he / she / they
    public var subject: String {
        switch self {
        case .he: "he"
        case .she: "she"
        case .they: "they"
        }
    }

    /// him / her / them
    public var object: String {
        switch self {
        case .he: "him"
        case .she: "her"
        case .they: "them"
        }
    }

    /// his / her / their
    public var possessive: String {
        switch self {
        case .he: "his"
        case .she: "her"
        case .they: "their"
        }
    }

    /// himself / herself / themselves
    public var reflexive: String {
        switch self {
        case .he: "himself"
        case .she: "herself"
        case .they: "themselves"
        }
    }

    /// Brother / Sister, or nil when no gendered honorific applies.
    public var honorific: String? {
        switch self {
        case .he: "Brother"
        case .she: "Sister"
        case .they: nil
        }
    }

    /// Plural form of the honorific, used when several people are sustained together.
    public var pluralHonorific: String? {
        switch self {
        case .he: "brothers"
        case .she: "sisters"
        case .they: nil
        }
    }

    /// Whether this pronoun takes plural verb agreement — "they *have* been called" versus
    /// "he *has* been called". Singular `they` still agrees as plural.
    public var takesPluralAgreement: Bool {
        self == .they
    }

    /// Falls back to `.he` rather than the collective form, so an unset value still produces a
    /// normal singular sentence. Every person in the roster is asked to pick.
    public init(tolerant raw: String?) {
        self = raw.flatMap(PronounSet.init(rawValue:)) ?? .he
    }
}
