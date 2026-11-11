//
//  IFSkeinLayoutItemTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSkeinLayoutItemTests: XCTestCase {

    private let skein: IFSkein = IFSkein(project: nil)

    /// A layout item for a new knot below the root, with the given command.
    private func makeItem(_ command: String,
                          subtreeWidth: CGFloat = 1.0,
                          level: Int32 = 1) -> IFSkeinLayoutItem {
        let item: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: command))
        return IFSkeinLayoutItem(item: item, subtreeWidth: subtreeWidth, level: level)
    }

    /// A layout item with three children, none of them on the selected line.
    private func makeFamily() -> (IFSkeinLayoutItem, [IFSkeinLayoutItem]) {
        let parent = makeItem("look")
        let children = [makeItem("north"), makeItem("south"), makeItem("east")]
        parent.children = children
        for child in children {
            child.parent = parent
        }
        return (parent, children)
    }

    // MARK: - Initialisation

    func testANewItem() {
        let layoutItem = makeItem("look", subtreeWidth: 42, level: 3)
        XCTAssertEqual(layoutItem.item.command, "look")
        XCTAssertEqual(layoutItem.subtreeWidth, 42)
        XCTAssertEqual(layoutItem.level, 3)
        XCTAssertEqual(layoutItem.boundingRect, .zero)
        XCTAssertNil(layoutItem.parent)
        XCTAssertNil(layoutItem.children)
        XCTAssertFalse(layoutItem.onSelectedLine)
        XCTAssertFalse(layoutItem.recentlyPlayed)
    }

    func testTheCommandIsMeasured() {
        let short = makeItem("x")
        let long = makeItem("examine the very long command")
        XCTAssertGreaterThan(short.commandWidth, 0)
        XCTAssertGreaterThan(long.commandWidth, short.commandWidth)

        // It's measured by the knot's view, which keeps the size in the knot
        XCTAssertFalse(long.item.commandSizeDidChange)
        XCTAssertEqual(long.commandWidth, long.item.cachedCommandSize.width)
        XCTAssertEqual(long.commandWidth, IFSkeinItemView.commandSize(long).width)
    }

    func testTheVisibleWidthIncludesTheLozengeEnds() {
        let layoutItem = makeItem("look")
        XCTAssertEqual(layoutItem.visibleWidth, 20 + layoutItem.commandWidth)
        layoutItem.commandWidth = 100
        XCTAssertEqual(layoutItem.visibleWidth, 120)
    }

    // MARK: - The tree

    func testTheChildrenAreACopy() {
        let parent = makeItem("look")
        let children = NSMutableArray(object: makeItem("north"))
        parent.setValue(children, forKey: "children")
        children.add(makeItem("south"))
        XCTAssertEqual(parent.children?.count, 1)
        XCTAssertEqual(parent.children?.first?.item.command, "north")
    }

    func testTheParentIsWeak() {
        let child = makeItem("north")
        autoreleasepool {
            let parent = makeItem("look")
            child.parent = parent
            XCTAssertTrue(child.parent === parent)
        }
        XCTAssertNil(child.parent)
    }

    // MARK: - Moving

    func testMovingRight() {
        let (parent, children) = makeFamily()
        let grandchild = makeItem("wait")
        children[0].children = [grandchild]
        parent.boundingRect = NSRect(x: 10, y: 5, width: 50, height: 34)
        children[0].boundingRect = NSRect(x: 20, y: 40, width: 60, height: 34)
        grandchild.boundingRect = NSRect(x: 30, y: 80, width: 70, height: 34)

        // Only the item, to a whole number of points
        parent.moveRight(by: 5.5, recursively: false)
        XCTAssertEqual(parent.boundingRect, NSRect(x: 15, y: 5, width: 50, height: 34))
        XCTAssertEqual(children[0].boundingRect.minX, 20)

        // The whole subtree, each rounded down on its own
        parent.moveRight(by: 2.25, recursively: true)
        XCTAssertEqual(parent.boundingRect, NSRect(x: 17, y: 5, width: 50, height: 34))
        XCTAssertEqual(children[0].boundingRect, NSRect(x: 22, y: 40, width: 60, height: 34))
        XCTAssertEqual(grandchild.boundingRect, NSRect(x: 32, y: 80, width: 70, height: 34))
        XCTAssertEqual(children[1].boundingRect, NSRect(x: 2, y: 0, width: 0, height: 0))

        // Rounded down when moving left too
        parent.moveRight(by: -0.5, recursively: false)
        XCTAssertEqual(parent.boundingRect.minX, 16)
    }

    // MARK: - Rectangles

    // The bounding rectangle is in the skein view, which is flipped. The lozenge is 5 points in from the left of the
    // rectangle and 10 from the right, 5 of them for the frame. Its top is 2 points below the top of a 30 point image
    // at the bottom of the rectangle, and it's 6 points shorter than the rectangle (IFSkeinConstants.h).

    func testTheLozenge() {
        let layoutItem = makeItem("look")
        layoutItem.boundingRect = NSRect(x: 100, y: 200, width: 80, height: 34)
        XCTAssertEqual(layoutItem.lozengeRect, NSRect(x: 105, y: 206, width: 65, height: 28))
        XCTAssertEqual(layoutItem.centreX, 137.5)

        layoutItem.boundingRect = NSRect(x: 0, y: 0, width: 200, height: 40)
        XCTAssertEqual(layoutItem.lozengeRect, NSRect(x: 5, y: 12, width: 185, height: 34))
        XCTAssertEqual(layoutItem.centreX, 97.5)
    }

    func testTheLozengeInTheKnotsView() {
        // The knot's view isn't flipped, and its origin is the bounding rectangle's
        let layoutItem = makeItem("look")
        layoutItem.boundingRect = NSRect(x: 100, y: 200, width: 80, height: 34)
        XCTAssertEqual(layoutItem.localSpaceLozengeRect, NSRect(x: 5, y: 0, width: 65, height: 28))

        layoutItem.boundingRect = NSRect(x: 0, y: 0, width: 200, height: 40)
        XCTAssertEqual(layoutItem.localSpaceLozengeRect, NSRect(x: 5, y: -6, width: 185, height: 34))
    }

    func testTheText() {
        let layoutItem = makeItem("look")
        layoutItem.boundingRect = NSRect(x: 100, y: 200, width: 80, height: 34)
        layoutItem.commandWidth = 40
        XCTAssertEqual(layoutItem.textRect, NSRect(x: 120, y: 206, width: 40, height: 28))
    }

    // MARK: - The selected line

    func testTheSelectedLineChild() {
        let (parent, children) = makeFamily()
        XCTAssertNil(parent.selectedLineChild)
        XCTAssertNil(makeItem("wait").selectedLineChild)

        children[1].onSelectedLine = true
        XCTAssertTrue(parent.selectedLineChild === children[1])

        // The first, if there's more than one
        children[2].onSelectedLine = true
        XCTAssertTrue(parent.selectedLineChild === children[1])
    }

    func testTheEndOfTheSelectedLine() {
        let (parent, children) = makeFamily()
        let grandchild = makeItem("wait")
        children[1].children = [grandchild]

        // None if the item isn't on the line
        XCTAssertNil(parent.leafSelectedLine)
        children[1].onSelectedLine = true
        XCTAssertNil(parent.leafSelectedLine)

        parent.onSelectedLine = true
        XCTAssertTrue(parent.leafSelectedLine === children[1])
        XCTAssertTrue(children[1].leafSelectedLine === children[1])

        grandchild.onSelectedLine = true
        XCTAssertTrue(parent.leafSelectedLine === grandchild)

        children[1].onSelectedLine = false
        XCTAssertTrue(parent.leafSelectedLine === parent)
    }

    // MARK: - Drawing

    func testTheDrawStateHash() {
        let layoutItem = makeItem("look")
        let fontBits = UInt(10 * IFSkeinView.fontSize) << 4
        func commandBits(_ command: String) -> UInt {
            return UInt(bitPattern: (command as NSString).hash)
        }
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("look") ^ fontBits)

        layoutItem.recentlyPlayed = true
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("look") ^ fontBits ^ 1)
        layoutItem.onSelectedLine = true
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("look") ^ fontBits ^ 3)

        layoutItem.item.ideal = "You see nothing special.\n\n>"
        layoutItem.item.actual = "You see a lamp.\n\n>"
        XCTAssertTrue(layoutItem.item.hasBadge)
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("look") ^ fontBits ^ 7)

        layoutItem.item.isTestSubItem = true
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("look") ^ fontBits ^ 15)

        layoutItem.item.command = "jump"
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("jump") ^ fontBits ^ 15)

        layoutItem.recentlyPlayed = false
        layoutItem.onSelectedLine = false
        XCTAssertEqual(layoutItem.drawStateHash, commandBits("jump") ^ fontBits ^ 12)
    }
}
