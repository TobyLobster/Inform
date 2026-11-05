//
//  IFIntelFileTests.swift
//  InformTests
//

import XCTest

final class IFIntelFileTests: XCTestCase {

    private func heading(_ name: String, level: Int32 = 4) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// A file with a heading on each of the given lines, named after its line.
    private func file(lines: [Int32]) -> IFIntelFile {
        let file = IFIntelFile()
        for line in lines {
            file.add(heading("Line \(line)"), atLine: line)
        }
        return file
    }

    /// Each symbol in the file, in order, with its line, following the links from the first.
    private func contents(_ file: IFIntelFile) -> [String] {
        var result: [String] = []
        var symbol = file.firstSymbol
        while let current = symbol {
            result.append("\(current.name ?? "-") at \(file.line(for: current))")
            symbol = current.next
        }
        return result
    }

    /// Each symbol in the file, last first, following the links back from the last.
    private func contentsBackwards(_ file: IFIntelFile) -> [String] {
        var last = file.firstSymbol
        while let next = last?.next { last = next }

        var result: [String] = []
        var symbol = last
        while let current = symbol {
            result.append(current.name ?? "-")
            symbol = current.last
        }
        return result
    }

    func testANewFile() {
        let file = IFIntelFile()
        XCTAssertNil(file.firstSymbol)
        XCTAssertNil(file.nearestSymbol(toLine: 0))
        XCTAssertEqual(file.line(for: nil), UInt(NSNotFound))
        XCTAssertEqual(file.line(for: heading("Elsewhere")), UInt(NSNotFound))
        XCTAssertEqual(file.description, "<IFIntelFile 0 symbols:>")
    }

    func testSymbolsAreKeptInLineOrder() {
        let file = file(lines: [8, 0, 4])
        XCTAssertEqual(contents(file), ["Line 0 at 0", "Line 4 at 4", "Line 8 at 8"])
        XCTAssertEqual(contentsBackwards(file), ["Line 8", "Line 4", "Line 0"])
        XCTAssertNil(file.firstSymbol?.last)
    }

    func testSymbolsOnTheSameLineAreKeptInTheOrderTheyWereAdded() {
        let file = file(lines: [0, 8])
        file.add(heading("First"), atLine: 4)
        file.add(heading("Second"), atLine: 4)
        XCTAssertEqual(contents(file), ["Line 0 at 0", "First at 4", "Second at 4", "Line 8 at 8"])
        XCTAssertEqual(contentsBackwards(file), ["Line 8", "Second", "First", "Line 0"])
    }

    func testTheNearestSymbolToALine() {
        let file = file(lines: [0, 4, 8])
        XCTAssertEqual(file.nearestSymbol(toLine: 0)?.name, "Line 0")
        XCTAssertEqual(file.nearestSymbol(toLine: 2)?.name, "Line 0")
        XCTAssertEqual(file.nearestSymbol(toLine: 4)?.name, "Line 4")
        XCTAssertEqual(file.nearestSymbol(toLine: 7)?.name, "Line 4")
        XCTAssertEqual(file.nearestSymbol(toLine: 8)?.name, "Line 8")
        XCTAssertEqual(file.nearestSymbol(toLine: 100)?.name, "Line 8")

        // The first symbol on a line with more than one
        file.add(heading("Second"), atLine: 4)
        XCTAssertEqual(file.nearestSymbol(toLine: 4)?.name, "Line 4")
        XCTAssertEqual(file.nearestSymbol(toLine: 5)?.name, "Second")
    }

    func testNoSymbolIsNearestToALineBeforeTheFirst() {
        let file = file(lines: [3, 6])
        XCTAssertNil(file.nearestSymbol(toLine: 0))
        XCTAssertNil(file.nearestSymbol(toLine: 2))
        XCTAssertEqual(file.nearestSymbol(toLine: 3)?.name, "Line 3")
    }

    func testInsertingALineMovesTheSymbolsFromThatLineOn() {
        let file = file(lines: [0, 4, 8])
        file.insertLine(beforeLine: 4)
        XCTAssertEqual(contents(file), ["Line 0 at 0", "Line 4 at 5", "Line 8 at 9"])

        file.insertLine(beforeLine: 0)
        XCTAssertEqual(contents(file), ["Line 0 at 1", "Line 4 at 6", "Line 8 at 10"])

        file.insertLine(beforeLine: 20)
        XCTAssertEqual(contents(file), ["Line 0 at 1", "Line 4 at 6", "Line 8 at 10"])
    }

