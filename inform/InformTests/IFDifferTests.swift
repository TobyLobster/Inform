//
//  IFDifferTests.swift
//  InformTests
//

import XCTest

final class IFDifferTests: XCTestCase {

    /// The start of a transcript, with an old-style banner from the given serial number and Inform 6 version.
    private func transcript(serial: String, i6: String, room: String = "Bedroom") -> String {
        return "Story\nAn Interactive Fiction by Jane Doe\n"
            + "Release 1 / Serial number \(serial) / Inform 7 build 6M62 (I6/v\(i6) lib 6/12N) SD\n\n"
            + "\(room)\nIt's dark.\n\n>"
    }

    /// Banners from different builds count as the same.
    func testBannersFromDifferentBuildsMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "141106", i6: "6.33"),
                                        actual: transcript(serial: "150101", i6: "6.34")))
        XCTAssertEqual(differ.differences.count, 0)
    }

    /// The text either side of the banner is still compared.
    func testTextAroundTheBannerIsCompared() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal(transcript(serial: "141106", i6: "6.33"),
                                       actual: transcript(serial: "150101", i6: "6.34", room: "Kitchen")))
        XCTAssertTrue(differ.diffIdeal("Hello\n" + transcript(serial: "141106", i6: "6.33"),
                                       actual: "Goodbye\n" + transcript(serial: "150101", i6: "6.34")))
    }

    /// Without a banner on both sides, a different serial number is a difference.
    func testSerialNumbersDifferWithoutABanner() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal("Serial number 141106", actual: "Serial number 150101"))
    }
}
