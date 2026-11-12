//
//  IFProject.swift
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFProject.h.
//

import Cocoa

@objc @implementation
extension IFProject {
    // The data for this project
    private final var projectFile: IFProjectFile?
    private final var _settings: IFCompilerSettings

    let compiler: IFCompiler

    private final let sourceTexts: IFSourceTexts

    private final var notes: NSTextStorage?

    var initialSelectionRange: NSRange
    var projectFileType: IFFileType

    private final let extensionTestCases: IFExtensionTestCases

    private final var _currentSkein: IFSkein?
    let skeins: NSMutableArray

    private final var watchExpressions: NSMutableArray
    private final var breakpoints: NSMutableArray

    private final var materialsAccess: IFProjectMaterialsPresenter?

    private final var _documentFileWrapper: FileWrapper?

    var inBuild: IFInBuild

    var preferences: IFPreferences

    // == Initialisation ==

    override init() {
        _settings               = IFCompilerSettings()
        projectFile             = nil
        sourceTexts             = IFSourceTexts()
        initialSelectionRange   = NSRange(location: 0, length: 0)
        projectFileType         = .unknown

        skeins                  = NSMutableArray()
        compiler                = IFCompiler()
        notes                   = NSTextStorage(string: "")
        materialsAccess         = nil
        extensionTestCases      = IFExtensionTestCases()
        inBuild                 = IFInBuild()
        preferences             = IFPreferences.shared

        watchExpressions        = NSMutableArray()
        breakpoints             = NSMutableArray()

        super.init()

        _currentSkein           = IFSkein(project: self)
    }

    // == close ==
    public override func close() {
        sourceTexts.unregisterTexts()

        materialsAccess?.close()
        materialsAccess = nil

        let projectURL = fileURL
        super.close()

        // Clean out any files that we aren't using any more, if set in the preferences. Saving cleans out the build
        // files, but the project is saved before it's built, so they're deleted here, from the disk, once the project
        // has closed.
        if preferences.cleanProjectOnClose, let projectURL {
            IFProject.cleanOutUnnecessaryFiles(at: projectURL,
                                               alsoCleanIndex: preferences.alsoCleanIndexFiles)
        }
    }

    func createMaterials() {
        materialsAccess?.close()
        materialsAccess = IFProjectMaterialsPresenter(url: fileURL)
    }

    // == useful file URLs ==
    private final var sourceDirectoryURL: URL? {
        return fileURL?.appendingPathComponent("Source")
    }

    var buildDirectoryURL: URL? {
        return fileURL?.appendingPathComponent("Build")
    }

    var buildOutputFileURL: URL? {
        return buildDirectoryURL?.appendingPathComponent("output")
                                 .appendingPathExtension(settings.fileExtension)
    }

    var mainSourceFileURL: URL? {
        guard let mainSourceFile else {
            return nil
        }
        return sourceDirectoryURL?.appendingPathComponent(mainSourceFile)
    }

    private final var testSourceFileURL: URL? {
        return sourceDirectoryURL?.appendingPathComponent("story.ni")
    }

    var indexDirectoryURL: URL? {
        return fileURL?.appendingPathComponent("Index")
    }

    var settingsFileURL: URL? {
        return fileURL?.appendingPathComponent("Settings.plist")
    }

    var materialsDirectoryURL: URL? {
        guard let fileURL else {
            return nil
        }

        // Work out the location of the materials folder
        let projectName = (fileURL.lastPathComponent as NSString).deletingPathExtension
        var pathURL     = fileURL.deletingLastPathComponent()
        pathURL         = pathURL.appendingPathComponent(projectName)
        pathURL         = pathURL.appendingPathExtension("materials")

        return pathURL
    }

    var useNewExtensions: Bool {
        // TODO
        return true
    }

    private final var metadataURL: URL? {
        return fileURL?.appendingPathComponent("Metadata.ifiction")
    }

    private final var normalProblemsURL: URL? {
        return buildDirectoryURL?.appendingPathComponent("Problems.html")
    }

    var extensionReportURL: URL? {
        return buildDirectoryURL?.appendingPathComponent("Inbuild.html")
    }

