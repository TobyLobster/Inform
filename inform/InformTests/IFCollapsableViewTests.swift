//
//  IFCollapsableViewTests.swift
//  InformTests
//

import XCTest

final class IFCollapsableViewTests: XCTestCase {

    /// The border around the views, and between them
    private let border: CGFloat = 8

    /// The space a view's title takes above it
    private var titleSpace: CGFloat {
        let font = NSFont.boldSystemFont(ofSize: 13)
        return (font.ascender - font.descender) * 1.2
    }

    private func makeView() -> IFCollapsableView {
        return IFCollapsableView(frame: NSRect(x: 0, y: 0, width: 300, height: 50))
    }

    private func subview(width: CGFloat, height: CGFloat) -> NSView {
        return NSView(frame: NSRect(x: 40, y: 30, width: width, height: height))
    }

    // MARK: - A new view

    func testANewView() {
        let view = makeView()
        XCTAssertEqual(view.subviews, [])
        XCTAssertTrue(view.isFlipped)
        XCTAssertFalse(view.isOpaque)
        XCTAssertEqual(view.frame, NSRect(x: 0, y: 0, width: 300, height: 50))
    }

    // MARK: - Laying out the views

    /// Each view is added below the one before, under its title, and the view is as tall as they are
    func testAddingViews() {
        let view = makeView()
        let first = subview(width: 100, height: 40)
        view.addSubview(first, withTitle: "First")

        XCTAssertIdentical(first.superview, view)
        XCTAssertEqual(first.autoresizingMask, [.maxXMargin, .maxYMargin])
        XCTAssertEqual(first.frame, NSRect(x: border, y: floor(border + titleSpace), width: 100, height: 40))
        XCTAssertEqual(view.frame.size, NSSize(width: 300, height: floor(border + titleSpace + 40 + border)))

        let second = subview(width: 150, height: 20)
        view.addSubview(second, withTitle: "Second")
        XCTAssertEqual(view.subviews, [first, second])
        XCTAssertEqual(first.frame.origin, NSPoint(x: border, y: floor(border + titleSpace)))
        XCTAssertEqual(second.frame, NSRect(x: border, y: floor(border + titleSpace + 40 + border + titleSpace),
                                            width: 150, height: 20))
        XCTAssertEqual(view.frame.size,
                       NSSize(width: 300, height: floor(border + 2 * (titleSpace + border) + 60)))
    }

    /// While the views are rearranged, they're added as they are, and laid out when it finishes
    func testRearranging() {
        let view = makeView()
        let first = subview(width: 100, height: 40)
        let second = subview(width: 150, height: 20)
        view.addSubview(first, withTitle: "First")
        view.addSubview(second, withTitle: "Second")
        let height = view.frame.height

        view.startRearranging()
        view.removeAllSubviews()
        XCTAssertEqual(view.subviews, [])
        XCTAssertNil(first.superview)
        XCTAssertNil(second.superview)

        let third = subview(width: 120, height: 10)
        view.addSubview(third, withTitle: "Third")
        XCTAssertEqual(view.subviews, [third])
        XCTAssertEqual(third.frame.origin, NSPoint(x: 40, y: 30))
        XCTAssertEqual(view.frame.height, height)

        view.finishRearranging()
        XCTAssertEqual(third.frame.origin, NSPoint(x: border, y: floor(border + titleSpace)))
        XCTAssertEqual(view.frame.height, floor(border + titleSpace + 10 + border))
    }

    /// Removing the views leaves the view's size as it was
    func testRemovingTheViews() {
        let view = makeView()
        view.addSubview(subview(width: 100, height: 40), withTitle: "First")
        let height = view.frame.height

        view.removeAllSubviews()
        XCTAssertEqual(view.subviews, [])
        XCTAssertEqual(view.frame.height, height)

        view.rearrangeSubviews()
        XCTAssertEqual(view.frame.height, floor(border))
    }

    /// Rearranging takes account of views that have changed size
    func testAViewThatChangesSize() {
        let view = makeView()
        let first = subview(width: 100, height: 40)
        let second = subview(width: 150, height: 20)
        view.addSubview(first, withTitle: "First")
        view.addSubview(second, withTitle: "Second")

        first.setFrameSize(NSSize(width: 100, height: 70))
        view.rearrangeSubviews()
        XCTAssertEqual(second.frame.origin,
                       NSPoint(x: border, y: floor(border + titleSpace + 70 + border + titleSpace)))
        XCTAssertEqual(view.frame.height, floor(border + 2 * (titleSpace + border) + 90))
    }

