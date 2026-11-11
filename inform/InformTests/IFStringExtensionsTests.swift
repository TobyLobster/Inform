//
//  IFStringExtensionsTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFStringExtensionsTests: XCTestCase {

    /// An empty string is never found, as with NSString's own searches.
    func testContainsSubstring() {
        XCTAssertTrue(("abc" as NSString).containsSubstring("b"))
        XCTAssertFalse(("abc" as NSString).containsSubstring("B"))
        XCTAssertTrue(("abc" as NSString).containsSubstring("B", options: .caseInsensitive))
        XCTAssertFalse(("abc" as NSString).containsSubstring("x"))
        XCTAssertFalse(("abc" as NSString).containsSubstring(""))
    }

    /// An empty prefix or suffix doesn't count, as with -[NSString hasPrefix:].
    func testStartsAndEndsWith() {
        XCTAssertTrue(("Inform" as NSString).starts(with: "Inf"))
        XCTAssertFalse(("Inform" as NSString).starts(with: "inf"))
        XCTAssertFalse(("Inform" as NSString).starts(with: ""))
        XCTAssertTrue(("Inform" as NSString).ends(with: "orm"))
        XCTAssertFalse(("Inform" as NSString).ends(with: "ORM"))
        XCTAssertFalse(("Inform" as NSString).ends(with: ""))
        XCTAssertFalse(("In" as NSString).ends(with: "Inform"))
    }

    func testStartsAndEndsWithIgnoringCase() {
        XCTAssertTrue(("Story.HTML" as NSString).ends(withCaseInsensitive: ".html"))
        XCTAssertFalse(("Story.HTML" as NSString).ends(withCaseInsensitive: ".htm"))
        XCTAssertTrue(("Version 2" as NSString).starts(withCaseInsensitive: "VERSION"))
        XCTAssertFalse(("Version 2" as NSString).starts(withCaseInsensitive: "Vers1"))
        XCTAssertFalse(("Version 2" as NSString).starts(withCaseInsensitive: ""))
    }

    func testIsEqualIgnoringCase() {
        XCTAssertTrue(("Inform" as NSString).isEqual(toStringCaseInsensitive: "INFORM"))
        XCTAssertFalse(("Inform" as NSString).isEqual(toStringCaseInsensitive: "Informs"))
        XCTAssertTrue(("" as NSString).isEqual(toStringCaseInsensitive: ""))
    }

    /// Whitespace includes line breaks and non-breaking spaces.
    func testTrimsWhitespace() {
        XCTAssertEqual(("  a b \n" as NSString).trimmingWhitespace, "a b")
        XCTAssertEqual(("\u{00A0}a\t" as NSString).trimmingWhitespace, "a")
        XCTAssertEqual((" \n " as NSString).trimmingWhitespace, "")
    }

    /// A string that's all whitespace is all leading and all trailing whitespace.
    func testLeadingAndTrailingWhitespace() {
        XCTAssertEqual(("ab \n" as NSString).trailingWhitespace, " \n")
        XCTAssertEqual(("ab" as NSString).trailingWhitespace, "")
        XCTAssertEqual(("  " as NSString).trailingWhitespace, "  ")
        XCTAssertEqual(("" as NSString).trailingWhitespace, "")
        XCTAssertEqual((" \nab " as NSString).leadingWhitespace, " \n")
        XCTAssertEqual(("ab" as NSString).leadingWhitespace, "")
        XCTAssertEqual(("  " as NSString).leadingWhitespace, "  ")
        XCTAssertEqual(("" as NSString).leadingWhitespace, "")
    }

    func testRemovesLeadingAndTrailingWhitespace() {
        XCTAssertEqual((" a b \n" as NSString).removingTrailingWhitespace, " a b")
        XCTAssertEqual(("  " as NSString).removingTrailingWhitespace, "")
        XCTAssertEqual(("\n a b " as NSString).removingLeadingWhitespace, "a b ")
        XCTAssertEqual(("  " as NSString).removingLeadingWhitespace, "")
        XCTAssertEqual(("\u{1F600} " as NSString).removingTrailingWhitespace, "\u{1F600}")
    }

    func testTrimsTheGivenCharacters() {
        XCTAssertEqual(("-=a-b=-" as NSString).trimmingCharacters(in: "-="), "a-b")
        XCTAssertEqual(("-=a-b=-" as NSString).trimmingCharacters(in: ""), "-=a-b=-")
    }

    func testReplaces() {
        XCTAssertEqual(("banana" as NSString).replacing("a", with: "o"), "bonono")
        XCTAssertEqual(("banana" as NSString).replacing("A", with: "o"), "banana")
        XCTAssertEqual(("banana" as NSString).replacing("an", with: ""), "ba")
    }

    /// Positions are in UTF-16 units, and a string that isn't there, or is empty, is NSNotFound.
    func testIndexOf() {
        XCTAssertEqual(("abcabc" as NSString).index(of: "c"), 2)
        XCTAssertEqual(("abcabc" as NSString).lastIndex(of: "c"), 5)
        XCTAssertEqual(("\u{1F600}c" as NSString).index(of: "c"), 2)
        XCTAssertEqual(("abc" as NSString).index(of: "x"), NSNotFound)
        XCTAssertEqual(("abc" as NSString).lastIndex(of: "x"), NSNotFound)
        XCTAssertEqual(("abc" as NSString).index(of: ""), NSNotFound)
        XCTAssertEqual(("abc" as NSString).lastIndex(of: ""), NSNotFound)
    }

    /// Each part of a relative path is appended as a path component.
    func testAppendsPathComponents() {
        XCTAssertEqual(("/a" as NSString).appendingPathComponents("b/c"), "/a/b/c")
        XCTAssertEqual(("/a" as NSString).appendingPathComponents("b/"), "/a/b")
        XCTAssertEqual(("/a/" as NSString).appendingPathComponents("b"), "/a/b")
        XCTAssertEqual(("/a" as NSString).appendingPathComponents(nil), "/a")
    }

    // MARK: - The Quick Look plugin

    /// The Quick Look plugin compiles the preferences, which compare theme names with the category as they make
    /// their styles, so it has the category too. The plugin's binary is read, not loaded, as it has its own copies
    /// of the app's classes; the category's name is only in a binary that has the category.
    func testTheQuickLookPluginHasTheCategory() throws {
        let pluginURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/QuickLook/InformQL.qlgenerator")
        let plugin = try XCTUnwrap(Bundle(url: pluginURL))
        let binary = try Data(contentsOf: try XCTUnwrap(plugin.executableURL))
        XCTAssertNotNil(binary.range(of: Data("IFPreferences".utf8)), "The plugin has the preferences")
        XCTAssertNotNil(binary.range(of: Data("IFStringAdditions".utf8)), "The plugin has the category")
    }
}
