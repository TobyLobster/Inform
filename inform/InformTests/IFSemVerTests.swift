//
//  IFSemVerTests.swift
//  InformTests
//

import XCTest

final class IFSemVerTests: XCTestCase {

    private func text(_ string: String) -> String {
        return IFSemVer(string: string).to_text
    }

    private func cmp(_ a: String, _ b: String) -> Int32 {
        return IFSemVer(string: a).cmp(IFSemVer(string: b))
    }

    // MARK: - Parsing

    func testParsesMajorMinorPatch() {
        XCTAssertEqual(text("1.2.3"), "1.2.3")
        XCTAssertEqual(text("2.0"), "2.0")
        XCTAssertEqual(text("7"), "7")
    }

    func testIgnoresVersionPrefixAndWhitespace() {
        XCTAssertEqual(text("Version 1.2.3"), "1.2.3")
        XCTAssertEqual(text("  2.0  "), "2.0")
    }

    func testParsesPrereleaseAndBuildMetadata() {
        XCTAssertEqual(text("1.2.3-alpha.1+build.5"), "1.2.3-alpha.1+build.5")
        XCTAssertEqual(text("1.0.0+20240531"), "1.0.0+20240531")
    }

    func testParsesDateStyleVersion() {
        // Old style Inform extension versions, e.g. "6/150203", read as major.0.date
        XCTAssertEqual(text("6/150203"), "6.0.150203")
        XCTAssertEqual(text("6/1502"), "null")
    }

    func testRejectsMalformedVersions() {
        XCTAssertEqual(text(""), "null")
        XCTAssertEqual(text("abc"), "null")
        XCTAssertEqual(text("01.2"), "null")
        XCTAssertEqual(text("1.2.3.4"), "null")
        XCTAssertEqual(text("1..2"), "null")
        XCTAssertEqual(text("1.2/3"), "null")
    }

    // MARK: - Comparison

    func testComparesNumerically() {
        XCTAssertEqual(cmp("1.2.3", "1.2.4"), -1)
        XCTAssertEqual(cmp("1.10", "1.9"), 1)
        XCTAssertEqual(cmp("2", "1.99.99"), 1)
    }

    func testMissingComponentsCountAsZero() {
        XCTAssertEqual(cmp("1", "1.0.0"), 0)
        XCTAssertEqual(cmp("1.0", "1.0.1"), -1)
    }

    func testBuildMetadataIsIgnored() {
        XCTAssertEqual(cmp("1.0.0+build1", "1.0.0+build2"), 0)
    }

    func testPrereleaseOrderingFollowsSemVerSpecification() {
        // The example ordering from section 11 of semver.org
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
                       "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"]
        for (i, lower) in ordered.enumerated() {
            for higher in ordered[(i + 1)...] {
                XCTAssertEqual(cmp(lower, higher), -1, "\(lower) < \(higher)")
                XCTAssertEqual(cmp(higher, lower), 1, "\(higher) > \(lower)")
            }
            XCTAssertEqual(cmp(lower, lower), 0, "\(lower) == \(lower)")
        }
    }
}
