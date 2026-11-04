//
//  IFGamePageTests.swift
//  InformTests
//

import XCTest

final class IFGamePageTests: XCTestCase {

    /// Everything the game page's input source would type, in order.
    private func typedCommands(_ page: IFGamePage) throws -> [String] {
        let source = try XCTUnwrap(page.takeTestCommands())
        var typed: [String] = []
        while let command = source.nextCommand?() {
            typed.append(command)
        }
        return typed
    }

    func testPlayingToAKnotTypesTheCommandsFromTheStart() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let inventory: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "inventory"))
        let examine: IFSkeinItem = inventory.addChild(IFSkeinItem(skein: skein, command: "examine ball"))

        let page: IFGamePage = IFGamePage(projectController: nil)
        page.setPointToRunTo(examine)
        XCTAssertEqual(try typedCommands(page), ["look", "inventory", "examine ball"])
        XCTAssertNil(page.takeTestCommands(), "The commands are typed only once")
    }

    func testTestCommandsAreTypedInOrder() throws {
        let page: IFGamePage = IFGamePage(projectController: nil)
        page.setTestCommands(["take ball", "drop ball", "test me"])
        XCTAssertEqual(try typedCommands(page), ["take ball", "drop ball", "test me"])
    }
}
