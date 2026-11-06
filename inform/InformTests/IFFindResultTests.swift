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

    /// A result for "cat" in "the cat sat", as Find All makes one.
    private func makeResult(context: String = "the cat sat",
                            contextRange: NSRange = NSRange(location: 4, length: 3),
                            documentSortName: String? = "Source",
                            exampleName: String? = nil,
                            groups: [String]? = nil) -> IFFindResult {
        return IFFindResult(filepath: "/Source/story.ni",
                            rangeInFile: NSRange(location: 104, length: 3),
                            documentDisplayName: "Story",
                            documentSortName: documentSortName,
                            locationType: .source,
                            context: context,
                            contextRange: contextRange,
                            exampleName: exampleName,
                            exampleAnchorTag: "e1",
                            codeAnchorTag: "c2",
                            definitionAnchorTag: "d3",
                            regexFoundGroups: groups)
    }

    // MARK: - What a result keeps

    func testKeepsWhatItIsGiven() {
        let result = makeResult(exampleName: "Ballpark", groups: ["cat", "c"])
        XCTAssertEqual(result.filepath, "/Source/story.ni")
        XCTAssertEqual(result.fileRange, NSRange(location: 104, length: 3))
        XCTAssertEqual(result.documentDisplayName, "Story")
        XCTAssertEqual(result.documentSortName, "Source")
        XCTAssertEqual(result.locationType, .source)
        XCTAssertEqual(result.context, "the cat sat")
        XCTAssertEqual(result.contextRange, NSRange(location: 4, length: 3))
        XCTAssertEqual(result.exampleName, "Ballpark")
        XCTAssertEqual(result.exampleAnchorTag, "e1")
        XCTAssertEqual(result.codeAnchorTag, "c2")
        XCTAssertEqual(result.definitionAnchorTag, "d3")
        XCTAssertEqual(result.regexFoundGroups, ["cat", "c"])
    }

    /// The phrase is the part of the context that matched.
    func testThePhraseIsTheMatchInItsContext() {
        XCTAssertEqual(makeResult().phrase, "cat")
    }

    /// The Recipe Book's pages sort as "001…", and Writing with Inform's as "000…".
    func testIsInTheRecipeBookWhenItsSortNameSaysSo() {
        XCTAssertTrue(makeResult(documentSortName: "001 Recipe").recipeBookResult)
        XCTAssertFalse(makeResult(documentSortName: "000 Writing").recipeBookResult)
        XCTAssertFalse(makeResult(documentSortName: nil).recipeBookResult)
    }

    // MARK: - Expanding a replacement

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

    /// \0 is the whole match and \1 to \9 its groups.
    func testExpandsGroups() {
        XCTAssertEqual(expand(#"[\0] \2-\1"#, groups: ["cat", "c", "at"]), "[cat] at-c")
        XCTAssertEqual(expand(#"<\1>"#, groups: ["x", ""]), "<>")
    }

    /// A group the match doesn't have is left as typed.
    func testLeavesAGroupItDoesNotHave() {
        XCTAssertEqual(expand(#"\1\2"#, groups: ["cat", "c"]), #"c\2"#)
        XCTAssertEqual(expand(#"\0"#), #"\0"#)
    }

    /// The text of a group isn't expanded again.
    func testDoesNotExpandTheTextOfAGroup() {
        XCTAssertEqual(expand(#"\1!"#, groups: [#"\t\1"#, #"\t\1"#]), #"\t\1!"#)
    }

    func testExpandsTheOtherControlCharacters() {
        XCTAssertEqual(expand(#"\t\v\f"#), "\t\u{0B}\u{0C}")
    }

    /// \x and two hex digits is that character.
    func testExpandsAHexEscape() {
        XCTAssertEqual(expand(#"a\x41b\x7e"#), "aAb~")
    }

    /// \x without two hex digits is left as typed.
    func testLeavesAHexEscapeWithoutTwoHexDigits() {
        XCTAssertEqual(expand(#"\xZZ"#), #"\xZZ"#)
        XCTAssertEqual(expand(#"\x4g!"#), #"\x4g!"#)
    }

    /// \\ is a backslash, which escapes nothing.
    func testExpandsADoubleBackslash() {
        XCTAssertEqual(expand(#"a\\b"#), #"a\b"#)
        XCTAssertEqual(expand(#"\\1"#, groups: ["cat", "c"]), #"\1"#)
    }

    /// A backslash before anything else, or at the end, is left as typed.
    func testLeavesOtherBackslashes() {
        XCTAssertEqual(expand(#"\q\"#), #"\q\"#)
        XCTAssertEqual(expand(#"\x4"#), #"\x4"#)
    }

    /// A result expands a replacement with its own groups.
    func testAResultExpandsWithItsOwnGroups() {
        XCTAssertEqual(makeResult(groups: ["cat", "c"]).string(byReplacingGroups: #"\1og"#), "cog")
        XCTAssertEqual(makeResult().string(byReplacingGroups: #"\1og"#), #"\1og"#)
    }

    // MARK: - Showing a result

    private func font(of text: NSAttributedString, at index: Int) -> NSFont? {
        return text.attribute(.font, at: index, effectiveRange: nil) as? NSFont
    }

    private func colour(of text: NSAttributedString, at index: Int) -> NSColor? {
        return text.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor
    }

    private func hasTrait(_ trait: NSFontTraitMask, _ font: NSFont?) -> Bool {
        guard let font else { return false }
        return NSFontManager.shared.traits(of: font).contains(trait)
    }

    /// The context is shown with its match in bold.
    func testShowsTheContextWithTheMatchInBold() {
        let shown = makeResult().attributedContext
        XCTAssertEqual(shown.string, "the cat sat")
        XCTAssertFalse(hasTrait(.boldFontMask, font(of: shown, at: 0)))
        XCTAssertEqual(font(of: shown, at: 0)?.pointSize, 11)
        XCTAssertTrue(hasTrait(.boldFontMask, font(of: shown, at: 4)))
        XCTAssertTrue(hasTrait(.boldFontMask, font(of: shown, at: 6)))
        XCTAssertEqual(font(of: shown, at: 4)?.pointSize, 12)
        XCTAssertFalse(hasTrait(.boldFontMask, font(of: shown, at: 7)))
        XCTAssertEqual(colour(of: shown, at: 0), NSColor.textColor)
        XCTAssertEqual(colour(of: shown, at: 4), NSColor.textColor)
    }

    /// A result in an example starts with the example's name, in italics.
    func testShowsTheExample() {
        let shown = makeResult(exampleName: "Ballpark").attributedContext
        let prefix = "(Example Ballpark)  "
        XCTAssertEqual(shown.string, prefix + "the cat sat")
        XCTAssertTrue(hasTrait(.italicFontMask, font(of: shown, at: 0)))
        XCTAssertTrue(hasTrait(.italicFontMask, font(of: shown, at: prefix.count - 1)))
        XCTAssertFalse(hasTrait(.italicFontMask, font(of: shown, at: prefix.count)))
        XCTAssertTrue(hasTrait(.boldFontMask, font(of: shown, at: prefix.count + 4)))

        XCTAssertEqual(makeResult(exampleName: "").attributedContext.string, "the cat sat")
    }

    /// A result that Replace All couldn't replace is shown in red.
    func testShowsAnErrorInRed() {
        let result = makeResult(exampleName: "Ballpark")
        result.setError(true)
        let shown = result.attributedContext
        XCTAssertEqual(colour(of: shown, at: 0), NSColor.systemRed)
        XCTAssertEqual(colour(of: shown, at: shown.length - 1), NSColor.systemRed)

        result.setError(false)
        XCTAssertEqual(colour(of: result.attributedContext, at: 0), NSColor.textColor)
    }
}
