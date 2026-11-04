//
//  IFPreferencesTests.swift
//  InformTests
//

import XCTest

final class IFPreferencesTests: XCTestCase {

    /// The Editing preferences' tab stop slider sets fractional widths, and the source view
    /// uses the width it reads back.
    func testReadsAFractionalTabWidthBack() {
        // A new object, not the shared one, in a batch that's never ended, so the change
        // stays in memory and isn't written to the user defaults.
        let prefs = IFPreferences()
        prefs.startBatchEditing()

        prefs.tabWidth = 30.5

        XCTAssertEqual(prefs.tabWidth, 30.5)
    }
}
