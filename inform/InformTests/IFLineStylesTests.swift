//
//  IFLineStylesTests.swift
//  InformTests
//

import XCTest

/// The paragraph style of each line of a text, with the standard tab stops or a table's
@MainActor
final class IFLineStylesTests: XCTestCase {

    /// The Inform 6 highlighter, whose tab width is always 28 points
    private let highlighter = IFInform6Highlighter()

    private let standardStops = IFTabStops.standardTabStops(forTabWidth: 28).map { $0.location }

    /// A table of three rows, with lines before and after it. The rows are lines 3 to 5, and line 8 is the empty line
    /// after the last newline.
    private let table = """
        The Kitchen is a room.

        Table of Fruit
        name\tcolour\tprice
        apple\tred\t3
        banana\tyellow\t4

        The fruit bowl is in the Kitchen.

        """

    /// A text, where its lines start, and its lines' styles, as IFSyntaxData has them once it has highlighted the
    /// text: each line with the standard style, which is on the text too, and its tables laid out if asked
    private func styled(_ string: String,
                        layingOutTables: Bool = false) -> (NSTextStorage, IFLineStarts, IFLineStyles) {
        let text = NSTextStorage(string: string)
        let lineStarts = IFLineStarts()
        let lineStyles = IFLineStyles(text: text, lineStarts: lineStarts, highlighter: highlighter)
        let lines = lineStarts.replaceLines(after: 0, through: 0, withLinesIn: string, at: 0,
                                            changeInLength: text.length)
        lineStyles.replaceLines(after: 0, through: 0, with: lines)
        for line in 0..<lineStarts.count {
            lineStyles.resetLine(line)
        }
        lineStyles.applyStyles(from: 0, through: lineStarts.count - 1)
        if layingOutTables {
            _ = lineStyles.layOutTables(nearLinesFrom: 0, through: lineStarts.count - 1, updatingAll: true,
                                        changedRange: NSRange(location: 0, length: 0))
        }
        return (text, lineStarts, lineStyles)
    }

    private func paragraphStyle(ofLine line: Int, in lineStyles: IFLineStyles) -> NSParagraphStyle? {
        return lineStyles.style(ofLine: line)[.paragraphStyle] as? NSParagraphStyle
    }

    /// The tab stops of a line's style
    private func stops(ofLine line: Int, in lineStyles: IFLineStyles) -> [CGFloat] {
        return paragraphStyle(ofLine: line, in: lineStyles)?.tabStops.map { $0.location } ?? []
    }

    /// The tab stops on the text at the start of a line
    private func stops(ofLine line: Int, in text: NSTextStorage, lineStarts: IFLineStarts) -> [CGFloat] {
        let style = text.attribute(.paragraphStyle, at: lineStarts.start(ofLine: line), effectiveRange: nil)
        return (style as? NSParagraphStyle)?.tabStops.map { $0.location } ?? []
    }

    /// Lays out the tables near some lines, without updating all of them or extending a range
    private func layOutTables(nearLinesFrom firstLine: Int, through lastLine: Int, in lineStyles: IFLineStyles,
                              updatingAll: Bool = false) {
        _ = lineStyles.layOutTables(nearLinesFrom: firstLine, through: lastLine, updatingAll: updatingAll,
                                    changedRange: NSRange(location: 0, length: 0))
    }

    // MARK: - The standard style

    /// A new text's one line has no style yet
    func testANewTextsLineHasNoStyle() {
        let lineStyles = IFLineStyles(text: NSTextStorage(), lineStarts: IFLineStarts(), highlighter: highlighter)
        XCTAssertEqual(lineStyles.count, 1)
        XCTAssertTrue(lineStyles.style(ofLine: 0).isEmpty)
    }

