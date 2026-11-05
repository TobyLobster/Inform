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

        XCTAssertEqual(Set(manager.availableExtensions(withCompilerVersion: "10.1")),
                       [info("Locksmith", locksmith, version: "v3"), info("Keys", keys, version: "")])
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

    // MARK: - Downloading extensions

    /// Stands in for a project's controller, which shows the manager's progress, and is told of each extension installed
    private final class ProjectControllerSpy: IFProjectController {
        var shown: [IFProgress] = []
        var removed: [(progress: IFProgress, message: String?)] = []
        var updated: [String?] = []

        override func addProgressIndicator(_ indicator: IFProgress) {
            shown.append(indicator)
        }

        /// Only the progress shown here: the manager takes away its last progress from the next controller it shows one in
        override func removeProgressIndicator(_ indicator: IFProgress) {
            if shown.contains(where: { $0 === indicator }) {
                removed.append((indicator, indicator.message))
            }
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

    /// Downloads go one at a time, under one progress. Without a project open, none can be installed.
    func testDownloadsOneAfterAnother() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        XCTAssertFalse(NSDocumentController.shared.documents.contains { $0 is IFProject })
        let folder = try makeFolder()
        let locksmith = folder.appendingPathComponent("Locksmith.zip")
        let keys = folder.appendingPathComponent("Keys.zip")
        try Data("Not really a zip file".utf8).write(to: locksmith)
        try Data("Nor this".utf8).write(to: keys)
        let controller = makeController()

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
        XCTAssertEqual(controller.updated, [])
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
}
