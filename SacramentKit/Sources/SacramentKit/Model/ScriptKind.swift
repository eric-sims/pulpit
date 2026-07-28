import Foundation

/// The pieces of a meeting that have customary spoken wording.
///
/// Each maps to an editable `ScriptTemplate`. The shipped defaults are drafted from customary
/// practice, not quoted from the Handbook, and every one is flagged for review before first use.
public enum ScriptKind: String, Codable, CaseIterable, Sendable, Hashable {
    case welcome
    case recognition
    case wardBusiness
    case stakeBusiness
    case sustaining
    case release
    case ordinationProposal
    case newMemberWelcome
    case movingInRecord
    case babyBlessing
    case confirmation
    case sacramentTransition
    case testimonyInvitation

    public var displayName: String {
        switch self {
        case .welcome: "Welcome"
        case .recognition: "Recognition of Presiding Authority"
        case .wardBusiness: "Ward Business"
        case .stakeBusiness: "Stake Business"
        case .sustaining: "Sustaining"
        case .release: "Release"
        case .ordinationProposal: "Proposal for Ordination"
        case .newMemberWelcome: "New Members"
        case .movingInRecord: "Records of Membership Received"
        case .babyBlessing: "Blessing of a Child"
        case .confirmation: "Confirmation"
        case .sacramentTransition: "Sacrament Transition"
        case .testimonyInvitation: "Invitation to Bear Testimony"
        }
    }

    /// A one-line note shown above the editor explaining when this wording is used.
    public var guidance: String {
        switch self {
        case .welcome:
            "Read at the start of the meeting, after the prelude."
        case .recognition:
            "Used when a stake officer or visiting authority is presiding."
        case .wardBusiness:
            "Read every week. Says there is none on the weeks there isn't any."
        case .stakeBusiness:
            "Turning the time over to someone representing the stake."
        case .sustaining:
            "Presenting a new calling for a sustaining vote."
        case .release:
            "Announcing a release. A release asks for a vote of thanks, not a sustaining vote."
        case .ordinationProposal:
            "The vote must be taken before the ordination is performed."
        case .newMemberWelcome:
            "Welcoming members recently baptized and confirmed in the ward."
        case .movingInRecord:
            "Acknowledging members whose records have been received. No vote is taken."
        case .babyBlessing:
            "Announcing a blessing of a child before it is performed."
        case .confirmation:
            "Announcing a confirmation before it is performed."
        case .sacramentTransition:
            "Handing the meeting to the priesthood for the administration of the sacrament."
        case .testimonyInvitation:
            "Inviting the congregation to bear testimony in a fast and testimony meeting."
        }
    }

    public init?(tolerant raw: String?) {
        guard let raw, let value = ScriptKind(rawValue: raw) else { return nil }
        self = value
    }
}
