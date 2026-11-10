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

    // MARK: - The end of the line before, for a heading's section

    func testTheEndOfTheLineBefore() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.index(ofLine: 1, in: text), 0)
        XCTAssertEqual(IFSourceLines.index(ofLine: 2, in: text), 3)
        XCTAssertEqual(IFSourceLines.index(ofLine: 3, in: text), 7)
        XCTAssertEqual(IFSourceLines.index(ofLine: 4, in: text), 13)
        XCTAssertEqual(IFSourceLines.index(ofLine: 5, in: text), notFound)
        XCTAssertEqual(IFSourceLines.index(ofLine: 0, in: text), notFound)
    }

    func testTheEndOfTheLineBeforeEndingInAReturnAndANewline() {
        // The last character of the ending
        let text = "One\r\nTwo\n\rThree"
        XCTAssertEqual(IFSourceLines.index(ofLine: 2, in: text), 4)
        XCTAssertEqual(IFSourceLines.index(ofLine: 3, in: text), 9)
    }

    // MARK: - The line a character is on, for the heading it's under

    func testACharacterOnTheFirstLine() {
        let text = "One\nTwo\nThree\n"
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 2, in: text), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: "One"), 0)
        XCTAssertEqual(IFSourceLines.line(forCharacter: 0, in: ""), 0)
    }
}
