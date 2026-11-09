//
//  IFPageBarView.swift
//  Inform
//
//  Created by Andrew Hunter on 01/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa

///
/// Object used to represent the layout of an individual cell
///
private final class IFPageCellLayout {
    /// Offset from the left/right for this cell
    var position: CGFloat = 0
    /// Minimum size that this cell can be
    var minWidth: CGFloat = 0
    /// Actual size that this cell should be drawn at
    var width: CGFloat = 0
    /// If `true` then this cell shouldn't be drawn
    var hidden = false
}

// MARK: - Constants

/// Margin to put on the right (to account for scrollbars, tabs, etc)
private let rightMargin: CGFloat = 14.0
/// Extra margin to put on the right when drawing the 'bar' image as opposed to the background
private let tabMargin: CGFloat = 0.0
/// Margin on the left and right until we actually draw the first cell
private let leftMargin: CGFloat = 3.0

@objc @implementation extension IFPageBarView {
    /// `true` if this page accepts keyboard input
    private final var isActive = false

    /// The cells that appear on the left of this view
    private final var leftCells: [NSCell] = []
    /// The cells that appear on the right of this view
    private final var rightCells: [NSCell] = []

    /// Left-hand cell layout
    private final var leftLayout: [IFPageCellLayout] = []
    /// Right-hand cell layout
    private final var rightLayout: [IFPageCellLayout] = []

    /// The cell that the mouse is down over
    private final weak var trackingCell: NSCell?
    /// The bounds for the cell that the mouse is down over
    private final var trackingCellFrame = NSRect.zero

    // MARK: - Drawing

    @objc(drawOverlay:inRect:totalBounds:)
    class func drawOverlay(_ overlay: NSColor,
                           in rect: NSRect,
                           totalBounds bounds: NSRect) {
        // Draws an overlay colour, given the bounds of this control and the area to draw
        let rect = NSIntersectionRect(rect, bounds)

        if rect.size.width > 0 {
            let destRect = NSRect(x: rect.origin.x, y: bounds.origin.y, width: rect.size.width, height: bounds.size.height)
            overlay.set()
            destRect.fill(using: .sourceOver)
            NSColor.controlAccentColor.set()
            destRect.fill(using: .overlay)
        }
    }

    private final func renderCell(_ cell: NSCell,
                                  for layout: IFPageCellLayout,
                                  isRight right: Bool,
                                  isFirst: Bool) -> NSImage {
        // Render the specified cell using the specified layout
        var bounds = self.bounds

        bounds.origin.x += leftMargin
        bounds.size.width -= leftMargin + tabMargin + rightMargin

        // Set this cell to be owned by this view
        if cell.controlView !== self {
            // Note that this makes it hard to move a cell from the left to the right
            if cell.responds(to: #selector(NSCell.setIsRight(_:))) {
                cell.setIsRight(right)
            }
        }

        // Construct the image that will contain this cell
        let cellImage = NSImage(size: NSSize(width: layout.width, height: bounds.size.height))

        var cellFrame = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: layout.width, height: bounds.size.height)
        if right {
            cellFrame.origin.x += bounds.size.width - layout.position - layout.width
        } else {
            cellFrame.origin.x += layout.position
        }

        // Prepare to draw the cell
        cellImage.lockFocus()

        let cellTransform = NSAffineTransform()
        cellTransform.translateX(by: -cellFrame.origin.x,
                                 yBy: -cellFrame.origin.y)
        cellTransform.concat()

        // Draw the cell
        cell.draw(withFrame: cellFrame,
                  in: self)

        // Draw the borders
        let marginLeftPos  = NSMinX(cellFrame) + 0.5
        let marginRightPos = NSMaxX(cellFrame) - 0.5

        NSColor.separatorColor.set()

        if right || isFirst {
            NSBezierPath.strokeLine(from: NSPoint(x: marginLeftPos, y: NSMinY(cellFrame) + 1.5),
                                    to: NSPoint(x: marginLeftPos, y: NSMaxY(cellFrame)))
        }

