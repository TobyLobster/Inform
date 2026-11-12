//
//  IFSourceTextsTests.swift
//  InformTests
//

import XCTest

/// The texts of a project's source files, read from its Source folder and written back
@MainActor
final class IFSourceTextsTests: XCTestCase {

    // MARK: - Helpers

    /// A project's folder in a new folder, removed when the test ends, with files in its Source folder and others by
    /// their paths in the project's folder
    private func makeProject(source: [String: Data], others: [String: Data] = [:]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let project = folder.appendingPathComponent("Lighthouse.inform")
        let files = source.map { ("Source/" + $0.key, $0.value) } + others.map { ($0.key, $0.value) }
        try FileManager.default.createDirectory(at: project.appendingPathComponent("Source"),
                                                withIntermediateDirectories: true)
        for (path, contents) in files {
            let url = project.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try contents.write(to: url)
        }
        return project
    }

    /// The texts of a project's Source folder, unregistered when the test ends
    private func read(_ project: URL, undoManager: UndoManager? = nil) throws -> IFSourceTexts {
        let texts = IFSourceTexts()
        let source = try FileWrapper(url: project.appendingPathComponent("Source"), options: .immediate)
        texts.read(sourceDirectory: source, undoManager: undoManager)
        addTeardownBlock { texts.unregisterTexts() }
        return texts
    }

    /// The text of a file, which is unregistered when the test ends if it isn't one of the texts
    private func text(of file: String?, in texts: IFSourceTexts, project: URL?,
                      undoManager: UndoManager? = nil) -> NSTextStorage? {
        let text = texts.text(forFile: file, inProjectAt: project, undoManager: undoManager)
        if let text {
            addTeardownBlock { IFSyntaxManager.unregisterTextStorage(text) }
        }
        return text
    }

