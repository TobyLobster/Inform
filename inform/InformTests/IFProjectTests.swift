//
//  IFProjectTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFProjectTests.never-written")!
    }

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

@MainActor
final class IFProjectTests: XCTestCase {

    private let lines = ["\"Line Endings\" by Inform.", "", "The Kitchen is a room."]

    /// The text of a source file, as Inform shows it once the file is opened on its own.
    /// (The file's document unregisters its text when it goes.)
    private func openedSourceFile(_ contents: String) throws -> String {
        let file = IFSingleFile()
        try file.read(from: Data(contents.utf8), ofType: "org.inform-fiction.source.inform7")
        return file.storage.string
    }

    /// The text of a project's source file, as Inform shows it once the project is opened.
    private func openedProject(_ contents: String) throws -> String {
        // The project is made in a temporary folder, as opening it makes a materials folder beside it
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let projectURL = folder.appendingPathComponent("Line Endings.inform")
        let sourceURL = projectURL.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: sourceURL.appendingPathComponent("story.ni"))

        let project = try IFProject(contentsOf: projectURL, ofType: "org.inform-fiction.project")
        let storage = try XCTUnwrap(project.sourceFiles?["story.ni"])
        IFSyntaxManager.unregisterTextStorage(storage)
        return storage.string
    }

    /// A file with Windows line endings opens with one line break per line, not two.
    func testWindowsLineEndings() throws {
        let contents = lines.joined(separator: "\r\n")
        XCTAssertEqual(try openedProject(contents), lines.joined(separator: "\n"))
        XCTAssertEqual(try openedSourceFile(contents), lines.joined(separator: "\n"))
    }

    func testOldMacLineEndings() throws {
        let contents = lines.joined(separator: "\r")
        XCTAssertEqual(try openedProject(contents), lines.joined(separator: "\n"))
        XCTAssertEqual(try openedSourceFile(contents), lines.joined(separator: "\n"))
    }

    func testUnixLineEndings() throws {
        let contents = lines.joined(separator: "\n")
        XCTAssertEqual(try openedProject(contents), contents)
        XCTAssertEqual(try openedSourceFile(contents), contents)
    }

    // MARK: - Helpers

    private let projectType = "org.inform-fiction.project"
    private let extensionProjectType = "org.inform-fiction.xproject"

    private let extensionText = "Lamplighting by Jane Doe begins here.\n\nA lamp is a kind of thing.\n\n"
        + "Lamplighting ends here.\n\n---- DOCUMENTATION ----\n\nLamps can be lit.\n\n"
        + "Example: * Lighthouse - A lamp at the top of a tower.\n\n\t*: \"Lighthouse\"\n\n"
        + "\tInclude Lamplighting by Jane Doe.\n\n"
        + "\tThe Lamp Room is a room. The great lamp is a lamp in the Lamp Room.\n\n"
        + "\tTest me with \"look / x lamp\".\n\n\n"
        + "Example: ** Café - A lamp in a café.\n\n\t*: \"Café\"\n\n"
        + "\tInclude Lamplighting by Jane Doe.\n\n"
        + "\tThe Café is a room.\n\n"
        + "\tTest me with \"look\".\n\n\n"

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A project in a new folder, with these files in its Source folder
    private func makeProject(named name: String = "Lighthouse.inform", source: [String: Data]) throws -> URL {
        let project = try makeFolder().appendingPathComponent(name)
        let sourceFolder = project.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        for (filename, contents) in source {
            try contents.write(to: sourceFolder.appendingPathComponent(filename))
        }
        return project
    }

    /// Opens a project as the app does. It's closed when the test ends.
    private func open(_ url: URL, ofType typeName: String = "org.inform-fiction.project") throws -> IFProject {
        let project = try IFProject(contentsOf: url, ofType: typeName)
        addTeardownBlock { project.close() }
        return project
    }

    /// Opens an extension project in a new folder, whose documentation has two examples
    private func openExtensionProject() throws -> IFProject {
        let url = try makeProject(named: "Lamplighting.i7xp", source: ["extension.i7x": Data(extensionText.utf8)])
        return try open(url, ofType: extensionProjectType)
    }

    /// The URL of something in a project's folder
    private func fileURL(_ path: String, in project: IFProject) throws -> URL {
        return try XCTUnwrap(project.fileURL).appendingPathComponent(path)
    }

    private func rtf(_ text: String) throws -> Data {
        let string = NSAttributedString(string: text)
        return try string.data(from: NSRange(location: 0, length: string.length),
                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private func text(_ wrapper: FileWrapper?) -> String? {
        return wrapper?.regularFileContents.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The commands of a skein's first line of play, without its root
    private func commands(_ skein: IFSkein) -> [String] {
        var commands: [String] = []
        var item = skein.rootItem
        while let child = item.children.first {
            commands.append(child.command)
            item = child
        }
        return commands
    }

    /// Saves skeins in a project's folder, each with a line of play
    private func saveSkeins(_ lines: [[String]], in url: URL, isExtensionProject: Bool) throws {
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: try FileWrapper(url: url, options: .immediate)))
        let skeins = lines.map { line in
            let skein = IFSkein(project: nil)
            var item = skein.rootItem
            for command in line {
                item = item.addChild(IFSkeinItem(skein: skein, command: command))
            }
            return skein
        }
        projectFile.write(skeins, isExtensionProject: isExtensionProject)
        projectFile.filename = url.path
        XCTAssertTrue(projectFile.write)
    }

    private func assertIsUnknownFileError(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain, file: file, line: line)
        XCTAssertEqual((error as NSError).code, NSFileReadUnknownError, file: file, line: line)
    }

    // MARK: - A new project

    func testANewProject() {
        let project = IFProject()

        XCTAssertNil(project.sourceFiles)
        XCTAssertNil(project.testCases)
        XCTAssertNil(project.mainSourceFile)
        XCTAssertNil(project.mainSourcePathName)
        XCTAssertEqual(project.projectFileType, .unknown)
        XCTAssertFalse(project.isExtensionProject)
        XCTAssertNotNil(project.currentSkein)
        XCTAssertEqual(project.skeins.count, 0)
        XCTAssertEqual(project.initialSelectionRange, NSRange(location: 0, length: 0))
        XCTAssertTrue(project.useNewExtensions)
    }

    func testANewProjectHasNoURLs() {
        let project = IFProject()

        XCTAssertNil(project.buildDirectoryURL)
        XCTAssertNil(project.materialsDirectoryURL)
        XCTAssertNil(project.mainSourceFileURL)
        XCTAssertNil(project.buildOutputFileURL)
        XCTAssertNil(project.settingsFileURL)
        XCTAssertNil(project.indexDirectoryURL)
        XCTAssertNil(project.extensionReportURL)
        XCTAssertNil(project.path(forSourceFile: "story.ni"))
        XCTAssertNil(project.path(forSourceFile: nil))
    }

    func testGivesTheStandardPathOfAnAbsolutePath() {
        XCTAssertEqual(IFProject().path(forSourceFile: "/Library/./Fonts//Sample.ttf"), "/Library/Fonts/Sample.ttf")
    }

    // MARK: - Reading

    func testReadsAProject() throws {
        let project = try open(makeProject(source: ["story.ni": Data("\"Lighthouse\"\n".utf8)]))

        XCTAssertEqual(project.projectFileType, .inform7Project)
        XCTAssertFalse(project.isExtensionProject)
        XCTAssertEqual(project.sourceFiles?.keys.sorted(), ["story.ni"])
        XCTAssertEqual(project.sourceFiles?["story.ni"]?.string, "\"Lighthouse\"\n")
        XCTAssertEqual(project.mainSourceFile, "story.ni")
        XCTAssertEqual(project.mainSourcePathName, try fileURL("Source/story.ni", in: project).path)
        XCTAssertEqual(project.testCases?.count, 0)
        XCTAssertEqual(project.skeins.count, 1)
        XCTAssertIdentical(project.currentSkein, project.skeins.firstObject as? IFSkein)
    }

    func testGivesAProjectsURLs() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let folder = try XCTUnwrap(project.fileURL).deletingLastPathComponent()

        XCTAssertEqual(project.buildDirectoryURL?.path, try fileURL("Build", in: project).path)
        XCTAssertEqual(project.materialsDirectoryURL?.path, folder.appendingPathComponent("Lighthouse.materials").path)
        XCTAssertEqual(project.mainSourceFileURL?.path, try fileURL("Source/story.ni", in: project).path)
        XCTAssertEqual(project.buildOutputFileURL?.path,
                       try fileURL("Build/output." + project.settings.fileExtension, in: project).path)
        XCTAssertEqual(project.settingsFileURL?.path, try fileURL("Settings.plist", in: project).path)
        XCTAssertEqual(project.indexDirectoryURL?.path, try fileURL("Index", in: project).path)
        XCTAssertEqual(project.extensionReportURL?.path, try fileURL("Build/Inbuild.html", in: project).path)
        XCTAssertEqual(project.path(forSourceFile: "Other.ni"), try fileURL("Source/Other.ni", in: project).path)
    }

    func testMakesAProjectsMaterialsFolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let materials = try XCTUnwrap(project.materialsDirectoryURL)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: materials.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testChoosesTheStoryAsTheMainSourceFile() throws {
        let project = try open(makeProject(source: ["story.ni": Data(), "Notes.txt": Data(), "Map.rtf": rtf("Map")]))
        XCTAssertEqual(project.mainSourceFile, "story.ni")
    }

    func testChoosesAnInform6SourceFileAsTheMainSourceFile() throws {
        XCTAssertEqual(try open(makeProject(source: ["game.inf": Data()])).mainSourceFile, "game.inf")
    }

    func testChoosesTheLastStoryInOrderOfName() throws {
        let names = ["a.ni", "b.i7", "c.inf", "d.ni", "e.i7", "f.inf", "story.ni", "z.txt"]
        let project = try open(makeProject(source: Dictionary(uniqueKeysWithValues: names.map { ($0, Data()) })))
        XCTAssertEqual(project.mainSourceFile, "story.ni")
    }

    func testHasNoMainSourceFileWithoutAStory() throws {
        // An extension isn't a project's main source file
        let project = try open(makeProject(source: ["Notes.txt": Data(), "extension.i7x": Data()]))

        XCTAssertNil(project.mainSourceFile)
        XCTAssertNil(project.mainSourceFileURL)
        XCTAssertNil(project.mainSourcePathName)
    }

    func testReadsAProjectsSettings() throws {
        let projectFile = IFProjectFile(emptyProject: ())
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 8
        projectFile.settings = settings
        projectFile.addSourceFile("story.ni", withContents: Data())
        let url = try makeFolder().appendingPathComponent("Lighthouse.inform")
        projectFile.filename = url.path
        XCTAssertTrue(projectFile.write)

        let project = try open(url)

        XCTAssertEqual(project.settings.zcodeVersion, 8)
        XCTAssertEqual(project.buildOutputFileURL?.pathExtension, "z8")
    }

    func testGivesAProjectWithoutSettingsNewOnes() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        XCTAssertEqual(project.settings.zcodeVersion, IFCompilerSettings().zcodeVersion)
    }

    func testReadsASourceFileThatIsntUTF8AsLatin1() throws {
        // "Café" in Latin-1
        let project = try open(makeProject(source: ["story.ni": Data([0x43, 0x61, 0x66, 0xE9])]))
        XCTAssertEqual(project.sourceFiles?["story.ni"]?.string, "Café")
    }

    func testReadsAnInform6SourceFileAsLatin1() throws {
        let project = try open(makeProject(source: ["game.inf": Data("Café".utf8)]))
        XCTAssertEqual(project.sourceFiles?["game.inf"]?.string, "CafÃ©")
    }

    func testReadsAnRTFSourceFile() throws {
        let project = try open(makeProject(source: ["story.ni": Data(), "Map.rtf": rtf("Map")]))
        XCTAssertEqual(project.sourceFiles?["Map.rtf"]?.string, "Map")
    }

    func testReadsOnlyTheFilesInTheSourceFolder() throws {
        let url = try makeProject(source: ["story.ni": Data()])
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Source/Folder"),
                                                withIntermediateDirectories: true)

        XCTAssertEqual(try open(url).sourceFiles?.keys.sorted(), ["story.ni"])
    }

    func testCantReadAProjectThatIsntAFolder() {
        XCTAssertThrowsError(try IFProject().read(from: FileWrapper(regularFileWithContents: Data()),
                                                  ofType: projectType)) { assertIsUnknownFileError($0) }
    }

    func testCantReadAProjectWhoseSourceIsntAFolder() {
        let wrapper = FileWrapper(directoryWithFileWrappers: ["Source": FileWrapper(regularFileWithContents: Data())])
        XCTAssertThrowsError(try IFProject().read(from: wrapper, ofType: projectType)) { assertIsUnknownFileError($0) }
    }

    func testKeepsItsSettingsWhenItCantReadAProject() {
        let project = IFProject()
        let settings = project.settings
        let wrapper = FileWrapper(directoryWithFileWrappers: ["Source": FileWrapper(regularFileWithContents: Data())])

        XCTAssertThrowsError(try project.read(from: wrapper, ofType: projectType))

        // (Read with KVC, as Swift takes the settings to be there)
        XCTAssertIdentical(project.value(forKey: "settings") as AnyObject?, settings)
    }

    func testCantReadOtherDocumentTypes() {
        let wrapper = FileWrapper(directoryWithFileWrappers: ["Source": FileWrapper(directoryWithFileWrappers: [:])])
        for typeName in ["org.inform-fiction.source.inform7", "org.inform-fiction.source.inform6",
                         "org.inform-fiction.inform7.extension", ""] {
            XCTAssertThrowsError(try IFProject().read(from: wrapper, ofType: typeName), typeName) {
                assertIsUnknownFileError($0)
            }
        }
    }

    // MARK: - Writing

    func testWritesItsSourceFiles() throws {
        let project = try open(makeProject(source: ["story.ni": Data("Old".utf8), "Map.rtf": rtf("Map")]))
        let story = try XCTUnwrap(project.sourceFiles?["story.ni"])
        story.replaceCharacters(in: NSRange(location: 0, length: story.length), with: "New café")

        let source = try project.fileWrapper(ofType: projectType).fileWrappers?["Source"]

        XCTAssertEqual(source?.fileWrappers?.keys.sorted(), ["Map.rtf", "story.ni"])
        XCTAssertEqual(text(source?.fileWrappers?["story.ni"]), "New café")
        let map = try XCTUnwrap(source?.fileWrappers?["Map.rtf"]?.regularFileContents)
        XCTAssertEqual(NSAttributedString(rtf: map, documentAttributes: nil)?.string, "Map")
    }

    func testWritesBackWhatItDoesntShow() throws {
        // Nothing shows a project's notes, watchpoints or breakpoints, but they're kept
        let projectFile = IFProjectFile(emptyProject: ())
        projectFile.addSourceFile("story.ni", withContents: Data())
        projectFile.writeNotes(try rtf("Remember the lamp"))
        projectFile.writeWatchpoints(["score"])
        projectFile.writeBreakpoints([[3, "story.ni"]])
        let url = try makeFolder().appendingPathComponent("Lighthouse.inform")
        projectFile.filename = url.path
        XCTAssertTrue(projectFile.write)

        let written = try open(url).fileWrapper(ofType: projectType)

        let reread = try XCTUnwrap(IFProjectFile(fileWrapper: written))
        XCTAssertEqual(reread.loadNotes?.string, "Remember the lamp")
        XCTAssertEqual(reread.loadWatchpoints, NSMutableArray(array: ["score"]))
        XCTAssertEqual(reread.loadBreakpoints, NSMutableArray(array: [[3, "story.ni"]]))
        XCTAssertEqual(reread.loadUUID, projectFile.loadUUID)
        XCTAssertNotNil(reread.settings)
        XCTAssertNotNil(written.fileWrappers?["Skein.skein"])
    }

    /// The save panel has asked whether to replace the file
    func testSavesTheIFictionRecordOverAFileThatsThere() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        try Data("<ifindex/>".utf8).write(to: fileURL("Metadata.ifiction", in: project))
        let copy = try makeFolder().appendingPathComponent("Lighthouse.iFiction")
        try Data("Old".utf8).write(to: copy)

        try project.saveIFiction(to: copy, hidingExtension: false)

        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "<ifindex/>")
    }

    func testSavingTheIFictionRecordSaysWhenThereIsNone() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let copy = try makeFolder().appendingPathComponent("Lighthouse.iFiction")

        XCTAssertThrowsError(try project.saveIFiction(to: copy, hidingExtension: false))
    }

    func testExportsAnExtensionOverAFileThatsThere() throws {
        let project = try openExtensionProject()
        let copy = try makeFolder().appendingPathComponent("Lamplighting.i7x")
        try Data("Old".utf8).write(to: copy)

        try project.exportExtension(to: copy, hidingExtension: false)

        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), extensionText)
    }

    func testExportingAnExtensionSaysWhenItCant() throws {
        let project = try openExtensionProject()
        let copy = try makeFolder().appendingPathComponent("Missing/Lamplighting.i7x")

        XCTAssertThrowsError(try project.exportExtension(to: copy, hidingExtension: false))
    }

    func testSavesAProjectElsewhere() throws {
        let project = try open(makeProject(source: ["story.ni": Data("Old".utf8)]))
        let story = try XCTUnwrap(project.sourceFiles?["story.ni"])
        story.replaceCharacters(in: NSRange(location: 0, length: story.length), with: "New")
        let copy = try makeFolder().appendingPathComponent("Copy.inform")

        try project.write(to: copy, ofType: projectType)

        XCTAssertEqual(try String(contentsOf: copy.appendingPathComponent("Source/story.ni"), encoding: .utf8), "New")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copy.appendingPathComponent("uuid.txt").path))
    }

    // MARK: - Source text

    func testGivesTheTextOfItsSourceFiles() throws {
        let project = try open(makeProject(source: ["story.ni": Data("Story".utf8)]))
        let story = try XCTUnwrap(project.sourceFiles?["story.ni"])

        XCTAssertIdentical(project.storage(forFile: "story.ni"), story)
        XCTAssertIdentical(project.storage(forFile: project.mainSourcePathName), story)
        XCTAssertNil(project.storage(forFile: "Missing.ni"))
    }

    func testGivesNoTextForNoFile() throws {
        // As for a project without a story file
        let project = try open(makeProject(source: ["story.ni": Data()]))
        XCTAssertNil(project.storage(forFile: nil))
    }

    func testGivesTheTextOfASourceFileThatHasGoneFromDisk() throws {
        let project = try open(makeProject(source: ["story.ni": Data("Story".utf8)]))
        try FileManager.default.removeItem(at: fileURL("Source/story.ni", in: project))

        let story = try XCTUnwrap(project.sourceFiles?["story.ni"])
        XCTAssertIdentical(project.storage(forFile: "story.ni"), story)
    }

    func testGivesNoTextForAFileOutsideItsSourceFolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let outside = try XCTUnwrap(project.fileURL).deletingLastPathComponent().appendingPathComponent("Outside.ni")
        try Data("Outside".utf8).write(to: outside)
        try Data().write(to: fileURL("Inside.ni", in: project))

        XCTAssertNil(project.storage(forFile: outside.path))
        XCTAssertNil(project.storage(forFile: try fileURL("Inside.ni", in: project).path))
    }

    func testGivesNoTextForAFileAddedToItsSourceFolder() throws {
        // Only the files read with the project
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let added = try fileURL("Source/Added.ni", in: project)
        try Data("Added".utf8).write(to: added)

        XCTAssertNil(project.storage(forFile: added.path))
        XCTAssertNil(project.storage(forFile: "Added.ni"))
    }

    func testReadsTheTextOfAFileInASourceSubfolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let folder = try fileURL("Source/Folder", in: project)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // "Café" in Latin-1
        try Data([0x43, 0x61, 0x66, 0xE9]).write(to: folder.appendingPathComponent("Other.ni"))

        let storage = try XCTUnwrap(project.storage(forFile: folder.appendingPathComponent("Other.ni").path))
        IFSyntaxManager.unregisterTextStorage(storage)

        XCTAssertEqual(storage.string, "Café")
        XCTAssertNil(project.sourceFiles?["Other.ni"])
    }

    // MARK: - Reloading

    func testReloadsItsSourceFolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        try FileManager.default.removeItem(at: fileURL("Source/story.ni", in: project))
        try Data().write(to: fileURL("Source/game.inf", in: project))
        XCTAssertEqual(project.mainSourceFile, "story.ni")

        project.reloadSourceDirectory()

        XCTAssertEqual(project.mainSourceFile, "game.inf")
    }

    func testReloadsItsFolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        try FileManager.default.removeItem(at: fileURL("Source/story.ni", in: project))
        try Data().write(to: fileURL("Source/game.inf", in: project))

        project.reloadDirectory()

        XCTAssertEqual(project.mainSourceFile, "game.inf")
    }

    func testReloadsItsIndexFolder() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let index = try fileURL("Index", in: project)
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        try Data("<html/>".utf8).write(to: index.appendingPathComponent("Welcome.html"))

        project.reloadIndexDirectory()
        XCTAssertEqual(try project.fileWrapper(ofType: projectType).fileWrappers?["Index"]?.fileWrappers?.keys.sorted(),
                       ["Welcome.html"])

        try FileManager.default.removeItem(at: index)
        project.reloadIndexDirectory()
        XCTAssertNil(try project.fileWrapper(ofType: projectType).fileWrappers?["Index"])
    }

    // MARK: - Closing

    /// Opens a project with files in its Build, Temp and Index folders, which cleans by preferences kept in memory
    private func openProjectWithBuildFiles(cleanOnClose: Bool, alsoCleanIndex: Bool) throws -> (IFProject, URL) {
        let url = try makeProject(source: ["story.ni": Data("The Kitchen is a room.".utf8)])
        for file in ["Build/output.ulx", "Build/Problems.html", "Temp/scratch", "Index/Welcome.html",
                     "Index/Details/1.html"] {
            let fileURL = url.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data("x".utf8).write(to: fileURL)
        }
        let project = try open(url)
        let stored = ["cleanProjectOnClose": cleanOnClose, "alsoCleanIndexFiles": alsoCleanIndex]
        project.preferences = IFPreferences(userDefaults: MemoryDefaults([IFPreferencesDefault: stored]))
        return (project, url)
    }

    /// The names of the files in a folder of a project, or nil if it has no such folder
    private func files(in folder: String, of url: URL) -> [String]? {
        return try? FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent(folder).path).sorted()
    }

    /// As the preference says, closing a project deletes its build files, though it was saved before they were made
    func testClosingCleansOutTheBuildFiles() throws {
        let (project, url) = try openProjectWithBuildFiles(cleanOnClose: true, alsoCleanIndex: false)

        project.close()

        XCTAssertEqual(files(in: "Build", of: url), [])
        XCTAssertNil(files(in: "Temp", of: url))
        XCTAssertEqual(files(in: "Index", of: url), ["Details", "Welcome.html"])
        XCTAssertEqual(files(in: "Source", of: url), ["story.ni"])
    }

    func testClosingAlsoCleansOutTheIndexFilesIfAsked() throws {
        let (project, url) = try openProjectWithBuildFiles(cleanOnClose: true, alsoCleanIndex: true)

        project.close()

        XCTAssertEqual(files(in: "Build", of: url), [])
        XCTAssertNil(files(in: "Temp", of: url))
        XCTAssertEqual(files(in: "Index", of: url), [])
        XCTAssertEqual(files(in: "Source", of: url), ["story.ni"])
    }

    /// The index files are only cleaned out with the build files, as the Advanced preferences show
    func testClosingCleansOutNothingIfNotAsked() throws {
        let (project, url) = try openProjectWithBuildFiles(cleanOnClose: false, alsoCleanIndex: true)

        project.close()

        XCTAssertEqual(files(in: "Build", of: url), ["Problems.html", "output.ulx"])
        XCTAssertEqual(files(in: "Temp", of: url), ["scratch"])
        XCTAssertEqual(files(in: "Index", of: url), ["Details", "Welcome.html"])
    }

    /// Saving cleans out the build files, but not the index files, which the Index page shows
    func testSavingLeavesTheIndexFiles() throws {
        let (project, _) = try openProjectWithBuildFiles(cleanOnClose: true, alsoCleanIndex: true)

        let wrapper = try project.fileWrapper(ofType: projectType)

        XCTAssertEqual(wrapper.fileWrappers?["Build"]?.fileWrappers?.keys.sorted(), [])
        XCTAssertNil(wrapper.fileWrappers?["Temp"])
        XCTAssertEqual(wrapper.fileWrappers?["Index"]?.fileWrappers?.keys.sorted(), ["Details", "Welcome.html"])
    }

    // MARK: - Reverting

    /// The source page shows the text storage it was given, so reverting gives that the saved text
    func testRevertingGivesASourceFilesTextTheSavedText() throws {
        let url = try makeProject(source: ["story.ni": Data("The Kitchen is a room.".utf8)])
        let project = try open(url)
        let story = try XCTUnwrap(project.sourceFiles?["story.ni"])
        story.replaceCharacters(in: NSRange(location: 0, length: story.length), with: "The Hall is a room.")

        try project.revert(toContentsOf: url, ofType: projectType)

        XCTAssertIdentical(project.sourceFiles?["story.ni"], story)
        XCTAssertEqual(story.string, "The Kitchen is a room.")
    }

    func testRevertingReplacesTheSkein() throws {
        let url = try makeProject(source: ["story.ni": Data()])
        try saveSkeins([["look"]], in: url, isExtensionProject: false)
        let project = try open(url)
        let skein = try XCTUnwrap(project.currentSkein)
        skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "north"))

        try project.revert(toContentsOf: url, ofType: projectType)

        XCTAssertEqual(project.skeins.count, 1)
        let reverted = try XCTUnwrap(project.currentSkein)
        XCTAssertIdentical(project.skeins.firstObject as AnyObject?, reverted)
        XCTAssertEqual(reverted.rootItem.children.map(\.command), ["look"])
    }

    func testRevertingAnExtensionProjectReplacesItsSkeins() throws {
        let url = try makeProject(named: "Lamplighting.i7xp", source: ["extension.i7x": Data(extensionText.utf8)])
        try saveSkeins([["look"], ["x lamp"]], in: url, isExtensionProject: true)
        let project = try open(url, ofType: extensionProjectType)

        try project.revert(toContentsOf: url, ofType: extensionProjectType)

        XCTAssertEqual(project.skeins.map { commands($0 as! IFSkein) }, [["look"], ["x lamp"]])
    }

    /// The Settings page shows the settings it was given, so it's told of the new ones
    func testRevertingGivesTheProjectTheSavedSettingsAndSaysSo() throws {
        let url = try makeProject(source: ["story.ni": Data()])
        let project = try open(url)
        project.settings.zcodeVersion = 8
        let replaced = XCTNSNotificationExpectation(name: .IFProjectSettingsReplaced, object: project)

        try project.revert(toContentsOf: url, ofType: projectType)

        wait(for: [replaced], timeout: 1)
        XCTAssertEqual(project.settings.zcodeVersion, IFCompilerSettings().zcodeVersion)
    }

    // MARK: - Extension projects

    func testReadsAnExtensionProject() throws {
        let project = try openExtensionProject()

        XCTAssertEqual(project.projectFileType, .inform7ExtensionProject)
        XCTAssertTrue(project.isExtensionProject)
        XCTAssertEqual(project.mainSourceFile, "extension.i7x")
        XCTAssertEqual(project.testCases?.map { $0["testTitle"] as? String }, ["Lighthouse", "Café"])
        // No test case's skein is chosen until one is
        XCTAssertNil(project.currentSkein)
        XCTAssertNil(project.nodeToReport)
        XCTAssertEqual(project.skeins.count, 1)
    }

    func testSelectsATestCasesSkein() throws {
        let project = try openExtensionProject()
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)

        project.selectSkein(1)

        wait(for: [replaced], timeout: 1)
        XCTAssertEqual(project.skeins.count, 2)
        XCTAssertIdentical(project.currentSkein, project.skeins[1] as? IFSkein)
        // Each skein is titled with its test case
        XCTAssertEqual((project.skeins[0] as? IFSkein)?.rootItem.command, "Lighthouse")
        XCTAssertEqual((project.skeins[1] as? IFSkein)?.rootItem.command, "Café")
    }

    func testSelectsNoSkein() throws {
        let project = try openExtensionProject()
        project.selectSkein(0)
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)

        project.selectSkein(-1)

        wait(for: [replaced], timeout: 1)
        XCTAssertNil(project.currentSkein)
    }

    func testDoesntReplaceTheSkeinSelected() throws {
        let project = try openExtensionProject()
        project.selectSkein(0)
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)
        replaced.isInverted = true

        project.selectSkein(0)

        wait(for: [replaced], timeout: 0.1)
    }

    func testGivesAnExtensionProjectsReportURLs() throws {
        let project = try openExtensionProject()
        let temporary = IFUtility.temporaryDirectoryURL()

        XCTAssertEqual(project.baseReportURL?.path, temporary.appendingPathComponent("Inform-Report.html").path)
        XCTAssertEqual(project.combinedReportURL?.path, try fileURL("Build/Problems.html", in: project).path)
        // The current report is the selected skein's
        XCTAssertNil(project.currentReportURL)
        project.selectSkein(1)
        XCTAssertEqual(project.currentReportURL?.path, temporary.appendingPathComponent("Inform-Report-2.html").path)
    }

    func testGivesATestCasesCommands() throws {
        let project = try openExtensionProject()

        XCTAssertEqual(project.testCommands(forExtensionTestCase: "A"), ["look", "x lamp"])
        XCTAssertEqual(project.testCommands(forExtensionTestCase: "B"), ["look"])
        XCTAssertNil(project.testCommands(forExtensionTestCase: "C"))
    }

    func testWritesATestCasesSourceAsTheStory() throws {
        let project = try openExtensionProject()

        project.extractSourceTask(forExtensionTestCase: "B")

        let story = try String(contentsOf: fileURL("Source/story.ni", in: project), encoding: .utf8)
        XCTAssertTrue(story.contains("The Café is a room."))
        XCTAssertFalse(story.contains("Lamp Room"))
    }

    func testWritesNoSourceWithoutATestCase() throws {
        let project = try openExtensionProject()

        project.extractSourceTask(forExtensionTestCase: nil)

        XCTAssertFalse(FileManager.default.fileExists(atPath: try fileURL("Source/story.ni", in: project).path))
    }

    func testWritesNoTestCaseSourceForAProject() throws {
        let project = try open(makeProject(source: ["story.ni": Data("Story".utf8)]))

        project.extractSourceTask(forExtensionTestCase: "A")

        XCTAssertEqual(try String(contentsOf: fileURL("Source/story.ni", in: project), encoding: .utf8), "Story")
    }

    func testRedirectsATestCasesLinksToTheExtension() throws {
        let project = try openExtensionProject()
        project.extractSourceTask(forExtensionTestCase: "B")

        // Line 5 of the test case's source, after its title, a blank line, the Include and a blank line
        let link = project.redirectLinks(toExtensionSourceCode: ["story.ni", "B", "5"])

        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.first as? String, "extension.i7x")
        let line = try XCTUnwrap(link.last as? Int)
        XCTAssertEqual(extensionText.components(separatedBy: "\n")[line - 1], "\tThe Café is a room.")
    }

    func testLeavesOtherLinksInAnExtensionProject() throws {
        let project = try openExtensionProject()

        XCTAssertEqual(project.redirectLinks(toExtensionSourceCode: ["Other.i7x", "B", "5"]) as NSArray,
                       ["Other.i7x", "5"] as NSArray)
    }

    func testTakesTheTestCaseFromAProjectsLinks() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))

        XCTAssertEqual(project.redirectLinks(toExtensionSourceCode: ["story.ni", "A", "12"]) as NSArray,
                       ["story.ni", "12"] as NSArray)
        XCTAssertEqual(project.redirectLinks(toExtensionSourceCode: ["story.ni", "12"]) as NSArray,
                       ["story.ni", "12"] as NSArray)
    }

    /// A problems page, as ni leaves after compiling a test case, with the markers intest looks for
    private func makeProblemsPage(for project: IFProject) throws {
        let build = try fileURL("Build", in: project)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try """
            <html><body>
             <!--CONTENT BEGINS-->
             <!--BANNER BEGINS-->
             <!--HEADING BEGINS-->
            Old heading
             <!--HEADING ENDS-->
             <!--BANNER ENDS-->
             <!--PROBLEMS BEGIN-->
            A problem
             <!--PROBLEMS END-->
             <!--CONTENT ENDS-->
            </body></html>

            """.write(to: build.appendingPathComponent("Problems.html"), atomically: true, encoding: .utf8)
    }

    func testWritesATestCasesReport() throws {
        let project = try openExtensionProject()
        try makeProblemsPage(for: project)
        let report = try makeFolder().appendingPathComponent("Report.html")

        XCTAssertTrue(project.generateReport(forTestCase: "A", errorCode: "right", skeinNodeId: 42, skeinNodes: 2,
                                             outputURL: report))
        XCTAssertTrue(try String(contentsOf: report, encoding: .utf8)
            .contains("Example A: &#8216;Lighthouse&#8217;: Succeeded"))

        XCTAssertFalse(project.generateReport(forTestCase: "A", errorCode: "maybe", skeinNodeId: 0, skeinNodes: 0,
                                              outputURL: report))
    }

    func testCombinesTestCasesReports() throws {
        let project = try openExtensionProject()
        try makeProblemsPage(for: project)
        let folder = try makeFolder()
        for (index, testCase) in ["A", "B"].enumerated() {
            XCTAssertTrue(project.generateReport(forTestCase: testCase, errorCode: "right", skeinNodeId: 0, skeinNodes: 0,
                                                 outputURL: folder.appendingPathComponent("Inform-Report-\(index + 1).html")))
        }
        let base = folder.appendingPathComponent("Inform-Report.html")
        let combined = folder.appendingPathComponent("Combined.html")

        XCTAssertTrue(project.generateCombinedReport(forBaseInputURL: base, numTests: 2, outputURL: combined))
        XCTAssertTrue(FileManager.default.fileExists(atPath: combined.path))

        XCTAssertFalse(project.generateCombinedReport(forBaseInputURL: base, numTests: 0,
                                                      outputURL: folder.appendingPathComponent("None.html")))
    }

    // MARK: - Compiling

    func testPreparesTheCompilerForAProject() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))

        let compiler = try XCTUnwrap(project.prepareCompiler(forRelease: false, forTesting: false, refreshOnly: false,
                                                             testCase: nil))

        XCTAssertIdentical(compiler, project.compiler)
        XCTAssertIdentical(compiler.settings, project.settings)
        XCTAssertEqual(compiler.inputFile, try XCTUnwrap(project.fileURL).path)
        XCTAssertEqual(compiler.directory, project.buildDirectoryURL?.path)
        XCTAssertEqual(compiler.outputFile, project.buildOutputFileURL?.path)
    }

    func testPreparesTheCompilerToMakeABlorbForRelease() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let output = try XCTUnwrap(project.settings.setting(for: IFI7OutputSettings.self) as? IFI7OutputSettings)
        output.createBlorbForRelease = true

        let compiler = try XCTUnwrap(project.prepareCompiler(forRelease: true, forTesting: false, refreshOnly: false,
                                                             testCase: nil))

        XCTAssertEqual((compiler.outputFile as NSString).pathExtension,
                       project.settings.zcodeVersion > 128 ? "gblorb" : "zblorb")
    }

    func testPreparesTheCompilerWithoutABlorbWhenTheSettingIsOff() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))
        let output = try XCTUnwrap(project.settings.setting(for: IFI7OutputSettings.self) as? IFI7OutputSettings)
        output.createBlorbForRelease = false

        let compiler = try XCTUnwrap(project.prepareCompiler(forRelease: true, forTesting: false, refreshOnly: false,
                                                             testCase: nil))

        XCTAssertEqual(compiler.outputFile, project.buildOutputFileURL?.path)
    }

    func testPreparesTheCompilerToRefreshTheIndex() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))

        XCTAssertNotNil(project.prepareCompiler(forRelease: false, forTesting: false, refreshOnly: true, testCase: nil))
    }

    func testCopiesAnExtensionProjectsExtensionToItsMaterialsWhenCompiling() throws {
        let project = try openExtensionProject()

        XCTAssertNotNil(project.prepareCompiler(forRelease: false, forTesting: false, refreshOnly: false, testCase: "A"))

        let copy = try XCTUnwrap(project.materialsDirectoryURL)
            .appendingPathComponent("Extensions/Jane Doe/Lamplighting.i7x")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), extensionText)
    }

    func testCopiesNoExtensionForAProject() throws {
        let project = try open(makeProject(source: ["story.ni": Data()]))

        XCTAssertNotNil(project.prepareCompiler(forRelease: false, forTesting: false, refreshOnly: false, testCase: nil))

        let extensions = try XCTUnwrap(project.materialsDirectoryURL).appendingPathComponent("Extensions")
        XCTAssertFalse(FileManager.default.fileExists(atPath: extensions.path))
    }

    // MARK: - Recordings

    /// A recording in a new folder; returns its path
    private func recording(_ contents: String) throws -> String {
        let file = try makeFolder().appendingPathComponent("Recording.rec")
        try Data(contents.utf8).write(to: file)
        return file.path
    }

    func testMakesASkeinFromARecording() throws {
        let skein = try XCTUnwrap(IFProject().skein(fromRecording: recording("look\nx lamp\n")))

        XCTAssertEqual(commands(skein), ["look", "x lamp"])
        XCTAssertIdentical(skein.activeItem, skein.rootItem.children.first?.children.first)
    }

    func testReadsARecordingsLineBreaks() throws {
        for lineBreak in ["\n", "\r", "\r\n", "\n\r"] {
            let contents = ["look", "x lamp", "wait"].joined(separator: lineBreak) + lineBreak
            let skein = try XCTUnwrap(IFProject().skein(fromRecording: recording(contents)), lineBreak.debugDescription)
            XCTAssertEqual(commands(skein), ["look", "x lamp", "wait"], lineBreak.debugDescription)
        }
    }

    func testReadsARecordingsLastCommandWithoutALineBreak() throws {
        let project = IFProject()

        XCTAssertEqual(commands(try XCTUnwrap(project.skein(fromRecording: recording("look\nwait")))), ["look", "wait"])
        XCTAssertEqual(commands(try XCTUnwrap(project.skein(fromRecording: recording("look")))), ["look"])
        // As long as it's no longer than any other
        XCTAssertNil(project.skein(fromRecording: try recording("look\n" + String(repeating: "a", count: 51))))
    }

    func testMakesNoSkeinFromWhatIsntARecording() throws {
        let project = IFProject()

        // No commands
        XCTAssertNil(project.skein(fromRecording: try recording("")))
        // A command longer than 50 characters
        XCTAssertNotNil(project.skein(fromRecording: try recording(String(repeating: "a", count: 50) + "\n")))
        XCTAssertNil(project.skein(fromRecording: try recording(String(repeating: "a", count: 51) + "\n")))
        // More than 10,000 commands
        XCTAssertNil(project.skein(fromRecording: try recording(String(repeating: "z\n", count: 10_001))))
        // More than 500,000 characters
        XCTAssertNil(project.skein(fromRecording: try recording(String(repeating: "z", count: 500_001))))
        // Not UTF-8
        let latin1 = try makeFolder().appendingPathComponent("Latin1.rec")
        try Data([0x43, 0x61, 0x66, 0xE9, 0x0A]).write(to: latin1)
        XCTAssertNil(project.skein(fromRecording: latin1.path))
        // No file
        XCTAssertNil(project.skein(fromRecording: try makeFolder().appendingPathComponent("Missing.rec").path))
    }
}
