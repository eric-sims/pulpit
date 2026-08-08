import Testing
@testable import PulpitKit

@Suite("Meeting templates follow the Handbook order")
struct MeetingTemplateTests {

    private func kinds(_ meeting: MeetingKind) -> [ItemKind] {
        MeetingTemplates.seed(for: meeting).map(\.kind)
    }

    @Test("Every meeting reads the ward business lead-in, business or not",
          arguments: MeetingKind.allCases)
    func wardBusinessIsAlwaysSeeded(meeting: MeetingKind) {
        let items = kinds(meeting)

        #expect(items.filter { $0 == .wardBusiness }.count == 1)
        // The lead-in is not itself business — that's what decides which branch it reads.
        #expect(ItemKind.wardBusiness.isBusiness == false)
        // And no template seeds actual business; those are occasional.
        #expect(!items.contains { $0.isBusiness && $0 != .sustaining })
    }

    @Test("Prelude and postlude are gone")
    func noPreludeOrPostlude() {
        let titles = ItemKind.allCases.map(\.defaultTitle)

        #expect(!titles.contains { $0.localizedCaseInsensitiveContains("prelude") })
        #expect(!titles.contains { $0.localizedCaseInsensitiveContains("postlude") })
        // An old saved item still loads, keeping whatever title it had.
        #expect(ItemKind(tolerant: "prelude") == .custom)
    }

    @Test("Every meeting has exactly one sacrament, and it cannot be deleted",
          arguments: MeetingKind.allCases)
    func sacramentIsPresentAndPermanent(meeting: MeetingKind) {
        let items = kinds(meeting)

        #expect(items.filter { $0 == .sacrament }.count == 1)
        #expect(ItemKind.sacrament.isDeletable == false)
    }

    @Test("The sacrament hymn immediately precedes the sacrament",
          arguments: MeetingKind.allCases)
    func sacramentHymnPrecedesSacrament(meeting: MeetingKind) {
        let items = kinds(meeting)
        guard let sacramentIndex = items.firstIndex(of: .sacrament) else {
            Issue.record("\(meeting) has no sacrament")
            return
        }
        #expect(sacramentIndex > 0)
        #expect(items[sacramentIndex - 1] == .sacramentHymn)
    }

    @Test("Every meeting opens and closes with a hymn and a prayer",
          arguments: MeetingKind.allCases)
    func openingAndClosing(meeting: MeetingKind) {
        let items = kinds(meeting)

        #expect(items.first == .welcome)
        #expect(items.last == .benediction)
        for required: ItemKind in [.openingHymn, .invocation, .closingHymn, .benediction] {
            #expect(items.contains(required), "\(meeting) is missing \(required)")
        }
        // The invocation comes before the sacrament; the benediction after everything.
        let invocation = items.firstIndex(of: .invocation)!
        let sacrament = items.firstIndex(of: .sacrament)!
        let benediction = items.firstIndex(of: .benediction)!
        let closingHymn = items.firstIndex(of: .closingHymn)!
        #expect(invocation < sacrament)
        #expect(closingHymn < benediction)
    }

    @Test("Templates are seeded in canonical order", arguments: MeetingKind.allCases)
    func seededInCanonicalOrder(meeting: MeetingKind) {
        // The intermediate hymn is the one deliberate exception: it belongs between speakers,
        // which a single rank can't express.
        let ranks = kinds(meeting)
            .filter { $0 != .intermediateHymn }
            .map(\.canonicalRank)

        #expect(ranks == ranks.sorted(), "\(meeting) seeds items out of canonical order")
    }

    @Test("A regular meeting seeds two speakers and an intermediate hymn")
    func regularMeeting() {
        let items = kinds(.regular)

        #expect(items.filter { $0 == .speaker }.count == 2)
        #expect(items.contains(.intermediateHymn))
    }

    @Test("A fast and testimony meeting has no assigned speakers")
    func fastAndTestimony() {
        let items = kinds(.fastAndTestimony)

        #expect(!items.contains(.speaker))
        #expect(items.contains(.testimonyInvitation))
        #expect(MeetingKind.fastAndTestimony.hasAssignedSpeakers == false)
    }

    @Test("Ward conference recognizes the presiding stake officer and sustains ward officers")
    func wardConference() {
        let seed = MeetingTemplates.seed(for: .wardConference)

        #expect(seed.map(\.kind).contains(.recognitions))
        let sustaining = seed.first { $0.kind == .sustaining }
        #expect(sustaining?.title == "Sustaining of Ward Officers")
    }

    @Test("A special program leaves a freeform block between the sacrament and the closing hymn")
    func specialProgram() {
        let items = kinds(.specialProgram)
        let presentation = items.firstIndex(of: .presentation)!

        #expect(presentation > items.firstIndex(of: .sacrament)!)
        #expect(presentation < items.firstIndex(of: .closingHymn)!)
        #expect(!items.contains(.speaker))
    }

    @Test("Slots that need filling are the ones the wizard should ask about")
    func placeholders() {
        let unfilled = MeetingTemplates.seed(for: .regular).filter(\.needsFilling).map(\.kind)

        #expect(unfilled.contains(.openingHymn))
        #expect(unfilled.contains(.invocation))
        #expect(unfilled.contains(.speaker))
        // The welcome, ward business and the sacrament need nothing typed into them.
        #expect(!unfilled.contains(.welcome))
        #expect(!unfilled.contains(.wardBusiness))
        #expect(!unfilled.contains(.sacrament))
    }
}

@Suite("Inserting items at their canonical position")
struct InsertionTests {
    private let regular = MeetingTemplates.seed(for: .regular).map(\.kind)

    @Test("Ward business lands after the invocation and before the sacrament hymn")
    func businessPlacement() {
        for kind: ItemKind in [.release, .sustaining, .ordinationProposal, .movingInRecord] {
            let index = MeetingTemplates.insertionIndex(for: kind, in: regular)

            #expect(index > regular.firstIndex(of: .invocation)!)
            #expect(index <= regular.firstIndex(of: .sacramentHymn)!)
        }
    }

    @Test("A baby blessing lands after ward business and before the sacrament hymn")
    func blessingPlacement() {
        let index = MeetingTemplates.insertionIndex(for: .babyBlessing, in: regular)

        #expect(index > regular.firstIndex(of: .invocation)!)
        #expect(index <= regular.firstIndex(of: .sacramentHymn)!)
    }

    @Test("Releases are proposed before new sustainings")
    func releasesBeforeSustainings() {
        var items = regular
        let releaseIndex = MeetingTemplates.insertionIndex(for: .release, in: items)
        items.insert(.release, at: releaseIndex)
        let sustainingIndex = MeetingTemplates.insertionIndex(for: .sustaining, in: items)

        #expect(sustainingIndex > releaseIndex)
    }

    @Test("Several items of the same kind stack in the order they were added")
    func repeatedKindsStack() {
        var items = regular
        let first = MeetingTemplates.insertionIndex(for: .sustaining, in: items)
        items.insert(.sustaining, at: first)
        let second = MeetingTemplates.insertionIndex(for: .sustaining, in: items)

        #expect(second == first + 1)
    }

    @Test("An unrecognized item lands in the body of the meeting rather than at the very end")
    func customPlacement() {
        let index = MeetingTemplates.insertionIndex(for: .custom, in: regular)

        #expect(index > regular.firstIndex(of: .sacrament)!)
        #expect(index < regular.count)
    }
}
