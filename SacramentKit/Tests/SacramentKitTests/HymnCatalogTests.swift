import Testing
@testable import SacramentKit

// These assertions are the guard on the bundled data. If a future batch is added carelessly —
// a duplicate number, a gap, a mistyped book — these fail before it reaches a pulpit.

@Suite("Bundled hymn catalog integrity")
struct HymnCatalogTests {
    let catalog = HymnCatalog.shared

    @Test("The 1985 hymnbook is complete and contiguous from 1 to 341")
    func hymns1985IsComplete() {
        let numbers = catalog.hymns(in: .hymns1985).map(\.number).sorted()

        #expect(numbers.count == 341)
        #expect(numbers == Array(1...341))
    }

    @Test("The sacrament section is hymns 169 through 196")
    func sacramentSection() {
        let sacrament = catalog.hymns(in: .hymns1985)
            .filter { $0.sacramentSuitability == .yes }
            .map(\.number)
            .sorted()

        #expect(sacrament == Array(169...196))
        #expect(catalog.hymn(book: .hymns1985, number: 169)?.title == "As Now We Take the Sacrament")
    }

    @Test("Every other 1985 section is marked unsuitable for the sacrament slot")
    func nonSacramentSectionsAreMarked() {
        for hymn in catalog.hymns(in: .hymns1985) where !(169...196).contains(hymn.number) {
            #expect(hymn.sacramentSuitability == .no, "hymn \(hymn.number) is misclassified")
        }
    }

    @Test("Home and Church hymns are present with unknown sacrament suitability")
    func homeAndChurchIsUnclassified() {
        let hymns = catalog.hymns(in: .homeAndChurch)

        #expect(hymns.count == 72)
        // The new hymnbook publishes no topical sections yet, so nothing may claim to know.
        #expect(hymns.allSatisfy { $0.sacramentSuitability == .unknown })
        #expect(hymns.allSatisfy { $0.number >= 1001 })
    }

    @Test("Home and Church numbering falls in the two published ranges")
    func homeAndChurchRanges() {
        for hymn in catalog.hymns(in: .homeAndChurch) {
            let general = (1001...1062).contains(hymn.number)
            let seasonal = (1201...1210).contains(hymn.number)
            #expect(general || seasonal, "unexpected number \(hymn.number)")
            #expect(seasonal == hymn.sections.contains("seasonal"))
        }
    }

    @Test("No book contains a duplicate hymn number")
    func noDuplicates() {
        for book in HymnBook.allCases {
            let numbers = catalog.hymns(in: book).map(\.number)
            #expect(numbers.count == Set(numbers).count, "\(book) has duplicate numbers")
        }
    }

    @Test("No hymn has an empty title")
    func titlesArePresent() {
        #expect(catalog.hymns.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    @Test("The catalog records when its data was verified")
    func provenance() {
        #expect(catalog.catalogVersion >= 1)
        #expect(!catalog.verifiedOn.isEmpty)
    }
}

@Suite("Hymn search")
struct HymnSearchTests {
    let catalog = HymnCatalog.shared

    @Test("A number match comes first")
    func numberSearch() {
        #expect(catalog.search("169").first?.title == "As Now We Take the Sacrament")
    }

    @Test("A partial number offers hymns starting with those digits")
    func partialNumberSearch() {
        let results = catalog.search("16", in: .hymns1985)

        #expect(results.first?.number == 16)
        #expect(results.contains { $0.number == 169 })
    }

    @Test("Titles beginning with the query rank above titles merely containing it")
    func titlePrefixRanking() {
        let results = catalog.search("come", in: .hymns1985)

        #expect(results.first?.title.lowercased().hasPrefix("come") == true)
        #expect(results.count > 1)
    }

    @Test("Search can be limited to one book")
    func bookScoping() {
        #expect(catalog.search("", in: .homeAndChurch).allSatisfy { $0.book == .homeAndChurch })
    }

    @Test("An empty query returns everything")
    func emptyQuery() {
        #expect(catalog.search("   ").count == catalog.hymns.count)
    }
}

@Suite("Hymn placement warnings")
struct HymnValidatorTests {
    let catalog = HymnCatalog.shared

    private func hymn(_ number: Int, _ book: HymnBook = .hymns1985) -> Hymn {
        catalog.hymn(book: book, number: number)!
    }

    @Test("A non-sacrament hymn in the sacrament slot is flagged")
    func nonSacramentHymnFlagged() {
        // 201 "Joy to the World" is a Christmas hymn.
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .sacramentHymn, hymn: hymn(201))
        ])

        #expect(warnings == [.notASacramentHymn(hymn(201))])
    }

    @Test("A sacrament hymn in the sacrament slot is not flagged")
    func sacramentHymnAccepted() {
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .sacramentHymn, hymn: hymn(169))
        ])

        #expect(warnings.isEmpty)
    }

    @Test("A hymn of unknown suitability is never flagged")
    func unknownSuitabilityIsSilent() {
        // "As Bread Is Broken" is plainly a sacrament hymn, but the new hymnbook publishes no
        // sections yet. Warning here would be wrong, and would teach you to ignore warnings.
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .sacramentHymn, hymn: hymn(1007, .homeAndChurch))
        ])

        #expect(warnings.isEmpty)
    }

    @Test("A Christmas hymn as the opening hymn is not flagged")
    func onlyTheSacramentSlotIsChecked() {
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .openingHymn, hymn: hymn(201))
        ])

        #expect(warnings.isEmpty)
    }

    @Test("A hymn used twice is flagged exactly once")
    func duplicateFlaggedOnce() {
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .openingHymn, hymn: hymn(2)),
            HymnPlacement(itemKind: .sacramentHymn, hymn: hymn(169)),
            HymnPlacement(itemKind: .closingHymn, hymn: hymn(2)),
        ])

        #expect(warnings == [.duplicate(hymn(2))])
    }

    @Test("The same number in different books is not a duplicate")
    func differentBooksAreDistinct() {
        let warnings = HymnValidator.warnings(for: [
            HymnPlacement(itemKind: .openingHymn, hymn: hymn(2)),
            HymnPlacement(itemKind: .closingHymn, hymn: hymn(1002, .homeAndChurch)),
        ])

        #expect(warnings.isEmpty)
    }
}
