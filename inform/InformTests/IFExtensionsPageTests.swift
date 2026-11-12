//
//  IFExtensionsPageTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no window, whose document is the project the test gives it
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which the page asks for as it's made
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
@MainActor
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
/// telling the tests when a navigation starts and finishes. Web pages aren't loaded, as the tests don't use the network.
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    private let page: WKNavigationDelegate
    /// The URL of each navigation that the page has been told has started
    private(set) var started: [String] = []
    /// The errors of the navigations that failed
    private(set) var errors: [Error] = []
    /// The web pages that the page asked to load, which weren't loaded
    private(set) var refused: [URL] = []
    /// Called when a navigation starts
    var onStart: (() -> Void)?
    /// Called when a navigation finishes
    var onFinish: (() -> Void)?
    /// Called when a web page isn't loaded
    var onRefuse: (() -> Void)?

    init(_ page: IFExtensionsPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, ["http", "https", "file"].contains(url.scheme) {
            refused.append(url)
            decisionHandler(.cancel)
            onRefuse?()
            return
        }
        page.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        started.append(webView.url?.absoluteString ?? "")
        page.webView?(webView, didStartProvisionalNavigation: navigation)
        onStart?()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        page.webView?(webView, didFinish: navigation)
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        errors.append(error)
        page.webView?(webView, didFail: navigation, withError: error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        errors.append(error)
        page.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
}

@MainActor
final class IFExtensionsPageTests: XCTestCase, @unchecked Sendable {

    /// A page being tested, with its web view and the watcher between them
    private struct Shown {
        let page: IFExtensionsPage
        let webView: WKWebView
        let watcher: NavigationWatcher
    }

    /// The page listing the project's extensions, which Inform writes in its materials folder
    private let catalogueURL = "inform://Extensions/Reserved/Documentation/Extensions.html"
    /// The project's catalogue, which says when an extension has been installed
    private let catalogue = """
        <html><body><p>Installed extensions</p>
        <script>window.downloadSucceeded = function (id) { document.title = 'Installed ' + id; };</script>
        </body></html>
        """

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

    /// A project, in the test's folder, with a catalogue of its extensions if one is given
    private func makeProject(catalogue: String?) throws -> IFProject {
        let project = IFProject()
        project.fileURL = try XCTUnwrap(folder).appendingPathComponent("Test.inform")
        if let catalogue {
            try writeCatalogue(catalogue)
        }
        return project
    }

    /// Writes the project's catalogue of its extensions
    private func writeCatalogue(_ html: String) throws {
        let url = try XCTUnwrap(folder).appendingPathComponent("Test.materials/Extensions/Reserved/Documentation/Extensions.html")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(html.utf8).write(to: url)
    }

    /// An extensions page, hidden, as a pane makes it, once it has loaded its first page
    private func makePage(project: IFProject?, recorder: Recorder? = nil) throws -> Shown {
        let controller = try XCTUnwrap(controller)
        controller.project = project
        let page = IFExtensionsPage(projectController: controller, with: IFProjectPane())
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

    /// An extensions page showing the project's catalogue of extensions
    private func makePageWithCatalogue(recorder: Recorder? = nil) throws -> Shown {
        return try makePage(project: makeProject(catalogue: catalogue), recorder: recorder)
    }

    /// Runs the block, and waits for a navigation to finish
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

    /// Runs the block, and waits for the web page it asks for to be refused
    private func waitForRefusal(_ watcher: NavigationWatcher, during block: () -> Void) {
        let refused = expectation(description: "web page refused")
        watcher.onRefuse = {
            refused.fulfill()
        }
        block()
        wait(for: [refused], timeout: 10)
        watcher.onRefuse = nil
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

    /// Opens a page, and waits for it to load
    private func open(_ url: String, in shown: Shown) {
        waitForNavigation(shown.watcher) {
            shown.page.open(URL(string: url)!)
        }
    }

    /// Waits until the web view has finished loading the URL, whatever loads it started before
    private func waitUntilShown(_ url: String, in shown: Shown) {
        let limit = Date(timeIntervalSinceNow: 10)
        while (shown.webView.isLoading || shown.webView.url?.absoluteString != url) && Date() < limit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, url)
        XCTAssertFalse(shown.webView.isLoading)
    }

    /// Tells the page that a navigation to the URL has started, without loading it
    private func tellPageNavigationStarted(_ url: String, in shown: Shown) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WebViewStandIn(frame: .zero, configuration: configuration)
        webView.shownURL = URL(string: url)
        (shown.page as WKNavigationDelegate).webView?(webView, didStartProvisionalNavigation: nil)
    }

    /// Tells the page that a navigation to the URL has failed
    private func tellPageNavigationFailed(_ url: String,
                                          provisional: Bool,
                                          domain: String = NSURLErrorDomain,
                                          code: Int = NSURLErrorCannotFindHost,
                                          in shown: Shown) {
        let error = NSError(domain: domain, code: code, userInfo: [NSURLErrorFailingURLErrorKey: URL(string: url)!])
        let page = shown.page as WKNavigationDelegate
        if provisional {
            page.webView?(shown.webView, didFailProvisionalNavigation: nil, withError: error)
        }
        else {
            page.webView?(shown.webView, didFail: nil, withError: error)
        }
    }

    private var publicLibraryURL: URL {
        get throws {
            return try XCTUnwrap(IFUtility.publicLibraryURL())
        }
    }

    func testTheTitle() throws {
        let shown = try makePageWithCatalogue()
        XCTAssertEqual(shown.page.title, "Extensions")
    }

    /// The page starts at the project's catalogue of its extensions, which isn't recorded in the history, as the page
    /// is hidden
    func testTheFirstPage() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        XCTAssertEqual(shown.watcher.started, [catalogueURL])
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .on])
        XCTAssertEqual(recorder.timesAsked, 0)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// With no project, the page starts at the extensions' documentation in Inform's folder in the Library
    func testWithoutAProject() throws {
        let shown = try makePage(project: nil)
        XCTAssertEqual(shown.watcher.started.first, "inform://Extensions/Extensions.html")
    }

    /// Until Inform has written the project's catalogue, the page shows a page saying there are no details yet
    func testAMissingCatalogue() throws {
        let recorder = Recorder()
        let shown = try makePage(project: makeProject(catalogue: nil), recorder: recorder)
        XCTAssertEqual(shown.watcher.started, [catalogueURL, "inform:/NoExtensions.html"])
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/NoExtensions.html")
        XCTAssertEqual(shown.watcher.errors.map { ($0 as NSError).code }, [NSURLErrorFileDoesNotExist])
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .off])
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// While the page is visible, a page that can't be loaded is recorded in the history, but the failure page shown in
    /// its place isn't
    func testTheFailurePageIsNotRecorded() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true

        open("inform://Extensions/Reserved/Documentation/Missing.html", in: shown)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/NoExtensions.html")
        XCTAssertEqual(recorder.timesAsked, 2)

        // What's shown next is recorded
        open("inform:/index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 4)
    }

    /// The Public Library's failure page is shown if the Public Library can't be loaded
    func testThePublicLibraryFailurePage() throws {
        let shown = try makePageWithCatalogue()
        let publicLibrary = try publicLibraryURL.absoluteString

        waitForNavigation(shown.watcher) {
            tellPageNavigationFailed(publicLibrary, provisional: true, in: shown)
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/pl404.html")

        open("inform:/index.html", in: shown)
        waitForNavigation(shown.watcher) {
            tellPageNavigationFailed(publicLibrary, provisional: false, in: shown)
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/pl404.html")
    }

    /// A cancelled navigation shows no failure page, nor does an error from the app's own URL schemes before the page
    /// is loaded, which is how a link that does something in the app ends
    func testErrorsThatShowNoFailurePage() throws {
        let shown = try makePageWithCatalogue()
        expectNoNavigation(shown.watcher) {
            tellPageNavigationFailed(catalogueURL, provisional: true, code: NSURLErrorCancelled, in: shown)
            tellPageNavigationFailed(catalogueURL, provisional: false, code: NSURLErrorCancelled, in: shown)
            tellPageNavigationFailed("source:story.ni#line1", provisional: true, domain: INFORM_ERROR_DOMAIN, code: 0, in: shown)
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)
    }

    /// When a census of the extensions finishes, the page is reloaded, as the catalogue may have changed, and that
    /// isn't recorded in the history. The other census notification doesn't reload it.
    func testTheCensusReloadsThePage() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true

        try writeCatalogue("<html><body><p>Updated</p></body></html>")
        waitForNavigation(shown.watcher) {
            NotificationCenter.default.post(name: .IFCensusFinished, object: nil)
        }
        XCTAssertEqual(shown.watcher.started, [catalogueURL, catalogueURL])
        XCTAssertEqual(try evaluate("document.body.innerText", in: shown.webView) as? String, "Updated")
        XCTAssertEqual(recorder.timesAsked, 0)

        expectNoNavigation(shown.watcher) {
            NotificationCenter.default.post(name: .IFCensusFinishedButDontUpdateExtensionsWebPage, object: nil)
        }

        // What's shown next is recorded
        open("inform:/index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 2)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// When a census finishes while the failure page is shown, the page that failed is tried again, as the census
    /// may have written it
    func testTheCensusRetriesAMissingCatalogue() throws {
        let recorder = Recorder()
        let shown = try makePage(project: makeProject(catalogue: nil), recorder: recorder)
        shown.page.pageIsVisible = true

        try writeCatalogue(catalogue)
        waitForNavigation(shown.watcher) {
            NotificationCenter.default.post(name: .IFCensusFinished, object: nil)
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .on])
        XCTAssertEqual(recorder.timesAsked, 0)

        // The catalogue isn't tried again once it has loaded
        try writeCatalogue("<html><body><p>Updated</p></body></html>")
        open("inform:/index.html", in: shown)
        waitForNavigation(shown.watcher) {
            NotificationCenter.default.post(name: .IFCensusFinished, object: nil)
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
    }

    /// The page bar's cells show the Public Library and the catalogue, each switching to the page and showing its page
    func testThePageBarCells() throws {
        let shown = try makePageWithCatalogue()
        let cells = shown.page.toolbarCells
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells.first?.stringValue, "Public Library")
        XCTAssertEqual(cells.last?.image?.name(), NSImage.homeTemplateName)
        XCTAssertEqual(cells.compactMap { $0.action.map(NSStringFromSelector) }, ["showPublicLibrary:", "showHome:"])
        XCTAssertTrue(cells.allSatisfy { $0.target === shown.page })

        open("inform:/index.html", in: shown)
        let home = try XCTUnwrap(cells.last)
        let showHome = try XCTUnwrap(home.action)
        var posted = notifications(.IFSwitchToPage, from: shown.page) {
            waitForNavigation(shown.watcher) {
                XCTAssertTrue(NSApp.sendAction(showHome, to: home.target, from: home))
            }
        }
        XCTAssertEqual(posted.map { $0.userInfo as? [String: String] }, [["Identifier": "IFExtensionsPage"]])
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)
        XCTAssertEqual(cells.map { $0.state }, [.off, .on])

        let publicLibrary = try XCTUnwrap(cells.first)
        let showPublicLibrary = try XCTUnwrap(publicLibrary.action)
        posted = notifications(.IFSwitchToPage, from: shown.page) {
            waitForRefusal(shown.watcher) {
                XCTAssertTrue(NSApp.sendAction(showPublicLibrary, to: publicLibrary.target, from: publicLibrary))
            }
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(shown.watcher.refused, [try publicLibraryURL])
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// The Public Library's cell is highlighted while the Public Library is shown, and either cell is highlighted for
    /// its page's URL in any case
    func testTheCellsHighlighted() throws {
        let shown = try makePageWithCatalogue()
        tellPageNavigationStarted(try publicLibraryURL.absoluteString, in: shown)
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.on, .off])

        tellPageNavigationStarted(catalogueURL.uppercased(), in: shown)
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .on])
    }

    /// Opening a URL switches to the page and shows it, with no cell highlighted for a page that isn't one of theirs
    func testOpeningAURL() throws {
        let shown = try makePageWithCatalogue()
        let posted = notifications(.IFSwitchToPage, from: shown.page) {
            open("inform:/index.html", in: shown)
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
        XCTAssertEqual(shown.page.toolbarCells.map { $0.state }, [.off, .off])
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// While the page is visible, each page it shows is recorded in the history, so that going back switches to the
    /// page and shows that page again, which isn't recorded
    func testTheHistory() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true

        let index = recorder.event
        open("inform:/index.html", in: shown)
        // To switch to the page, and to show its page
        XCTAssertEqual(recorder.timesAsked, 2)

        recorder.event = IFHistoryEvent(object: NSNull())
        open(catalogueURL, in: shown)
        XCTAssertEqual(recorder.timesAsked, 4)

        let posted = notifications(.IFSwitchToPage, from: shown.page) {
            waitForNavigation(shown.watcher) {
                index.replay()
            }
        }
        // Once from the history, and once more as the page is opened
        XCTAssertEqual(posted.count, 2)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
        XCTAssertEqual(recorder.timesAsked, 4)

        // What's shown next is recorded again
        open(catalogueURL, in: shown)
        XCTAssertEqual(recorder.timesAsked, 6)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Nothing is recorded in the history while the page isn't visible
    func testTheHistoryWhileHidden() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        open("inform:/index.html", in: shown)
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
        XCTAssertEqual(recorder.timesAsked, 0)
    }

    /// A link to install an extension from the Public Library isn't recorded in the history
    func testLibraryLinksAreNotRecorded() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true

        tellPageNavigationStarted("library:/resources/Extensions/Emily%20Short/Locksmith-v14.zip?id=1", in: shown)
        XCTAssertEqual(recorder.timesAsked, 0)

        tellPageNavigationStarted("inform:/index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 2)
    }

    /// Switching to the page records what it shows in the history, and reloads it
    func testSwitchingToThePage() throws {
        let recorder = Recorder()
        // Hidden, so that only what switching records is counted
        let shown = try makePageWithCatalogue(recorder: recorder)
        open("inform:/index.html", in: shown)

        let switched = recorder.event
        waitForNavigation(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertEqual(shown.watcher.started.suffix(2), ["inform:/index.html", "inform:/index.html"])

        recorder.event = IFHistoryEvent(object: NSNull())
        open(catalogueURL, in: shown)
        waitForNavigation(shown.watcher) {
            switched.replay()
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, "inform:/index.html")
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertTrue(shown.watcher.errors.isEmpty)
    }

    /// Switching to the page while it's visible records what it shows once, and not again as it's reloaded
    func testSwitchingToTheVisiblePageRecordsItOnce() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true
        open("inform:/index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 2)

        waitForNavigation(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, 3)
    }

    /// Going back to the page loads a page from the history straight after the reload as it's switched to. Neither
    /// is recorded, whichever starts, and what's shown next is.
    func testAPageFromTheHistoryAsThePageIsSwitchedTo() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        shown.page.pageIsVisible = true
        shown.page.didSwitchToPage()
        shown.page.openHistoricalURL(URL(string: "inform:/index.html"))
        waitUntilShown("inform:/index.html", in: shown)
        XCTAssertEqual(recorder.timesAsked, 1)

        open(catalogueURL, in: shown)
        XCTAssertEqual(recorder.timesAsked, 3)
    }

    /// Switching to the page while the failure page is shown records the page that failed in the history, not the
    /// failure page, and tries it again
    func testSwitchingToThePageRetriesAMissingCatalogue() throws {
        let recorder = Recorder()
        let shown = try makePage(project: makeProject(catalogue: nil), recorder: recorder)
        try writeCatalogue(catalogue)

        let switched = recorder.event
        waitForNavigation(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)

        open("inform:/index.html", in: shown)
        waitForNavigation(shown.watcher) {
            switched.replay()
        }
        XCTAssertEqual(shown.webView.url?.absoluteString, catalogueURL)
    }

    /// Switching to the page while the Public Library's failure page is shown tries the Public Library again
    func testSwitchingToThePageRetriesThePublicLibrary() throws {
        let recorder = Recorder()
        let shown = try makePageWithCatalogue(recorder: recorder)
        let publicLibrary = try publicLibraryURL
        waitForNavigation(shown.watcher) {
            tellPageNavigationFailed(publicLibrary.absoluteString, provisional: true, in: shown)
        }

        waitForRefusal(shown.watcher) {
            shown.page.didSwitchToPage()
        }
        XCTAssertEqual(recorder.timesAsked, 1)
        XCTAssertEqual(shown.watcher.refused, [publicLibrary])
    }

    /// When an extension has been installed from the Public Library, the page is told so
    func testAnExtensionUpdated() throws {
        let shown = try makePageWithCatalogue()
        shown.page.extensionUpdated("7")
        XCTAssertEqual(try evaluate("document.title", in: shown.webView) as? String, "Installed 7")
    }

    /// When the app's font size changes, the page is zoomed to it
    func testTheFontSize() throws {
        let shown = try makePageWithCatalogue()
        _ = try evaluate("document.body.style.zoom = '3'", in: shown.webView)
        NotificationCenter.default.post(name: .IFPreferencesAppFontSizeDidChange, object: IFPreferences.shared)
        let zoom = try evaluate("document.body.style.zoom", in: shown.webView) as? String
        XCTAssertEqual(zoom.flatMap { Double($0) },
                       Double(String(format: "%.2f", IFPreferences.shared.appFontSizeMultiplier)))
    }

    /// Once the page is closing, a census doesn't reload it
    func testClosing() throws {
        let shown = try makePageWithCatalogue()
        shown.page.willClose()

        expectNoNavigation(shown.watcher) {
            NotificationCenter.default.post(name: .IFCensusFinished, object: nil)
        }
    }
}
