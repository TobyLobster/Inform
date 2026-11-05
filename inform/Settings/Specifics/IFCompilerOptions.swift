//
//  IFCompilerOptions.swift
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFCompilerOptions.h.
//

import Cocoa

@objc @implementation
extension IFCompilerOptions {
    @IBOutlet private final var naturalInform: NSButton?

    override convenience init() {
        self.init(nibName: "CompilerSettings")
    }

    // MARK: - Misc info

    public override var title: String {
        return IFUtility.localizedString("Compiler Settings")
    }

    // MARK: - Setting up

    public override func updateFromCompilerSettings() {
        let settings = compilerSettings

        // Natural Inform
        naturalInform?.state = settings?.usingNaturalInform == true ? .on : .off
    }

    public override func setSettings() {
        let settings = compilerSettings

        // Whether or not to use Natural Inform
        settings?.usingNaturalInform = naturalInform?.state == .on
    }

    public override func enable(forCompiler compiler: String) -> Bool {
        // These settings are unsafe to change while using Natural Inform
        if compiler == IFCompilerNaturalInform {
            return false
        } else {
            return true
        }
    }
}
