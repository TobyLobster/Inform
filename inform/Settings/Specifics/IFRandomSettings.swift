//
//  IFRandomSettings.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFRandomSettings : IFSetting {
    @IBOutlet var makePredictable: NSButton!

    convenience init() {
        self.init(nibName:"RandomSettings")
    }

    override var title: String! {
        return IFUtility.localizedString("Randomness Settings")
    }

    override func updateFromCompilerSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        makePredictable.state = settings.nobbleRng ? NSControl.StateValue.on : NSControl.StateValue.off
    }

    override func setSettings() {
        let settings:IFCompilerSettings! = self.compilerSettings

        settings.nobbleRng = makePredictable.state == NSControl.StateValue.on
    }

    override func enable(forCompiler compiler: String!) -> Bool {
        // These settings only apply to Natural Inform
        return compiler == IFCompilerNaturalInform
    }
}
