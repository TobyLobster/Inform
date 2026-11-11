//
//  IFSkeinItemView.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import AppKit

/// Visible size of the menu image
private let kMenuVisibleWidth: CGFloat        = 21.0
/// Visible size of the menu image
private let kMenuVisibleHeight: CGFloat       = 21.0
/// Offset from end of command to draw menu image
private let kDrawMenuOffsetX: CGFloat         = -3.0

private let kMenuMouseOverOffsetX: CGFloat    = 6.0
private let kMenuMouseOverOffsetY: CGFloat    = 4.0

// Images. Loaded when first used, as the Objective-C's +initialize loaded them when the class was first used.
/// Active item
private let active          = NSImage(named: "App/Skein/Skein-active")
/// Selected item
private let selected        = NSImage(named: "App/Skein/Skein-selected")
/// Unselected item
private let unselected      = NSImage(named: "App/Skein/Skein-unselected")
/// Output differs from blessed transcript
private let differsBadge    = NSImage(named: "App/Skein/SkeinDiffersBadge")
/// Winning item
private let starBadge       = NSImage(named: "App/Skein/SkeinStarBadge")
/// Active item
private let activeMenu      = NSImage(named: "App/Skein/Skein-active-menu")
/// Selected item
private let selectedMenu    = NSImage(named: "App/Skein/Skein-selected-menu")
/// Unselected item
private let unselectedMenu  = NSImage(named: "App/Skein/Skein-unselected-menu")
/// highlight when mouse over
private let overMenu        = NSImage(named: "App/Skein/Skein-over-menu")

// The text's attributes. Made when first used, as the Objective-C's +initialize made them when the class was first
// used, at the skein's font size then; adjustAttributesToFontSize changes them to the size now.
private let testMeTextColor = NSColor(calibratedRed: 0.8,
                                      green: 0.8,
                                      blue: 0.8,
                                      alpha: 1.0)

// Standard attributes
@MainActor private var itemTextActiveAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]
@MainActor private var itemTextSelectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]
@MainActor private var itemTextUnselectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]

// "Test me" attributes
@MainActor private var itemTestMeTextActiveAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .obliqueness:     0.2,
    .foregroundColor: testMeTextColor ]
@MainActor private var itemTestMeTextSelectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .obliqueness:     0.2,
    .foregroundColor: testMeTextColor ]
@MainActor private var itemTestMeTextUnselectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.systemFont(ofSize: IFSkeinView.fontSize),
    .obliqueness:     0.2,
    .foregroundColor: testMeTextColor ]

// Root attributes
@MainActor private var itemTextRootActiveAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.boldSystemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]
@MainActor private var itemTextRootSelectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.boldSystemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]
@MainActor private var itemTextRootUnselectedAttributes: [NSAttributedString.Key: Any] = [
    .font:            NSFont.boldSystemFont(ofSize: IFSkeinView.fontSize),
    .foregroundColor: NSColor.white ]

@objc @implementation extension IFSkeinItemView {
    private final var menuTrackingArea: NSTrackingArea?
    private final var lozengeTrackingArea: NSTrackingArea?
    private final var insideMenuArea = false
    private final var insideLozengeArea = false

    // Dragging
    private final var dragCanMove = false
    private final var mouseDownLocation = NSPoint.zero

    private final var _drawnStateHash: UInt = 0

    var layoutItem: IFSkeinLayoutItem?
    var drawnStateHash: UInt { return _drawnStateHash }

    // MARK: - Initialisation

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([NSPasteboard.PasteboardType(IFSkeinItemPboardType)])
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the view up either.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    class func adjustAttributesToFontSize() {
        let size = IFSkeinView.fontSize

        itemTextRootUnselectedAttributes    = IFUtility.adjustAttributesFontSize(itemTextRootUnselectedAttributes,   size: size)
        itemTextRootSelectedAttributes      = IFUtility.adjustAttributesFontSize(itemTextRootSelectedAttributes,     size: size)
        itemTextRootActiveAttributes        = IFUtility.adjustAttributesFontSize(itemTextRootActiveAttributes,       size: size)
        itemTextUnselectedAttributes        = IFUtility.adjustAttributesFontSize(itemTextUnselectedAttributes,       size: size)
        itemTextSelectedAttributes          = IFUtility.adjustAttributesFontSize(itemTextSelectedAttributes,         size: size)
        itemTextActiveAttributes            = IFUtility.adjustAttributesFontSize(itemTextActiveAttributes,           size: size)
        itemTestMeTextUnselectedAttributes  = IFUtility.adjustAttributesFontSize(itemTestMeTextUnselectedAttributes, size: size)
        itemTestMeTextSelectedAttributes    = IFUtility.adjustAttributesFontSize(itemTestMeTextSelectedAttributes,   size: size)
        itemTestMeTextActiveAttributes      = IFUtility.adjustAttributesFontSize(itemTestMeTextActiveAttributes,     size: size)
    }

