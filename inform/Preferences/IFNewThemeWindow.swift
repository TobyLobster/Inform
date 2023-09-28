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
    @IBOutlet var _themeName:String!

    func themeName() -> String! {
        return _themeName
    }

    func setThemeName(theName:String!) {
        _themeName = theName
        nameField.stringValue = theName
    }

    @IBAction func okButtonClicked(sender:AnyObject!) {
        _themeName = nameField.stringValue
        NSApp.endSheet(self, returnCode: NSApplication.ModalResponse.OK.rawValue)
    }

    @IBAction func cancelButtonClicked(sender:AnyObject!) {
        _themeName = ""
        NSApp.endSheet(self, returnCode: NSApplication.ModalResponse.abort.rawValue)
    }
}
