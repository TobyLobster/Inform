//
//  IFSyntaxStyles.swift
//  Inform
//
//  Created by Toby Nelson on 19/04/2023.
//  Translated from Objective-C in November 2026. The interface is still IFSyntaxStyles.h.
//

import Foundation

@objc @implementation extension IFSyntaxStyles {

    var styles: UnsafeMutablePointer<IFSyntaxStyle>?
    var numCharStyles: UInt

    override init() {
        styles          = nil
        numCharStyles   = 0

        super.init()
    }

    func read(_ index: Int) -> IFSyntaxStyle {

        precondition(index >= 0, "style index out of range")

        // Allow index == numCharStyles, counting it as a terminator
        precondition(index <= numCharStyles, "style index out of range")

        if (index < 0) || (index >= numCharStyles) {
            return []       // IFSyntaxNone
        }
        return styles![index]
    }

    func write(_ index: Int, value: IFSyntaxStyle) {
        precondition(index >= 0, "style index out of range")
        precondition(index < numCharStyles, "style index out of range")

        if (index >= 0) && (index < numCharStyles) {
            styles![index] = value
        }
    }
}
