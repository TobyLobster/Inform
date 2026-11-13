//
//  IFErrorsPageTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no document or window, which records what the page asks of its source
private final class ProjectControllerStandIn: IFProjectController {
    override var document: AnyObject? {
        get {
            return nil
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

    /// Whether the source has the files the page asks for
    var hasFiles = true
    /// What the page has asked for
    private(set) var asked: [String] = []

    private func name(_ style: IFLineStyle) -> String {
        return style == .error ? "error" : "style \(style.rawValue)"
    }

    override func selectSourceFile(_ fileName: String) -> Bool {
        asked.append("select \(fileName)")
        return hasFiles
    }

    override func move(toSourceFileLine line: Int) {
        asked.append("move to \(line)")
    }

    override func removeHighlights(of style: IFLineStyle) {
        asked.append("remove \(name(style))")
    }

    override func highlightSourceFileLine(_ line: Int, inFile file: String, style: IFLineStyle) {
        asked.append("highlight \(line) in \(file) as \(name(style))")
    }
}

/// Gives the page a history event, as a pane would, and counts how often it's asked for one, which the page only
/// does to record something; while it replays an event, it gives none, as a pane doesn't
@MainActor
private final class Recorder: NSObject, IFHistoryRecorder {
    /// The event that what the page records goes in
    var event = IFHistoryEvent()
    /// How often the page has asked for the event, other than while replaying
    private(set) var timesAsked = 0
    private var replaying = false

    var historyEvent: IFHistoryEvent? {
        if replaying {
            return nil
        }
        timesAsked += 1
        return event
    }

    func replay(_ event: IFHistoryEvent) {
        replaying = true
        event.replay()
        replaying = false
    }
}

/// Stands between a web view and the page, its navigation delegate, passing on what the page is told, and telling
/// the tests when a navigation finishes
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    private let page: WKNavigationDelegate
    /// The URL of each navigation that the page has been told has started
    private(set) var started: [URL?] = []
    /// Called when a navigation finishes or fails
    var onFinish: (() -> Void)?

    init(_ page: IFErrorsPage) {
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
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFinish?()
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        onFinish?()
    }
}

@MainActor
final class IFErrorsPageTests: XCTestCase, @unchecked Sendable {

    /// The page's project controller, which the page doesn't keep
    private var controller: ProjectControllerStandIn?
    /// A folder for the files that the page's compiler controller shows
    private var folder: URL?
    /// What's kept until the test ends: the pages made, and the watchers of their web views, which a web view
    /// doesn't keep
    private var kept: [AnyObject] = []

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            try super.setUpWithError()

            // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
            // toolbar for them, which saves its configuration in the user's preferences.
            let controller = ProjectControllerStandIn()
            NotificationCenter.default.removeObserver(controller)
            self.controller = controller

            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
        }
    }

    override func tearDownWithError() throws {
        try MainActor.assumeIsolated {
            kept = []
            controller = nil
            if let folder {
                try FileManager.default.removeItem(at: folder)
            }
            try super.tearDownWithError()
        }
    }

    private func makePage(visible: Bool = false, recorder: Recorder? = nil) throws -> IFErrorsPage {
        let page = IFErrorsPage(projectController: try XCTUnwrap(controller), with: IFProjectPane())
        page.pageIsVisible = visible
        page.recorder = recorder
        kept.append(page)
        return page
    }

    /// Writes a file of the compiler's output, and has the page's compiler controller show it in a new tab
    @discardableResult
    private func show(_ name: String, contents: String = "Output", in page: IFErrorsPage) throws -> IFCompilerTabId {
        let file = try XCTUnwrap(folder).appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return page.compilerController.makeTab(forFile: file.path)
    }

    /// The notifications of the given name that the page posts while the block runs
    private func notifications(_ name: Notification.Name, from page: IFPage, during block: () throws -> Void) rethrows -> [Notification] {
        nonisolated(unsafe) var posted: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: name, object: page, queue: nil) {
            posted.append($0)
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        try block()
        return posted
    }

    private func titles(_ page: IFPage) -> [String] {
        return page.toolbarCells.map { $0.stringValue }
    }

    private func states(_ page: IFPage) -> [NSControl.StateValue] {
        return page.toolbarCells.map { $0.state }
    }

    func testTheTitle() throws {
        let page = try makePage()
        XCTAssertEqual(page.title, "Results")
    }

    /// The nib makes the page's compiler controller, with the page as its delegate, and with a tab for its console,
    /// which the page has a cell for
    func testTheCompilerController() throws {
        let page = try makePage()
        XCTAssertTrue(page.compilerController.delegate === page)
        XCTAssertEqual(page.compilerController.viewTabs.map { $0.tabId }, [.tabConsole])
        XCTAssertEqual(page.compilerController.selectedTabId, .tabConsole)
        XCTAssertEqual(titles(page), ["Console"])
        XCTAssertEqual(states(page), [.on])
    }

    /// Each tab of the compiler controller has a cell, in the order of their ids, the highest first, with the
    /// selected tab's cell on, and the page tells its page bar each time they change
    func testThePageBarCells() throws {
        let page = try makePage()
        let posted = try notifications(.IFUpdatePageBarCells, from: page) {
            try show("auto.inf", in: page)
            try show("Debug log.txt", in: page)
        }
        XCTAssertEqual(posted.count, 2)

        XCTAssertEqual(titles(page), ["Inform 6", "Debugging", "Console"])
        XCTAssertEqual(page.toolbarCells.map { $0.representedObject as? Int }, [3, 2, 1])
        XCTAssertEqual(states(page), [.off, .off, .on])
        for cell in page.toolbarCells {
            XCTAssertTrue(cell.target === page)
            XCTAssertEqual(cell.action.map(NSStringFromSelector), "switchToErrorPage:")
            XCTAssertEqual(cell.radioGroup, 128)
        }

        // When the tabs are cleared, the cells go too, but for the console's
        page.compilerController.clearTabViewsExcept(.tabConsole)
        XCTAssertEqual(titles(page), ["Console"])
    }

    /// A cell switches the compiler controller to its tab, and is then the one on
    func testSwitchingWithACell() throws {
        let page = try makePage()
        try show("auto.inf", in: page)
        try show("Debug log.txt", in: page)

        let debugging = page.toolbarCells[1]
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(debugging.action), to: debugging.target, from: debugging))
        XCTAssertEqual(page.compilerController.selectedTabId, .tabDebugging)
        XCTAssertEqual(states(page), [.off, .on, .off])

        let inform6 = page.toolbarCells[0]
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(inform6.action), to: inform6.target, from: inform6))
        XCTAssertEqual(page.compilerController.selectedTabId, .tabInform6)
        XCTAssertEqual(states(page), [.on, .off, .off])
    }

    /// Each switch of the compiler controller's tab is recorded in the history, even while the page isn't visible,
    /// so that going back switches to the page, and to that tab again
    func testSwitchingTabsIsRecorded() throws {
        let recorder = Recorder()
        let page = try makePage(recorder: recorder)
        try show("auto.inf", in: page)
        try show("Debug log.txt", in: page)

        let debugging = recorder.event
        page.compilerController.switchToView(with: .tabDebugging)
        XCTAssertEqual(recorder.timesAsked, 1)

        recorder.event = IFHistoryEvent()
        page.compilerController.switchToView(with: .tabInform6)
        XCTAssertEqual(recorder.timesAsked, 2)

        let posted = notifications(.IFSwitchToPage, from: page) {
            recorder.replay(debugging)
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(page.compilerController.selectedTabId, .tabDebugging)
        XCTAssertEqual(states(page), [.off, .on, .off])
        XCTAssertEqual(recorder.timesAsked, 2)
    }

    /// Switching to the page records its tab in the history
    func testSwitchingToThePage() throws {
        let recorder = Recorder()
        let page = try makePage(recorder: recorder)
        try show("Debug log.txt", in: page)

        let switched = recorder.event
        page.didSwitchToPage()
        XCTAssertEqual(recorder.timesAsked, 1)

        recorder.event = IFHistoryEvent()
        page.compilerController.switchToView(with: .tabDebugging)

        let posted = notifications(.IFSwitchToPage, from: page) {
            recorder.replay(switched)
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(page.compilerController.selectedTabId, .tabConsole)
        XCTAssertEqual(states(page), [.off, .on])
    }

    /// When a problem is chosen in the compiler controller, the source shows its line, highlighted as an error
    func testHighlightingAProblem() throws {
        let controller = try XCTUnwrap(controller)
        let page = try makePage()
        let delegate: IFCompilerControllerDelegate = page
        delegate.errorMessageHighlighted?(page.compilerController, atLine: 12, inFile: "story.ni")
        XCTAssertEqual(controller.asked, ["select story.ni", "move to 12", "remove error",
                                          "highlight 12 in story.ni as error"])

        // Nothing more is asked when the source doesn't have the file
        controller.hasFiles = false
        delegate.errorMessageHighlighted?(page.compilerController, atLine: 3, inFile: "Other.i7x")
        XCTAssertEqual(controller.asked.dropFirst(4), ["select Other.i7x"])
    }

    /// What another compiler controller says is passed over
    func testAnotherCompilerController() throws {
        let recorder = Recorder()
        let page = try makePage(recorder: recorder)
        try show("Debug log.txt", in: page)

        let other = IFCompilerController()
        let delegate: IFCompilerControllerDelegate = page
        delegate.viewSetHasUpdated?(other)
        delegate.compiler?(other, switchedToView: 0)
        XCTAssertEqual(titles(page), ["Debugging", "Console"])
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// Shows a page of the compiler's output in a web view, which the compiler controller makes, and waits for it
    /// to load (or fail to)
    private func showPage(_ name: String, in page: IFErrorsPage) throws -> (WKWebView, NavigationWatcher) {
        // The compiler controller makes its web views once it has its project controller
        page.compilerController.setProject(try XCTUnwrap(controller), with: IFProjectPane())

        let tabId = try show(name, contents: "<html><body><p>Problems</p></body></html>", in: page)
        let tab = try XCTUnwrap(page.compilerController.viewTabs.first { $0.tabId == tabId })
        let webView = try XCTUnwrap(tab.view as? WKWebView)
        let watcher = NavigationWatcher(page)
        webView.navigationDelegate = watcher
        kept.append(watcher)
        waitForNavigation(watcher)
        return (webView, watcher)
    }

    /// Waits for the watcher's web view to finish the navigation it has started
    private func waitForNavigation(_ watcher: NavigationWatcher) {
        let finished = expectation(description: "navigation finished")
        watcher.onFinish = {
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        watcher.onFinish = nil
    }

    /// While the page is visible, each page that the compiler controller's web views show is recorded in the
    /// history, so that going back switches to the page and shows it again, which isn't recorded
    func testThePagesShownAreRecorded() throws {
        let recorder = Recorder()
        let page = try makePage(visible: true, recorder: recorder)
        let problems = recorder.event
        let (webView, watcher) = try showPage("Problems.html", in: page)
        let url = try XCTUnwrap(watcher.started.first ?? nil)
        XCTAssertEqual(url.lastPathComponent, "Problems.html")
        // To switch to the page, and to show the page
        XCTAssertEqual(recorder.timesAsked, 2)

        // Switching to the report's tab makes its web view the one that's shown, and is recorded
        recorder.event = IFHistoryEvent()
        page.compilerController.switchToView(with: .tabReport)
        XCTAssertTrue(page.compilerController.currentWebView === webView)
        XCTAssertEqual(recorder.timesAsked, 3)

        let posted = notifications(.IFSwitchToPage, from: page) {
            recorder.replay(problems)
            waitForNavigation(watcher)
        }
        // Once from the history, and once more as the page is opened
        XCTAssertEqual(posted.count, 2)
        XCTAssertEqual(watcher.started.count, 2)
        XCTAssertEqual(watcher.started.last, url)
        XCTAssertEqual(recorder.timesAsked, 3)
    }

    /// A link that does something rather than show a page, as one to the source or to a knot of the skein, isn't
    /// recorded in the history
    func testALinkThatShowsNoPageIsntRecorded() throws {
        let recorder = Recorder()
        let page = try makePage(visible: true, recorder: recorder)
        let (webView, watcher) = try showPage("Problems.html", in: page)
        XCTAssertEqual(recorder.timesAsked, 2)

        for link in ["source:story.ni#line3", "skein:1003?case=B"] {
            let url = try XCTUnwrap(URL(string: link))
            webView.load(URLRequest(url: url))
            waitForNavigation(watcher)
            XCTAssertEqual(watcher.started.last, url)
            XCTAssertEqual(recorder.timesAsked, 2, link)
        }
    }

    /// Nothing that the web views show is recorded while the page isn't visible
    func testThePagesShownWhileHidden() throws {
        let recorder = Recorder()
        let page = try makePage(recorder: recorder)
        let (_, watcher) = try showPage("Problems.html", in: page)
        XCTAssertEqual(watcher.started.count, 1)
        XCTAssertEqual(recorder.timesAsked, 0)
    }
}
