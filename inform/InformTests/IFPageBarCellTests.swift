//
//  IFPageBarCellTests.swift
//  InformTests
//

import XCTest

final class IFPageBarCellTests: XCTestCase {

    /// A page bar that records what its cells ask of it
    private final class RecordingBar: IFPageBarView {
        var updatedCells: [NSCell] = []
        var statesSet: [(state: Int32, cell: IFPageBarCell)] = []

        override func updateCell(_ cell: NSCell) {
            updatedCells.append(cell)
            super.updateCell(cell)
        }

        override func setState(_ state: Int32, for cell: IFPageBarCell) {
            statesSet.append((state, cell))
            super.setState(state, for: cell)
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

    /// The size the cells are drawn at
    private let cellSize = NSSize(width: 100, height: 22)

    override func setUp() {
        super.setUp()
        // NSWindow moves a window made off the screen onto it, so it's moved off afterwards, so that the mouse is
        // never over the bar
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 22),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))

        bar = RecordingBar(frame: NSRect(x: 0, y: 0, width: 400, height: 22))
        window.contentView?.addSubview(bar)
        target = Target()
    }

    override func tearDown() {
        // Take off any events a test left queued
        while NSApp.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) != nil {
        }
        window.close()
        window = nil
        bar = nil
        target = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Puts cells on the left of the bar, and draws it, which makes it their control view, as in the app
    private func attach(_ cells: [IFPageBarCell]) {
        bar.setLeftCells(cells)
        bar.layoutCells()
        let rep = bar.bitmapImageRepForCachingDisplay(in: bar.bounds)!
        bar.cacheDisplay(in: bar.bounds, to: rep)
        for cell in cells {
            XCTAssertTrue(cell.controlView === bar)
        }
        bar.updatedCells = []
        bar.statesSet = []
    }

    private func radioCell(_ title: String, group: Int32 = 1) -> IFPageBarCell {
        let cell = IFPageBarCell(textCell: title)
        cell.radioGroup = group
        return cell
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
        return NSEvent.mouseEvent(with: type, location: bar.convert(point, to: nil), modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                  clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    }

    /// Follows the mouse in a cell as the bar does, from a press at a point through the events given, which are
    /// queued first
    @discardableResult
    private func track(_ cell: IFPageBarCell, in frame: NSRect, from point: NSPoint, through events: [NSEvent]) -> Bool {
        for event in events {
            NSApp.postEvent(event, atStart: false)
        }
        return cell.trackMouse(with: mouseEvent(.leftMouseDown, at: point), in: frame, of: bar, untilMouseUp: false)
    }

    /// A cell drawn in the bar into a bitmap, at the cell size, with the given appearance
    private func picture(of cell: IFPageBarCell, appearance: NSAppearance.Name = .aqua) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cellSize.width),
                                   pixelsHigh: Int(cellSize.height), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            cell.draw(withFrame: NSRect(origin: .zero, size: cellSize), in: bar)
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep
    }

    /// The colour of a pixel, with y measured from the top
    private func colour(in rep: NSBitmapImageRep, x: Int, y: Int) -> NSColor {
        return rep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    }

    /// Every pixel's colour
    private func colours(in rep: NSBitmapImageRep) -> [NSColor] {
        var result: [NSColor] = []
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                result.append(colour(in: rep, x: x, y: y))
            }
        }
        return result
    }

    /// Whether something nearly white is drawn (the label colour is partly transparent, so a template image drawn
    /// in it keeps a little of its own colour)
    private func hasWhiteInk(_ rep: NSBitmapImageRep) -> Bool {
        return colours(in: rep).contains {
            $0.alphaComponent > 0.5 && min($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.8
        }
    }

    /// Whether something nearly black is drawn
    private func hasBlackInk(_ rep: NSBitmapImageRep) -> Bool {
        return colours(in: rep).contains {
            $0.alphaComponent > 0.5 && max($0.redComponent, $0.greenComponent, $0.blueComponent) < 0.2
        }
    }

    /// A square of a colour
    private func square(_ colour: NSColor, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            colour.setFill()
            rect.fill()
            return true
        }
        image.isTemplate = template
        return image
    }

    /// The font and colour of the cell's text
    private func attributes(of cell: NSCell) -> [NSAttributedString.Key: Any] {
        return cell.attributedStringValue.attributes(at: 0, effectiveRange: nil)
    }

    // MARK: - Making cells

    func testATextCell() {
        let cell = IFPageBarCell(textCell: "Contents")

        XCTAssertEqual(cell.stringValue, "Contents")
        XCTAssertEqual(attributes(of: cell)[.font] as? NSFont, NSFont.systemFont(ofSize: 11))
        XCTAssertEqual(attributes(of: cell)[.foregroundColor] as? NSColor, NSColor.controlTextColor)
        XCTAssertNil(cell.image)
        XCTAssertEqual(cell.radioGroup, -1)
        XCTAssertEqual(cell.state, .off)
        XCTAssertNil(cell.identifier)
    }

    func testAnImageCell() {
        let image = square(.red)
        let cell = IFPageBarCell(imageCell: image)

        XCTAssertTrue(cell.image === image)
        XCTAssertEqual(cell.radioGroup, -1)
        XCTAssertEqual(cell.state, .off)
    }

    func testAPlainCell() {
        let cell = IFPageBarCell()

        XCTAssertEqual(cell.radioGroup, -1)
        XCTAssertEqual(cell.state, .off)
        XCTAssertEqual(cell.stringValue, "")
    }

    func testSettingTheTextUsesTheBarsFont() {
        // As the Index page does
        let cell = IFPageBarCell()
        cell.stringValue = "Actions"

        XCTAssertEqual(cell.stringValue, "Actions")
        XCTAssertEqual(attributes(of: cell)[.font] as? NSFont, NSFont.systemFont(ofSize: 11))
        XCTAssertEqual(attributes(of: cell)[.foregroundColor] as? NSColor, NSColor.controlTextColor)
    }

    func testSettingTheTitleUsesTheBarsFont() {
        // As the Skein page does
        let cell = IFPageBarCell(textCell: "")
        cell.title = "Show Help"

        XCTAssertEqual(cell.stringValue, "Show Help")
        XCTAssertEqual(attributes(of: cell)[.font] as? NSFont, NSFont.systemFont(ofSize: 11))
    }

    func testTheIdentifierIsAppKits() {
        // The pages keep their tabs' numbers in the represented object
        let cell = IFPageBarCell(textCell: "Contents")
        cell.identifier = NSUserInterfaceItemIdentifier("Contents")

        XCTAssertEqual(cell.identifier, NSUserInterfaceItemIdentifier("Contents"))
    }

    // MARK: - Key equivalents

    func testTheKeyEquivalentIsEmptyUntilSet() {
        XCTAssertEqual(IFPageBarCell(textCell: "Back").keyEquivalent, "")
        XCTAssertEqual(IFPageBarCell().keyEquivalent, "")
    }

    func testTheKeyEquivalentIsCopied() {
        let cell = IFPageBarCell(textCell: "Back")
        let key = NSMutableString(string: "-")
        cell.setKeyEquivalent(key as String)
        key.append("=")

        XCTAssertEqual(cell.keyEquivalent, "-")
    }

    func testTheBarSendsTheActionOfTheCellWithTheKeyEquivalent() {
        let back = IFPageBarCell(textCell: "Back")
        let forward = IFPageBarCell(textCell: "Forward")
        back.setKeyEquivalent("-")
        forward.setKeyEquivalent("=")
        forward.target = target
        forward.action = #selector(Target.act(_:))
        attach([back, forward])
        bar.setIsActive(true)

        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: ProcessInfo.processInfo.systemUptime,
                                     windowNumber: window.windowNumber, context: nil,
                                     characters: "=", charactersIgnoringModifiers: "=", isARepeat: false,
                                     keyCode: 24)!
        XCTAssertTrue(bar.performKeyEquivalent(with: event))
        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(target.senders.first! === bar)
    }

    // MARK: - Size

    func testTheSizeOfATextCell() {
        let cell = IFPageBarCell(textCell: "Contents")
        let textSize = cell.attributedStringValue.size()

        // The text, two points either side and four points of margin either side
        XCTAssertEqual(cell.cellSize, NSSize(width: floor(textSize.width + 12 + 0.5), height: floor(textSize.height)))
    }

    func testTheSizeOfAnImageCell() {
        let cell = IFPageBarCell(imageCell: NSImage(size: NSSize(width: 16, height: 13)))

        XCTAssertEqual(cell.cellSize, NSSize(width: 28, height: 13))
    }

    func testTheSizeOfACellWithAnImageAndText() {
        let cell = IFPageBarCell(textCell: "Contents")
        cell.image = NSImage(size: NSSize(width: 16, height: 30))
        let textSize = cell.attributedStringValue.size()

        // Two points between the image and the text, and the tallest of them
        XCTAssertEqual(cell.cellSize, NSSize(width: floor(16 + 2 + textSize.width + 12 + 0.5), height: 30))
    }

    func testTheSizeOfAnEmptyCell() {
        let cell = IFPageBarCell()
        // The height of a line with no text
        let textSize = cell.attributedStringValue.size()

        XCTAssertEqual(cell.cellSize, NSSize(width: 12, height: floor(textSize.height)))
    }

    // MARK: - State

    func testOnlyARadioCellTurnsOnWhenClicked() {
        XCTAssertEqual(IFPageBarCell(textCell: "Play All").nextState, NSControl.StateValue.off.rawValue)
        XCTAssertEqual(radioCell("Source", group: 0).nextState, NSControl.StateValue.on.rawValue)
        XCTAssertEqual(radioCell("Actions", group: 128).nextState, NSControl.StateValue.on.rawValue)
    }

    func testTurningARadioCellOnTurnsTheOthersInItsGroupOff() {
        let source = radioCell("Source")
        let headings = radioCell("Headings")
        let other = radioCell("Other", group: 2)
        attach([source, headings, other])

        source.state = .on
        other.state = .on
        headings.state = .on

        XCTAssertEqual(source.state, .off)
        XCTAssertEqual(headings.state, .on)
        XCTAssertEqual(other.state, .on, "A cell in another group was turned off")
    }

    func testTurningARadioCellOffLeavesTheOthers() {
        let source = radioCell("Source")
        let headings = radioCell("Headings")
        attach([source, headings])
        source.state = .on

        source.state = .off
        XCTAssertEqual(source.state, .off)
        XCTAssertEqual(headings.state, .off)

        headings.state = .on
        headings.state = .off
        XCTAssertEqual(source.state, .off)
    }

    func testCellsNotInARadioGroupCanAllBeOn() {
        let first = IFPageBarCell(textCell: "First")
        let second = IFPageBarCell(textCell: "Second")
        attach([first, second])

        first.state = .on
        second.state = .on

        XCTAssertEqual(first.state, .on)
        XCTAssertEqual(second.state, .on)
        XCTAssertTrue(bar.statesSet.isEmpty, "The bar was asked to change the state of a cell in no group")
    }

    func testARadioCellTellsTheBarWhenItsStateChanges() {
        let source = radioCell("Source")
        attach([source])

        source.state = .on
        source.state = .off

        XCTAssertEqual(bar.statesSet.map(\.state), [1, 0])
        XCTAssertTrue(bar.statesSet.allSatisfy { $0.cell === source })
    }

    func testChangingTheStateRedrawsTheCell() {
        let cell = IFPageBarCell(textCell: "Play All")
        attach([cell])

        cell.state = .on

        XCTAssertEqual(bar.updatedCells.count, 1)
        XCTAssertTrue(bar.updatedCells.first === cell)
    }

    func testSettingTheSameStateDoesNothing() {
        let cell = radioCell("Source")
        attach([cell])
        cell.state = .on
        bar.updatedCells = []
        bar.statesSet = []

        cell.state = .on

        XCTAssertTrue(bar.updatedCells.isEmpty)
        XCTAssertTrue(bar.statesSet.isEmpty)
    }

    func testHighlightingRedrawsTheCell() {
        let cell = IFPageBarCell(textCell: "Play All")
        attach([cell])

        cell.isHighlighted = true
        XCTAssertTrue(cell.isHighlighted)
        XCTAssertFalse(bar.updatedCells.isEmpty)
        XCTAssertTrue(bar.updatedCells.allSatisfy { $0 === cell })

        bar.updatedCells = []
        cell.isHighlighted = false
        XCTAssertFalse(cell.isHighlighted)
        XCTAssertFalse(bar.updatedCells.isEmpty)
        XCTAssertTrue(bar.updatedCells.allSatisfy { $0 === cell })
    }

    func testACellOutsideABarCanChangeState() {
        let cell = radioCell("Source")

        cell.state = .on
        cell.isHighlighted = true

        XCTAssertEqual(cell.state, .on)
        XCTAssertTrue(cell.isHighlighted)
    }

    // MARK: - Following the mouse

    func testPressingTheMouseHighlightsTheCell() {
        let cell = IFPageBarCell(textCell: "Play All")
        attach([cell])

        XCTAssertTrue(cell.startTracking(at: NSPoint(x: 10, y: 10), in: bar))
        XCTAssertTrue(cell.isHighlighted)
    }

    func testAClickSendsTheAction() {
        let cell = IFPageBarCell(textCell: "Play All")
        cell.target = target
        cell.action = #selector(Target.act(_:))
        attach([cell])
        let frame = NSRect(x: 3, y: 0, width: 60, height: 22)

        XCTAssertTrue(track(cell, in: frame, from: NSPoint(x: 20, y: 10),
                            through: [mouseEvent(.leftMouseUp, at: NSPoint(x: 22, y: 11))]))

        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(target.senders.first! === bar)
        XCTAssertFalse(cell.isHighlighted)
    }

    func testDraggingOutOfTheCellStopsFollowingTheMouse() {
        let cell = IFPageBarCell(textCell: "Play All")
        cell.target = target
        cell.action = #selector(Target.act(_:))
        attach([cell])
        let frame = NSRect(x: 3, y: 0, width: 60, height: 22)

        XCTAssertFalse(track(cell, in: frame, from: NSPoint(x: 20, y: 10),
                             through: [mouseEvent(.leftMouseDragged, at: NSPoint(x: 100, y: 10)),
                                       mouseEvent(.leftMouseUp, at: NSPoint(x: 100, y: 10))]))

        XCTAssertTrue(target.senders.isEmpty)
        XCTAssertFalse(cell.isHighlighted)
    }

    func testTheHighlightFollowsTheMouseInAndOutOfTheCell() {
        let cell = IFPageBarCell(textCell: "Play All")
        attach([cell])
        // Following a click sets the frame the cell is in
        let frame = NSRect(x: 3, y: 0, width: 60, height: 22)
        track(cell, in: frame, from: NSPoint(x: 20, y: 10),
              through: [mouseEvent(.leftMouseUp, at: NSPoint(x: 20, y: 10))])

        XCTAssertTrue(cell.continueTracking(last: NSPoint(x: 20, y: 10), current: NSPoint(x: 30, y: 10), in: bar))
        XCTAssertTrue(cell.isHighlighted)

        XCTAssertTrue(cell.continueTracking(last: NSPoint(x: 30, y: 10), current: NSPoint(x: 70, y: 10), in: bar))
        XCTAssertFalse(cell.isHighlighted)

        XCTAssertTrue(cell.continueTracking(last: NSPoint(x: 70, y: 10), current: NSPoint(x: 4, y: 1), in: bar))
        XCTAssertTrue(cell.isHighlighted)

        cell.stopTracking(last: NSPoint(x: 4, y: 1), current: NSPoint(x: 4, y: 1), in: bar, mouseIsUp: true)
        XCTAssertFalse(cell.isHighlighted)
    }

    func testAClickOnACellInTheBarSendsItsAction() {
        let first = radioCell("First")
        let second = radioCell("Second")
        second.target = target
        second.action = #selector(Target.act(_:))
        attach([first, second])
        // The second cell starts after the first, which starts three points in
        let point = NSPoint(x: 3 + first.cellSize.width + 5, y: 11)

        NSApp.postEvent(mouseEvent(.leftMouseUp, at: point), atStart: false)
        bar.mouseDown(with: mouseEvent(.leftMouseDown, at: point))

        XCTAssertEqual(target.senders.count, 1)
        XCTAssertTrue(bar.lastTrackedCell === second)
    }

    // MARK: - Drawing

    func testAnOrdinaryCellDrawsNoBackground() {
        let rep = picture(of: IFPageBarCell(textCell: "Play All"))

        XCTAssertEqual(colour(in: rep, x: 2, y: 2).alphaComponent, 0)
        XCTAssertEqual(colour(in: rep, x: 90, y: 20).alphaComponent, 0)
    }

    func testAHighlightedCellDrawsTheHighlightBehindIt() {
        let cell = IFPageBarCell(textCell: "Play All")
        cell.isHighlighted = true
        let corner = colour(in: picture(of: cell), x: 2, y: 2)

        XCTAssertGreaterThan(corner.alphaComponent, 0.99)
        XCTAssertGreaterThan(min(corner.redComponent, corner.greenComponent, corner.blueComponent), 0.95)
    }

    func testACellThatIsOnDrawsTheSelectionBehindIt() {
        let cell = IFPageBarCell(textCell: "Source")
        cell.state = .on
        let corner = colour(in: picture(of: cell), x: 2, y: 2)

        XCTAssertGreaterThan(corner.alphaComponent, 0.99)
        XCTAssertLessThan(min(corner.redComponent, corner.greenComponent, corner.blueComponent), 0.9)
    }

    func testTheBackgroundOfACellOnTheRightIsOnePointFurtherRight() {
        let left = IFPageBarCell(textCell: "Play All")
        left.isHighlighted = true
        let right = IFPageBarCell(textCell: "Play All")
        right.isHighlighted = true
        right.setIsRight(true)

        let leftPicture = picture(of: left)
        XCTAssertGreaterThan(colour(in: leftPicture, x: 0, y: 2).alphaComponent, 0.99)
        XCTAssertEqual(colour(in: leftPicture, x: 99, y: 2).alphaComponent, 0)

        let rightPicture = picture(of: right)
        XCTAssertEqual(colour(in: rightPicture, x: 0, y: 2).alphaComponent, 0)
        XCTAssertGreaterThan(colour(in: rightPicture, x: 99, y: 2).alphaComponent, 0.99)
    }

    func testTextIsDrawnInTheLabelColour() {
        let cell = IFPageBarCell(textCell: "Play All")

        let light = picture(of: cell, appearance: .aqua)
        XCTAssertTrue(hasBlackInk(light))
        XCTAssertFalse(hasWhiteInk(light))

        let dark = picture(of: cell, appearance: .darkAqua)
        XCTAssertTrue(hasWhiteInk(dark))
        XCTAssertFalse(hasBlackInk(dark))
    }

    func testTheTextOfACellThatIsOnIsWhite() {
        let cell = IFPageBarCell(textCell: "Source")
        cell.state = .on
        let rep = picture(of: cell)

        XCTAssertTrue(hasWhiteInk(rep))
        XCTAssertFalse(hasBlackInk(rep))
    }

    func testTheTextOfAHighlightedCellIsBlack() {
        let cell = IFPageBarCell(textCell: "Source")
        cell.isHighlighted = true

        XCTAssertTrue(hasBlackInk(picture(of: cell, appearance: .darkAqua)))
    }

    func testATemplateImageIsDrawnInTheTextColour() {
        let cell = IFPageBarCell(imageCell: square(.black, template: true))

        XCTAssertTrue(hasBlackInk(picture(of: cell, appearance: .aqua)))
        XCTAssertTrue(hasWhiteInk(picture(of: cell, appearance: .darkAqua)))

        let onCell = IFPageBarCell(imageCell: square(.black, template: true))
        onCell.state = .on
        let on = picture(of: onCell)
        XCTAssertTrue(hasWhiteInk(on))
        XCTAssertFalse(hasBlackInk(on))
    }

    func testAnEmptyTextCellDrawsNothing() {
        // As the Skein page makes its help cell, before giving it a title
        let rep = picture(of: IFPageBarCell(textCell: ""))

        XCTAssertTrue(colours(in: rep).allSatisfy { $0.alphaComponent == 0 })
    }

    func testAnImageThatIsntATemplateKeepsItsColours() {
        let cell = IFPageBarCell(imageCell: square(.red))
        // In the middle of the cell
        let middle = colour(in: picture(of: cell), x: 50, y: 11)

        XCTAssertGreaterThan(middle.redComponent, 0.9)
        XCTAssertLessThan(middle.greenComponent, 0.1)
        XCTAssertLessThan(middle.blueComponent, 0.1)
    }

    func testTheImageAndTextOfACellThatIsOnAreWhite() {
        let cell = IFPageBarCell(textCell: "Source")
        cell.image = square(.black, template: true)
        cell.state = .on
        let rep = picture(of: cell)

        XCTAssertTrue(hasWhiteInk(rep))
        XCTAssertFalse(hasBlackInk(rep))
    }
}
