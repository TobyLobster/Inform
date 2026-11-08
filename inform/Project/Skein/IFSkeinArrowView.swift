//
//  IFSkeinArrowView.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import Cocoa

private let kSkeinArrowHeadHalfHeight = kSkeinArrowHeadHeight * 0.5

@objc @implementation extension IFSkeinArrowView {

    // MARK: - Initialisation

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the view up either.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private final func drawArrow(withOffset offset: NSPoint, color: NSColor) {
        color.set()
        color.setFill()
        let path = NSBezierPath()
        path.lineWidth = kSkeinArrowLineThickness

        let y = floor(frame.size.height * 0.5) + 0.5 + offset.y
        let h = kSkeinArrowHeadHalfHeight
        let w = frame.size.width
        let m = frame.size.width - kSkeinArrowHeadLength + offset.x

        // Draw arrow head
        path.lineJoinStyle = .miter
        path.lineCapStyle = .butt
        path.move(to: NSPoint(x: m, y: y + h))
        path.line(to: NSPoint(x: w, y: y))
        path.line(to: NSPoint(x: m, y: y - h))
        path.line(to: NSPoint(x: m, y: y + h))
        path.fill()
        path.stroke()

        // Draw dotted line for stalk
        let dashArray: [CGFloat] = [1.0, 3.0]
        path.setLineDash(dashArray, count: 2, phase: 0.0)

        path.move(to: NSPoint(x: 0.0, y: y))
        path.line(to: NSPoint(x: w, y: y))
        path.stroke()
    }

    public override func draw(_ dirtyRect: NSRect) {

        // Draw a semi transparent box around the black arrow to stop the black arrow getting
        // visually muddled up with the black links beneath it.
        do {
            NSColor(deviceRed: 1.0,
                    green: 1.0,
                    blue: 1.0,
                    alpha: 0.8).set()

            let y = floor(frame.size.height * 0.5) + 0.5
            let h = kSkeinArrowHeadHalfHeight
            let m = frame.size.width - kSkeinArrowHeadLength - 2.0
            NSRect(x: 0, y: y - 2.0, width: m, height: 4.0).fill(using: .sourceOver)
            NSRect(x: m,
                   y: y - h - kSkeinArrowLineThickness,
                   width: kSkeinArrowHeadLength + 2.0,
                   height: 2.0 * h + 2.0 * kSkeinArrowLineThickness).fill(using: .sourceOver)
        }

        // Draw shadow
        drawArrow(withOffset: NSPoint(x: 1.0, y: -1.0), color: NSColor(deviceRed: 0.0,
                                                                       green: 0.0,
                                                                       blue: 0.0,
                                                                       alpha: 0.15))
        // Draw arrow
        drawArrow(withOffset: NSPoint(x: 0.0, y: 0.0), color: NSColor(deviceRed: 0.25,
                                                                      green: 0.25,
                                                                      blue: 0.25,
                                                                      alpha: 1.0))
    }
}
