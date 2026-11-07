//
//  IFNewInform7ExtensionProject.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//  Translated from Objective-C in November 2026. The interface is still IFNewInform7ExtensionProject.h.
//

import Cocoa

@objc @implementation extension IFNewInform7ExtensionProject {
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

        // Read extension source (none if there's no extension, or it can't be read)
        let data = extensionURL.flatMap { NSData(contentsOf: $0) as Data? } ?? Data()

        // Create the extension file
        file.addSourceFile("extension.i7x", withContents: data)
    }

    @objc(initialSelectionRange)
    var initialSelectionRange: NSRange {
        return NSRange(location: 0, length: 0)
    }

    @objc(typeName)
    var typeName: String {
        return "org.inform-fiction.xproject"
    }
}