    private static func attributesForLayoutItem(_ layoutItem: IFSkeinLayoutItem) -> [NSAttributedString.Key: Any] {
        var index = 0

        // Unselected, selected, active
        if layoutItem.recentlyPlayed {
            index = 2
        } else if layoutItem.onSelectedLine {
            index = 1
        }

        // Root, Standard, Test Me
        if layoutItem.item.isTestSubItem {
            index += 6
        }
        else if layoutItem.item.parent != nil {
            index += 3
        }

        return [itemTextRootUnselectedAttributes,   itemTextRootSelectedAttributes,   itemTextRootActiveAttributes,
                itemTextUnselectedAttributes,       itemTextSelectedAttributes,       itemTextActiveAttributes,
                itemTestMeTextUnselectedAttributes, itemTestMeTextSelectedAttributes, itemTestMeTextActiveAttributes
               ][index]
    }

    private static func backgroundForLayoutItem(_ layoutItem: IFSkeinLayoutItem) -> NSImage? {
        if layoutItem.recentlyPlayed {
            return active
        }
        if layoutItem.onSelectedLine {
            return selected
        }
        return unselected
    }

    private static func backgroundMenuForLayoutItem(_ layoutItem: IFSkeinLayoutItem) -> NSImage? {
        if layoutItem.recentlyPlayed {
            return activeMenu
        }
        if layoutItem.onSelectedLine {
            return selectedMenu
        }
        return unselectedMenu
    }

    class func commandSize(_ layoutItem: IFSkeinLayoutItem) -> NSSize {
        if layoutItem.item.commandSizeDidChange {
            let attributes = (layoutItem.item.parent == nil) ? itemTextRootActiveAttributes : itemTextActiveAttributes
            layoutItem.item.cachedCommandSize = (layoutItem.item.command as NSString).size(withAttributes: attributes)
            layoutItem.item.commandSizeDidChange = false
        }
        return layoutItem.item.cachedCommandSize
    }

    private static func drawLozengeImage(_ img: NSImage?,
                                         atPoint pos: NSPoint,
                                         withWidth width: CGFloat) {
        var pos = pos
        var width = width
        pos.x = floor(pos.x)
        pos.y = floor(pos.y)
        width = floor(width)

        if width <= 0.0 { width = 1.0 }

        // Using image slicing makes this so much easier.
        var drawRect = NSRect(origin: pos, size: NSSize(width: width, height: kSkeinItemImageHeight))
        // TODO: Test this!
        drawRect.size.width += kSkeinItemImageCommandLeftBorder + kSkeinItemImageCommandRightBorder
        img?.draw(in: drawRect,
                  from: NSZeroRect,
                  operation: .sourceOver,
                  fraction: 1.0,
                  respectFlipped: true,
                  hints: nil)
    }

    public override func draw(_ dirtyRect: NSRect) {
        // Nothing to draw until the view has its layout item
        guard let layoutItem else {
            return
        }

        NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).set()

        // Draw the background
        let background  = IFSkeinItemView.backgroundForLayoutItem(layoutItem)
        let commandSize = IFSkeinItemView.commandSize(layoutItem)
        let commandX = kSkeinItemImageCommandLeftBorder

        let imageHeight = background?.size.height ?? 0
        let commandY = floor((imageHeight - commandSize.height) / 2.0 + 1.0)

        // Draw the lozenge
        IFSkeinItemView.drawLozengeImage(background,
                                         atPoint: NSPoint(x: 0, y: 0),
                                         withWidth: commandSize.width)

        // Draw star if we are the winning item
        if skeinView?.skein?.isTheWinning(layoutItem.item) ?? false {
            let height = Float((starBadge?.size.height ?? 0) / 2)
            let width = Float((starBadge?.size.width ?? 0) / 2)
            starBadge?.draw(in: NSRect(x: 0.0, y: 0.0,
                                       width: CGFloat(width), height: CGFloat(height)),
                            from: NSZeroRect,
                            operation: .sourceOver,
                            fraction: 1.0)
        }

