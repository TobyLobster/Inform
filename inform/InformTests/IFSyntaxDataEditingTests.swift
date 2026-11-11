//
//  IFSyntaxDataEditingTests.swift
//  InformTests
//

import XCTest

/// Editing highlighted text: keeping the views restricted to part of it in step, and rewriting what's typed.
@MainActor
final class IFSyntaxDataEditingTests: XCTestCase {

    private let source = """
        "Editing" by Tester

        Every turn:
        \tsay "Tick."

        Chapter 1 - The Start

        The Kitchen is a room.

        Chapter 2 - The End

        The Hall is a room.

        """

    private let chapter1 = "Chapter 1 - The Start\n\nThe Kitchen is a room.\n\n"
    private let chapter2 = "Chapter 2 - The End\n\nThe Hall is a room.\n"

    /// A text storage registered for the test, and unregistered at the end.
    private func registered(_ text: String, intelligence: IFSyntaxIntelligence? = nil,
                            undoManager: UndoManager? = nil) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFSyntaxDataEditingTests", type: .inform7,
                                 intelligence: intelligence, undoManager: undoManager)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }
        return storage
    }

    /// A view of the storage restricted to some of its text, as the source page shows a single heading.
    private func view(of storage: NSTextStorage, restrictedTo text: String) throws -> (NSTextView, NSTextStorage) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.layoutManager?.replaceTextStorage(storage)
        let range = (storage.string as NSString).range(of: text)
        XCTAssertNotEqual(range.location, NSNotFound, text)
        IFSyntaxManager.restrictStorage(storage, range: range, for: textView)
        return (textView, try XCTUnwrap(IFSyntaxManager.restrictedTextStorage(storage, for: textView)))
    }

    /// Checks that the view shows the given text, which is its restricted range of the storage, highlighted as it is there.
    private func assertView(_ view: NSTextView, of storage: NSTextStorage, shows text: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let shown = IFSyntaxManager.restrictedTextStorage(storage, for: view) else {
            return XCTFail("The view isn't restricted", file: file, line: line)
        }
        XCTAssertEqual(shown.string, text, file: file, line: line)
        let range = IFSyntaxManager.restrictedRange(storage, for: view)
        guard range.location != NSNotFound, range.length >= 0, NSMaxRange(range) <= storage.length else {
            return XCTFail("The restricted range \(range) is outside the text", file: file, line: line)
        }
        let expected = storage.attributedSubstring(from: range)
        XCTAssertEqual(expected.string, text, "The restricted range", file: file, line: line)
        XCTAssertTrue(shown.isEqual(to: expected), "The highlighting", file: file, line: line)
    }

    /// The range of the first match of some text.
    private func range(of find: String, in storage: NSTextStorage,
                       file: StaticString = #filePath, line: UInt = #line) -> NSRange {
        let range = (storage.string as NSString).range(of: find)
        XCTAssertNotEqual(range.location, NSNotFound, find, file: file, line: line)
        return range
    }

    /// Replaces the first match of some text, as pasting over it does.
    private func replace(_ find: String, with replacement: String, in storage: NSTextStorage,
                         file: StaticString = #filePath, line: UInt = #line) {
        storage.replaceCharacters(in: range(of: find, in: storage, file: file, line: line), with: replacement)
    }

    /// Inserts text before the first match of some text, as pasting does.
    private func insert(_ text: String, before find: String, in storage: NSTextStorage,
                        file: StaticString = #filePath, line: UInt = #line) {
        let location = range(of: find, in: storage, file: file, line: line).location
        storage.replaceCharacters(in: NSRange(location: location, length: 0), with: text)
    }

    /// Types text one character at a time after the first match of some text.
    private func type(_ text: String, after find: String, in storage: NSTextStorage,
                      file: StaticString = #filePath, line: UInt = #line) {
        var location = NSMaxRange(range(of: find, in: storage, file: file, line: line))
        for character in text {
            let length = storage.length
            storage.replaceCharacters(in: NSRange(location: location, length: 0), with: String(character))
            location += storage.length - length
        }
    }

    // MARK: - Restricted views

    func testEditingTheTextInARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)
        assertView(view, of: storage, shows: chapter1)

        replace("Kitchen", with: "big Kitchen", in: storage)
        assertView(view, of: storage, shows: chapter1.replacingOccurrences(of: "Kitchen", with: "big Kitchen"))
        replace("big ", with: "", in: storage)
        assertView(view, of: storage, shows: chapter1)
    }

    func testEditingTheTextBeforeARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)
        let location = IFSyntaxManager.restrictedRange(storage, for: view).location

        replace("Tick", with: "Tick tock", in: storage)
        assertView(view, of: storage, shows: chapter1)
        XCTAssertEqual(IFSyntaxManager.restrictedRange(storage, for: view).location, location + 5)

        replace("Every turn:\n\tsay \"Tick tock.\"\n\n", with: "", in: storage)
        assertView(view, of: storage, shows: chapter1)
    }

    func testEditingTheTextAfterARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)
        let range = IFSyntaxManager.restrictedRange(storage, for: view)

        replace("Hall", with: "Great Hall", in: storage)
        replace("Chapter 2 - The End\n\n", with: "", in: storage)
        assertView(view, of: storage, shows: chapter1)
        XCTAssertEqual(IFSyntaxManager.restrictedRange(storage, for: view), range)
    }

    /// Text put just before the next heading belongs to the heading the view shows.
    func testInsertingTextAtTheEndOfARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)

        insert("The Pantry is a room.\n\n", before: "Chapter 2", in: storage)
        assertView(view, of: storage, shows: chapter1 + "The Pantry is a room.\n\n")
    }

    func testDeletingAcrossTheStartOfARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)

        replace("\"Tick.\"\n\nChapter 1 - ", with: "", in: storage)
        assertView(view, of: storage, shows: "The Start\n\nThe Kitchen is a room.\n\n")
    }

    func testDeletingAcrossTheEndOfARestrictedView() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)

        replace("room.\n\nChapter 2 - ", with: "", in: storage)
        assertView(view, of: storage, shows: "Chapter 1 - The Start\n\nThe Kitchen is a ")
    }

    func testDeletingARestrictedViewsTextAndTheTextAroundIt() throws {
        let storage = registered(source)
        let (view, _) = try view(of: storage, restrictedTo: chapter1)

        replace("\"Tick.\"\n\n" + chapter1 + "Chapter 2 - ", with: "", in: storage)
        assertView(view, of: storage, shows: "")
    }

    func testEditingARestrictedView() throws {
        let storage = registered(source)
        let (view, shown) = try view(of: storage, restrictedTo: chapter1)

        replace("Kitchen", with: "big Kitchen", in: shown)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Kitchen", with: "big Kitchen"))
        assertView(view, of: storage, shows: chapter1.replacingOccurrences(of: "Kitchen", with: "big Kitchen"))

        replace("big ", with: "", in: shown)
        XCTAssertEqual(storage.string, source)
        assertView(view, of: storage, shows: chapter1)
    }

    /// A change of highlighting reaches the view, beyond the characters that were edited.
    func testHighlightingAnEditInARestrictedView() throws {
        let storage = registered(source)
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        let (view, shown) = try view(of: storage, restrictedTo: chapter1)

        // A comment that isn't closed runs to the end of the text
        insert("[", before: "The Kitchen", in: storage)
        XCTAssertEqual(data.style(at: UInt(range(of: "room", in: storage).location)), .comment)
        assertView(view, of: storage, shows: chapter1.replacingOccurrences(of: "The Kitchen", with: "[The Kitchen"))

        type("]", after: "room.", in: shown)
        XCTAssertEqual(data.style(at: UInt(range(of: "room", in: storage).location)), .comment)
        XCTAssertEqual(data.style(at: UInt(range(of: "Hall", in: storage).location)), .naturalInform)
        assertView(view, of: storage, shows: chapter1.replacingOccurrences(of: "The Kitchen", with: "[The Kitchen")
                    .replacingOccurrences(of: "room.", with: "room.]"))
    }

    func testTwoRestrictedViews() throws {
        let storage = registered(source)
        let (first, firstShown) = try view(of: storage, restrictedTo: chapter1)
        let (second, secondShown) = try view(of: storage, restrictedTo: chapter2)

        replace("Kitchen", with: "big Kitchen", in: firstShown)
        assertView(first, of: storage, shows: chapter1.replacingOccurrences(of: "Kitchen", with: "big Kitchen"))
        assertView(second, of: storage, shows: chapter2)

        replace("Hall", with: "Great Hall", in: secondShown)
        assertView(first, of: storage, shows: chapter1.replacingOccurrences(of: "Kitchen", with: "big Kitchen"))
        assertView(second, of: storage, shows: chapter2.replacingOccurrences(of: "Hall", with: "Great Hall"))
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Kitchen", with: "big Kitchen")
                        .replacingOccurrences(of: "Hall", with: "Great Hall"))
    }

    // MARK: - Rewriting

    func testLineEndingsAreConverted() throws {
        let storage = registered(source)
        insert("Windows\r\nand\rMac\r\n", before: "Chapter 1", in: storage)
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 1", with: "Windows\nand\nMac\nChapter 1"))

        let (view, shown) = try view(of: storage, restrictedTo: chapter2)
        insert("\r", before: "The Hall", in: shown)
        assertView(view, of: storage, shows: chapter2.replacingOccurrences(of: "The Hall", with: "\nThe Hall"))
    }

    func testANewLineIsIndented() throws {
        try XCTSkipUnless(IFPreferences.shared.indentAfterNewline, "Indenting new lines is turned off in Inform's preferences")
        let storage = registered(source, intelligence: IFNaturalIntel())

        // One more tab than a line ending in a colon
        type("\n", after: "Every turn:", in: storage)
        XCTAssertTrue(storage.string.contains("Every turn:\n\t\n\tsay \"Tick.\"\n\nChapter 1"), storage.string)

        // As many tabs as the line before
        type("\n", after: "\"Tick.\"", in: storage)
        XCTAssertTrue(storage.string.contains("Every turn:\n\t\n\tsay \"Tick.\"\n\t\n\nChapter 1"), storage.string)

        // None after a line of only tabs
        type("\n", after: "Every turn:\n\t", in: storage)
        XCTAssertTrue(storage.string.contains("Every turn:\n\t\n\n\tsay \"Tick.\"\n\t\n\nChapter 1"), storage.string)
    }

    /// The line before is found in the whole text, not at the view's own offsets.
    func testANewLineInARestrictedViewIsIndented() throws {
        try XCTSkipUnless(IFPreferences.shared.indentAfterNewline, "Indenting new lines is turned off in Inform's preferences")
        let storage = registered(source, intelligence: IFNaturalIntel())
        let (view, shown) = try view(of: storage, restrictedTo: chapter2)

        type("\n", after: "The Hall is a room.", in: shown)
        assertView(view, of: storage, shows: chapter2 + "\n")

        type("\nInstead of waiting:", after: "The Hall is a room.\n", in: shown)
        type("\n", after: "Instead of waiting:", in: shown)
        assertView(view, of: storage, shows: chapter2 + "\nInstead of waiting:\n\t\n")
    }

    /// Undoing puts back what was there, without rewriting it.
    func testUndoingIsNotRewritten() throws {
        try XCTSkipUnless(IFPreferences.shared.indentAfterNewline, "Indenting new lines is turned off in Inform's preferences")
        let undo = UndoManager()
        undo.groupsByEvent = false
        let storage = registered(source, intelligence: IFNaturalIntel(), undoManager: undo)
        let location = NSMaxRange(range(of: "Every turn:", in: storage))

        undo.beginUndoGrouping()
        undo.registerUndo(withTarget: storage) { $0.replaceCharacters(in: NSRange(location: location, length: 0), with: "\n") }
        undo.endUndoGrouping()
        undo.undo()
        XCTAssertTrue(storage.string.contains("Every turn:\n\n\tsay"), storage.string)
    }

    func testAHeadingIsNumbered() throws {
        try XCTSkipUnless(IFPreferences.shared.autoNumberSections, "Numbering sections is turned off in Inform's preferences")
        let numbered = """
            "Numbering" by Tester

            Section 1 - Doors

            Section 2 - Windows

            """
        let storage = registered(numbered, intelligence: IFNaturalIntel())

        insert("Section\n\n", before: "Section 2", in: storage)
        type(" ", after: "Doors\n\nSection", in: storage)
        XCTAssertEqual(storage.string, numbered.replacingOccurrences(of: "Section 2", with: "Section 2 - \n\nSection 2"))

        // The sections after it are renumbered next time round the run loop
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(storage.string, numbered.replacingOccurrences(of: "Section 2", with: "Section 2 - \n\nSection 3"))
    }

    // MARK: - Lines

    func testLines() throws {
        let storage = registered(source)
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        XCTAssertEqual(data.text(forLine: 2), "Every turn:\n")
        XCTAssertEqual(data.text(forLine: 3), "\tsay \"Tick.\"\n")
        XCTAssertEqual(data.text(forLine: -1), "")
        XCTAssertEqual(data.text(forLine: 99), "")
        XCTAssertEqual(data.numberOfTabStops(forLine: 2), 0)
        XCTAssertEqual(data.numberOfTabStops(forLine: 3), 1)
        XCTAssertEqual(data.character(atEndOfLine: 2), unichar(UInt8(ascii: ":")))
        XCTAssertEqual(data.character(atEndOfLine: 3), unichar(UInt8(ascii: "\"")))

        let comment = registered("[A comment\nacross lines] Then text.\n")
        let commentData = try XCTUnwrap(IFSyntaxManager.data(for: comment))
        XCTAssertEqual(commentData.style(atEndOfLine: 0), .comment)
        XCTAssertEqual(commentData.style(atStartOfLine: 1), .comment)
        XCTAssertEqual(commentData.style(atEndOfLine: 1), .naturalInform)
        XCTAssertEqual(commentData.character(atEndOfLine: 1), unichar(UInt8(ascii: ".")))
    }
}
