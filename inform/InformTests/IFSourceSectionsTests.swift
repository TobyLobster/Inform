//
//  IFSourceSectionsTests.swift
//  InformTests
//

import XCTest

/// The sections of source text under its headings, as the source page shows one at a time.
final class IFSourceSectionsTests: XCTestCase {

    private let notFound = NSRange(location: NSNotFound, length: 0)

    /// A story with a section inside its first chapter, with the headings on lines 0, 2, 6 and 10, counting from 0.
    private let source = """
        "Story" by Me

        Chapter 1 - Hall

        The Hall is a room.

        Section 1 - Cupboard

        The Cupboard is a container.

        Chapter 2 - Yard

        The Yard is a room.

        """

    private var intel: IFIntelFile!

    override func setUpWithError() throws {
        intel = try headings(of: source)
    }

    /// The headings of a story, gathered as the source page's are, from a text storage unregistered at the end.
    private func headings(of text: String) throws -> IFIntelFile {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFSourceSectionsTests", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: nil)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }
        return try XCTUnwrap(IFSyntaxManager.intelligenceData(for: storage))
    }

    /// The heading whose name starts with some text, in the story's headings unless given others.
    private func heading(_ name: String, in headings: IFIntelFile? = nil,
                         file: StaticString = #filePath, line: UInt = #line) throws -> IFIntelSymbol {
        var symbol = (headings ?? intel).firstSymbol
        while let heading = symbol {
            if heading.name?.hasPrefix(name) == true { return heading }
            symbol = heading.next
        }
        return try XCTUnwrap(nil, "No heading \(name)", file: file, line: line)
    }

    /// The text of a heading's section, in the story unless given another and its headings.
    private func textOfSection(_ name: String, in text: String? = nil, headings: IFIntelFile? = nil,
                               file: StaticString = #filePath, line: UInt = #line) throws -> String? {
        let text = text ?? source
        let headings = headings ?? intel
        let symbol = try heading(name, in: headings, file: file, line: line)
        let range = IFSourceSections.range(ofSection: symbol, inFile: headings, in: text)
        if range.location == NSNotFound { return nil }
        return (text as NSString).substring(with: range)
    }

    // MARK: - The sections next to one, for the tears at the top and bottom

    func testTheSectionAfterAHeading() throws {
        XCTAssertIdentical(IFSourceSections.section(after: try heading("Chapter 1")), try heading("Chapter 2"))
        // From the last section in a chapter, the next chapter
        XCTAssertIdentical(IFSourceSections.section(after: try heading("Section 1")), try heading("Chapter 2"))
        XCTAssertNil(IFSourceSections.section(after: try heading("Chapter 2")))
        XCTAssertNil(IFSourceSections.section(after: try heading("\"Story\"")))
        XCTAssertNil(IFSourceSections.section(after: nil))
    }

    func testTheSectionBeforeAHeading() throws {
        XCTAssertIdentical(IFSourceSections.section(before: try heading("Chapter 2"), inFile: intel),
                           try heading("Chapter 1"))
        // From the first section in a chapter, the chapter
        XCTAssertIdentical(IFSourceSections.section(before: try heading("Section 1"), inFile: intel),
                           try heading("Chapter 1"))
        // Not the title, which is the whole story
        XCTAssertNil(IFSourceSections.section(before: try heading("Chapter 1"), inFile: intel))
        XCTAssertNil(IFSourceSections.section(before: nil, inFile: intel))
    }

    // MARK: - The sections above and below one, for showing more or fewer headings

    func testTheSectionAboveAHeading() throws {
        XCTAssertIdentical(IFSourceSections.section(above: try heading("Section 1"), inFile: intel),
                           try heading("Chapter 1"))
        // Not the title, which is the whole story
        XCTAssertNil(IFSourceSections.section(above: try heading("Chapter 1"), inFile: intel))
        XCTAssertNil(IFSourceSections.section(above: try heading("Chapter 2"), inFile: intel))
        XCTAssertNil(IFSourceSections.section(above: try heading("\"Story\""), inFile: intel))
    }

