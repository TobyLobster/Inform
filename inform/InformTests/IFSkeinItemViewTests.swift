//
//  IFSkeinItemViewTests.swift
//  InformTests
//

import XCTest

final class IFSkeinItemViewTests: XCTestCase {

    // The menu's area, as IFSkeinItemView has it: the visible size of its image, the image's offset from the end of
    // the command, and how far in from the image's bottom left the mouse is over it
    private let menuVisibleWidth: CGFloat     = 21.0
    private let menuVisibleHeight: CGFloat    = 21.0
    private let drawMenuOffsetX: CGFloat      = -3.0
    private let menuMouseOverOffsetX: CGFloat = 6.0
    private let menuMouseOverOffsetY: CGFloat = 4.0

    private let skein: IFSkein = IFSkein(project: nil)
    private var window: NSWindow!
    private var skeinView: IFSkeinView!
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        // Far off the screen, so that the mouse is never over a knot. NSWindow moves a window made off the screen
        // onto it, so it's moved off afterwards.
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        skeinView = IFSkeinView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        window.contentView?.addSubview(skeinView)
        pasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        window.close()
        window = nil
        skeinView = nil
        super.tearDown()
    }

    private func add(_ command: String, to parent: IFSkeinItem, actual: String) -> IFSkeinItem {
        let item: IFSkeinItem = IFSkeinItem(skein: skein, command: command)
        item.actual = actual
        return parent.addChild(item)
    }

    /// A skein of three levels (a knot's children are in alphabetical order), shown in the skein view:
    ///
    ///     - start -
    ///     ├── look
    ///     │   └── north
    ///     └── wait
    private func makeSkein() -> (look: IFSkeinItem, north: IFSkeinItem, wait: IFSkeinItem) {
        skein.rootItem.actual = "Welcome\n>"
        let look = add("look", to: skein.rootItem, actual: "A room.\n>")
        let north = add("north", to: look, actual: "A hall.\n>")
        let wait = add("wait", to: skein.rootItem, actual: "Time passes.\n>")
        skeinView.skein = skein
        return (look, north, wait)
    }

    /// Lays the skein out again, as after any change to it
    private func layOut() {
        skein.postChanged(withAnimate: false, keepActiveVisible: false)
    }

    private func knot(_ item: IFSkeinItem, in view: IFSkeinView? = nil) throws -> IFSkeinItemView {
        return try XCTUnwrap((view ?? skeinView).subviews.compactMap { $0 as? IFSkeinItemView }
                                                          .first { $0.layoutItem?.item === item })
    }

    // MARK: - Drawing helpers

    private func bitmap(_ view: NSView) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    /// The colour of the bitmap of a view at a point in the view
    private func colour(_ rep: NSBitmapImageRep, at point: NSPoint, in view: NSView) -> NSColor? {
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        let y = view.isFlipped ? point.y : view.bounds.height - point.y
        return rep.colorAt(x: Int(point.x * scale), y: Int(y * scale))
    }

    /// The smallest rectangle, in the view's coordinates, holding every pixel that differs between two bitmaps of it,
    /// or nil if none do
    private func differences(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, in view: NSView) throws -> NSRect? {
        XCTAssertEqual(a.pixelsWide, b.pixelsWide)
        XCTAssertEqual(a.pixelsHigh, b.pixelsHigh)
        XCTAssertEqual(a.bytesPerRow, b.bytesPerRow)
        let dataA = try XCTUnwrap(a.bitmapData)
        let dataB = try XCTUnwrap(b.bitmapData)
        let bytesPerPixel = a.bitsPerPixel / 8
        var result: NSRect?
        let scale = CGFloat(a.pixelsWide) / view.bounds.width
        for row in 0..<a.pixelsHigh {
            for x in 0..<a.pixelsWide {
                let offset = row * a.bytesPerRow + x * bytesPerPixel
                if memcmp(dataA + offset, dataB + offset, bytesPerPixel) != 0 {
                    let y = view.isFlipped ? CGFloat(row) / scale : view.bounds.height - CGFloat(row + 1) / scale
                    let pixel = NSRect(x: CGFloat(x) / scale, y: y, width: 1 / scale, height: 1 / scale)
                    result = result.map { NSUnionRect($0, pixel) } ?? pixel
                }
            }
        }
        return result
    }

    // MARK: - Mouse helpers

    /// The knot's tracking areas: the menu's, and the lozenge's, which includes the menu's
    private func trackingAreas(_ knot: IFSkeinItemView) throws -> (menu: NSTrackingArea, lozenge: NSTrackingArea) {
        XCTAssertEqual(knot.trackingAreas.count, 2)
        let areas = knot.trackingAreas.sorted { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
        let menu = try XCTUnwrap(areas.first)
        let lozenge = try XCTUnwrap(areas.last)
        return (menu, lozenge)
    }

    private func enterExitEvent(_ type: NSEvent.EventType, _ area: NSTrackingArea) throws -> NSEvent {
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                                                         windowNumber: window.windowNumber, context: nil,
                                                         eventNumber: 0,
                                                         trackingNumber: Int(bitPattern: Unmanaged.passUnretained(area).toOpaque()),
                                                         userData: nil))
        XCTAssertIdentical(event.trackingArea, area)
        return event
    }

    /// Moves the mouse into the knot's lozenge, and into its menu too if asked
    private func enter(_ knot: IFSkeinItemView, menu: Bool = false) throws {
        knot.updateTrackingAreas()
        let areas = try trackingAreas(knot)
        knot.mouseEntered(with: try enterExitEvent(.mouseEntered, areas.lozenge))
        if menu {
            knot.mouseEntered(with: try enterExitEvent(.mouseEntered, areas.menu))
        }
    }

    private func exit(_ knot: IFSkeinItemView, menu: Bool = false) throws {
        let areas = try trackingAreas(knot)
        if menu {
            knot.mouseExited(with: try enterExitEvent(.mouseExited, areas.menu))
        }
        knot.mouseExited(with: try enterExitEvent(.mouseExited, areas.lozenge))
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in view: NSView) throws -> NSEvent {
        return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [],
                                                timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func click(_ knot: IFSkeinItemView) throws {
        let centre = NSPoint(x: knot.bounds.midX, y: knot.bounds.midY)
        knot.mouseDown(with: try mouseEvent(.leftMouseDown, at: centre, in: knot))
        knot.mouseUp(with: try mouseEvent(.leftMouseUp, at: centre, in: knot))
    }

    // MARK: - Dragging helpers

    /// What a drag gives its destination
    private final class DraggingInfo: NSObject, NSDraggingInfo {
        let draggingDestinationWindow: NSWindow?
        let draggingSourceOperationMask: NSDragOperation
        let draggingLocation: NSPoint
        var draggedImageLocation: NSPoint { return draggingLocation }
        var draggedImage: NSImage? { return nil }
        let draggingPasteboard: NSPasteboard
        let draggingSource: Any?
        var draggingSequenceNumber: Int { return 1 }
        func slideDraggedImage(to screenPoint: NSPoint) {}
        var draggingFormation: NSDraggingFormation = .default
        var animatesToDestination = false
        var numberOfValidItemsForDrop = 1
        func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [],
                                    for view: NSView?,
                                    classes classArray: [AnyClass],
                                    searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
                                    using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
        var springLoadingHighlight: NSSpringLoadingHighlight { return .none }
        func resetSpringLoading() {}

        init(window: NSWindow?, mask: NSDragOperation, location: NSPoint, pasteboard: NSPasteboard, source: Any?) {
            draggingDestinationWindow = window
            draggingSourceOperationMask = mask
            draggingLocation = location
            draggingPasteboard = pasteboard
            draggingSource = source
        }
    }

    /// A drag of the source knot (or of nothing) to the centre of the destination knot's lozenge, or to a point in
    /// the skein view
    private func drag(_ source: IFSkeinItemView?, to destination: IFSkeinItem? = nil, point: NSPoint? = nil,
                      mask: NSDragOperation = [.copy, .move]) throws -> DraggingInfo {
        var location = point ?? .zero
        if let destination {
            let lozenge = try XCTUnwrap(try knot(destination).layoutItem).lozengeRect
            location = NSPoint(x: lozenge.midX, y: lozenge.midY)
        }
        return DraggingInfo(window: window, mask: mask, location: skeinView.convert(location, to: nil),
                            pasteboard: pasteboard, source: source)
    }

    /// Puts a knot on the pasteboard, as a drag of it does
    private func putOnPasteboard(_ item: IFSkeinItem) throws {
        let type = NSPasteboard.PasteboardType(IFSkeinItemPboardType)
        let data = try XCTUnwrap(item.pasteboardPropertyList(forType: type) as? Data)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setData(data, forType: type))
    }

    /// Counts the skein's change notifications while running the block
    private func changes(of skein: IFSkein, _ block: () throws -> Void) rethrows -> Int {
        var count = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFSkeinChanged, object: skein,
                                                              queue: nil) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        try block()
        return count
    }

    // MARK: - A new view

    /// A new view is layer-backed, redrawn only when asked, takes dropped knots, and has drawn nothing
    func testANewView() {
        let view = IFSkeinItemView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        XCTAssertNil(view.layoutItem)
        XCTAssertEqual(view.drawnStateHash, 0)
        XCTAssertTrue(view.wantsLayer)
        XCTAssertEqual(view.layerContentsRedrawPolicy, .onSetNeedsDisplay)
        XCTAssertEqual(view.registeredDraggedTypes, [NSPasteboard.PasteboardType(IFSkeinItemPboardType)])
    }

    /// Until it has its layout item, a view draws nothing and tracks nothing
    func testAViewWithoutItsLayoutItem() throws {
        let view = IFSkeinItemView(frame: NSRect(x: 10, y: 10, width: 100, height: 30))
        window.contentView?.addSubview(view)

        let rep = try bitmap(view)
        let data = try XCTUnwrap(rep.bitmapData)
        XCTAssertFalse(UnsafeBufferPointer(start: data, count: rep.bytesPerRow * rep.pixelsHigh).contains { $0 != 0 })

        view.updateTrackingAreas()
        XCTAssertEqual(view.trackingAreas, [])
    }

    // MARK: - The command's size

    /// A command's size is its size in the system font, or in bold for the start
    func testTheCommandSize() throws {
        let (look, _, _) = makeSkein()
        let font = NSFont.systemFont(ofSize: IFSkeinView.fontSize)
        let bold = NSFont.boldSystemFont(ofSize: IFSkeinView.fontSize)

        let lookItem = try XCTUnwrap(try knot(look).layoutItem)
        look.commandSizeDidChange = true
        XCTAssertEqual(IFSkeinItemView.commandSize(lookItem), ("look" as NSString).size(withAttributes: [.font: font]))
        XCTAssertFalse(look.commandSizeDidChange)

        let root: IFSkeinItem = skein.rootItem
        let rootItem = try XCTUnwrap(try knot(root).layoutItem)
        root.commandSizeDidChange = true
        XCTAssertEqual(IFSkeinItemView.commandSize(rootItem),
                       (root.command as NSString).size(withAttributes: [.font: bold]))
    }

    /// A command's size is kept until the command changes
    func testTheCommandSizeIsKept() throws {
        let (look, _, _) = makeSkein()
        let layoutItem = try XCTUnwrap(try knot(look).layoutItem)
        look.cachedCommandSize = NSSize(width: 1, height: 2)
        look.commandSizeDidChange = false
        XCTAssertEqual(IFSkeinItemView.commandSize(layoutItem), NSSize(width: 1, height: 2))

        look.command = "look around"
        XCTAssertTrue(look.commandSizeDidChange)
        let font = NSFont.systemFont(ofSize: IFSkeinView.fontSize)
        XCTAssertEqual(IFSkeinItemView.commandSize(layoutItem),
                       ("look around" as NSString).size(withAttributes: [.font: font]))
    }

    // MARK: - Drawing

    /// Drawing a knot remembers the state it drew, so that it's redrawn only when that changes
    func testDrawingRemembersTheState() throws {
        let (look, _, _) = makeSkein()
        let layoutItem = try XCTUnwrap(try knot(look).layoutItem)
        let view = IFSkeinItemView(frame: layoutItem.boundingRect)
        view.layoutItem = layoutItem
        XCTAssertEqual(view.drawnStateHash, 0)
        _ = try bitmap(view)
        XCTAssertEqual(view.drawnStateHash, layoutItem.drawStateHash)
        XCTAssertNotEqual(view.drawnStateHash, 0)
    }

    /// The lozenge has a different background for a knot recently played, one on the selected line, and the rest
    func testTheBackgroundShowsTheKnotsState() throws {
        let (look, north, wait) = makeSkein()
        skein.activeItem = look
        skeinView.select(north, withAnimation: false)
        layOut()

        func background(_ item: IFSkeinItem) throws -> NSColor? {
            let view = try knot(item)
            let lozenge = try XCTUnwrap(view.layoutItem).localSpaceLozengeRect
            return colour(try bitmap(view), at: NSPoint(x: lozenge.minX + 6, y: lozenge.midY), in: view)
        }
        XCTAssertTrue(try XCTUnwrap(knot(look).layoutItem).recentlyPlayed)
        XCTAssertFalse(try XCTUnwrap(knot(north).layoutItem).recentlyPlayed)
        XCTAssertTrue(try XCTUnwrap(knot(north).layoutItem).onSelectedLine)
        XCTAssertFalse(try XCTUnwrap(knot(wait).layoutItem).onSelectedLine)

        let played = try XCTUnwrap(try background(look))
        let selected = try XCTUnwrap(try background(north))
        let unselected = try XCTUnwrap(try background(wait))
        XCTAssertGreaterThan(played.alphaComponent, 0.9)
        XCTAssertGreaterThan(selected.alphaComponent, 0.9)
        XCTAssertGreaterThan(unselected.alphaComponent, 0.9)
        XCTAssertNotEqual(played, selected)
        XCTAssertNotEqual(played, unselected)
        XCTAssertNotEqual(selected, unselected)
    }

    /// A knot whose transcript differs from its blessed one has a badge at its top left
    func testTheBadge() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let plain = try bitmap(view)

        look.ideal = "A different room.\n>"
        XCTAssertTrue(look.hasBadge)
        let badged = try bitmap(view)
        let changed = try XCTUnwrap(try differences(plain, badged, in: view))
        XCTAssertLessThan(changed.minX, view.bounds.width / 4)
        XCTAssertGreaterThan(changed.maxY, view.bounds.height / 2)
    }

    /// The winning knot has a star at its bottom left
    func testTheWinningStar() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let plain = try bitmap(view)

        skein.winningItem = look
        let starred = try bitmap(view)
        let changed = try XCTUnwrap(try differences(plain, starred, in: view))
        XCTAssertLessThan(changed.minX, view.bounds.width / 4)
        XCTAssertLessThan(changed.minY, view.bounds.height / 2)
    }

    /// With the mouse over a knot, its menu shows after the command, highlighted while the mouse is over the menu
    func testTheMenuShowsWhenTheMouseIsOverTheKnot() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let layoutItem = try XCTUnwrap(view.layoutItem)
        let plain = try bitmap(view)

        try enter(view)
        let withMenu = try bitmap(view)
        let menu = try XCTUnwrap(try differences(plain, withMenu, in: view))
        let commandEnd = kSkeinItemImageCommandLeftBorder + IFSkeinItemView.commandSize(layoutItem).width
        XCTAssertGreaterThanOrEqual(menu.minX, floor(commandEnd + drawMenuOffsetX))

        try enter(view, menu: true)
        let highlighted = try bitmap(view)
        XCTAssertNotNil(try differences(withMenu, highlighted, in: view))

        try exit(view, menu: true)
        XCTAssertNil(try differences(plain, try bitmap(view), in: view))
    }

    /// A "test me" knot whose commands follow it has no menu
    func testATestMeKnotWithItsCommandsHasNoMenu() throws {
        let (look, north, _) = makeSkein()
        look.isTestSubItem = true
        north.isTestSubItem = true
        layOut()
        XCTAssertFalse(skeinView.hasMenu(look))

        let view = try knot(look)
        let plain = try bitmap(view)
        try enter(view, menu: true)
        XCTAssertNil(try differences(plain, try bitmap(view), in: view))
    }

    // MARK: - Tracking the mouse

    /// A knot tracks the mouse over its menu, and over its lozenge and menu together
    func testTheTrackingAreas() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let layoutItem = try XCTUnwrap(view.layoutItem)
        let mouse = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        XCTAssertFalse(NSPointInRect(mouse, view.visibleRect), "the mouse should be nowhere near")

        view.updateTrackingAreas()
        let areas = try trackingAreas(view)

        let commandEnd = kSkeinItemImageCommandLeftBorder + IFSkeinItemView.commandSize(layoutItem).width
        let menuRect = NSRect(x: commandEnd + drawMenuOffsetX + menuMouseOverOffsetX,
                              y: view.frame.height - menuVisibleHeight + menuMouseOverOffsetY,
                              width: menuVisibleWidth - menuMouseOverOffsetX,
                              height: menuVisibleHeight - menuMouseOverOffsetY)
        XCTAssertEqual(areas.menu.rect, NSIntersectionRect(menuRect, view.visibleRect))
        XCTAssertEqual(areas.lozenge.rect,
                       NSIntersectionRect(NSUnionRect(layoutItem.localSpaceLozengeRect, menuRect), view.visibleRect))
        for area in [areas.menu, areas.lozenge] {
            XCTAssertEqual(area.options, [.mouseEnteredAndExited, .activeInKeyWindow])
            XCTAssertIdentical(area.owner as AnyObject?, view)
        }

        // Updating them replaces them
        view.updateTrackingAreas()
        let newAreas = try trackingAreas(view)
        XCTAssertFalse(view.trackingAreas.contains { $0 === areas.menu || $0 === areas.lozenge })
        XCTAssertEqual(newAreas.lozenge.rect, areas.lozenge.rect)
    }

    /// Updating the tracking areas takes the mouse out of the old ones
    func testUpdatingTheTrackingAreasLeavesTheOldOnes() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let plain = try bitmap(view)
        try enter(view, menu: true)
        XCTAssertNotNil(try differences(plain, try bitmap(view), in: view))

        view.updateTrackingAreas()
        XCTAssertNil(try differences(plain, try bitmap(view), in: view))
        XCTAssertIdentical(NSCursor.current, NSCursor.openHand)
    }

    /// Over a knot's lozenge or its menu, the cursor is a pointing hand; elsewhere, an open hand to drag the skein
    func testTheCursor() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)

        try enter(view)
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)
        try enter(view, menu: true)
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)
        try exit(view, menu: true)
        XCTAssertIdentical(NSCursor.current, NSCursor.openHand)
    }

    /// A "test me" knot can't be clicked on the selected line, so the cursor there is an open hand
    func testATestMeKnotOnTheSelectedLineCantBeClicked() throws {
        let (_, north, _) = makeSkein()
        north.isTestSubItem = true
        layOut()
        let view = try knot(north)

        try enter(view)
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand, "off the selected line")
        try exit(view)

        skeinView.select(north, withAnimation: false)
        try enter(view)
        XCTAssertIdentical(NSCursor.current, NSCursor.openHand, "on the selected line")
    }

    // MARK: - Clicking

    /// Clicking a knot off the selected line selects it; clicking one on the selected line clears the selection
    func testClickingAKnot() throws {
        let (look, north, wait) = makeSkein()
        skeinView.select(north, withAnimation: false)

        let waitView = try knot(wait)
        try enter(waitView)
        try click(waitView)
        XCTAssertIdentical(skeinView.selectedItem, wait)

        try enter(waitView)
        try click(waitView)
        XCTAssertNil(skeinView.selectedItem)

        skeinView.select(north, withAnimation: false)
        let lookView = try knot(look)
        try enter(lookView)
        try click(lookView)
        XCTAssertNil(skeinView.selectedItem, "look is on the selected line, though not at its end")
    }

    /// A click away from the lozenge leaves the selection alone
    func testClickingAwayFromTheLozenge() throws {
        let (_, north, wait) = makeSkein()
        skeinView.select(north, withAnimation: false)
        try click(try knot(wait))
        XCTAssertIdentical(skeinView.selectedItem, north)
    }

    /// A knot's context menu is the skein view's
    func testTheContextMenu() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let lozenge = try XCTUnwrap(view.layoutItem).localSpaceLozengeRect
        let event = try mouseEvent(.rightMouseDown, at: NSPoint(x: lozenge.midX, y: lozenge.midY), in: view)
        let menu = try XCTUnwrap(view.menu(for: event))
        XCTAssertEqual(menu.items.map(\.title), skeinView.menu(for: look).items.map(\.title))
        XCTAssertFalse(menu.items.isEmpty)
    }

    // MARK: - Dragging from a knot

    /// Without a drag of its own begun, a knot lets its knot be copied within the app, and nothing outside it
    func testWhatADraggedKnotAllows() throws {
        let (look, _, _) = makeSkein()
        let view = try knot(look)
        let session = NSDraggingSession()
        XCTAssertEqual(view.draggingSession(session, sourceOperationMaskFor: .withinApplication), .copy)
        XCTAssertEqual(view.draggingSession(session, sourceOperationMaskFor: .outsideApplication), [])
    }

    /// At the end of a drag the skein forgets the dragged knot, and is laid out again if a drop asked for that
    func testTheEndOfADrag() throws {
        let (look, north, _) = makeSkein()
        let view = try knot(north)
        let session = NSDraggingSession()

        skein.draggingItem = north
        skein.draggingSourceNeedsUpdating = true
        XCTAssertEqual(changes(of: skein) { view.draggingSession(session, endedAt: .zero, operation: .move) }, 1)
        XCTAssertNil(skein.draggingItem)
        XCTAssertFalse(skein.draggingSourceNeedsUpdating)
        XCTAssertIdentical(north.parent, look, "only a drag the knot began can move it")

        skein.draggingItem = north
        XCTAssertEqual(changes(of: skein) { view.draggingSession(session, endedAt: .zero, operation: .copy) }, 0)
        XCTAssertNil(skein.draggingItem)
    }

    // MARK: - Dropping onto a knot

    /// Within a skein, a knot can be moved or copied onto another, but not onto itself, its parent or a knot below it
    func testWhereAKnotCanBeDropped() throws {
        let (look, north, wait) = makeSkein()
        let source = try knot(look)
        skein.draggingItem = look
        let destination = try knot(wait)

        XCTAssertEqual(destination.draggingEntered(try drag(source, to: wait)), .move)
        XCTAssertIdentical(NSCursor.current, NSCursor.pointingHand)
        XCTAssertEqual(destination.draggingUpdated(try drag(source, to: wait, mask: .copy)), .copy)
        XCTAssertIdentical(NSCursor.current, NSCursor.dragCopy)

        for item in [look, north, skein.rootItem] {
            XCTAssertEqual(destination.draggingUpdated(try drag(source, to: item)), [], item.command)
            XCTAssertIdentical(NSCursor.current, NSCursor.operationNotAllowed)
        }
        XCTAssertEqual(destination.draggingUpdated(try drag(source, point: NSPoint(x: 1, y: 1))), [], "nowhere")
    }

    /// A knot can't be dropped onto a "test me" knot whose commands follow it
    func testAKnotCantBeDroppedOntoATestMeKnot() throws {
        let (look, north, wait) = makeSkein()
        look.isTestSubItem = true
        north.isTestSubItem = true
        layOut()
        let source = try knot(wait)
        skein.draggingItem = wait

        XCTAssertEqual(try knot(look).draggingEntered(try drag(source, to: look)), [])
        XCTAssertEqual(try knot(look).draggingEntered(try drag(source, to: north)), .move, "the last command")
    }

    /// From another skein, or from elsewhere, a knot can be dropped onto any knot
    func testDroppingAKnotFromElsewhere() throws {
        let (look, _, _) = makeSkein()
        let otherSkein: IFSkein = IFSkein(project: nil)
        let other: IFSkeinItem = otherSkein.rootItem.addChild(IFSkeinItem(skein: otherSkein, command: "jump"))
        let otherView = IFSkeinView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView?.addSubview(otherView)
        otherView.skein = otherSkein
        otherSkein.draggingItem = other
        let source = try knot(other, in: otherView)
        let destination = try knot(look)

        XCTAssertEqual(destination.draggingEntered(try drag(source, to: skein.rootItem)), .move)
        XCTAssertEqual(destination.draggingEntered(try drag(nil, to: skein.rootItem)), .move)
    }

    /// A knot dropped within its skein is added below the knot dropped on, and the skein is laid out at the end of the
    /// drag; from another skein, it's laid out at once
    func testDroppingAKnot() throws {
        let (look, north, wait) = makeSkein()
        let source = try knot(north)
        skein.draggingItem = north
        let destination = try knot(wait)
        try putOnPasteboard(north)

        let info = try drag(source, to: wait)
        XCTAssertTrue(destination.prepareForDragOperation(info))
        XCTAssertEqual(changes(of: skein) { XCTAssertTrue(destination.performDragOperation(info)) }, 0)
        XCTAssertEqual(wait.children.map(\.command), ["north"])
        XCTAssertTrue(skein.draggingSourceNeedsUpdating)
        XCTAssertIdentical(north.parent, look, "the source isn't touched")

        // (Not onto look, as a knot added below one with the same command is merged with it)
        skein.draggingSourceNeedsUpdating = false
        let fromElsewhere = try drag(nil, to: skein.rootItem)
        XCTAssertEqual(changes(of: skein) { XCTAssertTrue(destination.performDragOperation(fromElsewhere)) }, 1)
        XCTAssertEqual(skein.rootItem.children.map(\.command), ["look", "north", "wait"])
        XCTAssertFalse(skein.draggingSourceNeedsUpdating)
    }

    /// Nothing is dropped where there's no knot, or with no knot on the pasteboard
    func testDroppingNothing() throws {
        let (look, north, wait) = makeSkein()
        let source = try knot(north)
        let destination = try knot(wait)

        pasteboard.clearContents()
        XCTAssertFalse(destination.performDragOperation(try drag(source, to: wait)))

        let type = NSPasteboard.PasteboardType(IFSkeinItemPboardType)
        pasteboard.setData(Data("not a knot".utf8), forType: type)
        XCTAssertFalse(destination.performDragOperation(try drag(source, to: wait)))

        try putOnPasteboard(north)
        XCTAssertFalse(destination.performDragOperation(try drag(source, point: NSPoint(x: 1, y: 1))))
        XCTAssertEqual(wait.children.count, 0)
        XCTAssertEqual(look.children.count, 1)
    }
}
