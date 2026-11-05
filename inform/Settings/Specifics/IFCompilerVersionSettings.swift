//
//  IFCompilerVersionSettings.swift
//  Inform
//
//  Created by Toby Nelson on 05/01/2019.
//  Copyright 2019 Toby Nelson. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFCompilerVersionSettings.h.
//

import Cocoa

@objc @implementation
extension IFCompilerVersionSettings {
    @IBOutlet private final var compilerVersionBox: NSPopUpButton?
    @IBOutlet private final var descriptionText: NSTextField?

    @IBAction private final func compilerVersionChanged(_ sender: Any?) {
        let selectedEntry = getSelectedListEntry(fromDisplayName: compilerVersionBox?.stringValue)
        if let selectedEntry {
            updateDescription(selectedEntry)
            setSettings()
        }
    }

    private final func updateDescription(_ selectedEntry: CompilerList.Entry?) {
        if let selectedEntry {
            descriptionText?.stringValue = selectedEntry.description
        } else {
            descriptionText?.stringValue = ""
        }
    }

    override convenience init() {
        self.init(nibName: "CompilerVersionSettings")
    }

    public override var title: String {
        return IFUtility.localizedString("Compiler Version Settings")
    }

    // MARK: - Setting up

    private final func getSelectedListEntry(fromDisplayName displayName: String?) -> CompilerList.Entry? {
        let list = CompilerList.compilerList
        for entry in list {
            if entry.displayName == compilerVersionBox?.title {
                return entry
            }
        }
        return nil
    }

    private final func getSelectedListEntry(fromId currentSelectedId: String?) -> CompilerList.Entry? {
        let list = CompilerList.compilerList
        var selectedEntry: CompilerList.Entry?
        for entry in list {
            compilerVersionBox?.addItem(withTitle: entry.displayName)
            if entry.identifier == currentSelectedId {
                selectedEntry = entry
            }
        }

        if selectedEntry == nil {
            if list.count > 0 {
                selectedEntry = list[0]
            }
        }
        return selectedEntry
    }

    public override func updateFromCompilerSettings() {
        compilerVersionBox?.removeAllItems()

        let settings = compilerSettings
        let selectedEntry = getSelectedListEntry(fromId: settings?.compilerVersion)
        if let selectedEntry {
            compilerVersionBox?.title = selectedEntry.displayName
        } else {
            compilerVersionBox?.title = ""
        }
        updateDescription(selectedEntry)
    }

    public override func setSettings() {
        let settings = compilerSettings
        let currentEntry = getSelectedListEntry(fromDisplayName: compilerVersionBox?.title)
        if let currentEntry {
            settings?.compilerVersion = currentEntry.identifier
        }
    }

    public override func enable(forCompiler compiler: String) -> Bool {
        // These settings only apply to Natural Inform
        if compiler == IFCompilerNaturalInform {
            return true
        } else {
            return false
        }
    }
}
