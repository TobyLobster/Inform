//
//  IFPageBarCell.swift
//  Inform
//
//  Created by Andrew Hunter on 06/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import AppKit

@objc @implementation extension IFPageBarCell {
    /// True if this cell is to be drawn on the right-hand side
    private final var isRight = false
    /// The frame of this cell reported when the last mouse tracking started
    private final var trackingFrame = NSRect.zero

    // Radio
    /// The radio group identifier for this cell
    var radioGroup: Int32

    // Key equivalent
    /// The key equivalent string for this cell
    private final var storedKeyEquivalent: String? = nil

    // MARK: - Initialisation

    public override init() {
        radioGroup = -1
        super.init()
    }

    public override init(textCell text: String) {
        radioGroup = -1
        super.init()

        let attrText = NSAttributedString(string: text,
                                          attributes: [.foregroundColor: NSColor.controlTextColor,
                                                       .font: NSFont.systemFont(ofSize: 11)])

        attributedStringValue = attrText
    }

    public override init(imageCell image: NSImage?) {
        radioGroup = -1
        super.init()

        self.image = image
    }

    /// Swift requires this, as the other initialisers are overridden. The Objective-C didn't override `initWithCoder:`,
    /// so a cell made from a nib (which none is) is in radio group 0, as there.
    public required init(coder: NSCoder) {
        radioGroup = 0
        super.init(coder: coder)
    }

    public override var stringValue: String {
        get {
            return super.stringValue
        }
        set {
            let attrText = NSAttributedString(string: newValue,
                                              attributes: [.foregroundColor: NSColor.controlTextColor,
                                                           .font: NSFont.systemFont(ofSize: 11)])

            attributedStringValue = attrText
        }
    }

    // MARK: - Cell properties

    func update() {
        (controlView as? NSControl)?.updateCell(self)
    }

