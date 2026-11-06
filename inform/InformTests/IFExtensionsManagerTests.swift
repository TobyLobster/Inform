//
//  IFExtensionsManagerTests.swift
//  InformTests
//

import Network
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

    /// Reads inbuild's census, as the manager does for projects after 6M62
    private func census(_ json: String?) -> [IFExtensionInfo] {
        return manager.parseExtensionsList(json) as? [IFExtensionInfo] ?? []
    }

    private func info(_ title: String, _ filepath: String?, by author: String = "Emily Short", version: String?) -> IFExtensionInfo {
        return IFExtensionInfo(displayName: title, filepath: filepath, author: author, version: version, isBuiltIn: false)
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

    func testReadsACensusEntryWithNothingButItsFileInIt() {
        XCTAssertEqual(census(#"{ "inspection": [ { "resource": { "type": "extension" }, "location-file": "/Extension.i7x" } ] }"#),
                       [IFExtensionInfo(displayName: "", filepath: "/Extension.i7x", author: "", version: "", isBuiltIn: false)])
    }

    /// Makes an empty file, and the folders it's in
    @discardableResult
    private func make(_ path: String, in folder: URL) throws -> String {
        let file = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        return file.path
    }

    /// The census of an extension that's a folder, as inbuild gives it: by its folder, not by a file
    private func census(ofFolder folder: URL, title: String) throws -> [IFExtensionInfo] {
        let entry: [String: Any] = ["resource": ["type": "extension", "title": title, "author": "Emily Short", "version": "1"],
                                    "location-directory": folder.path]
        let json = try JSONSerialization.data(withJSONObject: ["inspection": [entry]])
        return census(String(data: json, encoding: .utf8))
    }

    /// An extension that's a folder has the file inbuild reads, named after its title, whatever the folder is called
    func testAnExtensionThatsAFolderHasItsTitlesFile() throws {
        let folder = try makeFolder().appendingPathComponent("Keys-v1.i7xd")
        let keys = try make("Source/Keys.i7x", in: folder)
        try make("Source/Contents.w", in: folder)
        try make("Source/Another.i7x", in: folder)
        try make("Documentation/Documentation.md", in: folder)

        XCTAssertEqual(try census(ofFolder: folder, title: "Keys"), [info("Keys", keys, version: "v1")])
    }

    /// A literate extension has its contents, as its sections are read from there
    func testALiterateExtensionHasItsContents() throws {
        let folder = try makeFolder().appendingPathComponent("Keys-v1.i7xd")
        let contents = try make("Source/Contents.w", in: folder)
        try make("Source/Sections/Preamble.w", in: folder)
        try make("Source/Another.i7x", in: folder)

        XCTAssertEqual(try census(ofFolder: folder, title: "Keys"), [info("Keys", contents, version: "v1")])
    }

    /// Failing those, inbuild reads the first extension file in the source folder, without case mattering
    func testOtherwiseAFolderExtensionHasItsFirstFile() throws {
        let folder = try makeFolder().appendingPathComponent("Keys-v1.i7xd")
        try make("Source/b.i7x", in: folder)
        let first = try make("Source/A Name.I7X", in: folder)
        try make("Source/C.i7x", in: folder)
        try make("Source/.Hidden.i7x", in: folder)
        try make("Source/0 Notes.txt", in: folder)
        try make("Source/0 Folder.i7x/Inside.i7x", in: folder)

        XCTAssertEqual(try census(ofFolder: folder, title: "Keys"), [info("Keys", first, version: "v1")])
    }

    /// There's nothing to open or search in an extension with no file, so it isn't listed
    func testAnExtensionWithNoFileIsLeftOut() throws {
        let folder = try makeFolder().appendingPathComponent("Keys-v1.i7xd")
        XCTAssertEqual(try census(ofFolder: folder, title: "Keys"), [])
        try make("extension_metadata.json", in: folder)
        try make("Source/Sections/Preamble.w", in: folder)
        try make("Source/Notes.txt", in: folder)
        XCTAssertEqual(try census(ofFolder: folder, title: "Keys"), [])

        XCTAssertEqual(census(#"{ "inspection": [ { "resource": { "type": "extension", "title": "Keys" } } ] }"#), [])
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

    // MARK: - Installed extensions

    /// The extensions folder in Inform's Application Support, which only tests in their own home write in.
    /// It's removed after the test, and the manager's lists are made again.
    private func makeExtensionsFolder() throws -> String {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let folder = IFUtility.pathForInformExternalExtensions()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder))
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        IFExtensionsManager.sharedNaturalInform.dirtyCache()
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: folder)
            IFExtensionsManager.sharedNaturalInform.dirtyCache()
        }
        return folder
    }

    /// Writes an extension that starts with the given line, in a folder of the extensions folder
    @discardableResult
    private func put(_ firstLine: String, _ name: String, in authorFolder: String, of folder: String) throws -> String {
        let directory = (folder as NSString).appendingPathComponent(authorFolder)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let file = (directory as NSString).appendingPathComponent(name)
        try (firstLine + "\n\n" + "Something ends here.\n").write(toFile: file, atomically: true, encoding: .utf8)
        return file
    }

    /// For 6M62 and earlier, the extensions are the files in each author's folder whose first lines say what they are
    func testListsTheExtensionsInEachAuthorsFolder() throws {
        let folder = try makeExtensionsFolder()
        let locksmith = try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        let keys = try put("Keys by Emily Short begins here.", "Keys", in: "Emily Short", of: folder)
        let parser = try put("Unicode Parser by Andrew Plotkin begins here.", "Unicode Parser.I7X", in: "Andrew Plotkin", of: folder)
        // The author is the one on the first line
        let clock = try put("Clock by Jane Doe begins here.", "Clock.i7x", in: "Misfiled", of: folder)

        // None of these is listed
        try put("Notes by Emily Short begins here.", "Notes.txt", in: "Emily Short", of: folder)
        try put("Hidden by Emily Short begins here.", ".Hidden.i7x", in: "Emily Short", of: folder)
        try put("Not an extension", "Broken.i7x", in: "Emily Short", of: folder)
        try put("Secret by Emily Short begins here.", "Secret.i7x", in: "Reserved", of: folder)
        try put("Secret by Emily Short begins here.", "Secret.i7x", in: ".Hidden", of: folder)
        try put("Loose by Emily Short begins here.", "Loose.i7x", in: "", of: folder)

        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "6M62")),
                       [info("Locksmith", locksmith, version: "Version 3"),
                        info("Keys", keys, version: nil),
                        info("Unicode Parser", parser, by: "Andrew Plotkin", version: nil),
                        info("Clock", clock, by: "Jane Doe", version: nil)])

        // Sorted, without case mattering
        XCTAssertEqual(manager.availableAuthors(withCompilerVersion: "6M62"), ["Andrew Plotkin", "Emily Short", "Jane Doe"])
        XCTAssertEqual(manager.availableExtensions(byAuthor: "EMILY SHORT", withCompilerVersion: "6M62"),
                       [info("Keys", keys, version: nil), info("Locksmith", locksmith, version: "Version 3")])
        XCTAssertEqual(manager.availableExtensions(byAuthor: "Graham Nelson", withCompilerVersion: "6M62"), [])
    }

    /// The list is kept until the cache is dirtied. Each time it's made, anything that wants to know is told.
    func testKeepsTheListUntilItsCacheIsDirtied() throws {
        let folder = try makeExtensionsFolder()
        let locksmith = try put("Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        var told = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFCensusFinished, object: manager, queue: nil) { _ in
            told += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6M62"), [info("Locksmith", locksmith, version: nil)])
        XCTAssertEqual(told, 1)

        let keys = try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6M62"), [info("Locksmith", locksmith, version: nil)])
        XCTAssertEqual(manager.availableAuthors(withCompilerVersion: "6M62"), ["Emily Short"])
        XCTAssertEqual(told, 1)

        manager.dirtyCache()
        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "6M62")),
                       [info("Locksmith", locksmith, version: nil), info("Keys", keys, version: nil)])
        XCTAssertEqual(told, 2)
    }

    /// After 6M62, the list is inbuild's census of the extensions folder
    func testListsInbuildsCensusAfter6M62() throws {
        let folder = try makeExtensionsFolder()
        let locksmith = try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        let keys = try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        // An extension that's a folder, which inbuild gives by its folder
        let doors = try put("Version 2 of Doors by Emily Short begins here.", "Doors.i7x", in: "Emily Short/Doors-v2.i7xd/Source", of: folder)
        try #"{ "is": { "type": "extension", "title": "Doors", "author": "Emily Short", "version": "2" } }"#
            .write(toFile: (folder as NSString).appendingPathComponent("Emily Short/Doors-v2.i7xd/extension_metadata.json"),
                   atomically: true, encoding: .utf8)

        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "10.1")),
                       [info("Locksmith", locksmith, version: "v3"), info("Keys", keys, version: ""), info("Doors", doors, version: "v2")])
    }

    /// Find in Files searches a literate extension's sections, as well as its contents page
    /// Writes a literate extension, with one section, as a folder in the extensions folder, and gives its contents page
    @discardableResult
    private func putLiterate(_ title: String, by author: String, of folder: String, saying text: String = "") throws -> String {
        let extensionFolder = (folder as NSString).appendingPathComponent("\(author)/\(title)-v1.i7xd")
        let contents = (extensionFolder as NSString).appendingPathComponent("Source/Contents.w")
        let preamble = (extensionFolder as NSString).appendingPathComponent("Source/Sections/Preamble.w")
        try FileManager.default.createDirectory(atPath: (preamble as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try #"{ "is": { "type": "extension", "title": "\#(title)", "author": "\#(author)", "version": "1" } }"#
            .write(toFile: (extensionFolder as NSString).appendingPathComponent("extension_metadata.json"), atomically: true, encoding: .utf8)
        try "Version 1 of \(title) by \(author)\n\nSections\n\tPreamble\n".write(toFile: contents, atomically: true, encoding: .utf8)
        try "Preamble.\n\n@h \(title).\n\n=\n\(text)\n".write(toFile: preamble, atomically: true, encoding: .utf8)
        return contents
    }

    func testFindInFilesSearchesALiterateExtensionsSections() throws {
        let folder = try makeExtensionsFolder()
        let contents = try putLiterate("Lamps", by: "Emily Short", of: folder, saying: "A lamp is a kind of thing.")
        let preamble = ((contents as NSString).deletingLastPathComponent as NSString).appendingPathComponent("Sections/Preamble.w")
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "10.1"), [info("Lamps", contents, version: "v1")])

        let project = IFProject()
        project.settings.compilerVersion = "10.1"
        let finder = IFFindInFiles()
        let finished = expectation(description: "The search finishes")
        finder.start(withPhrase: "Lamp", withSearch: .contains, from: project, withLocations: .extensions) { num, total, _ in
            if num == total {
                finished.fulfill()
            }
        }
        wait(for: [finished], timeout: 10)

        XCTAssertEqual(Set(finder.results.compactMap(\.filepath)), [contents, preamble])
    }

    /// The Extensions menu opens each extension, but only makes a project from one that's kept in one file
    func testTheMenuMakesNoProjectFromALiterateExtension() throws {
        let folder = try makeExtensionsFolder()
        try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        try putLiterate("Lamps", by: "Emily Short", of: folder)
        try putLiterate("Clock", by: "Jane Doe", of: folder)

        let delegate = try XCTUnwrap(NSApp.delegate as? IFAppDelegate)
        delegate.updateExtensionsMenu(forCompilerVersion: "10.1")

        /// The items in the app's menus that do something
        func items(_ action: String) -> [NSMenuItem] {
            func found(in menu: NSMenu) -> [NSMenuItem] {
                return menu.items.flatMap { item in
                    (item.action == Selector((action)) ? [item] : []) + (item.submenu.map(found(in:)) ?? [])
                }
            }
            return NSApp.mainMenu.map(found(in:)) ?? []
        }
        /// The extensions in some items, by the author whose menu they're in
        func extensions(_ items: [NSMenuItem]) -> [String: [String]] {
            return Dictionary(grouping: items, by: { $0.menu?.title ?? "" }).mapValues { items in
                items.map { String(($0.attributedTitle?.string ?? "").prefix { $0 != "\t" }) }
            }
        }

        XCTAssertEqual(extensions(items("openExtension:")), ["Emily Short": ["Keys", "Lamps"], "Jane Doe": ["Clock"]])
        let newProjectItems = items("newExtensionProject:")
        XCTAssertEqual(extensions(newProjectItems.filter { $0.tag >= 0 }), ["Emily Short": ["Keys"]])

        // An author with only literate extensions has no menu for making a project
        let newExtension = try XCTUnwrap(newProjectItems.first { $0.tag == -1 })
        let createFromInstalled = try XCTUnwrap(newExtension.menu?.items.compactMap(\.submenu).first)
        XCTAssertEqual(createFromInstalled.items.map(\.title), ["Emily Short"])
    }

    /// Projects for 6M62 and earlier, and later ones, each get their own list, whichever asks first
    func testKeepsAListForEachKindOfProject() throws {
        let folder = try makeExtensionsFolder()
        let locksmith = try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        var told = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFCensusFinished, object: manager, queue: nil) { _ in
            told += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6M62"), [info("Locksmith", locksmith, version: "Version 3")])
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "10.1"), [info("Locksmith", locksmith, version: "v3")])
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6L38"), [info("Locksmith", locksmith, version: "Version 3")])
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "10.2"), [info("Locksmith", locksmith, version: "v3")])
        XCTAssertEqual(told, 2)

        // Dirtying the cache makes both again
        let keys = try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        manager.dirtyCache()
        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "10.1")),
                       [info("Locksmith", locksmith, version: "v3"), info("Keys", keys, version: "")])
        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "6M62")),
                       [info("Locksmith", locksmith, version: "Version 3"), info("Keys", keys, version: nil)])
        XCTAssertEqual(told, 4)
    }

    /// The files in an author's folders, by name, which a link to an extension is looked for in
    func testListsTheFilesInAnAuthorsFolders() throws {
        let yours = (IFUtility.pathForInformExternalExtensions() as NSString).appendingPathComponent("Graham Nelson")
        try XCTSkipIf(FileManager.default.fileExists(atPath: yours), "Has extensions by Graham Nelson of your own")
        let app = (IFUtility.path(forInformInternalExtensions: "") as NSString).appendingPathComponent("Graham Nelson")

        // (In Debug, the app's extensions are those in Inform Core, which may have others)
        let files = manager.filesInExtension(withName: "GRAHAM NELSON")
        XCTAssertTrue(Set(files).isSuperset(of: ["Basic Inform.i7xd", "English Language.i7xd", "Standard Rules.i7xd"].map {
            (app as NSString).appendingPathComponent($0)
        }), "\(files)")
        XCTAssertEqual(manager.filesInExtension(withName: "Nobody"), [])
    }

    func testListsTheFilesInAnAuthorsFoldersOfYourOwn() throws {
        let folder = try makeExtensionsFolder()
        let locksmith = try put("Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        let keys = try put("Keys by Emily Short begins here.", "keys.i7x", in: "Emily Short", of: folder)
        let notes = try put("Notes", "Notes.txt", in: "Emily Short", of: folder)

        XCTAssertEqual(manager.filesInExtension(withName: "emily short"), [keys, locksmith, notes])
    }

    /// Your own file comes before the app's of the same name, as your extension does for the compiler
    func testYourOwnFilesComeBeforeTheApps() throws {
        let folder = try makeExtensionsFolder()
        let yours = try put("Basic Inform by Graham Nelson begins here.", "basic inform.i7xd", in: "Graham Nelson", of: folder)
        let app = (IFUtility.path(forInformInternalExtensions: "") as NSString).appendingPathComponent("Graham Nelson")

        let files = manager.filesInExtension(withName: "Graham Nelson")
        XCTAssertTrue(files.contains(yours), "\(files)")
        XCTAssertFalse(files.contains((app as NSString).appendingPathComponent("Basic Inform.i7xd")), "\(files)")
        XCTAssertTrue(files.contains((app as NSString).appendingPathComponent("Standard Rules.i7xd")), "\(files)")
    }

    // MARK: - Installing a legacy extension

    private struct Installed {
        let result: IFExtensionResult
        let finalPath: String?
        let title: String?
        let author: String?
        let version: String?
    }

    private func install(_ file: String) -> Installed {
        var finalPath: NSString?
        var title: NSString?
        var author: NSString?
        var version: NSString?
        let result = manager.installLegacyExtension(file, finalPath: &finalPath, title: &title, author: &author, version: &version,
                                                    showWarningPrompts: false, notify: false)
        return Installed(result: result, finalPath: finalPath as String?, title: title as String?,
                         author: author as String?, version: version as String?)
    }

    func testInstallsALegacyExtensionInItsAuthorsFolder() throws {
        let folder = try makeExtensionsFolder()
        let file = try write(firstLine: "Version 2 of The Locksmith by Emily Short begins here.")

        let installed = install(file.path)
        let destination = (folder as NSString).appendingPathComponent("Emily Short/Locksmith.i7x")
        XCTAssertEqual(installed.result, .success)
        XCTAssertEqual(installed.finalPath, destination)
        XCTAssertEqual(installed.title, "Locksmith")
        XCTAssertEqual(installed.author, "Emily Short")
        XCTAssertEqual(installed.version, "Version 2")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: destination)), try Data(contentsOf: file))

        // The list is made again
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6M62"), [info("Locksmith", destination, version: "Version 2")])
    }

    /// Without the warnings, an extension replaces the one installed, and an old copy with no .i7x
    func testReplacesALegacyExtension() throws {
        let folder = try makeExtensionsFolder()
        let installed = try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        let old = try put("Version 1 of Locksmith by Emily Short begins here.", "Locksmith", in: "Emily Short", of: folder)
        let file = try write(firstLine: "Version 2 of Locksmith by Emily Short begins here.")

        XCTAssertEqual(install(file.path).result, .success)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: installed)), try Data(contentsOf: file))
        XCTAssertFalse(FileManager.default.fileExists(atPath: old))
    }

    func testShortensALongTitleForItsFile() throws {
        let folder = try makeExtensionsFolder()
        let title = String(repeating: "Lock", count: 15)
        let file = try write(firstLine: "\(title) by Emily Short begins here.")

        let installed = install(file.path)
        XCTAssertEqual(installed.result, .success)
        XCTAssertEqual(installed.title, title)
        XCTAssertEqual(installed.finalPath, (folder as NSString).appendingPathComponent("Emily Short/" + title.prefix(50) + ".i7x"))
    }

    func testDoesntInstallWhatIsntAnExtension() throws {
        _ = try makeExtensionsFolder()
        let folder = try makeFolder()

        XCTAssertEqual(install(folder.appendingPathComponent("Missing.i7x").path).result, .notFound)
        XCTAssertEqual(install(folder.path).result, .notFound)

        let notValid = install(try write(firstLine: "Locksmith begins here.").path)
        XCTAssertEqual(notValid.result, .notValid)
        XCTAssertNil(notValid.finalPath)
        XCTAssertNil(notValid.title)
        XCTAssertEqual(manager.availableExtensions(withCompilerVersion: "6M62"), [])
    }

    /// Installing a legacy extension takes the census, which documents the installed extensions
    /// in Inform's Application Support, where a 6M62 project's Extensions page reads them
    func testInstallingALegacyExtensionDocumentsIt() throws {
        _ = try makeExtensionsFolder()
        let documentation = IFUtility.pathForInformExternalDocumentation() as NSString
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: documentation as String)
        }
        let file = try write(firstLine: "Lamplighting by Jane Doe begins here.")

        // The census runs in the background, and says when it's finished
        let finished = expectation(forNotification: .IFCensusFinishedButDontUpdateExtensionsWebPage, object: nil)
        XCTAssertEqual(install(file.path).result, .success)
        wait(for: [finished], timeout: 30)

        let installed = try String(contentsOfFile: documentation.appendingPathComponent("Extensions.html"), encoding: .utf8)
        XCTAssertTrue(installed.contains("Lamplighting by Jane Doe"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentation.appendingPathComponent("Extensions/Jane Doe/Lamplighting.html")))
    }

    // MARK: - Downloading extensions

    /// Stands in for a project's controller, which shows the manager's progress, is given each extension
    /// downloaded for its project to install, and is told of each extension installed
    private final class ProjectControllerSpy: IFProjectController {
        var shown: [IFProgress] = []
        var removed: [(progress: IFProgress, message: String?)] = []
        var installing: [URL] = []
        var updated: [String?] = []
        /// The project, which the controller doesn't keep
        var project: IFProject?

        /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
        override var window: NSWindow? {
            get {
                return nil
            }
            set {
            }
        }

        override func addProgressIndicator(_ indicator: IFProgress) {
            shown.append(indicator)
        }

        /// Only the progress shown here: the manager takes away its last progress from the next controller it shows one in
        override func removeProgressIndicator(_ indicator: IFProgress) {
            if shown.contains(where: { $0 === indicator }) {
                removed.append((indicator, indicator.message))
            }
        }

        override func installExtensionURL(_ extensionURL: URL) {
            installing.append(extensionURL)
        }

        override func extensionUpdated(_ javascriptId: String?) {
            updated.append(javascriptId)
        }
    }

    /// With no window, a controller can't take changes to the project's intelligence or settings, so it isn't told of them
    private func makeController() -> ProjectControllerSpy {
        let controller = ProjectControllerSpy()
        NotificationCenter.default.removeObserver(controller)
        return controller
    }

    /// The controller of a project in the folder, which isn't open
    private func makeController(ofProjectIn folder: URL) -> ProjectControllerSpy {
        let controller = makeController()
        let project = IFProject()
        project.fileURL = folder.appendingPathComponent("Test.inform")
        controller.project = project
        controller.document = project
        return controller
    }

    /// A zip of an extension folder named after it, as the Public Library's are
    private func zipOfExtension(_ title: String, in folder: URL) throws -> URL {
        let source = folder.appendingPathComponent(title + ".i7xd/Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("\(title) by Emily Short begins here.\n".utf8).write(to: source.appendingPathComponent(title + ".i7x"))
        let zipURL = folder.appendingPathComponent(title + ".zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = folder
        zip.arguments = ["-q", "-r", zipURL.path, title + ".i7xd"]
        try zip.run()
        zip.waitUntilExit()
        XCTAssertEqual(zip.terminationStatus, 0)
        return zipURL
    }

    private func waitForTheProgressToGo(from controller: ProjectControllerSpy) {
        let removed = expectation(for: NSPredicate { _, _ in !controller.removed.isEmpty }, evaluatedWith: nil)
        wait(for: [removed], timeout: 10)
    }

    /// Waits long enough for the next download in the queue to have started and finished, if it was going to
    private func waitForAnyMoreDownloads() {
        let waited = expectation(description: "Waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { waited.fulfill() }
        wait(for: [waited], timeout: 5)
    }

    private func installed(_ done: Int32, of total: Int32) -> String {
        return String(format: IFUtility.localizedString("Installed %d of %d"), done, total)
    }

    private func installed(_ done: Int32, of total: Int32, failed: Int32) -> String {
        return String(format: IFUtility.localizedString("Installed %d of %d (%d failed)"), done, total, failed)
    }

    /// Downloads go one at a time, under one progress, and each is installed in the project it was downloaded for
    func testDownloadsOneAfterAnother() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        // No project is open, so none is in front
        XCTAssertFalse(NSDocumentController.shared.documents.contains { $0 is IFProject })
        let folder = try makeFolder()
        let locksmith = try zipOfExtension("Locksmith", in: folder)
        let keys = try zipOfExtension("Keys", in: folder)
        let controller = makeController(ofProjectIn: folder)

        XCTAssertTrue(manager.downloadAndInstallExtension(locksmith, window: nil, notifyDelegate: controller, javascriptId: "1"))
        XCTAssertTrue(manager.downloadAndInstallExtension(keys, window: nil, notifyDelegate: controller, javascriptId: "2"))
        XCTAssertEqual(controller.shown.count, 1)
        let progress = try XCTUnwrap(controller.shown.first)
        XCTAssertEqual(progress.message, IFUtility.localizedString("Installing extension"))
        XCTAssertTrue(progress.isInProgress)

        waitForTheProgressToGo(from: controller)
        waitForAnyMoreDownloads()
        XCTAssertEqual(controller.removed.count, 1)
        XCTAssertTrue(controller.removed.first?.progress === progress)
        XCTAssertEqual(controller.removed.first?.message, installed(2, of: 2))
        XCTAssertFalse(progress.isInProgress)
        // Each is unzipped in the project's materials, and given to its controller to install
        let temporary = folder.appendingPathComponent("Test.materials/Extensions/Reserved/Temporary")
        XCTAssertEqual(controller.installing.map(\.standardizedFileURL),
                       [temporary.appendingPathComponent("Locksmith.i7xd").standardizedFileURL,
                        temporary.appendingPathComponent("Keys.i7xd").standardizedFileURL])
        XCTAssertEqual(controller.updated, ["1", "2"])
    }

    /// Cancelling the progress stops the downloads still to come, and nothing is reported
    func testCancellingStopsTheDownloads() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let folder = try makeFolder()
        let keys = folder.appendingPathComponent("Keys.zip")
        try Data("Not really a zip file".utf8).write(to: keys)
        let controller = makeController()

        XCTAssertTrue(manager.downloadAndInstallExtension(folder.appendingPathComponent("Missing.zip"),
                                                          window: nil, notifyDelegate: controller, javascriptId: "1"))
        XCTAssertTrue(manager.downloadAndInstallExtension(keys, window: nil, notifyDelegate: controller, javascriptId: "2"))
        let progress = try XCTUnwrap(controller.shown.first)
        progress.cancel()

        waitForTheProgressToGo(from: controller)
        waitForAnyMoreDownloads()
        XCTAssertEqual(controller.removed.count, 1)
        XCTAssertEqual(controller.removed.first?.message, installed(0, of: 2, failed: 1))
    }

    /// A server, only on this Mac, that answers each request with "not found"
    private final class NotFoundServer {
        private let listener: NWListener
        private let queue = DispatchQueue(label: "NotFoundServer")
        private let lock = NSLock()
        private var count = 0
        private(set) var url: URL?

        var requests: Int {
            return lock.withLock { count }
        }

        init(path: String) throws {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            listener = try NWListener(using: parameters)

            let ready = DispatchSemaphore(value: 0)
            listener.stateUpdateHandler = { state in
                if case .ready = state {
                    ready.signal()
                }
            }
            listener.newConnectionHandler = { [lock, queue] connection in
                connection.start(queue: queue)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, _, _ in
                    lock.withLock { self?.count += 1 }
                    let reply = "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nNot found"
                    connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
                }
            }
            listener.start(queue: queue)

            if ready.wait(timeout: .now() + 5) == .success, let port = listener.port {
                url = URL(string: "http://127.0.0.1:\(port.rawValue)/\(path)")
            }
        }

        deinit {
            listener.cancel()
        }
    }

    /// The download is cancelled once the server gives an error, and that's reported as the one failure
    func testAServersErrorIsReportedOnce() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let server = try NotFoundServer(path: "Locksmith.zip")
        let url = try XCTUnwrap(server.url)
        let controller = makeController()

        XCTAssertTrue(manager.downloadAndInstallExtension(url, window: nil, notifyDelegate: controller, javascriptId: "1"))
        // Cancelled, so that nothing is reported in an alert
        try XCTUnwrap(controller.shown.first).cancel()
        // The main thread is busy, as it may be in the app, while the server answers and the task is cancelled
        Thread.sleep(forTimeInterval: 1)

        waitForTheProgressToGo(from: controller)
        waitForAnyMoreDownloads()
        XCTAssertEqual(server.requests, 1)
        XCTAssertEqual(controller.removed.count, 1)
        XCTAssertEqual(controller.removed.first?.message, installed(0, of: 1, failed: 1))
    }

    /// A failure is reported in a sheet on the window of the page that started the download, but not once
    /// that's closed with its project, as the sheet would open it again
    func testAFailureIsntReportedOnAClosedWindow() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let folder = try makeFolder()
        // A window that was on screen, and has been closed, as a closed project's has
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        addTeardownBlock {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
            }
            window.orderOut(nil)
        }
        window.orderFrontRegardless()
        window.close()
        let controller = makeController()

        XCTAssertTrue(manager.downloadAndInstallExtension(folder.appendingPathComponent("Missing.zip"),
                                                          window: window, notifyDelegate: controller, javascriptId: "1"))
        waitForTheProgressToGo(from: controller)
        XCTAssertEqual(controller.removed.first?.message, installed(0, of: 1, failed: 1))

        // Give a sheet time to appear
        let waited = expectation(description: "Waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { waited.fulfill() }
        wait(for: [waited], timeout: 5)
        XCTAssertNil(window.attachedSheet)
        XCTAssertFalse(window.isVisible)
    }
}
