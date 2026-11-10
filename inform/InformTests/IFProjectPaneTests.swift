//
//  IFProjectPaneTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller whose window, once loaded, isn't given an autosave name, which would keep its frame in the
/// user's preferences, nor hides the welcome window; which doesn't keep the panes' widths in the user's preferences;
/// and which can say it isn't safe for the panes to switch their pages, as a controller does while its window is
/// being restored
private final class TestProjectController: IFProjectController {
    var tabsMaySwitch = true

    override func windowDidLoad() {
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
    }

    override var safeToSwitchTabs: Bool {
        return tabsMaySwitch
    }
}

/// The two sides of a project window, with their real window and controller, kept off the screen and never shown
final class IFProjectPaneTests: XCTestCase {
    private var folder: URL!
    private var project: IFProject!
    private var controller: TestProjectController!
    /// The panes, which show the source and the documentation at first
    private var left: IFProjectPane!
    private var right: IFProjectPane!

    override func setUpWithError() throws {
        try super.setUpWithError()

        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = folder.appendingPathComponent("Lighthouse.inform/Source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("\"Lighthouse\" by Me\n\nThe Lamp Room is a room.\n".utf8)
            .write(to: source.appendingPathComponent("story.ni"))

        // An index, as a translation leaves, so that the index page can be shown
        let index = folder.appendingPathComponent("Lighthouse.inform/Index", isDirectory: true)
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        try Data("<html><body>Welcome</body></html>".utf8).write(to: index.appendingPathComponent("Welcome.html"))
        project = try IFProject(contentsOf: folder.appendingPathComponent("Lighthouse.inform"),
                                ofType: "org.inform-fiction.project")

        controller = TestProjectController()
        project.addWindowController(controller)
        let window = try XCTUnwrap(controller.window)
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))

        left = try XCTUnwrap(controller.sourcePane)
        right = try XCTUnwrap(controller.auxPane)
    }

    override func tearDownWithError() throws {
        // The panes' pages each start a process of their own to load in, which are let finish first, or they're still
        // starting as the tests after these run, and slow them
        waitForPagesToLoad(in: [left, right].compactMap { $0 })

        controller?.close()
        project?.close()
        left = nil
        right = nil
        controller = nil
        project = nil
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
        try super.tearDownWithError()
    }

    /// Waits for the web views in the panes' pages, shown or not, to finish loading
    private func waitForPagesToLoad(in panes: [IFProjectPane]) {
        var webViews: [WKWebView] = []
        func find(in view: NSView) {
            if let webView = view as? WKWebView {
                webViews.append(webView)
            } else {
                view.subviews.forEach(find(in:))
            }
        }
        for pane in panes {
            pane.tabView.tabViewItems.compactMap { $0.view }.forEach(find(in:))
        }

        let limit = Date(timeIntervalSinceNow: 10)
        while webViews.contains(where: { $0.isLoading }) && Date() < limit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertFalse(webViews.contains { $0.isLoading }, "The panes' pages didn't finish loading")
    }

    /// The pages of a pane, in the order of its tabs
    private func pages(of pane: IFProjectPane) -> [IFPage] {
        let pages: [IFPage?] = [pane.sourcePage, pane.errorsPage, pane.gamePage, pane.skeinPage, pane.indexPage,
                                pane.documentationPage, pane.extensionsPage, pane.settingsPage]
        return pages.compactMap { $0 }
    }

    /// The pages that a pane can show of each type of view, other than the game, which needs a story running
    private func pagesOfEachType(in pane: IFProjectPane) -> [(page: IFPage, type: IFProjectPaneType)] {
        return [(pane.sourcePage, .sourcePane), (pane.errorsPage, .errorPane), (pane.skeinPage, .skeinPane),
                (pane.indexPage, .indexPane), (pane.documentationPage, .documentationPane),
                (pane.extensionsPage, .extensionsPane)]
    }

    /// The identifier of the page a pane shows, its class's name
    private func pageShown(_ pane: IFProjectPane) -> String? {
        return pane.tabView.selectedTabViewItem?.identifier as? String
    }

    // MARK: - The pages

    func testEachPaneHasItsPagesInOrderAndOnlyTheSecondCanRunAStory() {
        let classes: [IFPage.Type] = [IFSourcePage.self, IFErrorsPage.self, IFGamePage.self, IFSkeinPage.self,
                                      IFIndexPage.self, IFDocumentationPage.self, IFExtensionsPage.self,
                                      IFSettingsPage.self]
        let identifiers = classes.map { $0.description() }
        XCTAssertEqual(right.tabView.tabViewItems.compactMap { $0.identifier as? String }, identifiers)
        XCTAssertEqual(left.tabView.tabViewItems.compactMap { $0.identifier as? String },
                       identifiers.filter { $0 != IFGamePage.description() })
        XCTAssertNil(left.gamePage)
        XCTAssertNotNil(right.gamePage)
        XCTAssertEqual(pages(of: right).map { $0.identifier }, identifiers)
    }

    func testEachPageIsShownInItsTabUnderItsTitle() {
        for pane in [left!, right!] {
            for page in pages(of: pane) {
                let index = pane.tabView.indexOfTabViewItem(withIdentifier: page.identifier)
                let item = pane.tabView.tabViewItem(at: index)
                XCTAssertTrue(page.view.superview === item.view, page.identifier)
                XCTAssertEqual(item.label, page.title)
            }
        }
    }

    func testEachPageKnowsItsPaneAndTheOtherAndRecordsItsHistoryInItsPane() {
        for (pane, other) in [(left!, right!), (right!, left!)] {
            for page in pages(of: pane) {
                XCTAssertTrue(page.thisPane === pane, page.identifier)
                XCTAssertTrue(page.otherPane === other, page.identifier)
                XCTAssertTrue(page.recorder as AnyObject? === pane, page.identifier)
            }
        }
    }

    func testTheCompilerControllerIsTheErrorsPages() {
        XCTAssertTrue(right.compilerController === right.errorsPage.compilerController)
        XCTAssertFalse(left.compilerController === right.compilerController)
    }

    // MARK: - What a pane shows

    func testWhatAPaneShowsIsTheTypeOfThePageShown() {
        for (page, type) in pagesOfEachType(in: right) {
            right.tabView.selectTabViewItem(withIdentifier: page.identifier)
            XCTAssertEqual(pageShown(right), page.identifier)
            XCTAssertEqual(right.currentView, type, page.identifier)
        }
    }

    func testSelectingATypeOfViewShowsItsPage() {
        for (page, type) in pagesOfEachType(in: right) {
            right.selectView(of: type)
            XCTAssertEqual(pageShown(right), page.identifier)
        }

        // An unknown type shows nothing new
        right.selectView(of: .unknownPane)
        XCTAssertEqual(pageShown(right), right.extensionsPage.identifier)
    }

    /// The Settings page has no type of view of its own, so it's not taken for the source
    func testAPaneShowingTheSettingsShowsNoKnownTypeOfView() {
        right.tabView.selectTabViewItem(withIdentifier: right.settingsPage.identifier)
        XCTAssertEqual(right.currentView, .unknownPane)
        XCTAssertTrue(right.activeView === right.tabView.selectedTabViewItem?.view)
    }

    /// With the Settings on the left and the source on the right, the source and what goes beside it, such as the
    /// documentation, go where they are, and the source's commands aren't enabled for the Settings
    func testAPaneShowingTheSettingsIsntTakenForTheSource() {
        left.tabView.selectTabViewItem(withIdentifier: left.settingsPage.identifier)
        right.selectView(of: .sourcePane)
        XCTAssertTrue(controller.sourcePane === right)
        XCTAssertTrue(controller.auxPane === left)

        controller.changeFirstResponder(left.tabView)
        XCTAssertFalse(controller.isSourcePaneCurrent)
    }

    func testTheGameIsntShownWithNoStoryRunning() {
        right.selectView(of: .gamePane)
        XCTAssertEqual(right.currentView, .documentationPane)
    }

    func testNoPageIsShownWhileTheControllerSaysItsntSafe() {
        controller.tabsMaySwitch = false
        right.selectView(of: .indexPane)
        XCTAssertEqual(right.currentView, .documentationPane)

        controller.tabsMaySwitch = true
        right.selectView(of: .indexPane)
        XCTAssertEqual(right.currentView, .indexPane)
    }

    func testShowingAPageMakesItVisibleAndTheOneBeforeNot() {
        right.selectView(of: .indexPane)
        XCTAssertTrue(right.indexPage.pageIsVisible)
        XCTAssertFalse(right.documentationPage.pageIsVisible)

        right.selectView(of: .skeinPane)
        XCTAssertTrue(right.skeinPage.pageIsVisible)
        XCTAssertFalse(right.indexPage.pageIsVisible)
    }

    func testAPageThatAsksToBeShownIsShownInItsOwnPane() {
        left.indexPage.switchToPage()
        XCTAssertEqual(left.currentView, .indexPane)
        XCTAssertEqual(right.currentView, .documentationPane)
    }

    func testAPageThatAsksToBeShownFromAnotherIsShownOnlyFromThatOne() {
        let index = right.indexPage.identifier
        right.indexPage.switchToPage(withIdentifier: index, fromPage: right.skeinPage.identifier)
        XCTAssertEqual(right.currentView, .documentationPane)

        right.indexPage.switchToPage(withIdentifier: index, fromPage: right.documentationPage.identifier)
        XCTAssertEqual(right.currentView, .indexPane)
    }

    func testTheActiveViewIsTheSourcesTextViewOrThePageShown() {
        XCTAssertEqual(left.currentView, .sourcePane)
        XCTAssertTrue(left.activeView === left.sourcePage.activeView)
        XCTAssertTrue(right.activeView === right.tabView.selectedTabViewItem?.view)

        right.selectView(of: .indexPane)
        XCTAssertTrue(right.activeView === right.tabView.selectedTabViewItem?.view)
    }

    // MARK: - The history

    /// The history is a proxy, which records any message it's sent, so it's only compared with nil, as XCTest would
    /// ask it for its description
    func testThePanesHistoryIsAProxyAimedAtThePane() throws {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        let event = try XCTUnwrap(right.historyEvent)
        let history = right.history as AnyObject?
        XCTAssertTrue(history != nil)
        XCTAssertTrue(right.historyEvent === event)
        XCTAssertTrue(event.target as AnyObject? === right)
    }

    func testOnceClosedThePaneHasNoHistory() {
        for type in [IFProjectPaneType.indexPane, .skeinPane] {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            right.selectView(of: type)
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))

        right.willClose()
        right.goBackwards(nil)
        XCTAssertEqual(right.currentView, .skeinPane)
    }

    // MARK: - Other

    func testRemovingThePaneTakesItsViewOutOfTheWindow() {
        XCTAssertNotNil(right.paneView.superview)
        right.removeFromSuperview()
        XCTAssertNil(right.paneView.superview)
    }

    func testTheAttributesOfASyntaxStyleAreThePreferencesStyle() {
        for style in [IFSyntaxStyle.string, .comment, .naturalInform, .heading] {
            XCTAssertEqual(IFProjectPane.attribute(for: style) as NSDictionary,
                           IFPreferences.shared.styles[Int(style.rawValue)])
        }
    }

    /// A pane that's never given a controller isn't set up, but records its history, which holds on to the pane until
    /// it's closed
    func testAStandardPaneIsANewOne() throws {
        weak var freed: IFProjectPane?
        try autoreleasepool {
            let pane = IFProjectPane.standard()
            freed = pane
            XCTAssertFalse(pane === IFProjectPane.standard())
            let event = try XCTUnwrap(pane.historyEvent)
            XCTAssertTrue(event.target as AnyObject? === pane)
            pane.willClose()
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        XCTAssertNil(freed)
    }
}
