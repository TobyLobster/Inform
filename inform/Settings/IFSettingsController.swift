//
//  IFSettingsController.swift
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

import Cocoa

/// The 'standard' settings classes, which are always added to the controller on startup
private var standardSettingsClasses: [IFSetting.Type] = []

@objc @implementation extension IFSettingsController {
    // UI + model
    /// (V) The view that will contain the settings (IFSettingsView is derived from IFCollapsableView)
    private final var _settingsView: IFSettingsView?
    /// (M) The compiler settings object that contains the settings data
    private final var _compilerSettings: IFCompilerSettings?

    // Settings to display
    private final var settings: [IFSetting]

    /// true if we're dealing with a change of settings (stops settings from updating at the wrong time)
    private final var settingsChanging = false

    // MARK: - Settings methods

    class func addStandardSettingsClass(_ settingClass: AnyClass) {
        guard let settingType = settingClass as? IFSetting.Type else {
            NSException(name: NSExceptionName("IFNotASettingClass"),
                        reason: "Class \(NSStringFromClass(settingClass)) is not a derivative of the IFSetting class",
                        userInfo: nil).raise()
            return
        }

        standardSettingsClasses.append(settingType)
    }

    class func makeStandardSettings() -> NSMutableArray {
        let res = NSMutableArray()

        // Create all the 'standard' classes
        // These must know how to initialise themselves with just an init call (NSObject's, as Swift only makes
        // objects from a class value with an initialiser that every subclass has)
        for settingClass in standardSettingsClasses {
            res.add((settingClass as NSObject.Type).init())
        }

        return res
    }

    // MARK: - Initialisation, etc

    override convenience init() {
        self.init(settings: IFSettingsController.makeStandardSettings() as! [IFSetting])
    }

    init(settings theSettings: [IFSetting]) {
        settings = theSettings

        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - User interface

    @objc private func settingChangedNotification(_ not: Notification) {
        settingsHaveChanged(not.object)
    }

    private final func repopulateSettings() {
        // Re-add all the settings views (with no compiler settings, the settings are asked about no compiler, as the
        // Objective-C's nil was taken as an empty string)
        let compilerType = _compilerSettings?.primaryCompilerType ?? ""

        _settingsView?.startRearranging()
        _settingsView?.removeAllSubviews()

        NotificationCenter.default.removeObserver(self)

        for setting in settings {
            // Skip this view if it's not enabled for this compiler type
            if !setting.enable(forCompiler: compilerType) {
                continue
            }

            _settingsView?.addSubview(setting.settingView,
                                      withTitle: setting.title)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(settingChangedNotification(_:)),
                                                   name: .IFSettingHasChanged,
                                                   object: setting)
        }

        // This notification will also have been removed above
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateAllSettings),
                                               name: .IFSetting,
                                               object: _compilerSettings)

        _settingsView?.finishRearranging()

        _compilerSettings?.setGeneric(settings)

        for setting in settings {
            setting.compilerSettings = _compilerSettings
        }
    }

    var settingsView: IFSettingsView? {
        get {
            return _settingsView
        }
        set {
            _settingsView = newValue

            repopulateSettings()
        }
    }

    @IBAction func settingsHaveChanged(_ sender: Any?) {
        guard let sender else {
            // All settings have changed
            for setting in settings {
                settingsHaveChanged(setting)
            }

            return
        }

        if let setting = sender as? IFSetting {
            // A specific settings object has changed
            settingsChanging = true
            setting.setSettings()
            settingsChanging = false

            updateAllSettings()
        } else {
            // Same as all settings changed, really
            settingsHaveChanged(nil)
        }

        _compilerSettings?.settingsHaveChanged()
    }

    // MARK: - Model

    var compilerSettings: IFCompilerSettings? {
        get {
            return _compilerSettings
        }
        set {
            if newValue === _compilerSettings {
                return
            }

            // NOTE: this implementation assumes a one-to-one relationship between the IFCompilerSettings object
            // and ourselves: things may go a bit wonky if multiple settings controllers refer to the same
            // IFCompilerSettings object.

            // (FIXME: this actually happens, as each pane has its own SettingsController. Though I don't think
            // this will cause any pain for now)

            // Deregister/release the compiler settings if we're not using them any more
            if let oldSettings = _compilerSettings {
                NotificationCenter.default.removeObserver(self,
                                                          name: .IFSetting,
                                                          object: oldSettings)
            }

            // Store the new compiler settings object
            _compilerSettings = newValue
            _compilerSettings?.setGeneric(settings)

            for setting in settings {
                setting.compilerSettings = _compilerSettings
            }
            _compilerSettings?.reloadAllSettings()

            // Show the settings, and update ourselves when the compiler settings change
            repopulateSettings()
        }
    }

    func updateAllSettings() {
        // Don't do anything if we're already in the middle of updating the settings
        if settingsChanging {
            return
        }

        // Get each setting object to reflect the status of the current compilerSettings
        for setting in settings {
            setting.updateFromCompilerSettings()
        }
    }
}
