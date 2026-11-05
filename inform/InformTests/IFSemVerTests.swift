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

    func testANewVersionIsNull() {
        XCTAssertEqual(IFSemVer().to_text, "null")
    }

    func testParsesMajorMinorPatch() {
        XCTAssertEqual(text("1.2.3"), "1.2.3")
        XCTAssertEqual(text("2.0"), "2.0")
        XCTAssertEqual(text("7"), "7")
    }

    func testIgnoresVersionPrefixAndWhitespace() {
        XCTAssertEqual(text("Version 1.2.3"), "1.2.3")
        XCTAssertEqual(text("version 1.2"), "1.2")
        XCTAssertEqual(text("  2.0  "), "2.0")
    }

    func testParsesPrereleaseAndBuildMetadata() {
        XCTAssertEqual(text("1.2.3-alpha.1+build.5"), "1.2.3-alpha.1+build.5")
        XCTAssertEqual(text("1.0.0+20240531"), "1.0.0+20240531")
    }

    /// A prerelease can follow any number, and keeps any later hyphens. The build is everything after the first +.
    func testParsesPrereleaseAndBuildText() {
        XCTAssertEqual(text("1-beta"), "1-beta")
        XCTAssertEqual(text("1.0.0-alpha-1.2"), "1.0.0-alpha-1.2")
        XCTAssertEqual(text("1.0+a+b"), "1.0+a+b")
        XCTAssertEqual(text("1.0-é😀+😀"), "1.0-é😀+😀")
    }

    /// An empty prerelease segment makes the version null, but an empty one at the end is dropped, as is an empty build.
    func testEmptyPrereleaseSegments() {
        XCTAssertEqual(text("1.0.0-alpha..1"), "null")
        XCTAssertEqual(text("1.0.0-alpha."), "1.0.0-alpha")
        XCTAssertEqual(text("1.0.0-"), "1.0.0")
        XCTAssertEqual(text("1.0.0-alpha+"), "1.0.0-alpha")
    }

    func testParsesDateStyleVersion() {
        // Old style Inform extension versions, e.g. "6/150203", read as major.0.date
        XCTAssertEqual(text("6/150203"), "6.0.150203")
        XCTAssertEqual(text("6/1502"), "null")
        // The date can start with a zero, but the major version can't
        XCTAssertEqual(text("6/050203"), "6.0.50203")
        XCTAssertEqual(text("06/150203"), "null")
    }

    /// A number too long for an int isn't meaningful, but it mustn't stop the version being read.
    func testOverlongNumbers() {
        XCTAssertTrue(text("1.2.99999999999").hasPrefix("1.2."))
        XCTAssertEqual(cmp("1.0.0-99999999999", "1.0.0-1"), 1)
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

    /// A null version compares as 0.0.0.
    func testNullComparesAsZero() {
        XCTAssertEqual(cmp("", "0"), 0)
        XCTAssertEqual(cmp("abc", "0.0.1"), -1)
        XCTAssertEqual(IFSemVer().cmp(IFSemVer(string: "1")), -1)
    }

    /// Numeric prerelease segments compare as numbers, unless they start with a zero.
    func testNumericPrereleaseSegments() {
        XCTAssertEqual(cmp("1.0.0-9", "1.0.0-10"), -1)
        XCTAssertEqual(cmp("1.0.0-011", "1.0.0-9"), -1)
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

    // MARK: - The extensions manager's checks

    /// These were checked by the extensions manager each time it started, in Debug
    func testTheExtensionsManagersVersions() {
        let versions = [
            "1+lobster":               "1+lobster",
            "1":                       "1",
            "1.2":                     "1.2",
            "1.2.3":                   "1.2.3",
            "71.0.45672":              "71.0.45672",
            "1.2.3.4":                 "null",
            "9/861022":                "9.0.861022",
            "9/86102":                 "null",
            "9/8610223":               "null",
            "9/861022.2":              "null",
            "9/861022/2":              "null",
            "1.2.3-alpha.0.x45.1789":  "1.2.3-alpha.0.x45.1789",
            "1.2+lobster":             "1.2+lobster",
            "1.2.3+lobster":           "1.2.3+lobster",
            "1.2.3-beta.2+shellfish":  "1.2.3-beta.2+shellfish",
        ]
        for (string, expected) in versions {
            XCTAssertEqual(text(string), expected, string)
        }
    }

    func testTheExtensionsManagersComparisons() {
        let comparisons: [(String, String, String)] = [
            ("3",                "<", "5"),
            ("3",                "=", "3"),
            ("3",                "=", "3.0"),
            ("3",                "=", "3.0.0"),
            ("3.1.41",           ">", "3.1.5"),
            ("3.1.41",           "<", "3.2.5"),
            ("3.1.41",           "=", "3.1.41+arm64"),
            ("3.1.41",           ">", "3.1.41-pre.0.1"),
            ("3.1.41-alpha.72",  ">", "3.1.41-alpha.8"),
            ("3.1.41-alpha.72a", "<", "3.1.41-alpha.8a"),
            ("3.1.41-alpha.72",  "<", "3.1.41-beta.72"),
            ("3.1.41-alpha.72",  "<", "3.1.41-alpha.72.zeta"),
            ("1.2.3+lobster.54", "=", "1.2.3+lobster.100"),
        ]
        let results = ["<": -1, "=": 0, ">": 1]
        for (a, op, b) in comparisons {
            XCTAssertEqual(cmp(a, b), Int32(results[op]!), "\(a) \(op) \(b)")
        }
    }
}
