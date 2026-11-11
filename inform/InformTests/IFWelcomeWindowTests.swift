//
//  IFWelcomeWindowTests.swift
//  InformTests
//

import XCTest
import WebKit

/// The kinds of row in the welcome window's lists, numbered as the app's `IFRecentFileType` numbers them,
/// as the tests can't see that Swift enum
private enum RowType: Int {
    case file, open, createProject, createExtension, copySample, websiteLink, saveEPubs
}

/// A row of one of the welcome window's lists, read from what the list's data source gives for it
private struct Row: Equatable {
    let title: String?
    let url: URL?
    let type: RowType?
    let hasImage: Bool
}

/// The window doesn't have three lists
private struct WrongNumberOfLists: Error {
    let count: Int
}

/// A progress indicator that remembers whether it was told to animate
private final class ProgressSpy: NSProgressIndicator {
    var animating = false

    override func startAnimation(_ sender: Any?) {
        animating = true
    }

    override func stopAnimation(_ sender: Any?) {
        animating = false
    }
}

/// A navigation of the given type to the given URL, as WebKit only makes them for its own web views
private final class Navigation: WKNavigationAction {
    private let type: WKNavigationType
    private let url: URL

    init(_ type: WKNavigationType, to url: URL) {
        self.type = type
        self.url = url
        super.init()
    }

    override var navigationType: WKNavigationType {
        return type
    }

    override var request: URLRequest {
        return URLRequest(url: url)
    }
}

/// What the window decided for a navigation
private final class PolicyRecorder {
    var policy: WKNavigationActionPolicy?
}

/// The welcome window, from a controller of its own rather than the shared one, with its window loaded but
/// never shown. Showing it would download the news and keep it in the user's defaults, and most of its rows
/// and links open panels, windows or the browser, so the tests stop short of those.
@MainActor
final class IFWelcomeWindowTests: XCTestCase, @unchecked Sendable {
    private var controller: IFWelcomeWindow!
    private var savedTimeZone: TimeZone!

    override func setUp() {
        MainActor.assumeIsolated {
            savedTimeZone = NSTimeZone.default
            controller = IFWelcomeWindow(windowNibName: "Launcher")
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            controller = nil
            NSTimeZone.default = savedTimeZone
        }
    }

    /// Every view of the given kind in the view and the views inside it, in the nib's order
    private func views<V: NSView>(_ kind: V.Type, in view: NSView) -> [V] {
        let own = (view as? V).map { [$0] } ?? []
        return own + view.subviews.flatMap { views(kind, in: $0) }
    }

    /// The window's buttons that send the given action
    private func buttons(sending action: Selector) throws -> [NSButton] {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return views(NSButton.self, in: contentView).filter { $0.action == action }
    }

    /// The window's lists: the recent documents, the documents it can create, and the samples
    private func lists() throws -> (recent: NSTableView, create: NSTableView, samples: NSTableView) {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tables = views(NSTableView.self, in: contentView)
        guard tables.count == 3 else {
            throw WrongNumberOfLists(count: tables.count)
        }
        return (tables[0], tables[1], tables[2])
    }

    /// The rows a list shows, as its data source gives them
    private func rows(of table: NSTableView) throws -> [Row] {
        let dataSource = try XCTUnwrap(table.dataSource)
        let count = try XCTUnwrap(dataSource.numberOfRows?(in: table))
        return try (0..<count).map { row in
            let info = try XCTUnwrap(dataSource.tableView?(table, objectValueFor: nil, row: row) as? NSObject)
            return Row(title: info.value(forKey: "title") as? String,
                       url: info.value(forKey: "url") as? URL,
                       type: (info.value(forKey: "type") as? Int).flatMap(RowType.init(rawValue:)),
                       hasImage: info.value(forKey: "image") != nil)
        }
    }

    /// A sample project in the app
    private func sample(_ name: String) throws -> URL {
        let resources = try XCTUnwrap(Bundle.main.resourcePath) as NSString
        return URL(fileURLWithPath: resources.appendingPathComponent("App/Samples/\(name)"), isDirectory: true)
    }

