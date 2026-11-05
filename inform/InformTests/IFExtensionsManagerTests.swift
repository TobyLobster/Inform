//
//  IFExtensionsManagerTests.swift
//  InformTests
//

import XCTest

final class IFExtensionsManagerTests: XCTestCase {

    private struct FirstLine {
        let result: IFExtensionResult
        let author: String?
        let title: String?
        let version: String?
    }

    private var manager: IFExtensionsManager {
        return IFExtensionsManager.sharedNaturalInform
    }

    /// A new temporary folder, removed after the test
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// Writes an extension file that starts with the given line
    private func write(firstLine: String, lineEnding: String = "\n") throws -> URL {
        let file = try makeFolder().appendingPathComponent("Extension.i7x")
        let text = firstLine + lineEnding + lineEnding + "Include Basic Screen Effects by Emily Short." + lineEnding
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Reads an extension file that starts with the given line, as the extensions manager does
    /// for legacy extensions and for the extension in an extension project.
    private func read(firstLine: String, lineEnding: String = "\n") throws -> FirstLine {
        return read(try write(firstLine: firstLine, lineEnding: lineEnding))
    }

    private func read(_ file: URL) -> FirstLine {
        var author: NSString?
        var title: NSString?
        var version: NSString?
        let result = IFExtensionsManager.sharedNaturalInform
            .info(forNaturalInformExtension: file.path, author: &author, title: &title, version: &version)
        return FirstLine(result: result, author: author as String?, title: title as String?, version: version as String?)
    }

    func testReadsTheTitleAuthorAndVersion() throws {
        let line = try read(firstLine: "Version 2/090402 of The Locksmith Kit by Emily Short begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Locksmith Kit")
        XCTAssertEqual(line.author, "Emily Short")
        XCTAssertEqual(line.version, "Version 2/090402")
    }

    func testReadsAnExtensionWithNoVersion() throws {
        let line = try read(firstLine: "Locksmith by Emily Short begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Locksmith")
        XCTAssertEqual(line.author, "Emily Short")
        XCTAssertNil(line.version)
    }

    /// A title can start with "Version" without the extension having a version.
    func testReadsATitleThatStartsWithVersion() throws {
        let line = try read(firstLine: "Version Control by Jane Doe begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Version Control")
        XCTAssertEqual(line.author, "Jane Doe")
        XCTAssertNil(line.version)
    }

    func testReadsAFirstLineInAnyCaseAndSpacing() throws {
        let line = try read(firstLine: "\t VERSION 3 OF THE Locksmith BY Emily Short BEGINS HERE. ")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Locksmith")
        XCTAssertEqual(line.author, "Emily Short")
        XCTAssertEqual(line.version, "VERSION 3")
    }

    func testReadsAnyLineEnding() throws {
        for lineEnding in ["\n", "\r\n", "\r"] {
            let line = try read(firstLine: "Locksmith by Emily Short begins here.", lineEnding: lineEnding)
            XCTAssertEqual(line.result, .success, lineEnding.debugDescription)
            XCTAssertEqual(line.author, "Emily Short", lineEnding.debugDescription)
        }
    }

    /// Only the start of the file is read
    func testRejectsAFirstLineLongerThanItReads() throws {
        let line = try read(firstLine: String(repeating: "Long ", count: 210) + "Locksmith by Emily Short begins here.")
        XCTAssertEqual(line.result, .notValid)
    }

    /// The start that's read can end part way through a character
    func testReadsAFileWhoseStartEndsInACharacter() throws {
        let start = "Locksmith by Emily Short begins here.\n\n"
        let text = start + String(repeating: "-", count: 1023 - start.utf8.count) + "\u{E9} ends here.\n"
        let file = try makeFolder().appendingPathComponent("Extension.i7x")
        try text.write(to: file, atomically: true, encoding: .utf8)
        // The first byte of the two in é is the last byte read
        XCTAssertEqual(try Data(contentsOf: file)[1023], 0xC3)

        let line = read(file)
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.author, "Emily Short")
    }

    func testRejectsAFirstLineWithNoAuthor() throws {
        XCTAssertEqual(try read(firstLine: "Locksmith by  begins here.").result, .notValid)
    }

    func testClearsWhatItsGivenWhenItFails() throws {
        let file = try write(firstLine: "Locksmith begins here.")
        var author: NSString? = "Someone"
        var title: NSString? = "Something"
        var version: NSString? = "Version 1"

        XCTAssertEqual(manager.info(forNaturalInformExtension: file.path, author: &author, title: &title, version: &version),
                       .notValid)
        XCTAssertNil(author)
        XCTAssertNil(title)
        XCTAssertNil(version)
    }

    func testNeedsNowhereToPutWhatItReads() throws {
        let file = try write(firstLine: "Locksmith by Emily Short begins here.")
        XCTAssertEqual(manager.info(forNaturalInformExtension: file.path, author: nil, title: nil, version: nil), .success)
    }

