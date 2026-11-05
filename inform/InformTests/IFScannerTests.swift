//
//  IFScannerTests.swift
//  InformTests
//

import XCTest

final class IFScannerTests: XCTestCase {

    private let notFound = NSRange(location: NSNotFound, length: 0)

    private func regexp(caseInsensitive: Bool = false) -> IFFindType {
        let flags = IFFindType.regexp.rawValue | (caseInsensitive ? IFFindType.caseInsensitive.rawValue : 0)
        return IFFindType(rawValue: flags)!
    }

    private func next(_ pattern: String, in text: String, from position: Int = 0,
                      caseInsensitive: Bool = false) -> NSRange {
        return IFScanner.findNextMatch(pattern, storage: text, position: UInt(position),
                                       options: regexp(caseInsensitive: caseInsensitive), regexFoundGroups: nil)
    }

    /// Finds the next match and the groups it captured.
    private func nextWithGroups(_ pattern: String, in text: String) -> (NSRange, [String]?) {
        var groups: NSArray? = nil
        let range = IFScanner.findNextMatch(pattern, storage: text, position: 0,
                                            options: regexp(), regexFoundGroups: &groups)
        return (range, groups as? [String])
    }

    private func previous(_ pattern: String, in text: String, from position: Int) -> NSRange {
        return IFScanner.findPreviousMatch(pattern, storage: text, position: UInt(position),
                                           options: regexp(), regexFoundGroups: nil)
    }

    /// Find Next finds the first match at or after the position.
    func testFindsTheNextMatch() {
        XCTAssertEqual(next(#"t\w+"#, in: "one two three two"), NSRange(location: 4, length: 3))
        XCTAssertEqual(next(#"t\w+"#, in: "one two three two", from: 5), NSRange(location: 8, length: 5))
        XCTAssertEqual(next(#"z\w+"#, in: "one two three two"), notFound)
    }

    /// Find Previous finds the last match that starts at or before the position.
    func testFindsThePreviousMatch() {
        XCTAssertEqual(previous(#"t\w+"#, in: "one two three two", from: 10), NSRange(location: 8, length: 5))
        XCTAssertEqual(previous(#"t\w+"#, in: "one two three two", from: 3), notFound)
    }

    /// The groups are the whole match then each group, with an empty string for a group that took no part.
    func testGivesTheGroups() {
        let (range, groups) = nextWithGroups("(a)(x)?(b)", in: "zab")
        XCTAssertEqual(range, NSRange(location: 1, length: 2))
        XCTAssertEqual(groups, ["ab", "a", "", "b"])
    }

    func testIgnoresCaseOnlyWhenAsked() {
        XCTAssertEqual(next("TWO", in: "one two", caseInsensitive: true), NSRange(location: 4, length: 3))
        XCTAssertEqual(next("TWO", in: "one two"), notFound)
    }

    /// A pattern that isn't a regular expression finds nothing, and gives no groups.
    func testInvalidPatternFindsNothing() {
        let (range, groups) = nextWithGroups("(", in: "a(b")
        XCTAssertEqual(range, notFound)
        XCTAssertNil(groups)
        XCTAssertEqual(next("a{2,1}", in: "aaa"), notFound)
    }

    /// Matches of no characters are passed over.
    func testSkipsEmptyMatches() {
        XCTAssertEqual(next("x*", in: "abxc"), NSRange(location: 2, length: 1))
    }

    /// ^ and $ match at the start and end of each line, as the Find window's help says, and not wherever
    /// the search starts.
    func testCaretAndDollarMatchAtLineStartsAndEnds() {
        XCTAssertEqual(next("^two", in: "one\ntwo"), NSRange(location: 4, length: 3))
        XCTAssertEqual(next("^two", in: "one\r\ntwo"), NSRange(location: 5, length: 3))
        XCTAssertEqual(next("one$", in: "one\ntwo"), NSRange(location: 0, length: 3))
        XCTAssertEqual(next("two$", in: "one two"), NSRange(location: 4, length: 3))
        XCTAssertEqual(next("^two", in: "one two", from: 4), notFound)
        XCTAssertEqual(previous(#"^t\w+"#, in: "two\nthree four", from: 10), NSRange(location: 4, length: 5))
    }

    /// A lookbehind sees the text before the search position. Find All and Find Previous search again from
    /// just after each match's start, so otherwise they found the second "a" in "aa" for (?<!a)a.
    func testLookbehindSeesTextBeforeTheSearchPosition() {
        XCTAssertEqual(next("(?<!a)a", in: "aa", from: 1), notFound)
        XCTAssertEqual(previous("(?<!a)a", in: "aa", from: 1), NSRange(location: 0, length: 1))
        XCTAssertEqual(next("(?<=a)b", in: "ab", from: 1), NSRange(location: 1, length: 1))
    }

    /// \b sees the text before the search position too, so Find All, which searches again from just after
    /// the start of each match, doesn't find a word boundary inside a word.
    func testWordBoundarySeesTextBeforeTheSearchPosition() {
        XCTAssertEqual(next(#"\bfoo"#, in: "xfoo", from: 1), notFound)
        XCTAssertEqual(next(#"\b\w"#, in: "ab cd", from: 1), NSRange(location: 3, length: 1))
        XCTAssertEqual(next(#"\Bb"#, in: "ab", from: 1), NSRange(location: 1, length: 1))
    }

    /// Characters outside the Basic Multilingual Plane are found at their UTF-16 positions.
    func testFindsCharactersOutsideTheBasicPlane() {
        XCTAssertEqual(next("\u{1F600}(.)", in: "x\u{1F600}yz"), NSRange(location: 1, length: 3))
    }
}
