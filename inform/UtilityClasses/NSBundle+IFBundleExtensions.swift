//
//  NSBundle+IFBundleExtensions.swift
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//  Translated from Objective-C in November 2026. The interface is still NSBundle+IFBundleExtensions.h.
//

import Cocoa

// *******************************************************************************************
@objc(IFBundleExtensions) @implementation extension Bundle {

    class func customLoadNib(_ nibName: String, owner: Any?) -> Bool {
        return Bundle.main.loadNibNamed(nibName,
                                        owner: owner,
                                        topLevelObjects: nil)
    }
}