    private func rtf(_ text: String) throws -> Data {
        let string = NSAttributedString(string: text)
        return try string.data(from: NSRange(location: 0, length: string.length),
                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private func string(_ wrapper: FileWrapper?) -> String? {
        return wrapper?.regularFileContents.flatMap { String(data: $0, encoding: .utf8) }
    }

    private func file(_ text: String) -> FileWrapper {
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    /// "Café" in Latin-1
    private let latin1 = Data([0x43, 0x61, 0x66, 0xE9])

    // MARK: - Reading

    func testHasNoTextsUntilTheSourceFolderIsRead() {
        XCTAssertNil(IFSourceTexts().texts)
    }

    /// Each file in the Source folder is read in its encoding, and an RTF file as RTF. A folder within it isn't read.
    func testReadsEachFileInTheSourceFolder() throws {
        let project = try makeProject(source: ["story.ni": Data("Café".utf8), "game.inf": Data("Café".utf8),
                                               "Map.rtf": try rtf("Map"), "Folder/Other.ni": Data("Other".utf8)])
        let texts = try read(project)
        XCTAssertEqual(texts.texts?.keys.sorted(), ["Map.rtf", "game.inf", "story.ni"])
        XCTAssertEqual(texts.texts?["story.ni"]?.string, "Café")
        XCTAssertEqual(texts.texts?["game.inf"]?.string, "CafÃ©")
        XCTAssertEqual(texts.texts?["Map.rtf"]?.string, "Map")
    }

    /// A file that isn't UTF-8 is read as Latin-1
    func testReadsAFileThatIsntInItsEncodingInAnother() throws {
        let project = try makeProject(source: ["story.ni": latin1])
        XCTAssertEqual(try read(project).texts?["story.ni"]?.string, "Café")
    }

    /// Returns, alone or before a newline, are made newlines
    func testMakesReturnsNewlines() throws {
        let project = try makeProject(source: ["story.ni": Data("One\r\nTwo\rThree\n".utf8)])
        XCTAssertEqual(try read(project).texts?["story.ni"]?.string, "One\nTwo\nThree\n")
    }

    /// Each text is registered to be highlighted, with the undo manager given, until the texts are unregistered
    func testRegistersEachText() throws {
        let undoManager = UndoManager()
        let project = try makeProject(source: ["story.ni": Data("Story".utf8), "game.inf": Data("Game".utf8)])
        let texts = try read(project, undoManager: undoManager)
        let all = Array((texts.texts ?? [:]).values)
        XCTAssertEqual(all.count, 2)
        for text in all {
            XCTAssertIdentical(IFSyntaxManager.data(for: text)?.undoManager, undoManager)
        }

        texts.unregisterTexts()
        XCTAssertFalse(all.contains { IFSyntaxManager.isRegistered($0) })
    }

    /// Reading the folder again gives the texts read before their files' new contents, as the pages show them. A new
    /// file has a new text, and the texts of files that have gone are unregistered.
    func testReadingAgainKeepsTheTextsReadBefore() throws {
        let project = try makeProject(source: ["story.ni": Data("Old".utf8), "Gone.ni": Data("Gone".utf8)])
        let texts = try read(project)
        let story = try XCTUnwrap(texts.texts?["story.ni"])
        let gone = try XCTUnwrap(texts.texts?["Gone.ni"])

        texts.read(sourceDirectory: FileWrapper(directoryWithFileWrappers: ["story.ni": file("New\r\n"),
                                                                            "New.ni": file("Added")]),
                   undoManager: nil)
        XCTAssertEqual(texts.texts?.keys.sorted(), ["New.ni", "story.ni"])
        XCTAssertIdentical(texts.texts?["story.ni"], story)
        XCTAssertEqual(story.string, "New\n")
        XCTAssertTrue(IFSyntaxManager.isRegistered(story))
        XCTAssertEqual(texts.texts?["New.ni"]?.string, "Added")
        XCTAssertTrue(IFSyntaxManager.isRegistered(try XCTUnwrap(texts.texts?["New.ni"])))
        XCTAssertFalse(IFSyntaxManager.isRegistered(gone))
    }

    // MARK: - Writing

    /// Each text is written into a Source folder, in place of any file of its name: an RTF file as RTF, and others in
    /// UTF-8. Other files are left there.
    func testWritesEachText() throws {
        let project = try makeProject(source: ["story.ni": Data("Old".utf8), "Map.rtf": try rtf("Map")])
        let texts = try read(project)
        let story = try XCTUnwrap(texts.texts?["story.ni"])
        story.replaceCharacters(in: NSRange(location: 0, length: story.length), with: "Café")
        texts.texts?["Map.rtf"]?.append(NSAttributedString(string: "s"))

        let source = FileWrapper(directoryWithFileWrappers: ["story.ni": file("Older"), "Other.ni": file("Other")])
        texts.write(into: source)
        XCTAssertEqual(source.fileWrappers?.keys.sorted(), ["Map.rtf", "Other.ni", "story.ni"])
        XCTAssertEqual(string(source.fileWrappers?["story.ni"]), "Café")
        XCTAssertEqual(string(source.fileWrappers?["Other.ni"]), "Other")
        let map = try XCTUnwrap(source.fileWrappers?["Map.rtf"]?.regularFileContents)
        XCTAssertEqual(NSAttributedString(rtf: map, documentAttributes: nil)?.string, "Maps")
    }

    func testWritesNothingBeforeTheFolderIsRead() {
        let source = FileWrapper(directoryWithFileWrappers: ["story.ni": file("Story")])
        IFSourceTexts().write(into: source)
        XCTAssertEqual(source.fileWrappers?.keys.sorted(), ["story.ni"])
        XCTAssertEqual(string(source.fileWrappers?["story.ni"]), "Story")
    }

    // MARK: - A file's text

    /// A file in the Source folder has its text, by its name or its path, but no file has none
    func testGivesTheTextOfAFileInTheSourceFolder() throws {
        let project = try makeProject(source: ["story.ni": Data("Story".utf8)])
        let texts = try read(project)
        let story = try XCTUnwrap(texts.texts?["story.ni"])
        XCTAssertIdentical(text(of: "story.ni", in: texts, project: project), story)
        XCTAssertIdentical(text(of: project.appendingPathComponent("Source/story.ni").path, in: texts,
                                project: project), story)
        XCTAssertNil(text(of: nil, in: texts, project: project))
    }

    /// A file in the Source folder that has gone from the disk still has its text, but one put there since the folder
    /// was read has none
    func testGivesTheTextsReadOnly() throws {
        let project = try makeProject(source: ["story.ni": Data("Story".utf8)])
        let texts = try read(project)
        try FileManager.default.removeItem(at: project.appendingPathComponent("Source/story.ni"))
        try Data("Added".utf8).write(to: project.appendingPathComponent("Source/Added.ni"))
        XCTAssertIdentical(text(of: "story.ni", in: texts, project: project), texts.texts?["story.ni"])
        XCTAssertNil(text(of: "Added.ni", in: texts, project: project))
        XCTAssertNil(text(of: project.appendingPathComponent("Source/Added.ni").path, in: texts, project: project))
    }

    /// A file outside the Source folder by an absolute path has no text, and nor has a file that isn't there
    func testGivesNoTextForAFileOutsideTheSourceFolderOrNotThere() throws {
        let project = try makeProject(source: ["story.ni": Data("Story".utf8)], others: ["Notes.ni": Data("N".utf8)])
        let texts = try read(project)
        XCTAssertNil(text(of: project.appendingPathComponent("Notes.ni").path, in: texts, project: project))
        XCTAssertNil(text(of: "Missing.ni", in: texts, project: project))
        XCTAssertNil(text(of: "Folder/Missing.ni", in: texts, project: project))
        XCTAssertNil(text(of: project.appendingPathComponent("Source/Folder/Missing.ni").path, in: texts,
                          project: project))
    }

    /// A file in a folder within the Source folder, by its path or by its path relative to the Source folder, is read
    /// from the disk, as UTF-8 or else Latin-1, into a new text each time, registered with the undo manager given
    func testReadsAFileInAFolderWithinTheSourceFolder() throws {
        let undoManager = UndoManager()
        let project = try makeProject(source: ["story.ni": Data("Story".utf8), "Folder/Other.ni": latin1,
                                               "Folder/Lines.ni": Data("One\r\nTwo".utf8)])
        let texts = try read(project)

        let path = project.appendingPathComponent("Source/Folder/Other.ni").path
        let other = try XCTUnwrap(text(of: path, in: texts, project: project, undoManager: undoManager))
        XCTAssertEqual(other.string, "Café")
        XCTAssertIdentical(IFSyntaxManager.data(for: other)?.undoManager, undoManager)
        XCTAssertNil(texts.texts?["Other.ni"])

        let again = try XCTUnwrap(text(of: "Folder/Other.ni", in: texts, project: project))
        XCTAssertFalse(again === other)
        XCTAssertEqual(again.string, "Café")
        XCTAssertTrue(IFSyntaxManager.isRegistered(again))

        XCTAssertEqual(text(of: "Folder/Lines.ni", in: texts, project: project)?.string, "One\nTwo")
    }

    /// A file by its path relative to the project's folder is read from the disk, if there's no such file in the
    /// Source folder
    func testReadsAFileInTheProjectsFolderByItsRelativePath() throws {
        let project = try makeProject(source: ["story.ni": Data("Story".utf8)],
                                      others: ["Build/auto.inf": Data("Auto".utf8), "story.ni": Data("Not".utf8)])
        let texts = try read(project)
        let auto = try XCTUnwrap(text(of: "Build/auto.inf", in: texts, project: project))
        XCTAssertEqual(auto.string, "Auto")
        XCTAssertTrue(IFSyntaxManager.isRegistered(auto))
        XCTAssertIdentical(text(of: "story.ni", in: texts, project: project), texts.texts?["story.ni"])
    }

    /// With no project's URL, as for a project never saved, a file by its name has no text, and one by its path is
    /// read from the disk
    func testWithoutAProjectsURL() throws {
        let project = try makeProject(source: ["story.ni": Data("Story".utf8)])
        let texts = try read(project)
        XCTAssertNil(text(of: "story.ni", in: texts, project: nil))
        let story = try XCTUnwrap(text(of: project.appendingPathComponent("Source/story.ni").path, in: texts,
                                       project: nil))
        XCTAssertFalse(story === texts.texts?["story.ni"])
        XCTAssertEqual(story.string, "Story")
    }
}
