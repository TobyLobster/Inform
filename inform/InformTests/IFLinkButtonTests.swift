//
//  IFLinkButtonTests.swift
//  InformTests
//

import XCTest

/// A link button that keeps the cursor rectangles it adds, rather than giving them to a window
private final class CursorRectSpy: IFLinkButton {
    var rects: [(rect: NSRect, cursor: NSCursor)] = []

    override func addCursorRect(_ rect: NSRect, cursor object: NSCursor) {
        rects.append((rect, object))
    }
}

/// A window that remembers the views it was told have cursor rectangles to set up again
private final class InvalidationSpy: NSWindow {
    var views: [NSView] = []

    override func invalidateCursorRects(for view: NSView) {
        views.append(view)
        super.invalidateCursorRects(for: view)
    }
}

@MainActor
final class IFLinkButtonTests: XCTestCase {

    func testANewButtonShowsAPointingHand() {
        XCTAssertTrue(IFLinkButton().showsPointingHand)
    }

    /// The pointing hand covers the whole button
    func testThePointingHand() throws {
        let button = CursorRectSpy(frame: NSRect(x: 10, y: 20, width: 120, height: 16))
        button.resetCursorRects()

        XCTAssertEqual(button.rects.count, 1)
        let cursorRect = try XCTUnwrap(button.rects.first)
        XCTAssertEqual(cursorRect.rect, button.bounds)
        XCTAssertIdentical(cursorRect.cursor, NSCursor.pointingHand)
    }

    func testAButtonNotShowingAPointingHandLeavesTheCursorAlone() {
        let button = CursorRectSpy(frame: NSRect(x: 10, y: 20, width: 120, height: 16))
        button.showsPointingHand = false
        button.resetCursorRects()
        XCTAssertTrue(button.rects.isEmpty)
    }

    /// Whether the button shows a pointing hand or not, its window sets up its cursor rectangles again
    func testChangingThePointingHandUpdatesTheWindow() {
        // A window that isn't shown, far off the screen so that the mouse is never over it
        let window = InvalidationSpy(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                                     styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // NSWindow moves a window made off the screen onto it, so it's moved off afterwards
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        let button = IFLinkButton(frame: NSRect(x: 10, y: 20, width: 120, height: 16))
        window.contentView?.addSubview(button)

        for shows in [false, true] {
            window.views = []
            button.showsPointingHand = shows
            XCTAssertEqual(button.showsPointingHand, shows)
            XCTAssertEqual(window.views.count, 1, "\(shows)")
            XCTAssertIdentical(window.views.first, button, "\(shows)")
        }
    }
}
