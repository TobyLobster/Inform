//
//  IFRenumberSectionsTests.swift
//  InformTests
//

import XCTest

final class IFRenumberSectionsTests: XCTestCase {

    /// Renumbers the sections in some Inform 7 source, as the Renumber Sections menu item does.
    private func renumbered(_ source: String) -> String {
        let storage = NSTextStorage(string: source)
        IFSyntaxManager.register(storage, name: "IFRenumberSectionsTests", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: nil)
        defer { IFSyntaxManager.unregisterTextStorage(storage) }

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.layoutManager?.replaceTextStorage(storage)

        IFSourceSharedActions().renumberSections(in: NSDocument(), textView: textView)
        return storage.string
    }

    func testEachChaptersSectionsAreNumberedFromOne() {
        let source = """
            "Renumbering" by Tester

            Chapter 1 - The Start

            Section 1 - Arrival

            Section 3 - Departure

            Chapter 2 - The End

            Section 4 - Return

            Section 5 - Rest

            """
        let expected = source
            .replacingOccurrences(of: "Section 3 - Departure", with: "Section 2 - Departure")
            .replacingOccurrences(of: "Section 4 - Return", with: "Section 1 - Return")
            .replacingOccurrences(of: "Section 5 - Rest", with: "Section 2 - Rest")
        XCTAssertEqual(renumbered(source), expected)
    }
}
