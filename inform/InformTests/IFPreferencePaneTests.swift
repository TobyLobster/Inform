//
//  IFPreferencePaneTests.swift
//  InformTests
//

import XCTest

/// A pane of the tests' own, for the Author pane's nib: a pane owns its nib, and loading that nib needs the
/// outlet it connects
final class IFPreferencePaneTestsPane: IFPreferencePane {
    @IBOutlet var newGameName: NSTextField?
}

/// A pane that gives a largest height of its own
final class IFPreferencePaneTestsTallPane: IFPreferencePane {
    override var maxHeight: CGFloat {
        return 321
    }
}

final class IFPreferencePaneTests: XCTestCase {
    func testAPaneWithNoNibHasNoViewAndNoHeight() {
        let pane = IFPreferencePane()
        XCTAssertNil(pane.preferenceView)
        XCTAssertEqual(pane.maxHeight, 0)
        XCTAssertEqual(pane.minHeight, 0)
    }

    func testAPaneHasNoNameImageOrTooltipOfItsOwn() {
        let pane = IFPreferencePane()
        XCTAssertEqual(pane.preferenceName, "Unnamed preference")
        XCTAssertNil(pane.toolbarImage)
        XCTAssertNil(pane.tooltip)
    }

    func testAPaneIsIdentifiedByItsClassName() {
        XCTAssertEqual(IFPreferencePane().identifier.rawValue, "IFPreferencePane")
        XCTAssertEqual(IFPreferencePaneTestsPane().identifier.rawValue, "InformTests.IFPreferencePaneTestsPane")
    }

    func testAPaneWithANibHasTheNibsViewAndItsHeight() throws {
        let pane = IFPreferencePaneTestsPane(nibName: "AuthorPreferences")
        let view = try XCTUnwrap(pane.preferenceView)
        XCTAssertNotNil(pane.newGameName)
        XCTAssertGreaterThan(view.frame.height, 0)
        XCTAssertEqual(pane.maxHeight, view.frame.height)
        XCTAssertEqual(pane.minHeight, view.frame.height)
    }

    func testThePanesHeightIsItsViewsHeight() {
        let pane = IFPreferencePane()
        pane.preferenceView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 123))
        XCTAssertEqual(pane.maxHeight, 123)
        XCTAssertEqual(pane.minHeight, 123)

        pane.preferenceView = nil
        XCTAssertEqual(pane.maxHeight, 0)
        XCTAssertEqual(pane.minHeight, 0)
    }

    func testTheSmallestHeightIsTheLargestASubclassGives() {
        XCTAssertEqual(IFPreferencePaneTestsTallPane().minHeight, 321)
    }
}
