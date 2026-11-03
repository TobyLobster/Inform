//
//  IFNewThemeWindow.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFNewThemeWindow: NSWindow {
    @IBOutlet var okButton: NSButton!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var nameField: NSTextField!
    @objc public var themeName: String!

    func setThemeName(theName:String!) {
        themeName = theName
        nameField.stringValue = theName
    }

    @IBAction func okButtonClicked(sender:AnyObject!) {
        themeName = nameField.stringValue
        sheetParent?.endSheet(self, returnCode: .OK)
    }

    @IBAction func cancelButtonClicked(sender:AnyObject!) {
        themeName = ""
        sheetParent?.endSheet(self, returnCode: .abort)
    }
}