    /// A line reset has the standard style, with the standard tab stops for the highlighter's tab width, or a point
    /// apart with no highlighter
    func testTheStandardStyle() {
        let (_, _, lineStyles) = styled("One\nTwo")
        XCTAssertEqual(lineStyles.count, 2)
        XCTAssertEqual(stops(ofLine: 0, in: lineStyles), standardStops)
        XCTAssertEqual(stops(ofLine: 1, in: lineStyles), standardStops)

        let plain = IFLineStyles(text: NSTextStorage(string: "One"), lineStarts: IFLineStarts(), highlighter: nil)
        plain.resetLine(0)
        XCTAssertEqual(stops(ofLine: 0, in: plain), IFTabStops.standardTabStops(forTabWidth: 1).map { $0.location })
    }

    /// The standard style is made once, and again only after it's forgotten
    func testTheStandardStyleIsMadeOnceUntilForgotten() throws {
        let (_, _, lineStyles) = styled("One\nTwo\nThree")
        let first = try XCTUnwrap(paragraphStyle(ofLine: 0, in: lineStyles))
        XCTAssertTrue(paragraphStyle(ofLine: 1, in: lineStyles) === first)
        XCTAssertTrue(paragraphStyle(ofLine: 2, in: lineStyles) === first)

        lineStyles.forgetStandardStyle()
        lineStyles.resetLine(2)
        let second = try XCTUnwrap(paragraphStyle(ofLine: 2, in: lineStyles))
        XCTAssertFalse(second === first)
        XCTAssertEqual(second.tabStops, first.tabStops)
        XCTAssertTrue(paragraphStyle(ofLine: 1, in: lineStyles) === first)

        lineStyles.resetLine(0)
        XCTAssertTrue(paragraphStyle(ofLine: 0, in: lineStyles) === second)
    }

    /// Resetting a line past the last style kept gives the lines up to it the standard style
    func testResettingALinePastTheEnd() {
        let lineStyles = IFLineStyles(text: NSTextStorage(), lineStarts: IFLineStarts(), highlighter: highlighter)
        lineStyles.resetLine(2)
        XCTAssertEqual(lineStyles.count, 3)
        XCTAssertTrue(lineStyles.style(ofLine: 0).isEmpty)
        XCTAssertEqual(stops(ofLine: 1, in: lineStyles), standardStops)
        XCTAssertEqual(stops(ofLine: 2, in: lineStyles), standardStops)
    }

    // MARK: - Edits

    /// With fewer new lines than old, the first old lines' styles go, and the new lines keep the rest. Otherwise the
    /// old lines' styles go, and the new lines have the standard style.
    func testReplacingLines() throws {
        let (_, _, lineStyles) = styled("0\n1\n2\n3")

        // Each line gets a standard style of its own
        var styles = [try XCTUnwrap(paragraphStyle(ofLine: 0, in: lineStyles))]
        for line in 1...3 {
            lineStyles.forgetStandardStyle()
            lineStyles.resetLine(line)
            styles.append(try XCTUnwrap(paragraphStyle(ofLine: line, in: lineStyles)))
            XCTAssertFalse(styles[line] === styles[line - 1])
        }

        // Lines 1 to 3 become two lines, which keep the styles of lines 2 and 3
        lineStyles.replaceLines(after: 0, through: 3, with: 2)
        XCTAssertEqual(lineStyles.count, 3)
        XCTAssertTrue(paragraphStyle(ofLine: 0, in: lineStyles) === styles[0])
        XCTAssertTrue(paragraphStyle(ofLine: 1, in: lineStyles) === styles[2])
        XCTAssertTrue(paragraphStyle(ofLine: 2, in: lineStyles) === styles[3])

        // Line 1 becomes three lines, with a new standard style, and the old line 3 follows them
        lineStyles.forgetStandardStyle()
        lineStyles.replaceLines(after: 0, through: 1, with: 3)
        XCTAssertEqual(lineStyles.count, 5)
        let standard = try XCTUnwrap(paragraphStyle(ofLine: 1, in: lineStyles))
        XCTAssertFalse(styles.contains { $0 === standard })
        XCTAssertEqual(standard.tabStops.map { $0.location }, standardStops)
        XCTAssertTrue(paragraphStyle(ofLine: 2, in: lineStyles) === standard)
        XCTAssertTrue(paragraphStyle(ofLine: 3, in: lineStyles) === standard)
        XCTAssertTrue(paragraphStyle(ofLine: 4, in: lineStyles) === styles[3])

        // Line 4 is replaced by one line, with the standard style
        lineStyles.replaceLines(after: 3, through: 4, with: 1)
        XCTAssertEqual(lineStyles.count, 5)
        XCTAssertTrue(paragraphStyle(ofLine: 4, in: lineStyles) === standard)

        // Lines 1 to 4 go
        lineStyles.replaceLines(after: 0, through: 4, with: 0)
        XCTAssertEqual(lineStyles.count, 1)
        XCTAssertTrue(paragraphStyle(ofLine: 0, in: lineStyles) === styles[0])
    }