    func testTheSectionBelowOneTowardsAnother() throws {
        let title = try heading("\"Story\"")
        let chapter1 = try heading("Chapter 1")
        let section1 = try heading("Section 1")
        XCTAssertIdentical(IFSourceSections.section(below: title, towards: section1), chapter1)
        XCTAssertIdentical(IFSourceSections.section(below: chapter1, towards: section1), section1)
        XCTAssertIdentical(IFSourceSections.section(below: title, towards: try heading("Chapter 2")),
                           try heading("Chapter 2"))
        XCTAssertNil(IFSourceSections.section(below: chapter1, towards: chapter1))
        XCTAssertNil(IFSourceSections.section(below: title, towards: nil))
        // Not when the other isn't under it
        XCTAssertNil(IFSourceSections.section(below: try heading("Chapter 2"), towards: section1))
    }

    // MARK: - The section a character is in

    func testTheSectionACharacterIsIn() throws {
        func sectionAt(_ find: String, after offset: Int = 0) -> String? {
            let index = (source as NSString).range(of: find).location + offset
            return IFSourceSections.section(atCharacter: UInt(index), inFile: intel, in: source)?.name
        }

        XCTAssertEqual(sectionAt("Story"), "\"Story\"")
        XCTAssertEqual(sectionAt("Chapter 1"), "Chapter 1 - Hall\n")
        XCTAssertEqual(sectionAt("The Hall"), "Chapter 1 - Hall\n")
        // On the blank line before the next heading
        XCTAssertEqual(sectionAt("room.\n\nSection 1", after: 6), "Chapter 1 - Hall\n")
        XCTAssertEqual(sectionAt("The Cupboard"), "Section 1 - Cupboard\n")
        XCTAssertEqual(sectionAt("The Yard"), "Chapter 2 - Yard\n")
        XCTAssertEqual(IFSourceSections.section(atCharacter: UInt(source.utf16.count), inFile: intel,
                                                in: source)?.name, "Chapter 2 - Yard\n")
    }

    // MARK: - The range of a section

    func testTheRangeOfASection() throws {
        // From its heading to the end of the text before the next section's
        XCTAssertEqual(try textOfSection("Chapter 1"),
                       "Chapter 1 - Hall\n\nThe Hall is a room.\n\n" +
                       "Section 1 - Cupboard\n\nThe Cupboard is a container.")
        XCTAssertEqual(try textOfSection("Section 1"), "Section 1 - Cupboard\n\nThe Cupboard is a container.")
    }

    func testTheRangeOfTheLastSection() throws {
        // To the end of the text
        XCTAssertEqual(try textOfSection("Chapter 2"), "Chapter 2 - Yard\n\nThe Yard is a room.\n")
    }

    func testTheRangeOfASectionWhoseHeadingFollowsText() throws {
        // A heading with no blank line before it is a heading, and the text before it is in the section before
        let text = "\"Story\" by Me\n\nChapter 1 - Hall\n\nThe Hall is a room.\n" +
                   "Chapter 2 - Yard\n\nThe Yard is a room.\n"
        let headings = try headings(of: text)
        XCTAssertEqual(try textOfSection("Chapter 1", in: text, headings: headings),
                       "Chapter 1 - Hall\n\nThe Hall is a room.")
        XCTAssertEqual(try textOfSection("Chapter 2", in: text, headings: headings),
                       "Chapter 2 - Yard\n\nThe Yard is a room.\n")
    }

    func testTheRangeOfASectionBeforeBlankLines() throws {
        // None of the blank lines before the next heading are in the section
        let text = "\"Story\" by Me\n\nChapter 1 - Hall\n\nThe Hall is a room.\n\n\n\nChapter 2 - Yard\n"
        XCTAssertEqual(try textOfSection("Chapter 1", in: text, headings: try headings(of: text)),
                       "Chapter 1 - Hall\n\nThe Hall is a room.")
    }

