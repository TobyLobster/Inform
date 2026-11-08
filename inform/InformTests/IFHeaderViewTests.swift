//
//  IFHeaderViewTests.swift
//  InformTests
//

import XCTest

/// A header view delegate that records what it's told
private final class RecordingDelegate: NSObject, IFHeaderViewDelegate {
    private(set) var clicked: [IFHeaderNode] = []
    private(set) var updates: [(node: IFHeaderNode, title: String)] = []
    private(set) var refreshes: [IFHeaderController] = []

    func headerView(_ view: IFHeaderView, clickedOn node: IFHeaderNode) {
        clicked.append(node)
    }

    func headerView(_ view: IFHeaderView, update node: IFHeaderNode, withNewTitle newTitle: String) {
        updates.append((node, newTitle))
    }

    func refreshHeaders(_ controller: IFHeaderController) {
        refreshes.append(controller)
    }
}

/// A header view delegate that wants to be told nothing
private final class QuietDelegate: NSObject, IFHeaderViewDelegate {
}

final class IFHeaderViewTests: XCTestCase {

    // MARK: - Headings

    private func heading(_ name: String, level: Int32) -> IFIntelSymbol {
        let symbol = IFIntelSymbol()
        symbol.type = IFSectionSymbolType
        symbol.name = name
        symbol.relation = .onLevel
        symbol.levelDelta = level
        return symbol
    }

    /// A file with each heading on the line given, counted from 0
    private func file(_ headings: [(String, Int32, Int32)]) -> IFIntelFile {
        let file = IFIntelFile()
        for (name, level, line) in headings {
            file.add(heading(name, level: level), atLine: line)
        }
        return file
    }

    /// A story's title and headings, with an example, each heading with its line's newline, as the highlighter gives it
    private let story: [(String, Int32, Int32)] = [
        ("The Story", 0, 0),
        ("Part One - The Beginning\n", 3, 2),
        ("Chapter 1 - Arrival\n", 4, 4),
        ("Chapter 2 - Departure\n", 4, 8),
        ("Part Two - The End\n", 3, 12),
        ("Section A\n", 5, 14),
        ("Example: * Locks\n", 6, 16),
    ]

    private var controllers: [IFHeaderController] = []

    /// A view showing a file's headers, made as the header page makes it: its depth is set, and then its controller
    /// gives it the headers
    private func headerView(depth: Int32 = 5, file: IFIntelFile? = nil) -> IFHeaderView {
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.displayDepth = depth

        let controller = IFHeaderController()
        controller.update(fromIntelligence: file ?? self.file(story))
        controller.addHeaderView(view)
        controllers.append(controller)
        return view
    }

    /// A node's heading, without its newline
    private func name(_ node: IFHeaderNode) -> String {
        return node.header.headingName.trimmingCharacters(in: .newlines)
    }

    /// A node and those below it, with each one's children in brackets
    private func outline(_ node: IFHeaderNode) -> String {
        guard let children = node.children else {
            return name(node)
        }
        return name(node) + " (" + children.map { outline($0) }.joined(separator: ", ") + ")"
    }

    /// The node at or below the one given whose heading starts with the text given
    private func node(_ prefix: String, in node: IFHeaderNode) -> IFHeaderNode? {
        if node.header.headingName.hasPrefix(prefix) {
            return node
        }
        for child in node.children ?? [] {
            if let found = self.node(prefix, in: child) {
                return found
            }
        }
        return nil
    }

    private var contents: String { IFUtility.localizedString("HeaderPage") }
    private var margin: CGFloat { CGFloat(UserDefaults.standard.double(forKey: "IFHeaderMargin")) }
    private var indent: CGFloat { CGFloat(UserDefaults.standard.double(forKey: "IFHeaderIndent")) }

    // MARK: - Events

