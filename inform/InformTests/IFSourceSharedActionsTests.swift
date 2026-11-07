//
//  IFSourceSharedActionsTests.swift
//  InformTests
//

import XCTest

/// Shift Left and Right, and Comment Out and Uncomment Selection, on source text with the selection
/// marked by « and ».
final class IFSourceSharedActionsTests: XCTestCase {

    private let actions = IFSourceSharedActions()
    private var undo: UndoManager!
    private var document: NSDocument!

    override func setUp() {
        super.setUp()
        undo = UndoManager()
        undo.groupsByEvent = false
        document = NSDocument()
        document.undoManager = undo
    }

    override func tearDown() {
        document = nil
        undo = nil
        super.tearDown()
    }

    /// A view showing the marked text, registered as source text is, with the marked range selected.
    private func makeView(_ marked: String) -> NSTextView {
        let start = (marked as NSString).range(of: "«").location
        let end = (marked as NSString).range(of: "»").location
        let text = marked.replacingOccurrences(of: "«", with: "").replacingOccurrences(of: "»", with: "")

        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: "IFSourceSharedActionsTests", type: .inform7,
                                 intelligence: IFNaturalIntel(), undoManager: undo)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.layoutManager?.replaceTextStorage(storage)
        textView.setSelectedRange(NSRange(location: start, length: end - start - 1))
        return textView
    }

    /// The view's text, with its selection marked.
    private func marked(_ textView: NSTextView) -> String {
        let text = NSMutableString(string: textView.string)
        let selection = textView.selectedRange()
        text.insert("»", at: NSMaxRange(selection))
        text.insert("«", at: selection.location)
        return text as String
    }

    /// Does the action as one change to undo, as a menu command does.
    private func perform(_ action: (NSDocument, NSTextView) -> Void, on textView: NSTextView) {
        undo.beginUndoGrouping()
        action(document, textView)
        undo.endUndoGrouping()
    }

    private func shiftLeft(_ textView: NSTextView) {
        perform(actions.shiftLeftTextView(in:textView:), on: textView)
    }

    private func shiftRight(_ textView: NSTextView) {
        perform(actions.shiftRightTextView(in:textView:), on: textView)
    }

    private func commentOut(_ textView: NSTextView) {
        perform(actions.commentOutSelection(in:textView:), on: textView)
    }

    private func uncomment(_ textView: NSTextView) {
        perform(actions.uncommentSelection(in:textView:), on: textView)
    }

    // MARK: - Shift Right

    func testShiftRightIndentsEachSelectedLine() {
        let textView = makeView("«a\nb»\nc\n")
        shiftRight(textView)
        XCTAssertEqual(marked(textView), "«\ta\n\tb»\nc\n")
        XCTAssertEqual(undo.undoActionName, "Shift Right")
    }

    func testShiftRightSelectsFromTheStartOfTheFirstLine() {
        let textView = makeView("a«b\nc»d\n")
        shiftRight(textView)
        XCTAssertEqual(marked(textView), "«\tab\n\tc»d\n")
    }

    func testShiftRightIndentsTheLineWithTheInsertionPoint() {
        let textView = makeView("a\nb«»c\nd\n")
        shiftRight(textView)
        XCTAssertEqual(textView.string, "a\n\tbc\nd\n")
    }

    func testShiftRightLeavesTheLineAfterASelectedLine() {
        let textView = makeView("«a\n»b\n")
        shiftRight(textView)
        XCTAssertEqual(marked(textView), "«\ta\n»b\n")
    }

    func testUndoingShiftRight() {
        let textView = makeView("«a\nb»\nc\n")
        shiftRight(textView)

        undo.undo()
        XCTAssertEqual(textView.string, "a\nb\nc\n")
        undo.redo()
        XCTAssertEqual(textView.string, "\ta\n\tb\nc\n")
    }

    // MARK: - Shift Left

    func testShiftLeftTakesATabFromEachSelectedLine() {
        let textView = makeView("«\t\ta\n\tb»\nc\n")
        shiftLeft(textView)
        XCTAssertEqual(marked(textView), "«\ta\nb»\nc\n")
        XCTAssertEqual(undo.undoActionName, "Shift Left")
    }

    func testShiftLeftGoesOnPastALineWithoutATab() {
        let textView = makeView("«a\nb\n\tc»\n")
        shiftLeft(textView)
        XCTAssertEqual(marked(textView), "«a\nb\nc»\n")
    }

    func testUndoingShiftLeft() {
        let textView = makeView("«\ta\n\tb»\nc\n")
        shiftLeft(textView)

        undo.undo()
        XCTAssertEqual(textView.string, "\ta\n\tb\nc\n")
        undo.redo()
        XCTAssertEqual(textView.string, "a\nb\nc\n")
    }

    func testUndoingShiftLeftLeavesLinesWithoutATab() {
        let textView = makeView("«a\n\tb»\n")
        shiftLeft(textView)

        undo.undo()
        XCTAssertEqual(textView.string, "a\n\tb\n")
        undo.redo()
        XCTAssertEqual(textView.string, "a\nb\n")
    }

    func testShiftingAnEmptyLastLine() {
        let textView = makeView("a\n«»")
        shiftLeft(textView)
        undo.undo()
        XCTAssertEqual(textView.string, "a\n")

        shiftRight(textView)
        XCTAssertEqual(textView.string, "a\n\t")
        undo.undo()
        XCTAssertEqual(textView.string, "a\n")
        undo.redo()
        XCTAssertEqual(textView.string, "a\n\t")
    }

    func testUndoingAShiftKeepsItsName() {
        let textView = makeView("«\ta\n\tb»\n")
        shiftRight(textView)
        undo.undo()
        XCTAssertEqual(undo.redoActionName, "Shift Right")
        undo.redo()
        XCTAssertEqual(undo.undoActionName, "Shift Right")

        shiftLeft(textView)
        undo.undo()
        XCTAssertEqual(undo.redoActionName, "Shift Left")
        undo.redo()
        XCTAssertEqual(undo.undoActionName, "Shift Left")
    }

    // MARK: - Comment Out and Uncomment Selection

    func testCommentOut() {
        let textView = makeView("a «b c» d")
        commentOut(textView)
        XCTAssertEqual(marked(textView), "a «[b c]» d")

        undo.undo()
        XCTAssertEqual(textView.string, "a b c d")
        undo.redo()
        XCTAssertEqual(textView.string, "a [b c] d")
    }

    func testCommentingOutInAStringChangesNothing() {
        let textView = makeView("say \"a «b» c\"")
        commentOut(textView)
        XCTAssertEqual(marked(textView), "say \"a «b» c\"")
    }

    func testUncomment() {
        let textView = makeView("a «[b c]» d")
        uncomment(textView)
        XCTAssertEqual(marked(textView), "a «b c» d")

        undo.undo()
        XCTAssertEqual(textView.string, "a [b c] d")
        undo.redo()
        XCTAssertEqual(textView.string, "a b c d")
    }

    func testUncommentingInsideAComment() {
        let textView = makeView("[a «b» c]")
        uncomment(textView)
        XCTAssertEqual(marked(textView), "[a «]b[» c]")

        undo.undo()
        XCTAssertEqual(textView.string, "[a b c]")
    }
}
