//
//  IFProjectControllerTests.swift
//  InformTests
//

import XCTest

/// A project controller whose window, once loaded, isn't given an autosave name, which would keep its frame in the
/// user's preferences, nor hides the welcome window
private final class TestProjectController: IFProjectController {
    override func windowDidLoad() {
    }

    /// Nor keeps the panes' widths in the user's preferences when the split views lay them out
    override func splitViewDidResizeSubviews(_ notification: Notification) {
    }
}

/// The project window's controller, with its real window and panes, kept off the screen and never shown
final class IFProjectControllerTests: XCTestCase {
    private let story = "\"Lighthouse\" by Me\n\nThe Lamp Room is a room.\n\nThe great lamp is in the Lamp Room.\n"

    private var folder: URL!
    private var project: IFProject!
    private var controller: TestProjectController!
    private var window: NSWindow!
    /// The panes, which show the source and the documentation at first
    private var left: IFProjectPane!
    private var right: IFProjectPane!

    override func setUpWithError() throws {
        try super.setUpWithError()

        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = folder.appendingPathComponent("Lighthouse.inform/Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data(story.utf8).write(to: source.appendingPathComponent("story.ni"))
        try Data("Remember the lamp.\n".utf8).write(to: source.appendingPathComponent("Notes.txt"))

        // An index, as a translation leaves, which the panes find as they're set up
        let index = folder.appendingPathComponent("Lighthouse.inform/Index", isDirectory: true)
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        try Data("<html><body>Welcome</body></html>".utf8).write(to: index.appendingPathComponent("Welcome.html"))
        try Data("<html><body>Actions</body></html>".utf8).write(to: index.appendingPathComponent("Actions.html"))
        project = try IFProject(contentsOf: folder.appendingPathComponent("Lighthouse.inform"),
                                ofType: "org.inform-fiction.project")

        controller = TestProjectController()
        project.addWindowController(controller)
        window = try XCTUnwrap(controller.window)
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))

