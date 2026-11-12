//
//  IFElasticTabsTests.swift
//  InformTests
//

import XCTest

/// The tables in source text that elastic tabs lay out in columns, and their cells.
@MainActor
final class IFElasticTabsTests: XCTestCase {

    /// A table, with its lines and their cells.
    private let fruit = "name\tcolour\tprice\napple\tred\t3\nbanana\tyellow\t4\ncherry\tdark red\t10\n"
    private let fruitCells = [["name", "colour", "price"],
                              ["apple", "red", "3"],
                              ["banana", "yellow", "4"],
                              ["cherry", "dark red", "10"],
                              []]

    /// The table, with text before and after it.
    private var source: String {
        "The Kitchen is a room.\n\nTable of Fruit\n" + fruit + "\nThe fruit bowl is in the Kitchen.\n"
    }

    /// The text of the table that a character is in, or nil if it isn't in one.
    private func table(at index: Int, in text: String) -> String? {
        let range = IFElasticTabs(string: text).rangeOfRegion(at: UInt(index))
        if range.location == NSNotFound {
            return nil
        }
        return (text as NSString).substring(with: range)
    }

    /// The text of the table that the first match of some text starts in, or nil if it isn't in one.
    private func table(at find: String, in text: String,
                       file: StaticString = #filePath, line: UInt = #line) -> String? {
        let index = (text as NSString).range(of: find).location
        XCTAssertNotEqual(index, NSNotFound, find, file: file, line: line)
        return table(at: index, in: text)
    }

    /// The text of the cells of each line in a range of a text, or all of it.
    private func cells(in text: String, region: NSRange? = nil) -> [[String]] {
        let region = region ?? NSRange(location: 0, length: (text as NSString).length)
        return IFElasticTabs(string: text).cells(inRegion: region).map { line in
            line.map { (text as NSString).substring(with: $0.rangeValue) }
        }
    }

    // MARK: - Finding tables

    func testATableIsTheLinesWithTabsAroundACharacter() {
        XCTAssertEqual(table(at: "apple", in: source), fruit)
    }

    func testEveryCharacterOfATableIsInIt() {
        let source = source
        let start = (source as NSString).range(of: fruit).location
        for index in start ..< start + (fruit as NSString).length {
            XCTAssertEqual(table(at: index, in: source), fruit, "Character \(index - start)")
        }
    }

    func testTheTextAroundATableIsNotInIt() {
        let source = source
        XCTAssertNil(table(at: "The Kitchen", in: source))
        XCTAssertNil(table(at: "Table of Fruit", in: source))
        XCTAssertNil(table(at: "The fruit bowl", in: source))

        // The blank lines before and after it, and the end of the text
        XCTAssertNil(table(at: (source as NSString).range(of: "\n\nTable").location + 1, in: source))
        XCTAssertNil(table(at: (source as NSString).range(of: "10\n\n").location + 3, in: source))
        XCTAssertNil(table(at: (source as NSString).length, in: source))
    }

    func testOneLineWithATabIsNotATable() {
        XCTAssertNil(table(at: 0, in: "name\tcolour\n"))
        XCTAssertNil(table(at: "name", in: "Some text.\nname\tcolour\nMore text.\n"))
    }

    func testTablesAreSeparatedByLinesWithoutTabs() {
        let text = "a\tb\nc\td\n\ne\tf\ng\th\nText.\ni\tj\nk\tl\n"
        XCTAssertEqual(table(at: "a", in: text), "a\tb\nc\td\n")
        XCTAssertEqual(table(at: "g", in: text), "e\tf\ng\th\n")
        XCTAssertEqual(table(at: "k", in: text), "i\tj\nk\tl\n")
    }

    func testLinesStartingWithATabAreNotInATable() {
        // As the phrases of a rule are indented
        let rule = "Every turn:\n\tsay \"Tick.\";\n\tsay \"Tock.\";\n"
        XCTAssertNil(table(at: "say", in: rule))

        // Even with a tab after something else, or with white space before the first tab
        let text = "a\tb\n\tc\td\n  \te\tf\n"
        XCTAssertNil(table(at: "a", in: text))
        XCTAssertNil(table(at: "c", in: text))
        XCTAssertNil(table(at: "e", in: text))
    }

    func testLinesStartingWithSpacesCanBeInATable() {
        let text = "  a\tb\n  c\td\n"
        XCTAssertEqual(table(at: "c", in: text), text)
    }

    func testATableCanStartAndEndTheText() {
        let text = "a\tb\nc\td"
        XCTAssertEqual(table(at: 0, in: text), text)
        XCTAssertEqual(table(at: (text as NSString).length, in: text), text)
    }

    func testNoText() {
        XCTAssertNil(table(at: 0, in: ""))
        XCTAssertEqual(cells(in: ""), [[]])
    }

    func testLinesEndingInReturns() {
        let text = "Text.\ra\tb\rc\td\rText.\r"
        XCTAssertEqual(table(at: "a", in: text), "a\tb\rc\td\r")
        XCTAssertEqual(table(at: "c", in: text), "a\tb\rc\td\r")
    }

    // MARK: - Cells

    func testTheCellsOfATablesLines() {
        XCTAssertEqual(cells(in: fruit), fruitCells)
    }

    func testTheCellsOfATableInText() {
        let source = source
        let apple = (source as NSString).range(of: "apple").location
        let region = IFElasticTabs(string: source).rangeOfRegion(at: UInt(apple))
        XCTAssertEqual(cells(in: source, region: region), fruitCells)
    }

    func testCellsCanBeEmpty() {
        XCTAssertEqual(cells(in: "a\t\tb\nc\td\t\n"), [["a", "", "b"], ["c", "d", ""], []])
    }

    func testWhiteSpaceIsPartOfACell() {
        XCTAssertEqual(cells(in: "  a \t b\n"), [["  a ", " b"], []])
    }

    func testTabsAtTheStartOfALineDontEndACell() {
        XCTAssertEqual(cells(in: "\ta\tb\n\t\tc\td\n"), [["\ta", "b"], ["\t\tc", "d"], []])
    }

    func testTheLastCellOfATableAtTheEndOfTheText() {
        XCTAssertEqual(cells(in: "a\tb\ncc\tdd"), [["a", "b"], ["cc", "dd"]])
        XCTAssertEqual(cells(in: "a\tb\nc\td"), [["a", "b"], ["c", "d"]])
    }

    func testLinesEndingInReturnsHaveCells() {
        XCTAssertEqual(cells(in: "a\tb\rc\td\r"), [["a", "b"], ["c", "d"], []])
    }
}
