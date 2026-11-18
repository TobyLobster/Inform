//
//  IFRecolouringTests.swift
//  InformTests
//

import XCTest

/// Highlighting a source again after an edit that changes how the rest of it is coloured, as typing a "[" at its start
/// makes all of it a comment
@MainActor
final class IFRecolouringTests: XCTestCase {

    /// Source with each kind of highlighting: a title, headings, comments over more than one line, text with
    /// substitutions, Inform 6 code, a table, and letters that the source font may not have
    private let piece = """
        "Recolouring" by Tester

        Volume 1 - Things

        Book: The Kitchen

        [A comment, [nested], over
        two lines.]

        Part 2 - The Hall

        The Kitchen is a room. "A [bold type]warm[roman type] kitchen, with “curly” quotes."

        Chapter Two - Meals

        Instead of eating:
        \tsay "Crème brûlée, καλημέρα, 日本語 and 🍰."

        Section 3 - Inform 6

        Include (-
        [ Hello x; print "Hello", (name) x; ! A comment
        \tif (x has light) rtrue;
        ];
        -).

        To decide what number is the score: (- (score + 1) -).

        Table of Fruit
        name\tcolour\tprice
        apple\tred\t3
        banana\tyellow\t4

        Example: * Fruit - A bowl of it.

        """

    /// A source of a few hundred lines
    private var source: String {
        return String(repeating: piece, count: 12)
    }