    var baseReportURL: URL? {
        if isExtensionProject {
            return extensionTestCases.baseReportURL
        }
        preconditionFailure("Asking for report when not an extension project")
    }

    var currentReportURL: URL? {
        if isExtensionProject {
            let index = _currentSkein.map { skeins.index(of: $0) } ?? NSNotFound
            if index == NSNotFound {
                return nil
            }

            return extensionTestCases.reportURL(forTestCaseAt: index)
        }
        preconditionFailure("Asking for report when not an extension project")
    }

    var combinedReportURL: URL? {
        if isExtensionProject {
            return buildDirectoryURL?.appendingPathComponent("Problems.html")
        }
        preconditionFailure("Asking for combined report when not an extension project")
    }

    // == useful file paths ==
    var mainSourceFile: String? {
        let sourceDir = projectFile?.sourceDirectory
        let source    = sourceDir?.fileWrappers ?? [:]

        var mainSource: String? = nil

        // In order of name, so that the choice doesn't change when there's more than one
        for key in source.keys.sorted() {
            let pathExtension = (key as NSString).pathExtension
            if projectFileType == .inform7ExtensionProject {
                if pathExtension == "i7x" {
                    mainSource = key
                }
            }
            else {
                if pathExtension == "inf" ||
                   pathExtension == "ni" ||
                   pathExtension == "i7" {
                    mainSource = key
                }
            }
        }

        return mainSource
    }

    private final var projectInputPathName: String? {
        // Inform 7 compiler takes the project directory path
        return fileURL?.path
    }

    var mainSourcePathName: String? {
        guard let mainSourceFileURL else {
            return nil
        }
        return mainSourceFileURL.path
    }

    func path(forSourceFile file: String?) -> String? {
        guard let file else { return nil }
        if (file as NSString).isAbsolutePath { return (file as NSString).standardizingPath }

        return sourceDirectoryURL?.appendingPathComponent(file).path
    }

    // == intest ==
    private final var testSourcePathName: String? {
        return testSourceFileURL?.path
    }

    var inTest: IFInTest {
        return extensionTestCases.inTest
    }

    func refreshTestCases() {
        // Only relevant for Inform7 extension projects
        let isExtensionProject = projectFileType == .inform7ExtensionProject
        extensionTestCases.refreshTestCases(forExtension: isExtensionProject ? mainSourcePathName : nil)
    }

    var testCases: [[String: Any]]? {
        return extensionTestCases.testCases
    }

    func extractSourceTask(forExtensionTestCase testCase: String?) {
        // Only relevant for Inform7 extension projects
        if projectFileType != .inform7ExtensionProject {
            return
        }

        extensionTestCases.extractSourceTask(forExtensionTestCase: testCase,
                                             fromExtension: mainSourcePathName ?? "",
                                             outputToSourceFile: testSourcePathName ?? "")
    }

    func testCommands(forExtensionTestCase testCase: String) -> [String]? {
        return extensionTestCases.testCommands(forExtensionTestCase: testCase,
                                               ofExtension: mainSourcePathName ?? "")
    }

    var nodeToReport: IFSkeinItem? {
        if let currentSkein {
            return currentSkein.nodeToReport
        }
        return nil
    }

    func generateReport(forTestCase testCase: String,
                        errorCode: String,
                        skeinNodeId: UInt,
                        skeinNodes: Int32,
                        outputURL: URL) -> Bool {
        return extensionTestCases.generateReport(forTestCase: testCase,
                                                 ofExtension: mainSourcePathName ?? "",
                                                 errorCode: errorCode,
                                                 problemsURL: normalProblemsURL!,
                                                 skeinNodeId: skeinNodeId,
                                                 skeinNodes: skeinNodes,
                                                 outputURL: outputURL)
    }

    // Outputs an HTML report that combinines the individual reports
    func generateCombinedReport(forBaseInputURL baseInputURL: URL,
                                numTests: Int32,
                                outputURL: URL) -> Bool {
        return extensionTestCases.generateCombinedReport(forBaseInputURL: baseInputURL,
                                                         ofExtension: mainSourcePathName ?? "",
                                                         numTests: numTests,
                                                         outputURL: outputURL)
    }

