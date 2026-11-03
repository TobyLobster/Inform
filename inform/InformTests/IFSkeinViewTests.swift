//
//  IFSkeinViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinViewTests: XCTestCase {

    /// Selecting a thread shows its transcript beside the knots, without painting over them.
    func testTranscriptDoesNotCoverTheKnots() throws {
        let skein: IFSkein = IFSkein(project: nil)
        var item: IFSkeinItem = skein.rootItem
        for i in 1...4 {
            let child: IFSkeinItem = IFSkeinItem(skein: skein, command: "command \(i)")
            child.actual = "Output for command \(i)."
            item = item.addChild(child)
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        let skeinView = IFSkeinView(frame: scrollView.bounds)
        scrollView.documentView = skeinView
        window.contentView!.addSubview(scrollView)

        skeinView.skein = skein
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
}
