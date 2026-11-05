//
//  IFBundleExtensionsTests.swift
//  InformTests
//

import XCTest

final class IFBundleExtensionsTests: XCTestCase {

    /// A page loads its nib with itself as the owner, which connects its view.
    func testLoadsANibForItsOwner() {
        let page: IFGamePage = IFGamePage(projectController: nil)
        XCTAssertNotNil(page.view as NSView?)
    }

    func testDoesNotLoadAMissingNib() {
        XCTAssertFalse(Bundle.customLoadNib("NoSuchNib", owner: nil))
    }
}
