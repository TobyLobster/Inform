//
//  IFToolbarProgressIndicator.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFToolbarProgressIndicator: NSProgressIndicator {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    override func draw(_ dirtyRect:NSRect) {
        var rect = self.bounds
        let radius = floor(rect.size.height / 2)
        let bz = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        // Draw progress inside
        bz.setClip()
        rect.size.width = floor(rect.size.width * (self.doubleValue / self.maxValue))
        NSColor(named: "StatusIndicator")?.set()
        rect.fill()

        // Draw border
        bz.lineWidth = 1.0
        NSColor(named: "StatusIndicatorBorder")?.set()
        bz.stroke()
    }
}
