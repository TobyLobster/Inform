//
//  IFAppDelegateTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests leave the user's own alone
private final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }

    override func bool(forKey defaultName: String) -> Bool {
        return (values[defaultName] as? Bool) ?? false
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        values[defaultName] = value
    }
}

/// Stands in for a project's controller, with a window of the test's own rather than a project's, recording what
/// it's told about spell checking
private final class ProjectControllerStandIn: IFProjectController {
    var testWindow: NSWindow?
    private(set) var spellChecking: [Bool] = []

    override var window: NSWindow? {
        get {
            return testWindow
        }
        set {
        }
    }

    override func setSourceSpellChecking(_ spellChecking: Bool) {
        self.spellChecking.append(spellChecking)
    }
}

/// Stands in for the controller of a file opened on its own, with no window, recording what it's told about spell
/// checking
private final class SingleControllerStandIn: IFSingleController {
    private(set) var spellChecking: [Bool] = []

    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }

    override func setSourceSpellChecking(_ spellChecking: Bool) {
        self.spellChecking.append(spellChecking)
    }
}

/// The app's delegate, a new one for each test rather than the app's own, so it isn't told the app has launched. It
/// keeps whether the source is spell checked in memory, and fills in menus of the test's own. Windows the tests put
/// on the list of the app's windows are off the screen, and documents they open are only known to the document
/// controller, which forgets them when the test ends.
@MainActor
final class IFAppDelegateTests: XCTestCase {

    // MARK: - Helpers

    private func makeDelegate() -> (delegate: IFAppDelegate, defaults: MemoryDefaults) {
        let defaults = MemoryDefaults()
        return (IFAppDelegate(defaults: defaults), defaults)
    }

