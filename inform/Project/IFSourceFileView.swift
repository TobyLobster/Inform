//
//  IFSourceFileView.swift
//  Inform
//
//  Created by Andrew Hunter on Mon Feb 16 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

import AppKit

/// The images, made when first used
private let topTear         = NSImage(named: "App/TornPages/torn_top")
private let bottomTear      = NSImage(named: "App/TornPages/torn_bottom")
private let arrowNotPressed = NSImage(named: "App/TornPages/TearArrow")

@objc @implementation extension IFSourceFileView {
    /// `true` if we should draw a 'tear' at the top of the view
    private final var tornAtTop = false
    /// `true` if we should draw a 'tear' at the bottom of the view
    private final var tornAtBottom = false
    /// The last known 'used' rect (used to determine whether or not to update the bottom tear)
    private final var lastUsedRect = NSRect.zero

    /// The rect the text uses in the text container, or none without a layout manager or text container
    private final var usedRect: NSRect {
        guard let layoutManager, let textContainer else { return .zero }
        return layoutManager.usedRect(for: textContainer)
    }

    public override func keyDown(with event: NSEvent) {
        if let controller = window?.windowController as? IFProjectController {
            RunLoop.current.perform(#selector(IFProjectController.removeAllTemporaryHighlights),
                                    target: controller,
                                    argument: nil,
                                    order: 8,
                                    modes: [.default])
        }

        super.keyDown(with: event)
    }

    public override func makeTouchBar() -> NSTouchBar? {
        return nil
    }

    public override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags

        if modifiers.intersection([.shift, .control, .option, .command]).isEmpty
            && event.clickCount == 1 {
            // Single click, no modifiers
            let bounds = self.bounds
            let usedRect = self.usedRect
            let mousePoint = convert(event.locationInWindow, from: nil)

            let deleg = delegate as? IFSourceNavigation
            if tornAtTop && mousePoint.y < NSMinY(bounds) + (topTear?.size.height ?? 0) {
                deleg?.sourceFileShowPreviousSection(self)

                return
            } else if tornAtBottom && mousePoint.y > NSMinY(bounds) + textContainerOrigin.y + NSMaxY(usedRect) {
                deleg?.sourceFileShowNextSection(self)

                // Finished handling this event
                return
            }
        }

