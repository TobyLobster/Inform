//
//  IFCollapsableView.swift
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

// Based around 'ZoomCollapsableView', used by Zoom for the iFiction drawer.
// We want this for our preferences tab

import Cocoa

private let border: CGFloat = 8.0
private let fontSize: CGFloat = 13.0

@objc @implementation extension IFCollapsableView {
    /// Views to display
    private final var views: [NSView] = []
    /// Titles of views to display (one-to-one mapping with views)
    private final var titles: [String] = []

    /// true if a rearrangement is in progress
    private final var rearranging = false

    // MARK: - Init/housekeeping

    public override init(frame: NSRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Drawing

    public override var isOpaque: Bool {
        return false
    }

    public override func draw(_ rect: NSRect) {
        let titleFont = NSFont.boldSystemFont(ofSize: fontSize)
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont,
                                                              .foregroundColor: NSColor.textColor]

        // Draw the titles and frames
        let frameColour = NSColor(deviceRed: 0.5,
                                  green: 0.5,
                                  blue: 0.5,
                                  alpha: 1.0)

        // Calculate the maximum width of all subviews, in whole points
        var maxWidth: CGFloat = 0
        for thisView in views {
            let thisFrame = thisView.frame

            maxWidth = max(maxWidth, thisFrame.size.width.rounded(.towardZero))
        }

        for (thisView, thisTitle) in zip(views, titles) {
            let titleSize = (thisTitle as NSString).size(withAttributes: titleAttributes)
            let thisFrame = thisView.frame

            let ypos = thisFrame.origin.y - (titleSize.height * 1.2)

            // Draw the border rect
            let borderRect = NSRect(x: floor(border) + 0.5,
                                    y: floor(ypos) + 0.5,
                                    width: maxWidth,
                                    height: floor(thisFrame.size.height + (titleSize.height * 1.2)))
            frameColour.set()
            NSBezierPath.stroke(borderRect)

            // Draw the title
            (thisTitle as NSString).draw(at: NSPoint(x: border * 2, y: ypos + 2 + titleSize.height * 0.1),
                                         withAttributes: titleAttributes)
        }

        // Draw the rest
        super.draw(rect)
    }

    // MARK: - Management

    func removeAllSubviews() {
        for subview in views {
            subview.removeFromSuperview()
        }

        views.removeAll()
        titles.removeAll()
    }

    func addSubview(_ subview: NSView,
                    withTitle title: String) {
        views.append(subview)
        titles.append(title)

        addSubview(subview)
        subview.autoresizingMask = [.maxYMargin, .maxXMargin]
        subview.needsDisplay = true

        // Rearrange the views
        rearrangeSubviews()
    }

    func rearrangeSubviews() {
        if rearranging {
            return
        }
        rearranging = true

        var newSize = self.bounds.size

        let titleFont = NSFont.boldSystemFont(ofSize: fontSize)
        let titleHeight = titleFont.ascender - titleFont.descender

        //
        // Stage one: Calculate our new height
        //
        var newHeight = border

        for subview in views {
            let viewFrame = subview.frame

            newHeight += titleHeight * 1.2
            newHeight += viewFrame.size.height
            newHeight += border
        }

        newSize.height = floor(newHeight)
        setFrameSize(newSize)

        //
        // Stage two: Position the views appropriately
        //
        var ypos = border

        for subview in views {
            var viewFrame = subview.frame

            ypos += titleHeight * 1.2

            if subview.superview !== self {
                if subview.superview != nil {
                    subview.removeFromSuperview()
                }
                addSubview(subview)
            }

            if viewFrame.origin.x != border ||
                viewFrame.origin.y != floor(ypos) {
                viewFrame.origin.x = border
                viewFrame.origin.y = floor(ypos)

                subview.setFrameOrigin(viewFrame.origin)
                subview.needsDisplay = true
            }

            ypos += viewFrame.size.height
            ypos += border
        }

        // Final stage: redraw
        needsDisplay = true
        rearranging = false
    }

    public override var isFlipped: Bool {
        return true
    }

    func startRearranging() {
        rearranging = true
    }

    func finishRearranging() {
        rearranging = false

        rearrangeSubviews()
    }
}