    /// A mouse event at a point in a view
    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in view: NSView) -> NSEvent {
        return NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0,
                                  clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    }

    /// Clicks a point in a view. The window makes the view the first responder first, as it accepts it, which ends
    /// any edit. A click that starts an edit gives the field editor the mouse down, and the field editor follows the
    /// mouse until it's released, so the release is queued first.
    private func click(_ view: IFHeaderView, at point: NSPoint) {
        view.window?.makeFirstResponder(view)
        NSApp.postEvent(mouseEvent(.leftMouseUp, at: point, in: view), atStart: false)
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: point, in: view))
        // Take the release off the queue if nothing did
        while let event = NSApp.nextEvent(matching: .leftMouseUp, until: nil, inMode: .default, dequeue: true) {
            _ = event
        }
    }

    /// A window, never shown, for a view whose headings are edited, as the field editor is the window's
    private func window(for view: IFHeaderView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        addTeardownBlock {
            window.contentView = nil
            window.close()
        }
        return window
    }

    // MARK: - A new view

    func testANewView() {
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        XCTAssertEqual(view.displayDepth, 5)
        XCTAssertEqual(view.backgroundColour, NSColor.white)
        XCTAssertNil(view.message)
        XCTAssertTrue(view.isFlipped)
        XCTAssertTrue(view.acceptsFirstResponder)
        // A root node for no headers
        XCTAssertEqual(view.rootHeaderNode.header.headingName, "")
        XCTAssertNil(view.rootHeaderNode.children)
        XCTAssertEqual(view.rootHeaderNode.frame, .zero)
    }

    /// The header page sets a new view's depth before there are any headers to show
    func testAViewWithNoHeadersYet() {
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        view.displayDepth = 3

        XCTAssertEqual(view.message, IFUtility.localizedString("NoHeadingsSet"))
        XCTAssertEqual(view.rootHeaderNode.header.headingName, "")
        XCTAssertNil(view.rootHeaderNode.children)
        XCTAssertEqual(view.frame.size, NSSize(width: 200, height: view.rootHeaderNode.frame.height + 5))
    }

    // MARK: - The headers shown

    func testTheHeadersShown() {
        let view = headerView()
        XCTAssertNil(view.message)
        // The deepest level shows examples too
        XCTAssertEqual(outline(view.rootHeaderNode),
                       "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, Chapter 2 - Departure), "
                       + "Part Two - The End (Section A (Example: * Locks))))")

        view.displayDepth = 4
        XCTAssertEqual(outline(view.rootHeaderNode),
                       "\(contents) (The Story (Part One - The Beginning (Chapter 1 - Arrival, Chapter 2 - Departure), "
                       + "Part Two - The End))")
        view.displayDepth = 3
        XCTAssertEqual(outline(view.rootHeaderNode),
                       "\(contents) (The Story (Part One - The Beginning, Part Two - The End))")
        view.displayDepth = 1
        XCTAssertEqual(outline(view.rootHeaderNode), "\(contents) (The Story)")
        XCTAssertNil(view.message)
        XCTAssertEqual(view.displayDepth, 1)
    }

    /// The message for no headings is only shown when the view shows nothing below the top header, but the story's
    /// header is always below it (see ToFix.md)
    func testTheMessagesForNoHeadings() {
        let titleOnly = headerView(file: file([("The Story", 0, 0)]))
        XCTAssertNil(titleOnly.message)
        XCTAssertEqual(outline(titleOnly.rootHeaderNode), "\(contents) (The Story)")

        // No depth in the depth menu shows nothing below the top header
        let view = headerView(depth: 0)
        XCTAssertEqual(view.message, IFUtility.localizedString("NoHeadingsVisible"))
        view.displayDepth = 1
        XCTAssertNil(view.message)
    }

    func testTheViewIsAsTallAsItsHeadings() {
        let view = headerView()
        XCTAssertEqual(view.frame.size, NSSize(width: 400, height: view.rootHeaderNode.frame.height + 5))

        view.displayDepth = 3
        XCTAssertEqual(view.frame.size, NSSize(width: 400, height: view.rootHeaderNode.frame.height + 5))
    }

    /// A message fills the scroll view it's in
    func testAMessageFillsTheScrollView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 500))
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        scrollView.documentView = view

        view.displayDepth = 5
        XCTAssertNotNil(view.message)
        XCTAssertEqual(view.frame.size, scrollView.contentSize)
        XCTAssertTrue(view.autoresizingMask.contains(.height))

        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        controller.addHeaderView(view)
        XCTAssertNil(view.message)
        XCTAssertEqual(view.frame.height, view.rootHeaderNode.frame.height + 5)
        XCTAssertFalse(view.autoresizingMask.contains(.height))
    }

    func testAnEmptyMessageIsNone() {
        let view = headerView()
        view.message = ""
        XCTAssertNil(view.message)
        view.message = "Hello"
        XCTAssertEqual(view.message, "Hello")
    }

    func testTheDelegateIsToldTheHeadersHaveChanged() {
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let delegate = RecordingDelegate()
        view.delegate = delegate

        let controller = IFHeaderController()
        controller.update(fromIntelligence: file(story))
        controller.addHeaderView(view)
        XCTAssertEqual(delegate.refreshes, [controller])

        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(delegate.refreshes, [controller, controller])

        // A delegate that doesn't want to know isn't told
        let quiet = QuietDelegate()
        view.delegate = quiet
        controller.update(fromIntelligence: file(story))
        XCTAssertEqual(delegate.refreshes.count, 2)
    }

    func testColours() {
        let view = headerView()
        view.setColours(NSColor.red)
        XCTAssertEqual(view.backgroundColour, NSColor.red)
        view.backgroundColour = NSColor.blue
        XCTAssertEqual(view.backgroundColour, NSColor.blue)
    }

    // MARK: - Drawing

    private func drawn(_ view: NSView) -> NSBitmapImageRep {
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    /// The colour drawn at a point in a view
    private func colour(_ bitmap: NSBitmapImageRep, at point: NSPoint, in view: NSView) -> [CGFloat]? {
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        guard let colour = bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB)
        else {
            return nil
        }
        return [colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent]
    }

    private func rgba(_ colour: NSColor) -> [CGFloat] {
        let colour = colour.usingColorSpace(.sRGB)!
        return [colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent]
    }

    private func assertColour(_ actual: [CGFloat]?, _ expected: [CGFloat], _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("No colour: " + message, file: file, line: line)
            return
        }
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a, e, accuracy: 0.02, message, file: file, line: line)
        }
    }

    func testTheBackgroundAndTheHeadingsAreDrawn() {
        let view = headerView()
        view.backgroundColour = NSColor(srgbRed: 1, green: 1, blue: 0.8, alpha: 1)
        let bitmap = drawn(view)

        // Away from the headings, the background
        let corner = NSPoint(x: view.bounds.maxX - 5, y: view.bounds.maxY - 2)
        assertColour(colour(bitmap, at: corner, in: view), [1, 1, 0.8, 1], "background")

        // Somewhere in the first part's heading, the heading
        let title = node("Part One", in: view.rootHeaderNode)!.headerTitleRect
        var found = false
        for x in stride(from: title.minX, to: title.maxX, by: 1) {
            if let drawn = colour(bitmap, at: NSPoint(x: x, y: title.midY), in: view),
               zip(drawn, [1, 1, 0.8, 1]).contains(where: { abs($0 - $1) > 0.1 }) {
                found = true
                break
            }
        }
        XCTAssertTrue(found)
    }

    func testAMessageIsDrawnInTheThemesTextColour() {
        let view = IFHeaderView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.backgroundColour = NSColor.white
        view.displayDepth = 5
        view.message = String(repeating: "\u{2588}", count: 30)
        let bitmap = drawn(view)

        let theme = IFPreferences.shared.getCurrentTheme()
        let mainText = rgba(theme.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)].colour)

        // The message, of solid blocks, is centred, starting 8 points from the top, so the darkest pixel in the middle
        // of its first line is the text's colour
        var darkest: [CGFloat] = [1, 1, 1, 1]
        for y in 8..<24 {
            for x in 190..<210 {
                if let drawn = colour(bitmap, at: NSPoint(x: CGFloat(x), y: CGFloat(y)), in: view),
                   drawn[0] + drawn[1] + drawn[2] < darkest[0] + darkest[1] + darkest[2] {
                    darkest = drawn
                }
            }
        }
        assertColour(darkest, mainText, "message")
    }

    // MARK: - The mouse

    func testClickingAHeading() {
        let view = headerView()
        let delegate = RecordingDelegate()
        view.delegate = delegate
        let part = node("Part One", in: view.rootHeaderNode)!
        let title = part.headerTitleRect

        // Its bullet and first word, which can't be edited
        click(view, at: NSPoint(x: margin + 2 * indent + 1, y: title.midY))
        XCTAssertEqual(delegate.clicked, [part])

        // The story's header
        let story = node("The Story", in: view.rootHeaderNode)!
        click(view, at: NSPoint(x: margin + indent + 1, y: story.frame.minY + 2))
        XCTAssertEqual(delegate.clicked, [part, story])

        // Nothing
        click(view, at: NSPoint(x: 1, y: title.midY))
        click(view, at: NSPoint(x: margin + 1, y: view.rootHeaderNode.frame.maxY + 2))
        XCTAssertEqual(delegate.clicked, [part, story])
        XCTAssertEqual(delegate.updates.count, 0)
    }

    /// When nothing is shown below the top header, clicking it does nothing
    func testClickingWhenNoHeadingsAreShown() {
        let view = headerView(depth: 0)
        let delegate = RecordingDelegate()
        view.delegate = delegate
        click(view, at: NSPoint(x: margin + 1, y: 2))
        XCTAssertEqual(delegate.clicked, [])
    }

    func testEditingAHeading() throws {
        let view = headerView()
        let window = window(for: view)
        let delegate = RecordingDelegate()
        view.delegate = delegate
        let part = node("Part One", in: view.rootHeaderNode)!
        let title = part.headerTitleRect

        click(view, at: NSPoint(x: title.minX + 2, y: title.midY))
        XCTAssertEqual(delegate.clicked, [])

        // The window's field editor edits the part of the heading that can be edited, over the node, to the edge of
        // the view
        let editor = try XCTUnwrap(view.subviews.first as? NSTextView)
        XCTAssertIdentical(editor, window.fieldEditor(false, for: nil))
        XCTAssertIdentical(window.firstResponder, editor)
        XCTAssertEqual(editor.string, "One - The Beginning")
        // (AppKit puts the editor on whole points, and makes it as tall as its text)
        XCTAssertEqual(editor.frame.minX, title.minX, accuracy: 1)
        XCTAssertEqual(editor.frame.minY, title.minY, accuracy: 1)
        XCTAssertEqual(editor.frame.maxX, 400, accuracy: 1)
        XCTAssertEqual(editor.frame.height, title.height, accuracy: 1)
        XCTAssertIdentical(editor.delegate, view)
        XCTAssertFalse(editor.isRichText)
        XCTAssertFalse(editor.drawsBackground)
        assertColour(rgba(editor.backgroundColor), rgba(part.textBackgroundColour!), "editor background")
        XCTAssertEqual(editor.typingAttributes[.font] as? NSFont, part.attributes[.font] as? NSFont)
        XCTAssertEqual(editor.typingAttributes[.foregroundColor] as? NSColor,
                       part.attributes[.foregroundColor] as? NSColor)
        XCTAssertEqual(part.selectionStyle, .inputCursor)
        XCTAssertTrue(part.isEditing)

        // Return ends the edit, with the heading's new line for the source
        editor.string = "One - The Start"
        editor.insertNewline(nil)
        XCTAssertEqual(delegate.updates.count, 1)
        XCTAssertIdentical(delegate.updates.first?.node, part)
        XCTAssertEqual(delegate.updates.first?.title, "Part One - The Start\n")

        XCTAssertNil(editor.superview)
        XCTAssertEqual(part.selectionStyle, .unselected)
        XCTAssertFalse(part.isEditing)
        // The nodes are made again
        XCTAssertNotNil(node("Part One", in: view.rootHeaderNode))
        XCTAssertNotIdentical(node("Part One", in: view.rootHeaderNode), part)
    }

    /// Making something else the first responder ends an edit
    func testAnEditEndsWhenTheEditorIsNoLongerTheFirstResponder() throws {
        let view = headerView()
        let window = window(for: view)
        let delegate = RecordingDelegate()
        view.delegate = delegate
        let chapter = node("Chapter 1", in: view.rootHeaderNode)!

        click(view, at: NSPoint(x: chapter.headerTitleRect.minX + 2, y: chapter.headerTitleRect.midY))
        let editor = try XCTUnwrap(view.subviews.first as? NSTextView)
        editor.string = "3 - Elsewhere"
        window.makeFirstResponder(view)

        XCTAssertEqual(delegate.updates.count, 1)
        XCTAssertIdentical(delegate.updates.first?.node, chapter)
        XCTAssertEqual(delegate.updates.first?.title, "Chapter 3 - Elsewhere\n")
        XCTAssertNil(editor.superview)
    }

    /// Clicking another heading while one is edited ends that edit, and edits the other
    func testEditingAnotherHeading() throws {
        let view = headerView()
        _ = window(for: view)
        let delegate = RecordingDelegate()
        view.delegate = delegate
        let part = node("Part One", in: view.rootHeaderNode)!
        let chapterTitle = node("Chapter 1", in: view.rootHeaderNode)!.headerTitleRect

        click(view, at: NSPoint(x: part.headerTitleRect.minX + 2, y: part.headerTitleRect.midY))
        click(view, at: NSPoint(x: chapterTitle.minX + 2, y: chapterTitle.midY))

        XCTAssertEqual(delegate.updates.count, 1)
        XCTAssertIdentical(delegate.updates.first?.node, part)
        XCTAssertEqual(delegate.updates.first?.title, "Part One - The Beginning\n")
        XCTAssertEqual(part.selectionStyle, .unselected)
        XCTAssertFalse(part.isEditing)

        // Ending the edit made the nodes again, and the chapter's new node is edited
        let chapter = node("Chapter 1", in: view.rootHeaderNode)!
        XCTAssertEqual(chapter.selectionStyle, .inputCursor)
        XCTAssertTrue(chapter.isEditing)
        let editor = try XCTUnwrap(view.subviews.first as? NSTextView)
        XCTAssertEqual(view.subviews.count, 1)
        XCTAssertEqual(editor.string, "1 - Arrival")
    }

    /// New headers end an edit
    func testNewHeadersEndAnEdit() throws {
        let view = headerView()
        _ = window(for: view)
        let delegate = RecordingDelegate()
        view.delegate = delegate
        let part = node("Part One", in: view.rootHeaderNode)!
        click(view, at: NSPoint(x: part.headerTitleRect.minX + 2, y: part.headerTitleRect.midY))
        XCTAssertEqual(view.subviews.count, 1)
        (view.subviews.first as? NSTextView)?.string = "One - Changed"

        controllers.last!.update(fromIntelligence: file(story))
        XCTAssertEqual(view.subviews.count, 0)
        // Taking the editor away ends the edit, and what was typed is kept
        XCTAssertEqual(delegate.updates.count, 1)
        XCTAssertIdentical(delegate.updates.first?.node, part)
        XCTAssertEqual(delegate.updates.first?.title, "Part One - Changed\n")
        XCTAssertEqual(part.selectionStyle, .unselected)
        XCTAssertFalse(part.isEditing)
    }

    func testThePointer() {
        let view = headerView()
        let part = node("Part One", in: view.rootHeaderNode)!
        let title = part.headerTitleRect

        view.mouseMoved(with: mouseEvent(.mouseMoved, at: NSPoint(x: title.minX + 2, y: title.midY), in: view))
        XCTAssertEqual(NSCursor.current, NSCursor.iBeam)
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: NSPoint(x: margin + 2 * indent + 1, y: title.midY), in: view))
        XCTAssertEqual(NSCursor.current, NSCursor.pointingHand)
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: NSPoint(x: 1, y: title.midY), in: view))
        XCTAssertEqual(NSCursor.current, NSCursor.arrow)

        // With nothing shown below the top header
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: NSPoint(x: title.minX + 2, y: title.midY), in: view))
        view.displayDepth = 0
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: NSPoint(x: margin + 1, y: 2), in: view))
        XCTAssertEqual(NSCursor.current, NSCursor.arrow)
    }
}