        // Draw the menu if necessary
        if insideLozengeArea || insideMenuArea {
            if skeinView?.hasMenu(layoutItem.item) ?? false {
                let backgroundMenu = IFSkeinItemView.backgroundMenuForLayoutItem(layoutItem)
                let drawPoint = NSPoint(x: floor(commandX + commandSize.width + kDrawMenuOffsetX),
                                        y: floor(frame.size.height) - (backgroundMenu?.size.height ?? 0))
                backgroundMenu?.draw(at: drawPoint,
                                     from: NSZeroRect,
                                     operation: .sourceOver,
                                     fraction: 1.0)
                if insideMenuArea {
                    overMenu?.draw(at: drawPoint,
                                   from: NSZeroRect,
                                   operation: .sourceOver,
                                   fraction: 1.0)
                }
            }
        }

        // Draw the text
        let sizedTextAttributes = IFSkeinItemView.attributesForLayoutItem(layoutItem)

        (layoutItem.item.command as NSString).draw(at: NSPoint(x: floor(commandX), y: floor(commandY)),
                                                   withAttributes: sizedTextAttributes)

        // Draw the badge if necessary
        if layoutItem.item.hasBadge {
            differsBadge?.draw(at: NSPoint(x: 0.0,
                                           y: floor(frame.size.height) - (differsBadge?.size.height ?? 0)),
                               from: NSZeroRect,
                               operation: .sourceOver,
                               fraction: 1.0)
        }
        _drawnStateHash = layoutItem.drawStateHash
    }

    private final var skeinView: IFSkeinView? {
        return superview as? IFSkeinView
    }

    private final var skein: IFSkein? {
        return skeinView?.skein
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        // Context menu is handled by the parent view
        return superview?.menu(for: event)
    }

    private final func imageForDragging() -> NSImage {
        var imgRect = NSRect.zero

        imgRect.origin = NSPoint(x: 0, y: 0)
        imgRect.size = frame.size

        let img = NSImage(size: imgRect.size)

        // Turn off insideLozengeArea, remembering what it was before
        let oldInsideLozengeArea = insideLozengeArea
        insideLozengeArea = false

        // Draw image
        img.lockFocus()
        NSColor.clear.set()
        imgRect.fill()
        draw(imgRect)
        img.unlockFocus()

        // Restore insideLozengeArea back to what it was
        insideLozengeArea = oldInsideLozengeArea

        return img
    }

    private final func canClickItem() -> Bool {
        if !(layoutItem?.item.isTestSubItem ?? false) { return true }
        if !(layoutItem?.onSelectedLine ?? false) { return true }

        return false
    }

    private final func updateCurrentCursor() {
        // (The mouse is only ever inside a view with a layout item, as one without has no tracking areas)
        if insideMenuArea, let layoutItem, skeinView?.hasMenu(layoutItem.item) ?? false {
            NSCursor.pointingHand.set()
        } else if insideLozengeArea && canClickItem() {
            NSCursor.pointingHand.set()
        }
        else {
            NSCursor.openHand.set()
        }
    }

    @objc private final func mouseEnteredMenuArea() {
        insideMenuArea = true
        updateCurrentCursor()
        needsDisplay = true
    }

    private final func mouseExitedMenuArea() {
        insideMenuArea = false
        updateCurrentCursor()
        needsDisplay = true
    }

    @objc private final func mouseEnteredLozengeArea() {
        insideLozengeArea = true
        updateCurrentCursor()
        needsDisplay = true
    }

    private final func mouseExitedLozengeArea() {
        insideLozengeArea = false
        updateCurrentCursor()
        needsDisplay = true
    }

    private final func addTrackingAreaWithRect(_ areaRect: NSRect,
                                               mousePos currentMousePos: NSPoint,
                                               insideSelector: Selector) -> NSTrackingArea? {
        let visibleRect = self.visibleRect
        let areaRect = NSIntersectionRect(areaRect, visibleRect)

        if !NSIsEmptyRect(areaRect) {
            // Do we start inside the rectangle?
            var options: NSTrackingArea.Options = []
            if NSPointInRect(currentMousePos, areaRect) {
                IFUtility.perform(insideSelector, object: self)

                options = .assumeInside
            }

            let trackingArea = NSTrackingArea(rect: areaRect,
                                              options: [.mouseEnteredAndExited,
                                                        .activeInKeyWindow, options],
                                              owner: self,
                                              userInfo: nil)
            addTrackingArea(trackingArea)
            return trackingArea
        }
        return nil
    }

    public override func updateTrackingAreas() {
        // Remove any existing tracking areas (because they are no longer valid)
        if let menuTrackingArea {
            removeTrackingArea(menuTrackingArea)
            self.menuTrackingArea = nil
        }
        if let lozengeTrackingArea {
            removeTrackingArea(lozengeTrackingArea)
            self.lozengeTrackingArea = nil
        }

        // Exit the areas (because they are no longer valid)
        if insideMenuArea {
            mouseExitedMenuArea()
        }
        if insideLozengeArea {
            mouseExitedLozengeArea()
        }

        // Nothing to track until the view has its layout item
        guard let layoutItem else {
            super.updateTrackingAreas()
            return
        }

        // Get current mouse position
        var currentMousePos = window?.mouseLocationOutsideOfEventStream ?? .zero
        currentMousePos = convert(currentMousePos,
                                  from: nil)

        // Add tracking areas
        do {
            // Add the menu tracking area
            let commandX = kSkeinItemImageCommandLeftBorder
            let commandSize = IFSkeinItemView.commandSize(layoutItem)
            var menuAreaRect = NSRect(x: commandX + commandSize.width + kDrawMenuOffsetX,
                                      y: frame.size.height - kMenuVisibleHeight,
                                      width: kMenuVisibleWidth, height: kMenuVisibleHeight)

            // Adjust from the visible area to get the mouse over area
            menuAreaRect = NSRect(x: menuAreaRect.origin.x + kMenuMouseOverOffsetX,
                                  y: menuAreaRect.origin.y + kMenuMouseOverOffsetY,
                                  width: menuAreaRect.size.width  - kMenuMouseOverOffsetX,
                                  height: menuAreaRect.size.height - kMenuMouseOverOffsetY)

            menuTrackingArea = addTrackingAreaWithRect(menuAreaRect,
                                                       mousePos: currentMousePos,
                                                       insideSelector: #selector(mouseEnteredMenuArea))

            // Add the lozenge area
            let localLozengeRect = layoutItem.localSpaceLozengeRect

            // Combine the two rectangles into one unified rectangle
            let unifiedRect = NSUnionRect(localLozengeRect, menuAreaRect)

            lozengeTrackingArea = addTrackingAreaWithRect(unifiedRect,
                                                          mousePos: currentMousePos,
                                                          insideSelector: #selector(mouseEnteredLozengeArea))
        }

        super.updateTrackingAreas()
    }

    public override func mouseEntered(with event: NSEvent) {
        if event.trackingArea === menuTrackingArea {
            mouseEnteredMenuArea()
        }
        else if event.trackingArea === lozengeTrackingArea {
            mouseEnteredLozengeArea()
        }
    }

    public override func mouseExited(with event: NSEvent) {
        if event.trackingArea === menuTrackingArea {
            mouseExitedMenuArea()
        }
        else if event.trackingArea === lozengeTrackingArea {
            mouseExitedLozengeArea()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        // Remember where the click started, so that a small movement isn't taken for a drag
        mouseDownLocation = event.locationInWindow
        super.mouseDown(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        // (The mouse is only ever inside a view with a layout item, as one without has no tracking areas)
        if insideMenuArea, let layoutItem, let skeinView, skeinView.hasMenu(layoutItem.item) {
            let menu = skeinView.menu(for: layoutItem.item)
            NSMenu.popUpContextMenu(menu, with: event, for: skeinView)
            return
        } else if insideLozengeArea {
            if !(layoutItem?.onSelectedLine ?? false) {
                // Select an item not currently on the selected line
                skeinView?.select(layoutItem?.item, withAnimation: true)
            } else {
                // Clear the selection if clicking an item on the selected line
                skeinView?.select(nil, withAnimation: true)
            }
            return
        }
        super.mouseUp(with: event)
    }

    private final func canDragItem() -> Bool {
        if layoutItem?.item.parent == nil {
            return false
        }
        if layoutItem?.item.isTestSubItem ?? false {
            return false
        }

        return true
    }

    public override func mouseDragged(with event: NSEvent) {
        if !canDragItem() {
            super.mouseDragged(with: event)
            return
        }

        // Wait until the mouse has moved far enough, so that a click that moves slightly is still a click
        let location = event.locationInWindow
        if hypot(location.x - mouseDownLocation.x, location.y - mouseDownLocation.y) < kSkeinItemDragThreshold {
            return
        }

        // Drag this item. Default action is a move action, but a copy op is possible if command is held down.

        // Create an image of this item (canDragItem means there's a layout item)
        if skeinView != nil, let layoutItem {
            let itemImage = imageForDragging()

            skein?.draggingItem = layoutItem.item
            dragCanMove = !layoutItem.item.hasDescendant(skein?.activeItem)

            let dragItem = NSDraggingItem(pasteboardWriter: layoutItem.item)
            dragItem.setDraggingFrame(NSRect(origin: .zero, size: itemImage.size), contents: itemImage)

            _ = beginDraggingSession(with: [dragItem], event: event, source: self)
        }
    }

    // MARK: - NSDraggingSource protocol

    @objc(draggingSession:sourceOperationMaskForDraggingContext:)
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .withinApplication {
            if dragCanMove {
                return [.copy, .move]
            } else {
                return .copy
            }
        } else {
            return []
        }
    }

    @objc(draggingSession:endedAtPoint:operation:)
    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        if operation.contains(.move) && skein?.draggingItem != nil && dragCanMove {

            // Keep selected item valid...
            if skein?.draggingItem?.hasDescendant(skeinView?.selectedItem) ?? false {
                skeinView?.selectedItem = skein?.draggingItem?.parent
            }

            // Finish the move operation by removing the source items
            skein?.draggingItem?.removeFromParent()
            skein?.draggingSourceNeedsUpdating = true
        }

        if skein?.draggingSourceNeedsUpdating ?? false {
            skein?.postChanged(withAnimate: true,
                               keepActiveVisible: false)
            skein?.draggingSourceNeedsUpdating = false
        }
        skein?.draggingItem = nil
    }

    // MARK: - NSDraggingDestination protocol

    private final func isDragToSameSkein(_ sender: NSDraggingInfo) -> Bool {
        var draggingIntoSameSkein = false
        let source = sender.draggingSource
        if let source = source as? IFSkeinItemView {
            let sourceSkeinView         = source.superview as? IFSkeinView
            let destinationSkeinView    = skeinView
            draggingIntoSameSkein = (sourceSkeinView?.skein === destinationSkeinView?.skein)
        }
        return draggingIntoSameSkein
    }

    private final func canDropOntoItem(_ destinationItem: IFSkeinItem?,
                                       sender: NSDraggingInfo) -> Bool {
        guard let destinationItem else {
            return false
        }

        // If dropping onto to the source skein, check we are not dropping in a bad place
        if isDragToSameSkein(sender) {
            if destinationItem === skein?.draggingItem?.parent {
                return false
            }

            if skein?.draggingItem?.hasDescendant(destinationItem) ?? false {
                return false
            }
        }

        if destinationItem.children.count > 0 {
            let firstChild = destinationItem.children[0]
            if firstChild.isTestSubItem {
                return false
            }
        }
        return true
    }

    private final func updateDragCursor(_ sender: NSDraggingInfo) -> NSDragOperation {
        let dragPoint = skeinView?.convert(sender.draggingLocation,
                                           from: nil) ?? .zero

        let destinationItem = skeinView?.item(at: dragPoint)

        if !canDropOntoItem(destinationItem,
                            sender: sender) {
            NSCursor.operationNotAllowed.set()

            return []
        }

        let isMoveOperation = sender.draggingSourceOperationMask.contains(.move)
        let isDraggingToChild = skein?.draggingItem?.hasDescendant(destinationItem) ?? false
        if isMoveOperation && !isDraggingToChild {
            NSCursor.pointingHand.set()

            return .move
        }

        NSCursor.dragCopy.set()
        return .copy
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return updateDragCursor(sender)
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return updateDragCursor(sender)
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let dragPoint = skeinView?.convert(sender.draggingLocation,
                                           from: nil) ?? .zero
        guard let destinationItem = skeinView?.item(at: dragPoint) else { return false }

        // Decode the IFSkeinItemPboardType data for this operation
        let pboard = sender.draggingPasteboard
        guard let data = pboard.data(forType: NSPasteboard.PasteboardType(IFSkeinItemPboardType)) else { return false }

        guard let newItem = try? NSKeyedUnarchiver.unarchivedObject(ofClass: IFSkeinItem.self,
                                                                    from: data) else { return false }

        // Add this as a child of the old item
        _ = destinationItem.addChild(newItem)

        // If source and destination of the drag are in different skeins, update the destination skein
        // otherwise we leave the update for the source drag protocol to update the skein, since it may
        // first delete some source items to complete a move operation.
        if isDragToSameSkein(sender) {
            skein?.draggingSourceNeedsUpdating = true
        }
        else {
            skein?.postChanged(withAnimate: true,
                               keepActiveVisible: false)
        }

        return true
    }

    public override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Nothing to do
    }
}
