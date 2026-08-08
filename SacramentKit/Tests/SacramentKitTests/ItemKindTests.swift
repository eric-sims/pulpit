import Testing
@testable import SacramentKit

@Suite("What each kind of item tracks")
struct ItemKindTests {

    @Test("Ordinances carry no assignment status to chase")
    func ordinancesDoNotTrackStatus() {
        #expect(!ItemKind.babyBlessing.tracksAssignmentStatus)
        #expect(!ItemKind.confirmation.tracksAssignmentStatus)
    }

    @Test("Everything you invite someone to does track a status")
    func invitedRolesTrackStatus() {
        for kind: ItemKind in [.speaker, .invocation, .benediction, .musicalNumber, .sustaining] {
            #expect(kind.tracksAssignmentStatus)
        }
    }
}
