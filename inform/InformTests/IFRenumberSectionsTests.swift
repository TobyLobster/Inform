//
//  IFRenumberSectionsTests.swift
//  InformTests
//

import XCTest

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
    private func makeSource(undoManager: UndoManager? = nil) -> (NSTextStorage, NSTextView) {
        let storage = NSTextStorage(string: source)
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

    func testAViewOfUnregisteredTextHasNoRegisteredStorage() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertNil(IFSyntaxManager.registeredStorage(for: textView))
    }
}
