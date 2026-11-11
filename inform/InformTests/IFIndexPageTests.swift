//
//  IFIndexPageTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no window, whose document is the project the test gives it
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which the page asks for its index
    var project: IFProject?

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }
}

/// Gives the page a history event, as a pane would, and counts how often it's asked for one, which the page only
/// does to record something
private final class Recorder: NSObject, IFHistoryRecorder {
    /// The event that what the page records goes in
    var event = IFHistoryEvent(object: NSNull())
    /// How often the page has asked for the event
    private(set) var timesAsked = 0

    var historyEvent: IFHistoryEvent? {
        timesAsked += 1
        return event
    }
}

/// A web view showing whatever URL the test gives it, for telling the page that a navigation has started without
/// loading anything
private final class WebViewStandIn: WKWebView {
    var shownURL: URL?

    override var url: URL? {
        return shownURL
    }
}

/// Stands between the page's web view and the page, its navigation delegate, passing on what the page is told, and
/// telling the tests when a navigation starts and finishes
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    private let page: WKNavigationDelegate
    /// The URL of each navigation that the page has been told has started
    private(set) var started: [URL?] = []
    /// The errors of the navigations that failed
    private(set) var errors: [Error] = []
    /// Called when a navigation starts
    var onStart: (() -> Void)?
    /// Called when a navigation finishes or fails
    var onFinish: (() -> Void)?

    init(_ page: IFIndexPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        page.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        started.append(webView.url)
        page.webView?(webView, didStartProvisionalNavigation: navigation)
        onStart?()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        errors.append(error)
        onFinish?()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        errors.append(error)
        onFinish?()
    }
}

@MainActor
final class IFIndexPageTests: XCTestCase, @unchecked Sendable {

    /// A page being tested, with its web view and the watcher between them
    private struct Shown {
        let page: IFIndexPage
        let webView: WKWebView
        let watcher: NavigationWatcher
    }

    /// The pages of an index, as Inform names them, and the tab each is for
    private let indexPages: [(file: String, tab: IFIndexTabType)] = [
        ("Actions.html", .actions), ("Contents.html", .contents), ("Kinds.html", .kinds),
        ("Phrasebook.html", .phrasebook), ("Rules.html", .rules), ("Scenes.html", .scenes),
        ("Welcome.html", .welcome), ("World.html", .world),
    ]

    /// The page's project controller, which the page doesn't keep
    private var controller: ProjectControllerStandIn?
    /// The pages made, kept until the test ends, as a web view doesn't keep its navigation delegate
    private var shown: [Shown] = []
    /// The folder the project is in, removed when the test ends
    private var folder: URL?

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            try super.setUpWithError()

            // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
            // toolbar for them, which saves its configuration in the user's preferences.
            let controller = ProjectControllerStandIn()
            NotificationCenter.default.removeObserver(controller)
            self.controller = controller

            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
        }
    }

    override func tearDownWithError() throws {
        try MainActor.assumeIsolated {
            shown = []
            controller = nil
            if let folder {
                try FileManager.default.removeItem(at: folder)
            }
            folder = nil
            try super.tearDownWithError()
        }
    }

    /// The project's index folder
    private var indexFolder: URL {
        get throws {
            return try XCTUnwrap(folder).appendingPathComponent("Test.inform/Index", isDirectory: true)
        }
    }

    /// The URL of a page of the project's index
    private func indexURL(_ file: String) throws -> URL {
        return try indexFolder.appendingPathComponent(file)
    }

    /// Writes the given pages of the project's index, each saying its name
    private func writeIndex(_ files: [String]) throws {
        try FileManager.default.createDirectory(at: indexFolder, withIntermediateDirectories: true)
        for file in files {
            try writePage(file, saying: (file as NSString).deletingPathExtension)
        }
    }

    /// Writes a page of the project's index
    private func writePage(_ file: String, saying text: String) throws {
        try Data("<html><body><p>\(text)</p></body></html>".utf8).write(to: indexURL(file))
    }

    /// An index page for a project in the test's folder, hidden, as a pane makes it
    private func makePage(recorder: Recorder? = nil) throws -> Shown {
        let project = IFProject()
        project.fileURL = try XCTUnwrap(folder).appendingPathComponent("Test.inform")

        let controller = try XCTUnwrap(controller)
        controller.project = project
        let page = IFIndexPage(projectController: controller, with: IFProjectPane())
        page.recorder = recorder

        let webView = try XCTUnwrap(page.view.subviews.compactMap { $0 as? WKWebView }.first)
        let watcher = NavigationWatcher(page)
        webView.navigationDelegate = watcher

        let made = Shown(page: page, webView: webView, watcher: watcher)
        shown.append(made)
        return made
    }

    /// An index page for a project with a whole index, showing its welcome page, as a pane starts it
    private func makePageShowingTheIndex(recorder: Recorder? = nil) throws -> Shown {
        try writeIndex(indexPages.map { $0.file })
        let shown = try makePage(recorder: recorder)
        shown.page.updateIndexView()
        waitForNavigation(shown.watcher) {
            shown.page.switch(toTab: IFIndexTabType.welcome.rawValue)
        }
        return shown
    }

    /// Runs the block, and waits for the navigation it starts to finish
    private func waitForNavigation(_ watcher: NavigationWatcher, during block: () -> Void) {
        let finished = expectation(description: "navigation finished")
        watcher.onFinish = {
            finished.fulfill()
        }
        block()
        wait(for: [finished], timeout: 10)
        watcher.onFinish = nil
    }

    /// Runs the block, and checks that no navigation starts
    private func expectNoNavigation(_ watcher: NavigationWatcher, during block: () -> Void) {
        let started = expectation(description: "navigation started")
        started.isInverted = true
        watcher.onStart = {
            started.fulfill()
        }
        block()
        wait(for: [started], timeout: 1)
        watcher.onStart = nil
    }

    /// Runs some JavaScript in the web view, and gives its result
    private func evaluate(_ script: String, in webView: WKWebView) throws -> Any? {
        let evaluated = expectation(description: "evaluated")
        var result: Result<Any?, Error> = .success(nil)
        webView.evaluateJavaScript(script) { value, error in
            result = error.map { .failure($0) } ?? .success(value)
            evaluated.fulfill()
        }
        wait(for: [evaluated], timeout: 10)
        return try result.get()
    }

    /// Switches to one of the index's tabs, and waits for its page to load
    private func switchToTab(_ tab: IFIndexTabType, in shown: Shown) {
        waitForNavigation(shown.watcher) {
            shown.page.switch(toTab: tab.rawValue)
        }
    }

    /// Tells the page that a navigation to the URL has started, without loading it
    private func tellPageNavigationStarted(_ url: URL, in shown: Shown) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WebViewStandIn(frame: .zero, configuration: configuration)
        webView.shownURL = url
        (shown.page as WKNavigationDelegate).webView?(webView, didStartProvisionalNavigation: nil)
    }

    /// The tab of each cell that's on
    private func highlightedTabs(_ shown: Shown) -> [Int] {
        return shown.page.toolbarCells.filter { $0.state == .on }.compactMap { ($0.representedObject as? NSNumber)?.intValue }
    }

    func testTheTitle() throws {
        let shown = try makePage()
        XCTAssertEqual(shown.page.title, "Index")
    }

    /// Before the project has an index, the page has no cells, isn't shown, and can't show a tab
    func testNoIndex() throws {
        let shown = try makePage()
        XCTAssertTrue(shown.page.toolbarCells.isEmpty)

        shown.page.updateIndexView()
        XCTAssertTrue(shown.page.toolbarCells.isEmpty)
        XCTAssertFalse(shown.page.shouldShowPage)
        XCTAssertFalse(shown.page.canSelectIndexTab(IFIndexTabType.welcome.rawValue))
        expectNoNavigation(shown.watcher) {
            shown.page.switch(toTab: IFIndexTabType.welcome.rawValue)
        }
    }

    /// The page has a cell for each of the index's pages that's one of its tabs, in order of the tabs, the last first,
    /// each named for its page, except the welcome page's, which is the home icon
    func testTheCells() throws {
        try writeIndex(indexPages.map { $0.file } + ["Other.html", "Headings.xml"])
        try FileManager.default.createDirectory(at: indexURL("Details"), withIntermediateDirectories: true)
        let shown = try makePage()
        shown.page.updateIndexView()

        let cells = shown.page.toolbarCells
        XCTAssertEqual(cells.compactMap { ($0.representedObject as? NSNumber)?.intValue }, Array((1...8).reversed()))
        XCTAssertEqual(cells.dropLast().map { $0.stringValue },
                       ["World", "Scenes", "Rules", "Phrasebook", "Kinds", "Actions", "Contents"])
        XCTAssertEqual(cells.last?.image?.name(), NSImage.homeTemplateName)
        for cell in cells {
            XCTAssertTrue(cell.target === shown.page)
            XCTAssertEqual(cell.action.map(NSStringFromSelector), "switchToTabWithObject:")
            XCTAssertEqual(cell.radioGroup, 128)
        }

        XCTAssertTrue(shown.page.shouldShowPage)
        for tab in 1...8 {
            XCTAssertTrue(shown.page.canSelectIndexTab(Int32(tab)), "\(tab)")
        }
        XCTAssertFalse(shown.page.canSelectIndexTab(9))
    }

    /// When the page tells the page bar its cells have changed, they're already in order
    func testTheCellsAreInOrderWhenThePageBarIsTold() throws {
        try writeIndex(indexPages.map { $0.file })
        let shown = try makePage()

        nonisolated(unsafe) var told: [[Int]] = []
        let observer = NotificationCenter.default.addObserver(forName: .IFUpdatePageBarCells, object: shown.page, queue: nil) { _ in
            MainActor.assumeIsolated {
                told.append(shown.page.toolbarCells.compactMap { ($0.representedObject as? NSNumber)?.intValue })
            }
        }
        shown.page.updateIndexView()
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(told, [Array((1...8).reversed())])
    }

    /// Without some of its pages, the index has only the cells for the pages it has, and can only show those tabs
    func testAPartIndex() throws {
        try writeIndex(["Welcome.html", "Contents.html"])
        let shown = try makePage()
        waitForNavigation(shown.watcher) {
            // It shows the welcome page, as it showed nothing before
            shown.page.updateIndexView()
        }

        XCTAssertEqual(shown.page.toolbarCells.compactMap { ($0.representedObject as? NSNumber)?.intValue }, [2, 1])
        XCTAssertTrue(shown.page.canSelectIndexTab(IFIndexTabType.contents.rawValue))
        XCTAssertFalse(shown.page.canSelectIndexTab(IFIndexTabType.rules.rawValue))
        expectNoNavigation(shown.watcher) {
            shown.page.switch(toTab: IFIndexTabType.rules.rawValue)
        }
    }

    /// Once the index has gone, the page has no cells, and isn't shown
    func testTheIndexRemoved() throws {
        let shown = try makePageShowingTheIndex()
        try FileManager.default.removeItem(at: indexFolder)
        shown.page.updateIndexView()
        XCTAssertTrue(shown.page.toolbarCells.isEmpty)
        XCTAssertFalse(shown.page.shouldShowPage)
    }

    /// Switching to a tab shows its page, with its cell highlighted
    func testSwitchingToATab() throws {
        let shown = try makePageShowingTheIndex()
        XCTAssertEqual(shown.webView.url, try indexURL("Welcome.html"))
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.welcome.rawValue)])

        for (file, tab) in indexPages {
            switchToTab(tab, in: shown)
            XCTAssertEqual(shown.webView.url, try indexURL(file))
            XCTAssertEqual(highlightedTabs(shown), [Int(tab.rawValue)], file)
        }
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Each cell shows its page
    func testTheCellsShowTheirPages() throws {
        let shown = try makePageShowingTheIndex()
        for cell in shown.page.toolbarCells {
            let action = try XCTUnwrap(cell.action)
            waitForNavigation(shown.watcher) {
                XCTAssertTrue(NSApp.sendAction(action, to: cell.target, from: cell))
            }
            let tab = try XCTUnwrap(cell.representedObject as? NSNumber).intValue
            let file = try XCTUnwrap(indexPages.first { Int($0.tab.rawValue) == tab }).file
            XCTAssertEqual(shown.webView.url, try indexURL(file))
            XCTAssertEqual(cell.state, .on)
        }
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Updating the index reloads the page shown, as the index may have changed
    func testUpdatingTheIndexReloadsThePage() throws {
        let shown = try makePageShowingTheIndex()
        switchToTab(.rules, in: shown)

        try writePage("Rules.html", saying: "New rules")
        waitForNavigation(shown.watcher) {
            shown.page.updateIndexView()
        }
        XCTAssertEqual(shown.webView.url, try indexURL("Rules.html"))
        XCTAssertEqual(try evaluate("document.body.innerText", in: shown.webView) as? String, "New rules")
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.rules.rawValue)])
    }

    /// The reload as the index is updated after a translation isn't recorded in the history, as it's the same page,
    /// and what's shown next is
    func testUpdatingTheIndexIsntRecorded() throws {
        let recorder = Recorder()
        let shown = try makePageShowingTheIndex(recorder: recorder)
        shown.page.pageIsVisible = true
        switchToTab(.rules, in: shown)
        XCTAssertEqual(recorder.timesAsked, 2)

        waitForNavigation(shown.watcher) {
            shown.page.updateIndexView()
        }
        XCTAssertEqual(recorder.timesAsked, 2)

        switchToTab(.kinds, in: shown)
        XCTAssertEqual(recorder.timesAsked, 4)
    }

    /// Each page the page shows is recorded in the history, so that going back switches to the page and shows that
    /// page again, which isn't recorded
    func testTheHistory() throws {
        let recorder = Recorder()
        let shown = try makePageShowingTheIndex(recorder: recorder)
        shown.page.pageIsVisible = true
        let asked = recorder.timesAsked

        let kinds = IFHistoryEvent(object: NSNull())
        recorder.event = kinds
        switchToTab(.kinds, in: shown)
        // To switch to the page, and to show its page
        XCTAssertEqual(recorder.timesAsked, asked + 2)

        recorder.event = IFHistoryEvent(object: NSNull())
        switchToTab(.world, in: shown)
        XCTAssertEqual(recorder.timesAsked, asked + 4)

        let posted = notifications(.IFSwitchToPage, from: shown.page) {
            waitForNavigation(shown.watcher) {
                kinds.replay()
            }
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(shown.webView.url, try indexURL("Kinds.html"))
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.kinds.rawValue)])
        XCTAssertEqual(recorder.timesAsked, asked + 4)

        // What's shown next is recorded again
        switchToTab(.rules, in: shown)
        XCTAssertEqual(recorder.timesAsked, asked + 6)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Nothing is recorded in the history while the page is hidden, as for the other pages: not the welcome page it
    /// shows as the pane is set up, nor a tab shown
    func testTheHistoryWhileHidden() throws {
        let recorder = Recorder()
        let shown = try makePageShowingTheIndex(recorder: recorder)
        XCTAssertEqual(recorder.timesAsked, 0)

        switchToTab(.kinds, in: shown)
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// Opening a URL from the history shows it without recording it, and nothing without one
    func testOpeningAHistoricalURL() throws {
        let recorder = Recorder()
        let shown = try makePageShowingTheIndex(recorder: recorder)
        let asked = recorder.timesAsked

        expectNoNavigation(shown.watcher) {
            shown.page.openHistoricalURL(nil)
        }
        let scenes = try indexURL("Scenes.html")
        waitForNavigation(shown.watcher) {
            shown.page.openHistoricalURL(scenes)
        }
        XCTAssertEqual(shown.webView.url, try indexURL("Scenes.html"))
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.scenes.rawValue)])
        XCTAssertEqual(recorder.timesAsked, asked)
    }

    /// Switching to the page records what it shows in the history, and highlights its cell
    func testSwitchingToThePage() throws {
        let recorder = Recorder()
        let shown = try makePageShowingTheIndex(recorder: recorder)
        switchToTab(.phrasebook, in: shown)
        for cell in shown.page.toolbarCells {
            cell.state = .off
        }

        let switched = IFHistoryEvent(object: NSNull())
        recorder.event = switched
        let asked = recorder.timesAsked
        expectNoNavigation(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, asked + 1)
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.phrasebook.rawValue)])

        recorder.event = IFHistoryEvent(object: NSNull())
        switchToTab(.actions, in: shown)
        waitForNavigation(shown.watcher) {
            switched.replay()
        }
        XCTAssertEqual(shown.webView.url, try indexURL("Phrasebook.html"))
    }

    /// After a project's first translation, the page shows its welcome page, which the pane asked for as it was set
    /// up, when there was no index to show. It isn't recorded in the history, as the reload in its place isn't.
    func testTheFirstIndexShowsTheWelcomePage() throws {
        let recorder = Recorder()
        let shown = try makePage(recorder: recorder)
        shown.page.pageIsVisible = true
        shown.page.updateIndexView()
        expectNoNavigation(shown.watcher) {
            shown.page.switch(toTab: IFIndexTabType.welcome.rawValue)
        }

        try writeIndex(indexPages.map { $0.file })
        waitForNavigation(shown.watcher) {
            shown.page.updateIndexView()
        }
        XCTAssertEqual(shown.page.toolbarCells.count, 8)
        XCTAssertEqual(shown.webView.url, try indexURL("Welcome.html"))
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.welcome.rawValue)])
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// A page of the index with no cell highlights none
    func testAPageWithNoCell() throws {
        try writeIndex(["Welcome.html", "Contents.html"])
        let shown = try makePage()
        shown.page.updateIndexView()

        tellPageNavigationStarted(try indexURL("Contents.html"), in: shown)
        XCTAssertEqual(highlightedTabs(shown), [Int(IFIndexTabType.contents.rawValue)])

        tellPageNavigationStarted(try indexURL("Rules.html"), in: shown)
        XCTAssertEqual(highlightedTabs(shown), [])
    }

    /// When the app's font size changes, the page is zoomed to it
    func testTheFontSize() throws {
        let shown = try makePageShowingTheIndex()
        _ = try evaluate("document.body.style.zoom = '3'", in: shown.webView)
        NotificationCenter.default.post(name: .IFPreferencesAppFontSizeDidChange, object: IFPreferences.shared)
        let zoom = try evaluate("document.body.style.zoom", in: shown.webView) as? String
        XCTAssertEqual(zoom.flatMap { Double($0) },
                       Double(String(format: "%.2f", IFPreferences.shared.appFontSizeMultiplier)))
    }

    /// The notifications of the given name that the page posts while the block runs
    private func notifications(_ name: Notification.Name, from page: IFPage, during block: () -> Void) -> [Notification] {
        nonisolated(unsafe) var posted: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: name, object: page, queue: nil) {
            posted.append($0)
        }
        block()
        NotificationCenter.default.removeObserver(observer)
        return posted
    }
}