    /// A line's style is put onto its text, from its start to the next line's start or the end of the text, and the
    /// other lines are left as they are
    func testPuttingTheStylesOntoTheText() {
        let text = NSTextStorage(string: "One\nTwo\nThree")
        let lineStarts = IFLineStarts()
        let lineStyles = IFLineStyles(text: text, lineStarts: lineStarts, highlighter: highlighter)
        let lines = lineStarts.replaceLines(after: 0, through: 0, withLinesIn: text.string, at: 0,
                                            changeInLength: text.length)
        lineStyles.replaceLines(after: 0, through: 0, with: lines)
        XCTAssertEqual(lineStyles.count, 3)

        var range = NSRange()
        lineStyles.applyStyles(from: 2, through: 2)
        XCTAssertNil(text.attribute(.paragraphStyle, at: 7, effectiveRange: nil))
        let last = text.attribute(.paragraphStyle, at: 8, effectiveRange: &range) as? NSParagraphStyle
        XCTAssertEqual(range, NSRange(location: 8, length: 5))
        XCTAssertTrue(last === paragraphStyle(ofLine: 2, in: lineStyles))

        lineStyles.applyStyles(from: 1, through: 1)
        XCTAssertNil(text.attribute(.paragraphStyle, at: 3, effectiveRange: nil))
        let middle = text.attribute(.paragraphStyle, at: 4, effectiveRange: &range) as? NSParagraphStyle
        XCTAssertEqual(range, NSRange(location: 4, length: 9))
        XCTAssertTrue(middle === paragraphStyle(ofLine: 1, in: lineStyles))
    }

    // MARK: - Tables

    /// A table's rows get the tab stops of its columns, in their styles and on the text, and the other lines keep the
    /// standard ones. The range given is extended over the table.
    func testLayingOutATable() {
        let (text, lineStarts, lineStyles) = styled(table)
        XCTAssertEqual(lineStarts.count, 9)
        let given = NSRange(location: lineStarts.start(ofLine: 4), length: 1)
        let changed = lineStyles.layOutTables(nearLinesFrom: 4, through: 4, updatingAll: false, changedRange: given)

        let rows = (table as NSString).range(of: "name\tcolour\tprice\napple\tred\t3\nbanana\tyellow\t4\n")
        XCTAssertEqual(changed, NSUnionRange(given, rows))

        let tableStops = stops(ofLine: 3, in: lineStyles)
        XCTAssertNotEqual(tableStops, standardStops)
        XCTAssertGreaterThanOrEqual(tableStops.count, 2)
        XCTAssertEqual(lineStyles.count, 9)
        for line in 0..<9 {
            let expected = (3...5).contains(line) ? tableStops : standardStops
            XCTAssertEqual(stops(ofLine: line, in: lineStyles), expected, "line \(line)")
            if line < 8 {
                XCTAssertEqual(stops(ofLine: line, in: text, lineStarts: lineStarts), expected,
                               "line \(line) of the text")
            }
        }
    }