    private final func setSkeinTestCaseTitles() {
        if skeins.count > 0 {
            var index = 0
            for case let skein as IFSkein in skeins {
                if let testCases, testCases.count > index {
                    skein.rootItem.command = testCases[index]["testTitle"] as? String
                }
                index += 1
            }
        }
    }

    var currentSkein: IFSkein? {
        return _currentSkein
    }

    func selectSkein(_ index: Int32) {
        if index < 0 {
            _currentSkein = nil
            let userDictionary: [AnyHashable: Any] = [:]
            NotificationCenter.default.post(name: .IFSkeinReplaced,
                                            object: self,
                                            userInfo: userDictionary)
            return
        }

        // Make sure we have enough skeins
        while skeins.count <= Int(index) {
            skeins.add(IFSkein(project: self))
        }

        // Has skein changed?
        let skein = skeins[Int(index)] as! IFSkein
        if _currentSkein !== skein {
            // Clear skein undos when setting skein
            if let currentSkein = _currentSkein { undoManager?.removeAllActions(withTarget: currentSkein) }

            // Select the appropriate skein
            _currentSkein = skein

            // Set the titles of each skein to the titles of each test case
            setSkeinTestCaseTitles()

            // Let the skein views update based on the new skein
            let userDictionary: [AnyHashable: Any] = [:]
            NotificationCenter.default.post(name: .IFSkeinReplaced,
                                            object: self,
                                            userInfo: userDictionary)
        }

        // Make sure the skein updates
        _currentSkein?.postChanged(withAnimate: false,
                                   keepActiveVisible: false)
    }

    private final func loadSkeins(fileType: IFFileType) {
        let isExtensionProject = fileType == .inform7ExtensionProject

        // Clear undo stack
        if let currentSkein = _currentSkein { undoManager?.removeAllActions(withTarget: currentSkein) }

        // Disable undo
        undoManager?.disableUndoRegistration()

        // Load skeins, in place of any read before, as by Revert To Saved
        skeins.removeAllObjects()
        projectFile?.load(into: skeins,
                          project: self,
                          isExtensionProject: isExtensionProject)

        // Enable undo
        undoManager?.enableUndoRegistration()

        // Select the first skein
        if isExtensionProject {
            selectSkein(-1)
        }
        else {
            selectSkein(0)
        }
    }

    func executeInBuild(forExtension extensionURL: URL,
                        action: String,
                        withConfirmation confirmed: Bool) -> Int32 {
        let internalPath = IFUtility.path(forInformInternalAppSupport: settings.compilerVersion)

        return inBuild.executeForInfo(withProject: fileURL!,
                                      action: action,
                                      forExtension: extensionURL,
                                      withInternal: URL(fileURLWithPath: internalPath),
                                      withConfirmation: confirmed,
                                      withResults: extensionReportURL!,
                                      settings: settings)
    }

    func testExtension(_ extensionPath: String,
                       command: String,
                       testcase: String) -> Bool {
        compiler.setBuild(forRelease: false,
                          forTesting: false)
        compiler.settings = settings
        return compiler.launchWith(inTestStage: extensionPath,
                                   command: command,
                                   testCase: testcase)
    }

    // == reading/writing ==

    private final func readProject(_ fileWrapper: FileWrapper, fileType: IFFileType) throws {
        // Check we have a directory... Inform projects are bundle directories.
        if !fileWrapper.isDirectory {
            throw CocoaError(.fileReadUnknown)
        }

        // Create an object to represent the bundle files
        projectFile = IFProjectFile(fileWrapper: fileWrapper)

        projectFileType = fileType

        // Create materials folder, if necessary
        createMaterials()

        // Turn the source directory into NSTextStorages
        guard let projectFile, let sourceDir = projectFile.sourceDirectory else {
            self.projectFile = nil

            throw CocoaError(.fileReadUnknown)
        }

        sourceTexts.read(sourceDirectory: sourceDir, undoManager: undoManager)

        // Refresh the settings, or create them as required
        _settings = projectFile.settings ?? IFCompilerSettings()

        // Load the notes (if present)
        notes = projectFile.loadNotes

        // Work out which test cases we have
        refreshTestCases()

        // Load the skein files (if present)
        loadSkeins(fileType: fileType)

        // Load the watchpoints file (if present)
        watchExpressions = projectFile.loadWatchpoints ?? NSMutableArray()

        // Load the breakpoints file (if present)
        breakpoints = projectFile.loadBreakpoints ?? NSMutableArray()

        // The Settings page shows the settings it was given, so it's told of the new ones
        NotificationCenter.default.post(name: .IFProjectSettingsReplaced, object: self)
    }