    public override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set {
            super.isHighlighted = newValue
            update()
        }
    }

    // MARK: - Sizing and rendering

    public override func setIsRight(_ newIsRight: Bool) {
        isRight = newIsRight
    }

    public override var cellSize: NSSize {
        var size = NSSize.zero

        // Work out the minimum size required to contain the text or the image
        let image = self.image
        let text = attributedStringValue

        if let image, text.length > 0 {
            let imageSize = image.size
            let textSize = text.size()

            if textSize.height > imageSize.height {
                size.height = textSize.height
            } else {
                size.height = imageSize.height
            }

            size.width = imageSize.width + 2 + textSize.width
            size.width += 4
        } else if let image {
            size = image.size
            size.width += 4
        } else {
            size = text.size()
            size.width += 4
        }

        // Add a border for the margins
        size.width += 8
        size.width = floor(size.width + 0.5)
        size.height = floor(size.height)

        return size
    }

    public override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let image = self.image
        var text = attributedStringValue

        // Draw the background
        var backgroundColor: NSColor? = nil

        if isHighlighted {
            backgroundColor = NSColor(named: "Highlighted")
        } else if state == .on {
            backgroundColor = NSColor(named: "Selected")
        }

        if let backgroundColor {
            var backgroundBounds = self.controlView?.bounds ?? .zero
            backgroundBounds.size.width -= 9.0

            var backgroundFrame = cellFrame
            backgroundFrame.size.width -= 1

            if isRight {
                backgroundFrame.origin.x += 1
            }

            IFPageBarView.drawOverlay(backgroundColor,
                                      in: backgroundFrame,
                                      totalBounds: backgroundBounds)
        }

        var textColor: NSColor? = NSColor.labelColor
        if state == .on {
            textColor = NSColor(named: "SelectedText")
        }
        // If the cell is highlighted we use the highlighted text colour whether the cell is selected or not.
        if isHighlighted {
            textColor = NSColor(named: "HighlightedText")
        }

        if let image, text.length > 0 {
            // Work out the sizes
            let imageSize = image.size
            let textSize = text.size()

            var size = NSSize.zero
            if textSize.height > imageSize.height {
                size.height = textSize.height
            } else {
                size.height = imageSize.height
            }

            size.width = imageSize.width + 2 + textSize.width

            // Draw the image
            var imageRect = NSRect.zero

            imageRect.origin = NSPoint(x: cellFrame.origin.x + (cellFrame.size.width - size.width) / 2,
                                       y: cellFrame.origin.y + (cellFrame.size.height + 2 - imageSize.height) / 2)
            imageRect.size = imageSize

            let layer = NSImage(size: NSSize(width: NSMaxX(imageRect), height: NSMaxY(imageRect)))
            layer.lockFocus()

            image.draw(in: imageRect,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1.0)

            if image.isTemplate {
                textColor?.set()
                imageRect.fill(using: .sourceAtop)
            }
            layer.unlockFocus()
            layer.draw(at: .zero,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1)

            // Draw the text
            var textPoint = NSPoint(x: cellFrame.origin.x + (cellFrame.size.width - size.width) / 2 + imageSize.width + 2,
                                    y: cellFrame.origin.y + (cellFrame.size.height + 2 - textSize.height) / 2)

            if isRight { textPoint.x += 1 }

            var textRect = NSRect.zero
            textRect.origin = textPoint
            textRect.size = textSize
            var attributes = text.attributes(at: 0, effectiveRange: nil)
            attributes[.foregroundColor] = textColor
            text = NSAttributedString(string: text.string, attributes: attributes)
            text.draw(in: NSIntegralRect(textRect))
        } else if let image {
            // Draw the image
            let imageSize = image.size
            var imageRect = NSRect.zero

            imageRect.origin = NSPoint(x: cellFrame.origin.x + (cellFrame.size.width - imageSize.width) / 2,
                                       y: cellFrame.origin.y + (cellFrame.size.height + 2 - imageSize.height) / 2)
            imageRect.size = imageSize
            let layer = NSImage(size: NSSize(width: NSMaxX(imageRect), height: NSMaxY(imageRect)))
            layer.lockFocus()

            image.draw(in: imageRect,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1.0)
            if image.isTemplate {
                textColor?.set()
                imageRect.fill(using: .sourceAtop)
            }
            layer.unlockFocus()
            layer.draw(at: .zero,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1)
        } else if text.length > 0 {
            // Draw the text (an empty string has no attributes to draw it with)
            let textSize = text.size()
            var textPoint = NSPoint(x: cellFrame.origin.x + (cellFrame.size.width - textSize.width) / 2,
                                    y: cellFrame.origin.y + (cellFrame.size.height + 2 - textSize.height) / 2)

            if isRight { textPoint.x += 1 }

            var textRect = NSRect.zero
            textRect.origin = textPoint
            textRect.size = textSize
            var attributes = text.attributes(at: 0, effectiveRange: nil)
            attributes[.foregroundColor] = textColor
            text = NSAttributedString(string: text.string, attributes: attributes)
            text.draw(in: NSIntegralRect(textRect))
        }
    }

    // MARK: - Cell states

    public override var nextState: Int {
        // Radio cells can be turned on (but get turned off manually)
        if radioGroup >= 0 {
            return NSControl.StateValue.on.rawValue
        }

        // TODO: allow for push-on/push-off cells
        return NSControl.StateValue.off.rawValue
    }

    public override var state: NSControl.StateValue {
        get {
            return super.state
        }
        set {
            if newValue == state {
                return
            }

            super.state = newValue
            update()

            if radioGroup >= 0 {
                (controlView as? IFPageBarView)?.setState(Int32(truncatingIfNeeded: newValue.rawValue),
                                                          for: self)
            }
        }
    }

    // MARK: - Tracking

    public override func trackMouse(with theEvent: NSEvent,
                                    in cellFrame: NSRect,
                                    of controlView: NSView,
                                    untilMouseUp: Bool) -> Bool {
        trackingFrame = cellFrame

        return super.trackMouse(with: theEvent,
                                in: cellFrame,
                                of: controlView,
                                untilMouseUp: untilMouseUp)
    }

    public override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        isHighlighted = true

        return true
    }

    public override func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint,
                                          in controlView: NSView) -> Bool {
        let shouldBeHighlighted = NSPointInRect(currentPoint, trackingFrame)
        if shouldBeHighlighted != isHighlighted {
            isHighlighted = shouldBeHighlighted
        }

        return true
    }

    public override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint,
                                      in controlView: NSView, mouseIsUp flag: Bool) {
        isHighlighted = false
    }

    // MARK: - Key equivalent

    public override var keyEquivalent: String {
        return storedKeyEquivalent ?? ""
    }

    func setKeyEquivalent(_ newKeyEquivalent: String) {
        storedKeyEquivalent = newKeyEquivalent
    }
}