    /// A text storage highlighted as a project's source is, unregistered at the end of the test.
    private func registered(_ text: String) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "story.ni", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: nil)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }
        return storage
    }

    /// Checks that the storage is highlighted as the same text is when it's first registered: each character has the
    /// same style and attributes.
    private func assertHighlightedAsIfOpened(_ storage: NSTextStorage, _ message: String,
                                             file: StaticString = #filePath, line: UInt = #line) throws {
        let opened = registered(storage.string)
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage), file: file, line: line)
        let openedData = try XCTUnwrap(IFSyntaxManager.data(for: opened), file: file, line: line)

        let styles = (0..<storage.length).map { data.style(at: UInt($0)) }
        let openedStyles = (0..<opened.length).map { openedData.style(at: UInt($0)) }
        if let index = styles.indices.first(where: { styles[$0] != openedStyles[$0] }) {
            XCTFail("\(message): the style of character \(index) is \(styles[index].rawValue), "
                    + "not \(openedStyles[index].rawValue)", file: file, line: line)
        }

        if !storage.isEqual(to: opened) {
            let index = (0..<storage.length).first { index in
                let attributes = storage.attributes(at: index, effectiveRange: nil) as NSDictionary
                return !attributes.isEqual(to: opened.attributes(at: index, effectiveRange: nil))
            }
            XCTFail("\(message): the attributes of character \(index ?? -1) differ", file: file, line: line)
        }
    }

    /// Checks that each character has the attributes of its style, with its line's paragraph style, and that a line
    /// with no tabs has the standard tab stops. A character the style's font has no glyph for may have another font.
    private func assertAttributesAreThoseOfTheStyles(_ storage: NSTextStorage, _ message: String,
                                                     file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage), file: file, line: line)
        let text = storage.string as NSString
        let standardTabStops = IFTabStops.standardTabStops(forTabWidth: IFPreferences.shared.tabWidth)
            .map { $0.location }
        let originalFont = NSAttributedString.Key("NSOriginalFont")
        var failures: [String] = []

        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length),
                                 options: [.byLines, .substringNotRequired]) { _, lineRange, enclosingRange, _ in
            let paragraphStyle = storage.attribute(.paragraphStyle, at: enclosingRange.location,
                                                   effectiveRange: nil) as? NSParagraphStyle
            if text.substring(with: lineRange).contains("\t") == false,
               paragraphStyle?.tabStops.map({ $0.location }) != standardTabStops {
                failures.append("the line at \(lineRange.location) doesn't have the standard tab stops")
            }

            for index in enclosingRange.location..<NSMaxRange(enclosingRange) {
                let style = data.style(at: UInt(index))
                var expected = IFPreferences.shared.styles[Int(style.rawValue)] as! [NSAttributedString.Key: Any]
                expected[.paragraphStyle] = paragraphStyle
                var attributes = storage.attributes(at: index, effectiveRange: nil)

                // A character the style's font has no glyph for
                let character = (text.substring(with: text.rangeOfComposedCharacterSequence(at: index)) as String)
                    .unicodeScalars.first!
                if let font = expected[.font] as? NSFont,
                   font.coveredCharacterSet.contains(character) == false {
                    attributes[.font] = nil
                    attributes[originalFont] = nil
                    expected[.font] = nil
                }

                for key in Set(attributes.keys).union(expected.keys) {
                    if !((attributes[key] as AnyObject?)?.isEqual(expected[key]) ?? (expected[key] == nil)) {
                        let actual = "\(attributes[key] ?? "none")".replacingOccurrences(of: "\n", with: " ")
                        let wanted = "\(expected[key] ?? "none")".replacingOccurrences(of: "\n", with: " ")
                        failures.append("character \(index), in style \(style.rawValue), has \(key.rawValue) "
                                        + "\(actual), not \(wanted)")
                    }
                }
            }
        }
        for failure in failures.prefix(5) {
            XCTFail("\(message): \(failure)", file: file, line: line)
        }
    }

    /// The range of the first match of some text
    private func range(of find: String, in storage: NSTextStorage,
                       file: StaticString = #filePath, line: UInt = #line) -> NSRange {
        let range = (storage.string as NSString).range(of: find)
        XCTAssertNotEqual(range.location, NSNotFound, find, file: file, line: line)
        return range
    }

    // MARK: - Tests

    func testOpeningASource() throws {
        let storage = registered(source)
        try assertAttributesAreThoseOfTheStyles(storage, "Opened")
    }

    func testOpeningACommentAtTheStart() throws {
        let storage = registered(source)

        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "[")
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        XCTAssertEqual(data.style(at: UInt(storage.length - 2)), .comment, "The rest of the source is a comment")
        try assertHighlightedAsIfOpened(storage, "After typing [")
        try assertAttributesAreThoseOfTheStyles(storage, "After typing [")

        storage.replaceCharacters(in: NSRange(location: 0, length: 1), with: "")
        try assertHighlightedAsIfOpened(storage, "After deleting [")
        try assertAttributesAreThoseOfTheStyles(storage, "After deleting [")
    }

    func testOpeningAQuotationAtTheStart() throws {
        let storage = registered(source)

        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "\"")
        try assertHighlightedAsIfOpened(storage, "After typing \"")
        try assertAttributesAreThoseOfTheStyles(storage, "After typing \"")

        storage.replaceCharacters(in: NSRange(location: 0, length: 1), with: "")
        try assertHighlightedAsIfOpened(storage, "After deleting \"")
    }

    func testDeletingTheEndOfAComment() throws {
        let storage = registered(source)

        storage.replaceCharacters(in: range(of: "lines.]", in: storage), with: "lines.")
        try assertHighlightedAsIfOpened(storage, "After deleting ]")
        try assertAttributesAreThoseOfTheStyles(storage, "After deleting ]")

        storage.replaceCharacters(in: range(of: "lines.", in: storage), with: "lines.]")
        try assertHighlightedAsIfOpened(storage, "After typing ]")
    }

    func testOpeningInform6Code() throws {
        let storage = registered(source)

        let location = range(of: "Part 2", in: storage).location
        storage.replaceCharacters(in: NSRange(location: location, length: 0), with: "(-")
        try assertHighlightedAsIfOpened(storage, "After typing (-")
        try assertAttributesAreThoseOfTheStyles(storage, "After typing (-")

        storage.replaceCharacters(in: range(of: "(-Part 2", in: storage), with: "Part 2")
        try assertHighlightedAsIfOpened(storage, "After deleting (-")
    }

    func testTypingAHeading() throws {
        let storage = registered(source)

        var location = NSMaxRange(range(of: "two lines.]\n\n", in: storage))
        for character in "Chapter 9 - New\n\n" {
            storage.replaceCharacters(in: NSRange(location: location, length: 0), with: String(character))
            location += 1
        }
        try assertHighlightedAsIfOpened(storage, "After typing a heading")
        try assertAttributesAreThoseOfTheStyles(storage, "After typing a heading")
    }
}
