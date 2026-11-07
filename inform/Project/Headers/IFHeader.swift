//
//  IFHeader.swift
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFHeader.h.
//

import Foundation

@objc @implementation extension IFHeader {
    /// The name of this header
    var headingName: String
    /// The parent of this header (NOT RETAINED)
    weak var parent: IFHeader?
    /// The child headings for this heading
    private final var childHeaders: [IFHeader]
    /// The symbol that is associated with this heading
    var symbol: IFIntelSymbol?

    // MARK: - Initialisation

    init(name: String, parent newParent: IFHeader?, children newChildren: [IFHeader]?) {
        headingName = name
        parent = newParent

        childHeaders = newChildren ?? []

        super.init()

        for child in childHeaders {
            child.parent = self
        }
    }

    // MARK: - Accessing values

    var children: [IFHeader] {
        get {
            return childHeaders
        }
        set {
            for child in childHeaders {
                child.parent = nil
            }

            childHeaders = newValue

            for child in childHeaders {
                child.parent = self
            }
        }
    }
}
