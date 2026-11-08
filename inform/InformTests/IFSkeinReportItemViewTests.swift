//
//  IFSkeinReportItemViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinReportItemViewTests: XCTestCase {

    /// The width of the text, inside the report's borders
    private let textWidth = kSkeinReportWidth - kSkeinReportInsideLeftBorder - kSkeinReportInsideRightBorder

    private func text(_ string: String) -> NSAttributedString {
        return NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 12)])
    }

    func testANewView() {
        let view = IFSkeinReportItemView()
        XCTAssertEqual(view.frame, .zero)
        XCTAssertEqual(view.subviews, [view.textView, view.blessButton] as [NSView])
        // Not laid out yet: the text view is only as high as its minimum height
        XCTAssertEqual(view.textView.frame, NSRect(x: 0, y: 0, width: 0, height: 1))
        XCTAssertEqual(view.blessButton.frame, .zero)
        XCTAssertEqual(view.textHeight, 0)
        XCTAssertEqual(view.uniqueId, 0)
        XCTAssertEqual(view.topBorderHeight, 0)

        let textView = view.textView
        XCTAssertNil(textView.textLayoutManager, "TextKit 1")
        XCTAssertFalse(textView.isEditable)
        XCTAssertFalse(textView.drawsBackground)
        XCTAssertFalse(textView.isContinuousSpellCheckingEnabled)
        XCTAssertFalse(textView.isGrammarCheckingEnabled)
        XCTAssertFalse(textView.isHorizontallyResizable)
        XCTAssertTrue(textView.isVerticallyResizable)
        XCTAssertEqual(textView.textContainerInset, .zero)
        // The view gives the text view the report's width as its minimum width, but AppKit doesn't keep it. It doesn't
        // matter: the text view's width doesn't resize.
        XCTAssertEqual(textView.minSize, NSSize(width: 0, height: 1))
    }

    /// The text view is as tall as its text, wrapped to the report's width, and the view is as tall as the text view
    func testSettingTheText() {
        let view = IFSkeinReportItemView()
        view.setAttributedString(text("Hello"), forceChange: false)
        XCTAssertEqual(view.textView.string, "Hello")
        let oneLine = view.textHeight
        XCTAssertGreaterThan(oneLine, 1)
        XCTAssertEqual(view.textView.frame,
                       NSRect(x: kSkeinReportInsideLeftBorder, y: 0, width: textWidth, height: oneLine))
        XCTAssertEqual(view.frame, NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: oneLine))

        view.setAttributedString(text(String(repeating: "A long line of output. ", count: 20)), forceChange: false)
        XCTAssertGreaterThan(view.textHeight, oneLine * 2)
        XCTAssertEqual(view.textView.frame,
                       NSRect(x: kSkeinReportInsideLeftBorder, y: 0, width: textWidth, height: view.textHeight))
        XCTAssertEqual(view.frame, NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: view.textHeight))
    }

    /// The text view is at the top of the view, below the top border, and the bless button at its bottom right
    func testTheFrame() {
        let view = IFSkeinReportItemView()
        view.topBorderHeight = 6
        view.setAttributedString(text("Hello"), forceChange: false)
        let height = view.textHeight

        view.frame = NSRect(x: 0, y: 40, width: kSkeinReportWidth, height: 100)
        XCTAssertEqual(view.textView.frame,
                       NSRect(x: kSkeinReportInsideLeftBorder, y: 100 - 6 - height, width: textWidth, height: height))
        XCTAssertEqual(view.blessButton.frame, NSRect(x: kSkeinReportWidth - 14, y: 1, width: 13, height: 13))
    }

    /// The same text again changes nothing but the view's position, unless the change is forced, as it is when the
    /// report's font size changes
    func testTheSameTextAgain() {
        let view = IFSkeinReportItemView()
        view.setAttributedString(text("Hello"), forceChange: false)
        let height = view.textHeight
        view.frame = NSRect(x: 5, y: 40, width: kSkeinReportWidth, height: 100)

        view.setAttributedString(text("Hello"), forceChange: false)
        XCTAssertEqual(view.frame, NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: 100))
        XCTAssertEqual(view.textHeight, height)

        view.setAttributedString(text("Hello"), forceChange: true)
        XCTAssertEqual(view.frame, NSRect(x: 0, y: 0, width: kSkeinReportWidth, height: height))
    }
}
