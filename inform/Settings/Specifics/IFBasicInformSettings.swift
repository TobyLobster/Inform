//
//  IFBasicInformSettings.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFBasicInformSettings : IFSetting {
    @IBOutlet var basicInform: NSButton!

    convenience init() {
        self.init(nibName:"BasicInformSettings")
    }

    func title() -> String! {
        return IFUtility.localizedString("Basic Inform")
    }

    override func updateFromCompilerSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        basicInform.state = settings.basicInform ? NSControl.StateValue.on : NSControl.StateValue.off
    }

    override func setSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        settings.basicInform = basicInform.state == NSControl.StateValue.on
    }

    func enableForCompiler(compiler:String!) -> Bool {
        // These settings only apply to Natural Inform
        return compiler == IFCompilerNaturalInform
    }
}
