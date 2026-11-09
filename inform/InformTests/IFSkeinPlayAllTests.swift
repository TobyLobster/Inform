//
//  IFSkeinPlayAllTests.swift
//  InformTests
//

import XCTest

/// The knots the skein's Play All plays to
final class IFSkeinPlayAllTests: XCTestCase {
    private let skein = IFSkein(project: nil)

    @discardableResult
    private func add(_ command: String, to parent: IFSkeinItem, isTestSubItem: Bool = false) -> IFSkeinItem {
        let item = IFSkeinItem(skein: skein, command: command)
        item.isTestSubItem = isTestSubItem
        return parent.addChild(item)
    }

    /// The commands of the knots played to, in turn
    private func commandsPlayedTo(_ playAll: IFSkeinPlayAll) -> [String] {
        var commands: [String] = []
        while let item = playAll.nextItem {
            commands.append(item.command)
            playAll.removeNextItem()
        }
        return commands
    }

    func testAnEmptySkeinIsPlayedToItsStart() {
        let playAll = IFSkeinPlayAll(rootItem: skein.rootItem)

        XCTAssertTrue(playAll.nextItem === skein.rootItem)
        playAll.removeNextItem()
        XCTAssertNil(playAll.nextItem)
    }

    func testEachThreadIsPlayedToItsEndInOrder() {
        let look = add("look", to: skein.rootItem)
        let north = add("north", to: look)
        add("east", to: north)
        add("south", to: look)
        add("wait", to: skein.rootItem)

        let playAll = IFSkeinPlayAll(rootItem: skein.rootItem)

        XCTAssertEqual(commandsPlayedTo(playAll), ["east", "south", "wait"])
    }

    func testTheNextKnotStaysUntilTakenAway() {
        add("look", to: skein.rootItem)
        let playAll = IFSkeinPlayAll(rootItem: skein.rootItem)

        XCTAssertEqual(playAll.nextItem?.command, "look")
        XCTAssertEqual(playAll.nextItem?.command, "look")
    }

    func testAThreadEndingInTestCommandsIsPlayedToItsTestMe() {
        let testMe = add("test me", to: skein.rootItem)
        let north = add("north", to: testMe, isTestSubItem: true)
        add("south", to: north, isTestSubItem: true)
        add("wait", to: skein.rootItem)

        let playAll = IFSkeinPlayAll(rootItem: skein.rootItem)

        XCTAssertTrue(playAll.nextItem === testMe)
        XCTAssertEqual(commandsPlayedTo(playAll), ["test me", "wait"])
    }

    func testAThreadGoingOnAfterTestCommandsIsPlayedToItsEnd() {
        let testMe = add("test me", to: skein.rootItem)
        let north = add("north", to: testMe, isTestSubItem: true)
        add("look", to: north)

        let playAll = IFSkeinPlayAll(rootItem: skein.rootItem)

        XCTAssertEqual(commandsPlayedTo(playAll), ["look"])
    }
}
