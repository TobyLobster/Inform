//
//  IFPageTests.swift
//  InformTests
//

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

/// Gives a page the history event that a pane would
private final class Recorder: NSObject, IFHistoryRecorder {
    var historyEvent: IFHistoryEvent?
}

final class IFPageTests: XCTestCase {

    /// A page with no nib, which is all a page needs to be tested on its own
    private func makePage(projectController: IFProjectController? = nil) -> IFPage {
        return IFPage(nibName: "No Such Nib", projectController: projectController)
    }

    /// A project controller that doesn't watch for settings changing, and so doesn't make the project window's
    /// toolbar for them, which saves its configuration in the user's preferences.
    private func makeProjectController() -> ProjectControllerStandIn {
        let controller = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(controller)
        return controller
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

    func testANewPage() {
        let page = makePage()
        XCTAssertNil(page.parent)
        XCTAssertNil(page.otherPane)
        XCTAssertNil(page.thisPane)
        XCTAssertNil(page.recorder)
        XCTAssertNil(page.history)
        XCTAssertFalse(page.pageIsVisible)
        XCTAssertEqual(page.title, "Untitled")
        XCTAssertEqual(page.identifier, "IFPage")
        XCTAssertTrue(page.shouldShowPage)
        XCTAssertEqual(page.toolbarCells.count, 0)
    }

    func testTheParent() {
        let controller = makeProjectController()
        let page = makePage(projectController: controller)
        XCTAssertTrue(page.parent === controller)
    }

    /// When the controller has finished with the page, it no longer has a parent or the other pane
    func testFinishing() {
        let controller = makeProjectController()
        let pane = IFProjectPane()
        let otherPane = IFProjectPane()
        let page = makePage(projectController: controller)
        page.thisPane = pane
        page.otherPane = otherPane

        page.finished()
        XCTAssertNil(page.parent)
        XCTAssertNil(page.otherPane)
        XCTAssertTrue(page.thisPane === pane)
    }

    /// The parent and panes aren't kept by the page
    func testTheParentAndPanesAreWeak() {
        let page = makePage(projectController: makeProjectController())
        autoreleasepool {
            let pane = IFProjectPane()
            page.thisPane = pane
            page.otherPane = pane
        }
        XCTAssertNil(page.parent)
        XCTAssertNil(page.thisPane)
        XCTAssertNil(page.otherPane)
    }

    /// The nib sets the view by its key, and the page keeps it; it's also the active view
    func testTheNibSetsTheView() {
        let page = makePage()
        weak var weakView: NSView?
        autoreleasepool {
            let view = NSView()
            weakView = view
            page.setValue(view, forKey: "view")
        }
        XCTAssertNotNil(weakView)
        XCTAssertTrue(page.view === weakView)
        XCTAssertTrue(page.activeView === weakView)
    }

    func testPageIsVisible() {
        let page = makePage()
        page.pageIsVisible = true
        XCTAssertTrue(page.pageIsVisible)
        page.pageIsVisible = false
        XCTAssertFalse(page.pageIsVisible)
    }

    /// Switching asks the project controller, by a notification, to show the page
    func testSwitchingToThePage() {
        let page = makePage()
        let posted = notifications(.IFSwitchToPage, from: page) {
            page.switchToPage()
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertEqual(posted.first?.userInfo as? [String: String], ["Identifier": "IFPage"])
    }

    func testSwitchingToAnotherPage() {
        let page = makePage()
        let posted = notifications(.IFSwitchToPage, from: page) {
            page.switchToPage(withIdentifier: "IFSourcePage", fromPage: "IFIndexPage")
            page.switchToPage(withIdentifier: "IFSkeinPage", fromPage: nil)
        }
        XCTAssertEqual(posted.map { $0.userInfo as? [String: String] },
                       [["Identifier": "IFSourcePage", "OldPageIdentifier": "IFIndexPage"],
                        ["Identifier": "IFSkeinPage"]])
    }

    func testToolbarCellsHaveUpdated() {
        let page = makePage()
        let posted = notifications(.IFUpdatePageBarCells, from: page) {
            page.toolbarCellsHaveUpdated()
        }
        XCTAssertEqual(posted.count, 1)
        XCTAssertNil(posted.first?.userInfo)
    }

    /// The history is a proxy for the recorder's event, aimed at the page, or nil without an event
    func testHistory() throws {
        let page = makePage()
        let recorder = Recorder()
        page.recorder = recorder
        XCTAssertTrue(page.recorder === recorder)
        XCTAssertNil(page.history)

        let event = IFHistoryEvent(object: NSNull())
        recorder.historyEvent = event
        let history = try XCTUnwrap(page.history as AnyObject?)
        XCTAssertTrue(event.target as AnyObject? === page)

        // What's sent to the history is recorded, and sent to the page when the event is replayed, as the pane
        // does for Back and Forward. Objective-C sends it to an id, which unsafeBitCast does here.
        unsafeBitCast(history, to: IFPage.self).toolbarCellsHaveUpdated()
        XCTAssertNil(event.target)
        let posted = notifications(.IFUpdatePageBarCells, from: page) {
            event.replay()
        }
        XCTAssertEqual(posted.count, 1)
    }

    /// The recorder isn't kept by the page
    func testTheRecorderIsWeak() {
        let page = makePage()
        autoreleasepool {
            let recorder = Recorder()
            page.recorder = recorder
            XCTAssertTrue(page.recorder === recorder)
        }
        XCTAssertNil(page.recorder)
    }

    /// The page's own actions do nothing, for the pages to override
    func testActions() {
        let page = makePage()
        page.didSwitchToPage()
        page.didSwitchAwayFromPage()
        page.willClose()
        XCTAssertFalse(page.pageIsVisible)
    }
}
