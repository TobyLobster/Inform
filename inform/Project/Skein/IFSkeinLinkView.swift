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

    // The line is the layer's contents, stretched to fill the layer, so it stays the right length while the
    // length animates. (A drawRect backing store isn't stretched, so the line was too short or too long.)
    override var wantsUpdateLayer: Bool {
        return true
    }

    override func updateLayer() {
        let height = self.bounds.size.height

        self.layer?.contents = NSImage(size: NSSize(width: 1.0, height: height), flipped: false) { rect in
            // Leave a one pixel border blank, because this helps antialiasing
            let blackRect = NSInsetRect(rect, 0.0, 1.0)

            // Draw rectangle
            NSColor(deviceRed:0.25,
                                   green:0.25,
                                    blue:0.25,
                                   alpha:1.0).set()
            blackRect.fill()
            return true
        }
        self.layer?.contentsGravity = .resize
    }
}
