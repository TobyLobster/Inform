//
//  IFSingleFileTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSingleFileTests: XCTestCase {
    private let inform7SourceType = "Inform 7 source file"
    private let inform7ExtensionType = "org.inform-fiction.inform7.extension"
    private let inform6SourceType = "Inform 6 source file"
    private let controlLanguageType = "Inform Control Language file"
    private let headerType = "public.c-header"

    /// A file read from these bytes, as of the type given. Its text storage is let go when the test ends.
    private func file(_ contents: Data, ofType typeName: String) throws -> IFSingleFile {
        let file = IFSingleFile()
        try file.read(from: contents, ofType: typeName)
        return file
    }

    /// How the file's text storage was registered for highlighting
    private func syntaxData(_ file: IFSingleFile) throws -> IFSyntaxData {
        return try XCTUnwrap(IFSyntaxManager.data(for: file.storage))
    }

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    // MARK: - A new file

    func testANewFile() throws {
        let file = IFSingleFile()
        XCTAssertEqual(file.storage.string, "")
        XCTAssertFalse(IFSyntaxManager.isRegistered(file.storage))
        XCTAssertFalse(file.isReadOnly)
        XCTAssertEqual(file.initialSelectionRange, NSRange(location: 0, length: 0))
        XCTAssertEqual(try file.data(ofType: inform7SourceType), Data())
    }

    func testTheInitialSelectionRange() {
        let file = IFSingleFile()
        file.initialSelectionRange = NSRange(location: 35, length: 4)
        XCTAssertEqual(file.initialSelectionRange, NSRange(location: 35, length: 4))
    }

    // MARK: - Reading

    /// Inform 7 source and extensions are UTF-8, highlighted as Inform 7, with Inform 7's intelligence
    func testInform7Files() throws {
        let text = "\"Lampe à huile 🪔\" by Émilie\n\nThe Lamp Room is a room.\n"
        for typeName in [inform7SourceType, inform7ExtensionType, "org.inform-fiction.source.inform7"] {
            let file = try file(Data(text.utf8), ofType: typeName)
            XCTAssertEqual(file.storage.string, text, typeName)

            let data = try syntaxData(file)
            XCTAssertEqual(data.type, .inform7, typeName)
            XCTAssertEqual(data.name, "single file", typeName)
            XCTAssertTrue(data.undoManager === file.undoManager, typeName)
            XCTAssertTrue(data.intelligence is IFNaturalIntel, typeName)
        }
    }

    /// Inform 6 source, and Inform 6 headers, as in a project, are Latin-1, highlighted as Inform 6, with no
    /// intelligence
    func testInform6Files() throws {
        let latin1: [UInt8] = [0x21, 0x20, 0x43, 0x61, 0x66, 0xE9, 0x0A]  // "! Café\n"
        for typeName in [inform6SourceType, "org.inform-fiction.source.inform6", headerType] {
            let file = try file(Data(latin1), ofType: typeName)
            XCTAssertEqual(file.storage.string, "! Café\n", typeName)
            XCTAssertEqual(try syntaxData(file).type, .inform6, typeName)
            XCTAssertNil(try syntaxData(file).intelligence, typeName)
        }
    }

    /// Inform control language files are Latin-1, and not highlighted
    func testControlLanguageFiles() throws {
        let latin1: [UInt8] = [0x21, 0x20, 0x43, 0x61, 0x66, 0xE9, 0x0A]  // "! Café\n"
        for typeName in [controlLanguageType] {
            let file = try file(Data(latin1), ofType: typeName)
            XCTAssertEqual(file.storage.string, "! Café\n", typeName)
            XCTAssertEqual(try syntaxData(file).type, IFHighlightType(rawValue: 0), typeName)
            XCTAssertNil(try syntaxData(file).intelligence, typeName)
        }
    }

    /// An Inform 7 file that isn't UTF-8 is read as Latin-1, rather than not at all
    func testAnInform7FileThatIsntUTF8() throws {
        let file = try file(Data([0x43, 0x61, 0x66, 0xE9]), ofType: inform7SourceType)  // "Café" in Latin-1
        XCTAssertEqual(file.storage.string, "Café")
        XCTAssertEqual(try syntaxData(file).type, .inform7)
    }

    // MARK: - Writing

    /// A file is written in the encoding it was read in
    func testWritingInTheFilesEncoding() throws {
        let utf8 = try file(Data("Café 🪔".utf8), ofType: inform7SourceType)
        utf8.storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Le ")
        XCTAssertEqual(try utf8.data(ofType: inform7SourceType), Data("Le Café 🪔".utf8))

        let latin1 = try file(Data([0x43, 0x61, 0x66, 0xE9]), ofType: inform6SourceType)
        latin1.storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Le ")
        XCTAssertEqual(try latin1.data(ofType: inform6SourceType), Data([0x4C, 0x65, 0x20, 0x43, 0x61, 0x66, 0xE9]))

        // An Inform 7 file read as Latin-1 is written as Latin-1
        let fallback = try file(Data([0x43, 0x61, 0x66, 0xE9]), ofType: inform7SourceType)
        XCTAssertEqual(try fallback.data(ofType: inform7SourceType), Data([0x43, 0x61, 0x66, 0xE9]))
    }

    /// A file opened from disk has the text of the file, and saving it writes the text back
    func testOpeningAndSaving() throws {
        let url = try makeFolder().appendingPathComponent("Lamps.i7x")
        try Data("Lamps by Emily Short begins here.\n".utf8).write(to: url)

        let file = try IFSingleFile(contentsOf: url, ofType: inform7ExtensionType)
        XCTAssertEqual(file.storage.string, "Lamps by Emily Short begins here.\n")
        XCTAssertEqual(file.fileURL, url)

        file.storage.replaceCharacters(in: NSRange(location: file.storage.length, length: 0),
                                       with: "\nLamps ends here.\n")
        try file.write(to: url, ofType: inform7ExtensionType)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       "Lamps by Emily Short begins here.\n\nLamps ends here.\n")
    }

    /// Text the file's encoding can't hold, such as an emoji in Inform 6 source, can't be saved, and the error says
    /// so, where there was none; the file on disk is left as it was
    func testSavingWhatTheEncodingCantHold() throws {
        let url = try makeFolder().appendingPathComponent("Café.inf")
        try Data([0x43, 0x61, 0x66, 0xE9]).write(to: url)  // "Café" in Latin-1
        let file = try IFSingleFile(contentsOf: url, ofType: inform6SourceType)
        file.storage.replaceCharacters(in: NSRange(location: 4, length: 0), with: " 🪔")

        let isEncodingError = { (error: Error) in
            let error = error as NSError
            XCTAssertEqual(error.domain, NSCocoaErrorDomain)
            XCTAssertEqual(error.code, NSFileWriteInapplicableStringEncodingError)
            XCTAssertEqual(error.userInfo[NSStringEncodingErrorKey] as? UInt, String.Encoding.isoLatin1.rawValue)
        }
        XCTAssertThrowsError(try file.data(ofType: inform6SourceType), "", isEncodingError)
        XCTAssertThrowsError(try file.write(to: url, ofType: inform6SourceType), "", isEncodingError)
        XCTAssertEqual(try Data(contentsOf: url), Data([0x43, 0x61, 0x66, 0xE9]))
    }

    // MARK: - Reverting

    /// Revert To Saved gives the text the window shows the saved text, so what's edited after it is what's saved
    func testRevertingToSaved() throws {
        let url = try makeFolder().appendingPathComponent("Lamps.i7x")
        try Data("Lamps by Emily Short begins here.\n".utf8).write(to: url)

        let file = try IFSingleFile(contentsOf: url, ofType: inform7ExtensionType)
        let shown = file.storage
        shown.replaceCharacters(in: NSRange(location: 0, length: shown.length), with: "Not saved.\n")

        try file.revert(toContentsOf: url, ofType: inform7ExtensionType)
        XCTAssertTrue(file.storage === shown)
        XCTAssertEqual(shown.string, "Lamps by Emily Short begins here.\n")
        XCTAssertEqual(try syntaxData(file).type, .inform7)

        shown.replaceCharacters(in: NSRange(location: shown.length, length: 0), with: "\nLamps ends here.\n")
        XCTAssertEqual(try file.data(ofType: inform7ExtensionType),
                       Data("Lamps by Emily Short begins here.\n\nLamps ends here.\n".utf8))
    }

    /// Reverting to a file changed on disk reads it as a file is first read: its line endings are made Unix ones,
    /// and one that isn't UTF-8 is read, and written, as Latin-1
    func testRevertingToAChangedFile() throws {
        let url = try makeFolder().appendingPathComponent("Lamps.i7x")
        try Data("Lamps by Emily Short begins here.\n".utf8).write(to: url)
        let file = try IFSingleFile(contentsOf: url, ofType: inform7ExtensionType)
        let shown = file.storage

        try Data("Lamps by Emily Short begins here.\r\n\r\nLamps ends here.\r\n".utf8).write(to: url)
        try file.revert(toContentsOf: url, ofType: inform7ExtensionType)
        XCTAssertEqual(shown.string, "Lamps by Emily Short begins here.\n\nLamps ends here.\n")

        try Data([0x43, 0x61, 0x66, 0xE9]).write(to: url)  // "Café" in Latin-1
        try file.revert(toContentsOf: url, ofType: inform7ExtensionType)
        XCTAssertEqual(shown.string, "Café")
        XCTAssertEqual(try file.data(ofType: inform7ExtensionType), Data([0x43, 0x61, 0x66, 0xE9]))
    }

    // MARK: - Letting go

    /// The file's text storage stops being highlighted when the file is let go
    func testTheStorageIsUnregisteredWithTheFile() throws {
        var storage: NSTextStorage!
        weak var gone: IFSingleFile?
        try autoreleasepool {
            let file = try file(Data("The Lamp Room is a room.\n".utf8), ofType: inform7SourceType)
            storage = file.storage
            gone = file
            XCTAssertTrue(IFSyntaxManager.isRegistered(storage))
        }

        let freed = expectation(for: NSPredicate { _, _ in gone == nil }, evaluatedWith: nil)
        wait(for: [freed], timeout: 5)
        XCTAssertFalse(IFSyntaxManager.isRegistered(storage))
    }

    /// Closing the file stops its text storage being highlighted at once, as a project's texts are as it closes
    func testClosingUnregistersTheStorage() throws {
        let file = try file(Data("The Lamp Room is a room.\n".utf8), ofType: inform7SourceType)
        XCTAssertTrue(IFSyntaxManager.isRegistered(file.storage))

        file.close()

        XCTAssertFalse(IFSyntaxManager.isRegistered(file.storage))
    }

    /// NSDocument can let go of a file on another thread after it has closed, which mustn't stop the app
    func testAClosedFileCanBeLetGoOfOnAnotherThread() throws {
        nonisolated(unsafe) var file: IFSingleFile?
        var storage: NSTextStorage!
        weak var gone: IFSingleFile?
        try autoreleasepool {
            let made = try self.file(Data("The Lamp Room is a room.\n".utf8), ofType: inform7SourceType)
            made.close()
            storage = made.storage
            gone = made
            file = made
        }

        let done = expectation(description: "The file was let go of on another thread")
        DispatchQueue.global().async {
            file = nil
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertNil(file)
        XCTAssertNil(gone)
        XCTAssertFalse(IFSyntaxManager.isRegistered(storage))
    }

    // MARK: - Read-only files

    /// The extensions built into the app are read-only, and can't be saved
    func testTheAppsExtensionsAreReadOnly() throws {
        let appExtensions = IFUtility.path(forInformInternalExtensions: "")
        let save = NSMenuItem(title: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "")

        let builtIn = IFSingleFile()
        builtIn.fileURL = URL(fileURLWithPath: appExtensions + "/Graham Nelson/Basic Inform.i7x")
        XCTAssertTrue(builtIn.isReadOnly)
        XCTAssertFalse(builtIn.validateMenuItem(save))

        // The path is compared without regard to case, once it's standardised
        let otherCase = IFSingleFile()
        otherCase.fileURL = URL(fileURLWithPath: appExtensions.uppercased() + "/../Extensions/Graham Nelson/Basic Inform.i7x")
        XCTAssertTrue(otherCase.isReadOnly)

        let elsewhere = IFSingleFile()
        elsewhere.fileURL = try makeFolder().appendingPathComponent("Lamps.i7x")
        XCTAssertFalse(elsewhere.isReadOnly)
        XCTAssertTrue(elsewhere.validateMenuItem(save))

        // A file that has never been saved isn't read-only
        XCTAssertFalse(IFSingleFile().isReadOnly)
        XCTAssertTrue(IFSingleFile().validateMenuItem(save))
    }
}