    func testTheRangeOfASectionAfterIndentedBlankLines() throws {
        // White space before the heading isn't in the section
        let text = "\"Story\" by Me\n\t\n  Chapter 1 - Hall\n\nThe Hall is a room.\n \nChapter 2 - Yard\n"
        let file = IFIntelFile()
        file.add(made("\"Story\"", level: 0), atLine: 0)
        let chapter1 = made("Chapter 1 - Hall\n")
        file.add(chapter1, atLine: 2)
        file.add(made("Chapter 2 - Yard\n"), atLine: 6)

        let range = IFSourceSections.range(ofSection: chapter1, inFile: file, in: text)
        XCTAssertEqual((text as NSString).substring(with: range), "Chapter 1 - Hall\n\nThe Hall is a room.")
    }

    func testTheRangeOfASectionWithReturns() throws {
        // A return and a newline end one line
        let text = "\"Story\" by Me\r\n\r\nChapter 1 - Hall\r\n\r\nThe Hall is a room.\r\n\r\nChapter 2 - Yard\r\n"
        let file = IFIntelFile()
        file.add(made("\"Story\"", level: 0), atLine: 0)
        let chapter1 = made("Chapter 1 - Hall\n")
        file.add(chapter1, atLine: 2)
        file.add(made("Chapter 2 - Yard\n"), atLine: 6)

        let range = IFSourceSections.range(ofSection: chapter1, inFile: file, in: text)
        XCTAssertEqual((text as NSString).substring(with: range), "Chapter 1 - Hall\r\n\r\nThe Hall is a room.")
    }

    func testTheRangeOfAHeadingThatIsntInTheFile() throws {
        XCTAssertEqual(IFSourceSections.range(ofSection: made("Chapter 3 - Attic\n"), inFile: intel,
                                              in: source), notFound)
    }

    func testTheRangeOfASectionWhoseNextHeadingIsntInTheText() throws {
        // As when the headings are out of step with the text
        let text = "\"Story\" by Me\n\nChapter 1 - Hall\n\nThe Hall is a room.\n"
        let file = IFIntelFile()
        file.add(made("\"Story\"", level: 0), atLine: 0)
        let chapter1 = made("Chapter 1 - Hall\n")
        file.add(chapter1, atLine: 2)
        file.add(made("Chapter 2 - Yard\n"), atLine: 50)

        XCTAssertEqual(IFSourceSections.range(ofSection: chapter1, inFile: file, in: text), notFound)
    }

    func testTheRangeOfALastHeadingThatIsntInTheText() throws {
        // As when the headings are out of step with the text
        let text = "\"Story\" by Me\n\nChapter 1 - Hall\n\nThe Hall is a room.\n"
        let file = IFIntelFile()
        file.add(made("\"Story\"", level: 0), atLine: 0)
        file.add(made("Chapter 1 - Hall\n"), atLine: 2)
        let chapter2 = made("Chapter 2 - Yard\n")
        file.add(chapter2, atLine: 50)

        XCTAssertEqual(IFSourceSections.range(ofSection: chapter2, inFile: file, in: text), notFound)
    }

    // MARK: - The lines of a range, for the header page

    func testTheLinesOfASection() throws {
        // The line after the heading's, counting from 0 as the headings do, and the number of lines after that up to
        // the last in the range, which is enough for the header page to find the heading
        func linesOf(_ name: String) throws -> NSRange {
            let range = IFSourceSections.range(ofSection: try heading(name), inFile: intel, in: source)
            return IFSourceSections.lines(of: range, in: source)
        }

        XCTAssertEqual(try linesOf("Chapter 1"), NSRange(location: 3, length: 6))
        XCTAssertEqual(try linesOf("Section 1"), NSRange(location: 7, length: 2))
        XCTAssertEqual(try linesOf("Chapter 2"), NSRange(location: 11, length: 3))
    }

    func testTheLinesOfARangeWithReturns() throws {
        // A return and a newline end one line
        let text = "One\r\nTwo\r\nThree\r\nFour\r\n"
        let three = (text as NSString).range(of: "Three")
        XCTAssertEqual(IFSourceSections.lines(of: three, in: text), NSRange(location: 3, length: 1))
    }

    /// A heading made by hand.
    private func made(_ name: String, level: Int32 = 4) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }
}
