//
//  IFLineStartsTests.swift
//  InformTests
//

import XCTest

/// Where each line of a text starts, kept in step with edits to the text.
@MainActor
final class IFLineStartsTests: XCTestCase {

    /// The starts of all the lines.
    private func starts(_ lines: IFLineStarts) -> [Int] {
        (0..<lines.count).map { lines.start(ofLine: $0) }
    }

    /// The starts of the lines of a text, found from scratch: one at 0, and one after each newline and each return.
    private func expectedStarts(_ text: String) -> [Int] {
        var result = [0]
        for (index, character) in text.utf16.enumerated() where character == 0x0A || character == 0x0D {
            result.append(index + 1)
        }
        return result
    }

    /// Replaces some of a text, and updates its lines as IFSyntaxData does: the lines the replaced characters were on
    /// are found first, and then replaced. Returns the number of lines put in.
    @discardableResult
    private func edit(_ text: NSMutableString,
                      _ lines: IFLineStarts,
                      replacing range: NSRange,
                      with replacement: String) -> Int {
        text.replaceCharacters(in: range, with: replacement)
        let changeInLength = (replacement as NSString).length - range.length

        let firstLine = lines.line(forIndex: range.location)
        let lastLine = lines.line(forIndex: range.location + range.length)
        return lines.replaceLines(after: firstLine,
                                  through: lastLine,
                                  withLinesIn: replacement,
                                  at: range.location,
                                  changeInLength: changeInLength)
    }

    /// The lines of a text, made as IFSyntaxData makes them: by putting the whole text into an empty one.
    private func lines(of string: String) -> (NSMutableString, IFLineStarts) {
        let text = NSMutableString()
        let lines = IFLineStarts()
        edit(text, lines, replacing: NSRange(location: 0, length: 0), with: string)
        return (text, lines)
    }

    /// Checks that replacing some of a text leaves its lines as they would be found from scratch.
    private func checkEdit(_ string: String,
                           replacing location: Int, _ length: Int,
                           with replacement: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        let (text, lines) = lines(of: string)
        edit(text, lines, replacing: NSRange(location: location, length: length), with: replacement)
        XCTAssertEqual(starts(lines), expectedStarts(text as String), (text as String).debugDescription,
                       file: file, line: line)
    }

    // MARK: - The lines of a text

