//
//  IFNewInform7ExtensionFileTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFNewInform7ExtensionFileTests.never-written")!
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
final class IFNewInform7ExtensionFileTests: XCTestCase, @unchecked Sendable {
    private var folder: URL!
    /// The project the extension is for, which the project type only holds weakly
    private var project: IFProject!

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            // Only the project's location is needed, so it isn't read from disk
            project = IFProject()
            project.fileURL = folder.appendingPathComponent("Lamplighter.inform")
        }
    }

    override func tearDownWithError() throws {
        try MainActor.assumeIsolated {
            project.close()
            project = nil
            try FileManager.default.removeItem(at: folder)
        }
    }

    /// Preferences that give the author's name, kept in memory
    private func preferences(author: String?) -> IFPreferences {
        var stored: [String: Any] = [:]
        if let author {
            stored["newGameAuthorName"] = author
        }
        return IFPreferences(userDefaults: MemoryDefaults([IFPreferencesDefault: stored]))
    }

    /// A project type for a new extension in the project, whose author's name comes from the preferences
    private func projectType(author: String? = "Emily Short") -> IFNewInform7ExtensionFile {
        return IFNewInform7ExtensionFile(project: project, preferences: preferences(author: author))
    }

    /// The project type's options, as the New Extension window shows them
    private func options(_ type: IFNewInform7ExtensionFile) throws -> IFNewInform7ExtensionView {
        return try XCTUnwrap(type.configView as? IFNewInform7ExtensionView)
    }

    /// The options' two text fields, found by what they show
    private func fields(_ options: IFNewInform7ExtensionView) throws -> (author: NSTextField, title: NSTextField) {
        let editable = (options.view?.subviews ?? []).compactMap { $0 as? NSTextField }.filter { $0.isEditable }
        XCTAssertEqual(editable.count, 2)
        let author = try XCTUnwrap(editable.first { $0.stringValue == options.authorName })
        let title = try XCTUnwrap(editable.first { $0.stringValue == options.extensionName })
        XCTAssertFalse(author === title)
        return (author, title)
    }

    /// A project type whose options have been filled in with this title and author
    private func filledIn(title: String, author: String) throws -> IFNewInform7ExtensionFile {
        let type = projectType()
        let (authorField, titleField) = try fields(try options(type))
        authorField.stringValue = author
        titleField.stringValue = title
        return type
    }

    /// Where an extension by this author with this title goes in the project's materials folder
    private func extensionURL(title: String, author: String) -> URL {
        return folder.appendingPathComponent("Lamplighter.materials/Extensions")
            .appendingPathComponent(author)
            .appendingPathComponent(title + ".i7x")
    }

    // MARK: - The project type

    func testItsAnExtensionWithOptions() throws {
        let type = projectType()
        XCTAssertEqual(type.typeName, "org.inform-fiction.inform7.extension")
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))

        let options = try options(type)
        XCTAssertNotNil(options.view)
        XCTAssertTrue(type.configView === options, "The options are made once")
    }

    /// Setting up a project file does nothing, as the extension isn't a project
    func testSettingUpAProjectFileDoesNothing() throws {
        let file = IFProjectFile(emptyProject: ())
        projectType().setupFile(file, from: try options(projectType()), withStory: "The Lamp Room is a room.",
                                withExtensionURL: folder)
        XCTAssertEqual(file.sourceDirectory?.fileWrappers?.count, 0)
        XCTAssertNil(file.settings)
    }

    // MARK: - The options

    /// The options start with the author's name from the preferences, and a title to change
    func testTheOptionsStartWithTheAuthorsName() throws {
        let options = try options(projectType(author: "Emily Short"))
        XCTAssertEqual(options.authorName, "Emily Short")
        XCTAssertEqual(options.extensionName, IFUtility.localizedString("New Extension"))
        XCTAssertEqual(options.extensionName, "New Extension")

        let (author, title) = try fields(options)
        XCTAssertEqual(author.stringValue, "Emily Short")
        XCTAssertEqual(title.stringValue, "New Extension")
    }

    /// An author's name with a full stop is put in quotation marks, as for a story (Inform rejects it for an
    /// extension: see ToFix.md)
    func testAnAuthorWithAFullStop() throws {
        XCTAssertEqual(try options(projectType(author: "J. R. Hartley")).authorName, "\"J. R. Hartley\"")
    }

    /// With no author in the preferences, it's the user's name
    func testNoAuthorInThePreferences() throws {
        var userName = NSFullUserName()
        if userName.isEmpty { userName = NSUserName() }
        if userName.isEmpty { userName = "Unknown Author" }
        if userName.contains(".") { userName = "\"\(userName)\"" }

        XCTAssertEqual(try options(projectType(author: nil)).authorName, userName)
    }

    /// Showing the options again starts them again
    func testShowingTheOptionsAgain() throws {
        let type = projectType()
        let options = try options(type)
        let (author, title) = try fields(options)
        author.stringValue = "Graham Nelson"
        title.stringValue = "Lamps"
        XCTAssertEqual(options.authorName, "Graham Nelson")
        XCTAssertEqual(options.extensionName, "Lamps")

        _ = type.configView
        XCTAssertEqual(options.authorName, "Emily Short")
        XCTAssertEqual(options.extensionName, "New Extension")
    }

    /// The title is where typing starts
    func testTheInitialFocusIsTheTitle() throws {
        let type = projectType()
        let options = try options(type)
        let title = try fields(options).title

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 300), styleMask: [.titled],
                              backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(try XCTUnwrap(options.view))
        type.setInitialFocus(window)

        // A text field being edited hands the keyboard to the window's field editor
        let responder = window.firstResponder
        XCTAssertTrue(responder === title || (responder as? NSText)?.delegate === title)
        window.close()
    }

    // MARK: - Checking the options

    func testAnAuthorAndATitleAreNeeded() throws {
        let missingAuthor = IFUtility.localizedString("BadExtensionAuthor")
        let missingTitle = IFUtility.localizedString("BadExtensionName")
        XCTAssertNotEqual(missingAuthor, "BadExtensionAuthor")
        XCTAssertNotEqual(missingTitle, "BadExtensionName")

        XCTAssertNil(try filledIn(title: "Lamps", author: "Emily Short").errorMessage)
        XCTAssertEqual(try filledIn(title: "Lamps", author: "").errorMessage, missingAuthor)
        XCTAssertEqual(try filledIn(title: "", author: "Emily Short").errorMessage, missingTitle)
        XCTAssertEqual(try filledIn(title: "", author: "").errorMessage, missingAuthor)
    }

    /// With its project gone, as when it's closed while the New Extension window is open, the extension has nowhere to
    /// go, so Create says so, where it raised
    func testAProjectThatsGone() throws {
        let noProject = IFUtility.localizedString("NoProjectForExtension")
        XCTAssertNotEqual(noProject, "NoProjectForExtension")

        var type: IFNewInform7ExtensionFile!
        weak var gone: IFProject?
        try autoreleasepool {
            let closed = IFProject()
            closed.fileURL = folder.appendingPathComponent("Closed.inform")
            gone = closed
            type = IFNewInform7ExtensionFile(project: closed, preferences: preferences(author: "Emily Short"))
            _ = try options(type)
            closed.close()
        }

        // A closed project is let go once the run loop has turned
        let freed = expectation(for: NSPredicate { _, _ in gone == nil }, evaluatedWith: nil)
        wait(for: [freed], timeout: 5)

        XCTAssertNil(type.saveFilename)
        XCTAssertEqual(type.errorMessage, noProject)
    }

    /// A project that has never been saved has nowhere to put the extension either
    func testAProjectNeverSaved() throws {
        let unsaved = IFProject()
        defer { unsaved.close() }
        let type = IFNewInform7ExtensionFile(project: unsaved, preferences: preferences(author: "Emily Short"))
        _ = try options(type)

        XCTAssertNil(type.saveFilename)
        XCTAssertEqual(type.errorMessage, IFUtility.localizedString("NoProjectForExtension"))
    }

    /// The extension goes in the project's materials folder, in a folder for its author
    func testWhereTheExtensionGoes() throws {
        let type = try filledIn(title: "Lamps", author: "Emily Short")
        XCTAssertEqual(type.saveFilename, extensionURL(title: "Lamps", author: "Emily Short").path)
    }

    /// Making an extension that's already there needs confirming, as it'll be written over
    func testAnExtensionThatsAlreadyThere() throws {
        let type = try filledIn(title: "Lamps", author: "Emily Short")
        XCTAssertNil(type.confirmationMessage)

        let url = extensionURL(title: "Lamps", author: "Emily Short")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Lamps by Emily Short begins here.\n".utf8).write(to: url)
        XCTAssertEqual(type.confirmationMessage, IFUtility.localizedString("Extension already exists"))
        XCTAssertNotEqual(type.confirmationMessage, "Extension already exists")
    }

    // MARK: - Writing the extension

    /// The new extension has its first and last lines, with an empty line between them where typing starts, and its
    /// folders are made
    func testWritingTheExtension() throws {
        let type = try filledIn(title: "Lamps", author: "Emily Short")
        let url = extensionURL(title: "Lamps", author: "Emily Short")

        XCTAssertTrue(type.writeExtension(url))
        let expected = "Lamps by Emily Short begins here.\n\n\n\nLamps ends here.\n"
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), expected)
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 35, length: 0))
        XCTAssertTrue((expected as NSString).substring(to: 35).hasSuffix("begins here.\n\n"))
    }

    /// An extension that's already there is written over
    func testWritingOverAnExtension() throws {
        let type = try filledIn(title: "Lamps", author: "Emily Short")
        let url = extensionURL(title: "Lamps", author: "Emily Short")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Lamps by Emily Short begins here.\n\nA lamp is a kind of thing.\n\nLamps ends here.\n".utf8)
            .write(to: url)

        XCTAssertTrue(type.writeExtension(url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8),
                       "Lamps by Emily Short begins here.\n\n\n\nLamps ends here.\n")
    }

    /// The extension is written as UTF-8, and where typing starts is counted in UTF-16 units, as a text view counts
    func testATitleThatIsntASCII() throws {
        let type = try filledIn(title: "Lampe à huile 🪔", author: "Émilie")
        let url = extensionURL(title: "Lampe à huile 🪔", author: "Émilie")

        XCTAssertTrue(type.writeExtension(url))
        let expected = "Lampe à huile 🪔 by Émilie begins here.\n\n\n\nLampe à huile 🪔 ends here.\n"
        XCTAssertEqual(try Data(contentsOf: url), Data(expected.utf8))
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 41, length: 0))
        XCTAssertTrue((expected as NSString).substring(to: 41).hasSuffix("begins here.\n\n"))
    }

    /// An extension that can't be written gives NO, and leaves where typing starts as it was
    func testWhatCantBeWritten() throws {
        let type = try filledIn(title: "Lamps", author: "Emily Short")

        XCTAssertFalse(type.writeExtension(try XCTUnwrap(URL(string: "https://example.com/Lamps.i7x"))))

        // A folder can't be made where there's a file
        let file = folder.appendingPathComponent("Emily Short")
        try Data().write(to: file)
        XCTAssertFalse(type.writeExtension(file.appendingPathComponent("Lamps.i7x")))

        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))
    }
}
