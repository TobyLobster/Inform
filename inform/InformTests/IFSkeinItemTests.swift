//
//  IFSkeinItemTests.swift
//  InformTests
//

import XCTest

final class IFSkeinItemTests: XCTestCase {

    /// Dragging a knot copies it, and the knots below it, through the pasteboard as an archive.
    private func dragCopy(_ item: IFSkeinItem) throws -> IFSkeinItem {
        let type = NSPasteboard.PasteboardType(IFSkeinItemPboardType)
        let data = try XCTUnwrap(item.pasteboardPropertyList(forType: type) as? Data)
        return try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: IFSkeinItem.self, from: data))
    }

    func testDraggingKeepsTheWholeKnot() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.actual = "Library\n\n>"
        look.ideal = "The Library\n\n>"
        let jump: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "jump"))
        jump.actual = "You jump.\n\n>"
        jump.ideal = "You jump on the spot.\n\n>"
        jump.isTestSubItem = true

        let copy = try dragCopy(look)
        XCTAssertEqual(copy.command, "look")
        XCTAssertEqual(copy.actual, "Library\n\n>")
        XCTAssertEqual(copy.ideal, "The Library\n\n>")
        XCTAssertFalse(copy.isTestSubItem)
        XCTAssertNil(copy.parent)

        XCTAssertEqual(copy.children.count, 1)
        let copiedJump: IFSkeinItem = copy.children[0]
        XCTAssertTrue(copiedJump.parent === copy)
        XCTAssertEqual(copiedJump.command, "jump")
        XCTAssertEqual(copiedJump.actual, "You jump.\n\n>")
        XCTAssertEqual(copiedJump.ideal, "You jump on the spot.\n\n>")
        XCTAssertTrue(copiedJump.isTestSubItem)
    }
}
