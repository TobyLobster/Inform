//
//  IFPageBarViewTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFPageBarViewTests: XCTestCase, @unchecked Sendable {

    /// A page bar that records when it, or parts of it, are to be redrawn
    private final class RecordingBar: IFPageBarView {
        var invalidatedRects: [NSRect] = []
        var timesMarkedForDisplay = 0

        override func setNeedsDisplay(_ invalidRect: NSRect) {
            invalidatedRects.append(invalidRect)
            super.setNeedsDisplay(invalidRect)
        }

        override var needsDisplay: Bool {
            get {
                return super.needsDisplay
            }
            set {
                if newValue {
                    timesMarkedForDisplay += 1
                }
                super.needsDisplay = newValue
            }
        }
    }

    /// A cell with no text or image, of a width the test chooses, so that it draws nothing but the bar's borders
    private final class FixedCell: IFPageBarCell {
        private let width: CGFloat

        init(width: CGFloat) {
            self.width = width
            super.init(textCell: "")
        }

        required init(coder: NSCoder) {
            fatalError("Not used")
        }

        override var cellSize: NSSize {
            return NSSize(width: width, height: 20)
        }
    }

    /// Receives the cells' actions
    private final class Target: NSObject {
        var senders: [AnyObject?] = []

        @objc func act(_ sender: Any?) {
            senders.append(sender as AnyObject?)
        }
    }

    private var window: NSWindow!
    private var bar: RecordingBar!
    private var target: Target!

    /// Where the cells start on the left, and the space the bar leaves after them on the right
    private let leftMargin: CGFloat = 3
    private let rightMargin: CGFloat = 14

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            // NSWindow moves a window made off the screen onto it, so it's moved off afterwards, so that the mouse is
            // never over the bar
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 22),
                              styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
            window.appearance = NSAppearance(named: .aqua)

            bar = RecordingBar(frame: NSRect(x: 0, y: 0, width: 400, height: 22))
            window.contentView?.addSubview(bar)
            target = Target()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            // Take off any events a test left queued
            while NSApp.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) != nil {
            }
            window.close()
            window = nil
            bar = nil
            target = nil
            super.tearDown()
        }
    }

    // MARK: - Helpers

    /// The right-hand end of the cells in the bar
    private var rightEdge: CGFloat {
        return bar.bounds.width - rightMargin
    }

    /// A cell of the given width that sends its action to the test's target
    private func cell(width: CGFloat = 40) -> FixedCell {
        let cell = FixedCell(width: width)
        cell.target = target
        cell.action = #selector(Target.act(_:))
        return cell
    }

    /// A cell showing a square of a colour, which sends its action to the test's target
    private func imageCell(_ colour: NSColor) -> IFPageBarCell {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            colour.setFill()
            rect.fill()
            return true
        }
        let cell = IFPageBarCell(imageCell: image)
        cell.target = target
        cell.action = #selector(Target.act(_:))
        return cell
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
        return NSEvent.mouseEvent(with: type, location: bar.convert(point, to: nil), modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                  clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    }

    /// Clicks the bar halfway up, at the given distance from its left
    private func click(at x: CGFloat) {
        let point = NSPoint(x: x, y: 11)
        NSApp.postEvent(mouseEvent(.leftMouseUp, at: point), atStart: false)
        bar.mouseDown(with: mouseEvent(.leftMouseDown, at: point))
    }

    /// The key equivalent event for a key pressed with Command
    private func keyEvent(_ characters: String) -> NSEvent {
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: window.windowNumber, context: nil,
                                characters: characters, charactersIgnoringModifiers: characters, isARepeat: false,
                                keyCode: 0)!
    }

    /// The bar drawn into a bitmap, a pixel to a point
    private func picture() -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bar.bounds.width),
                                   pixelsHigh: Int(bar.bounds.height), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = bar.bounds.size
        bar.cacheDisplay(in: bar.bounds, to: rep)
        return rep
    }

    /// How opaque a pixel is, with y measured from the top
    private func alpha(in rep: NSBitmapImageRep, x: Int, y: Int) -> CGFloat {
        return rep.colorAt(x: x, y: y)!.alphaComponent
    }

    /// Every pixel's colour
    private func colours(in rep: NSBitmapImageRep) -> [NSColor] {
        var result: [NSColor] = []
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                result.append(rep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!)
            }
        }
        return result
    }

    /// How opaque the most opaque pixel is
    private func greatestAlpha(in rep: NSBitmapImageRep) -> CGFloat {
        return colours(in: rep).map(\.alphaComponent).max() ?? 0
    }

    /// Whether anything red is drawn
    private func hasRed(_ rep: NSBitmapImageRep) -> Bool {
        return colours(in: rep).contains {
            $0.alphaComponent > 0.3 && $0.redComponent > 0.8 && $0.greenComponent < 0.3 && $0.blueComponent < 0.3
        }
    }

    // MARK: - Clicks

    func testAClickWithNoCellsDoesNothing() {
        click(at: 100)
        XCTAssertNil(bar.lastTrackedCell)
    }

    func testAClickOnACellOnTheLeftSendsItsAction() {
        let first = cell()
        let second = cell()
        bar.setLeftCells([first, second])

        click(at: leftMargin + 40 + 20)

        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(bar.lastTrackedCell === second)
    }

    /// The first cell on the right is at the right-hand end, and the others go leftwards from it
    func testAClickOnACellOnTheRightSendsItsAction() {
        let first = cell()
        let second = cell()
        bar.setRightCells([first, second])

        click(at: rightEdge - 40 - 20)

        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(bar.lastTrackedCell === second)
    }

    func testAClickBetweenTheCellsDoesNothing() {
        bar.setLeftCells([cell()])
        bar.setRightCells([cell()])

        click(at: 200)

        XCTAssertEqual(target.senders.count, 0)
        XCTAssertNil(bar.lastTrackedCell)
    }

    /// The cells at the ends take the clicks just beyond them, though only a click that ends in a cell sends its
    /// action
    func testTheCellsAtTheEndsTakeClicksJustBeyondThem() {
        let left = cell()
        let right = cell()
        bar.setLeftCells([left])
        bar.setRightCells([right])

        click(at: 0.5)
        XCTAssertTrue(bar.lastTrackedCell === left)

        click(at: rightEdge + 3)
        XCTAssertTrue(bar.lastTrackedCell === right)

        click(at: rightEdge + 6)
        XCTAssertNil(bar.lastTrackedCell, "No more than four points beyond the end")

        XCTAssertEqual(target.senders.count, 0)
    }

    func testAClickOnADisabledCellSendsNothing() {
        let disabled = cell()
        disabled.isEnabled = false
        bar.setLeftCells([disabled])

        click(at: leftMargin + 20)

        XCTAssertEqual(target.senders.count, 0)
        XCTAssertTrue(bar.lastTrackedCell === disabled, "The bar still remembers the cell that was clicked")
    }

    /// An image cell at either end is moved two points towards it, so that the image doesn't look lopsided
    func testAnImageCellAtTheEndIsMovedTwoPointsOut() {
        let left = imageCell(.red)
        let right = imageCell(.red)
        let width = left.cellSize.width
        bar.setLeftCells([left])
        bar.setRightCells([right])

        click(at: leftMargin + width - 1)
        XCTAssertNil(bar.lastTrackedCell)
        click(at: leftMargin + width - 3)
        XCTAssertTrue(bar.lastTrackedCell === left)

        click(at: rightEdge - width + 1)
        XCTAssertNil(bar.lastTrackedCell)
        click(at: rightEdge - width + 3)
        XCTAssertTrue(bar.lastTrackedCell === right)
    }

    /// A cell with no image goes right up to the end
    func testACellWithNoImageIsNotMoved() {
        let left = cell(width: 22)
        let right = cell(width: 22)
        bar.setLeftCells([left])
        bar.setRightCells([right])

        click(at: leftMargin + 22 - 1)
        XCTAssertTrue(bar.lastTrackedCell === left)

        click(at: rightEdge - 22 + 1)
        XCTAssertTrue(bar.lastTrackedCell === right)
    }

    // MARK: - Room for the cells

    /// A cell on the right is hidden when it would come within four points of the cells on the left
    func testACellOnTheRightIsHiddenWhenItWouldComeTooCloseToTheLeft() {
        bar.setLeftCells([cell()])
        let right = cell()
        bar.setRightCells([right])

        bar.setFrameSize(NSSize(width: leftMargin + 40 + 4 + 40 + rightMargin - 1, height: 22))
        click(at: rightEdge - 20)
        XCTAssertNil(bar.lastTrackedCell)

        bar.setFrameSize(NSSize(width: leftMargin + 40 + 4 + 40 + rightMargin + 2, height: 22))
        click(at: rightEdge - 20)
        XCTAssertTrue(bar.lastTrackedCell === right)
    }

    /// A cell on the left is hidden when it would come within twelve points of the right-hand end
    func testACellOnTheLeftIsHiddenWhenItWouldComeTooCloseToTheRight() {
        let left = cell()
        bar.setLeftCells([left])

        bar.setFrameSize(NSSize(width: leftMargin + 40 + 12 + rightMargin - 5, height: 22))
        click(at: leftMargin + 20)
        XCTAssertNil(bar.lastTrackedCell)

        bar.setFrameSize(NSSize(width: leftMargin + 40 + 12 + rightMargin - 1, height: 22))
        click(at: leftMargin + 20)
        XCTAssertNil(bar.lastTrackedCell, "Just within twelve points")

        bar.setFrameSize(NSSize(width: leftMargin + 40 + 12 + rightMargin + 2, height: 22))
        click(at: leftMargin + 20)
        XCTAssertTrue(bar.lastTrackedCell === left)
    }

    func testAHiddenCellIsNotDrawn() {
        bar.setIsActive(true)
        bar.setLeftCells([cell()])
        bar.setRightCells([imageCell(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))])

        bar.setFrameSize(NSSize(width: 78, height: 22))
        XCTAssertFalse(hasRed(picture()))

        bar.setFrameSize(NSSize(width: 90, height: 22))
        XCTAssertTrue(hasRed(picture()))
    }

    // MARK: - Drawing

    /// The bar draws a line along its bottom, under the cells
    func testTheBarDrawsALineAlongItsBottom() {
        let rep = picture()
        let bottom = rep.pixelsHigh - 1

        XCTAssertGreaterThan(alpha(in: rep, x: 100, y: bottom), 0)
        XCTAssertEqual(alpha(in: rep, x: 1, y: bottom), 0)
        XCTAssertEqual(alpha(in: rep, x: Int(rightEdge) + 5, y: bottom), 0)
        XCTAssertEqual(alpha(in: rep, x: 100, y: bottom - 2), 0)
    }

    /// The cells on the left have a line after them, and those on the right a line before them; the first on each
    /// side has a line on both sides
    func testTheCellsAreSeparatedByLines() {
        bar.setIsActive(true)
        bar.setLeftCells([cell(), cell()])
        bar.setRightCells([cell(), cell()])
        let rep = picture()
        let y = 10

        // On the left, from 3 to 43 and from 43 to 83
        XCTAssertGreaterThan(alpha(in: rep, x: 3, y: y), 0)
        XCTAssertEqual(alpha(in: rep, x: 20, y: y), 0)
        XCTAssertGreaterThan(alpha(in: rep, x: 42, y: y), 0)
        XCTAssertEqual(alpha(in: rep, x: 43, y: y), 0)
        XCTAssertGreaterThan(alpha(in: rep, x: 82, y: y), 0)

        // On the right, from 346 to 386 and from 306 to 346
        XCTAssertGreaterThan(alpha(in: rep, x: 385, y: y), 0)
        XCTAssertEqual(alpha(in: rep, x: 360, y: y), 0)
        XCTAssertGreaterThan(alpha(in: rep, x: 346, y: y), 0)
        XCTAssertEqual(alpha(in: rep, x: 345, y: y), 0)
        XCTAssertGreaterThan(alpha(in: rep, x: 306, y: y), 0)
    }

    /// The cells are drawn less opaque while the bar isn't active, and less again when they're disabled
    func testTheCellsAreFadedWhenTheBarIsInactiveOrTheyAreDisabled() {
        let red = imageCell(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
        bar.setLeftCells([red])

        XCTAssertEqual(greatestAlpha(in: picture()), 0.85, accuracy: 0.01)

        bar.setIsActive(true)
        XCTAssertEqual(greatestAlpha(in: picture()), 1.0, accuracy: 0.01)

        red.isEnabled = false
        XCTAssertEqual(greatestAlpha(in: picture()), 0.5, accuracy: 0.01)

        bar.setIsActive(false)
        XCTAssertEqual(greatestAlpha(in: picture()), 0.425, accuracy: 0.01)
    }

    // MARK: - Redrawing

    func testChangingTheCellsRedrawsTheBar() {
        // AppKit marks the bar for display while it's set up
        bar.timesMarkedForDisplay = 0

        bar.setLeftCells([cell()])
        XCTAssertEqual(bar.timesMarkedForDisplay, 1)

        bar.setRightCells([cell()])
        XCTAssertEqual(bar.timesMarkedForDisplay, 2)
    }

    func testActivatingRedrawsTheBarOnlyWhenItChanges() {
        // AppKit marks the bar for display while it's set up
        bar.timesMarkedForDisplay = 0

        bar.setIsActive(false)
        XCTAssertEqual(bar.timesMarkedForDisplay, 0)

        bar.setIsActive(true)
        XCTAssertEqual(bar.timesMarkedForDisplay, 1)

        bar.setIsActive(true)
        XCTAssertEqual(bar.timesMarkedForDisplay, 1)

        bar.setIsActive(false)
        XCTAssertEqual(bar.timesMarkedForDisplay, 2)
    }

    /// Updating a cell redraws it; the cell at each end is redrawn out to the end of the bar
    func testUpdatingACellRedrawsIt() {
        let leftFirst = cell()
        let leftSecond = cell()
        let rightFirst = cell()
        let rightSecond = cell()
        bar.setLeftCells([leftFirst, leftSecond])
        bar.setRightCells([rightFirst, rightSecond])

        let expected: [(NSCell, NSRect)] = [
            (leftSecond, NSRect(x: 43, y: 0, width: 40, height: 22)),
            (leftFirst, NSRect(x: 0, y: 0, width: 43, height: 22)),
            (rightSecond, NSRect(x: 306, y: 0, width: 40, height: 22)),
            (rightFirst, NSRect(x: 346, y: 0, width: 54, height: 22)),
        ]
        for (cell, rect) in expected {
            bar.invalidatedRects = []
            bar.updateCell(cell)
            XCTAssertEqual(bar.invalidatedRects, [rect])

            bar.invalidatedRects = []
            bar.updateCellInside(cell)
            XCTAssertEqual(bar.invalidatedRects, [rect])
        }
    }

    func testUpdatingACellNotInTheBarDoesNothing() {
        bar.setLeftCells([cell()])
        bar.setRightCells([cell()])

        bar.invalidatedRects = []
        bar.updateCell(cell())

        XCTAssertEqual(bar.invalidatedRects, [])
    }

    // MARK: - States

    /// Turning a cell on turns off the others in its radio group, on both sides of the bar
    func testTurningACellOnTurnsOffTheOthersInItsGroupOnBothSides() {
        let leftSame = cell()
        let leftOther = cell()
        let rightSame = cell()
        let turnedOn = cell()
        for cell in [leftSame, rightSame, turnedOn] {
            cell.radioGroup = 1
        }
        leftOther.radioGroup = 2
        for cell in [leftSame, leftOther, rightSame] {
            cell.state = .on
        }
        bar.setLeftCells([leftSame, leftOther])
        bar.setRightCells([rightSame, turnedOn])

        bar.setState(Int32(NSControl.StateValue.on.rawValue), for: turnedOn)

        XCTAssertEqual(turnedOn.state, .on)
        XCTAssertEqual(leftSame.state, .off)
        XCTAssertEqual(rightSame.state, .off)
        XCTAssertEqual(leftOther.state, .on)
    }

    /// A cell that isn't a page bar cell isn't in any radio group
    func testOtherCellsAreLeftAlone() {
        let button = NSButtonCell()
        button.setButtonType(.radio)
        button.state = .on
        let turnedOn = cell()
        turnedOn.radioGroup = 0
        bar.setLeftCells([button])
        bar.setRightCells([turnedOn])

        bar.setState(Int32(NSControl.StateValue.on.rawValue), for: turnedOn)

        XCTAssertEqual(button.state, .on)
    }

    // MARK: - Key equivalents

    func testAnInactiveBarIgnoresKeyEquivalents() {
        let back = cell()
        back.setKeyEquivalent("-")
        bar.setLeftCells([back])

        XCTAssertFalse(bar.performKeyEquivalent(with: keyEvent("-")))
        XCTAssertEqual(target.senders.count, 0)
    }

    func testTheCellsOnTheRightHaveKeyEquivalents() {
        let next = cell()
        next.setKeyEquivalent("x")
        bar.setRightCells([next])
        bar.setIsActive(true)

        XCTAssertTrue(bar.performKeyEquivalent(with: keyEvent("x")))
        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(target.senders.first! === bar)
    }

    /// When a cell on each side has the key equivalent, the one on the left has it
    func testTheCellsOnTheLeftComeFirst() {
        let left = cell()
        let right = cell()
        left.setKeyEquivalent("=")
        right.setKeyEquivalent("=")
        let rightTarget = Target()
        right.target = rightTarget
        bar.setLeftCells([left])
        bar.setRightCells([right])
        bar.setIsActive(true)

        XCTAssertTrue(bar.performKeyEquivalent(with: keyEvent("=")))
        XCTAssertEqual(target.senders.count, 1)
        XCTAssertEqual(rightTarget.senders.count, 0)
    }

    func testAKeyNoCellHasIsNotHandled() {
        let back = cell()
        back.setKeyEquivalent("-")
        bar.setLeftCells([back])
        bar.setIsActive(true)

        XCTAssertFalse(bar.performKeyEquivalent(with: keyEvent("q")))
        XCTAssertEqual(target.senders.count, 0)
    }
}