    /// Only the tables within a line of the lines given are laid out
    func testOnlyTablesNearTheLinesGivenAreLaidOut() {
        let (_, _, lineStyles) = styled(table)
        let given = NSRange(location: 0, length: 1)

        // Neither lines 0 and 1 nor the line after them are in the table
        XCTAssertEqual(lineStyles.layOutTables(nearLinesFrom: 0, through: 1, updatingAll: false, changedRange: given),
                       given)
        XCTAssertEqual(stops(ofLine: 3, in: lineStyles), standardStops)

        // The line after line 2 is
        layOutTables(nearLinesFrom: 2, through: 2, in: lineStyles)
        XCTAssertNotEqual(stops(ofLine: 3, in: lineStyles), standardStops)
    }

    /// Rows whose styles have the table's stops already are skipped, unless all are to be updated
    func testRowsWithTheirStopsAreSkipped() {
        let (text, lineStarts, lineStyles) = styled(table, layingOutTables: true)
        let tableStops = stops(ofLine: 4, in: lineStyles)
        XCTAssertNotEqual(tableStops, standardStops)

        // The text of line 4 loses its stops, though its style keeps them
        let row = NSRange(location: lineStarts.start(ofLine: 4),
                          length: lineStarts.start(ofLine: 5) - lineStarts.start(ofLine: 4))
        text.removeAttribute(.paragraphStyle, range: row)

        layOutTables(nearLinesFrom: 4, through: 4, in: lineStyles)
        XCTAssertEqual(stops(ofLine: 4, in: text, lineStarts: lineStarts), [])

        layOutTables(nearLinesFrom: 4, through: 4, in: lineStyles, updatingAll: true)
        XCTAssertEqual(stops(ofLine: 4, in: text, lineStarts: lineStarts), tableStops)
    }

    /// An edited row, reset to the standard style, gets the table's stops back
    func testAnEditedRowGetsTheTablesStops() {
        let (text, lineStarts, lineStyles) = styled(table, layingOutTables: true)
        let tableStops = stops(ofLine: 4, in: lineStyles)

        lineStyles.resetLine(4)
        lineStyles.applyStyles(from: 4, through: 4)
        XCTAssertEqual(stops(ofLine: 4, in: text, lineStarts: lineStarts), standardStops)

        layOutTables(nearLinesFrom: 4, through: 4, in: lineStyles)
        XCTAssertEqual(stops(ofLine: 4, in: lineStyles), tableStops)
        XCTAssertEqual(stops(ofLine: 4, in: text, lineStarts: lineStarts), tableStops)
    }

    /// A table at the end of the text, with no newline after its last row, has that row laid out too. A style is kept
    /// for a line after it, which isn't there.
    func testATableAtTheEndOfTheText() {
        let (text, lineStarts, lineStyles) = styled("Table\na\tb\ncc\td")
        XCTAssertEqual(lineStarts.count, 3)
        layOutTables(nearLinesFrom: 2, through: 2, in: lineStyles)

        let tableStops = stops(ofLine: 1, in: lineStyles)
        XCTAssertNotEqual(tableStops, standardStops)
        XCTAssertEqual(stops(ofLine: 0, in: lineStyles), standardStops)
        XCTAssertEqual(stops(ofLine: 2, in: lineStyles), tableStops)
        XCTAssertEqual(stops(ofLine: 2, in: text, lineStarts: lineStarts), tableStops)
        XCTAssertEqual(lineStyles.count, 4)
    }

    /// With a newline after the last row, the empty line after it, at the end of the text, gets the table's stops too,
    /// though it has no characters to put them on. A style is kept for a line after that, which isn't there.
    func testATableBeforeTheLastNewline() {
        let (_, lineStarts, lineStyles) = styled("Table\na\tb\ncc\td\n")
        XCTAssertEqual(lineStarts.count, 4)
        layOutTables(nearLinesFrom: 2, through: 2, in: lineStyles)

        let tableStops = stops(ofLine: 1, in: lineStyles)
        XCTAssertNotEqual(tableStops, standardStops)
        XCTAssertEqual(stops(ofLine: 2, in: lineStyles), tableStops)
        XCTAssertEqual(stops(ofLine: 3, in: lineStyles), tableStops)
        XCTAssertEqual(lineStyles.count, 5)
    }
}