        // Process this event as normal
        super.mouseDown(with: event)
    }

    private final func setMouseCursor(withPosition position: NSPoint) -> Bool {
        let mousePoint = convert(position, from: nil)
        if tornAtTop {
            let bounds = self.bounds
            let tornAtTopRect = NSRect(x: NSMinX(bounds), y: NSMinY(bounds),
                                       width: bounds.size.width, height: topTear?.size.height ?? 0)

            if NSPointInRect(mousePoint, tornAtTopRect) {
                NSCursor.pointingHand.set()
                return true
            }
        }

        if tornAtBottom {
            let origin = textContainerOrigin
            let bounds = self.bounds
            let usedRect = self.usedRect
            let containerSize = NSSize(width: NSMaxX(usedRect), height: NSMaxY(usedRect))

            let tornAtBottomRect = NSRect(x: NSMinX(bounds),
                                          y: origin.y + containerSize.height,
                                          width: bounds.size.width,
                                          height: bounds.size.height - (origin.y + containerSize.height))
            if NSPointInRect(mousePoint, tornAtBottomRect) {
                NSCursor.pointingHand.set()
                return true
            }
        }
        return false
    }

    public override func mouseMoved(with theEvent: NSEvent) {
        if !setMouseCursor(withPosition: theEvent.locationInWindow) {
            super.mouseMoved(with: theEvent)
        }
    }

    // MARK: - Drawing

    public override func draw(_ rect: NSRect) {
        // Perform normal drawing
        NSGraphicsContext.current?.saveGraphicsState()
        super.draw(rect)
        NSGraphicsContext.current?.restoreGraphicsState()

        // Draw the 'page tears' if necessary
        let bounds = self.bounds
        let tearColour = NSColor(deviceRed: 0.95,
                                 green: 0.95,
                                 blue: 0.9,
                                 alpha: 1.0)

        if tornAtTop {
            let tornSize = topTear?.size ?? .zero

            // Draw the tear
            topTear?.draw(in: NSRect(x: NSMinX(bounds), y: NSMinY(bounds), width: bounds.size.width, height: tornSize.height),
                          from: NSRect(x: 0, y: 0, width: bounds.size.width, height: tornSize.height),
                          operation: .sourceOver,
                          fraction: 1.0,
                          respectFlipped: true,
                          hints: nil)

            // Draw the 'up' arrow
            let arrow = arrowNotPressed
            let upSize = arrowNotPressed?.size ?? .zero
            var upRect = NSRect.zero

            upRect.origin = NSPoint(x: floor(NSMinX(bounds) + (bounds.size.width - upSize.width) / 2),
                                    y: floor(NSMinY(bounds) + (tornSize.height - upSize.height) / 2))
            upRect.size = upSize

            arrow?.draw(in: upRect,
                        from: .zero,
                        operation: .sourceOver,
                        fraction: 1.0,
                        respectFlipped: true,
                        hints: nil)
        }
        if tornAtBottom {
            let tornSize = bottomTear?.size ?? .zero
            let origin = textContainerOrigin
            let usedRect = self.usedRect
            let containerSize = NSSize(width: NSMaxX(usedRect), height: NSMaxY(usedRect))

            // Draw the background
            tearColour.set()
            NSRect(x: NSMinX(bounds),
                   y: origin.y + containerSize.height + tornSize.height,
                   width: bounds.size.width,
                   height: bounds.size.height - (origin.y + containerSize.height + tornSize.height)).fill()

            // Draw the tear
            bottomTear?.draw(in: NSRect(x: NSMinX(bounds), y: origin.y + containerSize.height, width: bounds.size.width, height: tornSize.height),
                             from: NSRect(x: 0, y: 0, width: bounds.size.width, height: tornSize.height),
                             operation: .sourceOver,
                             fraction: 1.0,
                             respectFlipped: true,
                             hints: nil)

            // Draw the 'down' arrow
            let arrow = arrowNotPressed
            let upSize = arrowNotPressed?.size ?? .zero
            var upRect = NSRect.zero

            upRect.origin = NSPoint(x: floor(NSMinX(bounds) + (bounds.size.width - upSize.width) / 2),
                                    y: (origin.y + containerSize.height + (tornSize.height - upSize.height) / 2))
            upRect.size = upSize

            arrow?.draw(in: upRect,
                        from: .zero,
                        operation: .sourceOver,
                        fraction: 1.0,
                        respectFlipped: false,
                        hints: nil)
        }
    }

    // MARK: - Drawing 'tears' at the top and bottom

    private final func updateTearing() {
        // Work out the inset to use
        var inset = NSSize(width: 3, height: 6)

        if tornAtTop {
            inset.height += floor(topTear?.size.height ?? 0)
        }
        if tornAtBottom {
            inset.height += floor(bottomTear?.size.height ?? 0)
        }
        inset.height = floor(inset.height / 2)

        // Update the display
        textContainerInset = inset

        lastUsedRect = usedRect
        needsDisplay = true
    }

    @discardableResult
    private final func checkForRedraw() -> Bool {
        if tornAtBottom {
            // If the last used rect is different from the current used rect, then redraw the bottom of the display as well
            let newUsedRect = usedRect

            if NSMaxY(newUsedRect) != NSMaxY(lastUsedRect) {
                let bounds = self.bounds
                lastUsedRect = newUsedRect

                let minY = NSMinY(lastUsedRect)

                let needsDisplay = NSRect(x: NSMinX(bounds), y: minY, width: bounds.size.width, height: NSMaxY(bounds) - minY)
                super.setNeedsDisplay(needsDisplay)

                return true
            }
        }

        return false
    }

    public override func setNeedsDisplay(_ invalidRect: NSRect) {
        super.setNeedsDisplay(invalidRect)
        checkForRedraw()
    }

    public override var textContainerOrigin: NSPoint {
        // Calculate the origin
        var origin = NSPoint(x: 3, y: 6)

        if tornAtTop {
            origin.y += topTear?.size.height ?? 0
        }

        return origin
    }

    func setTornAtTop(_ newTornAtTop: Bool) {
        if tornAtTop != newTornAtTop {
            tornAtTop = newTornAtTop
            updateTearing()
        }
    }

    func setTornAtBottom(_ newTornAtBottom: Bool) {
        if tornAtBottom != newTornAtBottom {
            tornAtBottom = newTornAtBottom
            updateTearing()
        }
    }

    //
    // Paste (and dropped text, and services)
    //
    public override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        // Plain text, which NSTextView asks for by its old name
        if type == .string || type.rawValue == "NSStringPboardType" {
            // Fix line endings (as NSString, in which "\r\n" holds "\r", unlike String, where it's one Character)
            if let string = pboard.string(forType: .string) as NSString?,
               string.range(of: "\r").location != NSNotFound {
                let fixedString = string.replacingOccurrences(of: "\r\n", with: "\n")
                                        .replacingOccurrences(of: "\r", with: "\n")

                // Read the fixed text instead, as from the pasteboard
                let fixed = NSPasteboard.withUniqueName()
                fixed.declareTypes([.string], owner: nil)
                fixed.setString(fixedString, forType: .string)
                let result = super.readSelection(from: fixed, type: type)
                fixed.releaseGlobally()
                return result
            }
        }

        return super.readSelection(from: pboard, type: type)
    }
}
