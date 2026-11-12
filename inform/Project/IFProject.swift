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

    private final var projectSkeins: IFProjectSkeins!

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

        compiler                = IFCompiler()
        notes                   = NSTextStorage(string: "")
        materialsAccess         = nil
        extensionTestCases      = IFExtensionTestCases()
        inBuild                 = IFInBuild()
        preferences             = IFPreferences.shared

        watchExpressions        = NSMutableArray()
        breakpoints             = NSMutableArray()

        super.init()

        projectSkeins           = IFProjectSkeins(project: self)
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

    var metadataURL: URL? {
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
            let index = currentSkein.map { skeins.index(of: $0) } ?? NSNotFound
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

    var skeins: NSMutableArray {
        return projectSkeins.skeins
    }

    var currentSkein: IFSkein? {
        return projectSkeins.currentSkein
    }

    func selectSkein(_ index: Int32) {
        projectSkeins.selectSkein(index)
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
        projectSkeins.loadSkeins(from: projectFile,
                                 isExtensionProject: fileType == .inform7ExtensionProject)

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

    @objc(saveIFictionToURL:hidingExtension:error:)
    func saveIFiction(to url: URL, hidingExtension hideExtension: Bool) throws {
        guard let iFictionURL = metadataURL else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try copyFile(at: iFictionURL, over: url, hidingExtension: hideExtension)
    }

    @objc(saveCompilerOutputToURL:hidingExtension:error:)
    func saveCompilerOutput(to url: URL, hidingExtension hideExtension: Bool) throws {
        try copyFile(at: URL(fileURLWithPath: compiler.outputFile), over: url, hidingExtension: hideExtension)
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

    @objc(importIntoCurrentSkeinFromFile:)
    func importIntoCurrentSkein(fromFile path: String) -> String? {
        return projectSkeins.importIntoCurrentSkein(fromFile: path)
    }

    @objc(exportExtensionToURL:hidingExtension:error:)
    func exportExtension(to url: URL, hidingExtension hideExtension: Bool) throws {
        guard let sourceExtensionFileURL = sourceDirectoryURL?.appendingPathComponent("extension.i7x") else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try copyFile(at: sourceExtensionFileURL, over: url, hidingExtension: hideExtension)
    }
}
