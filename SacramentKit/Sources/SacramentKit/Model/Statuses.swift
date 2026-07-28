import Foundation

/// What happened to a program item during the meeting.
///
/// Deliberately three-valued rather than a boolean: *skipped* is genuinely different from
/// *deleted*. When a speaker doesn't show or the meeting runs long, the record of what actually
/// happened is worth keeping.
public enum ItemStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case pending
    case completed
    case skipped

    public var displayName: String {
        switch self {
        case .pending: "Not yet"
        case .completed: "Done"
        case .skipped: "Skipped"
        }
    }

    /// Whether conducting mode considers this item finished and moves past it.
    public var isResolved: Bool {
        self != .pending
    }

    public init(tolerant raw: String?) {
        self = raw.flatMap(ItemStatus.init(rawValue:)) ?? .pending
    }
}

/// Where an assignment stands in the asking-and-confirming process, so Saturday-night triage
/// shows what's still outstanding.
public enum AssignmentStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case unassigned
    case invited
    case confirmed
    case declined

    public var displayName: String {
        switch self {
        case .unassigned: "Not asked"
        case .invited: "Invited"
        case .confirmed: "Confirmed"
        case .declined: "Declined"
        }
    }

    /// Whether this assignment still needs your attention before Sunday.
    public var needsFollowUp: Bool {
        switch self {
        case .unassigned, .invited, .declined: true
        case .confirmed: false
        }
    }

    public init(tolerant raw: String?) {
        self = raw.flatMap(AssignmentStatus.init(rawValue:)) ?? .unassigned
    }
}

/// What a person is doing in a given item.
public enum AssignmentRole: String, Codable, CaseIterable, Sendable, Hashable {
    case speaker
    case invocation
    case benediction
    case musician
    /// Whoever performs or voices an ordinance — the father blessing a child, the elder confirming.
    case officiator
    /// The person the item is *about*: the one being sustained, released, blessed, or confirmed.
    case subject

    public var displayName: String {
        switch self {
        case .speaker: "Speaker"
        case .invocation: "Invocation"
        case .benediction: "Benediction"
        case .musician: "Musician"
        case .officiator: "Officiating"
        case .subject: "Name"
        }
    }

    public init(tolerant raw: String?) {
        self = raw.flatMap(AssignmentRole.init(rawValue:)) ?? .subject
    }
}
