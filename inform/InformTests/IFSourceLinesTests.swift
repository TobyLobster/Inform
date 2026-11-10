//
//  IFSourceLinesTests.swift
//  InformTests
//

import XCTest

/// Finding lines in source text, as the source page does to go to a line, show it, highlight it, or show a heading's
/// section
final class IFSourceLinesTests: XCTestCase {

    private let notFound = UInt(NSNotFound)

    // MARK: - Where a line starts

    func testWhereALineStarts() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.start(ofLine: 1, in: text), 0)
        XCTAssertEqual(IFSourceLines.start(ofLine: 2, in: text), 4)
        XCTAssertEqual(IFSourceLines.start(ofLine: 3, in: text), 8)
        // The empty line after the last newline
        XCTAssertEqual(IFSourceLines.start(ofLine: 4, in: text), 14)
    }

    func testALineThatIsntThere() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.start(ofLine: 5, in: text), notFound)
        XCTAssertEqual(IFSourceLines.start(ofLine: 0, in: text), notFound)
        XCTAssertEqual(IFSourceLines.start(ofLine: -1, in: text), notFound)
        XCTAssertEqual(IFSourceLines.start(ofLine: 2, in: ""), notFound)
        XCTAssertEqual(IFSourceLines.start(ofLine: 1, in: ""), 0)
    }

    func testLinesEndingInReturns() {
        // A return and a newline, either way round, end one line; two newlines or two returns end two
        let text = "One\r\nTwo\rThree\n\rFour\n\nSix\r\rEight"
        XCTAssertEqual(IFSourceLines.start(ofLine: 2, in: text), 5)
        XCTAssertEqual(IFSourceLines.start(ofLine: 3, in: text), 9)
        XCTAssertEqual(IFSourceLines.start(ofLine: 4, in: text), 16)
        XCTAssertEqual(IFSourceLines.start(ofLine: 5, in: text), 21)
        XCTAssertEqual(IFSourceLines.start(ofLine: 6, in: text), 22)
        XCTAssertEqual(IFSourceLines.start(ofLine: 7, in: text), 26)
        XCTAssertEqual(IFSourceLines.start(ofLine: 8, in: text), 27)
        XCTAssertEqual(IFSourceLines.start(ofLine: 9, in: text), notFound)
    }

    // MARK: - The text on a line, for its find indicator

    func testTheTextOnALine() {
        let text = "One\nTwo\nThree"
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 1, in: text), NSRange(location: 0, length: 3))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 2, in: text), NSRange(location: 4, length: 3))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 3, in: text), NSRange(location: 8, length: 5))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 4, in: text).location, NSNotFound)
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 0, in: text).location, NSNotFound)
    }

    func testTheTextOnALineEndingInAReturn() {
        let text = "One\r\nTwo\r\n\r\nFour"
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 1, in: text), NSRange(location: 0, length: 3))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 2, in: text), NSRange(location: 5, length: 3))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 3, in: text), NSRange(location: 10, length: 0))
        XCTAssertEqual(IFSourceLines.rangeOfText(onLine: 4, in: text), NSRange(location: 12, length: 4))
    }

    // MARK: - A line with its ending, for highlighting it and renaming a heading

    func testALineWithItsEnding() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.range(ofLine: 1, in: text), NSRange(location: 0, length: 4))
        XCTAssertEqual(IFSourceLines.range(ofLine: 2, in: text), NSRange(location: 4, length: 4))
        XCTAssertEqual(IFSourceLines.range(ofLine: 3, in: text), NSRange(location: 8, length: 6))
        XCTAssertEqual(IFSourceLines.range(ofLine: 5, in: text).location, NSNotFound)
        XCTAssertEqual(IFSourceLines.range(ofLine: 0, in: text).location, NSNotFound)
    }

    func testALineWithAReturnAndANewline() {
        // Only the first character of the ending
        let text = "One\r\nTwo\n"
        XCTAssertEqual(IFSourceLines.range(ofLine: 1, in: text), NSRange(location: 0, length: 4))
        XCTAssertEqual(IFSourceLines.range(ofLine: 2, in: text), NSRange(location: 5, length: 4))
    }

    func testALastLineWithNoEnding() {
        // The range stays inside the text
        XCTAssertEqual(IFSourceLines.range(ofLine: 3, in: "One\nTwo\nThree"), NSRange(location: 8, length: 5))
        XCTAssertEqual(IFSourceLines.range(ofLine: 4, in: "One\nTwo\nThree\n"), NSRange(location: 14, length: 0))
        XCTAssertEqual(IFSourceLines.range(ofLine: 1, in: ""), NSRange(location: 0, length: 0))
    }

    // MARK: - The line a character is on, for the heading it's under

    func testACharacterOnTheFirstLine() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 2, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: "One"), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: ""), 0)
    }

    func testTheLineACharacterIsOn() {
        // Counting from 0, as the headings do, with what ends a line on that line
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.line(forCharacter: 3, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 4, in: text), 1)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 7, in: text), 1)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 8, in: text), 2)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 13, in: text), 2)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 14, in: text), 3)
    }

    func testTheLineACharacterIsOnWithReturns() {
        // The lines start at 0, 5, 9 and 11
        let text = "One\r\nTwo\n\n\rFour"
        XCTAssertEqual(IFSourceLines.line(forCharacter: 3, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 4, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 5, in: text), 1)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 8, in: text), 1)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 9, in: text), 2)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 10, in: text), 2)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 11, in: text), 3)
    }

    func testTheHeadingACharacterIsUnder() {
        // As the source page finds the section to show for Show Current Section Only
        let text = "\"Story\" by Me\n\nChapter 1\n\nThe Hall is a room.\n\nChapter 2\n\nThe Yard is a room.\n"
        let file = IFIntelFile()
        file.add(heading("\"Story\" by Me", level: 0), atLine: 0)
        file.add(heading("Chapter 1"), atLine: 2)
        file.add(heading("Chapter 2"), atLine: 6)

        func headingUnder(_ string: String, after offset: Int = 0) -> String? {
            let index = (text as NSString).range(of: string).location + offset
            return file.nearestSymbol(toLine: IFSourceLines.line(forCharacter: UInt(index), in: text))?.name
        }

        XCTAssertEqual(headingUnder("The Hall"), "Chapter 1")
        // At the end of the section's last line, and on the blank line after it
        XCTAssertEqual(headingUnder("room.\n\nChapter 2", after: 5), "Chapter 1")
        XCTAssertEqual(headingUnder("room.\n\nChapter 2", after: 6), "Chapter 1")
        XCTAssertEqual(headingUnder("Chapter 2"), "Chapter 2")
        XCTAssertEqual(headingUnder("The Yard"), "Chapter 2")
    }

    private func heading(_ name: String, level: Int32 = 2) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }
}
