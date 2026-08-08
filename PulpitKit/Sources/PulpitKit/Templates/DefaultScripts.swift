import Foundation

/// A shipped starting point for one script.
public struct ScriptTemplateSeed: Sendable, Hashable, Identifiable {
    public let kind: ScriptKind
    public let body: String
    public let seedVersion: Int

    public var id: String { kind.rawValue }
}

/// The wording the app ships with.
///
/// **These are drafts of customary practice, not quotations from the Handbook, and every one of
/// them needs review before it is read aloud.** Wording varies between wards and stakes, and the
/// app treats these as a starting point you edit — not as authority. `ScriptTemplate.isUserModified`
/// records when you've made a template your own, so a future update to these defaults never
/// overwrites your version.
///
/// Text in square brackets is a stage direction. It is shown in the conducting view as an aside
/// and is not meant to be spoken.
public enum DefaultScripts {

    /// Bumped when the shipped wording changes. Templates you haven't edited follow the new
    /// version; templates you have edited stay put and are flagged as out of date instead.
    public static let currentSeedVersion = 4

    public static func body(for kind: ScriptKind) -> String {
        switch kind {

        case .welcome:
            """
            Good morning, brothers and sisters. Welcome to the {{unit}} sacrament meeting.
            """

        case .recognition:
            """
            We are pleased to have with us today {{names}}.

            {{Subject}} {{is}} presiding at this meeting.
            """

        case .wardBusiness:
            """
            {{#if hasWardBusiness}}We have some ward business to present.{{else}}There is no ward business.{{/if}}
            """

        case .stakeBusiness:
            """
            I will now turn the time over to {{names}} for some stake business.
            """

        case .sustaining:
            """
            The following members have been called to the positions indicated. Please stand as your names are read and remain standing until the vote has been taken:

            {{#each}}
            {{names}} {{has}} been called{{#if hasCalling}} as {{calling}}{{/if}}.
            {{/each}}
            All in favor may manifest it by the uplifted hand.

            [Pause for the vote.]

            Any opposed may also manifest it.

            [Pause.]

            Thank you.
            """

        case .release:
            """
            The following individuals have been released from the positions indicated and we propose they be given a vote of thanks for their service:

            {{#each}}
            {{names}} {{has}} been released{{#if hasCalling}} as {{calling}}{{/if}}.
            {{/each}}
            Those who wish to express their appreciation may manifest it by the uplifted hand.

            [Pause for the vote.]

            Thank you.
            """

        case .ordinationProposal:
            """
            It is proposed that {{names}} be ordained{{#if hasOffice}} {{officeWithArticle}}{{/if}}.

            All who can sustain {{object}} may manifest it by the uplifted hand.

            [Pause for the vote.]

            Any opposed may manifest it by the same sign.

            [Pause.]

            Thank you.

            [The vote is taken before the ordination is performed.]
            """

        case .newMemberWelcome:
            """
            We are pleased to welcome {{names}}, who {{was}} recently baptized and confirmed.

            We welcome {{object}} into the {{unit}}.
            """

        case .movingInRecord:
            """
            {{#if multiple}}We have received the membership records of the following members. Please stand as your names are read so we can welcome you.

            {{#each}}
            {{names}}
            {{/each}}
            Please join me in welcoming these people into the ward by the uplifted hand.

            [Pause.]

            Thank you.{{else}}We have received the membership record of {{names}}.

            We welcome {{object}} to the {{unit}}.{{/if}}
            """

        case .babyBlessing:
            """
            The blessing will be given by {{officiators}}.

            We will now invite the {{family}} family and those that have been asked to participate to come forward for the baby blessing.
            """

        case .confirmation:
            """
            {{plainNames}}, who {{was}} recently baptized, will now be confirmed a member of The Church of Jesus Christ of Latter-day Saints.

            Those who have been invited to participate may come forward.
            """

        case .sacramentTransition:
            """
            We will now be led in the sacrament hymn, after which the sacrament will be administered to the congregation.

            [Nothing else takes place during the administration and passing of the sacrament — no announcements, no music, no other business.]
            """

        case .testimonyInvitation:
            """
            We now have the opportunity to bear our testimonies.

            We invite you to come forward to share your brief testimony of the Savior.
            """
        }
    }

    public static var all: [ScriptTemplateSeed] {
        ScriptKind.allCases.map {
            ScriptTemplateSeed(kind: $0, body: body(for: $0), seedVersion: currentSeedVersion)
        }
    }
}