        left = try XCTUnwrap(controller.sourcePane)
        right = try XCTUnwrap(controller.auxPane)
    }

    override func tearDownWithError() throws {
        controller?.close()
        project?.close()
        left = nil
        right = nil
        window = nil
        controller = nil
        project = nil
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
        try super.tearDownWithError()
    }

    /// A file's highlights, each its line and style
    private func highlights(_ file: String) -> [[UInt32]]? {
        return controller.highlights(forFile: file)?.map { $0.map { $0.uint32Value } }
    }

    /// The identifier of the page a pane shows, its class's name
    private func pageShown(_ pane: IFProjectPane) -> String? {
        return pane.tabView.selectedTabViewItem?.identifier as? String
    }

    // MARK: - The panes

    func testTheSourceIsOnTheLeftAndTheDocumentationOnTheRightAtFirst() throws {
        XCTAssertFalse(left === right)
        XCTAssertEqual(left.currentView, .sourcePane)
        XCTAssertEqual(right.currentView, .documentationPane)
        XCTAssertTrue(left.paneView.window === window)
        XCTAssertTrue(right.paneView.window === window)
        XCTAssertLessThan(left.paneView.convert(left.paneView.bounds, to: nil).minX,
                          right.paneView.convert(right.paneView.bounds, to: nil).minX)
    }

    func testEachPaneIsOppositeTheOther() {
        XCTAssertTrue(controller.oppositePane(left) === right)
        XCTAssertTrue(controller.oppositePane(right) === left)
        XCTAssertNil(controller.oppositePane(IFProjectPane()))
    }

    func testTheIndexGoesInAPaneShowingItOrWhereTheDocumentationGoes() {
        XCTAssertTrue(controller.indexPane === right)
        left.selectView(of: .indexPane)
        XCTAssertTrue(controller.indexPane === left)
    }

    func testNoPaneRunsAGameAtFirst() {
        XCTAssertNil(controller.runningGamePane)
        XCTAssertFalse(controller.isRunningGame)
    }

    func testOnceTheWindowHasClosedThereAreNoPanes() {
        controller.close()

        XCTAssertNil(controller.sourcePane)
        XCTAssertNil(controller.auxPane)
        XCTAssertNil(controller.indexPane)
        XCTAssertNil(controller.runningGamePane)
        XCTAssertNil(controller.oppositePane(left))
    }

    // MARK: - Switching tabs and panes

    func testTheTabCommandsDoNothingWithNoCurrentPane() {
        XCTAssertFalse(controller.hasCurrentTabView)

        controller.tabIndex(nil)
        controller.tabSkein(nil)

        XCTAssertEqual(left.currentView, .sourcePane)
        XCTAssertEqual(right.currentView, .documentationPane)
    }

    func testTheTabCommandsSwitchTheCurrentPanesTab() {
        controller.changeFirstResponder(right.tabView)
        XCTAssertTrue(controller.hasCurrentTabView)
        XCTAssertFalse(controller.isSourcePaneCurrent)

        controller.tabIndex(nil)
        XCTAssertEqual(right.currentView, .indexPane)
        controller.tabSkein(nil)
        XCTAssertEqual(right.currentView, .skeinPane)
        controller.tabErrors(nil)
        XCTAssertEqual(right.currentView, .errorPane)
        controller.tabExtensions(nil)
        XCTAssertEqual(right.currentView, .extensionsPane)
        controller.tabSettings(nil)
        XCTAssertEqual(pageShown(right), IFSettingsPage.description())
        controller.tabDocumentation(nil)
        XCTAssertEqual(right.currentView, .documentationPane)
        controller.tabSource(nil)
        XCTAssertEqual(right.currentView, .sourcePane)

        XCTAssertEqual(left.currentView, .sourcePane)
    }

    func testTheGameTabDoesNothingWithNoGameRunning() {
        controller.changeFirstResponder(right.tabView)
        controller.tabGame(nil)
        XCTAssertEqual(right.currentView, .documentationPane)
    }

    func testGoingToEachPaneMakesItCurrent() {
        controller.gotoLeftPane(nil)
        XCTAssertTrue(controller.isSourcePaneCurrent)
        controller.gotoRightPane(nil)
        XCTAssertFalse(controller.isSourcePaneCurrent)
        XCTAssertTrue(controller.hasCurrentTabView)

        controller.switchPanes(nil)
        XCTAssertTrue(controller.isSourcePaneCurrent)
        controller.switchPanes(nil)
        XCTAssertFalse(controller.isSourcePaneCurrent)
    }

    func testGoingToThePaneWithTheSourceActivatesItsTextView() {
        XCTAssertFalse(controller.isTextViewFirstResponder)

        controller.gotoLeftPane(nil)

        XCTAssertTrue(controller.isTextViewFirstResponder)
        XCTAssertTrue(controller.firstResponderHasIntelligence)
        XCTAssertEqual(controller.firstResponderSelectionLength, 0)
    }

    func testShowingAnIndexTabShowsTheIndexWhereTheDocumentationGoes() {
        let item = NSMenuItem()
        item.tag = Int(IFIndexTabType.actions.rawValue)

        controller.showIndexTab(item)

        XCTAssertEqual(left.currentView, .sourcePane)
        XCTAssertEqual(right.currentView, .indexPane)
    }

    func testWithNoIndexTheIndexCantBeShown() throws {
        try FileManager.default.removeItem(at: folder.appendingPathComponent("Lighthouse.inform/Index"))
        left.indexPage.updateIndexView()
        right.indexPage.updateIndexView()
        let item = NSMenuItem()
        item.tag = Int(IFIndexTabType.actions.rawValue)

        controller.showIndexTab(item)

        XCTAssertEqual(right.currentView, .documentationPane)
        XCTAssertFalse(controller.canSelectIndexTab(IFIndexTabType.actions.rawValue))
    }

    func testTheDocumentationCommandsShowItWhereTheDocumentationGoes() {
        controller.docExtensions(nil)
        XCTAssertEqual(right.currentView, .extensionsPane)

        controller.docRecipes(nil)
        XCTAssertEqual(right.currentView, .documentationPane)

        right.selectView(of: .indexPane)
        controller.docIndex(nil)
        XCTAssertEqual(right.currentView, .documentationPane)

        XCTAssertEqual(left.currentView, .sourcePane)
    }

    // MARK: - The source

    func testSelectingOneOfTheProjectsFilesShowsItInTheSourcePane() {
        XCTAssertTrue(controller.selectSourceFile("Notes.txt"))
        XCTAssertEqual(((left.sourcePage.currentFile ?? "") as NSString).lastPathComponent, "Notes.txt")
    }

    func testMovingToALineShowsTheSourceWhereItGoes() throws {
        left.selectView(of: .errorPane)

        controller.move(toSourceFileLine: 3)

        XCTAssertEqual(left.currentView, .errorPane)
        XCTAssertEqual(right.currentView, .sourcePane)
        let textView = try XCTUnwrap(window.firstResponder as? NSTextView)
        XCTAssertTrue(textView.isDescendant(of: right.paneView))
        XCTAssertEqual(textView.selectedRange(),
                       NSRange(location: (story as NSString).range(of: "The Lamp Room").location, length: 0))
    }

    func testHighlightsLinesOfTheProjectsFiles() {
        XCTAssertNil(highlights("story.ni"))

        controller.highlightSourceFileLine(3, inFile: "story.ni", style: .error)
        controller.highlightSourceFileLine(1, inFile: "story.ni", style: .neutral)
        controller.highlightSourceFileLine(1, inFile: "Notes.txt", style: .error)

        XCTAssertEqual(highlights("story.ni"), [[3, IFLineStyle.error.rawValue], [1, IFLineStyle.neutral.rawValue]])
        XCTAssertEqual(highlights("Notes.txt"), [[1, IFLineStyle.error.rawValue]])
    }

    func testRemovesHighlightsOfAStyle() {
        controller.highlightSourceFileLine(3, inFile: "story.ni", style: .error)
        controller.highlightSourceFileLine(1, inFile: "story.ni", style: .neutral)
        controller.highlightSourceFileLine(1, inFile: "Notes.txt", style: .error)

        controller.removeHighlights(inFile: "story.ni", of: .error)
        XCTAssertEqual(highlights("story.ni"), [[1, IFLineStyle.neutral.rawValue]])
        XCTAssertEqual(highlights("Notes.txt"), [[1, IFLineStyle.error.rawValue]])

        controller.highlightSourceFileLine(3, inFile: "story.ni", style: .error)
        controller.removeHighlights(of: .error)
        XCTAssertEqual(highlights("story.ni"), [[1, IFLineStyle.neutral.rawValue]])
        XCTAssertEqual(highlights("Notes.txt"), [])
    }

    func testRemovesTheTemporaryHighlights() {
        controller.highlightSourceFileLine(3, inFile: "story.ni", style: .error)
        controller.highlightSourceFileLine(4, inFile: "story.ni", style: .warning)
        controller.highlightSourceFileLine(1, inFile: "story.ni", style: .neutral)
        controller.highlightSourceFileLine(2, inFile: "Notes.txt", style: .highlight)

        controller.removeAllTemporaryHighlights()

        XCTAssertEqual(highlights("story.ni"), [[1, IFLineStyle.neutral.rawValue]])
        XCTAssertEqual(highlights("Notes.txt"), [])
    }

    // MARK: - Test cases

    func testShowingATestCaseTheToolbarDoesntHaveDoesNothing() {
        XCTAssertFalse(controller.showTestCase("A", skeinNode: 0))
        XCTAssertEqual(left.currentView, .sourcePane)
        XCTAssertEqual(right.currentView, .documentationPane)
    }

    // MARK: - Playing the skein

    /// The game page tells the controller when the commands it was given, by the skein or a test case, have run
    /// out. A moment later the controller reports on the skein, when testing, and plays the next of the skein's
    /// threads, when playing them all.
    func testCommandsRunningOutWithNothingMoreToPlayDoesNothing() {
        controller.inputSourceHasFinished(nil)

        // The controller looks once the run loop has run (and any exception it raised fails the test)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertFalse(controller.isRunningGame)
        XCTAssertFalse(controller.isCurrentlyTesting)
    }

    // MARK: - The window

    func testTheWindowIsTitledWithTheProjectsName() {
        XCTAssertEqual(controller.windowTitle(forDocumentDisplayName: "Lighthouse"), "Lighthouse")
    }

    func testAnExtensionProjectsWindowSaysSo() throws {
        let extensionURL = folder.appendingPathComponent("Lamplighting.i7xp")
        let source = extensionURL.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("Lamplighting by Jane Doe begins here.\n\nLamplighting ends here.\n".utf8)
            .write(to: source.appendingPathComponent("extension.i7x"))
        let extensionProject = try IFProject(contentsOf: extensionURL, ofType: "org.inform-fiction.xproject")
        defer { extensionProject.close() }

        // Its window isn't loaded
        let extensionController = TestProjectController()
        extensionController.document = extensionProject

        XCTAssertEqual(extensionController.windowTitle(forDocumentDisplayName: "Lamplighting"),
                       IFUtility.localizedString("Extension Project") + " - Lamplighting")
    }

    // MARK: - The menu

    func testTheMenusStateForAStoryProject() {
        XCTAssertFalse(controller.isExtensionProject)
        XCTAssertFalse(controller.isCurrentlyTesting)
        XCTAssertFalse(controller.isTestAllCasesSelected)
        XCTAssertEqual(controller.numberOfToolbarTestCases, 0)
        XCTAssertNil(controller.toolbarTestCase)
        XCTAssertFalse(controller.isCompilerRunning)
        XCTAssertFalse(controller.isCompiling)
        XCTAssertTrue(controller.isUsingNaturalInform)
        XCTAssertFalse(controller.hasCurrentTabView)
        XCTAssertFalse(controller.isSourcePaneCurrent)
        XCTAssertTrue(controller.canSelectIndexTab(IFIndexTabType.actions.rawValue))
        XCTAssertFalse(controller.canSelectIndexTab(IFIndexTabType.world.rawValue))
    }

    func testTheMenuIsEnabledFromTheControllersState() {
        let stop = NSMenuItem(title: "Stop", action: #selector(IFProjectController.stopProcess(_:)), keyEquivalent: "")
        let go = NSMenuItem(title: "Go", action: #selector(IFProjectController.compileAndRun(_:)), keyEquivalent: "")

        XCTAssertFalse(controller.validateMenuItem(stop))
        XCTAssertTrue(controller.validateMenuItem(go))
    }

    // MARK: - Settings

    func testAChangeToTheProjectsSettingsMarksItEdited() {
        XCTAssertFalse(project.isDocumentEdited)

        NotificationCenter.default.post(name: .IFSetting, object: project.settings)

        XCTAssertTrue(project.isDocumentEdited)
    }

    func testAChangeToAnotherProjectsSettingsDoesntMarkItEdited() {
        NotificationCenter.default.post(name: .IFSetting, object: IFCompilerSettings())

        XCTAssertFalse(project.isDocumentEdited)
    }
}