    /// The dates of an event in the news, as the news page shows them: the days the calendar gives
    private func dates(_ start: String, _ end: String) throws -> String {
        let calendarDates = ISO8601DateFormatter()
        calendarDates.formatOptions = .withFullDate

        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return formatter.string(from: try XCTUnwrap(calendarDates.date(from: start)),
                                to: try XCTUnwrap(calendarDates.date(from: end)))
    }

    /// The rows of the news page for the given news: what the page has in place of its template's marker
    private func newsRows(_ news: String?) throws -> String {
        let templateURL = try XCTUnwrap(Bundle.main.url(forResource: "NewsTemplate", withExtension: "html"))
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let parts = template.components(separatedBy: "<!-- CONTENT HERE -->")
        XCTAssertEqual(parts.count, 2)

        let page = try XCTUnwrap(controller.newsPage(forNews: news))
        let before = try XCTUnwrap(parts.first)
        let after = try XCTUnwrap(parts.last)
        XCTAssertTrue(page.hasPrefix(before))
        XCTAssertTrue(page.hasSuffix(after))
        let length = page.utf16.count - before.utf16.count - after.utf16.count
        guard length >= 0 else {
            return page
        }
        return (page as NSString).substring(with: NSRange(location: before.utf16.count, length: length))
    }

    /// The policy the window gives a navigation in one of its web views
    private func policy(for navigation: WKNavigationAction) -> WKNavigationActionPolicy? {
        // Nothing the web view does is kept
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        let recorder = PolicyRecorder()
        (controller as WKNavigationDelegate).webView?(webView, decidePolicyFor: navigation) { policy in
            recorder.policy = policy
        }
        return recorder.policy
    }

    func testTheSharedWelcomeWindowIsMadeOnce() {
        XCTAssertTrue(IFWelcomeWindow.shared() === IFWelcomeWindow.shared())
    }

    func testTheWindowIsCentredOnItsScreenAndDoesntFloat() throws {
        let window = try XCTUnwrap(controller.window)
        let screen = try XCTUnwrap(window.screen)
        XCTAssertEqual(window.frame.midX, screen.frame.midX, accuracy: 1)
        XCTAssertEqual(window.frame.midY, screen.frame.midY, accuracy: 1)
        XCTAssertEqual(window.level, .normal)
        XCTAssertFalse(window.isVisible)

        // Clicking the banner shows its other image, rather than darkening it
        let banner = try XCTUnwrap(buttons(sending: #selector(IFWelcomeWindow.clickImage(_:))).first)
        XCTAssertEqual((banner.cell as? NSButtonCell)?.highlightsBy, .contentsCellMask)
    }

    func testTheRecentListHasTheRecentDocumentsThenOpen() throws {
        let recentURLs = NSDocumentController.shared.recentDocumentURLs.prefix(8)
        let expected = recentURLs.map { Row(title: $0.lastPathComponent, url: $0, type: .file, hasImage: true) }
            + [Row(title: IFUtility.localizedString("Open..."), url: nil, type: .open, hasImage: true)]
        XCTAssertEqual(try rows(of: lists().recent), expected)
    }

    func testTheCreateListMakesAProjectAnExtensionOrEBooks() throws {
        XCTAssertEqual(try rows(of: lists().create), [
            Row(title: IFUtility.localizedString("Create Project..."), url: nil, type: .createProject, hasImage: true),
            Row(title: IFUtility.localizedString("Create Extension..."), url: nil, type: .createExtension, hasImage: true),
            Row(title: IFUtility.localizedString("Save Documentation as eBooks"), url: nil, type: .saveEPubs, hasImage: true),
        ])
    }

    func testTheSampleListCopiesTheSamplesOrLinksToIFDB() throws {
        let ifdb = "http://ifdb.tads.org/search?sortby=new&newSortBy.x=0&newSortBy.y=0&searchfor=tag%3A+i7+source+available"
        XCTAssertEqual(try rows(of: lists().samples), [
            Row(title: IFUtility.localizedString("Copy Onyx"), url: try sample("Onyx.inform"), type: .copySample, hasImage: true),
            Row(title: IFUtility.localizedString("Copy Disenchantment Bay"), url: try sample("Disenchantment Bay.inform"),
                type: .copySample, hasImage: true),
            Row(title: IFUtility.localizedString("Link to IFDB"), url: URL(string: ifdb), type: .websiteLink, hasImage: true),
        ])
    }

    func testTheSamplesAreInTheApp() throws {
        for name in ["Onyx.inform", "Disenchantment Bay.inform"] {
            var isFolder: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: try sample(name).path, isDirectory: &isFolder), name)
            XCTAssertTrue(isFolder.boolValue, name)
        }
    }

