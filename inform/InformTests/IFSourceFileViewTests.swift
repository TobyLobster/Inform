//
//  IFSourceFileViewTests.swift
//  InformTests
//

import XCTest

final class IFSourceFileViewTests: XCTestCase {

    /// A delegate that can go to the previous and next sections, as the Source page does, and records when it's asked
    private final class Navigator: NSObject, NSTextViewDelegate, IFSourceNavigation {
        var calls: [String] = []
        var senders: [AnyObject?] = []

        func sourceFileShowPreviousSection(_ sender: Any?) {
            calls.append("previous")
            senders.append(sender as AnyObject?)
        }

        func sourceFileShowNextSection(_ sender: Any?) {
            calls.append("next")
            senders.append(sender as AnyObject?)
        }
    }

    /// A delegate that can't
    private final class OtherDelegate: NSObject, NSTextViewDelegate {
    }

    private var window: NSWindow!
    private var textView: IFSourceFileView!
    private var navigator: Navigator!

    private let topTearHeight = NSImage(named: "App/TornPages/torn_top")?.size.height ?? 0
    private let bottomTearHeight = NSImage(named: "App/TornPages/torn_bottom")?.size.height ?? 0

    override func setUp() {
        super.setUp()
        // NSWindow moves a window made off the screen onto it, so it's moved off afterwards, so that the mouse is
        // never over the view
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))

        // As the Source page makes it
        let textStorage = NSTextStorage(string: "one\ntwo\nthree")
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: 500, height: 400))
        layoutManager.addTextContainer(textContainer)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        let contentSize = scrollView.contentSize

        textView = IFSourceFileView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
                                    textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat(Float.greatestFiniteMagnitude),
                                  height: CGFloat(Float.greatestFiniteMagnitude))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.isRichText = false
        textView.enabledTextCheckingTypes = 0
        textView.textContainer?.containerSize = NSSize(width: contentSize.width,
                                                       height: CGFloat(Float.greatestFiniteMagnitude))
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 3, height: 6)

        navigator = Navigator()
        textView.delegate = navigator

        scrollView.documentView = textView
        window.contentView?.addSubview(scrollView)
        textView.layoutManager?.ensureLayout(for: textContainer)
    }

    override func tearDown() {
        textView.delegate = nil
        window.close()
        window = nil
        textView = nil
        navigator = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags = [],
                            clickCount: Int = 1) -> NSEvent {
        return NSEvent.mouseEvent(with: type, location: textView.convert(point, to: nil), modifierFlags: modifiers,
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                  clickCount: clickCount, pressure: type == .leftMouseUp ? 0 : 1)!
    }

    /// Clicks a point in the view. A click the text view handles follows the mouse until it's released, so the
    /// release is queued first, and taken off the queue afterwards if nothing did.
    private func click(at point: NSPoint, modifiers: NSEvent.ModifierFlags = [], clickCount: Int = 1) {
        window.makeFirstResponder(textView)
        NSApp.postEvent(mouseEvent(.leftMouseUp, at: point, modifiers: modifiers, clickCount: clickCount),
                        atStart: false)
        textView.mouseDown(with: mouseEvent(.leftMouseDown, at: point, modifiers: modifiers, clickCount: clickCount))
        while NSApp.nextEvent(matching: .leftMouseUp, until: nil, inMode: .default, dequeue: true) != nil {
        }
    }

    private func moveMouse(to point: NSPoint) {
        textView.mouseMoved(with: mouseEvent(.mouseMoved, at: point))
    }

    /// Where the text ends, below which the bottom tear is
    private var endOfText: CGFloat {
        let usedRect = textView.layoutManager!.usedRect(for: textView.textContainer!)
        return textView.textContainerOrigin.y + usedRect.maxY
    }

    /// The view drawn into a bitmap
    private func picture() -> NSBitmapImageRep {
        let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds)!
        textView.cacheDisplay(in: textView.bounds, to: rep)
        return rep
    }

    /// The colour at a point in the view, in a picture of it
    private func colour(in rep: NSBitmapImageRep, at point: NSPoint) -> NSColor? {
        let scale = CGFloat(rep.pixelsWide) / textView.bounds.width
        return rep.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.deviceRGB)
    }

    private func isWhite(_ colour: NSColor?) -> Bool {
        guard let colour else { return false }
        return colour.redComponent > 0.99 && colour.greenComponent > 0.99 && colour.blueComponent > 0.99
    }

    // MARK: - Tearing

    func testTheImagesAreThere() {
        XCTAssertGreaterThan(topTearHeight, 0)
        XCTAssertGreaterThan(bottomTearHeight, 0)
        XCTAssertNotNil(NSImage(named: "App/TornPages/TearArrow"))
    }

    func testAViewThatIsntTorn() {
        XCTAssertEqual(textView.textContainerOrigin, NSPoint(x: 3, y: 6))
        XCTAssertEqual(textView.textContainerInset, NSSize(width: 3, height: 6))
    }

    func testTearingTheTopMovesTheTextDown() {
        textView.setTornAtTop(true)

        XCTAssertEqual(textView.textContainerOrigin, NSPoint(x: 3, y: 6 + topTearHeight))
        XCTAssertEqual(textView.textContainerInset, NSSize(width: 3, height: floor((6 + floor(topTearHeight)) / 2)))
    }

    func testTearingTheBottomLeavesTheTextWhereItIs() {
        textView.setTornAtBottom(true)

        XCTAssertEqual(textView.textContainerOrigin, NSPoint(x: 3, y: 6))
        XCTAssertEqual(textView.textContainerInset, NSSize(width: 3, height: floor((6 + floor(bottomTearHeight)) / 2)))
    }

    func testTearingBoth() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        XCTAssertEqual(textView.textContainerOrigin, NSPoint(x: 3, y: 6 + topTearHeight))
        XCTAssertEqual(textView.textContainerInset,
                       NSSize(width: 3, height: floor((6 + floor(topTearHeight) + floor(bottomTearHeight)) / 2)))
    }

    func testMendingBoth() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        textView.setTornAtTop(false)
        textView.setTornAtBottom(false)

        XCTAssertEqual(textView.textContainerOrigin, NSPoint(x: 3, y: 6))
        XCTAssertEqual(textView.textContainerInset, NSSize(width: 3, height: 3))
    }

    func testTearingAgainChangesNothing() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)
        textView.textContainerInset = NSSize(width: 1, height: 2)

        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        XCTAssertEqual(textView.textContainerInset, NSSize(width: 1, height: 2))
    }

    func testMendingWhatIsntTornChangesNothing() {
        textView.setTornAtTop(false)
        textView.setTornAtBottom(false)

        XCTAssertEqual(textView.textContainerInset, NSSize(width: 3, height: 6))
    }

    // MARK: - Drawing

    func testNothingIsDrawnAtTheTopUntilItsTorn() {
        textView.string = ""
        let band = stride(from: 1, to: Int(topTearHeight) - 1, by: 2).map { NSPoint(x: 250, y: CGFloat($0)) }
            + stride(from: 5, to: Int(textView.bounds.width), by: 20).map { NSPoint(x: CGFloat($0), y: topTearHeight / 2) }

        let before = picture()
        XCTAssertTrue(band.allSatisfy { isWhite(colour(in: before, at: $0)) })

        textView.setTornAtTop(true)
        let after = picture()
        XCTAssertFalse(band.allSatisfy { isWhite(colour(in: after, at: $0)) }, "Nothing was drawn for the tear")
    }

    func testBelowTheBottomTearIsPaper() throws {
        let bottom = NSPoint(x: 10, y: textView.bounds.maxY - 3)
        XCTAssertTrue(isWhite(colour(in: picture(), at: bottom)))

        textView.setTornAtBottom(true)

        let paper = try XCTUnwrap(colour(in: picture(), at: bottom))
        // The colour is in device RGB, and comes back from the picture a little changed
        XCTAssertEqual(paper.redComponent, 0.95, accuracy: 0.03)
        XCTAssertEqual(paper.greenComponent, 0.95, accuracy: 0.03)
        XCTAssertEqual(paper.blueComponent, 0.9, accuracy: 0.03)
    }

    // MARK: - Clicks

    func testAClickOnTheTopTearGoesToThePreviousSection() {
        textView.setTornAtTop(true)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        click(at: NSPoint(x: 250, y: topTearHeight / 2))

        XCTAssertEqual(navigator.calls, ["previous"])
        XCTAssertIdentical(navigator.senders.first ?? nil, textView)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
    }

    func testAClickOnTheBottomTearGoesToTheNextSection() {
        textView.setTornAtBottom(true)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        click(at: NSPoint(x: 250, y: endOfText + 5))

        XCTAssertEqual(navigator.calls, ["next"])
        XCTAssertIdentical(navigator.senders.first ?? nil, textView)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
    }

    func testAClickAnywhereOnTheTopTearGoesToThePreviousSection() {
        textView.setTornAtTop(true)

        click(at: NSPoint(x: 2, y: 1))
        click(at: NSPoint(x: textView.bounds.maxX - 2, y: topTearHeight - 1))

        XCTAssertEqual(navigator.calls, ["previous", "previous"])
    }

    func testAClickInTheTextPlacesTheCursor() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        let point = NSPoint(x: 20, y: endOfText - 5)
        let index = textView.characterIndexForInsertion(at: point)
        XCTAssertGreaterThan(index, 0)

        click(at: point)

        XCTAssertEqual(navigator.calls, [])
        XCTAssertEqual(textView.selectedRange(), NSRange(location: index, length: 0))
    }

    func testAClickWhereTheTearsWouldBeIsAnOrdinaryClickWhenTheyArent() {
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        click(at: NSPoint(x: 250, y: 1))
        click(at: NSPoint(x: 250, y: endOfText + 5))

        XCTAssertEqual(navigator.calls, [])
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 13, length: 0))
    }

    func testAClickWithAModifierOnATearIsAnOrdinaryClick() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        for modifier in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
            click(at: NSPoint(x: 250, y: topTearHeight / 2), modifiers: modifier)
            click(at: NSPoint(x: 250, y: endOfText + 5), modifiers: modifier)
        }

        XCTAssertEqual(navigator.calls, [])
    }

    func testADoubleClickOnATearIsAnOrdinaryClick() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        click(at: NSPoint(x: 250, y: topTearHeight / 2), clickCount: 2)
        click(at: NSPoint(x: 250, y: endOfText + 5), clickCount: 2)

        XCTAssertEqual(navigator.calls, [])
    }

    func testAClickOnATearDoesNothingWithADelegateThatCantChangeSection() {
        let other = OtherDelegate()
        textView.delegate = other
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        click(at: NSPoint(x: 250, y: topTearHeight / 2))
        click(at: NSPoint(x: 250, y: endOfText + 5))

        XCTAssertEqual(navigator.calls, [])
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
        textView.delegate = nil
    }

    // MARK: - The cursor

    func testTheCursorIsAPointingHandOverTheTears() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        NSCursor.arrow.set()
        moveMouse(to: NSPoint(x: 250, y: topTearHeight / 2))
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)

        NSCursor.arrow.set()
        moveMouse(to: NSPoint(x: 250, y: endOfText + 5))
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)
        NSCursor.arrow.set()
    }

    func testTheCursorIsntAPointingHandOverTheText() {
        textView.setTornAtTop(true)
        textView.setTornAtBottom(true)

        NSCursor.arrow.set()
        moveMouse(to: NSPoint(x: 20, y: endOfText - 5))

        XCTAssertNotIdentical(NSCursor.current, NSCursor.pointingHand)
        NSCursor.arrow.set()
    }

    func testTheCursorIsntAPointingHandWhereTheTearsWouldBe() {
        NSCursor.arrow.set()
        moveMouse(to: NSPoint(x: 250, y: 1))
        XCTAssertNotIdentical(NSCursor.current, NSCursor.pointingHand)

        moveMouse(to: NSPoint(x: 250, y: endOfText + 5))
        XCTAssertNotIdentical(NSCursor.current, NSCursor.pointingHand)
        NSCursor.arrow.set()
    }

    // MARK: - Typing and the Touch Bar

    func testTypingInAWindowWithoutAProject() {
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                     timestamp: ProcessInfo.processInfo.systemUptime,
                                     windowNumber: window.windowNumber, context: nil, characters: "s",
                                     charactersIgnoringModifiers: "s", isARepeat: false, keyCode: 1)!

        textView.keyDown(with: event)

        XCTAssertEqual(textView.string, "ones\ntwo\nthree")
    }

    func testThereIsNoTouchBar() {
        XCTAssertNil(textView.makeTouchBar())
    }
}
