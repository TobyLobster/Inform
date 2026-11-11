//
//  IFSkeinLayoutTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSkeinLayoutTests: XCTestCase {

    private let skein: IFSkein = IFSkein(project: nil)

    /// Adds a knot with the given command below the given one.
    @discardableResult
    private func add(_ command: String, to parent: IFSkeinItem) -> IFSkeinItem {
        return parent.addChild(IFSkeinItem(skein: skein, command: command))
    }

    /// The layout item for each knot in a laid-out skein, by command.
    private func layoutItems(_ layout: IFSkeinLayout) -> [String: IFSkeinLayoutItem] {
        var result: [String: IFSkeinLayoutItem] = [:]
        var queue: [IFSkeinLayoutItem] = layout.rootLayoutItem.map { [$0] } ?? []
        while let layoutItem = queue.popLast() {
            result[layoutItem.item.command] = layoutItem
            queue += layoutItem.children ?? []
        }
        return result
    }

    /// The layout items on each level, left to right.
    private func levels(_ layout: IFSkeinLayout) -> [[IFSkeinLayoutItem]] {
        var result: [[IFSkeinLayoutItem]] = []
        for layoutItem in layoutItems(layout).values {
            while result.count <= Int(layoutItem.level) {
                result.append([])
            }
            result[Int(layoutItem.level)].append(layoutItem)
        }
        return result.map { $0.sorted { $0.boundingRect.minX < $1.boundingRect.minX } }
    }

    /// A skein of three levels (a knot's children are in alphabetical order):
    ///
    ///     - start -
    ///     ├── look
    ///     │   ├── north
    ///     │   └── open the very long description
    ///     └── wait
    private func makeSkein() -> (look: IFSkeinItem, north: IFSkeinItem, open: IFSkeinItem, wait: IFSkeinItem) {
        let look = add("look", to: skein.rootItem)
        let north = add("north", to: look)
        let open = add("open the very long description", to: look)
        let wait = add("wait", to: skein.rootItem)
        return (look, north, open, wait)
    }

    /// A skein laid out as the skein view does it, with the given heights for its levels.
    private func layOut(selecting selected: IFSkeinItem? = nil,
                        active: IFSkeinItem? = nil,
                        levelHeights: [CGFloat] = []) -> IFSkeinLayout {
        let layout = IFSkeinLayout(rootItem: skein.rootItem)
        layout.selectedItem = selected
        layout.activeItem = active
        layout.layoutSkein()
        layout.update(withReportDetails: levelHeights.map { NSNumber(value: Double($0)) })
        return layout
    }

    // MARK: - A new layout

    func testANewLayout() {
        for layout in [IFSkeinLayout(), IFSkeinLayout(rootItem: nil)] {
            XCTAssertNil(layout.rootItem)
            XCTAssertNil(layout.activeItem)
            XCTAssertNil(layout.selectedItem)
            XCTAssertNil(layout.rootLayoutItem)
            XCTAssertNil(layout.selectedLayoutItem)
            XCTAssertEqual(layout.reportPosition, .zero)
            XCTAssertEqual(layout.size, .zero)
        }
        XCTAssertTrue(IFSkeinLayout(rootItem: skein.rootItem).rootItem === skein.rootItem)
    }

    func testLayingOutNothing() {
        let layout = IFSkeinLayout(rootItem: nil)
        layout.layoutSkein()
        layout.update(withReportDetails: [])
        XCTAssertNil(layout.rootLayoutItem)
        XCTAssertEqual(layout.size, .zero)
        XCTAssertNil(layout.item(at: NSPoint(x: 30, y: 30)))
    }

    // MARK: - The tree

    func testThereIsALayoutItemForEachKnot() throws {
        let knots = makeSkein()
        let layout = layOut()

        let root = try XCTUnwrap(layout.rootLayoutItem)
        XCTAssertTrue(root.item === skein.rootItem)
        XCTAssertNil(root.parent)
        XCTAssertEqual(root.level, 0)
        XCTAssertEqual(root.children?.map { $0.item.command }, ["look", "wait"])

        let look = try XCTUnwrap(root.children?.first)
        XCTAssertTrue(look.item === knots.look)
        XCTAssertTrue(look.parent === root)
        XCTAssertEqual(look.level, 1)
        XCTAssertEqual(look.children?.map { $0.item.command }, ["north", "open the very long description"])
        for child in look.children ?? [] {
            XCTAssertTrue(child.parent === look)
            XCTAssertEqual(child.level, 2)
            XCTAssertEqual(child.children?.count, 0)
        }
        XCTAssertEqual(layoutItems(layout).count, 5)
    }

    func testEachLayoutIsNew() throws {
        _ = makeSkein()
        let layout = layOut()
        let first = try XCTUnwrap(layout.rootLayoutItem)
        layout.layoutSkein()
        XCTAssertFalse(layout.rootLayoutItem === first)
        XCTAssertEqual(layoutItems(layout).count, 5)
    }

    func testTheSelectedKnotsLayoutItem() throws {
        let knots = makeSkein()
        XCTAssertNil(layOut().selectedLayoutItem)
        let layout = layOut(selecting: knots.north)
        XCTAssertTrue(try XCTUnwrap(layout.selectedLayoutItem).item === knots.north)

        // A knot that isn't in the skein has none
        XCTAssertNil(layOut(selecting: IFSkeinItem(skein: skein, command: "wait")).selectedLayoutItem)
    }

    // MARK: - Played and selected knots

    func testTheKnotsAboveTheActiveOneWereRecentlyPlayed() {
        let knots = makeSkein()
        let items = layoutItems(layOut(active: knots.north))
        XCTAssertEqual(Set(items.filter { $0.value.recentlyPlayed }.keys), ["- start -", "look", "north"])

        XCTAssertEqual(layoutItems(layOut()).values.filter { $0.recentlyPlayed }.count, 0)
    }

    func testTheSelectedLine() {
        let knots = makeSkein()
        func selectedLine(_ selected: IFSkeinItem?) -> Set<String> {
            return Set(layoutItems(layOut(selecting: selected)).filter { $0.value.onSelectedLine }.keys)
        }
        XCTAssertEqual(selectedLine(nil), [])
        XCTAssertEqual(selectedLine(knots.wait), ["- start -", "wait"])
        XCTAssertEqual(selectedLine(knots.open), ["- start -", "look", "open the very long description"])

        // Below the selected knot, the line follows the first child each time
        XCTAssertEqual(selectedLine(knots.look), ["- start -", "look", "north"])
        XCTAssertEqual(selectedLine(skein.rootItem), ["- start -", "look", "north"])
    }

    // MARK: - Positions

    func testTheKnotsOnALevelDontOverlap() {
        _ = makeSkein()
        add("xyzzy", to: skein.rootItem)
        for selected in [nil, skein.rootItem.children[1]] {
            for level in levels(layOut(selecting: selected)) {
                for (left, right) in zip(level, level.dropFirst()) {
                    XCTAssertLessThan(left.lozengeRect.maxX, right.lozengeRect.minX,
                                      "\(left.item.command!) and \(right.item.command!)")
                }
            }
        }
    }

    func testAKnotIsAsWideAsItsCommand() {
        _ = makeSkein()
        for layoutItem in layoutItems(layOut()).values {
            XCTAssertEqual(layoutItem.boundingRect.width, (35 + layoutItem.commandWidth).rounded(.up),
                           accuracy: 1, layoutItem.item.command)
            XCTAssertEqual(layoutItem.boundingRect.height, 34)
            XCTAssertEqual(layoutItem.boundingRect.minX, layoutItem.boundingRect.minX.rounded(.down))
        }
    }

    func testAParentIsCentredOverItsChildren() {
        _ = makeSkein()
        let items = layoutItems(layOut())
        for layoutItem in items.values {
            guard let children = layoutItem.children, !children.isEmpty else { continue }
            let centres = children.map { $0.centreX }
            XCTAssertEqual(layoutItem.centreX, (centres.min()! + centres.max()!) / 2,
                           accuracy: 1, layoutItem.item.command)
        }
    }

    func testTheSelectedLineIsStraight() {
        let knots = makeSkein()
        let layout = layOut(selecting: knots.open)
        var layoutItem = layout.rootLayoutItem
        var count = 0
        while let item = layoutItem, let child = item.selectedLineChild {
            XCTAssertEqual(child.centreX, item.centreX, accuracy: 1, child.item.command)
            layoutItem = child
            count += 1
        }
        XCTAssertEqual(count, 2)
    }

    // MARK: - The report

    func testTheLevelsTakeTheReportsHeights() {
        _ = makeSkein()
        let layout = layOut(levelHeights: [50, 60.5])
        for (index, level) in levels(layout).enumerated() {
            for layoutItem in level {
                XCTAssertEqual(layoutItem.boundingRect.minY, [20, 70, 130.5][index], layoutItem.item.command)
            }
        }
        // A level the report doesn't give has the least height
        XCTAssertEqual(layout.size.height, 20 + 50 + 60.5 + 34 + 20)
    }

    func testTheReportIsBesideTheSelectedLine() throws {
        let knots = makeSkein()
        let layout = layOut(selecting: knots.look)
        let items = layoutItems(layout)

        // To the right of the knots on the selected line, level with the first
        let line = items.values.filter { $0.onSelectedLine }
        XCTAssertEqual(line.count, 3)
        let rightOfLine = line.map { ($0.lozengeRect.maxX + 15).rounded(.down) }.max()!
        XCTAssertEqual(layout.reportPosition, NSPoint(x: rightOfLine, y: 20 + 2 + 15 - 6 - 5))

        // The knots to the right of the selected line move right of the report
        for command in ["wait", "open the very long description"] {
            let layoutItem = try XCTUnwrap(items[command])
            XCTAssertGreaterThanOrEqual(layoutItem.boundingRect.minX, layout.reportPosition.x + 410 + 10 - 5, command)
        }
    }

    func testTheReportsRoomGoesWithTheSelection() {
        let knots = makeSkein()
        let neverSelected = layOut().size

        let layout = layOut(selecting: knots.look)
        XCTAssertGreaterThan(layout.size.width, neverSelected.width)

        layout.selectedItem = nil
        layout.layoutSkein()
        layout.update(withReportDetails: [])
        XCTAssertEqual(layout.size, neverSelected)
    }

    // MARK: - Finding knots

    func testFindingTheKnotAtAPoint() {
        _ = makeSkein()
        let layout = layOut(selecting: skein.rootItem, levelHeights: [50, 60])
        for layoutItem in layoutItems(layout).values {
            let lozenge = layoutItem.lozengeRect
            XCTAssertTrue(layout.item(at: NSPoint(x: lozenge.midX, y: lozenge.midY)) === layoutItem.item,
                          layoutItem.item.command)
            XCTAssertNil(layout.item(at: NSPoint(x: lozenge.minX - 1, y: lozenge.midY)), layoutItem.item.command)
        }
        XCTAssertNil(layout.item(at: NSPoint(x: 30, y: 5)))
        XCTAssertNil(layout.item(at: NSPoint(x: 30, y: 10_000)))
    }

    func testBeforeTheReportTheLayoutHasNoHeight() throws {
        // The skein view always gives the report's details after laying out
        _ = makeSkein()
        let layout = IFSkeinLayout(rootItem: skein.rootItem)
        layout.layoutSkein()
        XCTAssertEqual(layout.size.height, 40)
        let root = try XCTUnwrap(layout.rootLayoutItem)
        XCTAssertNil(layout.item(at: NSPoint(x: root.lozengeRect.midX, y: root.lozengeRect.midY)))
    }
}
