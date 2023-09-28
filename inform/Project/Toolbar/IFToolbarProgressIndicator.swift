//
//  IFToolbarProgressIndicator.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFToolbarProgressIndicator: NSProgressIndicator {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    override func draw(_ dirtyRect:NSRect) {
        var rect:NSRect = self.bounds
        let radius:CGFloat = floor(rect.size.height / 2)
        let bz:NSBezierPath! = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

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
