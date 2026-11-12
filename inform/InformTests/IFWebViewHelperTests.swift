//
//  IFWebViewHelperTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no window, which records what the helper asks of it
private final class ProjectControllerStandIn: IFProjectController {
    var project: IFProject?
    var standInSourcePane: IFProjectPane?
    /// What selectSourceFile: and showTestCase:skeinNode: answer
    var sourceFileSelectable = true
    var testCaseShowable = true
    /// Each call the helper makes, in order
    private(set) var calls: [String] = []
    /// Called after each call is recorded
    var onCall: (() -> Void)?

    private func record(_ call: String) {
        calls.append(call)
        onCall?()
    }

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

    override var sourcePane: IFProjectPane? {
        return standInSourcePane
    }

    override func selectSourceFile(_ fileName: String) -> Bool {
        record("selectSourceFile \(fileName)")
        return sourceFileSelectable
    }

    override func move(toSourceFileLine line: Int) {
        record("moveToSourceFileLine \(line)")
    }

    override func removeHighlights(of style: IFLineStyle) {
        record("removeHighlights \(style.rawValue)")
    }

    override func highlightSourceFileLine(_ line: Int, inFile file: String, style: IFLineStyle) {
        record("highlightSourceFileLine \(line) \(file) \(style.rawValue)")
    }

    override func showTestCase(_ testCase: String, skeinNode skeinNodeId: UInt) -> Bool {
        record("showTestCase \(testCase) \(skeinNodeId)")
        return testCaseShowable
    }

    override func confirmInbuildAction() {
        record("confirmInbuildAction")
    }

    override func installExtension(_ extension: String) {
        record("installExtension \(`extension`)")
    }

    override func uninstallExtension(_ extension: String) {
        record("uninstallExtension \(`extension`)")
    }

    override func moderniseExtension(_ extension: String) {
        record("moderniseExtension \(`extension`)")
    }

    override func testExtension(_ extension: String, command: String, testcase: String) {
        record("testExtension \(`extension`) \(command) \(testcase)")
    }
}

/// A pane that records the views it's asked to show, with a stand-in source page
private final class PaneStandIn: IFProjectPane {
    private(set) var selected: [IFProjectPaneType] = []
    var standInSourcePage: IFSourcePage?

    override func selectView(of pane: IFProjectPaneType) {
        selected.append(pane)
    }

    override var sourcePage: IFSourcePage {
        return standInSourcePage!
    }
}

/// A source page that records the code pasted into it
private final class SourcePageStandIn: IFSourcePage {
    private(set) var pasted: [String] = []

    override func pasteSourceCode(_ sourceCode: String) {
        pasted.append(sourceCode)
    }
}

/// A script message, as a page's script posts to the helper
private final class ScriptMessage: WKScriptMessage {
    private let messageBody: Any

    init(_ body: Any) {
        messageBody = body
        super.init()
    }

    override var body: Any {
        return messageBody
    }

    override var name: String {
        return "scriptHandler"
    }
}

/// A URL scheme task that records what the helper sends it.
private final class RecordingTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    var response: URLResponse?
    var data = Data()
    var error: Error?
    var finished = false

    init(_ url: String) {
        request = URLRequest(url: URL(string: url)!)
    }

    func didReceive(_ response: URLResponse) { self.response = response }
    func didReceive(_ data: Data) { self.data.append(data) }
    func didFinish() { finished = true }
    func didFailWithError(_ error: Error) { self.error = error }
}

/// Tells the tests when a web view's navigation finishes
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    var onFinish: (() -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?()
    }
}

@MainActor
final class IFWebViewHelperTests: XCTestCase, @unchecked Sendable {

    /// The helper's project controller, with its source pane, and its other pane
    private var controller: ProjectControllerStandIn!
    private var sourcePane: PaneStandIn!
    private var pane: PaneStandIn!

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()

