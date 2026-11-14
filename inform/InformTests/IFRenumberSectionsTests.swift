//
//  IFRenumberSectionsTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFRenumberSectionsTests: XCTestCase {

    private let source = """
        "Renumbering" by Tester

        Chapter 1 - The Start

        Section 1 - Arrival

        Section 3 - Departure

        Chapter 2 - The End

        Section 4 - Return

        Section 5 - Rest

        """

    private var renumberedSource: String {
        source
            .replacingOccurrences(of: "Section 3 - Departure", with: "Section 2 - Departure")
            .replacingOccurrences(of: "Section 4 - Return", with: "Section 1 - Return")
            .replacingOccurrences(of: "Section 5 - Rest", with: "Section 2 - Rest")
    }

    /// A source text storage with syntax intelligence, as a project has, and a view showing it.
    private func makeSource(_ text: String? = nil, undoManager: UndoManager? = nil) -> (NSTextStorage, NSTextView) {
        let storage = NSTextStorage(string: text ?? source)
        IFSyntaxManager.register(storage, name: "IFRenumberSectionsTests", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: undoManager)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.layoutManager?.replaceTextStorage(storage)
        return (storage, textView)
    }

    func testEachChaptersSectionsAreNumberedFromOne() {
        let (storage, textView) = makeSource()

        IFSourceSharedActions().renumberSections(in: NSDocument(), textView: textView)
        XCTAssertEqual(storage.string, renumberedSource)
    }

    func testRenumberingWhileTheViewShowsOneHeading() throws {
        let undo = UndoManager()
        undo.groupsByEvent = false
        let document = NSDocument()
        document.undoManager = undo
        let (storage, textView) = makeSource(undoManager: undo)

        // Show only chapter 2, as choosing it in the Headings bar does
        let chapter2 = (source as NSString).range(of: "Chapter 2").location
        IFSyntaxManager.restrictStorage(storage, range: NSRange(location: chapter2, length: storage.length - chapter2),
                                        for: textView)
        let shown = try XCTUnwrap(IFSyntaxManager.restrictedTextStorage(storage, for: textView))
        XCTAssertTrue(textView.textStorage === shown)
        XCTAssertTrue(IFSyntaxManager.registeredStorage(for: textView) === storage)

        IFSourceSharedActions().renumberSections(in: document, textView: textView)
        XCTAssertEqual(storage.string, renumberedSource)
        XCTAssertEqual(shown.string, String(renumberedSource[renumberedSource.range(of: "Chapter 2")!.lowerBound...]))

        // One undo puts every section back
        undo.undo()
        XCTAssertEqual(storage.string, source)
        XCTAssertEqual(shown.string, String(source[source.range(of: "Chapter 2")!.lowerBound...]))
    }

    /// A source text after Renumber All Sections
    private func renumbered(_ text: String) -> String {
        let (storage, textView) = makeSource(text)
        IFSourceSharedActions().renumberSections(in: NSDocument(), textView: textView)
        return storage.string
    }

    /// A heading numbered in words is renumbered in words, in its own capitals, even when the number is the last word
    /// of its line
    func testHeadingsNumberedInWordsAreRenumberedInWords() {
        let text = """
            "Words" by Tester

            Chapter One - The Start

            Chapter Three - The Middle

            CHAPTER FIVE - The End

            chapter seven - The Epilogue

            Chapter Nine

            """
        XCTAssertEqual(renumbered(text), text
            .replacingOccurrences(of: "Chapter Three", with: "Chapter Two")
            .replacingOccurrences(of: "CHAPTER FIVE", with: "CHAPTER THREE")
            .replacingOccurrences(of: "chapter seven", with: "chapter four")
            .replacingOccurrences(of: "Chapter Nine", with: "Chapter Five"))
    }

    /// Headings numbered in words and in figures keep their own way, and are counted together
    func testHeadingsInWordsAndFiguresAreCountedTogether() {
        let text = """
            "Mixed" by Tester

            Chapter Two - The Start

            Chapter 4

            Chapter Six - The End

            """
        XCTAssertEqual(renumbered(text), text
            .replacingOccurrences(of: "Chapter Two", with: "Chapter One")
            .replacingOccurrences(of: "Chapter 4", with: "Chapter 2")
            .replacingOccurrences(of: "Chapter Six", with: "Chapter Three"))
    }

    /// A number that would take more than one word, from 100, is put in figures, as a heading's number is its second
    /// word
    func testAHundredIsPutInFiguresThoughTheHeadingWasInWords() {
        let numbered = (1...99).map { "Section \($0) - Room\n\n" }.joined()
        let text = "\"Many\" by Tester\n\n" + numbered + "Section Seven - The Last Room\n\n"
        XCTAssertEqual(renumbered(text), "\"Many\" by Tester\n\n" + numbered + "Section 100 - The Last Room\n\n")
    }

    func testAViewOfUnregisteredTextHasNoRegisteredStorage() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertNil(IFSyntaxManager.registeredStorage(for: textView))
    }
}
