//
//  IFFindTextViewTests.swift
//  InformTests
//

import XCTest

/// Not finding a match beeps, so some of these tests do.
@MainActor
final class IFFindTextViewTests: XCTestCase {

    /// Gives a text view an undo manager, as its window would. The text view has to allow undo, as the source's does,
    /// or it has no undo manager.
    private final class UndoGiver: NSObject, NSTextViewDelegate {
        let undo = UndoManager()

        override init() {
            super.init()
            undo.groupsByEvent = false
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            return undo
        }
    }

    /// For the methods that take a find controller, which don't use it. It stops watching for main windows at once,
    /// and would keep its histories in defaults that are never written.
    private lazy var findController: IFFindController = {
        let controller = IFFindController(defaults: UserDefaults(suiteName: "IFFindTextViewTests.never-written")!)
        NotificationCenter.default.removeObserver(controller)
        return controller
    }()

    private let caseInsensitive = IFFindType(rawValue: IFFindType.contains.rawValue
                                                       | IFFindType.caseInsensitive.rawValue)!

    private func makeTextView(_ text: String) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        return textView
    }

    /// Finds the next match, and gives what the completion handler was told
    private func findNext(_ match: String, _ type: IFFindType = .contains, in textView: NSTextView) -> Bool? {
        var found: Bool?
        textView.findNextMatch(match, of: type) { found = $0 }
        return found
    }

    private func findPrevious(_ match: String, _ type: IFFindType = .contains, in textView: NSTextView) -> Bool? {
        var found: Bool?
        textView.findPreviousMatch(match, of: type) { found = $0 }
        return found
    }

    private func selection(in textView: NSTextView) -> String? {
        var selected: String?
        textView.currentSelectionForFind { selected = $0 }
        return selected
    }

    private func range(_ location: Int, _ length: Int) -> NSRange {
        return NSRange(location: location, length: length)
    }

    /// What the find controller does for Replace All
    private func replaceAll(_ results: [IFFindResult], with replacement: String,
                            in textView: NSTextView) -> (results: [IFFindResult?], offset: Int32) {
        var offset: Int32 = 0
        textView.beginReplaceAll(findController)
        let newResults = results.map { textView.replaceFindAllResult($0, with: replacement, offset: &offset) }
        textView.finishedReplaceAll(findController)
        return (newResults, offset)
    }

    // MARK: - Finding

    /// Each find starts after the selection, and goes round to the start of the text
    func testFindingTheNextMatch() {
        let textView = makeTextView("one two one two")
        XCTAssertEqual(findNext("two", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(4, 3))
        XCTAssertEqual(findNext("two", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(12, 3))
        XCTAssertEqual(findNext("two", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(4, 3))

        // From the end of the text, the search starts at the beginning
        textView.setSelectedRange(range(15, 0))
        XCTAssertEqual(findNext("one", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(0, 3))
    }

    /// Each find starts before the selection, and goes round to the end of the text
    func testFindingThePreviousMatch() {
        let textView = makeTextView("one two one two")
        XCTAssertEqual(findPrevious("one", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(8, 3))
        XCTAssertEqual(findPrevious("one", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(0, 3))
        XCTAssertEqual(findPrevious("one", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(8, 3))

        // From inside a match, that match is found
        textView.setSelectedRange(range(10, 0))
        XCTAssertEqual(findPrevious("one", in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(8, 3))
    }

    /// A match that isn't there leaves the selection alone
    func testFindingNothing() {
        let textView = makeTextView("one two one two")
        textView.setSelectedRange(range(4, 3))
        XCTAssertEqual(findNext("three", in: textView), false)
        XCTAssertEqual(findPrevious("three", in: textView), false)
        XCTAssertEqual(textView.selectedRange(), range(4, 3))
    }

    func testFindingInNoText() {
        let textView = makeTextView("")
        XCTAssertEqual(findNext("one", in: textView), false)
        XCTAssertEqual(findPrevious("one", in: textView), false)
        XCTAssertEqual(textView.selectedRange(), range(0, 0))
    }

    /// The completion handlers can be left out, as the find controller does
    func testFindingWithoutCompletionHandlers() {
        let textView = makeTextView("one two one two")
        textView.findNextMatch("two", of: .contains, completionHandler: nil)
        XCTAssertEqual(textView.selectedRange(), range(4, 3))
        textView.findPreviousMatch("one", of: .contains, completionHandler: nil)
        XCTAssertEqual(textView.selectedRange(), range(0, 3))
    }

    /// The type is the scanner's, and a text view can use every one
    func testFindTypes() {
        let textView = makeTextView("One two once")
        XCTAssertEqual(findNext("one", in: textView), false)
        XCTAssertEqual(findNext("one", caseInsensitive, in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(0, 3))
        XCTAssertEqual(findNext("on", .beginsWith, in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(8, 2))
        XCTAssertEqual(findNext("t.o", .regexp, in: textView), true)
        XCTAssertEqual(textView.selectedRange(), range(4, 3))

        for type in [IFFindType.invalidType, .contains, .beginsWith, .completeWord, .regexp, caseInsensitive] {
            XCTAssertTrue(textView.canUse(type))
        }
    }

    /// The groups of the last regular expression found are kept for Replace, and shared by every text view
    func testLastFoundGroups() {
        let textView = makeTextView("one two")
        let other = makeTextView("")
        XCTAssertEqual(findNext("(t)(w)o", .regexp, in: textView), true)
        XCTAssertEqual(textView.lastFoundGroups, ["two", "t", "w"])
        XCTAssertEqual(other.lastFoundGroups, ["two", "t", "w"])

        XCTAssertEqual(findPrevious("o(n)e", .regexp, in: textView), true)
        XCTAssertEqual(textView.lastFoundGroups, ["one", "n"])

        XCTAssertEqual(findNext("one", in: textView), true)
        XCTAssertNil(textView.lastFoundGroups)
    }

    func testCurrentSelection() {
        let textView = makeTextView("one two one two")
        XCTAssertEqual(selection(in: textView), "")
        textView.setSelectedRange(range(4, 3))
        XCTAssertEqual(selection(in: textView), "two")
    }

    // MARK: - Find All

    func testFindingAll() throws {
        let textView = makeTextView("one two\nthree one")
        let results = try XCTUnwrap(textView.findAllMatches("one", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        XCTAssertEqual(results.map(\.fileRange), [range(0, 3), range(14, 3)])
        for result in results {
            XCTAssertNil(result.filepath)
            XCTAssertEqual(result.locationType, .currentPage)
            XCTAssertEqual((result.context as NSString).substring(with: result.contextRange), "one")
            XCTAssertNil(result.regexFoundGroups)
        }
        XCTAssertEqual(results.map(\.context), ["one two", "three one"])

        // Finding all doesn't move the selection
        XCTAssertEqual(textView.selectedRange(), range(0, 0))

        XCTAssertEqual(textView.findAllMatches("four", of: .contains, in: .currentPage,
                                               in: findController, withIdentifier: 1)?.count, 0)
        XCTAssertNil(textView.findAllMatches("", of: .contains, in: .currentPage,
                                             in: findController, withIdentifier: 1))
    }

    /// Each search starts just after the start of the last match, as Find in Files does, so matches can overlap
    func testFindingAllOverlappingMatches() throws {
        let textView = makeTextView("aaaa")
        let results = try XCTUnwrap(textView.findAllMatches("aa", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        XCTAssertEqual(results.map(\.fileRange), [range(0, 2), range(1, 2), range(2, 2)])
    }

    /// Each result keeps its groups, and the last result's are kept for Replace
    func testFindingAllRegularExpressions() throws {
        let textView = makeTextView("one two\nthree once")
        let results = try XCTUnwrap(textView.findAllMatches("o(n)(c?)e", of: .regexp, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        XCTAssertEqual(results.map(\.fileRange), [range(0, 3), range(14, 4)])
        XCTAssertEqual(results.map(\.regexFoundGroups), [["one", "n", ""], ["once", "n", "c"]])
        XCTAssertEqual(textView.lastFoundGroups, ["once", "n", "c"])
    }

    func testHighlightingAResult() throws {
        let textView = makeTextView("one two one two")
        let results = try XCTUnwrap(textView.findAllMatches("one", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        textView.highlight(results[1])
        XCTAssertEqual(textView.selectedRange(), range(8, 3))
    }

    // MARK: - Replacing

    /// Replace replaces the selection, which can be undone and redone
    func testReplacing() {
        let undoGiver = UndoGiver()
        let textView = makeTextView("one two one two")
        textView.delegate = undoGiver
        textView.allowsUndo = true
        textView.setSelectedRange(range(4, 3))

        undoGiver.undo.beginUndoGrouping()
        textView.replaceFound(with: "2")
        undoGiver.undo.endUndoGrouping()
        XCTAssertEqual(textView.string, "one 2 one two")
        XCTAssertEqual(textView.selectedRange(), range(4, 1))
        XCTAssertEqual(undoGiver.undo.undoActionName, IFUtility.localizedString("Replace"))

        undoGiver.undo.undo()
        XCTAssertEqual(textView.string, "one two one two")
        XCTAssertEqual(textView.selectedRange(), range(4, 3))

        undoGiver.undo.redo()
        XCTAssertEqual(textView.string, "one 2 one two")
        XCTAssertEqual(textView.selectedRange(), range(4, 1))
    }

    /// With nothing selected, Replace inserts at the insertion point
    func testReplacingNothing() {
        let textView = makeTextView("one two")
        textView.setSelectedRange(range(3, 0))
        textView.replaceFound(with: "!")
        XCTAssertEqual(textView.string, "one! two")
        XCTAssertEqual(textView.selectedRange(), range(3, 1))
    }

    /// Replace All replaces each result, moving later ones by how much the earlier ones changed the length,
    /// and is undone in one go
    func testReplacingAll() throws {
        let undoGiver = UndoGiver()
        let textView = makeTextView("one two\nthree one")
        textView.delegate = undoGiver
        textView.allowsUndo = true
        let results = try XCTUnwrap(textView.findAllMatches("one", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))

        let (newResults, offset) = replaceAll(results, with: "1", in: textView)
        XCTAssertEqual(textView.string, "1 two\nthree 1")
        XCTAssertEqual(offset, -4)
        XCTAssertEqual(newResults.map { $0?.fileRange }, [range(0, 1), range(12, 1)])
        XCTAssertEqual(newResults.map { $0?.context }, ["1 two", "three 1"])
        XCTAssertEqual(newResults.map { $0?.contextRange }, [range(0, 1), range(6, 1)])
        XCTAssertEqual(newResults.map { $0?.locationType }, [.currentPage, .currentPage])
        XCTAssertEqual(textView.selectedRange(), range(12, 1))
        XCTAssertEqual(undoGiver.undo.undoActionName, IFUtility.localizedString("Replace All"))

        undoGiver.undo.undo()
        XCTAssertEqual(textView.string, "one two\nthree one")
        XCTAssertFalse(undoGiver.undo.canUndo)

        undoGiver.undo.redo()
        XCTAssertEqual(textView.string, "1 two\nthree 1")
    }

    /// A result whose text has changed since it was found isn't replaced
    func testReplacingAllAfterAnEdit() throws {
        let textView = makeTextView("one two one")
        let results = try XCTUnwrap(textView.findAllMatches("one", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        textView.textStorage?.replaceCharacters(in: range(8, 3), with: "ten")

        let (newResults, offset) = replaceAll(results, with: "1", in: textView)
        XCTAssertEqual(textView.string, "1 two ten")
        XCTAssertNotNil(newResults[0])
        XCTAssertNil(newResults[1])
        XCTAssertEqual(offset, -2)
    }

    /// Overlapping results can't all be replaced
    func testReplacingAllOverlappingMatches() throws {
        let textView = makeTextView("xaaaa")
        let results = try XCTUnwrap(textView.findAllMatches("aa", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        let (newResults, _) = replaceAll(results, with: "b", in: textView)
        XCTAssertEqual(textView.string, "xbb")
        XCTAssertEqual(newResults.map { $0 != nil }, [true, false, true])
    }

    /// Replacing a result with something shorter can move a later one that overlapped it to before the start of
    /// the text, which isn't replaced
    func testReplacingAllOverlappingMatchesAtTheStart() throws {
        let textView = makeTextView("  x")
        let results = try XCTUnwrap(textView.findAllMatches(" +", of: .regexp, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        XCTAssertEqual(results.map(\.fileRange), [range(0, 2), range(1, 1)])
        let (newResults, offset) = replaceAll(results, with: "", in: textView)
        XCTAssertEqual(textView.string, "x")
        XCTAssertEqual(newResults.map { $0 != nil }, [true, false])
        XCTAssertEqual(offset, -2)
    }

    /// Text that can't be edited, such as the compiler's output on the Errors page, isn't replaced
    func testReplacingTextThatCantBeEdited() throws {
        let textView = makeTextView("one two one")
        textView.isEditable = false
        textView.setSelectedRange(range(0, 3))
        textView.replaceFound(with: "1")
        XCTAssertEqual(textView.string, "one two one")
        XCTAssertEqual(textView.selectedRange(), range(0, 3))

        let results = try XCTUnwrap(textView.findAllMatches("one", of: .contains, in: .currentPage,
                                                            in: findController, withIdentifier: 1))
        let (newResults, offset) = replaceAll(results, with: "1", in: textView)
        XCTAssertEqual(textView.string, "one two one")
        XCTAssertEqual(newResults.map { $0 == nil }, [true, true])
        XCTAssertEqual(offset, 0)
    }

    // MARK: - AppKit's own set-up

    /// Nothing replaces NSTextView's own +initialize, which sets up its kill ring among other things
    func testNSTextViewKeepsItsOwnInitialize() throws {
        var count: UInt32 = 0
        let methods = try XCTUnwrap(class_copyMethodList(object_getClass(NSTextView.self), &count))
        defer { free(methods) }
        let initializers = (0..<Int(count)).filter { method_getName(methods[$0]) == NSSelectorFromString("initialize") }
        XCTAssertEqual(initializers.count, 1)
    }

    /// Control-K kills to the end of the paragraph, and Control-Y yanks it back
    func testKillingAndYanking() {
        let textView = makeTextView("hello world")
        textView.setSelectedRange(range(5, 0))
        textView.deleteToEndOfParagraph(nil)
        XCTAssertEqual(textView.string, "hello")
        textView.setSelectedRange(range(0, 0))
        textView.yank(nil)
        XCTAssertEqual(textView.string, " worldhello")
    }

    // MARK: - The find controller

    /// The find controller takes anything that responds to findNextMatch:ofType:completionHandler: as a delegate,
    /// and asks before using the optional methods
    func testATextViewIsAFindDelegate() {
        let textView = NSTextView()
        XCTAssertTrue(textView.conforms(to: IFFindDelegate.self))
        let selectors = [
            #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:)),
            #selector(IFFindDelegate.findPreviousMatch(_:of:completionHandler:)),
            #selector(IFFindDelegate.canUse(_:)),
            #selector(IFFindDelegate.currentSelectionForFind(completionHandler:)),
            #selector(IFFindDelegate.findAllMatches(_:of:in:in:withIdentifier:)),
            #selector(IFFindDelegate.highlight(_:)),
            #selector(IFFindDelegate.replaceFound(with:)),
            #selector(IFFindDelegate.beginReplaceAll(_:)),
            #selector(IFFindDelegate.replaceFindAllResult(_:with:offset:)),
            #selector(IFFindDelegate.finishedReplaceAll(_:)),
            #selector(getter: IFFindDelegate.lastFoundGroups),
        ]
        for selector in selectors {
            XCTAssertTrue(textView.responds(to: selector), NSStringFromSelector(selector))
        }
    }
}
