//
//  IFNotifyingWindow.swift
//  Inform
//
//  Created by Andrew Hunter on 06/01/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa

@objc @implementation extension IFNotifyingWindow {
    public override func makeFirstResponder(_ aResponder: NSResponder?) -> Bool {
        // Cocoa doesn't provide any way for us to track which window is the first responder: this
        // should hopefully correct that oversight
        let res = super.makeFirstResponder(aResponder)

        if res {
            // For convenience's sake, we assume that the delegate implements our changeFirstResponder: method
            // (this is bad practice in general, but saves a lot of hassle in this case as we aren't planning
            // to reuse this class)
            (delegate as? NSObject)?.changeFirstResponder(aResponder)
        }

        IFFindController.shared().updateFromFirstResponder()
        return res
    }
}
