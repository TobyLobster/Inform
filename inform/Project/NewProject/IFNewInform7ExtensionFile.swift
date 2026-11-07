//
//  IFNewInform7ExtensionFile.swift
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFNewInform7ExtensionFile.h.
//

import Cocoa

@objc @implementation extension IFNewInform7ExtensionFile {
    private final var vw: IFNewInform7ExtensionView?
    private final weak var project: IFProject?
    /// Where the author's name comes from
    private final let preferences: IFPreferences
    /// Where to put the insertion point in the new extension, once it's written
    private final var _initialSelectionRange: NSRange

    convenience init(project theProject: IFProject) {
        self.init(project: theProject, preferences: IFPreferences.shared)
    }

    init(project theProject: IFProject, preferences thePreferences: IFPreferences) {
        project = theProject
        preferences = thePreferences
        _initialSelectionRange = NSRange(location: 0, length: 0)
        super.init()
    }

    @objc(configView)
    var configView: (any IFNewProjectSetupView)? {
        let options: IFNewInform7ExtensionView
        if let vw {
            options = vw
        } else {
            options = IFNewInform7ExtensionView(preferences: preferences)
            _ = Bundle.customLoadNib("NaturalExtensionOptions", owner: options)
            vw = options
        }

        options.setupControls()

        return options
    }

    @objc(setupFile:fromView:withStory:withExtensionURL:)
    func setupFile(_ file: IFProjectFile,
                   from view: (any IFNewProjectSetupView)?,
                   withStory story: String?,
                   withExtensionURL extensionURL: URL?) {
    }

    @objc(errorMessage)
    var errorMessage: String? {
        // With the project gone, or never saved, there's nowhere to put the extension
        if project?.materialsDirectoryURL == nil {
            return IFUtility.localizedString("NoProjectForExtension")
        }
        if (vw?.authorName ?? "").isEmpty {
            return IFUtility.localizedString("BadExtensionAuthor")
        }
        if (vw?.extensionName ?? "").isEmpty {
            return IFUtility.localizedString("BadExtensionName")
        }

        return nil
    }

    @objc(confirmationMessage)
    var confirmationMessage: String? {
        if let saveFilename, FileManager.default.fileExists(atPath: saveFilename) {
            return IFUtility.localizedString("Extension already exists")
        }

        return nil
    }

    @objc(saveFilename)
    var saveFilename: String? {
        guard let materialsPath = project?.materialsDirectoryURL?.path else {
            return nil
        }
        // As in Objective-C, a missing name adds nothing to the path
        let extensionFilename = ((vw?.extensionName ?? "") as NSString).appendingPathExtension("i7x") ?? ""
        var extnDir = (materialsPath as NSString).appendingPathComponent("Extensions")
        extnDir = (extnDir as NSString).appendingPathComponent(vw?.authorName ?? "")
        extnDir = (extnDir as NSString).appendingPathComponent(extensionFilename)
        return extnDir
    }

    private final func createDeepDirectory(_ deepDirectory: URL) {
        // Creates a directory and any parent directories as required
        try? FileManager.default.createDirectory(atPath: deepDirectory.path,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
    }

    func writeExtension(_ fileURL: URL) -> Bool {
        let extensionName = vw?.extensionName ?? ""
        let authorName = vw?.authorName ?? ""
        let contents1 = "\(extensionName) by \(authorName) begins here.\n\n"
        let contents2 = "\n\n\(extensionName) ends here.\n"
        let contents = contents1 + contents2

        let range = NSRange(location: contents1.utf16.count, length: 0)

        let contentData = contents.data(using: .utf8)

        if !fileURL.isFileURL {
            return false
        }

        // Try to create the extension directory, if necessary
        createDeepDirectory(fileURL.deletingLastPathComponent())

        // Try to create the file
        if !FileManager.default.createFile(atPath: fileURL.path,
                                           contents: contentData,
                                           attributes: nil) {
            return false
        }

        _initialSelectionRange = range
        return true
    }

    @objc(createAndOpenDocument:)
    func createAndOpenDocument(_ fileURL: URL) -> Bool {
        if !writeExtension(fileURL) {
            return false
        }

        // Open the file
        guard let newDoc = try? IFSingleFile(contentsOf: fileURL, ofType: "Inform 7 extension") else {
            // The extension is written, but can't be opened (Objective-C gave the document controller nil)
            return false
        }
        newDoc.initialSelectionRange = _initialSelectionRange
        NSDocumentController.shared.addDocument(newDoc)
        newDoc.makeWindowControllers()
        newDoc.showWindows()

        return true
    }

    @objc(setInitialFocus:)
    func setInitialFocus(_ window: NSWindow) {
        vw?.setInitialFocus(window)
    }

    @objc(initialSelectionRange)
    var initialSelectionRange: NSRange {
        return _initialSelectionRange
    }

    @objc(typeName)
    var typeName: String {
        return "org.inform-fiction.inform7.extension"
    }
}

@objc @implementation extension IFNewInform7ExtensionView {
    @IBOutlet private final var optionsView: NSView?

    @IBOutlet private final var authorNameField: NSTextField?
    @IBOutlet private final var extensionNameField: NSTextField?

    /// Where the author's name comes from
    private final let preferences: IFPreferences

    init(preferences thePreferences: IFPreferences) {
        preferences = thePreferences
        super.init()
    }

    @objc(view)
    var view: NSView? {
        return optionsView
    }

    func setupControls() {
        var longuserName: String = preferences.freshGameAuthorName

        // If longuserName contains a '.', then we have to enclose it in quotes
        let needQuotes = longuserName.utf16.contains(UInt16(UInt8(ascii: ".")))

        if needQuotes { longuserName = "\"\(longuserName)\"" }

        authorNameField?.stringValue = longuserName
        extensionNameField?.stringValue = IFUtility.localizedString("New Extension")
    }

    var authorName: String {
        return authorNameField?.stringValue ?? ""
    }

    var extensionName: String {
        return extensionNameField?.stringValue ?? ""
    }

    func setInitialFocus(_ window: NSWindow) {
        window.makeFirstResponder(extensionNameField)
    }
}
