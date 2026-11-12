//
//  IFTabStopsTests.swift
//  InformTests
//

import XCTest

final class IFTabStopsTests: XCTestCase {

    private func locations(_ stops: [NSTextTab]) -> [CGFloat] {
        return stops.map(\.location)
    }

    // MARK: - The standard tab stops

    /// There are 48 standard tab stops, a tab's width apart
    func testTheStandardTabStopsAreATabsWidthApart() {
        XCTAssertEqual(locations(IFTabStops.standardTabStops(forTabWidth: 28)), (1...48).map { CGFloat($0) * 28 })
    }

    /// A tab width of part of a point is kept
    func testAFractionalTabWidth() {
        XCTAssertEqual(locations(IFTabStops.standardTabStops(forTabWidth: 12.5)).prefix(3), [12.5, 25, 37.5])
    }

    /// With a tab width of less than a point, as with no highlighter, the stops are a point apart
    func testATabWidthOfLessThanAPointIsAPoint() {
        XCTAssertEqual(locations(IFTabStops.standardTabStops(forTabWidth: 0)), (1...48).map { CGFloat($0) })
        XCTAssertEqual(locations(IFTabStops.standardTabStops(forTabWidth: 0.5)).prefix(2), [1, 2])
    }

    /// The standard stops align text to their left
    func testTheStandardTabStopsAreLeftTabs() {
        XCTAssertEqual(Set(IFTabStops.standardTabStops(forTabWidth: 28).map(\.alignment)), [.left])
    }

    // MARK: - A table's tab stops

    /// A table's cells, each line's separated by tabs
    private func cells(_ lines: [String]) -> [[NSAttributedString]] {
        return lines.map { line in
            line.components(separatedBy: "\t").map {
                NSAttributedString(string: $0, attributes: [.font: NSFont.systemFont(ofSize: 12)])
            }
        }
    }

    /// The width of a column for its widest cell: the cell's width, with a margin of 8 points, rounded down
    private func columnWidth(_ cell: String) -> CGFloat {
        let text = NSAttributedString(string: cell, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        return floor(text.size().width + 8)
    }

    /// A table with no cells has no tab stops
    func testATableWithNoCellsHasNoTabStops() {
        XCTAssertEqual(locations(IFTabStops.elasticTabStops(forCells: [], tabWidth: 28)), [])
        XCTAssertEqual(locations(IFTabStops.elasticTabStops(forCells: [[]], tabWidth: 28)), [])
    }

    /// Each column of narrow cells is a tab's width
    func testANarrowColumnIsATabsWidth() {
        XCTAssertLessThan(columnWidth("ab"), 100)
        XCTAssertEqual(locations(IFTabStops.elasticTabStops(forCells: cells(["a\tb", "ab\t"]), tabWidth: 100)),
                       [100, 200])
    }

    /// A column is as wide as its widest cell, with the margin, and the next column starts there
    func testAColumnIsAsWideAsItsWidestCell() {
        let widest = columnWidth("a much longer cell")
        XCTAssertGreaterThan(widest, columnWidth("short"))
        XCTAssertGreaterThan(columnWidth("short"), 28)
        let stops = IFTabStops.elasticTabStops(forCells: cells(["short\tx", "a much longer cell\ty", "\tz"]),
                                               tabWidth: 28)
        XCTAssertEqual(locations(stops), [widest, widest + 28])
    }

    /// Each column is as wide as its own widest cell
    func testEachColumnIsAsWideAsItsOwnWidestCell() {
        let first = columnWidth("Table of Fruit"), second = columnWidth("dark red and black")
        XCTAssertLessThan(columnWidth("10"), 28)
        let stops = IFTabStops.elasticTabStops(forCells: cells(["Table of Fruit\tred\t3", "x\tdark red and black\t10"]),
                                               tabWidth: 28)
        XCTAssertEqual(locations(stops), [first, first + second, first + second + 28])
    }

    /// Lines with fewer cells than others leave the columns they don't reach to the others
    func testLinesCanHaveDifferentNumbersOfCells() {
        let stops = IFTabStops.elasticTabStops(forCells: cells(["a", "a\tb\tc", "a\tb"]), tabWidth: 100)
        XCTAssertEqual(locations(stops), [100, 200, 300])
    }

    /// Each stop is rounded down to a whole point, as it's added to the stops before it
    func testTheStopsAreRoundedDown() {
        let stops = IFTabStops.elasticTabStops(forCells: cells(["\t\t"]), tabWidth: 12.5)
        XCTAssertEqual(locations(stops), [12, 24, 36])
    }

    /// A table's stops align text to their left
    func testATablesStopsAreLeftTabs() {
        let stops = IFTabStops.elasticTabStops(forCells: cells(["a much longer cell\tb"]), tabWidth: 28)
        XCTAssertEqual(Set(stops.map(\.alignment)), [.left])
    }
}
