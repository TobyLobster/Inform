//
//  IFMiscSettings.swift
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFMiscSettings.h.
//

import Cocoa

@objc @implementation
extension IFMiscSettings {
    @IBOutlet private final var strictMode: NSButton?
    @IBOutlet private final var infixMode: NSButton?
    @IBOutlet private final var debugMode: NSButton?

    override convenience init() {
        self.init(nibName: "MiscSettings")
    }

    public override var title: String {
        return IFUtility.localizedString("Misc Settings")
    }

    // MARK: - Setting up

    public override func updateFromCompilerSettings() {
        strictMode?.state = strict ? .on : .off
        infixMode?.state = infix ? .on : .off
        debugMode?.state = debug ? .on : .off

        if compilerSettings?.usingNaturalInform == true {
            infixMode?.isEnabled = false
            infixMode?.state = .off
            dictionary()?[IFSettingInfix] = NSNumber(value: false)
        } else {
            infixMode?.isEnabled = true
        }
    }

    public override func setSettings() {
        strict = strictMode?.state == .on
        infix = infixMode?.state == .on
        debug = debugMode?.state == .on
    }

    // MARK: - The settings

    var strict: Bool {
        get {
            let setting = dictionary()?[IFSettingStrict] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return true
            }
        }
        set {
            dictionary()?[IFSettingStrict] = NSNumber(value: newValue)
            settingsHaveChanged(self)
        }
    }

    var infix: Bool {
        get {
            let setting = dictionary()?[IFSettingInfix] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return false
            }
        }
        set {
            dictionary()?[IFSettingInfix] = NSNumber(value: newValue)
            settingsHaveChanged(self)
        }
    }

    var debug: Bool {
        get {
            let setting = dictionary()?[IFSettingDEBUG] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return true
            }
        }
        set {
            dictionary()?[IFSettingDEBUG] = NSNumber(value: newValue)
            settingsHaveChanged(self)
        }
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
