//
//  IFToolbarManagerTests.swift
//  InformTests
//

import XCTest

final class IFToolbarManagerTests: XCTestCase {

    /// The status view is drawn over the status spacer item, and is hidden if the spacer is too narrow
    /// for it, so the spacer has to take up the toolbar's spare width.
    func testStatusSpacerTakesTheSpareWidth() throws {
        let manager = IFToolbarManager()
        let toolbar = NSToolbar(identifier: "IFInform7Toolbar")
        toolbar.autosavesConfiguration = false
        toolbar.delegate = manager

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.toolbar = toolbar
        window.layoutIfNeeded()

        let spacer = try XCTUnwrap(toolbar.items.first { $0.itemIdentifier.rawValue == "toolbarStatusSpacingItem" }?.view)
        XCTAssertGreaterThan(spacer.frame.width, 300)
    }

    /// A project controller owns its toolbar manager, so the manager mustn't keep the controller alive:
    /// if it did, neither would be freed once the project's window had closed.
    func testDoesNotKeepItsProjectControllerAlive() {
        weak var weakController: IFProjectController?
        autoreleasepool {
            let controller = IFProjectController()
            weakController = controller
        }

        XCTAssertNil(weakController)
    }
}