    func testAFolderIsNotFound() throws {
        let folder = try makeFolder()
        XCTAssertEqual(manager.info(forNaturalInformExtension: folder.path, author: nil, title: nil, version: nil), .notFound)
    }

    func testRejectsAFileThatIsNotAnExtension() throws {
        XCTAssertEqual(try read(firstLine: "\"An Interactive Fiction\" by Jane Doe").result, .notValid)
        // Without an author
        XCTAssertEqual(try read(firstLine: "Locksmith begins here.").result, .notValid)

        var author: NSString?
        var title: NSString?
        var version: NSString?
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        XCTAssertEqual(IFExtensionsManager.sharedNaturalInform
            .info(forNaturalInformExtension: missing, author: &author, title: &title, version: &version), .notFound)
    }

    // MARK: - Inbuild's census

    /// Reads inbuild's census, as the manager does for projects after 6M62 (parseExtensionsList: isn't in the header)
    private func census(_ json: String?) -> [IFExtensionInfo] {
        let result = manager.perform(NSSelectorFromString("parseExtensionsList:"), with: json)?.takeUnretainedValue()
        return result as? [IFExtensionInfo] ?? []
    }

    private func info(_ title: String, _ filepath: String?, version: String) -> IFExtensionInfo {
        return IFExtensionInfo(displayName: title, filepath: filepath, author: "Emily Short", version: version, isBuiltIn: false)
    }

    func testReadsInbuildsCensus() {
        // As inbuild -inspect -recursive -contents-of ... -json - gives it, with some entries it doesn't give
        let infos = census("""
            {
                "inspection": [ {
                    "resource": {
                        "type": "extension",
                        "title": "Locksmith",
                        "author": "Emily Short",
                        "version": "3.1"
                    },
                    "location-file": "/Extensions/Emily Short/Locksmith.i7x"
                }, {
                    "resource": {
                        "type": "Extension",
                        "title": "Keys",
                        "author": "Emily Short"
                    },
                    "location-file": "/Extensions/Emily Short/Keys.i7x"
                }, {
                    "resource": {
                        "type": "project",
                        "title": "Notes.txt"
                    },
                    "location-file": "/Extensions/Emily Short/Notes.txt"
                },
                "Not an entry",
                { "resource": "Not a resource" }
                ]
            }
            """)

        XCTAssertEqual(infos, [info("Locksmith", "/Extensions/Emily Short/Locksmith.i7x", version: "v3.1"),
                               info("Keys", "/Extensions/Emily Short/Keys.i7x", version: "")])
    }

    func testReadsACensusEntryWithNothingInIt() {
        XCTAssertEqual(census(#"{ "inspection": [ { "resource": { "type": "extension" } } ] }"#),
                       [IFExtensionInfo(displayName: "", filepath: nil, author: "", version: "", isBuiltIn: false)])
    }

    /// inbuild gives an extension that's a folder by its folder, which isn't kept
    func testAnExtensionThatsAFolderHasNoFile() {
        let infos = census("""
            { "inspection": [ {
                "resource": { "type": "extension", "title": "Keys", "author": "Emily Short", "version": "1" },
                "location-directory": "/Extensions/Emily Short/Keys-v1.i7xd"
            } ] }
            """)
        XCTAssertEqual(infos, [info("Keys", nil, version: "v1")])
    }

    func testACensusItCantReadIsEmpty() {
        XCTAssertEqual(census("{"), [])
        XCTAssertEqual(census("[]"), [])
        XCTAssertEqual(census(#"{ "inspection": {} }"#), [])
        XCTAssertEqual(census(#"{ "other": [] }"#), [])
    }

    /// As when inbuild hasn't run, or its output wasn't UTF-8
    func testNoCensusIsEmpty() {
        XCTAssertEqual(census(nil), [])
    }

    // MARK: - The open panel

    func testTheOpenPanelOffersFoldersAndExtensionFiles() throws {
        let folder = try makeFolder()
        for name in ["Locksmith.i7x", "Keys.I7X", "Readme", "Notes.txt"] {
            try Data().write(to: folder.appendingPathComponent(name))
        }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Emily Short.txt"), withIntermediateDirectories: true)

        let delegate = manager as NSOpenSavePanelDelegate
        func offers(_ name: String) -> Bool? {
            return delegate.panel?(self, shouldEnable: folder.appendingPathComponent(name))
        }
        XCTAssertEqual(offers("Locksmith.i7x"), true)
        XCTAssertEqual(offers("Keys.I7X"), true)
        XCTAssertEqual(offers("Readme"), true)
        XCTAssertEqual(offers("Emily Short.txt"), true)
        XCTAssertEqual(offers("Notes.txt"), false)
        XCTAssertEqual(offers("Missing.i7x"), false)
    }
}
