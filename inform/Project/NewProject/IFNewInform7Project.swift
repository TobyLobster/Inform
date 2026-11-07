//
//  IFNewInform7Project.swift
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFNewInform7Project.h.
//

import Cocoa

@objc @implementation extension IFNewInform7Project {
    /// Where the author's name comes from
    private final let preferences: IFPreferences
    private final var _initialSelectionRange: NSRange

    override convenience init() {
        self.init(preferences: IFPreferences.shared)
    }

    init(preferences newPreferences: IFPreferences) {
        preferences = newPreferences
        _initialSelectionRange = NSRange(location: 0, length: 0)
        super.init()
    }

    @objc(configView)
    var configView: (any IFNewProjectSetupView)? {
        return nil
    }

    @objc(setInitialFocus:)
    func setInitialFocus(_ window: NSWindow) {
        // Nothing to do
    }

    @objc(setupFile:fromView:withStory:withExtensionURL:)
    func setupFile(_ file: IFProjectFile,
                   from view: (any IFNewProjectSetupView)?,
                   withStory story: String?,
                   withExtensionURL extensionURL: URL?) {
        let settings = IFCompilerSettings()

        settings.usingNaturalInform = true
        settings.allowLegacyExtensionDirectory = false
        file.settings = settings

        let defaultContents: String

        // Default file content
        if let story {
            defaultContents = story
        } else {
            var name = (((file.filename ?? "") as NSString).lastPathComponent as NSString).deletingPathExtension
            if name.isEmpty { name = "Untitled" }

            var longuserName: String = preferences.freshGameAuthorName

            // If longusername contains a '.', then we have to enclose it in quotes
            let needQuotes = longuserName.utf16.contains(UInt16(UInt8(ascii: ".")))

            if needQuotes { longuserName = "\"\(longuserName)\"" }

            // The contents of the file
            let heading = "\"\(name)\" by \(longuserName)\n\n"

            _initialSelectionRange = NSRange(location: heading.utf16.count, length: "Example Location".utf16.count)
            defaultContents = heading + "Example Location is a room. "
        }

        // Create the default file
        file.addSourceFile("story.ni",
                           withContents: defaultContents.data(using: .utf8) ?? Data())
    }

    @objc(initialSelectionRange)
    var initialSelectionRange: NSRange {
        return _initialSelectionRange
    }

    @objc(typeName)
    var typeName: String {
        return "org.inform-fiction.project"
    }
}
