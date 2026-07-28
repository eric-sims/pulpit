> Your edits, folded back into the templates. Two changes went deeper than wording — see the
> note at the end. Everything here is still editable in the app.

# Scripts

Rendered against sample data, incorporating your edits. All editable in the app.

## Welcome

_Read at the start of the meeting, after the prelude._

Good morning, brothers and sisters. Welcome to the Cold Spring Ranch 3rd Ward sacrament meeting.

---

## Recognition of Presiding Authority

_Used when a stake officer or visiting authority is presiding._

We are pleased to have with us today President Paul Weeks.

He is presiding at this meeting.

---

## Sustaining

_Presenting a new calling for a sustaining vote._

The following members have been called to the positions indicated. Please stand as your names are read and remain standing until the vote has been taken:

Sister Jane Doe has been called as Relief Society President.

Brother John Smith has been called as Sunday School Teacher.

All in favor may manifest it by the uplifted hand.

[Pause for the vote.]

Any opposed may also manifest it.

[Pause.]

Thank you.

---

## Release

_Announcing a release. A release asks for a vote of thanks, not a sustaining vote._

The following individuals have been released from the positions indicated and we propose they be given a vote of thanks for their service:

Sister Jane Doe has been released as Relief Society President.

Brother John Smith has been released as Sunday School Teacher.

Those who wish to express their appreciation may manifest it by the uplifted hand.

[Pause for the vote.]

Thank you.

---

## Proposal for Ordination

_The vote must be taken before the ordination is performed._

It is proposed that Brother Samuel Hale be ordained an elder.

All who can sustain him may manifest it by the uplifted hand.

[Pause for the vote.]

Any opposed may manifest it by the same sign.

[Pause.]

Thank you.

[The vote is taken before the ordination is performed.]

---

## New Members

_Welcoming members recently baptized and confirmed in the ward._

We are pleased to welcome Sister Jane Doe, who was recently baptized and confirmed.

We welcome her into the Cold Spring Ranch 3rd Ward.

---

## Records of Membership Received

_Acknowledging members whose records have been received. No vote is taken._

We have received the membership record of Sister Jane Doe.

We welcome her to the Cold Spring Ranch 3rd Ward.

**Same script, several members:**

We have received the membership records of the following members. Please stand as your names are read so we can welcome you.

Sister Jane Doe

Brother John Smith

Please join me in welcoming these people into the ward by the uplifted hand.

[Pause.]

Thank you.

---

## Blessing of a Child

_Announcing a blessing of a child before it is performed._

Emma Nielsen, child of Brother and Sister Nielsen, will now receive a name and a blessing.

The blessing will be given by Brother Mark Nielsen.

[Invite the family to come forward.]

---

## Confirmation

_Announcing a confirmation before it is performed._

Jane Doe, who was recently baptized, will now be confirmed a member of The Church of Jesus Christ of Latter-day Saints.

Those who have been invited to participate may come forward.

---

## Sacrament Transition

_Handing the meeting to the priesthood for the administration of the sacrament._

We will now be led in the sacrament hymn, after which the sacrament will be administered to the congregation.

[Nothing else takes place during the administration and passing of the sacrament — no announcements, no music, no other business.]

---

## Invitation to Bear Testimony

_Inviting the congregation to bear testimony in a fast and testimony meeting._

We now have the opportunity to bear our testimonies.

We invite you to come forward to share your brief testimony of the Savior.

---

## Notes on your edits

**Two of your changes needed model support, not just new text.**

1. *"President Paul Weeks"* — a person now carries an optional **title** ("President", "Bishop",
   "Elder") that outranks the Brother/Sister their pronouns imply. The collective
   `{{brotherSister}}` phrase stays pronoun-based, so a stake president in a group is still
   counted among the brothers.

2. *"The following members have been called to the positions indicated…"* — your rewrite reads a
   preamble, then several people **each with their own calling**, then takes one vote. The old
   model had one calling per item shared by everyone, which couldn't express that. A sustaining or
   release item now holds a list of person-and-calling pairs, and templates gained an
   `{{#each}}…{{/each}}` block that repeats a line per person with their own calling and verb
   agreement.

**Three typos corrected:** "porpose" → "propose", "serivce" → "service", "breif" → "brief".

**One thing I changed on purpose, tell me if you'd rather I didn't.** In the plural
records-of-membership script you wrote `[Read names]` as a stage direction. Since the app already
knows who they are, it now lists the names instead. I also completed the sentence
"…so we can welcome" to "…so we can welcome you" — it read as unfinished. Both are easy to revert.

**One thing I left exactly as you wrote it:** the Confirmation script no longer names who is
officiating. If you'd like it back, the `{{officiators}}` placeholder still works.
