//
//  IFI7OutputSettings.swift
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFI7OutputSettings.h.
//

import Cocoa

@objc @implementation
extension IFI7OutputSettings {
    @IBOutlet private final var zmachineVersion: NSMatrix?
    @IBOutlet private final var releaseBlorb: NSButton?

    override convenience init() {
        self.init(nibName: "OutputSettingsI7")
    }

    public override var title: String {
        return IFUtility.localizedString("Output Settings")
    }

    // MARK: - Setting up

    var createBlorbForRelease: Bool {
        get {
            let settings = compilerSettings
            let value = settings?.dictionary(for: type(of: self))[IFSettingCreateBlorb] as AnyObject?

            let result: Bool

            if let value {
                result = value.boolValue!
            } else {
                result = true
            }

            return result
        }
        set {
            let settings = compilerSettings

            settings?.dictionary(for: type(of: self))[IFSettingCreateBlorb] = NSNumber(value: newValue)
            settings?.settingsHaveChanged()
        }
    }

    public override func updateFromCompilerSettings() {
        let settings = compilerSettings

        // Supported Z-Machine versions
        let supportedZMachines = settings?.supportedZMachines

        for cell in zmachineVersion?.cells ?? [] {
            if let supportedZMachines {
                if supportedZMachines.contains(NSNumber(value: Int32(truncatingIfNeeded: cell.tag))) {
                    cell.isEnabled = true
                } else {
                    cell.isEnabled = false
                }
            } else {
                cell.isEnabled = true
            }
        }

        // Selected Z-Machine version
        let zcodeVersion = Int(settings?.zcodeVersion ?? 0)

        if zmachineVersion?.cell(withTag: zcodeVersion) != nil {
            zmachineVersion?.selectCell(withTag: zcodeVersion)
        } else {
            // (A radio matrix only deselects its cells if it allows no selection)
            zmachineVersion?.allowsEmptySelection = true
            zmachineVersion?.deselectAllCells()
        }

        // Whether or not we should generate a blorb file on release
        releaseBlorb?.state = createBlorbForRelease ? .on : .off
    }

    public override func setSettings() {
        let willCreateBlorb = releaseBlorb?.state == .on
        let settings = compilerSettings

        // (Nothing is selected if the version isn't one offered here)
        if let selectedCell = zmachineVersion?.selectedCell() {
            settings?.zcodeVersion = Int32(truncatingIfNeeded: selectedCell.tag)
        }
        createBlorbForRelease = willCreateBlorb
    }

    public override func enable(forCompiler compiler: String) -> Bool {
        // These settings are unsafe to change while using Natural Inform
        if compiler == IFCompilerNaturalInform {
            return true
        } else {
            return false
        }
    }
}
