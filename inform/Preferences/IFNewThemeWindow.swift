//
//  IFNewThemeWindow.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFNewThemeWindow: NSWindow, NSTextFieldDelegate {
    @IBOutlet var okButton: NSButton!
    @IBOutlet var cancelButton: NSButton!
    @IBOutlet var nameField: NSTextField!
    @objc public var themeName: String!

    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            nameField.delegate = self
        }
    }

    /// Puts a name in the name field
    func setThemeName(theName:String!) {
        themeName = theName
        nameField.stringValue = theName
        enableOKButton()
    }

    /// The name in the name field, without spaces around it
    private var typedName: String {
        return nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A theme needs a name
    private func enableOKButton() {
        okButton.isEnabled = !typedName.isEmpty
    }

    func controlTextDidChange(_ obj: Notification) {
        enableOKButton()
    }

    @IBAction func okButtonClicked(sender:AnyObject!) {
        themeName = typedName
        sheetParent?.endSheet(self, returnCode: .OK)
    }

    @IBAction func cancelButtonClicked(sender:AnyObject!) {
        themeName = ""
        sheetParent?.endSheet(self, returnCode: .abort)
    }
}