    func testRemovingLinesRemovesTheirSymbolsAndMovesTheRest() {
        let file = file(lines: [0, 4, 6, 8, 12])
        let removed = file.nearestSymbol(toLine: 4)!

        file.removeLines(NSRange(location: 4, length: 3))
        XCTAssertEqual(contents(file), ["Line 0 at 0", "Line 8 at 5", "Line 12 at 9"])
        XCTAssertEqual(contentsBackwards(file), ["Line 12", "Line 8", "Line 0"])
        XCTAssertNil(removed.next)
        XCTAssertNil(removed.last)
        XCTAssertEqual(file.line(for: removed), UInt(NSNotFound))
    }

    func testClearingSymbolsLeavesTheLinesWhereTheyAre() {
        let file = file(lines: [0, 4, 6, 8])
        file.clearSymbols(forLines: NSRange(location: 4, length: 1))
        XCTAssertEqual(contents(file), ["Line 0 at 0", "Line 6 at 6", "Line 8 at 8"])
        XCTAssertEqual(contentsBackwards(file), ["Line 8", "Line 6", "Line 0"])

        // Lines with no symbols
        file.clearSymbols(forLines: NSRange(location: 1, length: 4))
        XCTAssertEqual(contents(file), ["Line 0 at 0", "Line 6 at 6", "Line 8 at 8"])
    }

    func testClearingTheFirstAndLastSymbols() {
        let file = file(lines: [0, 4, 6, 8])
        file.clearSymbols(forLines: NSRange(location: 0, length: 5))
        XCTAssertEqual(contents(file), ["Line 6 at 6", "Line 8 at 8"])
        XCTAssertNil(file.firstSymbol?.last)

        file.clearSymbols(forLines: NSRange(location: 7, length: 100))
        XCTAssertEqual(contents(file), ["Line 6 at 6"])
        XCTAssertNil(file.firstSymbol?.next)

        file.clearSymbols(forLines: NSRange(location: 0, length: 100))
        XCTAssertNil(file.firstSymbol)
        XCTAssertNil(file.nearestSymbol(toLine: 6))
    }

    func testAddingASymbolAfterSomeWereCleared() {
        let file = file(lines: [0, 4, 8])
        file.clearSymbols(forLines: NSRange(location: 4, length: 1))
        file.add(heading("New"), atLine: 6)
        XCTAssertEqual(contents(file), ["Line 0 at 0", "New at 6", "Line 8 at 8"])
        XCTAssertEqual(contentsBackwards(file), ["Line 8", "New", "Line 0"])
    }

    func testDescription() {
        let file = IFIntelFile()
        file.add(heading("Story", level: 0), atLine: 0)
        file.add(heading("Chapter 1"), atLine: 4)
        XCTAssertEqual(file.description, """
            <IFIntelFile 2 symbols:
            \tLine 0 - IFIntelSymbol 'Story' - delta 0
            \tLine 4 - IFIntelSymbol 'Chapter 1' - delta 4>
            """)
    }

    func testChangesAreNotifiedOnceTwoSecondsLater() {
        let file = IFIntelFile()
        let start = Date()
        var times: [TimeInterval] = []
        let observer = NotificationCenter.default.addObserver(forName: .IFIntelFileHasChanged,
                                                              object: file, queue: nil) { _ in
            times.append(Date().timeIntervalSince(start))
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        file.add(heading("Story", level: 0), atLine: 0)
        file.insertLine(beforeLine: 0)
        file.intelFileHasChanged()
        XCTAssertEqual(times.count, 0)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertEqual(times.count, 1)
        XCTAssertGreaterThan(times.first ?? 0, 1.9)

        // Changes after the notification are notified again
        file.removeLines(NSRange(location: 0, length: 1))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertEqual(times.count, 2)
    }

    func testClearingLinesWithNoSymbolsIsNotAChange() {
        let file = IFIntelFile()
        var notified = false
        let observer = NotificationCenter.default.addObserver(forName: .IFIntelFileHasChanged,
                                                              object: file, queue: nil) { _ in
            notified = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        file.clearSymbols(forLines: NSRange(location: 0, length: 10))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertFalse(notified)
    }
}
