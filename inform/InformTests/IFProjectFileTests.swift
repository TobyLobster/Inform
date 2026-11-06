//
//  IFProjectFileTests.swift
//  InformTests
//

import XCTest

final class IFProjectFileTests: XCTestCase {

    private let fileManager = FileManager.default

    private func makeFolder() throws -> URL {
        let folder = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func file(_ text: String) -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    private func folder(_ children: [String: FileWrapper] = [:]) -> FileWrapper {
        return FileWrapper(directoryWithFileWrappers: children)
    }

    private func text(_ wrapper: FileWrapper?) -> String? {
        return wrapper?.regularFileContents.map { String(decoding: $0, as: UTF8.self) }
    }

    private func names(_ wrapper: FileWrapper) -> [String] {
        return (wrapper.fileWrappers ?? [:]).keys.sorted()
    }

    /// A project folder, as Inform reads it, named for the project
    private func project(_ children: [String: FileWrapper] = [:], name: String = "Lighthouse.inform") -> FileWrapper {
        let project = folder(children)
        project.preferredFilename = name
        return project
    }

    /// A project written to disk and read back, as Inform opens it
    private func reread(_ projectFile: IFProjectFile, in folder: URL) throws -> FileWrapper {
        let url = folder.appendingPathComponent("Lighthouse.inform")
        projectFile.filename = url.path
        XCTAssertTrue(projectFile.write)
        return try FileWrapper(url: url, options: .immediate)
    }

    private func skein(_ commands: [String]) -> IFSkein {
        let skein: IFSkein = IFSkein(project: nil)
        var item: IFSkeinItem = skein.rootItem
        for command in commands {
            item = item.addChild(IFSkeinItem(skein: skein, command: command))
        }
        return skein
    }

    /// The commands of a skein's first line of play, from its root
    private func commands(_ skein: IFSkein) -> [String] {
        var commands: [String] = [skein.rootItem.command]
        var item = skein.rootItem
        while let child = item.children.first {
            commands.append(child.command)
            item = child
        }
        return commands
    }

    private func loadSkeins(_ projectFile: IFProjectFile, isExtensionProject: Bool) -> [IFSkein] {
        let skeins = NSMutableArray()
        projectFile.load(into: skeins, project: IFProject(), isExtensionProject: isExtensionProject)
        return skeins.compactMap { $0 as? IFSkein }
    }

    // MARK: - New projects

    func testANewProjectHasItsFoldersAndAUUID() throws {
        let projectFile = IFProjectFile(emptyProject: ())

        let written = try reread(projectFile, in: try makeFolder())

        XCTAssertEqual(names(written), ["Build", "Index", "Source", "uuid.txt"])
        for name in ["Build", "Index", "Source"] {
            XCTAssertEqual(written.fileWrappers?[name]?.isDirectory, true, name)
            XCTAssertEqual(written.fileWrappers?[name]?.fileWrappers?.count, 0, name)
        }
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(projectFile.loadUUID)))
        XCTAssertEqual(text(written.fileWrappers?["uuid.txt"]), projectFile.loadUUID)
    }

    func testANewProjectHasNothingElse() throws {
        let projectFile = IFProjectFile(emptyProject: ())

        XCTAssertNil(projectFile.settings)
        XCTAssertNil(projectFile.loadNotes)
        XCTAssertNil(projectFile.loadWatchpoints)
        XCTAssertNil(projectFile.loadBreakpoints)
        XCTAssertEqual(try XCTUnwrap(projectFile.sourceDirectory).fileWrappers?.count, 0)
    }

    func testEachNewProjectHasItsOwnUUID() {
        XCTAssertNotEqual(IFProjectFile(emptyProject: ()).loadUUID, IFProjectFile(emptyProject: ()).loadUUID)
    }

    func testAddsSourceFiles() throws {
        let projectFile = IFProjectFile(emptyProject: ())

        projectFile.addSourceFile("story.ni", withContents: Data("The Lamp Room is a room.".utf8))

        let source = try XCTUnwrap(projectFile.sourceDirectory)
        XCTAssertEqual(text(source.fileWrappers?["story.ni"]), "The Lamp Room is a room.")
    }

    func testDoesntWriteWhereThereIsNoFolder() throws {
        let projectFile = IFProjectFile(emptyProject: ())
        projectFile.filename = try makeFolder().appendingPathComponent("Missing/Lighthouse.inform").path

        XCTAssertFalse(projectFile.write)
    }

    func testItsFilenameIsItsFolders() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.filename = "/Projects/Lighthouse.inform"

        XCTAssertEqual(wrapper.filename, "/Projects/Lighthouse.inform")
        XCTAssertEqual(projectFile.filename, "/Projects/Lighthouse.inform")
    }

    // MARK: - Reading a project

    func testAFileIsNotAProject() {
        XCTAssertNil(IFProjectFile(fileWrapper: file("The Lamp Room is a room.")))
    }

    func testAddsWhatsMissingToAProject() throws {
        let wrapper = project(["Index": folder()])

        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        XCTAssertEqual(names(wrapper), ["Build", "Index", "Source", "uuid.txt"])
        XCTAssertTrue(projectFile.sourceDirectory === wrapper.fileWrappers?["Source"])
        XCTAssertEqual(wrapper.fileWrappers?["Build"]?.isDirectory, true)
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(projectFile.loadUUID)))
    }

    func testKeepsWhatAProjectHas() throws {
        let source = folder(["story.ni": file("The Lamp Room is a room.")])
        let build = folder(["output.ulx": file("story")])
        let wrapper = project(["Source": source, "Build": build, "uuid.txt": file("8C5D5A49-2B0E-4C6B-9D3A-6F1E2A7B4C90")])

        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        XCTAssertEqual(names(wrapper), ["Build", "Source", "uuid.txt"])
        XCTAssertTrue(wrapper.fileWrappers?["Source"] === source)
        XCTAssertTrue(wrapper.fileWrappers?["Build"] === build)
        XCTAssertTrue(projectFile.sourceDirectory === source)
        XCTAssertEqual(projectFile.loadUUID, "8C5D5A49-2B0E-4C6B-9D3A-6F1E2A7B4C90")
    }

    func testASourceFileIsntASourceFolder() throws {
        let wrapper = project(["Source": file("The Lamp Room is a room.")])

        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        XCTAssertNil(projectFile.sourceDirectory)
        XCTAssertEqual(text(wrapper.fileWrappers?["Source"]), "The Lamp Room is a room.")
    }

    /// A project's UUID is the whole of its uuid.txt, which doesn't end with a NUL. Reading
    /// past its end isn't seen in a normal run, as the bytes after it are usually zero, but
    /// Address Sanitizer reports it.
    func testReadsTheUUIDFromItsFileAlone() throws {
        let uuid = "8C5D5A49-2B0E-4C6B-9D3A-6F1E2A7B4C90"
        let project = FileWrapper(directoryWithFileWrappers: [
            "uuid.txt": FileWrapper(regularFileWithContents: Data(uuid.utf8))
        ])

        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project))

        XCTAssertEqual(projectFile.loadUUID, uuid)
    }

    // MARK: - Settings

    func testWritesSettingsInPlaceOfOldOnes() throws {
        let wrapper = project(["Settings": file("old settings")])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 8

        projectFile.settings = settings
        projectFile.settings = settings

        XCTAssertEqual(names(wrapper), ["Build", "Settings.plist", "Source", "uuid.txt"])
        XCTAssertEqual(try XCTUnwrap(projectFile.settings).zcodeVersion, 8)
        XCTAssertFalse(try XCTUnwrap(projectFile.settings) === settings)
    }

    func testAnOldSettingsFileItCantReadGivesTheDefaults() throws {
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(["Settings": file("old settings")])))

        let settings = try XCTUnwrap(projectFile.settings)

        XCTAssertEqual(settings.zcodeVersion, 256)
    }

    /// No settings are written as an empty file, which gives the defaults
    func testWritesNoSettingsAsAnEmptyFile() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.settings = nil

        XCTAssertEqual(wrapper.fileWrappers?["Settings.plist"]?.regularFileContents, Data())
        XCTAssertEqual(try XCTUnwrap(projectFile.settings).zcodeVersion, 256)
    }

    /// Before Settings.plist, settings were archived with NSArchiver in a Settings file, after
    /// the name of the app that wrote them and a version number. These are archived as the
    /// settings archive themselves now, with a Z-code version of 8, and not strict.
    private let oldSettings = """
        BAtzdHJlYW10eXBlZIHoA4QBQISEhAhOU1N0cmluZwGEhAhOU09iamVjdACFhAErBkluZm9ybYaEAWkBkoSEhBJJRkNvbXBp\
        bGVyU2V0dGluZ3MAlJKEhIQTTlNNdXRhYmxlRGljdGlvbmFyeQCEhAxOU0RpY3Rpb25hcnkAlJYCkoSTlQ5JRk1pc2NTZXR0\
        aW5nc4aShJiWAZKEk5UPSUZTZXR0aW5nU3RyaWN0hpKEhIQITlNOdW1iZXIAhIQHTlNWYWx1ZQCUhAEqhIQBY50AhoaShJOV\
        EElGT3V0cHV0U2V0dGluZ3OGkoSYlgGShJOVFUlGU2V0dGluZ1pDb2RlVmVyc2lvboaShJ6chJaWCIaGhoY=
        """

    func testReadsAnOldSettingsFile() throws {
        let data = try XCTUnwrap(Data(base64Encoded: oldSettings))
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(["Settings": FileWrapper(regularFileWithContents: data)])))

        let settings = try XCTUnwrap(projectFile.settings)

        XCTAssertEqual(settings.zcodeVersion, 8)
        XCTAssertFalse(settings.strict)
    }

    func testADamagedOldSettingsFileGivesTheDefaults() throws {
        let data = try XCTUnwrap(Data(base64Encoded: oldSettings))
        let damaged = FileWrapper(regularFileWithContents: data.prefix(data.count / 2))
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(["Settings": damaged])))

        let settings = try XCTUnwrap(projectFile.settings)

        XCTAssertEqual(settings.zcodeVersion, 256)
    }

    // MARK: - Notes

    func testWritesAndReadsNotes() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let notes = NSAttributedString(string: "Light the lamp")
        let rtf = try notes.data(from: NSRange(location: 0, length: notes.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])

        projectFile.writeNotes(Data("Old notes".utf8))
        projectFile.writeNotes(rtf)

        XCTAssertEqual(projectFile.loadNotes?.string, "Light the lamp")
        XCTAssertEqual(names(wrapper), ["Build", "Source", "notes.rtf", "uuid.txt"])
    }

    /// A project with no notes has nil for them, and they're written as an empty file
    func testWritesNoNotesAsAnEmptyFile() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.writeNotes(nil)

        XCTAssertEqual(wrapper.fileWrappers?["notes.rtf"]?.regularFileContents, Data())
        XCTAssertNil(projectFile.loadNotes)
    }

    // MARK: - Watchpoints and breakpoints

    func testWritesAndReadsWatchpointsAndBreakpoints() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.writeWatchpoints(["old"])
        projectFile.writeWatchpoints(["lamp", "lens"])
        projectFile.writeBreakpoints([["story.ni", 3]])

        XCTAssertEqual(projectFile.loadWatchpoints, ["lamp", "lens"])
        XCTAssertEqual(projectFile.loadBreakpoints, [["story.ni", 3]])
        XCTAssertEqual(names(wrapper), ["Breakpoints.plist", "Build", "Source", "Watchpoints.plist", "uuid.txt"])
        projectFile.loadWatchpoints?.add("prism")
        XCTAssertEqual(projectFile.loadWatchpoints?.count, 2)
    }

    func testRemovesWatchpointsAndBreakpointsWhenThereAreNone() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        projectFile.writeWatchpoints(["lamp"])
        projectFile.writeBreakpoints([["story.ni", 3]])

        projectFile.writeWatchpoints([])
        projectFile.writeBreakpoints([])

        XCTAssertNil(projectFile.loadWatchpoints)
        XCTAssertNil(projectFile.loadBreakpoints)
        XCTAssertEqual(names(wrapper), ["Build", "Source", "uuid.txt"])
    }

    func testIgnoresWatchpointsAndBreakpointsItCantRead() throws {
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project([
            "Watchpoints.plist": file("not a property list"),
            "Breakpoints.plist": file("not a property list"),
        ])))

        XCTAssertNil(projectFile.loadWatchpoints)
        XCTAssertNil(projectFile.loadBreakpoints)
    }

    // MARK: - Skeins

    func testWritesAndReadsASkein() throws {
        let wrapper = project()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let skein = skein(["look", "light lamp"])

        projectFile.write([skein], isExtensionProject: false)
        let loaded = loadSkeins(projectFile, isExtensionProject: false)

        // The root is named for the project
        XCTAssertEqual(skein.rootItem.command, "Lighthouse")
        XCTAssertEqual(loaded.map(commands), [["Lighthouse", "look", "light lamp"]])
        let xml = try XCTUnwrap(text(wrapper.fileWrappers?["Skein.skein"]))
        XCTAssertTrue(xml.hasPrefix("<?xml version=\"1.0\"?>\n"), xml)
    }

    func testANewSkeinWhenThereIsNone() throws {
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project()))

        let loaded = loadSkeins(projectFile, isExtensionProject: false)

        XCTAssertEqual(loaded.map(commands), [["Lighthouse"]])
    }

    func testWritesAndReadsAnExtensionProjectsSkeins() throws {
        let folder = try makeFolder()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(name: "Lighthouse.i7xp")))
        projectFile.write([skein(["look"]), skein(["north"]), skein(["climb"])], isExtensionProject: true)

        let written = try reread(projectFile, in: folder)
        let loaded = loadSkeins(try XCTUnwrap(IFProjectFile(fileWrapper: written)), isExtensionProject: true)

        XCTAssertEqual(names(written).filter { $0.hasSuffix(".skein") }, ["SkeinA.skein", "SkeinB.skein", "SkeinC.skein"])
        XCTAssertEqual(loaded.map { commands($0).last }, ["look", "north", "climb"])
    }

    func testReadsAnExtensionProjectsSkeinsUpToTheFirstMissingLetter() throws {
        let folder = try makeFolder()
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(name: "Lighthouse.i7xp")))
        projectFile.write([skein(["look"]), skein(["north"]), skein(["climb"])], isExtensionProject: true)
        let url = folder.appendingPathComponent("Lighthouse.inform")
        projectFile.filename = url.path
        XCTAssertTrue(projectFile.write)
        try fileManager.removeItem(at: url.appendingPathComponent("SkeinB.skein"))

        let written = try FileWrapper(url: url, options: .immediate)
        let loaded = loadSkeins(try XCTUnwrap(IFProjectFile(fileWrapper: written)), isExtensionProject: true)

        XCTAssertEqual(loaded.map { commands($0).last }, ["look"])
    }

    func testANewSkeinForAnExtensionProjectWithNone() throws {
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project(name: "Lighthouse.i7xp")))

        let loaded = loadSkeins(projectFile, isExtensionProject: true)

        XCTAssertEqual(loaded.map(commands), [["Lighthouse"]])
    }

    // MARK: - Replacing folders

    /// Reloading the Source folder when it's missing on disk leaves the project without one.
    func testReplacingTheSourceFolderWithNothingRemovesIt() throws {
        let source = FileWrapper(directoryWithFileWrappers: [:])
        source.preferredFilename = "Source"
        let project = FileWrapper(directoryWithFileWrappers: ["Source": source])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project))

        projectFile.replaceSourceDirectoryWrapper(nil)

        XCTAssertNil(project.fileWrappers?["Source"])
    }

    func testReplacesTheSourceFolder() throws {
        let wrapper = project(["Source": folder(["story.ni": file("old")])])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let source = folder(["story.ni": file("new")])
        source.preferredFilename = "Source"

        projectFile.replaceSourceDirectoryWrapper(source)

        XCTAssertTrue(wrapper.fileWrappers?["Source"] === source)
    }

    /// After the Source folder or the whole project is reloaded, its Source folder is the new one.
    func testItsSourceFolderIsTheOneItHasNow() throws {
        let wrapper = project(["Source": folder(["story.ni": file("old")])])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let source = folder(["story.ni": file("new")])
        source.preferredFilename = "Source"

        projectFile.replaceSourceDirectoryWrapper(source)
        XCTAssertTrue(projectFile.sourceDirectory === source)

        let reloaded = folder(["story.ni": file("reloaded")])
        projectFile.replace(folder(["Source": reloaded]))
        XCTAssertTrue(projectFile.sourceDirectory === reloaded)

        projectFile.replaceSourceDirectoryWrapper(nil)
        XCTAssertNil(projectFile.sourceDirectory)
    }

    func testReplacesTheIndexFolder() throws {
        let wrapper = project(["Index": folder(["Welcome.html": file("old")])])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let index = folder(["Welcome.html": file("new")])
        index.preferredFilename = "Index"

        projectFile.replaceIndexDirectoryWrapper(index)
        XCTAssertTrue(wrapper.fileWrappers?["Index"] === index)

        projectFile.replaceIndexDirectoryWrapper(nil)
        XCTAssertNil(wrapper.fileWrappers?["Index"])
    }

    func testReplacesEverything() throws {
        let wrapper = project(["Source": folder(), "Build": folder(), "notes.rtf": file("old")])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))
        let source = folder(["story.ni": file("new")])
        let reloaded = folder(["Source": source, "Settings.plist": file("settings")])

        projectFile.replace(reloaded)
        XCTAssertEqual(names(wrapper), ["Settings.plist", "Source"])
        XCTAssertTrue(wrapper.fileWrappers?["Source"] === source)

        projectFile.replace(nil)
        XCTAssertEqual(names(wrapper), [])
    }

    // MARK: - Cleaning

    func testCleaningEmptiesTheBuildFolderAndRemovesTemp() throws {
        let index = folder(["Welcome.html": file("index")])
        let wrapper = project(["Build": folder(["output.ulx": file("story")]), "Temp": folder(), "Index": index])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.cleanOutUnnecessaryFiles(alsoCleanIndex: false)

        XCTAssertEqual(names(wrapper), ["Build", "Index", "Source", "uuid.txt"])
        XCTAssertEqual(wrapper.fileWrappers?["Build"]?.fileWrappers?.count, 0)
        XCTAssertTrue(wrapper.fileWrappers?["Index"] === index)
    }

    func testCleaningCanEmptyTheIndexFolder() throws {
        let wrapper = project(["Index": folder(["Welcome.html": file("index")])])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: wrapper))

        projectFile.cleanOutUnnecessaryFiles(alsoCleanIndex: true)

        XCTAssertEqual(names(wrapper), ["Build", "Index", "Source", "uuid.txt"])
        XCTAssertEqual(wrapper.fileWrappers?["Index"]?.isDirectory, true)
        XCTAssertEqual(wrapper.fileWrappers?["Index"]?.fileWrappers?.count, 0)
    }
}
