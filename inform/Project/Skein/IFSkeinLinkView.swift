//
//  IFSkeinLinkView.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFSkeinLinkView: NSView {

    override init(frame frameRect:NSRect) {
        super.init(frame:frameRect)

        self.wantsLayer = true
        self.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        self.wantsLayer = true
        self.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
    }

    override func draw(_ dirtyRect:NSRect) {
        var blackRect:NSRect = self.bounds

        // Leave a one pixel border blank, because this helps antialiasing
        blackRect = NSInsetRect(blackRect, 0.0, 1.0)

        // Only draw the part that needs redrawing
        blackRect = NSIntersectionRect(blackRect, dirtyRect)

        // Draw rectangle
        NSColor(deviceRed:0.25,
                               green:0.25,
                                blue:0.25,
                               alpha:1.0).set()
        blackRect.fill()
    }
}
