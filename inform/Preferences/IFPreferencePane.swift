//
//  IFPreferencePane.swift
//  Inform
//
//  Created by Andrew Hunter on 01/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFPreferencePane.h.
//

import Cocoa

@objc @implementation extension IFPreferencePane {
    /// The view for these preferences
    var preferenceView: NSView?

    // MARK: - Initialisation

    override init() {
        super.init()
    }

    init(nibName: String) {
        super.init()

        _ = Bundle.customLoadNib(nibName,
                                 owner: self)
    }

    // MARK: - Information about the preference window

    var toolbarImage: NSImage? {
        return nil
    }

    var preferenceName: String {
        return "Unnamed preference"
    }

    var identifier: NSToolbarItem.Identifier {
        return NSToolbarItem.Identifier(type(of: self).description())
    }

    var maxHeight: CGFloat {
        if let preferenceView {
            return preferenceView.frame.size.height
        } else {
            return 0
        }
    }

    var minHeight: CGFloat {
        return self.maxHeight
    }

    var tooltip: String? {
        return nil
    }
}
