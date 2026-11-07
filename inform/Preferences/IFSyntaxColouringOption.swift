//
//  IFSyntaxColouringOption.swift
//  Inform
//
//  Created by Toby Nelson in 2022, in IFPreferences.m.
//  Translated from Objective-C in November 2026. The interface is still in IFPreferences.h.
//

import Cocoa

@objc @implementation extension IFSyntaxColouringOption {

    @NSCopying var colour: NSColor
    @NSCopying var defaultColour: NSColor

    override convenience init() {
        self.init(colour: NSColor.black)
    }

    init(colour defaultColour: NSColor) {
        self.colour           = defaultColour.copy() as! NSColor
        self.defaultColour    = defaultColour.copy() as! NSColor
        super.init()
    }

    @objc(encodeWithCoder:)
    func encode(with encoder: NSCoder) {
        encoder.encode(colour, forKey: "colour")
        encoder.encode(defaultColour, forKey: "defaultColour")
    }

    public required convenience init?(coder decoder: NSCoder) {
        self.init() // Call the designated initialiser first

        guard let colour = decoder.decodeObject(of: NSColor.self, forKey: "colour"),
              let defaultColour = decoder.decodeObject(of: NSColor.self, forKey: "defaultColour") else {
            // A damaged archive: read as nothing, so that the theme it's in can be left out
            return nil
        }
        self.colour = colour.copy() as! NSColor
        self.defaultColour = defaultColour.copy() as! NSColor
    }

    class var supportsSecureCoding: Bool {
        return true
    }

    @objc(copyWithZone:)
    func copy(with zone: NSZone? = nil) -> Any {
        let result = IFSyntaxColouringOption()
        result.colour = colour.copy() as! NSColor
        result.defaultColour = defaultColour.copy() as! NSColor
        return result
    }
}
