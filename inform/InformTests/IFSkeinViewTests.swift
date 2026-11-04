//
//  IFSkeinViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinViewTests: XCTestCase {

    /// A skein view in a 700 by 500 scroll view, in a window that isn't shown.
    private func makeSkeinView(_ skein: IFSkein) -> (NSWindow, IFSkeinView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
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

        skeinView.layoutSkein(withAnimation: false)
        XCTAssertEqual(skeinView.visibleRect.origin, scrolledTo)
    }
}
