//
//  IFSyntaxDataTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSyntaxDataTests: XCTestCase {

    /// A table, with text before and after it.
    private let source = """
        The Kitchen is a room.

        Table of Fruit
        name\tcolour\tprice
        apple\tred\t3
        banana\tyellow\t4
        cherry\tdark red\t10

        The fruit bowl is in the Kitchen.

        """

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            // Elastic tabs are a preference, which the tests mustn't change
            try XCTSkipUnless(IFPreferences.shared.elasticTabs, "Elastic tabs are turned off in Inform's preferences")
        }
    }

    /// Source text highlighted as the editor highlights it.
    private func highlightedStorage(_ text: String) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFSyntaxDataTests", type: .inform7,
                                 intelligence: nil, undoManager: nil)
        return storage
    }

    /// The tab stops of each line.
    private func tabStops(_ storage: NSTextStorage) -> [[CGFloat]] {
        var result: [[CGFloat]] = []
        let text = storage.string as NSString
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length),
                                 options: [.byLines, .substringNotRequired]) { _, _, lineRange, _ in
            let style = storage.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle
            result.append(style?.tabStops.map { $0.location } ?? [])
        }
        return result
    }

    /// Makes the edits to the source (each replacing the first match of some text), one after another, and checks that each line then has the
    /// same tab stops as it would when the edited source is first opened.
    private func checkEdits(_ edits: [(String, String)], file: StaticString = #filePath, line: UInt = #line) {
        let storage = highlightedStorage(source)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }

        for (find, replacement) in edits {
            let range = (storage.string as NSString).range(of: find)
            XCTAssertNotEqual(range.location, NSNotFound, find, file: file, line: line)

            // Change only the characters that differ, as typing or deleting would
            let old = Array(find.utf16), new = Array(replacement.utf16)
            var prefix = 0
            while prefix < min(old.count, new.count) && old[prefix] == new[prefix] { prefix += 1 }
            var suffix = 0
            while suffix < min(old.count, new.count) - prefix && old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
            let changed = String(utf16CodeUnits: Array(new[prefix..<(new.count - suffix)]), count: new.count - suffix - prefix)
            storage.replaceCharacters(in: NSRange(location: range.location + prefix, length: old.count - prefix - suffix),
                                      with: changed)
        }

        let opened = highlightedStorage(storage.string)
        defer { IFSyntaxManager.unregisterTextStorage(opened) }
        let edited = tabStops(storage)
        let expected = tabStops(opened)
        XCTAssertEqual(edited.count, expected.count, file: file, line: line)

        let lines = storage.string.components(separatedBy: "\n")
        for (index, (stops, expectedStops)) in zip(edited, expected).enumerated() where stops != expectedStops {
            XCTFail("Line \(index + 1), \"\(lines[index])\": tab stops \(stops.prefix(3)) rather than \(expectedStops.prefix(3))",
                    file: file, line: line)
        }
    }

    /// Typing the given text one character at a time, after the text that's found.
    private func typing(_ text: String, after find: String) -> [(String, String)] {
        var edits: [(String, String)] = []
        var typed = find
        for character in text {
            edits.append((typed, typed + String(character)))
            typed += String(character)
        }
        return edits
    }

    /// The table's rows are laid out in columns, unlike the text around them.
    func testTableIsLaidOutInColumns() {
        let storage = highlightedStorage(source)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }
        let stops = tabStops(storage)
        XCTAssertNotEqual(stops[3], stops[0])
        XCTAssertEqual(stops[3], stops[6])
    }

    /// Text outside tables has tab stops at the width set in Inform's preferences.
    func testOtherTextUsesTheTabWidthPreference() {
        let storage = highlightedStorage(source)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }
        let width = IFPreferences.shared.tabWidth
        XCTAssertEqual(tabStops(storage)[0].prefix(2), [width, width * 2])
    }

    /// TobyLobster/Inform#50: editing a table left rows with the wrong tab stops until the file was reopened.
    func testTypingInACellThatIsNotTheWidest() {
        checkEdits(typing("s", after: "apple\tred"))
    }

    func testTypingInTheWidestCell() {
        checkEdits(typing("der", after: "cherry\tdark red"))
    }

    func testTypingANewRow() {
        checkEdits(typing("\ndate\tbrown\t5", after: "banana\tyellow\t4"))
    }

    func testDeletingARow() {
        checkEdits([("banana\tyellow\t4\n", "")])
    }

    func testDeletingTheWidestRow() {
        checkEdits([("cherry\tdark red\t10\n", "")])
    }

    func testEditingTheTableName() {
        checkEdits(typing("s", after: "Table of Fruit"))
    }

    func testDeletingACellsTab() {
        checkEdits([("apple\tred", "applered")])
    }

    /// A table at the end of the source, with no newline after its last row, as while that row is typed, is laid out
    /// as it is with one.
    func testATableAtTheEndOfTheSource() {
        let text = "Table of Fruit\nname\tcolour\tprice\napple\tred\t3\ncherry\tdark red and black"
        let storage = highlightedStorage(text)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }
        let withNewline = highlightedStorage(text + "\n")
        defer { IFSyntaxManager.unregisterTextStorage(withNewline) }
        XCTAssertEqual(tabStops(storage), tabStops(withNewline))
    }
}
