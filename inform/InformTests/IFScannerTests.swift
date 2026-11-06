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

    /// Nothing found gives no groups, though matches of no characters were passed over on the way.
    func testFindingNothingGivesNoGroups() {
        let (range, groups) = nextWithGroups("x*", in: "ab")
        XCTAssertEqual(range, notFound)
        XCTAssertNil(groups)
    }

    /// Find Previous gives the groups of the match it found, and none when it finds nothing.
    func testFindPreviousGivesTheGroupsOfItsMatch() {
        var groups: NSArray? = nil
        let range = IFScanner.findPreviousMatch(#"(a)(\d)"#, storage: "a1 a2 a3", position: 4,
                                                options: regexp(), regexFoundGroups: &groups)
        XCTAssertEqual(range, NSRange(location: 3, length: 2))
        XCTAssertEqual(groups as? [String], ["a2", "a", "2"])

        let none = IFScanner.findPreviousMatch("(b)", storage: "ab", position: 0,
                                               options: regexp(), regexFoundGroups: &groups)
        XCTAssertEqual(none, notFound)
        XCTAssertNil(groups)
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

    // MARK: - Searches that aren't regular expressions

    private func options(_ type: IFFindType, caseInsensitive: Bool) -> IFFindType {
        let flags = type.rawValue | (caseInsensitive ? IFFindType.caseInsensitive.rawValue : 0)
        return IFFindType(rawValue: flags)!
    }

    private func find(_ phrase: String, in text: String, type: IFFindType = .contains,
                      from position: Int = 0, caseInsensitive: Bool = false) -> NSRange {
        return IFScanner.findNextMatch(phrase, storage: text, position: UInt(position),
                                       options: options(type, caseInsensitive: caseInsensitive),
                                       regexFoundGroups: nil)
    }

    private func findPrevious(_ phrase: String, in text: String, type: IFFindType = .contains,
                              from position: Int) -> NSRange {
        return IFScanner.findPreviousMatch(phrase, storage: text, position: UInt(position),
                                           options: options(type, caseInsensitive: false),
                                           regexFoundGroups: nil)
    }

    /// Contains finds the phrase as typed, not as a regular expression, at or after the position.
    func testContainsFindsThePhraseAsTyped() {
        XCTAssertEqual(find("a.c", in: "abc a.c"), NSRange(location: 4, length: 3))
        XCTAssertEqual(find("b", in: "abcb", from: 1), NSRange(location: 1, length: 1))
        XCTAssertEqual(find("b", in: "abcb", from: 2), NSRange(location: 3, length: 1))
        XCTAssertEqual(find("aa", in: "aaa", from: 1), NSRange(location: 1, length: 2))
        XCTAssertEqual(find("z", in: "abc"), notFound)
    }

    func testContainsIgnoresCaseOnlyWhenAsked() {
        XCTAssertEqual(find("ABC", in: "xabc"), notFound)
        XCTAssertEqual(find("ABC", in: "xabc", caseInsensitive: true), NSRange(location: 1, length: 3))
    }

    /// Begins With only finds the phrase at the start of a word.
    func testBeginsWithFindsTheStartOfAWord() {
        XCTAssertEqual(find("cat", in: "concat catalogue", type: .beginsWith), NSRange(location: 7, length: 3))
        XCTAssertEqual(find("cat", in: "cat", type: .beginsWith), NSRange(location: 0, length: 3))
        XCTAssertEqual(find("cat", in: "x-cat", type: .beginsWith), NSRange(location: 2, length: 3))
        XCTAssertEqual(find("cat", in: "concat 2cat", type: .beginsWith), notFound)
        XCTAssertEqual(find("CAT", in: "a cat", type: .beginsWith, caseInsensitive: true),
                       NSRange(location: 2, length: 3))
    }

    /// Complete Word only finds the phrase as a whole word, with letters and digits counting as part of one.
    func testCompleteWordFindsAWholeWord() {
        XCTAssertEqual(find("cat", in: "catalogue concat cat.", type: .completeWord), NSRange(location: 17, length: 3))
        XCTAssertEqual(find("cat", in: "a cat", type: .completeWord), NSRange(location: 2, length: 3))
        XCTAssertEqual(find("cat", in: "cat1 2cat cat", type: .completeWord), NSRange(location: 10, length: 3))
        XCTAssertEqual(find("cat", in: "cats", type: .completeWord), notFound)
    }

    /// Letters that aren't ASCII, and accents on their own, are part of a word too.
    func testWordsCanHaveLettersThatAreNotASCII() {
        XCTAssertEqual(find("caf", in: "caf\u{E9}", type: .completeWord), notFound)
        XCTAssertEqual(find("cafe", in: "cafe\u{301}", type: .completeWord), notFound)
        XCTAssertEqual(find("t", in: "\u{E9}t\u{E9}", type: .beginsWith), notFound)
        XCTAssertEqual(find("\u{3B2}", in: "\u{3B1}\u{3B2} \u{3B2}", type: .beginsWith), NSRange(location: 3, length: 1))
        XCTAssertEqual(find("\u{E9}t\u{E9}", in: "un \u{E9}t\u{E9}.", type: .completeWord), NSRange(location: 3, length: 3))
    }

    /// Nothing is found from the end of the text or past it, nor for an empty phrase.
    func testFindsNothingFromTheEnd() {
        XCTAssertEqual(find("c", in: "abc", from: 2), NSRange(location: 2, length: 1))
        XCTAssertEqual(find("c", in: "abc", from: 3), notFound)
        XCTAssertEqual(find("c", in: "abc", from: 4), notFound)
        XCTAssertEqual(find("", in: "abc"), notFound)
    }

    /// Find Previous finds a match that starts at the position, or before it.
    func testFindPreviousFindsAMatchStartingAtOrBeforeThePosition() {
        XCTAssertEqual(findPrevious("ab", in: "ab ab", from: 3), NSRange(location: 3, length: 2))
        XCTAssertEqual(findPrevious("ab", in: "ab ab", from: 2), NSRange(location: 0, length: 2))
        XCTAssertEqual(findPrevious("cat", in: "concat cat", type: .completeWord, from: 7), NSRange(location: 7, length: 3))
        XCTAssertEqual(findPrevious("cat", in: "concat cat", type: .completeWord, from: 6), notFound)
    }

    /// Only a regular expression gives groups.
    func testOnlyARegularExpressionGivesGroups() {
        var groups: NSArray? = ["left over"]
        let range = IFScanner.findNextMatch("b", storage: "abc", position: 0,
                                            options: .contains, regexFoundGroups: &groups)
        XCTAssertEqual(range, NSRange(location: 1, length: 1))
        XCTAssertNil(groups)
    }
}