    /// Rearranging brings back views that have been taken out of the view, or moved
    func testAViewTakenAway() {
        let view = makeView()
        let first = subview(width: 100, height: 40)
        let second = subview(width: 150, height: 20)
        view.addSubview(first, withTitle: "First")
        view.addSubview(second, withTitle: "Second")
        let secondFrame = second.frame

        first.removeFromSuperview()
        let elsewhere = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        elsewhere.addSubview(second)
        second.setFrameOrigin(NSPoint(x: 1, y: 2))

        view.rearrangeSubviews()
        XCTAssertIdentical(first.superview, view)
        XCTAssertIdentical(second.superview, view)
        XCTAssertEqual(elsewhere.subviews, [])
        XCTAssertEqual(first.frame.origin, NSPoint(x: border, y: floor(border + titleSpace)))
        XCTAssertEqual(second.frame, secondFrame)
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

    /// The colours drawn in a rectangle of a view, with the most opaque first
    private func colours(_ bitmap: NSBitmapImageRep, in rect: NSRect, of view: NSView) -> [[CGFloat]] {
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        var result: [[CGFloat]] = []
        for y in Int(rect.minY * scale)..<Int(rect.maxY * scale) {
            for x in Int(rect.minX * scale)..<Int(rect.maxX * scale) {
                if let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                    result.append([colour.redComponent, colour.greenComponent, colour.blueComponent,
                                   colour.alphaComponent])
                }
            }
        }
        return result.sorted { $0[3] > $1[3] }
    }

    /// Each view is drawn in a grey box as wide as the widest, with its title above it, and nothing else is drawn
    func testDrawing() {
        let view = makeView()
        let first = subview(width: 100, height: 40)
        let second = subview(width: 150, height: 20)
        view.addSubview(first, withTitle: "First")
        view.addSubview(second, withTitle: "Second")
        let bitmap = drawn(view)

        let font = NSFont.boldSystemFont(ofSize: 13)
        let grey = rgba(NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        let clear: [CGFloat] = [0, 0, 0, 0]

        for (subview, title) in [(first, "First"), (second, "Second")] {
            let titleSize = (title as NSString).size(withAttributes: [.font: font])
            let top = floor(subview.frame.minY - titleSize.height * 1.2) + 0.5
            let bottom = top + floor(subview.frame.height + titleSize.height * 1.2)

            // The box
            assertColour(colour(bitmap, at: NSPoint(x: border + 0.5, y: subview.frame.midY), in: view), grey,
                         "\(title)'s box's left")
            assertColour(colour(bitmap, at: NSPoint(x: border + 0.5 + 150, y: subview.frame.midY), in: view), grey,
                         "\(title)'s box's right")
            assertColour(colour(bitmap, at: NSPoint(x: 60, y: top), in: view), grey, "\(title)'s box's top")
            assertColour(colour(bitmap, at: NSPoint(x: 60, y: bottom), in: view), grey, "\(title)'s box's bottom")
            assertColour(colour(bitmap, at: NSPoint(x: 60, y: subview.frame.midY), in: view), clear,
                         "inside \(title)'s box")
            assertColour(colour(bitmap, at: NSPoint(x: border + 152, y: subview.frame.midY), in: view), clear,
                         "beside \(title)'s box")

            // The title, in the text colour
            let titleY = top + 2 + titleSize.height * 0.1
            let titleRect = NSRect(x: border * 2, y: titleY, width: titleSize.width, height: titleSize.height)
            let titleColours = colours(bitmap, in: titleRect, of: view)
            XCTAssertGreaterThan(titleColours.filter { $0[3] > 0.5 }.count, 20, title)
            var textColour: [CGFloat] = []
            view.effectiveAppearance.performAsCurrentDrawingAppearance {
                textColour = rgba(NSColor.textColor)
            }
            assertColour(titleColours.first, textColour, "\(title)'s title")
            let besideTitle = NSRect(x: titleRect.maxX + 4, y: titleRect.minY + 2, width: 20,
                                     height: titleRect.height - 4)
            XCTAssertEqual(colours(bitmap, in: besideTitle, of: view).first?[3], 0, "beside \(title)'s title")
        }

        // Nothing once the views are removed
        view.removeAllSubviews()
        XCTAssertEqual(colours(drawn(view), in: view.bounds, of: view).first?[3], 0)
    }
}
