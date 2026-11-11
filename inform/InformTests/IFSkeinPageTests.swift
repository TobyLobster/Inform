//
//  IFSkeinPageTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A project controller with no window, whose document is the project the test gives it
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which the page asks for its skein and settings
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

/// Stands between the page's web view and the page, its navigation delegate, telling the tests when a navigation
/// finishes
private final class NavigationWatcher: NSObject, WKNavigationDelegate {
    private let page: WKNavigationDelegate
    /// Called when a navigation finishes
    var onFinish: (() -> Void)?

    init(_ page: IFSkeinPage) {
        self.page = page
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        page.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?()
    }
}

@MainActor
final class IFSkeinPageTests: XCTestCase, @unchecked Sendable {

    /// A page being tested, with its views
    @MainActor
    private struct Shown {
        let page: IFSkeinPage
        let project: IFProject
        let splitView: NSSplitView
        let skeinView: IFSkeinView
        let webView: WKWebView
        let watcher: NavigationWatcher

        /// The view holding the help, which the split view collapses to hide it
        var helpView: NSView {
            return splitView.subviews[1]
        }

        /// The page bar cell that shows and hides the help
        var toggleHelpCell: IFPageBarCell {
            return page.toolbarCells[2]
        }
    }

    /// The help's blocks, as the help's template names them
    private let helpBlocks = ["welcome", "title", "purple", "grey", "blue", "report", "tick", "cross", "badge",
                              "threads", "knots", "moreknots", "menu", "welcomead"]
    /// The height the help is given, while it's shown
    private let helpHeight: CGFloat = 250

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

    /// The views of the given class in a view, at any depth
    private func descendants<T: NSView>(of view: NSView, _ type: T.Type) -> [T] {
        return view.subviews.flatMap { subview -> [T] in
            return ((subview as? T).map { [$0] } ?? []) + descendants(of: subview, type)
        }
    }

