//
//  IFExtensionInfoTests.swift
//  InformTests
//

import XCTest

final class IFExtensionInfoTests: XCTestCase {
    private func info(_ displayName: String = "Locksmith",
                      filepath: String? = "/Extensions/Emily Short/Locksmith.i7x",
                      author: String = "Emily Short",
                      version: String? = "v12",
                      isBuiltIn: Bool = false) -> IFExtensionInfo {
        return IFExtensionInfo(displayName: displayName, filepath: filepath, author: author,
                               version: version, isBuiltIn: isBuiltIn)
    }

    /// Compares two infos as sorting does (caseInsensitiveCompare: isn't in the header, as only sorting uses it)
    private func compare(_ a: IFExtensionInfo, _ b: IFExtensionInfo) -> ComparisonResult {
        typealias Compare = @convention(c) (AnyObject, Selector, AnyObject) -> Int
        let selector = NSSelectorFromString("caseInsensitiveCompare:")
        let compare = unsafeBitCast(a.method(for: selector), to: Compare.self)
        return ComparisonResult(rawValue: compare(a, selector, b))!
    }

    func testAnInfoKeepsWhatItsGiven() {
        let locksmith = info(isBuiltIn: true)

        XCTAssertEqual(locksmith.displayName, "Locksmith")
        XCTAssertEqual(locksmith.filepath, "/Extensions/Emily Short/Locksmith.i7x")
        XCTAssertEqual(locksmith.author, "Emily Short")
        XCTAssertEqual(locksmith.version, "v12")
        XCTAssertTrue(locksmith.isBuiltIn)
    }

    func testCanonicalTitles() {
        let titles = [
            "Locksmith": "Locksmith",
            "The Locksmith": "Locksmith",
            "the locksmith": "locksmith",
            "A Locksmith": "Locksmith",
            "An Old Locksmith": "Old Locksmith",
            "Theatre": "Theatre",
            "Another": "Another",
            "Locksmith (for Glulx only)": "Locksmith",
            "The Locksmith (for Glulx only)": "Locksmith",
            "Locksmith (old) (new)": "Locksmith",
            "Locksmith(for Glulx only)": "Locksmith(for Glulx only)",
            "Locksmith (old) and new": "Locksmith (old) and new",
            "Lo (x)": "Lo",
            // A bracket straight after the first letter is kept
            "L (x)": "L (x)",
        ]

        for (title, canonical) in titles {
            XCTAssertEqual(IFExtensionInfo.canonicalTitle(title), canonical, title)
        }
    }

    func testVersions() {
        XCTAssertEqual(info(version: "v12").safeVersion, "v12")
        XCTAssertEqual(info(version: "").safeVersion, "")
        XCTAssertEqual(info(version: nil).safeVersion, "Version (none)")

        XCTAssertEqual(info(version: "12.1.0").semver.to_text, IFSemVer(string: "12.1.0").to_text)
        XCTAssertEqual(info(version: "v12").semver.to_text, IFSemVer(string: "v12").to_text)
        XCTAssertEqual(info(version: nil).semver.to_text, IFSemVer().to_text)
    }

    func testOrder() {
        // By name, ignoring case
        XCTAssertEqual(compare(info("apple"), info("Banana")), .orderedAscending)
        XCTAssertEqual(compare(info("Banana"), info("apple")), .orderedDescending)

        // Then by author, ignoring case
        XCTAssertEqual(compare(info("Locksmith", author: "Anon"), info("LOCKSMITH", author: "emily Short")),
                       .orderedAscending)

        // Then by file, minding case
        XCTAssertEqual(compare(info(filepath: "/b"), info(filepath: "/a", author: "EMILY SHORT")), .orderedDescending)
        XCTAssertEqual(compare(info(filepath: "/a"), info(filepath: "/B")), .orderedDescending)
        XCTAssertEqual(compare(info(), info(version: "v1", isBuiltIn: true)), .orderedSame)
    }

    func testEquality() {
        XCTAssertTrue(info().isEqual(info()))
        XCTAssertTrue(info(filepath: nil, version: nil).isEqual(info(filepath: nil, version: nil)))

        XCTAssertFalse(info().isEqual(info("Keys")))
        XCTAssertFalse(info().isEqual(info(filepath: "/Extensions/Locksmith.i7x")))
        XCTAssertFalse(info().isEqual(info(filepath: nil)))
        XCTAssertFalse(info(filepath: nil).isEqual(info()))
        XCTAssertFalse(info().isEqual(info(author: "emily short")))
        XCTAssertFalse(info().isEqual(info(version: "v13")))
        XCTAssertFalse(info().isEqual(info(version: nil)))
        XCTAssertFalse(info().isEqual(info(isBuiltIn: true)))

        XCTAssertFalse(info().isEqual(nil))
        XCTAssertFalse(info().isEqual("Locksmith"))
    }
}
