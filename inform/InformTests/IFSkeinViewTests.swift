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

    /// Selecting a thread makes the levels taller and so the lines between knots longer. Each line has to be
    /// drawn again at its new length, or its layer keeps the shorter line and the knots look disconnected.
    func testLinesRedrawWhenTheirLengthChanges() {
        let skein: IFSkein = IFSkein(project: nil)
        let item = addThread(to: skein.rootItem, skein: skein, count: 4)
        let (window, skeinView) = makeSkeinView(skein)
        defer { window.close() }

        skeinView.select(item, withAnimation: false)
        let lines = skeinView.subviews.filter { NSStringFromClass(type(of: $0)).hasSuffix("IFSkeinLinkView") }
        XCTAssertEqual(lines.count, 4)
        for line in lines {
            XCTAssertEqual(line.layerContentsRedrawPolicy, .duringViewResize)
        }
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
