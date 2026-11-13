//
//  IFSkeinViewTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSkeinViewTests: XCTestCase {

    /// A skein view in a 700 by 500 scroll view, in a window that isn't shown, far off the screen so that the mouse
    /// is never over it.
    private func makeSkeinView(_ skein: IFSkein) -> (NSWindow, IFSkeinView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // NSWindow moves a window made off the screen onto it, so it's moved off afterwards
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        let skeinView = IFSkeinView(frame: scrollView.bounds)
        scrollView.documentView = skeinView
        window.contentView!.addSubview(scrollView)
        skeinView.skein = skein
        return (window, skeinView)
    }

    /// Adds a thread of knots below the given item, and returns the last one.
    private func addThread(to item: IFSkeinItem, skein: IFSkein, count: Int) -> IFSkeinItem {
        var last = item
        for i in 1...count {
            let child: IFSkeinItem = IFSkeinItem(skein: skein, command: "command \(i)")
            child.actual = "Output for command \(i)."
            last = last.addChild(child)
        }
        return last
    }

    /// The views that draw the knots.
    private func knotViews(_ skeinView: IFSkeinView) -> [NSView] {
        return skeinView.subviews.filter { NSStringFromClass(type(of: $0)) == "IFSkeinItemView" }
    }

    /// Selecting a thread shows its transcript beside the knots, without painting over them.
    func testTranscriptDoesNotCoverTheKnots() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let item = addThread(to: skein.rootItem, skein: skein, count: 4)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(item, withAnimation: false)

        let report = try XCTUnwrap(skeinView.subviews.first { $0 is IFSkeinReportView })
        XCTAssertGreaterThan(report.frame.minX, 0)

        let bitmap = try XCTUnwrap(skeinView.bitmapImageRepForCachingDisplay(in: skeinView.bounds))
        skeinView.cacheDisplay(in: skeinView.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / skeinView.bounds.width
        func colour(at point: NSPoint) -> NSColor? {
            return bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))
        }

        // The transcript's background, and a point to its left where the knots are
        let transcript = colour(at: NSPoint(x: report.frame.minX + 2, y: report.frame.minY + 2))
        let knots = colour(at: NSPoint(x: report.frame.minX / 2, y: report.frame.minY + 2))
        XCTAssertNotNil(transcript)
        XCTAssertNotEqual(transcript, knots)
    }

    /// Selecting a knot scrolls to it, rather than moving the skein view or jumping to the top left.
    func testSelectingAKnotKeepsItInView() throws {
        let skein: IFSkein = IFSkein(project: nil)
        for i in 1...25 {
            let child: IFSkeinItem = IFSkeinItem(skein: skein, command: "branch \(i)")
            child.actual = "Output for branch \(i)."
            skein.rootItem.addChild(child)
        }
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // Scroll to the rightmost knot, and select it
        let rightmost = try XCTUnwrap(knotViews(skeinView).max { $0.frame.maxX < $1.frame.maxX })
        skeinView.scrollToVisible(rightmost.frame)
        XCTAssertGreaterThan(skeinView.visibleRect.minX, 0)
        let item = try XCTUnwrap(skeinView.item(at: NSPoint(x: rightmost.frame.midX, y: rightmost.frame.midY)))
        skein.activeItem = item
        skeinView.select(item, withAnimation: false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        XCTAssertEqual(skeinView.frame.origin, .zero)
        let knot = try XCTUnwrap(knotViews(skeinView).first { $0.value(forKeyPath: "layoutItem.item") as? IFSkeinItem === item })
        XCTAssertTrue(skeinView.visibleRect.intersects(knot.frame))
    }

    /// Each transcript row fits its text after the selection moves between threads with shorter and longer output.
    func testTranscriptRowsFitTheirTextAfterChangingThreads() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let fork = addThread(to: skein.rootItem, skein: skein, count: 2)
        var short = fork
        var long = fork
        for i in 1...2 {
            let shortItem: IFSkeinItem = IFSkeinItem(skein: skein, command: "short \(i)")
            shortItem.actual = "Short output \(i)."
            short = short.addChild(shortItem)
            let longItem: IFSkeinItem = IFSkeinItem(skein: skein, command: "long \(i)")
            longItem.actual = String(repeating: "Long output \(i). ", count: 20)
            long = long.addChild(longItem)
        }
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        for leaf in [short, long, short] {
            skeinView.select(leaf, withAnimation: false)
            let report = try XCTUnwrap(skeinView.subviews.first { $0 is IFSkeinReportView })
            for case let row as IFSkeinReportItemView in report.subviews where row.textView.string.count > 0 {
                let text = try XCTUnwrap(row.textView.textStorage)
                let fit = text.boundingRect(with: NSSize(width: row.textView.frame.width, height: 10000),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading])
                XCTAssertEqual(row.textView.frame.height, ceil(fit.height), accuracy: 1, row.textView.string)
            }
        }
    }

    /// The lines between knots.
    private func lineViews(_ skeinView: IFSkeinView) -> [NSView] {
        return skeinView.subviews.filter { NSStringFromClass(type(of: $0)).hasSuffix("IFSkeinLinkView") }
    }

    /// Each line runs from the top of a knot up to the knot above it, from the first time the skein is laid out.
    func testLinesPointToTheKnotAbove() throws {
        let skein: IFSkein = IFSkein(project: nil)
        for name in ["a", "b", "c"] {
            var item: IFSkeinItem = skein.rootItem
            for i in 1...2 {
                item = item.addChild(IFSkeinItem(skein: skein, command: "\(name)\(i)"))
            }
        }
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let lines = lineViews(skeinView)
        XCTAssertEqual(lines.count, 6)
        for line in lines {
            let layer = try XCTUnwrap(line.layer)
            let angle = line.frameRotation * .pi / 180
            let start = layer.position
            let end = NSPoint(x: start.x + layer.bounds.width * cos(angle), y: start.y + layer.bounds.width * sin(angle))
            XCTAssertLessThan(end.y, start.y)
            XCTAssertTrue(knotViews(skeinView).contains { $0.frame.insetBy(dx: -3, dy: -3).contains(end) }, "\(end)")
        }
    }

    /// Selecting a thread makes the levels taller and so the lines between knots longer, with an animation.
    /// The line is its layer's contents stretched to fit, so that it's the right length all the way through.
    func testLinesStretchWithTheirLayers() {
        let skein: IFSkein = IFSkein(project: nil)
        let item = addThread(to: skein.rootItem, skein: skein, count: 4)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(item, withAnimation: false)
        let lines = lineViews(skeinView)
        XCTAssertEqual(lines.count, 4)
        for line in lines {
            // The window isn't shown, so display the layer here as the window would
            line.layer?.display()
            XCTAssertTrue(line.layer?.contents is NSImage)
            XCTAssertEqual(line.layer?.contentsGravity, .resize)
        }
    }

    /// A click on a knot that moves the mouse slightly is still a click, rather than the start of a drag.
    /// (Only the small movement is tested: a drag would start a real drag session on the screen.)
    func testSmallMovementDoesNotDragAKnot() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let item = addThread(to: skein.rootItem, skein: skein, count: 2)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let knot = try XCTUnwrap(knotViews(skeinView).first { $0.value(forKeyPath: "layoutItem.item") as? IFSkeinItem === item })
        let centre = knot.convert(NSPoint(x: knot.bounds.midX, y: knot.bounds.midY), to: nil)
        func event(_ type: NSEvent.EventType, at point: NSPoint) throws -> NSEvent {
            return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                                                    windowNumber: window.windowNumber, context: nil,
                                                    eventNumber: 0, clickCount: 1, pressure: 1))
        }

        knot.mouseDown(with: try event(.leftMouseDown, at: centre))
        knot.mouseDragged(with: try event(.leftMouseDragged, at: NSPoint(x: centre.x + 2, y: centre.y + 2)))
        XCTAssertNil(skein.draggingItem)
    }

    /// Laying the skein out again, as happens after every edit, keeps the scroll position.
    func testLayoutKeepsTheScrollPosition() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let item = addThread(to: skein.rootItem, skein: skein, count: 30)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // Show the thread's transcript, which makes the levels taller, and scroll to the bottom
        skeinView.select(item, withAnimation: false)
        skeinView.scroll(NSPoint(x: 0, y: skeinView.frame.height - skeinView.visibleRect.height))
        let scrolledTo = skeinView.visibleRect.origin
        XCTAssertGreaterThan(scrolledTo.y, 0)

        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertEqual(skeinView.visibleRect.origin, scrolledTo)
    }

    // MARK: - Helpers for the view's own work

    @discardableResult
    private func add(_ command: String, to parent: IFSkeinItem, in skein: IFSkein, actual: String = "",
                     testSubItem: Bool = false) -> IFSkeinItem {
        let item: IFSkeinItem = IFSkeinItem(skein: skein, command: command)
        item.actual = actual
        item.isTestSubItem = testSubItem
        return parent.addChild(item)
    }

    /// A skein of three levels (a knot's children are in alphabetical order):
    ///
    ///     - start -
    ///     ├── look
    ///     │   └── north
    ///     └── wait
    private func makeSkein() -> (skein: IFSkein, look: IFSkeinItem, north: IFSkeinItem, wait: IFSkeinItem) {
        let skein: IFSkein = IFSkein(project: nil)
        skein.rootItem.actual = "Welcome\n>"
        let look = add("look", to: skein.rootItem, in: skein, actual: "A room.\n>")
        let north = add("north", to: look, in: skein, actual: "A hall.\n>")
        let wait = add("wait", to: skein.rootItem, in: skein, actual: "Time passes.\n>")
        return (skein, look, north, wait)
    }

    /// A skein wider and taller than the skein view: 25 branches from the start, one of them 30 knots long
    private func makeLargeSkein() -> IFSkein {
        let skein: IFSkein = IFSkein(project: nil)
        for i in 1...25 {
            let branch = add("branch \(i)", to: skein.rootItem, in: skein, actual: "Output for branch \(i).")
            if i == 1 {
                _ = addThread(to: branch, skein: skein, count: 30)
            }
        }
        return skein
    }

    private func knot(_ item: IFSkeinItem, in skeinView: IFSkeinView) throws -> IFSkeinItemView {
        return try XCTUnwrap(skeinView.subviews.compactMap { $0 as? IFSkeinItemView }
                                               .first { $0.layoutItem?.item === item })
    }

    private func centre(of view: NSView) -> NSPoint {
        return NSPoint(x: view.frame.midX, y: view.frame.midY)
    }

    private func commands(_ item: IFSkeinItem) -> [String] {
        return item.children.map(\.command)
    }

    private func changes(of skein: IFSkein, _ block: () throws -> Void) rethrows -> Int {
        nonisolated(unsafe) var count = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFSkeinChanged, object: skein,
                                                              queue: nil) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        try block()
        return count
    }

    private func selectionChanges(of skeinView: IFSkeinView, _ block: () throws -> Void) rethrows -> [Notification] {
        nonisolated(unsafe) var notifications: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: .IFSkeinSelectionChanged, object: skeinView,
                                                              queue: nil) { notifications.append($0) }
        defer { NotificationCenter.default.removeObserver(observer) }
        try block()
        return notifications
    }

    /// A mouse event at a point in the window
    private func mouseEvent(_ type: NSEvent.EventType, at location: NSPoint, in window: NSWindow) throws -> NSEvent {
        return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0,
                                                windowNumber: window.windowNumber, context: nil,
                                                eventNumber: 0, clickCount: 1, pressure: 1))
    }

    // MARK: Menu helpers

    private func menuItem(_ title: String, for item: IFSkeinItem, in skeinView: IFSkeinView) throws -> NSMenuItem {
        return try XCTUnwrap(skeinView.menu(for: item).item(withTitle: IFUtility.localizedString(title)), title)
    }

    /// Chooses a command from a knot's menu, whether or not it's enabled
    private func choose(_ title: String, for item: IFSkeinItem, in skeinView: IFSkeinView) throws {
        let menuItem = try menuItem(title, for: item, in: skeinView)
        let action = try XCTUnwrap(menuItem.action)
        XCTAssertTrue(NSApp.sendAction(action, to: skeinView, from: menuItem))
    }

    /// The actions of the commands enabled in a knot's menu
    private func enabledActions(for item: IFSkeinItem, in skeinView: IFSkeinView) -> [String] {
        return skeinView.menu(for: item).items.filter { !$0.isSeparatorItem && $0.isEnabled }
                                              .compactMap { $0.action.map(NSStringFromSelector) }
    }

    private let allActions = ["playToHere:", "insertPreviousItem:", "insertNextItem:", "deleteOneItem:",
                              "editContextItem:", "setWinningCommandItem:", "addNewBranch:", "deleteItem:",
                              "blessItem:", "blessToHere:"]

    private func allActions(except excluded: [String]) -> [String] {
        return allActions.filter { !excluded.contains($0) }
    }

    // MARK: Editing helpers

    /// The field editor a command is being edited in
    private func fieldEditor(in window: NSWindow) throws -> NSTextView {
        let editor = try XCTUnwrap(window.firstResponder as? NSTextView)
        XCTAssertTrue(editor.isFieldEditor)
        return editor
    }

    /// Replaces the text of the command being edited, as typing would
    private func typeText(_ text: String, in window: NSWindow) throws {
        let editor = try fieldEditor(in: window)
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func isEditing(_ skeinView: IFSkeinView) -> Bool {
        return skeinView.subviews.contains { $0 is NSScrollView }
    }

    private final class Delegate: NSObject, IFSkeinViewDelegate {
        var calls: [String] = []

        private func name(_ item: IFSkeinItem) -> String {
            return item.parent == nil ? "start" : item.command
        }

        func stopGame() {
            calls.append("stop")
        }

        func play(toPoint point: IFSkeinItem, fromPoint currentPoint: IFSkeinItem) {
            calls.append("play to \(name(point)) from \(name(currentPoint))")
        }
    }

    // MARK: - A new view

    func testANewView() {
        let skeinView = IFSkeinView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNotNil(skeinView.skein)
        XCTAssertNotNil(skeinView.layoutTree.rootItem)
        XCTAssertIdentical(skeinView.layoutTree.rootItem, skeinView.skein?.rootItem)
        XCTAssertNil(skeinView.selectedItem)
        XCTAssertNil(skeinView.delegate)
        XCTAssertTrue(knotViews(skeinView).isEmpty)
        XCTAssertTrue(skeinView.wantsLayer)
        XCTAssertTrue(skeinView.isFlipped)
        XCTAssertTrue(skeinView.acceptsFirstResponder)
        XCTAssertTrue(skeinView.acceptsFirstMouse(for: nil))
    }

    // MARK: - The skein and the selection

    func testSettingTheSkein() throws {
        let (skein, look, north, _) = makeSkein()
        skein.activeItem = north
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // The skein is laid out, and nothing in it is active
        XCTAssertNil(skein.activeItem)
        XCTAssertIdentical(skeinView.layoutTree.rootItem, skein.rootItem)
        XCTAssertEqual(knotViews(skeinView).count, 4)

        // Setting the same skein again changes nothing
        skeinView.select(look, withAnimation: false)
        skein.activeItem = look
        skeinView.skein = skein
        XCTAssertIdentical(skeinView.selectedItem, look)
        XCTAssertIdentical(skein.activeItem, look)

        // Another skein: nothing in it is selected, and only its changes lay the view out
        let other: IFSkein = IFSkein(project: nil)
        let notifications = selectionChanges(of: skeinView) { skeinView.skein = other }
        XCTAssertNil(skeinView.selectedItem)
        XCTAssertTrue(notifications.isEmpty)
        XCTAssertIdentical(skeinView.layoutTree.rootItem, other.rootItem)
        XCTAssertEqual(knotViews(skeinView).count, 1)
        add("east", to: skein.rootItem, in: skein)
        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertEqual(knotViews(skeinView).count, 1)
        add("east", to: other.rootItem, in: other)
        other.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertEqual(knotViews(skeinView).count, 2)

        // No skein
        skeinView.skein = nil
        XCTAssertNil(skeinView.layoutTree.rootItem)
        XCTAssertTrue(knotViews(skeinView).isEmpty)
    }

    func testSettingTheSelectionPostsTheChange() throws {
        let (skein, look, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        var notifications = selectionChanges(of: skeinView) { skeinView.selectedItem = look }
        XCTAssertEqual(notifications.count, 1)
        XCTAssertIdentical(notifications.first?.userInfo?[IFSkeinSelectionChangedItemKey] as AnyObject?, look)

        notifications = selectionChanges(of: skeinView) { skeinView.selectedItem = look }
        XCTAssertTrue(notifications.isEmpty)

        notifications = selectionChanges(of: skeinView) { skeinView.selectedItem = nil }
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.userInfo?.count, 0)
    }

    func testSelectingAKnotLaysTheSkeinOutAgain() {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(north, withAnimation: false)
        XCTAssertIdentical(skeinView.selectedItem, north)
        XCTAssertIdentical(skeinView.layoutTree.selectedItem, north)
        XCTAssertTrue(skeinView.isReportVisible)

        skeinView.select(nil, withAnimation: false)
        XCTAssertNil(skeinView.selectedItem)
        XCTAssertNil(skeinView.layoutTree.selectedItem)
        XCTAssertFalse(skeinView.isReportVisible)
    }

    func testSelectingAKnotByItsId() {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        XCTAssertTrue(skeinView.selectItem(withNodeId: north.uniqueId))
        XCTAssertIdentical(skeinView.selectedItem, north)

        let unused = [skein.rootItem, look, north, wait].map(\.uniqueId).max()! + 1000
        XCTAssertFalse(skeinView.selectItem(withNodeId: unused))
        XCTAssertIdentical(skeinView.selectedItem, north)
    }

    func testTheKnotAtAPoint() throws {
        let (skein, look, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        XCTAssertIdentical(skeinView.item(at: centre(of: try knot(look, in: skeinView))), look)
        XCTAssertNil(skeinView.item(at: NSPoint(x: 5, y: skeinView.bounds.maxY - 5)))
    }

    func testASelectedKnotThatsRemovedGivesWayToTheActiveKnot() {
        let (skein, _, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(north, withAnimation: false)
        skein.activeItem = wait
        north.removeFromParent()
        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertIdentical(skeinView.selectedItem, wait)

        // ...or to nothing, if the active knot has gone too
        wait.removeFromParent()
        let notifications = selectionChanges(of: skeinView) {
            skein.postChanged(withAnimate: false, keepActiveVisible: false)
        }
        XCTAssertNil(skeinView.selectedItem)
        XCTAssertEqual(notifications.count, 1)
    }

    func testAChangeCanScrollToTheActiveKnot() throws {
        let skein = makeLargeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let rightmost = try XCTUnwrap(knotViews(skeinView).max { $0.frame.maxX < $1.frame.maxX })
        XCTAssertFalse(skeinView.visibleRect.intersects(rightmost.frame))
        skein.activeItem = try XCTUnwrap(skeinView.item(at: centre(of: rightmost)))

        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertFalse(skeinView.visibleRect.intersects(rightmost.frame))

        skein.postChanged(withAnimate: false, keepActiveVisible: true)
        XCTAssertTrue(skeinView.visibleRect.intersects(rightmost.frame))
    }

    func testTheViewFillsItsScrollView() throws {
        let small: IFSkein = IFSkein(project: nil)
        let (window, skeinView) = makeSkeinView(small)
        defer { window.close() }
        let clipSize = try XCTUnwrap(skeinView.superview).frame.size
        XCTAssertEqual(skeinView.frame.size, clipSize)

        skeinView.skein = makeLargeSkein()
        XCTAssertGreaterThan(skeinView.layoutTree.size.width, clipSize.width)
        XCTAssertGreaterThan(skeinView.layoutTree.size.height, clipSize.height)
        XCTAssertEqual(skeinView.frame.size, skeinView.layoutTree.size)
    }

    // MARK: - The mouse

    func testTheTrackingArea() throws {
        let (skein, _, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.updateTrackingAreas()
        XCTAssertEqual(skeinView.trackingAreas.count, 1)
        let area = try XCTUnwrap(skeinView.trackingAreas.first)
        XCTAssertEqual(area.rect, skeinView.visibleRect)
        XCTAssertEqual(area.options, [.cursorUpdate, .activeInKeyWindow])
        XCTAssertIdentical(area.owner as AnyObject?, skeinView)

        // Updating it replaces it
        skeinView.updateTrackingAreas()
        XCTAssertEqual(skeinView.trackingAreas.count, 1)
        XCTAssertNotIdentical(skeinView.trackingAreas.first, area)
    }

    func testDraggingTheBackgroundScrollsTheSkein() throws {
        let skein = makeLargeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.cursorUpdate(with: try mouseEvent(.mouseMoved, at: .zero, in: window))
        XCTAssertEqual(NSCursor.current, NSCursor.openHand)

        let start = skeinView.visibleRect
        let location = skeinView.convert(NSPoint(x: start.midX, y: start.midY), to: nil)
        skeinView.mouseDown(with: try mouseEvent(.leftMouseDown, at: location, in: window))
        XCTAssertEqual(NSCursor.current, NSCursor.closedHand)

        // Dragging left and up moves the skein with the mouse, showing more of it to the right and below
        let moved = NSPoint(x: location.x - 100, y: location.y + 50)
        skeinView.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: moved, in: window))
        XCTAssertEqual(skeinView.visibleRect.origin, NSPoint(x: start.minX + 100, y: start.minY + 50))
        XCTAssertEqual(NSCursor.current, NSCursor.closedHand)

        skeinView.mouseUp(with: try mouseEvent(.leftMouseUp, at: moved, in: window))
        XCTAssertEqual(NSCursor.current, NSCursor.openHand)

        // Once the mouse is up, a drag does nothing
        skeinView.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: location, in: window))
        XCTAssertEqual(skeinView.visibleRect.origin, NSPoint(x: start.minX + 100, y: start.minY + 50))
    }

    func testTheSkeinDoesntBounce() throws {
        let (skein, _, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        let scrollView = try XCTUnwrap(skeinView.enclosingScrollView)
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .allowed

        skeinView.awakeFromNib()
        XCTAssertEqual(scrollView.horizontalScrollElasticity, .none)
        XCTAssertEqual(scrollView.verticalScrollElasticity, .none)
    }

    func testRightClickingAKnotShowsItsMenu() throws {
        let (skein, look, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let onKnot = skeinView.convert(centre(of: try knot(look, in: skeinView)), to: nil)
        let menu = try XCTUnwrap(skeinView.menu(for: try mouseEvent(.rightMouseDown, at: onKnot, in: window)))
        XCTAssertNotNil(menu.item(withTitle: IFUtility.localizedString("Play to Here")))

        let offKnot = skeinView.convert(NSPoint(x: 5, y: skeinView.bounds.maxY - 5), to: nil)
        XCTAssertNil(skeinView.menu(for: try mouseEvent(.rightMouseDown, at: offKnot, in: window)))
    }

    // MARK: - The menu

    func testTheMenu() throws {
        let (skein, look, _, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let menu = skeinView.menu(for: look)
        XCTAssertFalse(menu.autoenablesItems)
        let expected: [(title: String, action: String)?] = [
            ("Play to Here", "playToHere:"),
            nil,
            ("Insert Previous Command", "insertPreviousItem:"),
            ("Insert Next Command", "insertNextItem:"),
            ("Delete Command", "deleteOneItem:"),
            ("Edit Command", "editContextItem:"),
            ("Set Winning Command", "setWinningCommandItem:"),
            nil,
            ("Split Thread", "addNewBranch:"),
            ("Delete Threads from Here", "deleteItem:"),
            nil,
            ("Bless Command", "blessItem:"),
            ("Bless all Commands to Here", "blessToHere:"),
        ]
        XCTAssertEqual(menu.items.count, expected.count)
        for (menuItem, expected) in zip(menu.items, expected) {
            guard let expected else {
                XCTAssertTrue(menuItem.isSeparatorItem)
                continue
            }
            XCTAssertEqual(menuItem.title, IFUtility.localizedString(expected.title))
            XCTAssertEqual(menuItem.action.map(NSStringFromSelector), expected.action)
            XCTAssertNil(menuItem.target)
            XCTAssertEqual(menuItem.keyEquivalent, "")
            XCTAssertTrue(menuItem.isEnabled, expected.title)
            XCTAssertEqual(menuItem.state, .off, expected.title)
        }

        // The winning command is ticked
        skein.winningItem = look
        XCTAssertEqual(try menuItem("Set Winning Command", for: look, in: skeinView).state, .on)
        XCTAssertEqual(try menuItem("Set Winning Command", for: wait, in: skeinView).state, .off)
    }

    func testWhatTheMenuAllows() {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        XCTAssertEqual(enabledActions(for: look, in: skeinView), allActions)
        XCTAssertEqual(enabledActions(for: north, in: skeinView), allActions)

        // The start: nothing goes before it, it has more than one thread to go after it, and its command is fixed
        XCTAssertEqual(enabledActions(for: skein.rootItem, in: skeinView),
                       allActions(except: ["insertPreviousItem:", "insertNextItem:", "deleteOneItem:",
                                           "editContextItem:", "setWinningCommandItem:"]))

        // The thread being played can't be deleted
        skein.activeItem = north
        let notDeleted = allActions(except: ["deleteOneItem:", "deleteItem:"])
        XCTAssertEqual(enabledActions(for: look, in: skeinView), notDeleted)
        XCTAssertEqual(enabledActions(for: north, in: skeinView), notDeleted)
        XCTAssertEqual(enabledActions(for: wait, in: skeinView), allActions)
    }

    func testWhatTheMenuAllowsForATestMeCommand() {
        let (skein, _, _, _) = makeSkein()
        let testMe = add("test me", to: skein.rootItem, in: skein)
        let jump = add("jump", to: testMe, in: skein, testSubItem: true)
        let sing = add("sing", to: jump, in: skein, testSubItem: true)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // Nothing can go between "test me" and its commands
        XCTAssertEqual(enabledActions(for: testMe, in: skeinView),
                       allActions(except: ["insertNextItem:", "addNewBranch:"]))
        XCTAssertTrue(skeinView.hasMenu(testMe))

        // Its commands have no menu, except the last, which can be played on from
        XCTAssertFalse(skeinView.hasMenu(jump))
        XCTAssertTrue(skeinView.hasMenu(sing))
        XCTAssertEqual(enabledActions(for: sing, in: skeinView),
                       ["insertNextItem:", "addNewBranch:", "blessItem:", "blessToHere:"])
    }

    // MARK: - The menu's commands

    /// The commands act on the knot whose menu was shown, so with no menu shown they do nothing
    func testTheMenusCommandsNeedAKnot() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        skeinView.select(north, withAnimation: false)
        let delegate = Delegate()
        skeinView.delegate = delegate

        // Stop at the first failure, as some commands beep without a knot
        continueAfterFailure = false
        for action in ["deleteItem:", "blessItem:", "blessToHere:", "playToHere:", "insertPreviousItem:",
                       "insertNextItem:", "deleteOneItem:", "setWinningCommandItem:", "editContextItem:",
                       "addNewBranch:"] {
            let changes = changes(of: skein) {
                XCTAssertTrue(NSApp.sendAction(NSSelectorFromString(action), to: skeinView, from: nil), action)
            }
            XCTAssertEqual(changes, 0, action)
            XCTAssertIdentical(skeinView.selectedItem, north, action)
            XCTAssertEqual(delegate.calls, [], action)
            XCTAssertFalse(isEditing(skeinView), action)
        }
        XCTAssertEqual(commands(skein.rootItem), ["look", "wait"])
        XCTAssertEqual(skein.rootItem.ideal, "")
    }

    func testPlayToHere() throws {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        let delegate = Delegate()
        skeinView.delegate = delegate
        skein.activeItem = look

        // From the knot being played, if the knot is further on
        try choose("Play to Here", for: north, in: skeinView)
        XCTAssertEqual(delegate.calls, ["play to north from look"])

        // Otherwise from the start
        delegate.calls = []
        try choose("Play to Here", for: wait, in: skeinView)
        XCTAssertEqual(delegate.calls, ["stop", "play to wait from start"])
    }

    func testPlayToHereNeedsADelegateAndACommandThatIsntPartOfTestMe() throws {
        let (skein, _, north, _) = makeSkein()
        let testMe = add("test me", to: skein.rootItem, in: skein)
        let jump = add("jump", to: testMe, in: skein, testSubItem: true)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Play to Here", for: north, in: skeinView)

        let delegate = Delegate()
        skeinView.delegate = delegate
        try choose("Play to Here", for: jump, in: skeinView)
        XCTAssertEqual(delegate.calls, [])
    }

    func testInsertPreviousCommand() throws {
        let (skein, look, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let changes = try changes(of: skein) { try choose("Insert Previous Command", for: north, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(commands(look), [""])
        let inserted = try XCTUnwrap(look.children.first)
        XCTAssertEqual(commands(inserted), ["north"])
        XCTAssertIdentical(north.parent, inserted)

        // The new knot's command is being edited
        XCTAssertEqual(try fieldEditor(in: window).string, "")

        // Nothing goes before the start
        try choose("Insert Previous Command", for: skein.rootItem, in: skeinView)
        XCTAssertNil(skein.rootItem.parent)
        XCTAssertEqual(commands(skein.rootItem), ["look", "wait"])
    }

    func testInsertPreviousCommandLeavesTheOtherThreads() throws {
        let (skein, look, _, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Insert Previous Command", for: look, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["", "wait"])
        let inserted = try XCTUnwrap(skein.rootItem.children.first)
        XCTAssertEqual(commands(inserted), ["look"])
        XCTAssertIdentical(look.parent, inserted)
        XCTAssertIdentical(wait.parent, skein.rootItem)
    }

    /// Where the knot before already has a blank knot, the new knot is merged into it, and so the knot is merged into
    /// the blank knot's knot with the same command, if it has one. The knots that are dropped give way to the ones
    /// they're merged into as the knot being played, the selected knot and the winning knot.
    func testInsertPreviousCommandKeepsTheKnotsItMerges() throws {
        let (skein, look, north, _) = makeSkein()
        let blank = add("", to: skein.rootItem, in: skein)
        let blankLook = add("look", to: blank, in: skein)
        let blankNorth = add("north", to: blankLook, in: skein)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        skein.activeItem = north
        skeinView.select(north, withAnimation: false)
        skein.winningItem = look

        try choose("Insert Previous Command", for: look, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["", "wait"])
        XCTAssertEqual(commands(blank), ["look"])
        XCTAssertEqual(commands(blankLook), ["north"])
        XCTAssertIdentical(skein.activeItem, blankNorth)
        XCTAssertIdentical(skeinView.selectedItem, blankNorth)
        XCTAssertIdentical(skein.winningItem, blankLook)
    }

    func testInsertNextCommand() throws {
        let (skein, look, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // After a knot with no thread after it
        try choose("Insert Next Command", for: north, in: skeinView)
        XCTAssertEqual(commands(north), [""])
        XCTAssertEqual(try fieldEditor(in: window).string, "")

        // Between a knot and the one knot after it
        try choose("Insert Next Command", for: look, in: skeinView)
        XCTAssertEqual(commands(look), [""])
        let inserted = try XCTUnwrap(look.children.first)
        XCTAssertNotIdentical(inserted, north)
        XCTAssertIdentical(north.parent, inserted)

        // Not after a knot with more than one thread after it
        try choose("Insert Next Command", for: skein.rootItem, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["look", "wait"])
    }

    func testSplitThread() throws {
        let (skein, look, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let changes = try changes(of: skein) { try choose("Split Thread", for: look, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(commands(look), ["", "north"])
        XCTAssertEqual(try fieldEditor(in: window).string, "")

        try typeText("east", in: window)
        try fieldEditor(in: window).insertNewline(nil)
        XCTAssertEqual(commands(look), ["east", "north"])
    }

    func testDeleteCommand() throws {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // The knots after it join the knot before it, and a selection after it stays
        skeinView.select(north, withAnimation: false)
        let changes = try changes(of: skein) { try choose("Delete Command", for: look, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(commands(skein.rootItem), ["north", "wait"])
        XCTAssertIdentical(north.parent, skein.rootItem)
        XCTAssertNil(look.parent)
        XCTAssertIdentical(skeinView.selectedItem, north)

        // A selection elsewhere stays
        skeinView.select(wait, withAnimation: false)
        try choose("Delete Command", for: north, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["wait"])
        XCTAssertIdentical(skeinView.selectedItem, wait)

        // The start can't be deleted
        try choose("Delete Command", for: skein.rootItem, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["wait"])
    }

    /// The knots after a deleted knot are merged into the knot before's knots with the same commands, and the
    /// selected and winning knots go to the knots they're merged into
    func testDeleteCommandKeepsTheKnotsItMerges() throws {
        let (skein, look, north, wait) = makeSkein()
        let rootNorth = add("north", to: skein.rootItem, in: skein)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        skeinView.select(north, withAnimation: false)
        skein.winningItem = north

        try choose("Delete Command", for: look, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["north", "wait"])
        XCTAssertIdentical(skeinView.selectedItem, rootNorth)
        XCTAssertIdentical(skein.winningItem, rootNorth)

        // A selected knot that's deleted gives way to the knot before, if that has no other threads
        skeinView.select(wait, withAnimation: false)
        try choose("Delete Command", for: wait, in: skeinView)
        XCTAssertIdentical(skeinView.selectedItem, skein.rootItem)
    }

    func testDeletingTestMeDeletesItsCommands() throws {
        let (skein, _, _, _) = makeSkein()
        let testMe = add("test me", to: skein.rootItem, in: skein)
        let jump = add("jump", to: testMe, in: skein, testSubItem: true)
        let sing = add("sing", to: jump, in: skein, testSubItem: true)
        let east = add("east", to: sing, in: skein)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Delete Command", for: testMe, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["east", "look", "wait"])
        XCTAssertIdentical(east.parent, skein.rootItem)
        XCTAssertNil(testMe.parent)
        XCTAssertIdentical(jump.parent, testMe)
    }

    func testDeleteThreadsFromHere() throws {
        let (skein, look, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // A selection that was in the threads goes to the knot before, if it has only one thread left
        skeinView.select(north, withAnimation: false)
        let changes = try changes(of: skein) { try choose("Delete Threads from Here", for: look, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(commands(skein.rootItem), ["wait"])
        XCTAssertNil(look.parent)
        XCTAssertIdentical(skeinView.selectedItem, skein.rootItem)

        // From the start, every thread goes
        try choose("Delete Threads from Here", for: skein.rootItem, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), [])
        XCTAssertNil(skeinView.selectedItem)
    }

    /// The thread being played can't be deleted from the start either, since the story's next command would be added
    /// to a knot no longer in the skein
    func testTheThreadBeingPlayedCantBeDeletedFromTheStart() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skein.activeItem = north
        XCTAssertFalse(enabledActions(for: skein.rootItem, in: skeinView).contains("deleteItem:"))
        try choose("Delete Threads from Here", for: skein.rootItem, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), ["look", "wait"])
        XCTAssertIdentical(north.skein, skein)

        // Before the story has been played past the start, every thread can go
        skein.activeItem = skein.rootItem
        XCTAssertTrue(enabledActions(for: skein.rootItem, in: skeinView).contains("deleteItem:"))
        try choose("Delete Threads from Here", for: skein.rootItem, in: skeinView)
        XCTAssertEqual(commands(skein.rootItem), [])
    }

    func testDeleteThreadsFromHereDeselectsWhenTheKnotBeforeHasThreadsLeft() throws {
        let (skein, look, north, _) = makeSkein()
        add("south", to: look, in: skein)
        add("up", to: look, in: skein)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(north, withAnimation: false)
        try choose("Delete Threads from Here", for: north, in: skeinView)
        XCTAssertEqual(commands(look), ["south", "up"])
        XCTAssertNil(skeinView.selectedItem)
    }

    func testSetWinningCommand() throws {
        let (skein, look, _, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let changes = try changes(of: skein) { try choose("Set Winning Command", for: look, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertIdentical(skein.winningItem, look)

        try choose("Set Winning Command", for: wait, in: skeinView)
        XCTAssertIdentical(skein.winningItem, wait)

        // Setting it again unsets it
        try choose("Set Winning Command", for: wait, in: skeinView)
        XCTAssertNil(skein.winningItem)

        // The start can't win
        try choose("Set Winning Command", for: skein.rootItem, in: skeinView)
        XCTAssertNil(skein.winningItem)
    }

    func testBlessing() throws {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        let changes = try changes(of: skein) { try choose("Bless Command", for: north, in: skeinView) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(north.ideal, "A hall.\n>")
        XCTAssertEqual(look.ideal, "")

        try choose("Bless all Commands to Here", for: look, in: skeinView)
        XCTAssertEqual(look.ideal, "A room.\n>")
        XCTAssertEqual(skein.rootItem.ideal, "Welcome\n>")
        XCTAssertEqual(wait.ideal, "")

        // As the bless buttons in the report do
        skeinView.setItemBlessed(north, bless: false)
        XCTAssertEqual(north.ideal, "")
        skeinView.setItemBlessed(wait, bless: true)
        XCTAssertEqual(wait.ideal, "Time passes.\n>")
    }

    // MARK: - Editing a command

    func testEditCommand() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Edit Command", for: north, in: skeinView)
        let editor = try fieldEditor(in: window)
        XCTAssertEqual(editor.string, "north")
        XCTAssertIdentical(editor.delegate, skeinView)
        XCTAssertIdentical(editor.enclosingScrollView?.superview, skeinView)
        XCTAssertTrue(isEditing(skeinView))

        // Return keeps the change
        try typeText("south", in: window)
        let changes = changes(of: skein) { editor.insertNewline(nil) }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(north.command, "south")
        XCTAssertFalse(isEditing(skeinView))
        XCTAssertIdentical(window.firstResponder, skeinView)

        // The start's command can't be edited
        try choose("Edit Command", for: skein.rootItem, in: skeinView)
        XCTAssertFalse(isEditing(skeinView))
    }

    func testLeavingTheCommandCancelsTheEdit() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Edit Command", for: north, in: skeinView)
        try typeText("south", in: window)
        window.makeFirstResponder(skeinView)
        XCTAssertEqual(north.command, "north")
        XCTAssertFalse(isEditing(skeinView))
    }

    func testClickingTheSkeinKeepsTheEdit() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Edit Command", for: north, in: skeinView)
        try typeText("south", in: window)
        let location = skeinView.convert(NSPoint(x: 5, y: skeinView.bounds.maxY - 5), to: nil)
        skeinView.mouseDown(with: try mouseEvent(.leftMouseDown, at: location, in: window))
        skeinView.mouseUp(with: try mouseEvent(.leftMouseUp, at: location, in: window))
        XCTAssertEqual(north.command, "south")
        XCTAssertFalse(isEditing(skeinView))
    }

    /// Removing the view takes the first responder away from the field editor, which cancels the edit
    func testRemovingTheViewCancelsTheEdit() throws {
        let (skein, _, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Edit Command", for: north, in: skeinView)
        try typeText("south", in: window)
        nonisolated(unsafe) var movements: [Int?] = []
        let observer = NotificationCenter.default.addObserver(forName: NSText.didEndEditingNotification,
                                                              object: try fieldEditor(in: window), queue: nil) {
            movements.append($0.userInfo?["NSTextMovement"] as? Int)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        skeinView.removeFromSuperview()
        XCTAssertEqual(movements, [NSTextMovement.other.rawValue])
        XCTAssertEqual(north.command, "north")
        XCTAssertFalse(isEditing(skeinView))
    }

    func testEditingACommandKeepsTheKnotsInOrder() throws {
        let (skein, look, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        try choose("Edit Command", for: look, in: skeinView)
        try typeText("xyzzy", in: window)
        try fieldEditor(in: window).insertNewline(nil)
        XCTAssertEqual(commands(skein.rootItem), ["wait", "xyzzy"])
    }

    func testEditingACommandToAnotherKnotsCommandMergesThem() throws {
        let (skein, look, north, wait) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        skeinView.select(look, withAnimation: false)
        skein.activeItem = look

        try choose("Edit Command", for: look, in: skeinView)
        try typeText("wait", in: window)
        let notifications = try selectionChanges(of: skeinView) { try fieldEditor(in: window).insertNewline(nil) }
        XCTAssertEqual(commands(skein.rootItem), ["wait"])
        XCTAssertIdentical(north.parent, wait)

        // The knot it merged into takes over as the active and selected knot
        XCTAssertIdentical(skein.activeItem, wait)
        XCTAssertIdentical(skeinView.selectedItem, wait)
        XCTAssertEqual(notifications.count, 1)
    }

    /// Merging goes on knot by knot down each thread, and a knot after the edited one that matches one already there
    /// is dropped. That one takes over from it as the knot being played, the selected knot and the winning knot.
    func testEditingACommandToAnotherKnotsCommandKeepsTheKnotsAfterIt() throws {
        let (skein, look, north, wait) = makeSkein()
        let waitNorth = add("north", to: wait, in: skein)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        skein.activeItem = waitNorth
        skeinView.select(waitNorth, withAnimation: false)
        skein.winningItem = waitNorth

        try choose("Edit Command", for: wait, in: skeinView)
        try typeText("look", in: window)
        try fieldEditor(in: window).insertNewline(nil)
        XCTAssertEqual(commands(skein.rootItem), ["look"])
        XCTAssertEqual(commands(look), ["north"])
        XCTAssertIdentical(skein.activeItem, north)
        XCTAssertIdentical(skeinView.selectedItem, north)
        XCTAssertIdentical(skein.winningItem, north)
    }

    // MARK: - Undo

    /// A knot and the knots after it, as "command(child, child)"
    private func tree(_ item: IFSkeinItem) -> String {
        let children = item.children.map { tree($0) }
        return children.isEmpty ? item.command : "\(item.command!)(\(children.joined(separator: ", ")))"
    }

    /// Editing a command and deleting one can be undone and redone, though each takes a knot out of the skein to
    /// change it
    func testUndoingEditCommandAndDeleteCommand() throws {
        // A skein in a project that the document controller knows, so that changes to its knots can be undone, and
        // the project's undo manager, which makes a step to undo only when told to
        let project = IFProject()
        let skein = try XCTUnwrap(project.currentSkein)
        project.skeins.add(skein)
        let undoManager = try XCTUnwrap(project.undoManager)
        undoManager.groupsByEvent = false
        NSDocumentController.shared.addDocument(project)
        defer { NSDocumentController.shared.removeDocument(project) }

        undoManager.disableUndoRegistration()
        let look = add("look", to: skein.rootItem, in: skein)
        let north = add("north", to: look, in: skein)
        add("jump", to: add("east", to: north, in: skein), in: skein)
        add("east", to: look, in: skein)
        undoManager.enableUndoRegistration()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // Editing a command, which puts the knot back among its siblings in order
        try choose("Edit Command", for: north, in: skeinView)
        try typeText("away", in: window)
        undoManager.beginUndoGrouping()
        try fieldEditor(in: window).insertNewline(nil)
        undoManager.endUndoGrouping()
        XCTAssertEqual(tree(look), "look(away(east(jump)), east)")
        undoManager.undo()
        XCTAssertEqual(tree(look), "look(east, north(east(jump)))")
        undoManager.redo()
        XCTAssertEqual(tree(look), "look(away(east(jump)), east)")
        undoManager.undo()

        // Deleting a command, which merges the knots after it into the knots before
        undoManager.beginUndoGrouping()
        try choose("Delete Command", for: north, in: skeinView)
        undoManager.endUndoGrouping()
        XCTAssertEqual(tree(look), "look(east(jump))")
        undoManager.undo()
        XCTAssertEqual(tree(look), "look(east, north(east(jump)))")
        XCTAssertIdentical(north.parent, look)
        undoManager.redo()
        XCTAssertEqual(tree(look), "look(east(jump))")
        XCTAssertNil(north.parent)
    }

    // MARK: - The font size

    func testTheFontSize() throws {
        XCTAssertEqual(IFSkeinView.fontSize, kSkeinDefaultItemFontSize * IFPreferences.shared.appFontSizeMultiplier)

        let (skein, _, _, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }
        let changes = changes(of: skein) {
            skeinView.fontSizePreferenceChanged(Notification(name: Notification.Name("Test")))
        }
        XCTAssertEqual(changes, 1)
    }

    // MARK: - What the help shows

    func testWhatTheHelpAsksAbout() throws {
        let (skein, look, north, _) = makeSkein()
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        // Nothing selected or played
        XCTAssertEqual(skeinView.itemsVisible, 4)
        XCTAssertFalse(skeinView.isAnyItemPurple)
        XCTAssertTrue(skeinView.isAnyItemGrey)
        XCTAssertFalse(skeinView.isAnyItemBlue)
        XCTAssertFalse(skeinView.isReportVisible)
        XCTAssertFalse(skeinView.isTickVisible)
        XCTAssertFalse(skeinView.isCrossVisible)
        XCTAssertFalse(skeinView.isBadgedItemVisible)

        // A thread selected, with nothing blessed
        skeinView.select(north, withAnimation: false)
        XCTAssertTrue(skeinView.isAnyItemBlue)
        XCTAssertTrue(skeinView.isAnyItemGrey)
        XCTAssertTrue(skeinView.isReportVisible)
        XCTAssertTrue(skeinView.isTickVisible)
        XCTAssertFalse(skeinView.isCrossVisible)

        // A knot on the thread blessed, and another blessed with different output
        skeinView.setItemBlessed(north, bless: true)
        XCTAssertTrue(skeinView.isTickVisible)
        XCTAssertTrue(skeinView.isCrossVisible)
        XCTAssertFalse(skeinView.isBadgedItemVisible)
        look.ideal = "Somewhere else.\n>"
        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertTrue(skeinView.isBadgedItemVisible)

        // A thread played
        skein.activeItem = north
        skein.postChanged(withAnimate: false, keepActiveVisible: false)
        XCTAssertTrue(skeinView.isAnyItemPurple)
    }
}
