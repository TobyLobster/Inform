//
//  IFSkeinBlessButtonTests.swift
//  InformTests
//

import XCTest

final class IFSkeinBlessButtonTests: XCTestCase {

    private func image(_ name: String) throws -> NSImage {
        return try XCTUnwrap(NSImage(named: "App/Skein/" + name))
    }

    /// An event for the mouse, which the button doesn't look at
    private func event(_ type: NSEvent.EventType) throws -> NSEvent {
        return try XCTUnwrap(NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                                                    windowNumber: 0, context: nil, eventNumber: 0,
                                                    trackingNumber: 0, userData: nil))
    }

    func testANewButton() throws {
        let button = IFSkeinBlessButton()
        XCTAssertFalse(button.isBordered)
        XCTAssertTrue(button.wantsLayer)
        XCTAssertTrue(button.blessState)
        XCTAssertIdentical(button.image, try image("Trans-tick-off"))
    }

    /// Blessed, the button shows a tick, and cursed, a cross
    func testTheBlessState() throws {
        let button = IFSkeinBlessButton()
        button.blessState = false
        XCTAssertIdentical(button.image, try image("Trans-cross-off"))

        button.toggleBlessState()
        XCTAssertTrue(button.blessState)
        XCTAssertIdentical(button.image, try image("Trans-tick-off"))

        button.toggleBlessState()
        XCTAssertFalse(button.blessState)
        XCTAssertIdentical(button.image, try image("Trans-cross-off"))
    }

    /// While the mouse is inside it, the button shows its tick or cross highlighted
    func testTheMouseInside() throws {
        let button = IFSkeinBlessButton()
        button.mouseEntered(with: try event(.mouseEntered))
        XCTAssertIdentical(button.image, try image("Trans-tick"))
        button.blessState = false
        XCTAssertIdentical(button.image, try image("Trans-cross"))

        button.mouseExited(with: try event(.mouseExited))
        XCTAssertIdentical(button.image, try image("Trans-cross-off"))
        button.blessState = true
        XCTAssertIdentical(button.image, try image("Trans-tick-off"))
    }

    /// The button tracks the mouse entering and leaving its visible rectangle, and sets the cursor there, with one
    /// tracking area, however often its tracking areas are updated
    func testTrackingTheMouse() throws {
        let button = IFSkeinBlessButton()
        let others = button.trackingAreas.count

        button.updateTrackingAreas()
        XCTAssertEqual(button.trackingAreas.count, others + 1)
        let area = try XCTUnwrap(button.trackingAreas.last)
        XCTAssertEqual(area.options, [.activeInActiveApp, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect])
        XCTAssertIdentical(area.owner as AnyObject?, button)

        button.updateTrackingAreas()
        XCTAssertEqual(button.trackingAreas.count, others + 1)
    }

    /// Over the button, the cursor is a pointing hand
    func testTheCursor() throws {
        let button = IFSkeinBlessButton()
        NSCursor.arrow.set()

        button.cursorUpdate(with: try event(.cursorUpdate))
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)
        NSCursor.arrow.set()
    }
}
