//
//  IFToolbarManagerTests.swift
//  InformTests
//

import XCTest

/// A project controller whose window, project and state the tests set, and which records the senders of
/// Test Selector
private final class ProjectControllerStandIn: IFProjectController {
    var project: IFProject?
    var testWindow: NSWindow?
    var gameIsRunning = false
    var testingNow = false
    var compilingNow = false
    var testSelectorSenders: [Any?] = []

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    override var window: NSWindow? {
        get {
            return testWindow
        }
        set {
        }
    }

    override var isRunningGame: Bool {
        return gameIsRunning
    }

    override var isCurrentlyTesting: Bool {
        return testingNow
    }

    override var isCompiling: Bool {
        return compilingNow
    }

    override func testSelector(_ sender: Any?) {
        testSelectorSenders.append(sender)
    }
}

final class IFToolbarManagerTests: XCTestCase {

    private var controller: ProjectControllerStandIn!
    private var manager: IFToolbarManager!

    override func setUp() {
        super.setUp()
        controller = ProjectControllerStandIn()
        manager = IFToolbarManager(projectController: controller)
    }

    override func tearDown() {
        // Toolbars with the same identifier share their items while they last
        controller?.testWindow?.toolbar = nil
        controller?.testWindow?.close()
        manager = nil
        controller = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var delegate: NSToolbarDelegate {
        return manager
    }

    /// A toolbar with the identifier given, which doesn't save its configuration
    private func toolbar(_ identifier: String = "IFToolbarManagerTests") -> NSToolbar {
        let toolbar = NSToolbar(identifier: identifier)
        toolbar.autosavesConfiguration = false
        return toolbar
    }

    /// The item the manager makes for a toolbar
    private func item(_ identifier: String) -> NSToolbarItem? {
        return delegate.toolbar?(toolbar(), itemForItemIdentifier: NSToolbarItem.Identifier(identifier),
                                 willBeInsertedIntoToolbar: true)
    }

    private func defaultItems(_ identifier: String) -> [String]? {
        return delegate.toolbarDefaultItemIdentifiers?(toolbar(identifier)).map(\.rawValue)
    }

    /// Gives the controller a project of the type given
    private func useProject(_ type: IFFileType) {
        let project = IFProject()
        project.projectFileType = type
        controller.project = project
    }

    /// Gives the controller a window of the width given, off screen and never shown, with the manager's toolbar,
    /// laid out
    @discardableResult
    private func showToolbar(width: CGFloat = 1400) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        controller.testWindow = window

        manager.setToolbar()
        window.layoutIfNeeded()
        manager.redrawToolbar()
        return window
    }

    /// The view that the status view is put in
    private func statusParent(_ window: NSWindow) -> NSView? {
        return window.standardWindowButton(.closeButton)?.superview
    }

    /// The manager's status view, if it's shown in the window
    private func statusView(_ window: NSWindow) -> IFToolbarStatusView? {
        return statusParent(window)?.subviews.compactMap { $0 as? IFToolbarStatusView }.first
    }

    /// The status view's parts that the manager changes
    private func titleText(_ view: IFToolbarStatusView) -> NSTextField { return view.subviews[3] as! NSTextField }
    private func storyText(_ view: IFToolbarStatusView) -> NSTextField { return view.subviews[4] as! NSTextField }
    private func progressBar(_ view: IFToolbarStatusView) -> NSProgressIndicator {
        return view.subviews[5] as! NSProgressIndicator
    }
    private func cancelButton(_ view: IFToolbarStatusView) -> NSButton { return view.subviews[6] as! NSButton }

    /// The span of the status spacer item in the status view's parent
    private func spacerSpan(_ window: NSWindow) throws -> ClosedRange<CGFloat> {
        let spacer = try XCTUnwrap(window.toolbar?.items.first {
            $0.itemIdentifier.rawValue == "toolbarStatusSpacingItem"
        }?.view)
        let parent = try XCTUnwrap(statusParent(window))
        let start = spacer.convert(spacer.bounds.origin, to: parent).x
        let end = spacer.convert(NSPoint(x: NSMaxX(spacer.bounds), y: NSMaxY(spacer.bounds)), to: parent).x
        return start...end
    }