    /// A window off the screen, on the list of the app's windows until the test ends
    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        addTeardownBlock {
            window.orderOut(nil)
        }
        return window
    }

    /// A document the document controller knows until the test ends, with this controller
    private func open(_ document: NSDocument, with controller: NSWindowController) {
        NotificationCenter.default.removeObserver(controller)
        document.addWindowController(controller)
        NSDocumentController.shared.addDocument(document)
        addTeardownBlock {
            NSDocumentController.shared.removeDocument(document)
            document.removeWindowController(controller)
        }
    }

    /// A project open in the app, whose controller has a window off the screen, not yet on the list of the app's
    /// windows
    private func openProject() -> (controller: ProjectControllerStandIn, window: NSWindow) {
        let controller = ProjectControllerStandIn()
        let window = makeWindow()
        controller.testWindow = window
        open(IFProject(), with: controller)
        return (controller, window)
    }

    /// A folder of the test's own, removed when it ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }
        return folder
    }

    /// A folder with a file of this text in it
    @discardableResult
    private func makeFolder(_ url: URL, holding text: String) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent("story.ni")
        try Data(text.utf8).write(to: file)
        return file
    }

    /// The 'Open Installed Extension' and 'New Extension Project' menus, of the test's own, for the delegate to fill in
    private func makeExtensionsMenus(for delegate: IFAppDelegate) -> (open: NSMenu, new: NSMenu) {
        let openItem = NSMenuItem()
        openItem.submenu = NSMenu()
        let newItem = NSMenuItem()
        newItem.submenu = NSMenu()
        delegate.setValue(openItem, forKey: "openExtensionMenu")
        delegate.setValue(newItem, forKey: "newExtensionProjectMenu")
        return (openItem.submenu!, newItem.submenu!)
    }

    /// The extensions folder in Inform's Application Support, which only tests in their own home write in.
    /// It's removed after the test, and the extensions manager's lists are made again.
    private func makeExtensionsFolder() throws -> String {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let folder = IFUtility.pathForInformExternalExtensions()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder))
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        manager.dirtyCache()
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: folder)
            IFExtensionsManager.sharedNaturalInform.dirtyCache()
        }
        return folder
    }

    /// Writes an extension that starts with the given line, in a folder of the extensions folder
    private func put(_ firstLine: String, _ name: String, in authorFolder: String, of folder: String) throws {
        let directory = (folder as NSString).appendingPathComponent(authorFolder)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let file = (directory as NSString).appendingPathComponent(name)
        try (firstLine + "\n\n" + "Something ends here.\n").write(toFile: file, atomically: true, encoding: .utf8)
    }

    /// Writes a literate extension, with one section, as a folder in the extensions folder
    private func putLiterate(_ title: String, by author: String, of folder: String) throws {
        let extensionFolder = (folder as NSString).appendingPathComponent("\(author)/\(title)-v1.i7xd")
        let contents = (extensionFolder as NSString).appendingPathComponent("Source/Contents.w")
        let preamble = (extensionFolder as NSString).appendingPathComponent("Source/Sections/Preamble.w")
        try FileManager.default.createDirectory(atPath: (preamble as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try #"{ "is": { "type": "extension", "title": "\#(title)", "author": "\#(author)", "version": "1" } }"#
            .write(toFile: (extensionFolder as NSString).appendingPathComponent("extension_metadata.json"), atomically: true, encoding: .utf8)
        try "Version 1 of \(title) by \(author)\n\nSections\n\tPreamble\n".write(toFile: contents, atomically: true, encoding: .utf8)
        try "Preamble.\n\n@h \(title).\n\n=\n\n".write(toFile: preamble, atomically: true, encoding: .utf8)
    }

    /// The name in an extension's item, before any tab and version
    private func name(_ item: NSMenuItem) -> String {
        return String((item.attributedTitle?.string ?? "").prefix { $0 != "\t" })
    }

    private var manager: IFExtensionsManager {
        return IFExtensionsManager.sharedNaturalInform
    }

    // MARK: - Spell checking

    /// The source isn't spell checked until it's turned on
    func testTheSourceIsntSpellCheckedAtFirst() {
        let (delegate, defaults) = makeDelegate()
        XCTAssertFalse(delegate.sourceSpellChecking)
        defaults.set(true, forKey: "IFSourceSpellChecking")
        XCTAssertTrue(delegate.sourceSpellChecking)
    }

    /// The menu item that turns it on and off is ticked while it's on
    func testTheMenuItemIsTickedWhileTheSourceIsSpellChecked() {
        let (delegate, defaults) = makeDelegate()
        let item = NSMenuItem(title: "Check Spelling", action: #selector(IFAppDelegate.toggleSourceSpellChecking(_:)),
                              keyEquivalent: "")
        item.state = .mixed

        XCTAssertTrue(delegate.validateMenuItem(item))
        XCTAssertEqual(item.state, .off)

        defaults.set(true, forKey: "IFSourceSpellChecking")
        XCTAssertTrue(delegate.validateMenuItem(item))
        XCTAssertEqual(item.state, .on)
    }

    /// Every other item the delegate is asked about is enabled, and left as it was
    func testOtherMenuItemsAreEnabled() {
        let (delegate, _) = makeDelegate()
        let item = NSMenuItem(title: "About", action: #selector(IFAppDelegate.showAbout(_:)), keyEquivalent: "")
        item.state = .mixed

        XCTAssertTrue(delegate.validateMenuItem(item))
        XCTAssertEqual(item.state, .mixed)
    }

    /// Turning spell checking on or off remembers it, and tells the controllers of open projects and files
    func testTurningSpellCheckingOnAndOffTellsEachWindow() {
        let (delegate, defaults) = makeDelegate()
        let (project, _) = openProject()
        let single = SingleControllerStandIn(initialSelectionRange: NSRange(location: 0, length: 0))
        open(IFSingleFile(), with: single)

        delegate.toggleSourceSpellChecking(nil)
        XCTAssertEqual(defaults.object(forKey: "IFSourceSpellChecking") as? Bool, true)
        XCTAssertTrue(delegate.sourceSpellChecking)
        XCTAssertEqual(project.spellChecking, [true])
        XCTAssertEqual(single.spellChecking, [true])

        delegate.toggleSourceSpellChecking(nil)
        XCTAssertEqual(defaults.object(forKey: "IFSourceSpellChecking") as? Bool, false)
        XCTAssertFalse(delegate.sourceSpellChecking)
        XCTAssertEqual(project.spellChecking, [true, false])
        XCTAssertEqual(single.spellChecking, [true, false])
    }

    // MARK: - The frontmost project

    /// With no project open, none is in front
    func testNoProjectIsInFrontWhenNoneIsOpen() {
        let (delegate, _) = makeDelegate()
        XCTAssertFalse(NSDocumentController.shared.documents.contains { $0 is IFProject })
        makeWindow().orderFrontRegardless()
        XCTAssertNil(delegate.frontmostProjectController)
    }

    /// The project in front is the one whose window is in front of the others
    func testTheProjectInFrontIsTheOneWhoseWindowIsInFront() {
        let (delegate, _) = makeDelegate()
        let (first, firstWindow) = openProject()
        let (second, secondWindow) = openProject()

        firstWindow.orderFrontRegardless()
        secondWindow.orderFrontRegardless()
        XCTAssertTrue(delegate.frontmostProjectController === second)

        firstWindow.orderFrontRegardless()
        XCTAssertTrue(delegate.frontmostProjectController === first)
    }

    /// A window in front that isn't a project's is passed over for the project's behind it
    func testAWindowInFrontThatIsntAProjectsIsPassedOver() {
        let (delegate, _) = makeDelegate()
        let (project, projectWindow) = openProject()
        let other = makeWindow()
        let (_, behindWindow) = openProject()

        behindWindow.orderFrontRegardless()
        projectWindow.orderFrontRegardless()
        other.orderFrontRegardless()
        XCTAssertTrue(delegate.frontmostProjectController === project)
    }

    // MARK: - The extensions menus

    /// Open Installed Extension has a menu for each author, listing their extensions, and New Extension Project
    /// offers a new extension, or one made from an installed extension that's kept in one file, with the same tag
    /// as in Open Installed Extension. Anything in the menus before goes.
    func testTheExtensionsMenusListEachAuthorsExtensions() throws {
        let folder = try makeExtensionsFolder()
        try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        try putLiterate("Lamps", by: "Emily Short", of: folder)
        try putLiterate("Clock", by: "Jane Doe", of: folder)
        try put("Unicode Parser by Andrew Plotkin begins here.", "Unicode Parser.i7x", in: "Andrew Plotkin", of: folder)
        let (delegate, _) = makeDelegate()
        let (open, new) = makeExtensionsMenus(for: delegate)
        open.addItem(withTitle: "Old", action: nil, keyEquivalent: "")
        new.addItem(withTitle: "Old", action: nil, keyEquivalent: "")

        delegate.updateExtensionsMenu(forCompilerVersion: "10.1")

        XCTAssertEqual(open.items.map(\.title), ["Andrew Plotkin", "Emily Short", "Jane Doe"])
        XCTAssertEqual(open.items.map { $0.submenu?.title }, ["Andrew Plotkin", "Emily Short", "Jane Doe"])
        let openItems = open.items.compactMap(\.submenu).map(\.items)
        XCTAssertEqual(openItems.map { $0.map(name) }, [["Unicode Parser"], ["Keys", "Lamps", "Locksmith"], ["Clock"]])
        XCTAssertEqual(openItems.map { $0.map(\.tag) }, [[0], [1, 2, 3], [4]])
        for item in openItems.joined() {
            XCTAssertEqual(item.action, Selector(("openExtension:")))
            XCTAssertTrue(item.target === delegate)
        }

        XCTAssertEqual(new.items.map(\.title), [IFUtility.localizedString("New Extension..."),
                                                IFUtility.localizedString("Create From Installed Extension")])
        let newExtension = new.items[0]
        XCTAssertEqual(newExtension.tag, -1)
        XCTAssertEqual(newExtension.action, Selector(("newExtensionProject:")))
        XCTAssertTrue(newExtension.target === delegate)
        let createFrom = try XCTUnwrap(new.items[1].submenu)
        XCTAssertEqual(createFrom.title, new.items[1].title)

        // Jane Doe has only a literate extension
        XCTAssertEqual(createFrom.items.map(\.title), ["Andrew Plotkin", "Emily Short"])
        XCTAssertEqual(createFrom.items.map { $0.submenu?.title }, ["Andrew Plotkin", "Emily Short"])
        let newItems = createFrom.items.compactMap(\.submenu).map(\.items)
        XCTAssertEqual(newItems.map { $0.map(name) }, [["Unicode Parser"], ["Keys", "Locksmith"]])
        XCTAssertEqual(newItems.map { $0.map(\.tag) }, [[0], [1, 3]])
        for item in newItems.joined() {
            XCTAssertEqual(item.action, Selector(("newExtensionProject:")))
            XCTAssertTrue(item.target === delegate)
        }
    }

    /// An extension's item shows its name, in the text colour for one installed by the user, then its version after
    /// a tab, smaller, with the tab past the widest of its author's names
    func testAnExtensionsItemShowsItsNameAndVersion() throws {
        let folder = try makeExtensionsFolder()
        try put("Version 3 of Locksmith by Emily Short begins here.", "Locksmith.i7x", in: "Emily Short", of: folder)
        try put("Keys by Emily Short begins here.", "Keys.i7x", in: "Emily Short", of: folder)
        try putLiterate("Lamps", by: "Emily Short", of: folder)
        let (delegate, _) = makeDelegate()
        let (open, _) = makeExtensionsMenus(for: delegate)

        delegate.updateExtensionsMenu(forCompilerVersion: "10.1")

        let font = NSFont.menuFont(ofSize: 14)
        let smallFont = NSFont.menuFont(ofSize: 10)
        let items = try XCTUnwrap(open.items.first?.submenu?.items)
        // A version is always found for Inform 10, empty if the extension doesn't give one
        XCTAssertEqual(items.map { $0.attributedTitle?.string }, ["Keys\t", "Lamps\tv1", "Locksmith\tv3"])
        let widest = ["Keys", "Lamps", "Locksmith"].map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0

        for item in items {
            let title = try XCTUnwrap(item.attributedTitle)
            let tab = (title.string as NSString).range(of: "\t").location
            let nameAttributes = title.attributes(at: 0, effectiveRange: nil)
            XCTAssertEqual(nameAttributes[.font] as? NSFont, font)
            XCTAssertEqual(nameAttributes[.foregroundColor] as? NSColor, NSColor.textColor)
            let paragraph = try XCTUnwrap(nameAttributes[.paragraphStyle] as? NSParagraphStyle)
            XCTAssertEqual(paragraph.tabStops.count, 1)
            XCTAssertEqual(paragraph.tabStops.first?.location ?? 0, widest + 10, accuracy: 0.001)
            XCTAssertEqual(paragraph.lineBreakMode, .byClipping)

            let versionAttributes = title.attributes(at: tab, effectiveRange: nil)
            XCTAssertEqual(versionAttributes[.font] as? NSFont, smallFont)
            XCTAssertEqual(versionAttributes[.foregroundColor] as? NSColor, NSColor.textColor)
            XCTAssertEqual(versionAttributes[.paragraphStyle] as? NSParagraphStyle, paragraph)
        }
    }

    /// An installed extension that's already open is brought to the front, not opened again. (Its file is removed
    /// once it's open, so that it couldn't be opened again, as that would show a window on the screen.)
    func testOpeningAnInstalledExtensionThatsOpenShowsIt() throws {
        let folder = try makeExtensionsFolder()
        try put("Unicode Parser by Andrew Plotkin begins here.", "Unicode Parser.i7x", in: "Andrew Plotkin", of: folder)
        let file = URL(fileURLWithPath: folder).appendingPathComponent("Andrew Plotkin/Unicode Parser.i7x")
        let (delegate, _) = makeDelegate()
        let (openMenu, _) = makeExtensionsMenus(for: delegate)
        delegate.updateExtensionsMenu(forCompilerVersion: "10.1")
        let item = try XCTUnwrap(openMenu.items.first { $0.title == "Andrew Plotkin" }?.submenu?.items.first)

        let document = try IFSingleFile(contentsOf: file, ofType: "Inform 7 extension")
        let window = makeWindow()
        open(document, with: NSWindowController(window: window))
        try FileManager.default.removeItem(at: file)

        // (The action isn't in the delegate's header)
        _ = delegate.perform(Selector(("openExtension:")), with: item)

        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(NSDocumentController.shared.documents.filter { $0.fileURL == file }, [document])
    }

    // MARK: - Copying sample projects

    /// Copying a project over one already there asks first, so with the alert unanswered, as in the tests, nothing
    /// is copied
    func testCopyingOverAProjectAsksFirst() throws {
        let (delegate, _) = makeDelegate()
        let folder = try makeFolder()
        let source = folder.appendingPathComponent("Sample.inform")
        try makeFolder(source, holding: "The sample.")
        let destination = folder.appendingPathComponent("Copy.inform")
        let mine = try makeFolder(destination, holding: "Mine.")
        let documents = NSDocumentController.shared.documents.count

        delegate.doCopyProject(source, to: destination)

        XCTAssertEqual(try String(contentsOf: mine, encoding: .utf8), "Mine.")
        XCTAssertEqual(NSDocumentController.shared.documents.count, documents)
    }

    /// ...as it does when only the project's materials folder is there
    func testCopyingOverAProjectsMaterialsAsksFirst() throws {
        let (delegate, _) = makeDelegate()
        let folder = try makeFolder()
        let source = folder.appendingPathComponent("Sample.inform")
        try makeFolder(source, holding: "The sample.")
        let destination = folder.appendingPathComponent("Copy.inform")
        let mine = try makeFolder(folder.appendingPathComponent("Copy.materials"), holding: "Mine.")
        let documents = NSDocumentController.shared.documents.count

        delegate.doCopyProject(source, to: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try String(contentsOf: mine, encoding: .utf8), "Mine.")
        XCTAssertEqual(NSDocumentController.shared.documents.count, documents)
    }

    /// A project that can't be copied isn't opened: the error is reported, which in the tests is only logged
    func testAProjectThatCantBeCopiedIsntOpened() throws {
        let (delegate, _) = makeDelegate()
        let folder = try makeFolder()
        let destination = folder.appendingPathComponent("Copy.inform")
        let documents = NSDocumentController.shared.documents.count

        delegate.doCopyProject(folder.appendingPathComponent("Missing.inform"), to: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(NSDocumentController.shared.documents.count, documents)
    }
}
