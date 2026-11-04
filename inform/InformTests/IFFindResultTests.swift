//
//  IFFindResultTests.swift
//  InformTests
//

import XCTest

final class IFFindResultTests: XCTestCase {

    /// Expands the escapes in a regular expression's replacement, as Replace does.
    private func expand(_ replacement: String, groups: [String] = []) -> String {
        return IFFindResult.string(byReplacingGroups: replacement, regexFoundGroups: groups)
    }

    /// \n is a newline and \r a return, as in the regular expression.
    func testExpandsNewlineAndReturnEscapes() {
        XCTAssertEqual(expand(#"a\nb\rc"#), "a\nb\rc")
    }

    /// Each escape is expanded, however many come together.
    func testExpandsEscapesThatFollowEachOther() {
        XCTAssertEqual(expand(#"\t\t"#), "\t\t")
        XCTAssertEqual(expand(#"\x41\x42"#), "AB")
        XCTAssertEqual(expand(#"\1\t\2"#, groups: ["a-b", "a", "b"]), "a\tb")
    }
}
