//
//  IFAdvancedSettings.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFAdvancedSettings: IFSetting {
    @IBOutlet var allowLegacyExtensionDirectory: NSButton!

    convenience init() {
        self.init(nibName:"AdvancedSettings")
    }

    func title() -> String! {
        return IFUtility.localizedString("Extensions Settings")
    }

    override func updateFromCompilerSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        allowLegacyExtensionDirectory.state = settings.allowLegacyExtensionDirectory ? NSControl.StateValue.on : NSControl.StateValue.off
    }

    override func setSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        settings.allowLegacyExtensionDirectory = allowLegacyExtensionDirectory.state==NSControl.StateValue.on
    }

    override func enable(forCompiler compiler:String!) -> Bool {
        return true
    }
}
