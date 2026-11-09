//
//  IFSourceHighlightsTests.swift
//  InformTests
//

import XCTest

/// The lines highlighted in a project's source files
final class IFSourceHighlightsTests: XCTestCase {
    private let highlights = IFSourceHighlights()
    private let story = "/Projects/Lighthouse.inform/Source/story.ni"
    private let other = "/Projects/Lighthouse.inform/Source/Other.ni"

    /// A file's highlights, each its line and style
    private func highlightsIn(_ file: String?) -> [[UInt32]]? {
        return highlights.highlights(inFile: file)?.map { $0.map { $0.uint32Value } }
    }

    func testThereAreNoneAtFirst() {
        XCTAssertEqual(highlights.files, [])
        XCTAssertNil(highlightsIn(story))
        XCTAssertNil(highlightsIn(nil))
        XCTAssertFalse(highlights.hasTemporaryHighlights)
    }

    func testEachFileKeepsItsHighlightsInOrder() {
        highlights.highlightLine(3, inFile: story, style: .neutral)
        highlights.highlightLine(1, inFile: story, style: .error)
        highlights.highlightLine(7, inFile: other, style: .warning)

        XCTAssertEqual(highlightsIn(story), [[3, IFLineStyle.neutral.rawValue], [1, IFLineStyle.error.rawValue]])
        XCTAssertEqual(highlightsIn(other), [[7, IFLineStyle.warning.rawValue]])
        XCTAssertEqual(highlights.files.sorted(), [other, story])
    }

    func testRemovesOneStyleFromOneFile() {
        highlights.highlightLine(3, inFile: story, style: .error)
        highlights.highlightLine(4, inFile: story, style: .neutral)
        highlights.highlightLine(5, inFile: story, style: .error)
        highlights.highlightLine(6, inFile: other, style: .error)

        XCTAssertTrue(highlights.removeHighlights(of: .error, inFile: story))

        XCTAssertEqual(highlightsIn(story), [[4, IFLineStyle.neutral.rawValue]])
        XCTAssertEqual(highlightsIn(other), [[6, IFLineStyle.error.rawValue]])
    }

    func testSaysWhenThereWereNoneToRemove() {
        highlights.highlightLine(4, inFile: story, style: .neutral)

        XCTAssertFalse(highlights.removeHighlights(of: .error, inFile: story))
        XCTAssertFalse(highlights.removeHighlights(of: .error, inFile: other))
        XCTAssertFalse(highlights.removeHighlights(of: .error, inFile: nil))
        XCTAssertEqual(highlightsIn(story), [[4, IFLineStyle.neutral.rawValue]])
    }

    func testAFileStaysOnceItsHighlightsAreRemoved() {
        highlights.highlightLine(3, inFile: story, style: .error)

        _ = highlights.removeHighlights(of: .error, inFile: story)

        XCTAssertEqual(highlights.files, [story])
        XCTAssertEqual(highlightsIn(story), [])
    }

    func testNotesTemporaryHighlights() {
        highlights.highlightLine(1, inFile: story, style: .neutral)
        XCTAssertFalse(highlights.hasTemporaryHighlights)

        for style: IFLineStyle in [.warning, .error, .fatalError, .highlight] {
            highlights.highlightLine(2, inFile: story, style: style)
            XCTAssertTrue(highlights.hasTemporaryHighlights, "style \(style.rawValue)")

            highlights.temporaryHighlightsWereRemoved()
            XCTAssertFalse(highlights.hasTemporaryHighlights, "style \(style.rawValue)")
        }
    }

    func testTemporaryHighlightsAreNotedUntilSaidToBeRemoved() {
        highlights.highlightLine(2, inFile: story, style: .error)

        _ = highlights.removeHighlights(of: .error, inFile: story)

        XCTAssertTrue(highlights.hasTemporaryHighlights)
    }
}
