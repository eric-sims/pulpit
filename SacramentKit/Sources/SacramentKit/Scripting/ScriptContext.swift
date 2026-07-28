import Foundation

/// A person as the script engine sees them. Deliberately a value type with no persistence
/// dependency, so script rendering is testable without a store.
public struct ScriptPerson: Sendable, Hashable {
    public var fullName: String
    public var preferredName: String?
    /// An explicit form of address that outranks the pronoun-derived Brother/Sister — "President"
    /// for a stake officer, "Bishop", "Elder" for a visiting authority or missionary.
    public var title: String?
    /// How to say a name you'd otherwise mangle from the pulpit. Never rendered into a script —
    /// it's shown alongside as a reading aid.
    public var phoneticSpelling: String?
    public var pronouns: PronounSet

    public init(
        fullName: String,
        preferredName: String? = nil,
        title: String? = nil,
        phoneticSpelling: String? = nil,
        pronouns: PronounSet = .he
    ) {
        self.fullName = fullName
        self.preferredName = preferredName
        self.title = title
        self.phoneticSpelling = phoneticSpelling
        self.pronouns = pronouns
    }

    /// How to address this person: an explicit title if one is recorded, otherwise the honorific
    /// their pronouns imply, otherwise nothing.
    public var formOfAddress: String? {
        if let title, !title.isEmpty { return title }
        return pronouns.honorific
    }

    /// "President Paul Weeks", "Sister Jane Doe", or a bare name.
    public var addressedName: String {
        guard let formOfAddress else { return fullName }
        return "\(formOfAddress) \(fullName)"
    }
}

/// One person the script is about, together with what it's about *for them*.
///
/// A single sustaining commonly covers several people in several different callings — the
/// preamble is read once, each name and calling is read in turn, and one vote is taken at the end.
/// Pairing the calling with the person rather than with the item is what makes that work.
public struct ScriptSubject: Sendable, Hashable {
    public var person: ScriptPerson
    public var calling: String?
    public var office: String?

    public init(person: ScriptPerson, calling: String? = nil, office: String? = nil) {
        self.person = person
        self.calling = calling
        self.office = office
    }
}

/// Everything a script template can refer to.
public struct ScriptContext: Sendable {
    /// The people the script is about, each with their own calling or office.
    public var subjects: [ScriptSubject]
    /// Whoever performs an ordinance: the father blessing a child, the elder confirming a member.
    /// Kept separate from `subjects` because an ordinance script names both.
    public var officiators: [ScriptPerson]
    /// A calling for the item as a whole, used outside an `{{#each}}` block. Falls back to the
    /// first subject's calling when unset.
    public var explicitCalling: String?
    /// A priesthood office for the item as a whole.
    public var explicitOffice: String?
    /// Parents named when a child is blessed, already formatted for reading aloud.
    public var parents: String?
    /// The ward or branch name.
    public var unitName: String
    /// Ad-hoc token values, for user-authored templates that invent their own placeholders.
    public var extras: [String: String]
    /// Named conditions the surrounding meeting supplies, testable with `{{#if flagName}}`.
    /// Used for things a single item can't know on its own — whether the meeting has any ward
    /// business at all, for instance.
    public var flags: Set<String>

    public init(
        subjects: [ScriptSubject] = [],
        officiators: [ScriptPerson] = [],
        calling: String? = nil,
        office: String? = nil,
        parents: String? = nil,
        unitName: String = "",
        extras: [String: String] = [:],
        flags: Set<String> = []
    ) {
        self.subjects = subjects
        self.officiators = officiators
        self.explicitCalling = calling
        self.explicitOffice = office
        self.parents = parents
        self.unitName = unitName
        self.extras = extras
        self.flags = flags
    }

    /// Convenience for the common case where everyone shares one calling, or none applies.
    public init(
        people: [ScriptPerson],
        officiators: [ScriptPerson] = [],
        calling: String? = nil,
        office: String? = nil,
        parents: String? = nil,
        unitName: String = "",
        extras: [String: String] = [:],
        flags: Set<String> = []
    ) {
        self.init(
            subjects: people.map { ScriptSubject(person: $0, calling: calling, office: office) },
            officiators: officiators,
            calling: calling,
            office: office,
            parents: parents,
            unitName: unitName,
            extras: extras,
            flags: flags
        )
    }

    public var people: [ScriptPerson] { subjects.map(\.person) }

    public var calling: String? {
        explicitCalling ?? subjects.first?.calling
    }

    public var office: String? {
        explicitOffice ?? subjects.first?.office
    }

    /// A context narrowed to a single subject, used inside an `{{#each}}` block so that
    /// `{{names}}`, `{{calling}}` and verb agreement all refer to that one person.
    public func scoped(to subject: ScriptSubject) -> ScriptContext {
        ScriptContext(
            subjects: [subject],
            officiators: officiators,
            calling: subject.calling ?? explicitCalling,
            office: subject.office ?? explicitOffice,
            parents: parents,
            unitName: unitName,
            extras: extras,
            flags: flags
        )
    }

    /// Whether the script should read as plural.
    ///
    /// True for several people, and *also* true for one person using they/them — singular `they`
    /// still takes plural verb agreement ("they have been called", not "they has been called").
    public var isPlural: Bool {
        if subjects.count > 1 { return true }
        if let only = subjects.first { return only.person.pronouns.takesPluralAgreement }
        return false
    }

    /// The pronoun set to use when the script refers back to the subject. With several people
    /// this is always they/them regardless of the individuals' pronouns.
    public var effectivePronouns: PronounSet {
        subjects.count == 1 ? subjects[0].person.pronouns : .they
    }

    /// "Brother" / "Sister" for one person; "brothers", "sisters", or "brothers and sisters" for
    /// several. Empty when no gendered honorific applies.
    ///
    /// Pronoun-derived rather than title-derived: this token is about brothers and sisters
    /// collectively, so a stake president in the group is still a brother.
    public var honorificPhrase: String {
        guard !subjects.isEmpty else { return "" }
        if subjects.count == 1 {
            return subjects[0].person.pronouns.honorific ?? ""
        }
        let sets = Set(subjects.map(\.person.pronouns))
        if sets == [.he] { return "brothers" }
        if sets == [.she] { return "sisters" }
        return "brothers and sisters"
    }

    /// Names with their form of address, joined for reading aloud:
    /// "Sister Jane Doe", "President Paul Weeks and Sister Jane Doe", "A, B, and C".
    public var formattedNames: String {
        ScriptContext.joinForSpeech(subjects.map(\.person.addressedName))
    }

    /// Names without any form of address.
    public var plainNames: String {
        ScriptContext.joinForSpeech(subjects.map(\.person.fullName))
    }

    /// Officiators' names with their form of address, joined for reading aloud.
    public var formattedOfficiators: String {
        ScriptContext.joinForSpeech(officiators.map(\.addressedName))
    }

    /// The priesthood office with its indefinite article — "a deacon", "an elder".
    ///
    /// Worth computing rather than making you type the article: "elder" and "high priest" want
    /// different articles, and getting it wrong is audible.
    public var officeWithArticle: String {
        guard let office, !office.isEmpty else { return "" }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        let article = vowels.contains(Character(office.prefix(1).lowercased())) ? "an" : "a"
        return "\(article) \(office)"
    }

    /// Joins a list the way it would be spoken, with an Oxford comma at three or more.
    static func joinForSpeech(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }
}