    func testEachRowShowsItsTitleAndImage() throws {
        let tables = try lists()
        for table in [tables.recent, tables.create, tables.samples] {
            let column = try XCTUnwrap(table.tableColumns.first)
            for (index, row) in try rows(of: table).enumerated() {
                // A copy of the column's cell, which the delegate fills in, as the table has it do before drawing
                let cell = try XCTUnwrap((column.dataCell as? NSCell)?.copy() as? NSCell)
                table.delegate?.tableView?(table, willDisplayCell: cell, for: column, row: index)
                XCTAssertEqual(cell.title, row.title)
                XCTAssertNotNil(cell.image, row.title ?? "")
            }
        }
    }

    func testAdviceShowsInPlaceOfTheListsUntilTheBannerIsClicked() throws {
        let recent = try lists().recent
        let adviceArea = try XCTUnwrap(controller.value(forKey: "webViewParent") as? NSView)
        let banner = try XCTUnwrap(buttons(sending: #selector(IFWelcomeWindow.clickImage(_:))).first)

        // The links to advice come after the seven links to websites, which open in the browser
        let adviceLinks = try buttons(sending: NSSelectorFromString("clickedWebLink:")).filter { $0.tag >= 7 }
        XCTAssertEqual(adviceLinks.map(\.tag).sorted(), [7, 8, 9, 10, 11])
        for link in adviceLinks {
            link.performClick(nil)
            XCTAssertTrue(recent.isHiddenOrHasHiddenAncestor, "\(link.tag)")
            XCTAssertFalse(adviceArea.isHidden, "\(link.tag)")

            banner.performClick(nil)
            XCTAssertFalse(recent.isHiddenOrHasHiddenAncestor, "\(link.tag)")
            XCTAssertTrue(adviceArea.isHidden, "\(link.tag)")
        }
    }

    /// The advice is shown in one web view, made once, though the window is shown again and again
    func testTheAdviceHasOneWebView() throws {
        _ = controller.window
        let adviceArea = try XCTUnwrap(controller.value(forKey: "webViewParent") as? NSView)
        XCTAssertEqual(views(WKWebView.self, in: adviceArea).count, 0)

        // As each time the window is shown, which isn't done, as it downloads the news
        for _ in 0..<3 {
            _ = controller.perform(NSSelectorFromString("addAdviceWebView"))
        }
        XCTAssertEqual(views(WKWebView.self, in: adviceArea).count, 1)
    }

    func testTheSpinnerTurnsWhileMaintenanceRuns() throws {
        _ = controller.window
        let spinner = ProgressSpy()
        controller.setValue(spinner, forKey: "backgroundProgress")

        for finished in [Notification.Name.IFCensusFinished, .IFCensusFinishedButDontUpdateExtensionsWebPage] {
            NotificationCenter.default.post(name: .IFMaintenanceTasksStarted, object: self)
            XCTAssertTrue(spinner.animating, finished.rawValue)
            NotificationCenter.default.post(name: finished, object: self)
            XCTAssertFalse(spinner.animating, finished.rawValue)
        }
    }

    func testFollowingALinkToAnInformPageStaysInTheWindow() throws {
        let url = try XCTUnwrap(URL(string: "inform:/AdviceCredits.html"))
        XCTAssertEqual(policy(for: Navigation(.linkActivated, to: url)), .allow)
    }

    func testOnlyLinksThatAreFollowedGoToTheBrowser() throws {
        let url = try XCTUnwrap(URL(string: "https://iftechfoundation.org/"))
        XCTAssertEqual(policy(for: Navigation(.other, to: url)), .allow)
    }

    func testTheNewsPageHasARowForEachEvent() throws {
        let news = "2026-11-14\t2026-11-16\tIFComp results\thttps://ifcomp.org/\r\n"
            + "2026-12-01\t2026-12-01\tSpeed IF\thttps://example.com/speed\r\n"
        XCTAssertEqual(try newsRows(news),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-16"))</td>"
                       + "<td><a href=\"https://ifcomp.org/\">IFComp results</a></td></tr>\n"
                       + "<tr><td>\(try dates("2026-12-01", "2026-12-01"))</td>"
                       + "<td><a href=\"https://example.com/speed\">Speed IF</a></td></tr>\n")
    }

    func testEventsAreOnTheCalendarsDaysWestOfGreenwich() throws {
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(try newsRows("2026-11-14\t2026-11-16\tIFComp results\thttps://ifcomp.org/"),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-16"))</td>"
                       + "<td><a href=\"https://ifcomp.org/\">IFComp results</a></td></tr>\n")
    }

    func testAnEventWithNoEndDateIsOnItsStartDate() throws {
        let row = "<tr><td>\(try dates("2026-11-14", "2026-11-14"))</td><td><a href=\"https://example.com/\">Meet-up</a></td></tr>\n"
        XCTAssertEqual(try newsRows("2026-11-14\t\tMeet-up\thttps://example.com/"), row)
        XCTAssertEqual(try newsRows("2026-11-14\tsoon\tMeet-up\thttps://example.com/"), row)
    }

    func testAnEventWhoseStartDateCantBeReadIsLeftOut() throws {
        let news = "soon\t2026-11-16\tMystery\thttps://example.com/mystery\n"
            + "2026-11-14\t\tMeet-up\thttps://example.com/"
        XCTAssertEqual(try newsRows(news),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-14"))</td><td><a href=\"https://example.com/\">Meet-up</a></td></tr>\n")
    }

    func testAnEventWithNoLinkLinksToNothing() throws {
        XCTAssertEqual(try newsRows("2026-11-14\t2026-11-14\tMeet-up"),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-14"))</td><td><a href=\"\">Meet-up</a></td></tr>\n")
    }

    func testLinesWithNoHeadlineAreLeftOut() throws {
        XCTAssertEqual(try newsRows("\n2026-11-14\t2026-11-16\n\n"), "")
    }

    func testNoNewsGivesNoRows() throws {
        XCTAssertEqual(try newsRows(nil), "")
        XCTAssertEqual(try newsRows(""), "")
    }

    func testHeadlinesAreEscaped() throws {
        XCTAssertEqual(try newsRows("2026-11-14\t\tTom & Jerry's \"<b>Show</b>\"\thttps://example.com/"),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-14"))</td><td><a href=\"https://example.com/\">"
                       + "Tom &amp; Jerry&#39;s &quot;&lt;b&gt;Show&lt;/b&gt;&quot;</a></td></tr>\n")
    }

    func testLinksAreEscaped() throws {
        XCTAssertEqual(try newsRows("2026-11-14\t\tMeet-up\thttps://example.com/?a=1&b=\"x\" onclick=\"alert(1)"),
                       "<tr><td>\(try dates("2026-11-14", "2026-11-14"))</td>"
                       + "<td><a href=\"https://example.com/?a=1&amp;b=&quot;x&quot; onclick=&quot;alert(1)\">Meet-up</a></td></tr>\n")
    }
}
