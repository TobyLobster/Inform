//
//  IFSetting.swift
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFSetting.h, and
//  the constants are defined in IFSettingConstants.m.
//

import Cocoa

@objc @implementation
extension IFSetting {
    /// The view that can be used to edit the settings
    var settingView: NSView!
    /// The compiler settings object that this setting should manage
    weak var compilerSettings: IFCompilerSettings?
    /// YES if the settings are in the process of changing
    private final var settingsChanging = false

    // MARK: - Initialisation

    override init() {
        super.init()
    }

    init(nibName: NSNib.Name?) {
        super.init()

        if let nibName {
            _ = Bundle.customLoadNib(nibName, owner: self)
        }
    }

    // MARK: - Setting up the view

    var title: String {
        return "Setting"
    }

    // MARK: - Communicating with the IFCompilerSettings object

    func setSettings() {
        // Do nothing
    }

    func updateFromCompilerSettings() {
        // Do nothing
    }

    func enable(forCompiler compiler: String) -> Bool {
        return true
    }

    func dictionary() -> NSMutableDictionary? {
        if let compilerSettings {
            return compilerSettings.dictionary(for: type(of: self))
        }

        return nil
    }

    // MARK: - Notifying the controller about things

    @IBAction func settingsHaveChanged(_ sender: Any?) {
        if settingsChanging { return }

        settingsChanging = true
        NotificationCenter.default.post(name: .IFSettingHasChanged,
                                        object: self)
        settingsChanging = false
    }

    // MARK: - Default way of dealing with the plist: copy entries from the dictionary

    var plistEntries: NSMutableDictionary? {
        return dictionary()
    }

    @objc(updateSettings:withPlistEntries:)
    func update(_ settings: IFCompilerSettings,
                withPlistEntries entries: [String: Any]?) {
        guard let entries, entries.count > 0 else { return } // nothing to do

        let dict = dictionary()

        if let dict, (entries as NSDictionary) === dict { return } // Really, just sanity checking: this shouldn't happen

        dict?.removeAllObjects()

        // Load entries from the list of entries
        for (key, value) in entries {
            dict?[key] = value
        }

        // Cause the settings to be updated
        updateFromCompilerSettings()
    }
}
