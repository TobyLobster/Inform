//
//  IFIntelSymbolTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFIntelSymbolTests: XCTestCase {

    /// A heading's symbol, as the Natural Inform intelligence makes it.
    private func heading(_ name: String, level: Int32) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// The headings of a story in a file, two lines apart. Part 2 has a section with no chapter
    /// above it, followed by a chapter.
    private func story() -> (IFIntelFile, [IFIntelSymbol]) {
        let headings = [heading("Story", level: 0),
                        heading("Part 1", level: 3),
                        heading("Chapter 1", level: 4),
                        heading("Chapter 2", level: 4),
                        heading("Part 2", level: 3),
                        heading("Section 1", level: 5),
                        heading("Chapter 3", level: 4)]
        let file = IFIntelFile()
        for (index, symbol) in headings.enumerated() {
            file.add(symbol, atLine: Int32(index * 2))
        }
        return (file, headings)
    }

    func testANewSymbol() {
        let symbol = IFIntelSymbol()
        XCTAssertNil(symbol.name)
        XCTAssertNil(symbol.type)
        XCTAssertEqual(symbol.relation, .onLevel)
        XCTAssertEqual(symbol.levelDelta, 0)
        XCTAssertEqual(symbol.level, 0)
        XCTAssertNil(symbol.next)
        XCTAssertNil(symbol.last)
        XCTAssertNil(symbol.parent)
        XCTAssertNil(symbol.child)
        XCTAssertNil(symbol.sibling)
        XCTAssertNil(symbol.previousSibling)
    }

    func testTheLevelOfASymbolOnALevelIsItsDelta() {
        let symbol = heading("Chapter 1", level: 4)
        XCTAssertEqual(symbol.level, 4)
    }

    func testSettingTheLevelOverridesTheDelta() {
        let symbol = heading("Chapter 1", level: 4)
        symbol.level = 2
        XCTAssertEqual(symbol.level, 2)

        // A negative level means work it out again
        symbol.level = -1
        XCTAssertEqual(symbol.level, 4)
    }

    func testARelativeLevelWithNoSymbolBefore() {
        let symbol = IFIntelSymbol()
        symbol.relation = .deltaLevel
        symbol.levelDelta = 2
        XCTAssertEqual(symbol.level, 2)

        symbol.levelDelta = -1
        XCTAssertEqual(symbol.level, 0)
    }

    func testARelativeLevelIsCountedFromTheSymbolBefore() {
        let previous = heading("Part 1", level: 1)
        let symbol = IFIntelSymbol()
        symbol.relation = .deltaLevel
        symbol.levelDelta = 2
        withExtendedLifetime(previous) {
            symbol.last = previous
            XCTAssertEqual(symbol.level, 3)

            previous.levelDelta = 3
            symbol.levelDelta = -1
            XCTAssertEqual(symbol.level, 2)
        }
    }

    func testARelativeLevelIsNeverBelowZero() {
        let previous = heading("Part 1", level: 1)
        let symbol = IFIntelSymbol()
        symbol.relation = .deltaLevel
        symbol.levelDelta = -2
        withExtendedLifetime(previous) {
            symbol.last = previous
            XCTAssertEqual(symbol.level, 0)
        }
    }

    func testParents() {
        let (file, headings) = story()
        withExtendedLifetime(file) {
            XCTAssertEqual(headings.map { $0.parent?.name ?? "-" },
                           ["-", "Story", "Part 1", "Part 1", "Story", "Part 2", "Part 2"])
        }
    }

    func testChildren() {
        let (file, headings) = story()
        withExtendedLifetime(file) {
            XCTAssertEqual(headings.map { $0.child?.name ?? "-" },
                           ["Part 1", "Chapter 1", "-", "-", "Section 1", "-", "-"])
        }
    }

    func testSiblings() {
        let (file, headings) = story()
        withExtendedLifetime(file) {
            // A section's sibling can be a chapter that follows it with the same parent,
            // though the chapter's previous sibling isn't the section
            XCTAssertEqual(headings.map { $0.sibling?.name ?? "-" },
                           ["-", "Part 2", "Chapter 2", "-", "-", "Chapter 3", "-"])
            XCTAssertEqual(headings.map { $0.previousSibling?.name ?? "-" },
                           ["-", "-", "-", "Chapter 1", "Part 1", "-", "-"])
        }
    }

    func testDescription() {
        XCTAssertEqual(heading("Chapter 1", level: 4).description, "IFIntelSymbol 'Chapter 1' - delta 4")
        XCTAssertEqual(IFIntelSymbol().description, "IFIntelSymbol '(null)' - delta 0")
    }

    func testArchivingKeepsTheSymbolsDataButNotItsNeighbours() throws {
        let (file, headings) = story()
        let chapter = headings[3]
        chapter.relation = .deltaLevel
        chapter.levelDelta = 1
        chapter.level = 6

        let data = try withExtendedLifetime(file) {
            try NSKeyedArchiver.archivedData(withRootObject: chapter, requiringSecureCoding: true)
        }
        let copy = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: IFIntelSymbol.self, from: data))
        XCTAssertEqual(copy.name, "Chapter 2")
        XCTAssertEqual(copy.type, IFSectionSymbolType)
        XCTAssertEqual(copy.relation, .deltaLevel)
        XCTAssertEqual(copy.levelDelta, 1)
        XCTAssertEqual(copy.level, 6)
        XCTAssertNil(copy.next)
        XCTAssertNil(copy.last)

        // A level that is worked out is archived as such
        let story = heading("Story", level: 0)
        let storyCopy = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
            ofClass: IFIntelSymbol.self,
            from: NSKeyedArchiver.archivedData(withRootObject: story, requiringSecureCoding: true)))
        storyCopy.levelDelta = 2
        XCTAssertEqual(storyCopy.level, 2)
    }
}