    func testAnEmptyTextHasOneLine() {
        let lines = IFLineStarts()
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.start(ofLine: 0), 0)
    }

    func testEachNewlineEndsALine() {
        XCTAssertEqual(starts(lines(of: "ab\ncd\n\nef").1), [0, 3, 6, 7])
    }

    func testATextEndingWithANewlineHasAnEmptyLastLine() {
        XCTAssertEqual(starts(lines(of: "ab\n").1), [0, 3])
    }

    func testEachReturnEndsALine() {
        XCTAssertEqual(starts(lines(of: "ab\rcd\r").1), [0, 3, 6])
    }

    func testAReturnAndANewlineEndTwoLines() {
        XCTAssertEqual(starts(lines(of: "ab\r\ncd").1), [0, 3, 4])
    }

    func testLinesAreCountedInUTF16() {
        XCTAssertEqual(starts(lines(of: "é😀\nx").1), [0, 4])
    }

    // MARK: - The line an index is on

    func testTheLineForAnIndex() {
        let (text, lines) = lines(of: "ab\ncd\nef")
        let found = (0...text.length).map { lines.line(forIndex: $0) }
        XCTAssertEqual(found, [0, 0, 0, 1, 1, 1, 2, 2, 2])
    }

    func testAnIndexPastTheEndIsOnTheLastLine() {
        let (_, lines) = lines(of: "ab\ncd")
        XCTAssertEqual(lines.line(forIndex: 100), 1)
    }

    func testTheEndOfATextEndingWithANewlineIsOnTheEmptyLastLine() {
        let (_, lines) = lines(of: "ab\n")
        XCTAssertEqual(lines.line(forIndex: 2), 0)
        XCTAssertEqual(lines.line(forIndex: 3), 1)
    }

    func testTheLineForAnIndexInManyLines() {
        let string = (0..<100).map { String(repeating: "x", count: $0 % 7) }.joined(separator: "\n")
        let (text, lines) = lines(of: string)
        let lineStarts = expectedStarts(string)
        for index in 0...text.length {
            let expected = lineStarts.lastIndex { $0 <= index }!
            XCTAssertEqual(lines.line(forIndex: index), expected, "index \(index)")
        }
    }

    // MARK: - Editing

    func testTypingMovesTheLinesAfter() {
        checkEdit("ab\ncd\nef", replacing: 1, 0, with: "xyz")
        checkEdit("ab\ncd\nef", replacing: 4, 0, with: "x")
        checkEdit("ab\ncd\nef", replacing: 8, 0, with: "x")
    }

    func testDeletingMovesTheLinesAfter() {
        checkEdit("abc\ncd\nef", replacing: 1, 2, with: "")
        checkEdit("ab\ncde\nef", replacing: 4, 1, with: "")
    }

    func testTypingANewline() {
        checkEdit("ab\ncd\nef", replacing: 1, 0, with: "\n")
        checkEdit("ab\ncd\nef", replacing: 3, 0, with: "\n")
        checkEdit("ab\ncd\nef", replacing: 2, 0, with: "\n")
        checkEdit("ab\ncd\nef", replacing: 8, 0, with: "\n")
        checkEdit("", replacing: 0, 0, with: "\n")
    }

    func testDeletingANewline() {
        checkEdit("ab\ncd\nef", replacing: 2, 1, with: "")
        checkEdit("ab\ncd\nef", replacing: 5, 1, with: "")
        checkEdit("ab\n", replacing: 2, 1, with: "")
    }

    func testDeletingWholeLines() {
        checkEdit("ab\ncd\nef\ngh", replacing: 3, 6, with: "")
        checkEdit("ab\ncd\nef\ngh", replacing: 0, 6, with: "")
        checkEdit("ab\ncd\nef\ngh", replacing: 5, 6, with: "")
        checkEdit("ab\ncd\nef\ngh", replacing: 0, 11, with: "")
    }

    func testReplacingLinesWithMoreLines() {
        checkEdit("ab\ncd\nef", replacing: 1, 3, with: "1\n2\n3\n4")
        checkEdit("ab\ncd\nef", replacing: 2, 1, with: "\n\n")
    }

    func testReplacingLinesWithFewerLines() {
        checkEdit("a\nb\nc\nd\ne", replacing: 1, 5, with: "\nX")
        checkEdit("a\nb\nc\nd\ne", replacing: 1, 6, with: "\n")
    }

    func testReplacingLinesWithAsManyLines() {
        checkEdit("a\nb\nc\nd", replacing: 1, 4, with: "\nxyz\n")
        checkEdit("a\nb\nc\nd", replacing: 1, 4, with: "\r\r")
    }

    func testEditingReturnsAndNewlines() {
        checkEdit("ab\r\ncd", replacing: 3, 0, with: "x")
        checkEdit("ab\r\ncd", replacing: 2, 1, with: "")
        checkEdit("ab\r\ncd", replacing: 3, 1, with: "")
        checkEdit("ab\r\ncd", replacing: 2, 2, with: "\n")
    }

    func testReplacingEverything() {
        checkEdit("ab\ncd\nef", replacing: 0, 8, with: "x\ny")
        checkEdit("ab\ncd\nef", replacing: 0, 8, with: "")
    }

    func testTheNumberOfLinesPutIn() {
        let (text, lines) = lines(of: "ab\ncd\nef")
        XCTAssertEqual(edit(text, lines, replacing: NSRange(location: 1, length: 0), with: "x"), 0)
        XCTAssertEqual(edit(text, lines, replacing: NSRange(location: 1, length: 0), with: "\n\r\n"), 3)
        XCTAssertEqual(edit(text, lines, replacing: NSRange(location: 1, length: 5), with: "\n"), 1)
        XCTAssertEqual(edit(text, lines, replacing: NSRange(location: 0, length: text.length), with: ""), 0)
    }

    /// Many edits of many kinds, each checked against the lines found from scratch.
    func testManyEdits() {
        // A fixed sequence of numbers, so that a failure can be repeated
        var seed: UInt64 = 12345
        func random(_ upperBound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(upperBound))
        }
        let characters = ["a", "b", "\n", "\r", "\t", "é"]
        func randomString() -> String {
            (0..<random(10)).map { _ in characters[random(characters.count)] }.joined()
        }

        let (text, lines) = lines(of: "ab\ncd\r\nef\n")
        for step in 0..<2000 {
            let location = random(text.length + 1)
            let length = random(min(text.length - location, 8) + 1)
            let replacement = randomString()
            edit(text, lines, replacing: NSRange(location: location, length: length), with: replacement)

            let expected = expectedStarts(text as String)
            if starts(lines) != expected {
                XCTFail("step \(step), replacing \(length) at \(location) with \(replacement.debugDescription): "
                        + "\(starts(lines)) for \((text as String).debugDescription)")
                return
            }
        }
    }
}
