//
//  IFSkeinBlessButton.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//

import Cocoa

// Loaded when first used, as the Objective-C's +initialize loaded them when the class was first used
private let blessImage      = NSImage(named: "App/Skein/Trans-tick-off")
private let curseImage      = NSImage(named: "App/Skein/Trans-cross-off")
private let blessOverImage  = NSImage(named: "App/Skein/Trans-tick")
private let curseOverImage  = NSImage(named: "App/Skein/Trans-cross")

@objc @implementation extension IFSkeinBlessButton {
    private final var _blessState = false
    private final var inside = false
    private final var focusTrackingArea: NSTrackingArea?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        isBordered = false
        wantsLayer = true
        blessState = true
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't set the button up either.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var blessState: Bool {
        get {
            return _blessState
        }
        set {
            _blessState = newValue
            updateImage()
        }
    }

    private final func imageForState() -> NSImage? {
        let state = (_blessState ? 2 : 0) + (inside ? 1 : 0)
        return [curseImage, curseOverImage, blessImage, blessOverImage][state]
    }

    private final func updateImage() {
        image = imageForState()
        needsDisplay = true
    }

    func toggleBlessState() {
        blessState = !_blessState
    }

    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    public override func mouseEntered(with event: NSEvent) {
        inside = true
        updateImage()
    }

    public override func mouseExited(with event: NSEvent) {
        inside = false
        updateImage()
    }

    public override func updateTrackingAreas() {
        if focusTrackingArea == nil {
            var focusTrackingAreaOptions: NSTrackingArea.Options = .activeInActiveApp
            focusTrackingAreaOptions.insert(.mouseEnteredAndExited)
            focusTrackingAreaOptions.insert(.cursorUpdate)
            focusTrackingAreaOptions.insert(.inVisibleRect)

            let focusTrackingArea = NSTrackingArea(rect: NSZeroRect,
                                                   options: focusTrackingAreaOptions,
                                                   owner: self,
                                                   userInfo: nil)
            self.focusTrackingArea = focusTrackingArea
            addTrackingArea(focusTrackingArea)
        }
    }
}
