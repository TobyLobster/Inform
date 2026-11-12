//
//  IFProjectSkeinsTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFProjectSkeinsTests: XCTestCase {

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

    /// A file with these contents in a new folder; returns its path
    private func file(_ name: String, contents: Data) throws -> String {
        let file = try makeFolder().appendingPathComponent(name)
        try contents.write(to: file)
        return file.path
    }

    /// Opens an extension project in a new folder, whose documentation has two examples, closed when the test ends
    private func openExtensionProject() throws -> IFProject {
        let url = try makeFolder().appendingPathComponent("Lamplighting.i7xp")
        let source = url.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data(extensionText.utf8).write(to: source.appendingPathComponent("extension.i7x"))
        let project = try IFProject(contentsOf: url, ofType: "org.inform-fiction.xproject")
        addTeardownBlock { project.close() }
        return project
    }

    /// A skein with a line of play
    private func skein(_ line: [String]) -> IFSkein {
        let skein = IFSkein(project: nil)
        var item = skein.rootItem
        for command in line {
            item = item.addChild(IFSkeinItem(skein: skein, command: command))
        }
        return skein
    }

    /// A project's files, kept in memory, with skeins each with a line of play, if there are any
    private func projectFile(_ lines: [[String]], isExtensionProject: Bool) throws -> IFProjectFile {
        let source = FileWrapper(directoryWithFileWrappers: [:])
        source.addRegularFile(withContents: Data(), preferredFilename: "story.ni")
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: FileWrapper(directoryWithFileWrappers: [
            "Source": source,
        ])))
        // A project's files are written with its skein, which it always has once it's read
        if !lines.isEmpty {
            projectFile.write(lines.map { skein($0) }, isExtensionProject: isExtensionProject)
        }
        return projectFile
    }

    /// The commands that start the threads of a skein, and those after one of them
    private func threads(of skein: IFSkein?) -> Set<String> {
        return Set((skein?.rootItem.children ?? []).compactMap(\.command))
    }

    private func commands(of skein: IFSkein?, after command: String) -> [String] {
        let thread = skein?.rootItem.children.first { $0.command == command }
        return (thread?.children ?? []).compactMap(\.command)
    }

    /// The commands of a skein's first line of play
    private func commands(_ skein: IFSkein?) -> [String] {
        var commands: [String] = []
        var item = skein?.rootItem
        while let child = item?.children.first {
            commands.append(child.command)
            item = child
        }
        return commands
    }

    // MARK: - Choosing the skein shown

    func testShowsASkeinOfItsOwnUntilTheSkeinsAreRead() {
        let skeins = IFProjectSkeins(project: nil)

        XCTAssertNotNil(skeins.currentSkein)
        XCTAssertEqual(skeins.skeins.count, 0)
    }

    func testMakesTheSkeinsUpToTheOneChosen() {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)

        skeins.selectSkein(2)

        wait(for: [replaced], timeout: 1)
        XCTAssertEqual(skeins.skeins.count, 3)
        XCTAssertIdentical(skeins.currentSkein, skeins.skeins[2] as? IFSkein)
    }

    func testDoesntReplaceTheSkeinShown() {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.selectSkein(0)
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)
        replaced.isInverted = true

        skeins.selectSkein(0)

        wait(for: [replaced], timeout: 0.1)
    }

    func testShowsNoSkein() {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.selectSkein(0)
        let replaced = expectation(forNotification: .IFSkeinReplaced, object: project)

        skeins.selectSkein(-1)

        wait(for: [replaced], timeout: 1)
        XCTAssertNil(skeins.currentSkein)
        XCTAssertEqual(skeins.skeins.count, 1)
    }

    func testTitlesTheSkeinsWithTheProjectsTestCases() throws {
        let project = try openExtensionProject()
        let skeins = IFProjectSkeins(project: project)

        skeins.selectSkein(1)

        XCTAssertEqual((skeins.skeins[0] as? IFSkein)?.rootItem.command, "Lighthouse")
        XCTAssertEqual((skeins.skeins[1] as? IFSkein)?.rootItem.command, "Café")
    }

    /// The project's undo manager, with an action on the skein given, as editing it leaves
    private func undoManager(of project: IFProject, withAnActionOn skein: IFSkein?) throws -> UndoManager {
        let undoManager = try XCTUnwrap(project.undoManager)
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: try XCTUnwrap(skein)) { _ in }
        undoManager.endUndoGrouping()
        XCTAssertTrue(undoManager.canUndo)
        return undoManager
    }

    func testTakesTheSkeinsActionsOffTheUndoStackWhenAnotherIsShown() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.selectSkein(0)
        let undoManager = try undoManager(of: project, withAnActionOn: skeins.currentSkein)

        skeins.selectSkein(1)

        XCTAssertFalse(undoManager.canUndo)
    }

    /// Undo mustn't change a skein that isn't shown
    func testTakesTheSkeinsActionsOffTheUndoStackWhenNoneIsShown() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.selectSkein(0)
        let undoManager = try undoManager(of: project, withAnActionOn: skeins.currentSkein)

        skeins.selectSkein(-1)

        XCTAssertFalse(undoManager.canUndo)
    }

    // MARK: - Reading

    func testReadsAProjectsSkeinAndShowsIt() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)

        skeins.loadSkeins(from: try projectFile([["look", "x lamp"]], isExtensionProject: false),
                          isExtensionProject: false)

        XCTAssertEqual(skeins.skeins.count, 1)
        XCTAssertIdentical(skeins.currentSkein, skeins.skeins.firstObject as AnyObject?)
        XCTAssertEqual(commands(skeins.currentSkein), ["look", "x lamp"])
    }

    func testReadsAnExtensionProjectsSkeinsAndShowsNone() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)

        skeins.loadSkeins(from: try projectFile([["look"], ["x lamp"]], isExtensionProject: true),
                          isExtensionProject: true)

        XCTAssertEqual(skeins.skeins.map { commands($0 as? IFSkein) }, [["look"], ["x lamp"]])
        XCTAssertNil(skeins.currentSkein)
    }

    func testReadingAgainReplacesTheSkeins() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.loadSkeins(from: try projectFile([["look"]], isExtensionProject: false), isExtensionProject: false)

        skeins.loadSkeins(from: try projectFile([["wait"]], isExtensionProject: false), isExtensionProject: false)

        XCTAssertEqual(skeins.skeins.map { commands($0 as? IFSkein) }, [["wait"]])
        XCTAssertIdentical(skeins.currentSkein, skeins.skeins.firstObject as AnyObject?)
    }

    func testReadsASkeinForAProjectWithoutOne() throws {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)

        skeins.loadSkeins(from: try projectFile([], isExtensionProject: false), isExtensionProject: false)

        XCTAssertEqual(skeins.skeins.count, 1)
        XCTAssertEqual(commands(skeins.currentSkein), [])
    }

    // MARK: - Recordings

    /// A recording in a new folder; returns its path
    private func recording(_ contents: String) throws -> String {
        let file = try makeFolder().appendingPathComponent("Recording.rec")
        try Data(contents.utf8).write(to: file)
        return file.path
    }

    func testMakesASkeinFromARecording() throws {
        let skein = try XCTUnwrap(IFProjectSkeins(project: nil).skein(fromRecording: recording("look\nx lamp\n")))

        XCTAssertEqual(commands(skein), ["look", "x lamp"])
        XCTAssertIdentical(skein.activeItem, skein.rootItem.children.first?.children.first)
    }

    func testReadsARecordingsLineBreaks() throws {
        let skeins = IFProjectSkeins(project: nil)
        for lineBreak in ["\n", "\r", "\r\n", "\n\r"] {
            let contents = ["look", "x lamp", "wait"].joined(separator: lineBreak) + lineBreak
            let skein = try XCTUnwrap(skeins.skein(fromRecording: recording(contents)), lineBreak.debugDescription)
            XCTAssertEqual(commands(skein), ["look", "x lamp", "wait"], lineBreak.debugDescription)
        }
    }

    func testReadsARecordingsLastCommandWithoutALineBreak() throws {
        let skeins = IFProjectSkeins(project: nil)

        XCTAssertEqual(commands(try XCTUnwrap(skeins.skein(fromRecording: recording("look\nwait")))), ["look", "wait"])
        XCTAssertEqual(commands(try XCTUnwrap(skeins.skein(fromRecording: recording("look")))), ["look"])
        // As long as it's no longer than any other
        XCTAssertNil(skeins.skein(fromRecording: try recording("look\n" + String(repeating: "a", count: 51))))
    }

    func testMakesNoSkeinFromWhatIsntARecording() throws {
        let skeins = IFProjectSkeins(project: nil)

        // No commands
        XCTAssertNil(skeins.skein(fromRecording: try recording("")))
        // A command longer than 50 characters
        XCTAssertNotNil(skeins.skein(fromRecording: try recording(String(repeating: "a", count: 50) + "\n")))
        XCTAssertNil(skeins.skein(fromRecording: try recording(String(repeating: "a", count: 51) + "\n")))
        // More than 10,000 commands
        XCTAssertNil(skeins.skein(fromRecording: try recording(String(repeating: "z\n", count: 10_001))))
        // More than 500,000 characters
        XCTAssertNil(skeins.skein(fromRecording: try recording(String(repeating: "z", count: 500_001))))
        // Not UTF-8
        let latin1 = try makeFolder().appendingPathComponent("Latin1.rec")
        try Data([0x43, 0x61, 0x66, 0xE9, 0x0A]).write(to: latin1)
        XCTAssertNil(skeins.skein(fromRecording: latin1.path))
        // No file
        XCTAssertNil(skeins.skein(fromRecording: try makeFolder().appendingPathComponent("Missing.rec").path))
    }

    // MARK: - Importing

    /// A project's skeins, showing a skein with a line of play
    private func skeinsShowing(_ line: [String]) -> (IFProject, IFProjectSkeins) {
        let project = IFProject()
        let skeins = IFProjectSkeins(project: project)
        skeins.selectSkein(0)
        if let current = skeins.currentSkein {
            var item = current.rootItem
            for command in line {
                item = item.addChild(IFSkeinItem(skein: current, command: command))
            }
        }
        return (project, skeins)
    }

    func testImportsARecordingIntoTheSkeinShown() throws {
        for name in ["Recording.rec", "Recording.TXT"] {
            let (project, skeins) = skeinsShowing(["north"])

            let recording = try file(name, contents: Data("look\nx lamp\n".utf8))

            XCTAssertNil(skeins.importIntoCurrentSkein(fromFile: recording), name)

            XCTAssertEqual(threads(of: skeins.currentSkein), ["north", "look"], name)
            XCTAssertEqual(commands(of: skeins.currentSkein, after: "look"), ["x lamp"], name)
            withExtendedLifetime(project) {}
        }
    }

    func testImportsASkeinsThreadsIntoTheSkeinShown() throws {
        let (project, skeins) = skeinsShowing(["north"])
        let imported = skein(["look", "x lamp"])
        imported.rootItem.addChild(IFSkeinItem(skein: imported, command: "wait"))

        XCTAssertNil(skeins.importIntoCurrentSkein(fromFile: try file("Old.skein",
                                                                      contents: Data(imported.xmlString.utf8))))

        XCTAssertEqual(threads(of: skeins.currentSkein), ["north", "look", "wait"])
        XCTAssertEqual(commands(of: skeins.currentSkein, after: "look"), ["x lamp"])
        withExtendedLifetime(project) {}
    }

    func testImportsAZoomSavedGamesSkein() throws {
        let (project, skeins) = skeinsShowing([])
        let saved = try makeFolder().appendingPathComponent("Lighthouse.zoomSave")
        try FileManager.default.createDirectory(at: saved, withIntermediateDirectories: true)
        try Data(skein(["look"]).xmlString.utf8).write(to: saved.appendingPathComponent("Skein.skein"))

        XCTAssertNil(skeins.importIntoCurrentSkein(fromFile: saved.path))

        XCTAssertEqual(commands(skeins.currentSkein), ["look"])
        withExtendedLifetime(project) {}
    }

    func testSaysWhyARecordingCouldntBeImported() throws {
        let (project, skeins) = skeinsShowing(["north"])
        let tooLong = try file("Recording.rec", contents: Data(String(repeating: "a", count: 51).utf8))

        XCTAssertEqual(skeins.importIntoCurrentSkein(fromFile: tooLong),
                       IFUtility.localizedString("Recording Skein Load Failure", default: nil))

        XCTAssertEqual(threads(of: skeins.currentSkein), ["north"])
        withExtendedLifetime(project) {}
    }

    func testSaysWhyAnotherFileCouldntBeImported() throws {
        let (project, skeins) = skeinsShowing(["north"])
        let failure = IFUtility.localizedString("Skein Load Failure", default: nil)

        XCTAssertEqual(skeins.importIntoCurrentSkein(fromFile: try file("Broken.skein", contents: Data("<no".utf8))),
                       failure)
        XCTAssertEqual(skeins.importIntoCurrentSkein(fromFile: try makeFolder().appendingPathComponent("Empty.zoomSave")
                                                                               .path),
                       failure)
        XCTAssertEqual(skeins.importIntoCurrentSkein(fromFile: try file("Notes.pdf", contents: Data("look\n".utf8))),
                       failure)

        XCTAssertEqual(threads(of: skeins.currentSkein), ["north"])
        withExtendedLifetime(project) {}
    }
}