    /// A skein page for a new project, once it has loaded its help
    private func makePage(helpShown: Bool? = nil, shownCount: Int32? = nil) throws -> Shown {
        let project = IFProject()
        if let helpShown {
            project.settings.testingTabHelpShown = helpShown
        }
        if let shownCount {
            project.settings.testingTabShownCount = shownCount
        }

        let controller = try XCTUnwrap(controller)
        controller.project = project
        let page = IFSkeinPage(projectController: controller, with: IFProjectPane())

        let webView = try XCTUnwrap(descendants(of: page.view, WKWebView.self).first)
        let watcher = NavigationWatcher(page)
        webView.navigationDelegate = watcher
        waitForNavigation(watcher) {
            // The page has started loading its help
        }

        let made = Shown(page: page,
                         project: project,
                         splitView: try XCTUnwrap(descendants(of: page.view, NSSplitView.self).first),
                         skeinView: try XCTUnwrap(descendants(of: page.view, IFSkeinView.self).first),
                         webView: webView,
                         watcher: watcher)
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

    /// Lets what the page has put off until the next turn of the run loop happen
    private func runTheRunLoop() {
        let ran = expectation(description: "run loop ran")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ran.fulfill()
        }
        wait(for: [ran], timeout: 2)
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

    /// The help's blocks that are shown
    private func shownHelpBlocks(_ shown: Shown) throws -> [String] {
        let script = "[\(helpBlocks.map { "'\($0)'" }.joined(separator: ","))]"
            + ".filter(id => document.getElementById(id).style.display == 'block')"
        return try XCTUnwrap(evaluate(script, in: shown.webView) as? [String])
    }

    /// Clicks the cell that shows and hides the help, which isn't in a page bar, so has no control view
    private func toggleHelp(_ shown: Shown) throws {
        let cell = shown.toggleHelpCell
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(cell.action), to: cell.target, from: nil))
    }

    func testTheTitle() throws {
        let shown = try makePage()
        XCTAssertEqual(shown.page.title, "Testing")
    }

    /// The page bar's cells play all the blessed knots, save the transcript, which needs a knot selected, and show
    /// and hide the help
    func testThePageBarCells() throws {
        let shown = try makePage()
        let cells = shown.page.toolbarCells
        XCTAssertEqual(cells.map { $0.title }, ["Play All", "Save Transcript", "Hide Help"])
        XCTAssertEqual(cells.compactMap { $0.action.map(NSStringFromSelector) },
                       ["replayEntireSkein:", "saveTranscript:", "toggleHelp:"])
        XCTAssertTrue(cells.allSatisfy { $0.target === shown.page })
        XCTAssertEqual(cells.map { $0.isEnabled }, [true, false, true])
    }

    /// The page shows the project's skein, and tells the project's controller what's done in it
    func testTheSkeinView() throws {
        let shown = try makePage()
        XCTAssertTrue(shown.skeinView.skein === shown.project.currentSkein)
        XCTAssertTrue(shown.skeinView.delegate === controller)
    }

    /// The help is shown at first if the project's settings say so, as they do for a new project
    func testTheHelpShownAtFirst() throws {
        let shown = try makePage()
        XCTAssertTrue(shown.project.settings.testingTabHelpShown)
        XCTAssertEqual(shown.toggleHelpCell.title, "Hide Help")
        XCTAssertFalse(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.splitView.subviews[0].frame.height, shown.splitView.bounds.height - helpHeight)
    }

    /// The help is hidden at first if the project's settings say so
    func testTheHelpHiddenAtFirst() throws {
        let shown = try makePage(helpShown: false)
        XCTAssertEqual(shown.toggleHelpCell.title, "Show Help")
        XCTAssertTrue(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertFalse(shown.project.settings.testingTabHelpShown)
    }

    /// The help cell hides the help, and shows it again, keeping the project's settings in step
    func testTogglingTheHelp() throws {
        let shown = try makePage()

        try toggleHelp(shown)
        XCTAssertTrue(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.toggleHelpCell.title, "Show Help")
        XCTAssertFalse(shown.project.settings.testingTabHelpShown)

        try toggleHelp(shown)
        XCTAssertFalse(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.toggleHelpCell.title, "Hide Help")
        XCTAssertTrue(shown.project.settings.testingTabHelpShown)
        XCTAssertEqual(shown.splitView.subviews[0].frame.height, shown.splitView.bounds.height - helpHeight)
    }

    /// Moving the divider to hide the help, or to show it again, changes the cell and the project's settings
    func testMovingTheDivider() throws {
        let shown = try makePage()
        let height = shown.splitView.bounds.height

        shown.splitView.setPosition(height, ofDividerAt: 0)
        XCTAssertTrue(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.toggleHelpCell.title, "Show Help")
        XCTAssertFalse(shown.project.settings.testingTabHelpShown)

        shown.splitView.setPosition(height - helpHeight, ofDividerAt: 0)
        XCTAssertFalse(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.toggleHelpCell.title, "Hide Help")
        XCTAssertTrue(shown.project.settings.testingTabHelpShown)
    }

    /// Another split view resizing doesn't change the cell or the project's settings
    func testAnotherSplitViewResizing() throws {
        let shown = try makePage(helpShown: false)
        NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification, object: NSSplitView())
        XCTAssertTrue(shown.splitView.isSubviewCollapsed(shown.helpView))
        XCTAssertEqual(shown.toggleHelpCell.title, "Show Help")
        XCTAssertFalse(shown.project.settings.testingTabHelpShown)
    }

    /// Switching to the page counts it in the project's settings, and shows the help for what the skein shows: for a
    /// new project, its title, its grey and blue knots, and that knots appear as turns are played, with a welcome for
    /// the first ten times
    func testSwitchingToThePage() throws {
        let shown = try makePage()
        shown.page.didSwitchToPage()
        runTheRunLoop()
        XCTAssertEqual(shown.project.settings.testingTabShownCount, 1)
        XCTAssertEqual(try shownHelpBlocks(shown), ["welcome", "title", "grey", "blue", "knots"])
    }

    /// From the tenth time the page is switched to, the welcome gives way to the advanced buttons
    func testTheWelcomeGoes() throws {
        let shown = try makePage(shownCount: 9)
        shown.page.didSwitchToPage()
        runTheRunLoop()
        XCTAssertEqual(shown.project.settings.testingTabShownCount, 10)
        XCTAssertEqual(try shownHelpBlocks(shown), ["title", "grey", "blue", "knots", "welcomead"])
    }

    /// Selecting a knot allows its transcript to be saved, and shows the help for the report
    func testSelectingAKnot() throws {
        let shown = try makePage()
        shown.page.didSwitchToPage()
        let root = try XCTUnwrap(shown.project.currentSkein).rootItem

        XCTAssertTrue(shown.page.selectSkeinItem(withNodeId: root.uniqueId))
        XCTAssertTrue(shown.skeinView.selectedItem === root)
        XCTAssertTrue(shown.page.toolbarCells[1].isEnabled)
        runTheRunLoop()
        XCTAssertTrue(try shownHelpBlocks(shown).contains("report"))

        XCTAssertFalse(shown.page.selectSkeinItem(withNodeId: root.uniqueId + 1000))
    }

    /// When the project's skein is replaced, the page shows the project's skein
    func testTheSkeinReplaced() throws {
        let shown = try makePage()
        shown.skeinView.skein = IFSkein(project: shown.project)
        NotificationCenter.default.post(name: .IFSkeinReplaced, object: nil)
        XCTAssertTrue(shown.skeinView.skein === shown.project.currentSkein)
    }

    /// The split view only collapses the help, and keeps the help's height as it's resized
    func testTheSplitView() throws {
        let shown = try makePage()
        let delegate = shown.page as NSSplitViewDelegate
        let split = shown.splitView
        XCTAssertEqual(delegate.splitView?(split, canCollapseSubview: split.subviews[0]), false)
        XCTAssertEqual(delegate.splitView?(split, canCollapseSubview: split.subviews[1]), true)

        let height = split.bounds.height
        for proposed: CGFloat in [0, 100, height / 2, height] {
            XCTAssertEqual(delegate.splitView?(split, constrainSplitPosition: proposed, ofSubviewAt: 0),
                           max(helpHeight, height - helpHeight))
        }

        split.setFrameSize(NSSize(width: 500, height: 900))
        XCTAssertEqual(split.subviews[1].frame.height, helpHeight)
        XCTAssertEqual(split.subviews[0].frame.height, 900 - helpHeight - split.dividerThickness)
        XCTAssertEqual(split.subviews.map { $0.frame.width }, [500, 500])
    }

    /// When the app's font size changes, the help is zoomed to it
    func testTheFontSize() throws {
        let shown = try makePage()
        _ = try evaluate("document.body.style.zoom = '3'", in: shown.webView)
        NotificationCenter.default.post(name: .IFPreferencesAppFontSizeDidChange, object: IFPreferences.shared)
        let zoom = try evaluate("document.body.style.zoom", in: shown.webView) as? String
        XCTAssertEqual(zoom.flatMap { Double($0) },
                       Double(String(format: "%.2f", IFPreferences.shared.appFontSizeMultiplier)))
    }
}
