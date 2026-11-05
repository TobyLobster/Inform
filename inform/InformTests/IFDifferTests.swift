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

    /// The start of a transcript with the banner Inform 10 prints, as in "Inform 7 v10.2.0 / D".
    private func transcript(serial: String, version: String, room: String = "Bedroom") -> String {
        return "Story\nAn Interactive Fiction by Jane Doe\n"
            + "Release 1 / Serial number \(serial) / Inform 7 v\(version) / D\n\n"
            + "\(room)\nIt's dark.\n\n>"
    }

    /// Inform 10's banners from different days and builds count as the same.
    func testInform10BannersFromDifferentBuildsMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "261104", version: "10.2.0"),
                                        actual: transcript(serial: "261105", version: "10.2.0")))
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "221105", version: "10.1.2"),
                                        actual: transcript(serial: "261105", version: "10.2.0-beta+6Y13")))
        XCTAssertTrue(differ.diffIdeal(transcript(serial: "261104", version: "10.2.0"),
                                       actual: transcript(serial: "261105", version: "10.2.0", room: "Kitchen")))
    }

    /// A transcript blessed with an older Inform still matches one from Inform 10.
    func testOldAndInform10BannersMatch() {
        let differ = IFDiffer()
        XCTAssertFalse(differ.diffIdeal(transcript(serial: "151220", i6: "6.33"),
                                        actual: transcript(serial: "261104", version: "10.2.0")))
    }

    /// Without a banner on both sides, a different serial number is a difference.
    func testSerialNumbersDifferWithoutABanner() {
        let differ = IFDiffer()
        XCTAssertTrue(differ.diffIdeal("Serial number 141106", actual: "Serial number 150101"))
    }
}
