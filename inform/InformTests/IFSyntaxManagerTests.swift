//
//  IFSyntaxManagerTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSyntaxManagerTests: XCTestCase {

    private let source = """
        "Managed" by Tester

        [A comment.]
        Chapter 1 - The Start

        The Kitchen is a room.

        """

    /// A text storage registered for the test, and unregistered at the end.
    private func registered(_ text: String, name: String = "IFSyntaxManagerTests",
                            intelligence: IFSyntaxIntelligence? = nil) -> NSTextStorage {
        let storage = NSTextStorage(string: text)
        IFSyntaxManager.register(storage, name: name, type: .inform7, intelligence: intelligence, undoManager: nil)
        addTeardownBlock { IFSyntaxManager.unregisterTextStorage(storage) }
        return storage
    }

    /// A text view showing the storage, as the source page has.
    private func view(showing storage: NSTextStorage) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.layoutManager?.replaceTextStorage(storage)
        return textView
    }

    func testRegistering() throws {
        let storage = NSTextStorage(string: source)
        XCTAssertFalse(IFSyntaxManager.isRegistered(storage))
        XCTAssertNil(IFSyntaxManager.data(for: storage))

        let undo = UndoManager()
        let intelligence = IFNaturalIntel()
        IFSyntaxManager.register(storage, name: "Story", type: .inform6, intelligence: intelligence, undoManager: undo)
        XCTAssertTrue(IFSyntaxManager.isRegistered(storage))
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        XCTAssertTrue(data.textStorage === storage)
        XCTAssertEqual(data.name, "Story")
        XCTAssertEqual(data.type, .inform6)
        XCTAssertTrue(data.undoManager === undo)
        XCTAssertTrue(data.intelligence === intelligence)

        IFSyntaxManager.unregisterTextStorage(storage)
        XCTAssertFalse(IFSyntaxManager.isRegistered(storage))
        XCTAssertNil(IFSyntaxManager.data(for: storage))
    }

    func testRegisteringByFilename() throws {
        let types: [(String, IFHighlightType)] = [
            ("story.ni", .inform7), ("Locksmith.I7X", .inform7), ("Story", .inform7),
            ("Main.inf", .inform6), ("Parser.h", .inform6), ("Notes.txt", .none),
        ]
        for (filename, type) in types {
            let storage = NSTextStorage(string: source)
            IFSyntaxManager.register(storage, filename: filename, intelligence: nil, undoManager: nil)
            defer { IFSyntaxManager.unregisterTextStorage(storage) }

            let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
            XCTAssertEqual(data.name, filename)
            XCTAssertEqual(data.type, type, filename)
        }
    }

    func testEachStorageHasItsOwnData() throws {
        let first = registered(source)
        let second = registered(source)
        XCTAssertFalse(try XCTUnwrap(IFSyntaxManager.data(for: first)) === IFSyntaxManager.data(for: second))
    }

    func testRegisteringAgainReplacesTheData() throws {
        let storage = registered(source, name: "First")
        let first = try XCTUnwrap(IFSyntaxManager.data(for: storage))

        IFSyntaxManager.register(storage, name: "Second", type: .inform7, intelligence: nil, undoManager: nil)
        let second = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        XCTAssertFalse(first === second)
        XCTAssertEqual(second.name, "Second")
    }

    func testUnregisteringAStorageThatIsntRegistered() {
        let storage = registered(source)
        IFSyntaxManager.unregisterTextStorage(NSTextStorage(string: source))
        XCTAssertTrue(IFSyntaxManager.isRegistered(storage))
    }

    func testHighlightingAgain() throws {
        let storage = registered(source)
        let data = try XCTUnwrap(IFSyntaxManager.data(for: storage))
        let comment = (source as NSString).range(of: "[A comment.]")
        XCTAssertEqual(data.style(at: UInt(comment.location)), .comment)
        let highlighted = storage.attributes(at: comment.location, effectiveRange: nil) as NSDictionary
        XCTAssertNotEqual(highlighted.count, 0)

        let rehighlights: [(String, () -> Void)] = [
            ("highlight all", { IFSyntaxManager.highlightAll(storage, forceUpdateTabs: true) }),
            ("preferences changed", { IFSyntaxManager.preferencesChanged(storage) }),
        ]
        for (name, rehighlight) in rehighlights {
            // Take the highlighting away without the syntax data seeing
            storage.delegate = nil
            storage.setAttributes([:], range: NSRange(location: 0, length: storage.length))
            storage.delegate = data
            XCTAssertNotEqual(storage.attributes(at: comment.location, effectiveRange: nil) as NSDictionary, highlighted, name)

            rehighlight()
            XCTAssertEqual(storage.attributes(at: comment.location, effectiveRange: nil) as NSDictionary, highlighted, name)
        }
    }

    func testRestrictingAView() throws {
        let storage = registered(source)
        let textView = view(showing: storage)
        XCTAssertFalse(IFSyntaxManager.isRestricted(storage, for: textView))
        XCTAssertEqual(IFSyntaxManager.restrictedRange(storage, for: textView), NSRange(location: NSNotFound, length: 0))
        XCTAssertNil(IFSyntaxManager.restrictedTextStorage(storage, for: textView))
        XCTAssertTrue(IFSyntaxManager.registeredStorage(for: textView) === storage)

        let chapter = (source as NSString).range(of: "Chapter 1 - The Start\n")
        IFSyntaxManager.restrictStorage(storage, range: chapter, for: textView)
        XCTAssertTrue(IFSyntaxManager.isRestricted(storage, for: textView))
        XCTAssertEqual(IFSyntaxManager.restrictedRange(storage, for: textView), chapter)
        let shown = try XCTUnwrap(IFSyntaxManager.restrictedTextStorage(storage, for: textView))
        XCTAssertEqual(shown.string, "Chapter 1 - The Start\n")
        XCTAssertTrue(textView.textStorage === shown)
        XCTAssertTrue(IFSyntaxManager.registeredStorage(for: textView) === storage)

        // The view is left showing the restricted copy, now empty, until it's given the full text again
        IFSyntaxManager.removeRestriction(storage, for: textView)
        XCTAssertFalse(IFSyntaxManager.isRestricted(storage, for: textView))
        XCTAssertNil(IFSyntaxManager.restrictedTextStorage(storage, for: textView))
        XCTAssertEqual(textView.string, "")
        XCTAssertNil(IFSyntaxManager.registeredStorage(for: textView))
    }

    func testLines() {
        let storage = registered(source)
        XCTAssertEqual(IFSyntaxManager.textForLine(with: storage, lineNumber: 0), "\"Managed\" by Tester\n")
        XCTAssertEqual(IFSyntaxManager.textForLine(with: storage, lineNumber: 3), "Chapter 1 - The Start\n")
        XCTAssertEqual(IFSyntaxManager.textForLine(with: storage, lineNumber: 99), "")

        IFSyntaxManager.replaceLine(with: storage, lineNumber: 3, withLine: "Chapter 2 - The End\n")
        XCTAssertEqual(storage.string, source.replacingOccurrences(of: "Chapter 1 - The Start", with: "Chapter 2 - The End"))
    }

    func testIntelligenceData() throws {
        let storage = registered(source, intelligence: IFNaturalIntel())
        let intel = try XCTUnwrap(IFSyntaxManager.intelligenceData(for: storage))
        XCTAssertEqual(intel.firstSymbol?.name, "\"Managed\"")
        XCTAssertEqual(intel.firstSymbol?.next?.name, "Chapter 1 - The Start\n")

        let plain = registered(source)
        XCTAssertNil(try XCTUnwrap(IFSyntaxManager.intelligenceData(for: plain)).firstSymbol)
    }

    func testAStorageThatIsntRegistered() {
        let storage = NSTextStorage(string: source)
        let textView = view(showing: storage)
        let attributes = storage.attributes(at: 0, effectiveRange: nil) as NSDictionary
        XCTAssertFalse(IFSyntaxManager.isRestricted(storage, for: textView))
        XCTAssertEqual(IFSyntaxManager.restrictedRange(storage, for: textView), NSRange(location: 0, length: 0))
        XCTAssertNil(IFSyntaxManager.restrictedTextStorage(storage, for: textView))
        XCTAssertNil(IFSyntaxManager.registeredStorage(for: textView))
        XCTAssertNil(IFSyntaxManager.textForLine(with: storage, lineNumber: 0))
        XCTAssertNil(IFSyntaxManager.intelligenceData(for: storage))

        // Nothing changes
        IFSyntaxManager.restrictStorage(storage, range: NSRange(location: 0, length: 5), for: textView)
        IFSyntaxManager.removeRestriction(storage, for: textView)
        IFSyntaxManager.highlightAll(storage, forceUpdateTabs: true)
        IFSyntaxManager.preferencesChanged(storage)
        IFSyntaxManager.replaceLine(with: storage, lineNumber: 0, withLine: "Changed\n")
        XCTAssertTrue(textView.textStorage === storage)
        XCTAssertEqual(storage.string, source)
        XCTAssertEqual(storage.attributes(at: 0, effectiveRange: nil) as NSDictionary, attributes)
    }
}