    nonisolated public override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        // The document isn't read concurrently, so NSDocument reads it on the main thread, where the wrapper is kept
        nonisolated(unsafe) let fileWrapper = fileWrapper
        try MainActor.assumeIsolated {
            documentFileWrapper = fileWrapper

            let fileType = IFProjectTypes.fileType(from: typeName)
            switch fileType {
            // Inform project file
            case .inform7Project, .inform7ExtensionProject:
                try readProject(fileWrapper, fileType: fileType)

            // Unknown
            default:
                throw CocoaError(.fileReadUnknown)
            }
        }
    }

    @discardableResult
    private final func writeBegin() -> Bool {
        // Clean out any files that we aren't using any more, if set in the preferences
        if preferences.cleanProjectOnClose {
            cleanOutUnnecessaryFiles(false)
        }

        return true
    }

    /// The project's file wrapper; a new, empty one when none is set
    private final var documentFileWrapper: FileWrapper {
        get {
            if let documentFileWrapper = _documentFileWrapper {
                return documentFileWrapper
            }
            let documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
            _documentFileWrapper = documentFileWrapper
            return documentFileWrapper
        }
        set {
            _documentFileWrapper = newValue
        }
    }

    private final func writeProject() -> FileWrapper {
        writeBegin()

        // Create new 'project file', based on the document's file wrapper
        projectFile = IFProjectFile(fileWrapper: documentFileWrapper)
        let source = projectFile?.sourceDirectory

        sourceTexts.write(into: source)

        // Replace the current source directory with the new source directory files
        projectFile?.replaceSourceDirectoryWrapper(source)

        // Write the Notes file
        projectFile?.writeNotes(notes.flatMap {
            $0.rtf(from: NSRange(location: 0, length: $0.length),
                   documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        })

        // Write the Skein file
        projectFile?.write(skeins as! [IFSkein], isExtensionProject: isExtensionProject)

        // Write the Watchpoints file
        projectFile?.writeWatchpoints(Array(watchExpressions))

        // Write the Breakpoints file
        projectFile?.writeBreakpoints(Array(breakpoints))

        // Setup the settings
        projectFile?.settings = settings

        if let source {
            documentFileWrapper.addFileWrapper(source)
        }

        return documentFileWrapper
    }

    public override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        switch IFProjectTypes.fileType(from: typeName) {
        // Inform project file
        case .inform7Project, .inform7ExtensionProject:
            return writeProject()

        // Unknown
        default:
            preconditionFailure("Unknown typeName of \(typeName)")
        }
    }

    // == General housekeeping ==
    public override func makeWindowControllers() {
        let aController = IFProjectController()
        addWindowController(aController)
    }

    // == Document info ==
    var settings: IFCompilerSettings {
        return _settings
    }

    func storage(forFile sourceFile: String?) -> NSTextStorage? {
        return sourceTexts.text(forFile: sourceFile, inProjectAt: fileURL, undoManager: undoManager)
    }

    var sourceFiles: [String: NSTextStorage]? {
        return sourceTexts.texts
    }

    func reloadIndexDirectory() {
        // Get a new index wrapper
        var indexWrapper: FileWrapper? = nil

        if let indexURL = indexDirectoryURL, FileManager.default.fileExists(atPath: indexURL.path) {
            indexWrapper = try? FileWrapper(url: indexURL,
                                            options: [])
            indexWrapper?.preferredFilename = "Index"
        }

        // Replace the old index wrapper
        projectFile?.replaceIndexDirectoryWrapper(indexWrapper)
    }

    func reloadDirectory() {
        // Get a new wrapper
        var wrapper: FileWrapper? = nil

        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            wrapper = try? FileWrapper(url: fileURL,
                                       options: .immediate)
        }

        // Replace the old build wrapper
        projectFile?.replace(wrapper)
    }

    func reloadSourceDirectory() {
        // Get a new wrapper
        var wrapper: FileWrapper? = nil

        if let sourceURL = sourceDirectoryURL, FileManager.default.fileExists(atPath: sourceURL.path) {
            wrapper = try? FileWrapper(url: sourceURL,
                                       options: [])
            wrapper?.preferredFilename = "Source"
        }

        // Replace the old build wrapper
        projectFile?.replaceSourceDirectoryWrapper(wrapper)
    }

    // MARK: - Cleaning

    private final func cleanOutUnnecessaryFiles(_ alsoCleanIndex: Bool) {
        projectFile?.cleanOutUnnecessaryFiles(alsoCleanIndex: alsoCleanIndex)
    }

    /// Deletes the files in a project's Build folder, and its Temp folder, and if asked the files in its Index folder,
    /// as the project file's cleanOutUnnecessaryFiles does with its file wrappers
    private static func cleanOutUnnecessaryFiles(at projectURL: URL, alsoCleanIndex: Bool) {
        let fileManager = FileManager.default

        func deleteFiles(in folder: String) {
            let folderURL = projectURL.appendingPathComponent(folder)
            for file in (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? [] {
                try? fileManager.removeItem(at: file)
            }
        }

        deleteFiles(in: "Build")
        try? fileManager.removeItem(at: projectURL.appendingPathComponent("Temp"))
        if alsoCleanIndex {
            deleteFiles(in: "Index")
        }
    }

    var isExtensionProject: Bool {
        return projectFileType == .inform7ExtensionProject
    }

    @discardableResult
    private final func copyProjectExtensionSourceToMaterialsExtensions() -> Bool {
        // Only relevant for extension projects
        if !isExtensionProject {
            return false
        }

        if let sourceDirectoryURL {
            var title: NSString? = nil
            var author: NSString? = nil
            var version: NSString? = nil

            let sourceExtensionFileURL = sourceDirectoryURL.appendingPathComponent("extension.i7x")

            // Extract title and author from sourceExtensionFileURL
            let mgr = IFExtensionsManager.sharedNaturalInform
            let gotInfo = mgr.info(forNaturalInformExtension: sourceExtensionFileURL.path,
                                   author: &author,
                                   title: &title,
                                   version: &version)
            if gotInfo == .success, let author, let title, let materialsURL = materialsDirectoryURL {
                let extensionsURL = materialsURL.appendingPathComponent("Extensions")
                let authorURL     = extensionsURL.appendingPathComponent(author as String)
                var fileURL       = authorURL.appendingPathComponent(title as String)
                fileURL           = fileURL.appendingPathExtension("i7x")

                // Read source data
                if let data = try? Data(contentsOf: sourceExtensionFileURL) {
                    // Create intermediate directories
                    try? FileManager.default.createDirectory(at: authorURL,
                                                             withIntermediateDirectories: true,
                                                             attributes: nil)
                    // Write to destination path
                    return (try? data.write(to: fileURL,
                                            options: [])) != nil
                }
            }
        }
        return false
    }

    // Extension project compilation problems need redirecting back to extension.i7x source, not story.ni
    func redirectLinks(toExtensionSourceCode link: [Any]) -> [Any] {
        return extensionTestCases.redirectLinks(toExtensionSourceCode: link,
                                                inExtensionProject: projectFileType == .inform7ExtensionProject)
    }

    // Save iFiction
    @objc(saveIFictionWithWindow:)
    func saveIFiction(with window: NSWindow) {
        // Work out where the iFiction file should be
        let iFictionURL = metadataURL

        // Prompt the user to save the iFiction file if it exists
        if let iFictionURL, FileManager.default.fileExists(atPath: iFictionURL.path) {
            // Setup a save panel
            let panel = NSSavePanel()

            panel.accessoryView = nil
            panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["iFiction"])
            panel.canSelectHiddenExtension = true
            panel.prompt = IFUtility.localizedString("Save iFiction record")
            panel.treatsFilePackagesAsDirectories = false
            panel.directoryURL = fileURL?.deletingLastPathComponent()
            panel.nameFieldStringValue = ((fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

            // Show it
            panel.beginSheetModal(for: window) { result in
                // Copy the file to the specified path
                if result == .OK, let url = panel.url {
                    do {
                        try self.saveIFiction(to: url, hidingExtension: panel.isExtensionHidden)
                    } catch {
                        panel.close()
                        NSAlert(error: error).beginSheetModal(for: window)
                    }
                }
            }
        } else {
            // Oops, failed to generate an iFiction record
            IFUtility.runAlertWarning(window,
                                      title: "The compiler failed to produce an iFiction record",
                                      informativeText: IFUtility.localizedString("The compiler failed to create an iFiction record; check the errors page to see why."))
        }
    }

    @objc(saveIFictionToURL:hidingExtension:error:)
    func saveIFiction(to url: URL, hidingExtension hideExtension: Bool) throws {
        guard let iFictionURL = metadataURL else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try copyFile(at: iFictionURL, over: url, hidingExtension: hideExtension)
    }

    /// Copies a file to one the user chose in a save panel, which has asked whether to replace a file that's there
    private final func copyFile(at source: URL, over destination: URL, hidingExtension hideExtension: Bool) throws {
        let filepath = (destination.path as NSString).resolvingSymlinksInPath

        // Remove the existing file, then copy
        if FileManager.default.fileExists(atPath: filepath) {
            try FileManager.default.removeItem(atPath: filepath)
        }
        try FileManager.default.copyItem(atPath: source.path,
                                         toPath: filepath)

        // Hide the file extension if the user has requested it
        if var attributes = try? FileManager.default.attributesOfItem(atPath: filepath) {
            attributes[.extensionHidden] = hideExtension
            try? FileManager.default.setAttributes(attributes,
                                                   ofItemAtPath: filepath)
        }
    }

    func saveDocumentWithoutUserInteraction() {
        // Note: We don't call [self saveDocument: self]; because from 10.5 and upwards this performs
        // checks to see if the file has changed since last opened or saved, and shows a user dialog if so.
        // This is a problem for our application because the compiler output adds folders / files to the
        // saved bundle, making it look like it's changed.

        if let fileURL, let fileType {
            save(to: fileURL, ofType: fileType, for: .saveOperation) { errorOrNil in
                if let errorOrNil {
                    NSLog("Saving project %@ failed. Error: %@", self, errorOrNil as NSError)
                }
            }
        }
    }

    func openMaterials() {
        // Work out where the materials folder is located
        let materialsPath = materialsDirectoryURL?.path

        // Create materials folder if necessary, in a sandbox friendly way, with an icon
        createMaterials()

        // Open the folder if it exists
        var isDir: ObjCBool = false
        if let materialsPath, FileManager.default.fileExists(atPath: materialsPath,
                                                             isDirectory: &isDir) {
            if !isDir.boolValue {
                // Odd; the materials folder is a file. We open the containing path so the user can see this and correct it if they like
                NSWorkspace.shared.open(URL(fileURLWithPath: (materialsPath as NSString).deletingLastPathComponent))
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: materialsPath))
            }
        }
    }

    @objc(saveCompilerOutputWithWindow:)
    func saveCompilerOutput(with window: NSWindow) {
        // Setup a save panel
        let panel = NSSavePanel()

        panel.accessoryView = nil
        panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: [(compiler.outputFile as NSString).pathExtension])
        panel.canSelectHiddenExtension = true
        panel.prompt = IFUtility.localizedString("Save")
        panel.treatsFilePackagesAsDirectories = false
        panel.nameFieldStringValue = ((fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

        // Show it
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let whereToSave = panel.url?.path {
                // Remove existing file then copy
                try? FileManager.default.removeItem(atPath: whereToSave)
                do {
                    try FileManager.default.copyItem(atPath: self.compiler.outputFile,
                                                     toPath: whereToSave)
                } catch {
                    panel.close()

                    // File failed to save
                    // Report that a file failed to save
                    let alert = NSAlert()
                    let contents = String(format: IFUtility.localizedString("An error was encountered while trying to save the file '%@'"),
                                          (whereToSave as NSString).lastPathComponent)

                    alert.addButton(withTitle: IFUtility.localizedString("Retry"))
                    alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                    alert.messageText = IFUtility.localizedString("Unable to save file")
                    alert.informativeText = contents
                    alert.alertStyle = .warning

                    alert.beginSheetModal(for: window) { returnCode in
                        if returnCode == .alertFirstButtonReturn {
                            // Try again, in the same window
                            RunLoop.current.perform(#selector(self.saveCompilerOutput(with:)),
                                                    target: self,
                                                    argument: window,
                                                    order: 128,
                                                    modes: [.default])
                        }
                    }
                    return
                }
            }
        }
    }

    private final func buildBlorbSetting() -> Bool {
        let outputSettings = settings.setting(for: IFI7OutputSettings.self) as? IFI7OutputSettings
        return outputSettings?.createBlorbForRelease ?? false
    }

    func prepareCompiler(forRelease release: Bool,
                         forTesting releaseForTesting: Bool,
                         refreshOnly onlyRefresh: Bool,
                         testCase: String?) -> IFCompiler? {
        // Set up the compiler
        let buildBlorb = release && buildBlorbSetting()

        let theCompiler = compiler
        theCompiler.setBuild(forRelease: release,
                             forTesting: releaseForTesting)
        theCompiler.settings = settings

        // Create <projectname>.materials folder, in a sandbox friendly way
        createMaterials()

        // If necessary, copy the extension from an extension project to <projectname>.materials/Extensions/Author/Extension.i7x
        copyProjectExtensionSourceToMaterialsExtensions()

        theCompiler.outputFile = buildOutputFileURL?.path
        theCompiler.inputFile = projectInputPathName
        theCompiler.directory = buildDirectoryURL?.path

        if onlyRefresh {
            theCompiler.addNaturalInformStage(usingTestCase: testCase)
            if !theCompiler.prepareForLaunch(withBlorbStage: false, testCase: testCase) {
                return nil
            }
        } else {
            if !theCompiler.prepareForLaunch(withBlorbStage: buildBlorb, testCase: testCase) {
                return nil
            }
        }

        return theCompiler
    }

    // MARK: - Importing skein information

    func skein(fromRecording path: String) -> IFSkein? {
        let lineFeed: unichar       = 0x0A
        let carriageReturn: unichar = 0x0D

        // Read the file
        guard let fileData = NSData(contentsOfFile: path),
              let fileString = NSString(data: fileData as Data,
                                        encoding: String.Encoding.utf8.rawValue) else {
            return nil
        }

        // Pull out the lines from the file
        var lineStart = 0
        var pos = 0
        let len = fileString.length

        // Maximum length of 500k characters
        if len > 500000 { return nil }

        var lines: [String] = []

        while pos < len {
            // Get the next character
            let lineChar = fileString.character(at: pos)

            // Check for a newline
            if lineChar == lineFeed || lineChar == carriageReturn {
                // Maximum line length of 50 characters
                if pos - lineStart > 50 { return nil }

                // Maximum 10,000 moves
                if lines.count >= 10000 { return nil }

                // Get the current line
                let thisLine = fileString.substring(with: NSRange(location: lineStart, length: pos - lineStart))
                lines.append(thisLine)

                // Deal with <CR><LF> and <LF><CR> sequences
                if pos + 1 < len {
                    if lineChar == carriageReturn && fileString.character(at: pos + 1) == lineFeed { pos += 1 }
                    else if lineChar == lineFeed && fileString.character(at: pos + 1) == carriageReturn { pos += 1 }
                }

                // Store the start of the next line
                lineStart = pos + 1
            }
            pos += 1
        }

        // The last line needn't end with a newline
        if lineStart < len {
            if len - lineStart > 50 { return nil }
            if lines.count >= 10000 { return nil }

            lines.append(fileString.substring(with: NSRange(location: lineStart, length: len - lineStart)))
        }

        // Must be at least one line in the file
        if lines.count < 1 { return nil }

        // Build the new skein
        let newSkein = IFSkein(project: self)

        newSkein.activeItem = newSkein.rootItem

        for line in lines {
            newSkein.inputCommand(line)
        }

        return newSkein
    }

    @objc(importIntoSkeinWithWindow:)
    func importIntoSkein(with window: NSWindow) {
        // We can currently import .rec files, .txt files, zoomSave packages and .skein files
        // In the case of .rec/.txt files, they must be <300k, be valid UTF-8 and have less than 10000 lines
        // of a length no more than 50 characters each. (Anything else probably isn't a recording)

        // Set up an open panel
        let importPanel = NSOpenPanel()

        importPanel.accessoryView = nil
        importPanel.canChooseFiles = true
        importPanel.canChooseDirectories = false
        importPanel.resolvesAliases = true
        importPanel.allowsMultipleSelection = false
        importPanel.title = IFUtility.localizedString("Choose a recording, skein or Zoom save game file")
        importPanel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["rec", "txt", "zoomSave", "skein"])

        // Display the panel
        importPanel.beginSheetModal(for: window) { result in
            if result == .OK, let path = importPanel.url?.path {
                let extn = (path as NSString).pathExtension.lowercased()

                var loadedSkein: IFSkein? = nil
                var loadError: String? = nil

                if extn == "txt" || extn == "rec" {
                    loadedSkein = self.skein(fromRecording: path)

                    loadError = IFUtility.localizedString("Recording Skein Load Failure", default: nil)
                } else if extn == "skein" {
                    let skein = IFSkein(project: self)

                    let parsed = (NSData(contentsOfFile: path) as Data?).map { skein.parseXmlData($0) } ?? false
                    loadedSkein = parsed ? skein : nil
                } else if extn == "zoomsave" {
                    let skein = IFSkein(project: self)

                    let skeinPath = (path as NSString).appendingPathComponent("Skein.skein")
                    let parsed = (NSData(contentsOfFile: skeinPath) as Data?).map { skein.parseXmlData($0) } ?? false
                    loadedSkein = parsed ? skein : nil
                }

                if let loadedSkein {
                    // Merge the new skein into the current skein
                    while loadedSkein.rootItem.children.count > 0 {
                        let child = loadedSkein.rootItem.children[0]
                        child.removeFromParent()

                        self._currentSkein?.rootItem.addChild(child)
                    }

                    self._currentSkein?.postChanged(withAnimate: false,
                                                    keepActiveVisible: false)
                } else {
                    if loadError == nil {
                        loadError = IFUtility.localizedString("Skein Load Failure", default: nil)
                    }

                    importPanel.close()
                    let alert = NSAlert()
                    alert.messageText = IFUtility.localizedString("Could not import skein")
                    alert.informativeText = loadError ?? ""
                    alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                    alert.beginSheetModal(for: window) { returnCode in
                        // do nothing.
                    }
                }
            }
        }
    }

    func exportExtension(_ window: NSWindow) {
        if isExtensionProject {
            // Save the project, without user interaction.
            save(self)

            // Set up an open panel
            let panel = NSSavePanel()

            panel.accessoryView = nil
            panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["i7x"])
            panel.canSelectHiddenExtension = true
            panel.prompt = IFUtility.localizedString("Export Extension (.i7x)")
            panel.treatsFilePackagesAsDirectories = false
            panel.directoryURL = fileURL?.deletingLastPathComponent()
            panel.nameFieldStringValue = ((fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

            // Show it
            panel.beginSheetModal(for: window) { result in
                // Copy the file to the specified path
                if result == .OK, let url = panel.url {
                    do {
                        try self.exportExtension(to: url, hidingExtension: panel.isExtensionHidden)
                    } catch {
                        panel.close()
                        NSAlert(error: error).beginSheetModal(for: window)
                    }
                }
            }
        }
    }

    @objc(exportExtensionToURL:hidingExtension:error:)
    func exportExtension(to url: URL, hidingExtension hideExtension: Bool) throws {
        guard let sourceExtensionFileURL = sourceDirectoryURL?.appendingPathComponent("extension.i7x") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try copyFile(at: sourceExtensionFileURL, over: url, hidingExtension: hideExtension)
    }
}
