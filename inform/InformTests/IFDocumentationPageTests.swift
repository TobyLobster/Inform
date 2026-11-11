//
//  IFDocumentationPageTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no document or window
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

/// Stands between the page's web view and the page, its navigation delegate, passing on what the page is told, and
/// telling the tests when a navigation starts and finishes
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    private let page: WKNavigationDelegate
    /// The URL of each navigation that the page has been told has started
    private(set) var started: [String] = []
    /// The errors of the navigations that failed
    private(set) var errors: [Error] = []
    /// Called when a navigation starts
    var onStart: (() -> Void)?
    /// Called when a navigation finishes or fails
    var onFinish: (() -> Void)?

    init(_ page: IFDocumentationPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        page.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        started.append(webView.url?.absoluteString ?? "")
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
final class IFDocumentationPageTests: XCTestCase, @unchecked Sendable {

    /// A page being tested, with its web view and the watcher between them
    private struct Shown {
        let page: IFDocumentationPage
        let webView: WKWebView
        let watcher: NavigationWatcher
    }

    /// The page's project controller, which the page doesn't keep
    private var controller: ProjectControllerStandIn?
    /// The pages made, kept until the test ends, as a web view doesn't keep its navigation delegate
    private var shown: [Shown] = []

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()

            // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
            // toolbar for them, which saves its configuration in the user's preferences.
            let controller = ProjectControllerStandIn()
            NotificationCenter.default.removeObserver(controller)
            self.controller = controller
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            shown = []
            controller = nil
            super.tearDown()
        }
    }

    /// A documentation page, once it has loaded its first page
    private func makePage(visible: Bool = false, recorder: Recorder? = nil) throws -> Shown {
        let page = IFDocumentationPage(projectController: try XCTUnwrap(controller), with: IFProjectPane())
        page.pageIsVisible = visible
        page.recorder = recorder

        let webView = try XCTUnwrap(page.view.subviews.compactMap { $0 as? WKWebView }.first)
        let watcher = NavigationWatcher(page)
        webView.navigationDelegate = watcher
        waitForNavigation(watcher) {
            // The page has started loading its first page
        }

        let made = Shown(page: page, webView: webView, watcher: watcher)
        shown.append(made)
        return made
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

    /// The notifications of the given name that the page posts while the block runs
    private func notifications(_ name: Notification.Name, from page: IFPage, during block: () -> Void) -> [Notification] {
        var posted: [Notification] = []
        let observer = NotificationCenter.default.addObserver(forName: name, object: page, queue: nil) {
            posted.append($0)
        }
        block()
        NotificationCenter.default.removeObserver(observer)
        return posted
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

    /// Opens a page of the documentation, and waits for it to load
    private func open(_ url: String, in shown: Shown) {
        waitForNavigation(shown.watcher) {
            shown.page.open(URL(string: url)!)
        }
    }

    func testTheTitle() throws {
        let shown = try makePage()
        XCTAssertEqual(shown.page.title, "Documentation")
    }

    /// The page starts at the contents, which isn't recorded in the history, even when the page is visible
    func testTheFirstPage() throws {
        let recorder = Recorder()
        let shown = try makePage(visible: true, recorder: recorder)
        XCTAssertEqual(shown.watcher.started, ["inform:/index.html"])
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .off, .on])
        XCTAssertEqual(recorder.timesAsked, 0)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// The page bar's cells show the general index, the examples and the contents, each switching to the page and
    /// showing its page, and each highlighted while its page is shown
    func testThePageBarCells() throws {
        let shown = try makePage()
        let cells = shown.page.toolbarCells
        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells.first?.stringValue, "General Index")
        XCTAssertEqual(cells.dropFirst().first?.stringValue, "Examples")
        XCTAssertEqual(cells.last?.image?.name(), NSImage.homeTemplateName)
        XCTAssertEqual(cells.compactMap { $0.action.map(NSStringFromSelector) },
                       ["showGeneralIndex:", "showExamples:", "showToc:"])

        let urls = ["inform:/general_index.html", "inform:/examples_alphabetical.html", "inform:/index.html"]
        for (index, cell) in cells.enumerated() {
            XCTAssertTrue(cell.target === shown.page)
            let action = try XCTUnwrap(cell.action)
            let posted = notifications(.IFSwitchToPage, from: shown.page) {
                waitForNavigation(shown.watcher) {
                    XCTAssertTrue(NSApp.sendAction(action, to: cell.target, from: cell))
                }
            }
            XCTAssertEqual(posted.map { $0.userInfo as? [String: String] }, [["Identifier": "IFDocumentationPage"]])
            XCTAssertEqual(shown.webView.url?.absoluteString, urls[index])
            XCTAssertEqual(cells.map { $0.state }, cells.indices.map { $0 == index ? NSControl.StateValue.on : .off }, urls[index])
        }
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Opening a URL switches to the page and shows it, with no cell highlighted for a page that isn't one of theirs
    func testOpeningAURL() throws {
        let shown = try makePage()
        let posted = notifications(.IFSwitchToPage, from: shown.page) {
            open("inform:/WI_1_1.html", in: shown)
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/WI_1_1.html")
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .off, .off])
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// A cell is highlighted for its page's URL in any case
    func testTheCellsIgnoreCase() throws {
        let shown = try makePage()
        open("inform:/Examples_Alphabetical.html", in: shown)
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .on, .off])
    }

    /// While the page is visible, each page it shows is recorded in the history, so that going back switches to the
    /// page and shows that page again, which isn't recorded
    func testTheHistory() throws {
        let recorder = Recorder()
        let shown = try makePage(visible: true, recorder: recorder)

        let examples = recorder.event
        open("inform:/examples_alphabetical.html", in: shown)
        // To switch to the page, and to show its page
        XCTAssertEqual(recorder.timesAsked, 2)

        recorder.event = IFHistoryEvent(object: NSNull())
        open("inform:/general_index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 4)

        let posted = notifications(.IFSwitchToPage, from: shown.page) {
            waitForNavigation(shown.watcher) {
                examples.replay()
            }
        }
        // Once from the history, and once more as the page is opened
        XCTAssertEqual(posted.count, 2)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/examples_alphabetical.html")
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .on, .off])
        XCTAssertEqual(recorder.timesAsked, 4)

        // What's shown next is recorded again
        open("inform:/WI_1_1.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 6)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Nothing is recorded in the history while the page isn't visible
    func testTheHistoryWhileHidden() throws {
        let recorder = Recorder()
        let shown = try makePage(recorder: recorder)
        open("inform:/examples_alphabetical.html", in: shown)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/examples_alphabetical.html")
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// When a census of the extensions finishes, the page is reloaded, as the pages of the installed extensions may
    /// have changed, and that isn't recorded in the history
    func testTheCensusReloadsThePage() throws {
        let recorder = Recorder()
        let shown = try makePage(visible: true, recorder: recorder)
        for name in [Notification.Name.IFCensusFinished, .IFCensusFinishedButDontUpdateExtensionsWebPage] {
            waitForNavigation(shown.watcher) {
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
        XCTAssertEqual(shown.watcher.started, Array(repeating: "inform:/index.html", count: 3))
        XCTAssertEqual(recorder.timesAsked, 0)

        // What's shown next is recorded
        open("inform:/examples_alphabetical.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 2)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Switching to the page records what it shows in the history, and reloads it
    func testSwitchingToThePage() throws {
        let recorder = Recorder()
        // Hidden, so that only what switching records is counted
        let shown = try makePage(recorder: recorder)
        open("inform:/examples_alphabetical.html", in: shown)

        let switched = recorder.event
        waitForNavigation(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertEqual(shown.watcher.started.suffix(2),
                       ["inform:/examples_alphabetical.html", "inform:/examples_alphabetical.html"])

        recorder.event = IFHistoryEvent(object: NSNull())
        open("inform:/general_index.html", in: shown)
        waitForNavigation(shown.watcher) {
            switched.replay()
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/examples_alphabetical.html")
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// When the app's font size changes, the page is zoomed to it
    func testTheFontSize() throws {
        let shown = try makePage()
        _ = try evaluate("document.body.style.zoom = '3'", in: shown.webView)
        NotificationCenter.default.post(name: .IFPreferencesAppFontSizeDidChange, object: IFPreferences.shared)
        let zoom = try evaluate("document.body.style.zoom", in: shown.webView) as? String
        XCTAssertEqual(zoom.flatMap { Double($0) },
                       Double(String(format: "%.2f", IFPreferences.shared.appFontSizeMultiplier)))
    }

    /// Once the page is closing, a census doesn't reload it
    func testClosing() throws {
        let shown = try makePage()
        shown.page.willClose()

        let started = expectation(description: "navigation started")
        started.isInverted = true
        shown.watcher.onStart = {
            started.fulfill()
        }
        NotificationCenter.default.post(name: .IFCensusFinished, object: nil)
        wait(for: [started], timeout: 1)
    }
}
