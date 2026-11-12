//
//  IFLinkButton.swift
//  Inform
//
//  Added in November 2026. The interface is IFLinkButton.h.
//

import Cocoa

@objc @implementation extension IFLinkButton {
    private final var _showsPointingHand = true

    var showsPointingHand: Bool {
        get {
            return _showsPointingHand
        }
        set {
            _showsPointingHand = newValue
            window?.invalidateCursorRects(for: self)
        }
    }

    public override func resetCursorRects() {
        if _showsPointingHand {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}