        if !right || isFirst {
            NSBezierPath.strokeLine(from: NSPoint(x: marginRightPos, y: NSMinY(cellFrame) + 1.5),
                                    to: NSPoint(x: marginRightPos, y: NSMaxY(cellFrame)))
        }

        // Finish drawing
        cellImage.unlockFocus()

        // Return the result
        return cellImage
    }

    private final func drawCells(from cellList: [NSCell],
                                 layout layoutList: [IFPageCellLayout],
                                 isOnRight right: Bool) {
        // Draw a set of suitably laid-out cells, either on the right or on the left
        var bounds = self.bounds

        bounds.origin.x += leftMargin
        bounds.size.width -= leftMargin + tabMargin + rightMargin

        var isFirst = true
        for (cell, layout) in zip(cellList, layoutList) {
            if layout.hidden { continue }

            // Draw the cell's image
            let cellImage = renderCell(cell,
                                       for: layout,
                                       isRight: right,
                                       isFirst: isFirst)

            // Draw the cell itself
            var cellFrame = NSRect(x: 0, y: 0, width: layout.width, height: bounds.size.height)
            var cellSource = cellFrame
            if right {
                cellFrame.origin.x = bounds.size.width - layout.position - layout.width
            } else {
                cellFrame.origin.x = layout.position
            }
            cellFrame.origin.x += bounds.origin.x

            cellFrame.size.height -= 2; cellFrame.origin.y += 2
            cellSource.size.height -= 2; cellSource.origin.y += 2

            cellImage.draw(in: NSIntegralRect(cellFrame),
                           from: cellSource,
                           operation: .sourceOver,
                           fraction: (cell.isEnabled ? 1.0 : 0.5) * (isActive ? 1.0 : 0.85))
            isFirst = false
        }
    }

    public override func draw(_ rect: NSRect) {
        // Update the cell positioning information
        layoutCells()

        // Draw the left-hand cells
        drawCells(from: leftCells,
                  layout: leftLayout,
                  isOnRight: false)

        // Draw the right-hand cells
        drawCells(from: rightCells,
                  layout: rightLayout,
                  isOnRight: true)

        // Draw single pixel horizontal line separating from main content
        let fullRect = self.bounds
        NSColor.separatorColor.set()
        NSBezierPath.strokeLine(from: NSPoint(x: 3.0, y: 0.5),
                                to: NSPoint(x: fullRect.size.width - 14.0, y: 0.5))
    }

    // MARK: - Managing cells

    func setLeftCells(_ newLeftCells: [NSCell]?) {
        leftCells = newLeftCells ?? []

        leftLayout = []

        needsDisplay = true
    }

    func setRightCells(_ newRightCells: [NSCell]?) {
        rightCells = newRightCells ?? []

        rightLayout = []

        needsDisplay = true
    }

    private final func addCells(_ cells: [NSCell],
                                to layout: inout [IFPageCellLayout]) {
        var position: CGFloat = 0
        for cell in cells {
            let cellLayout = IFPageCellLayout()

            cellLayout.position = position
            cellLayout.minWidth = cell.cellSize.width
            cellLayout.hidden = false

            if position == 0 && cell.image != nil {
                // Prevent images from looking a bit lopsided when right on the edge
                cellLayout.position -= 2
                position -= 2
            }

            cellLayout.width = cellLayout.minWidth

            layout.append(cellLayout)
            position += cellLayout.width
        }
    }

    func layoutCells() {
        leftLayout = []
        rightLayout = []

        // First pass: add all cells to the left and right regardless of how wide they are
        addCells(leftCells,
                 to: &leftLayout)
        addCells(rightCells,
                 to: &rightLayout)

        // Second pass: reduce the width of any cell that can be shrunk
        //
        // TODO: But less important than:

        // Third pass: remove cells from the right, then from the left when there is
        // still not enough space
        var bounds = self.bounds

        bounds.origin.x += leftMargin
        bounds.size.width -= leftMargin + tabMargin + rightMargin

        var maxLeftPos: CGFloat = 0
        if leftCells.count > 0, let lastLeftLayout = leftLayout.last {
            maxLeftPos = lastLeftLayout.position + lastLeftLayout.width
        }
        maxLeftPos += NSMinX(bounds)

        for cellLayout in rightLayout {
            if NSMaxX(bounds) - (cellLayout.position + cellLayout.width) <= maxLeftPos + 4 {
                cellLayout.hidden = true
            } else {
                cellLayout.hidden = false
            }
        }

        for cellLayout in leftLayout {
            if NSMinX(bounds) + (cellLayout.position + cellLayout.width) >= NSMaxX(bounds) - 12 {
                cellLayout.hidden = true
            } else {
                cellLayout.hidden = false
            }
        }
    }

    @objc(setState:forCell:)
    func setState(_ state: Int32,
                  for cell: IFPageBarCell) {
        // Set the cell state (the boring bit)
        cell.state = NSControl.StateValue(rawValue: Int(state))

        // Get the radio group, and do nothing if this isn't a radio cell
        let group = cell.radioGroup
        if group < 0 {
            return
        }

        // If we're not turning a cell on, then we don't need to do anything more
        if Int(state) != NSControl.StateValue.on.rawValue {
            return
        }

        // Turn off any cells in the same group in the left or right groups

        for otherCell in leftCells {
            // Do nothing if this is the cell whose state is being set
            if otherCell === cell { continue }

            // Do nothing if this cell is already turned off
            if otherCell.state == .off { continue }

            // Get the group for this cell
            var otherGroup: Int32 = -1
            if let otherCell = otherCell as? IFPageBarCell { otherGroup = otherCell.radioGroup }

            // If it's the same as the cell we're updating, then turn this cell off
            if otherGroup == group { otherCell.state = .off }
        }

        for otherCell in rightCells {
            // Do nothing if this is the cell whose state is being set
            if otherCell === cell { continue }

            // Do nothing if this cell is already turned off
            if otherCell.state == .off { continue }

            // Get the group for this cell
            var otherGroup: Int32 = -1
            if let otherCell = otherCell as? IFPageBarCell { otherGroup = otherCell.radioGroup }

            // If it's the same as the cell we're updating, then turn this cell off
            if otherGroup == group { otherCell.state = .off }
        }
    }

    // MARK: - Cell housekeeping

    private final func indexOfCell(at point: NSPoint) -> Int {
        // Returns 0 if no cell, a negative number for a right-hand cell or a positive number for a
        // left-hand cell
        var point = point

        // Update the cell layout
        layoutCells()

        // Work out the bounds for the cells
        var bounds = self.bounds

        bounds.origin.x += leftMargin
        bounds.size.width -= leftMargin + tabMargin + rightMargin

        // Not this cell if the rectangle is outside the bounds of this control
        if point.y < NSMinY(bounds) || point.y > NSMaxY(bounds) {
            return 0
        }

        if point.x < NSMinX(bounds) - 4 || point.x > NSMaxX(bounds) + 4 {
            return 0
        }

        point.x -= NSMinX(bounds)

        // Search the left-hand cells
        for (index, (_, layout)) in zip(leftCells, leftLayout).enumerated() {
            // Ignore hidden cells
            if layout.hidden { continue }

            // Test for a hit on this cell
            if (index == 0 || point.x >= layout.position) && layout.position + layout.width >= point.x {
                return index + 1
            }
        }

        // Search the right-hand cells
        for (index, (_, layout)) in zip(rightCells, rightLayout).enumerated() {
            // Ignore hidden cells
            if layout.hidden { continue }

            // Test for a hit on this cell
            if point.x >= bounds.size.width - layout.position - layout.width
                && (index == 0 || bounds.size.width - layout.position >= point.x) {
                return -(index + 1)
            }
        }

        return 0
    }

    private final func boundsForCell(at index: Int,
                                     isOnRight isRight: Bool) -> NSRect {
        // Update the cell layout
        layoutCells()
        var bounds = self.bounds

        bounds.origin.x += leftMargin
        bounds.size.width -= leftMargin + tabMargin + rightMargin

        let layout = (isRight ? rightLayout : leftLayout)[index]

        var cellFrame = NSRect(x: 0, y: 0, width: layout.width, height: bounds.size.height)
        if isRight {
            cellFrame.origin.x = bounds.size.width - layout.position - layout.width
        } else {
            cellFrame.origin.x = layout.position
        }
        cellFrame.origin.x += bounds.origin.x

        return cellFrame
    }

    public override func updateCell(_ aCell: NSCell) {
        // Update the cell layout
        layoutCells()

        var isRight = false

        // Find the cell in the left or right-hand collections
        var cellIndex = leftCells.firstIndex { $0 === aCell }
        if cellIndex == nil {
            isRight = true
            cellIndex = rightCells.firstIndex { $0 === aCell }
        }

        // Do nothing if this cell is not part of this control
        guard let cellIndex else { return }

        // Refresh this cell
        var bounds = boundsForCell(at: cellIndex,
                                   isOnRight: isRight)

        if cellIndex == 0 {
            // If on the left or right, then we also need to update the end caps
            if isRight {
                bounds.size.width = NSMaxX(self.bounds) - bounds.origin.x
            } else {
                let viewBounds = self.bounds
                bounds.size.width = NSMaxX(bounds) - NSMinX(viewBounds)
                bounds.origin.x = NSMinX(viewBounds)
            }
        }

        setNeedsDisplay(bounds)
    }

    public override func updateCellInside(_ aCell: NSCell) {
        updateCell(aCell)
    }

    // MARK: - Mouse events

    weak var lastTrackedCell: NSCell? {
        return trackingCell
    }

    public override func mouseDown(with event: NSEvent) {
        // Clear any tracking cell that might exist
        trackingCell = nil

        // Find which cell was clicked on
        var index = indexOfCell(at: convert(event.locationInWindow,
                                            from: nil))
        let isOnRight: Bool
        if index > 0 {
            // Left-hand cell was clicked
            isOnRight = false
            index -= 1

            trackingCell = leftCells[index]
        } else if index < 0 {
            // Right-hand cell was clicked
            isOnRight = true
            index = (-index) - 1

            trackingCell = rightCells[index]
        } else {
            // No cell was clicked
            return
        }

        trackingCellFrame = boundsForCell(at: index,
                                          isOnRight: isOnRight)

        // Track the mouse
        var trackResult = false
        var trackingEvent = event

        while !trackResult {
            guard let trackingCell, trackingCell.isEnabled else { return }

            trackResult = trackingCell.trackMouse(with: trackingEvent,
                                                  in: trackingCellFrame,
                                                  of: self,
                                                  untilMouseUp: false)

            if !trackResult {
                // If the mouse is still down, continue tracking it in case it re-enters
                // the control
                while let nextEvent = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp],
                                                      until: .distantFuture,
                                                      inMode: .eventTracking,
                                                      dequeue: true) {
                    trackingEvent = nextEvent
                    if trackingEvent.type == .leftMouseUp {
                        // All finished
                        return
                    } else if trackingEvent.type == .leftMouseDragged {
                        // Restart tracking if the mouse has re-entered the cell
                        let location = convert(trackingEvent.locationInWindow,
                                               from: nil)
                        if NSPointInRect(location, trackingCellFrame) {
                            break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Keyboard events

    func setIsActive(_ newIsActive: Bool) {
        if isActive == newIsActive { return }

        isActive = newIsActive
        needsDisplay = true
    }

    private final func performKeyEquiv(_ equiv: String?,
                                       on cells: [NSCell]) -> Bool {
        for cell in cells {
            if let equiv, (cell.keyEquivalent as NSString).isEqual(to: equiv) {
                sendAction(cell.action,
                           to: cell.target)
                return true
            }
        }

        return false
    }

    public override func performKeyEquivalent(with theEvent: NSEvent) -> Bool {
        if !isActive { return false }

        // Cmd + back and Cmd + forward perform goForward and goBackwards actions in the 'current' view
        let keyEquivString = theEvent.charactersIgnoringModifiers

        if performKeyEquiv(keyEquivString,
                           on: leftCells) {
            return true
        }
        if performKeyEquiv(keyEquivString,
                           on: rightCells) {
            return true
        }

        return false
    }
}