            // A project controller that doesn't watch for settings changing, and so doesn't make the project window's
            // toolbar for them, which saves its configuration in the user's preferences.
            controller = ProjectControllerStandIn()
            NotificationCenter.default.removeObserver(controller as Any)
            sourcePane = PaneStandIn()
            pane = PaneStandIn()
            controller.standInSourcePane = sourcePane
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            controller = nil
            sourcePane = nil
            pane = nil
            super.tearDown()
        }
    }

    /// The helper for the stand-in project controller and pane
    private func makeHelper() -> IFWebViewHelper {
        return IFWebViewHelper(projectController: controller, with: pane)
    }

    /// Loads a URL through the helper's handler for the app's own URL schemes, from a web view with no page.
    private func load(_ url: String, helper: IFWebViewHelper? = nil) -> RecordingTask {
        let helper = helper ?? IFWebViewHelper(projectController: nil, with: nil)
        let task = RecordingTask(url)
        helper.webView(WKWebView(frame: .zero, configuration: WKWebViewConfiguration()), start: task)
        return task
    }

    /// The file at this path in the app's resources
    private func resource(_ path: String) throws -> Data {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)
        return try Data(contentsOf: resources.appendingPathComponent(path))
    }

    /// Checks that the task was given the data and type and then finished
    private func assertLoaded(_ task: RecordingTask, _ data: Data, type: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let url = task.request.url!.absoluteString
        XCTAssertNil(task.error, url, file: file, line: line)
        XCTAssertTrue(task.finished, url, file: file, line: line)
        XCTAssertEqual(task.response?.url, task.request.url, url, file: file, line: line)
        XCTAssertEqual(task.response?.mimeType, type, url, file: file, line: line)
        XCTAssertEqual(task.response?.expectedContentLength, Int64(data.count), url, file: file, line: line)
        XCTAssertEqual(task.data, data, url, file: file, line: line)
    }

    /// Checks that the task failed with this error, and was given nothing
    private func assertFailed(_ task: RecordingTask, domain: String, code: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
        let url = task.request.url!.absoluteString
        let error = task.error as NSError?
        XCTAssertEqual(error?.domain, domain, url, file: file, line: line)
        XCTAssertEqual(error?.code, code, url, file: file, line: line)
        XCTAssertNil(task.response, url, file: file, line: line)
        XCTAssertTrue(task.data.isEmpty, url, file: file, line: line)
        XCTAssertFalse(task.finished, url, file: file, line: line)
    }

    /// Checks that the task failed as the helper fails the links it acts on, so that the web view stays on its page
    private func assertFailedAsHandled(_ task: RecordingTask, file: StaticString = #filePath, line: UInt = #line) {
        assertFailed(task, domain: INFORM_ERROR_DOMAIN, code: 0, file: file, line: line)
    }

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// Writes a file, making its folder
    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    /// Opens a project in a new folder, as the app does, which makes its materials folder beside it. It's closed when
    /// the test ends.
    private func openProject() throws -> IFProject {
        let url = try makeFolder().appendingPathComponent("Lighthouse.inform")
        try write("\"Lighthouse\"\n", to: url.appendingPathComponent("Source/story.ni"))
        let project = try IFProject(contentsOf: url, ofType: "org.inform-fiction.project")
        addTeardownBlock { project.close() }
        return project
    }

    /// Posts a message to the helper, as a page's script does
    private func post(_ body: Any, to helper: IFWebViewHelper) {
        helper.userContentController(WKUserContentController(), didReceive: ScriptMessage(body))
    }

    /// A web view made by the helper, once it has loaded a page
    private func makeLoadedWebView(_ helper: IFWebViewHelper) -> (WKWebView, NavigationWatcher) {
        let webView = helper.createWebView(withFrame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let watcher = NavigationWatcher()
        webView.navigationDelegate = watcher
        let loaded = expectation(description: "loaded")
        watcher.onFinish = { loaded.fulfill() }
        webView.loadHTMLString("<html><body><p>Lighthouse</p></body></html>", baseURL: nil)
        wait(for: [loaded], timeout: 10)
        watcher.onFinish = nil
        return (webView, watcher)
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

    /// The zoom that the helper gives a web view's page for the font size preference
    private var expectedZoom: String {
        return String(format: "%.2f", IFPreferences.shared.appFontSizeMultiplier)
    }

    // MARK: - The web view

    func testMakesAWebViewForTheAppsURLSchemes() {
        let helper = makeHelper()
        let frame = NSRect(x: 10, y: 20, width: 400, height: 300)
        let webView = helper.createWebView(withFrame: frame)

        XCTAssertEqual(webView.frame, frame)
        XCTAssertEqual(webView.autoresizingMask, [.width, .height])
        XCTAssertIdentical(webView.uiDelegate, helper)
        for scheme in ["inform", "source", "skein", "library"] {
            XCTAssertIdentical(webView.configuration.urlSchemeHandler(forURLScheme: scheme), helper, scheme)
        }
    }

    /// The tests' web views keep their website data in memory, not in the user's Library.
    func testWebViewsKeepTheirDataInMemory() {
        let helper: IFWebViewHelper = IFWebViewHelper(projectController: nil, with: nil)
        let webView = helper.createWebView(withFrame: .zero)
        XCTAssertFalse(webView.configuration.websiteDataStore.isPersistent)
    }

    /// Each page's main frame is given a script that sets its zoom for the font size preference, and the scripts that
    /// post its messages to the app
    func testGivesEachPageItsScripts() throws {
        let webView = makeHelper().createWebView(withFrame: .zero)
        let scripts = webView.configuration.userContentController.userScripts
        let messages = try String(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "messages_to_objc",
                                                                          withExtension: "js")),
                                  encoding: .utf8)

        XCTAssertEqual(scripts.count, 1)
        XCTAssertEqual(scripts.first?.source,
                       "window.addEventListener(\"load\",function () { document.body.style.zoom = '\(expectedZoom)'; }, false);"
                       + messages)
        XCTAssertEqual(scripts.first?.injectionTime, .atDocumentStart)
        XCTAssertEqual(scripts.first?.isForMainFrameOnly, true)
    }

    func testAPageIsZoomedForTheFontSizePreference() throws {
        let (webView, _) = makeLoadedWebView(makeHelper())

        let zoom = try XCTUnwrap(evaluate("document.body.style.zoom", in: webView) as? String)
        XCTAssertEqual(Double(zoom), Double(expectedZoom))
    }

    func testZoomsAPageAgainWhenTheFontSizePreferenceChanges() throws {
        let helper = makeHelper()
        let (webView, _) = makeLoadedWebView(helper)
        _ = try evaluate("document.body.style.zoom = '3'", in: webView)

        helper.fontSizePreferenceChanged(webView)

        let zoom = try XCTUnwrap(evaluate("document.body.style.zoom", in: webView) as? String)
        XCTAssertEqual(Double(zoom), Double(expectedZoom))
    }

    /// A page's script posts its messages to the helper through the Project object that the helper's script gives it
    func testAPagesScriptPostsItsMessagesToTheHelper() throws {
        let helper = makeHelper()
        let (webView, _) = makeLoadedWebView(helper)
        let called = expectation(description: "called")
        controller.onCall = { called.fulfill() }

        _ = try evaluate("window.Project.install('Locksmith by Emily Short')", in: webView)

        wait(for: [called], timeout: 10)
        XCTAssertEqual(controller.calls, ["installExtension Locksmith by Emily Short"])
    }

    // MARK: - inform: URLs for the app's resources

    /// The pages the Extensions page shows when it can't load the Public Library, or the
    /// project's catalogue of extensions, are in the app's resources.
    func testExtensionsFailurePagesLoad() {
        for page in ["inform:/pl404.html", "inform:/NoExtensions.html"] {
            let task = load(page)
            XCTAssertNil(task.error, page)
            XCTAssertTrue(task.finished, page)
            XCTAssertEqual(task.response?.mimeType, "text/html", page)
            XCTAssertFalse(task.data.isEmpty, page)
        }
    }

    func testLoadsAPageOfTheDocumentation() throws {
        assertLoaded(load("inform:/WI_1_1.html"), try resource("en.lproj/WI_1_1.html"), type: "text/html")
    }

    /// The compiler writes some links in lower case, and the files' names aren't
    func testLoadsAPageWhoseNameIsInAnotherCase() throws {
        assertLoaded(load("inform:/wi_9_1.html"), try resource("en.lproj/WI_9_1.html"), type: "text/html")
    }

    func testLoadsAFileInAFolder() throws {
        assertLoaded(load("inform:/doc_images/Sophia.jpg"), try resource("doc_images/Sophia.jpg"), type: "image/jpeg")
    }

    func testGivesEachFileItsType() throws {
        let files = ["inform:/doc_images/Below.png": ("doc_images/Below.png", "image/png"),
                     "inform:/doc_images/Below.tif": ("doc_images/Below.tif", "image/tiff"),
                     "inform:/Internal/Templates/Quixe/waiting.gif": ("Internal/Templates/Quixe/waiting.gif", "image/gif"),
                     "inform:/Internal/HTML/main.css": ("Internal/HTML/main.css", "text/css"),
                     "inform:/messages_to_objc.js": ("messages_to_objc.js", "text/javascript"),
                     "inform:/InformCoreVersion.txt": ("InformCoreVersion.txt", "text/plain")]
        for (url, (path, type)) in files {
            assertLoaded(load(url), try resource(path), type: type)
        }
    }

    /// A file of a type with no MIME type is given as HTML
    func testGivesAFileOfAnUnknownTypeAsHTML() throws {
        assertLoaded(load("inform:/retrospective/6L38/I6T/Char.i6t"), try resource("retrospective/6L38/I6T/Char.i6t"),
                     type: "text/html")
    }

    /// An image that isn't a file in the resources, but is in the asset catalog, is given as a TIFF, whether or not
    /// its name asks for the double-size image
    func testGivesAnImageInTheAssetCatalogAsATIFF() throws {
        let image = try XCTUnwrap(NSImage(named: "Blob-Logo")?.tiffRepresentation)
        assertLoaded(load("inform:/Blob-Logo.png"), image, type: "image/tiff")
        assertLoaded(load("inform:/Blob-Logo@2x.png"), image, type: "image/tiff")

        let skeinImage = try XCTUnwrap(NSImage(named: "App/Skein/Skein-active")?.tiffRepresentation)
        assertLoaded(load("inform:/App/Skein/Skein-active.png"), skeinImage, type: "image/tiff")
    }

    func testFailsForAMissingFile() {
        let task = load("inform:/NoSuchPage.html")

        assertFailed(task, domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)
        XCTAssertEqual((task.error as NSError?)?.userInfo[NSURLErrorFailingURLErrorKey] as? URL, task.request.url)
    }

    func testFailsForAFolder() {
        for url in ["inform:/doc_images", "inform:/doc_images/", "inform:/Internal/HTML"] {
            assertFailed(load(url), domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)
        }
    }

    /// With no path, it's the resources folder itself
    func testFailsForNoPath() {
        // NSURL gives the last two no path at all
        for url in ["inform:/", "inform:", "inform:pl404.html"] {
            assertFailed(load(url), domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)
        }
    }

    // MARK: - inform: URLs for extensions

    func testLoadsAFileInTheProjectsExtensions() throws {
        let project = try openProject()
        controller.project = project
        let materials = try XCTUnwrap(project.materialsDirectoryURL)
        let notes = "<p>Notes</p>"
        try write(notes, to: materials.appendingPathComponent("Extensions/Jane Doe/Notes.html"))

        // As the host, the path's first part, or both
        for url in ["inform://Extensions/Jane%20Doe/Notes.html",
                    "inform://extensions/Jane%20Doe/Notes.html",
                    "inform:/Extensions/Jane%20Doe/Notes.html",
                    "inform:/extensions/Jane%20Doe/Notes.html",
                    "inform://Extensions/Extensions/Jane%20Doe/Notes.html"] {
            assertLoaded(load(url, helper: makeHelper()), Data(notes.utf8), type: "text/html")
        }
    }

    /// The Index links to an extension's documentation as Documentation/<author>/<title>.html, but Inform writes the
    /// page in a folder named for the extension's version
    func testLoadsTheDocumentationOfAnExtensionInTheProject() throws {
        let project = try openProject()
        controller.project = project
        let materials = try XCTUnwrap(project.materialsDirectoryURL)
        let page = "<p>Lighthouse Lamps</p>"
        try write(page, to: materials.appendingPathComponent(
            "Extensions/Reserved/Documentation/Jane Doe/Lighthouse Lamps-v2/index.html"))

        for url in ["inform://Extensions/Documentation/Jane%20Doe/Lighthouse%20Lamps.html",
                    "inform:/Extensions/Documentation/Jane%20Doe/Lighthouse%20Lamps.html"] {
            assertLoaded(load(url, helper: makeHelper()), Data(page.utf8), type: "text/html")
        }
    }

    /// An extensions URL whose file isn't in the project is looked for in the top folder of the app's resources
    func testLooksInTheResourcesForAnExtensionsFileNotInTheProject() throws {
        controller.project = try openProject()

        assertLoaded(load("inform://Extensions/messages_to_objc.js", helper: makeHelper()),
                     try resource("messages_to_objc.js"), type: "text/javascript")
        assertFailed(load("inform://Extensions/Jane%20Doe/Missing.html", helper: makeHelper()),
                     domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)
    }

    /// With no project, an extensions URL is looked for in Inform's documentation folder in the Library
    func testFailsForAMissingExtensionsFileWithNoProject() {
        assertFailed(load("inform://Extensions/No%20Such%20Author/Missing.html"),
                     domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist)
    }

    // MARK: - inform: URLs that go up

    /// A URL's path can go up out of the folder it's looked for in, as NSURL decodes "..%2F"
    func testGivesNothingAboveTheResources() {
        for url in ["inform:/..%2FInfo.plist", "inform:/doc_images/..%2F..%2FInfo.plist", "inform:/%2E%2E/Info.plist"] {
            assertFailed(load(url), domain: NSURLErrorDomain, code: NSURLErrorNoPermissionsToReadFile)
        }
    }

    func testGivesNothingAboveTheProjectsExtensions() throws {
        let project = try openProject()
        controller.project = project
        let materials = try XCTUnwrap(project.materialsDirectoryURL)
        try write("<p>Notes</p>", to: materials.appendingPathComponent("Extensions/Jane Doe/Notes.html"))

        for url in ["inform://Extensions/..%2F..%2FLighthouse.inform%2FSource%2Fstory.ni",
                    "inform:/Extensions/..%2F..%2FLighthouse.inform%2FSource%2Fstory.ni"] {
            assertFailed(load(url, helper: makeHelper()), domain: NSURLErrorDomain,
                         code: NSURLErrorNoPermissionsToReadFile)
        }
    }

    // MARK: - source: and skein: links

    func testASourceLinkShowsItsLineInTheSource() throws {
        controller.project = IFProject()

        let task = load("source:story.ni#line12", helper: makeHelper())

        XCTAssertEqual(controller.calls, ["selectSourceFile story.ni",
                                          "moveToSourceFileLine 12",
                                          "removeHighlights \(IFLineStyle.error.rawValue)",
                                          "highlightSourceFileLine 12 story.ni \(IFLineStyle.error.rawValue)"])
        assertFailedAsHandled(task)
    }

    func testASourceLinkToAFileThatCantBeShownDoesNothing() throws {
        controller.project = IFProject()
        controller.sourceFileSelectable = false

        let task = load("source:Notes.ni#line3", helper: makeHelper())

        XCTAssertEqual(controller.calls, ["selectSourceFile Notes.ni"])
        assertFailedAsHandled(task)
    }

    func testASourceLinkDoesNothingWithNoProject() {
        let task = load("source:story.ni#line12", helper: makeHelper())

        XCTAssertEqual(controller.calls, [])
        assertFailedAsHandled(task)
    }

    /// Inform only writes source links with a line
    func testASourceLinkWithNoLineDoesNothing() {
        controller.project = IFProject()

        let task = load("source:story.ni", helper: makeHelper())

        XCTAssertEqual(controller.calls, [])
        assertFailedAsHandled(task)
    }

    func testASkeinLinkShowsItsKnot() {
        let task = load("skein:1003?case=B", helper: makeHelper())

        XCTAssertEqual(controller.calls, ["showTestCase B 1003"])
        assertFailedAsHandled(task)
    }

    func testASkeinLinkToATestCaseThatCantBeShownFails() {
        controller.testCaseShowable = false

        let task = load("skein:1003?case=Z", helper: makeHelper())

        XCTAssertEqual(controller.calls, ["showTestCase Z 1003"])
        assertFailedAsHandled(task)
    }

    /// A library link is made into a link to the Public Library from the web view's page. A web view with no page
    /// downloads nothing.
    func testALibraryLinkInAWebViewWithNoPageDoesNothing() {
        let task = load("library:/resources/Extensions/Jane%20Doe/Lighthouse%20Lamps-v2.zip?id=4", helper: makeHelper())

        XCTAssertEqual(controller.calls, [])
        assertFailedAsHandled(task)
    }

    // MARK: - Script messages

    func testSelectsAViewInThePane() {
        let helper = makeHelper()
        let views: [(String, IFProjectPaneType)] = [("error", .errorPane), ("game", .gamePane),
                                                    ("documentation", .documentationPane), ("index", .indexPane),
                                                    ("skein", .skeinPane), ("Index", .indexPane)]

        for (view, _) in views {
            post(["selectView", view], to: helper)
        }

        XCTAssertEqual(pane.selected, views.map { $0.1 })
        XCTAssertEqual(sourcePane.selected, [])
    }

    func testSelectsTheSourceInTheSourcePane() {
        post(["selectView", "Source"], to: makeHelper())

        XCTAssertEqual(sourcePane.selected, [.sourcePane])
        XCTAssertEqual(pane.selected, [])
    }

    func testSelectsNoOtherView() {
        let helper = makeHelper()

        for view in ["extensions", "settings", ""] {
            post(["selectView", view], to: helper)
        }

        XCTAssertEqual(sourcePane.selected, [])
        XCTAssertEqual(pane.selected, [])
    }

    func testPassesExtensionActionsToTheProjectController() {
        let helper = makeHelper()

        post(["confirmAction"], to: helper)
        post(["install", "Locksmith by Emily Short"], to: helper)
        post(["modernise", "Lighthouse Lamps by Jane Doe"], to: helper)
        post(["uninstall", "Basic Screen Effects by Emily Short"], to: helper)
        post(["test", "Lighthouse Lamps by Jane Doe", "-test", "A"], to: helper)

        XCTAssertEqual(controller.calls, ["confirmInbuildAction",
                                          "installExtension Locksmith by Emily Short",
                                          "moderniseExtension Lighthouse Lamps by Jane Doe",
                                          "uninstallExtension Basic Screen Effects by Emily Short",
                                          "testExtension Lighthouse Lamps by Jane Doe -test A"])
    }

    /// The documentation's Paste buttons give their code with escapes, such as \n and \t
    func testPastesCodeIntoTheSourcePage() {
        let sourcePage = SourcePageStandIn(projectController: controller)
        sourcePane.standInSourcePage = sourcePage

        post(["pasteCode", "The Kitchen is a room.\\n\\tIt is dark."], to: makeHelper())

        XCTAssertEqual(sourcePage.pasted, ["The Kitchen is a room.\n\tIt is dark."])
    }

    func testIgnoresAMessageWithTooFewParts() {
        let helper = makeHelper()

        for message in [["selectView"], ["install"], ["modernise"], ["uninstall"], ["test", "A", "B"],
                        ["createNewProject", "Lighthouse"], ["pasteCode"], ["openFile"], ["openURL"], []] {
            post(message, to: helper)
        }

        XCTAssertEqual(controller.calls, [])
        XCTAssertEqual(sourcePane.selected, [])
        XCTAssertEqual(pane.selected, [])
    }

    func testIgnoresPartsBeyondThoseNeeded() {
        post(["install", "Locksmith by Emily Short", "extra"], to: makeHelper())

        XCTAssertEqual(controller.calls, ["installExtension Locksmith by Emily Short"])
    }

    /// Including those the Public Library's script posts that the app doesn't act on
    func testIgnoresAMessageItDoesntKnow() {
        let helper = makeHelper()

        for message in [["askInterfaceForLocalVersion", "Emily Short", "Locksmith", "10.1"],
                        ["askInterfaceForLocalVersionText", "Emily Short", "Locksmith"],
                        ["downloadMultipleExtensions", "Emily Short"],
                        ["Install", "Locksmith by Emily Short"]] {
            post(message, to: helper)
        }

        XCTAssertEqual(controller.calls, [])
    }

    /// No page's script posts anything but a list of strings
    func testIgnoresAMessageThatIsntAListOfStrings() {
        let helper = makeHelper()
        let messages: [Any] = ["install", 4, ["install": "Locksmith by Emily Short"],
                               ["selectView", 4], ["selectView", NSNull()], ["install", 4], ["confirmAction", 4],
                               ["install", "Locksmith by Emily Short", NSNull()]]

        for message in messages {
            post(message, to: helper)
        }

        XCTAssertEqual(controller.calls, [])
        XCTAssertEqual(sourcePane.selected, [])
        XCTAssertEqual(pane.selected, [])
    }
}
