//
//  IFSkeinArrowViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinArrowViewTests: XCTestCase {

    /// An arrow as the skein view makes it, as high as the arrow head and a point above and below it
    private func makeArrow(width: CGFloat) -> IFSkeinArrowView {
        let arrow = IFSkeinArrowView()
        arrow.frame = NSRect(x: 0, y: 0, width: width, height: kSkeinArrowHeadHeight + 2)
        return arrow
    }

    private func drawn(_ view: NSView) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    /// The colour drawn in the point whose bottom left corner is at x, y, in the view's own coordinates
    private func colour(_ bitmap: NSBitmapImageRep, x: CGFloat, y: CGFloat, in view: NSView) -> [CGFloat] {
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        let row = Int((view.bounds.height - y - 0.5) * scale)
        guard let colour = bitmap.colorAt(x: Int((x + 0.5) * scale), y: row)?.usingColorSpace(.sRGB) else {
            return []
        }
        return [colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent]
    }

    private func rgba(_ colour: NSColor) -> [CGFloat] {
        let colour = colour.usingColorSpace(.sRGB)!
        return [colour.redComponent, colour.greenComponent, colour.blueComponent, colour.alphaComponent]
    }

    private func assertColour(_ actual: [CGFloat], _ expected: [CGFloat], _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, 4, message, file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a, e, accuracy: 0.02, message, file: file, line: line)
        }
    }

    func testANewView() {
        let arrow = IFSkeinArrowView()
        XCTAssertTrue(arrow.wantsLayer)
        XCTAssertEqual(arrow.layerContentsRedrawPolicy, .onSetNeedsDisplay)
        XCTAssertFalse(arrow.isFlipped)
    }

    /// A dotted line along the middle of the view, to an arrow head at its right, with a shadow below and to the
    /// right, on a translucent white box, so that the links behind it don't muddle it
    func testDrawing() throws {
        let arrow = makeArrow(width: 60)
        let bitmap = try drawn(arrow)
        let grey = rgba(NSColor(deviceRed: 0.25, green: 0.25, blue: 0.25, alpha: 1))
        let box = rgba(NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 0.8))
        let clear: [CGFloat] = [0, 0, 0, 0]

        // The line is the fourth point up, a dot of one point every four
        for x in 0..<52 {
            assertColour(colour(bitmap, x: CGFloat(x), y: 3, in: arrow), x % 4 == 0 ? grey : box, "line at \(x)")
        }
        // The shadow's line is the point below, its dots 15% black on the box (how much darker than the box they look
        // depends on the colour space they're blended in)
        let shadow = colour(bitmap, x: 8, y: 2, in: arrow)
        XCTAssertEqual(shadow.last ?? 0, 0.15 + 0.8 * 0.85, accuracy: 0.02, "the shadow below a dot")
        XCTAssertLessThan(shadow.first ?? 1, 0.9, "the shadow below a dot")
        assertColour(colour(bitmap, x: 10, y: 2, in: arrow), box, "the shadow between dots")
        // The box is two points above and below the line's middle
        assertColour(colour(bitmap, x: 10, y: 4, in: arrow), box, "above the line")
        assertColour(colour(bitmap, x: 10, y: 6, in: arrow), clear, "above the box")
        assertColour(colour(bitmap, x: 10, y: 0, in: arrow), clear, "below the box")

        // The arrow head is five points long and five high, and its box covers the whole height
        assertColour(colour(bitmap, x: 57, y: 3, in: arrow), grey, "inside the arrow head")
        assertColour(colour(bitmap, x: 53, y: 6, in: arrow), box, "the arrow head's box")
        assertColour(colour(bitmap, x: 53, y: 0, in: arrow), box, "the arrow head's box")
    }
}