    /// The view in the title bar that holds the toolbar
    private func toolbarView(_ window: NSWindow) -> NSView? {
        return window.contentView?.superview?.subviews.first {
            $0.isKind(of: NSClassFromString("NSTitlebarContainerView")!)
        }
    }

    /// The sender of each Test Selector the project controller was sent
    private var testSelectorSenders: [AnyObject?] {
        return controller.testSelectorSenders.map { $0 as AnyObject? }
    }

    /// The times a story could have started at, from before something is done to after it
    private func times(during action: () -> Void) -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let before = formatter.string(from: Date())
        action()
        return [before, formatter.string(from: Date())]
    }

    private func progress(priority: Int32, bar: Bool = true, cancel: Bool = true) -> IFProgress {
        return IFProgress(priority: priority, showsProgressBar: bar, canCancel: cancel)
    }

    private let testCases: [[String: Any]] = [["testKey": "A", "testTitle": "\"The Lamp\""],
                                              ["testKey": "B", "testTitle": "The Rope"]]

    // MARK: - The toolbar

    func testTheToolbarIsTheInform7ToolbarExceptForExtensionProjects() {
        XCTAssertEqual(manager.toolbarIdentifier, "IFInform7Toolbar", "With no project")

        useProject(.inform7Project)
        XCTAssertEqual(manager.toolbarIdentifier, "IFInform7Toolbar")

        useProject(.inform7ExtensionProject)
        XCTAssertEqual(manager.toolbarIdentifier, "IFInform7ExtensionProjectToolbar")

        XCTAssertEqual(IFToolbarManager().toolbarIdentifier, "IFInform7Toolbar", "With no project controller")
    }

    func testSetToolbarGivesTheWindowAToolbarThatCantBeCustomised() throws {
        useProject(.inform7ExtensionProject)
        let window = showToolbar()

        let toolbar = try XCTUnwrap(window.toolbar)
        XCTAssertEqual(NSStringFromClass(type(of: toolbar)), "Inform.IFToolbar")
        XCTAssertEqual(toolbar.identifier, "IFInform7ExtensionProjectToolbar")
        XCTAssertTrue(toolbar.delegate === manager)
        XCTAssertFalse(toolbar.allowsUserCustomization)
        XCTAssertFalse(toolbar.autosavesConfiguration)
        XCTAssertEqual(toolbar.displayMode, .iconAndLabel)
        XCTAssertEqual(toolbar.items.map(\.itemIdentifier.rawValue), defaultItems("IFInform7ExtensionProjectToolbar"))
    }

    func testEachKindOfToolbarHasItsOwnItems() {
        XCTAssertEqual(defaultItems("IFInform7Toolbar"),
                       ["compileAndRunItem", "replayItem", "releaseItem", "searchProjectItem",
                        "toolbarStatusSpacingItem", "searchDocsItem"])
        XCTAssertEqual(defaultItems("IFInform7ExtensionProjectToolbar"),
                       ["compileAndRunItem", "testItem", "testSelectorItem", "installExtensionItem",
                        "toolbarStatusSpacingItem", "searchProjectItem", "searchDocsItem"])
        XCTAssertEqual(defaultItems("SomethingElse"),
                       ["compileAndRunItem", "replayItem", "releaseItem", "toolbarStatusSpacingItem"])
    }

    func testTheAllowedItems() {
        XCTAssertEqual(delegate.toolbarAllowedItemIdentifiers?(toolbar()).map(\.rawValue),
                       ["compileItem", "compileAndRunItem", "replayItem", "refreshIndexItem", "stopItem",
                        "searchDocsItem", "searchProjectItem", "toolbarStatusSpacingItem",
                        NSToolbarItem.Identifier.space.rawValue, NSToolbarItem.Identifier.flexibleSpace.rawValue,
                        "releaseItem", "testSelectorItem"])
    }

    // MARK: - Items

    func testTheButtonsHaveTheirImagesLabelsTipsAndActions() throws {
        let buttons: [(identifier: String, image: String, label: String, tip: String, action: String)] = [
            ("compileItem", "compile", "Compile", "CompileTip", "compile:"),
            ("compileAndRunItem", "run", "Go!", "GoTip", "compileAndRun:"),
            ("releaseItem", "release", "Release", "ReleaseTip", "release:"),
            ("replayItem", "replay", "Replay", "ReplayTip", "replayUsingSkein:"),
            ("refreshIndexItem", "refresh_index", "Refresh Index", "RefreshIndexTip", "compileAndRefresh:"),
            ("stopItem", "stop", "Stop", "StopTip", "stopProcess:"),
            ("installExtensionItem", "install", "Install Extension", "InstallExtensionTip",
             "installLegacyExtension:"),
            ("testItem", "test", "Test", "TestTip", "testMe:"),
        ]

        for button in buttons {
            let item = try XCTUnwrap(item(button.identifier), button.identifier)
            XCTAssertEqual(item.itemIdentifier.rawValue, button.identifier)
            XCTAssertNotNil(item.image, button.identifier)
            XCTAssertTrue(item.image === NSImage(named: "App/Toolbar/\(button.image)"), button.identifier)
            XCTAssertEqual(item.label, IFUtility.localizedString(button.label), button.identifier)
            XCTAssertEqual(item.paletteLabel, item.label, button.identifier)
            XCTAssertEqual(item.toolTip, IFUtility.localizedString(button.tip, default: nil), button.identifier)
            XCTAssertEqual(item.action, NSSelectorFromString(button.action), button.identifier)
            XCTAssertNil(item.view, button.identifier)
        }
    }

    func testEachItemIsANewCopy() throws {
        let first = try XCTUnwrap(item("compileItem"))
        let second = try XCTUnwrap(item("compileItem"))
        XCTAssertFalse(first === second)

        let firstSearch = try XCTUnwrap(item("searchDocsItem")?.view)
        let secondSearch = try XCTUnwrap(item("searchDocsItem")?.view)
        XCTAssertFalse(firstSearch === secondSearch)
    }

    func testThereIsNoItemForAnUnknownIdentifier() {
        XCTAssertNil(item("unknownItem"))
    }

    private func checkWidthLimits(_ view: NSView, _ minimum: CGFloat, _ maximum: CGFloat,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let widths = view.constraints.filter { $0.firstAttribute == .width && $0.firstItem === view }
        XCTAssertEqual(widths.count, 2, file: file, line: line)
        XCTAssertEqual(widths.first { $0.relation == .greaterThanOrEqual }?.constant, minimum, file: file, line: line)
        XCTAssertEqual(widths.first { $0.relation == .lessThanOrEqual }?.constant, maximum, file: file, line: line)
        XCTAssertTrue(widths.allSatisfy(\.isActive), file: file, line: line)
    }

    func testTheSearchItemsAreSearchFieldsThatSearchWhenReturnIsPressed() throws {
        let searches = [("searchDocsItem", "Search Documentation", "SearchDocsTip", "Documentation", "searchDocs:"),
                        ("searchProjectItem", "Search Project", "SearchProjectTip", "Project", "searchProject:")]

        for (identifier, label, tip, placeholder, action) in searches {
            let item = try XCTUnwrap(item(identifier))
            XCTAssertEqual(item.label, "", identifier)
            XCTAssertEqual(item.paletteLabel, IFUtility.localizedString(label), identifier)
            XCTAssertEqual(item.toolTip, IFUtility.localizedString(tip, default: nil), identifier)

            let field = try XCTUnwrap(item.view as? NSSearchField, identifier)
            let cell = try XCTUnwrap(field.cell as? NSSearchFieldCell, identifier)
            XCTAssertEqual(cell.placeholderString, IFUtility.localizedString(placeholder), identifier)
            XCTAssertTrue(cell.isScrollable, identifier)
            XCTAssertTrue(cell.sendsWholeSearchString, identifier)
            XCTAssertFalse(field.isContinuous, identifier)
            XCTAssertTrue(field.target === controller, identifier)
            XCTAssertEqual(field.action, NSSelectorFromString(action), identifier)
            checkWidthLimits(field, 70, 150)
        }
    }

    func testTheTestCaseItemIsAMenuOfTestCases() throws {
        XCTAssertNil(manager.testCasesPopUpButton, "Not made until the toolbar asks for it")

        let item = try XCTUnwrap(item("testSelectorItem"))
        XCTAssertEqual(item.label, IFUtility.localizedString("Test Case"))
        XCTAssertEqual(item.paletteLabel, item.label)
        XCTAssertEqual(item.toolTip, IFUtility.localizedString("TestSelectorTip", default: nil))
        XCTAssertEqual(item.action, NSSelectorFromString("testSelector:"))

        let popUp = try XCTUnwrap(item.view as? NSPopUpButton)
        XCTAssertTrue(manager.testCasesPopUpButton === popUp)
        XCTAssertFalse(popUp.pullsDown)
        XCTAssertEqual(popUp.numberOfItems, 0)
        XCTAssertTrue(popUp.target === controller)
        XCTAssertEqual(popUp.action, NSSelectorFromString("testSelector:"))
        checkWidthLimits(popUp, 100, 190)

        let another = try XCTUnwrap(self.item("testSelectorItem")?.view)
        XCTAssertTrue(manager.testCasesPopUpButton === another, "The latest is kept")
    }

    func testTheStatusSpacerIsAFlexibleSpaceWithNoLabel() throws {
        let item = try XCTUnwrap(item("toolbarStatusSpacingItem"))
        XCTAssertEqual(item.label, "")
        XCTAssertEqual(item.paletteLabel, "")
        XCTAssertNil(item.image)
        XCTAssertNil(item.action)
        let view = try XCTUnwrap(item.view)
        XCTAssertEqual(String(describing: type(of: view)), "IFToolbarStatusSpacingView")
        checkWidthLimits(view, 10, 10000)
    }

    /// The status view is drawn over the status spacer item, and is hidden if the spacer is too narrow
    /// for it, so the spacer has to take up the toolbar's spare width.
    func testStatusSpacerTakesTheSpareWidth() throws {
        let manager = IFToolbarManager()
        let toolbar = NSToolbar(identifier: "IFInform7Toolbar")
        toolbar.autosavesConfiguration = false
        toolbar.delegate = manager

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.toolbar = toolbar
        window.layoutIfNeeded()

        let spacer = try XCTUnwrap(toolbar.items.first { $0.itemIdentifier.rawValue == "toolbarStatusSpacingItem" }?.view)
        XCTAssertGreaterThan(spacer.frame.width, 300)
    }

    // MARK: - Validating items

    private func isEnabled(_ action: String?, identifier: String = "someItem") -> Bool {
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(identifier))
        item.action = action.map(NSSelectorFromString)
        return manager.validateToolbarItem(item)
    }

    private let buildActions = ["compile:", "release:", "releaseForTesting:", "compileAndRun:", "replayUsingSkein:",
                                "compileAndRefresh:"]

    func testStopIsOnlyEnabledWhileAStoryIsRunning() {
        XCTAssertFalse(isEnabled("stopProcess:", identifier: "stopItem"))
        controller.gameIsRunning = true
        XCTAssertTrue(isEnabled("stopProcess:", identifier: "stopItem"))
        XCTAssertTrue(isEnabled(nil, identifier: "stopItem"), "It goes by the identifier")

        controller.gameIsRunning = false
        XCTAssertTrue(isEnabled("stopProcess:"), "Not for another item")
    }

    func testBuildingIsDisabledWhileCompiling() {
        for action in buildActions {
            XCTAssertTrue(isEnabled(action), action)
        }

        controller.compilingNow = true
        for action in buildActions {
            XCTAssertFalse(isEnabled(action), action)
        }
        XCTAssertTrue(isEnabled("searchDocs:"))
        XCTAssertTrue(isEnabled(nil))
    }

    func testBuildingAnExtensionProjectNeedsATestCaseChosen() throws {
        useProject(.inform7ExtensionProject)
        let popUp = try XCTUnwrap(item("testSelectorItem")?.view as? NSPopUpButton)
        for action in buildActions {
            XCTAssertFalse(isEnabled(action), "No test cases: \(action)")
        }

        manager.setTestCases(testCases)
        for action in buildActions {
            XCTAssertFalse(isEnabled(action), "Test All: \(action)")
        }

        popUp.selectItem(at: 2)
        for action in buildActions {
            XCTAssertTrue(isEnabled(action), action)
        }

        controller.compilingNow = true
        for action in buildActions {
            XCTAssertFalse(isEnabled(action), "Compiling: \(action)")
        }
    }

    func testTestingNeedsTestCasesAndIsDisabledWhileTesting() {
        XCTAssertFalse(isEnabled("testMe:"))

        manager.setTestCases(testCases)
        XCTAssertTrue(isEnabled("testMe:"))

        controller.testingNow = true
        XCTAssertFalse(isEnabled("testMe:"))
    }

    // MARK: - Test cases

    func testTestCasesWithNoMenu() {
        XCTAssertEqual(manager.numberOfTestCases, 0)
        XCTAssertNil(manager.getTestCase(0))

        manager.setTestCases(testCases)
        XCTAssertEqual(manager.testCases?.count, 2)
        XCTAssertEqual(manager.numberOfTestCases, 2)
        XCTAssertEqual(manager.getTestCase(0), "A")
        XCTAssertEqual(manager.getTestCase(1), "B")
        XCTAssertNil(manager.getTestCase(2))
        XCTAssertNil(manager.getTestCase(-1))
        XCTAssertEqual(manager.testCaseIndex, -1, "None is chosen")
        XCTAssertNil(manager.currentTestCase)

        manager.setTestCases(nil)
        XCTAssertNil(manager.testCases)
        XCTAssertEqual(manager.numberOfTestCases, 0)
        XCTAssertNil(manager.getTestCase(0))
    }

    func testTheMenuListsTestAllAndTheTestCasesWithoutQuotes() throws {
        let popUp = try XCTUnwrap(item("testSelectorItem")?.view as? NSPopUpButton)

        manager.setTestCases(testCases)
        XCTAssertEqual(popUp.itemTitles, [IFUtility.localizedString("Test All"), "The Lamp", "The Rope"])
        XCTAssertEqual(popUp.indexOfSelectedItem, 0)
        XCTAssertEqual(manager.testCaseIndex, -1, "Test All")
        XCTAssertNil(manager.currentTestCase)

        popUp.selectItem(at: 1)
        XCTAssertEqual(manager.testCaseIndex, 0)
        XCTAssertEqual(manager.currentTestCase, "A")

        popUp.selectItem(at: 2)
        XCTAssertEqual(manager.testCaseIndex, 1)
        XCTAssertEqual(manager.currentTestCase, "B")

        manager.setTestCases([])
        XCTAssertEqual(popUp.numberOfItems, 0, "No Test All without test cases")
        XCTAssertEqual(manager.testCaseIndex, -1)
        XCTAssertNil(manager.currentTestCase)
    }

    func testTheChosenTestCaseIsKeptByItsTitle() throws {
        let popUp = try XCTUnwrap(item("testSelectorItem")?.view as? NSPopUpButton)
        manager.setTestCases(testCases)
        popUp.selectItem(at: 2)

        manager.setTestCases([["testKey": "C", "testTitle": "The Rope"], ["testKey": "D", "testTitle": "The Box"]])
        XCTAssertEqual(popUp.titleOfSelectedItem, "The Rope")
        XCTAssertEqual(manager.currentTestCase, "C")

        manager.setTestCases(testCases.reversed())
        XCTAssertEqual(popUp.titleOfSelectedItem, "The Rope")
        XCTAssertEqual(manager.currentTestCase, "B")

        manager.setTestCases([["testKey": "E", "testTitle": "The Lantern"]])
        XCTAssertEqual(popUp.indexOfSelectedItem, 0, "Test All, when the title has gone")
        XCTAssertNil(manager.currentTestCase)
    }

    func testSelectingATestCaseByItsKeyChoosesItAndTellsTheProjectController() throws {
        let popUp = try XCTUnwrap(item("testSelectorItem")?.view as? NSPopUpButton)
        manager.setTestCases(testCases)

        XCTAssertTrue(manager.selectTestCase("b"))
        XCTAssertEqual(popUp.indexOfSelectedItem, 2)
        XCTAssertEqual(testSelectorSenders.count, 1)
        XCTAssertTrue(testSelectorSenders.first! === popUp)

        XCTAssertFalse(manager.selectTestCase("C"))
        XCTAssertEqual(popUp.indexOfSelectedItem, 2)
        XCTAssertEqual(testSelectorSenders.count, 1)
    }

    func testSelectingATestCaseWithNoMenuStillTellsTheProjectController() {
        manager.setTestCases(testCases)

        XCTAssertTrue(manager.selectTestCase("A"))
        XCTAssertEqual(testSelectorSenders.count, 1)
        XCTAssertNil(testSelectorSenders.first!)
        XCTAssertNil(manager.currentTestCase)
    }

    // MARK: - The status view

    func testTheStatusViewIsCentredInTheToolbarOverTheSpacer() throws {
        let window = showToolbar(width: 2000)
        let view = try XCTUnwrap(statusView(window))
        XCTAssertTrue(view.delegate === manager)

        let parent = try XCTUnwrap(statusParent(window))
        let container = try XCTUnwrap(toolbarView(window))
        let toolbarRect = parent.convert(container.bounds, from: container)
        XCTAssertEqual(toolbarRect.width, 2000)
        XCTAssertEqual(view.frame, NSRect(x: 850, y: floor(toolbarRect.minY + 16), width: 300, height: 30))

        let span = try spacerSpan(window)
        XCTAssertTrue(span.contains(view.frame.minX) && span.contains(view.frame.maxX))
    }

    func testTheStatusViewStartsNoFurtherLeftThanTheSpacer() throws {
        let window = showToolbar(width: 1400)
        let view = try XCTUnwrap(statusView(window))

        let span = try spacerSpan(window)
        XCTAssertGreaterThan(span.lowerBound, 550, "The middle is left of the spacer")
        XCTAssertEqual(view.frame.minX, span.lowerBound)
        XCTAssertEqual(view.frame.width, 300)
    }

    func testTheStatusViewIsHiddenWhenTheSpacerIsTooNarrow() throws {
        let window = showToolbar(width: 500)
        let span = try spacerSpan(window)
        XCTAssertLessThan(span.upperBound - span.lowerBound, 300)
        XCTAssertNil(statusView(window))
    }

    func testTheStatusViewIsHiddenWithNoSpacer() throws {
        let window = showToolbar()
        let toolbar = try XCTUnwrap(window.toolbar)
        let spacer = try XCTUnwrap(toolbar.items.firstIndex { $0.itemIdentifier.rawValue == "toolbarStatusSpacingItem" })
        toolbar.removeItem(at: spacer)
        defer {
            toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier("toolbarStatusSpacingItem"), at: spacer)
        }
        window.layoutIfNeeded()

        XCTAssertNil(statusView(window))
    }

    func testTheStatusViewFollowsTheWindowsSize() throws {
        let window = showToolbar(width: 2000)
        let view = try XCTUnwrap(statusView(window))
        XCTAssertEqual(view.frame.minX, 850)

        window.setContentSize(NSSize(width: 1200, height: 300))
        let span = try spacerSpan(window)
        XCTAssertGreaterThan(span.lowerBound, 450)
        XCTAssertEqual(view.frame.minX, span.lowerBound)
        XCTAssertTrue(statusView(window) === view)

        window.setContentSize(NSSize(width: 2000, height: 300))
        XCTAssertEqual(view.frame.minX, max(850, try spacerSpan(window).lowerBound),
                       "The middle, or the spacer's start if that's further right")
    }

    func testTheStatusViewIsTakenOutWhileGoingInOrOutOfFullScreen() throws {
        let window = showToolbar()
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.close() }

        for (will, did) in [(NSWindow.willEnterFullScreenNotification, NSWindow.didEnterFullScreenNotification),
                            (NSWindow.willExitFullScreenNotification, NSWindow.didExitFullScreenNotification)] {
            NotificationCenter.default.post(name: will, object: other)
            XCTAssertNotNil(statusView(window), "Not for another window: \(will.rawValue)")

            NotificationCenter.default.post(name: will, object: window)
            XCTAssertNil(statusView(window), will.rawValue)

            NotificationCenter.default.post(name: did, object: window)
            XCTAssertNotNil(statusView(window), did.rawValue)
        }
    }

    func testTheStatusViewIsHiddenWithTheToolbar() throws {
        let window = showToolbar()
        let toolbar = try XCTUnwrap(window.toolbar)

        toolbar.isVisible = false
        NotificationCenter.default.post(name: Notification.Name("IFToolbarChangedVisibility"), object: toolbar)
        XCTAssertNil(statusView(window))

        toolbar.isVisible = true
        window.layoutIfNeeded()
        NotificationCenter.default.post(name: Notification.Name("IFToolbarChangedVisibility"), object: toolbar)
        XCTAssertNotNil(statusView(window))
    }

    /// View ▸ Hide Toolbar and Show Toolbar set the toolbar's visibility, and the manager hears of it
    func testHidingOrShowingTheToolbarIsPosted() throws {
        let window = showToolbar()
        let toolbar = try XCTUnwrap(window.toolbar)
        var posted = 0
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name("IFToolbarChangedVisibility"),
                                                              object: toolbar, queue: nil) { _ in
            posted += 1
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        toolbar.isVisible = false
        XCTAssertEqual(posted, 1)
        XCTAssertNil(statusView(window))

        toolbar.isVisible = true
        XCTAssertEqual(posted, 2)
    }

    func testMessagesGoToTheStatusView() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))

        manager.showMessage("Compiling")
        XCTAssertEqual(titleText(view).stringValue, "Compiling")
    }

    // MARK: - Progress

    func testAProgressIndicatorIsShownInTheStatusView() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))
        XCTAssertTrue(progressBar(view).isHidden)

        let indicator = progress(priority: IFProgressPriorityCompiler)
        manager.addProgressIndicator(indicator)
        XCTAssertTrue(indicator.delegate === manager)
        XCTAssertFalse(progressBar(view).isHidden, "Shown as soon as it's added")
        XCTAssertFalse(cancelButton(view).isHidden)
        XCTAssertEqual(progressBar(view).maxValue, 100)
        XCTAssertTrue(progressBar(view).isIndeterminate)

        indicator.start()
        indicator.percentage = 40
        XCTAssertFalse(progressBar(view).isIndeterminate)
        XCTAssertEqual(progressBar(view).doubleValue, 40)

        indicator.message = "Translating the source"
        XCTAssertEqual(titleText(view).stringValue, "Translating the source")

        indicator.message = nil
        XCTAssertEqual(titleText(view).stringValue, "Translating the source", "No message leaves the last")

        manager.removeProgressIndicator(indicator)
        XCTAssertNil(indicator.delegate)
        XCTAssertTrue(progressBar(view).isHidden)
        XCTAssertTrue(cancelButton(view).isHidden)
    }

    func testAProgressIndicatorWithNoBarOrCancelShowsNeither() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))

        let indicator = progress(priority: IFProgressPrioritySyntax, bar: false, cancel: false)
        manager.addProgressIndicator(indicator)
        indicator.start()
        XCTAssertTrue(progressBar(view).isHidden)
        XCTAssertTrue(cancelButton(view).isHidden)
    }

    func testTheStatusViewShowsTheActiveIndicatorOfHighestPriority() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))

        let low = progress(priority: IFProgressPrioritySyntax)
        let high = progress(priority: IFProgressPriorityTestAll)
        manager.addProgressIndicator(low)
        manager.addProgressIndicator(high)
        low.message = "Low"
        high.message = "High"
        low.percentage = 10
        high.percentage = 90
        XCTAssertEqual(progressBar(view).doubleValue, 90, "Neither is active, so the higher")

        low.start()
        low.percentage = 10
        XCTAssertEqual(progressBar(view).doubleValue, 10, "The active one")
        XCTAssertEqual(titleText(view).stringValue, "Low")

        high.start()
        high.percentage = 90
        XCTAssertEqual(progressBar(view).doubleValue, 90, "Both active, so the higher")

        manager.removeProgressIndicator(high)
        XCTAssertEqual(progressBar(view).doubleValue, 10)
    }

    func testCancellingCancelsTheIndicatorShown() throws {
        let low = progress(priority: IFProgressPrioritySyntax)
        let high = progress(priority: IFProgressPriorityTestAll)
        manager.addProgressIndicator(low)
        manager.addProgressIndicator(high)
        low.start()

        manager.cancelProgress()
        XCTAssertTrue(low.isCancelled)
        XCTAssertFalse(high.isCancelled)
    }

    func testTheCancelButtonIsHiddenOnceCancelled() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))
        let indicator = progress(priority: IFProgressPriorityCompiler)
        manager.addProgressIndicator(indicator)
        indicator.start()
        XCTAssertFalse(cancelButton(view).isHidden)

        manager.cancelProgress()
        manager.updateProgress()
        XCTAssertTrue(cancelButton(view).isHidden)
    }

    func testStoriesStartingAndStoppingAreShownInTheStatusView() throws {
        let window = showToolbar()
        let view = try XCTUnwrap(statusView(window))
        let indicator = progress(priority: IFProgressPriorityRunGame, bar: false)
        manager.addProgressIndicator(indicator)

        let started = times { indicator.startStory() }.map {
            String(format: IFUtility.localizedString("Story started at %@."), $0)
        }
        XCTAssertTrue(started.contains(storyText(view).stringValue), storyText(view).stringValue)
        XCTAssertFalse(storyText(view).isHidden)

        indicator.stopStory()
        XCTAssertEqual(storyText(view).stringValue, IFUtility.localizedString("Story stopped."))
    }

    // MARK: - The project controller

    /// A project controller owns its toolbar manager, so the manager mustn't keep the controller alive:
    /// if it did, neither would be freed once the project's window had closed.
    func testDoesNotKeepItsProjectControllerAlive() {
        weak var weakController: IFProjectController?
        autoreleasepool {
            let controller = IFProjectController()
            weakController = controller
        }

        XCTAssertNil(weakController)
    }

    func testTheProjectControllerIsKeptWeakly() {
        var manager: IFToolbarManager?
        autoreleasepool {
            let controller = ProjectControllerStandIn()
            manager = IFToolbarManager(projectController: controller)
            XCTAssertTrue(manager?.projectController === controller)
        }

        XCTAssertNotNil(manager)
        XCTAssertNil(manager?.projectController)
    }
}
