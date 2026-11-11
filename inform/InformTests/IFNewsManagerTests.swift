//
//  IFNewsManagerTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests leave the user's own alone
private final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func string(forKey defaultName: String) -> String? {
        return values[defaultName] as? String
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

/// Answers every request as the test asks, and records what was asked for
private final class FakeNewsServer: URLProtocol {
    /// The status and body to answer with, or the error to fail with
    nonisolated(unsafe) static var answer: Result<(status: Int, body: Data), Error> = .success((200, Data()))
    nonisolated(unsafe) private(set) static var requests: [URL] = []

    static func reset() {
        answer = .success((200, Data()))
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let url = request.url!
        FakeNewsServer.requests.append(url)
        switch FakeNewsServer.answer {
        case .success(let (status, body)):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}

@MainActor
final class IFNewsManagerTests: XCTestCase, @unchecked Sendable {

    private let calendarURL = URL(string: "https://iftechfoundation.org/calendar/cal.txt")!
    private let calendar = "2026-11-21\t2026-11-22\tIFComp results\thttps://ifcomp.org/\n"

    private var defaults: MemoryDefaults!
    private var session: URLSession!

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            defaults = MemoryDefaults(suiteName: nil)
            FakeNewsServer.reset()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FakeNewsServer.self]
            session = URLSession(configuration: configuration)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            session.invalidateAndCancel()
            super.tearDown()
        }
    }

    private struct News {
        var news: String?
        var response: URLResponse?
        var error: Error?
        var onMainThread: Bool
    }

    /// What the completion handler was given, which it's given on another thread
    private final class Result: @unchecked Sendable {
        var news = News(news: nil, response: nil, error: nil, onMainThread: true)
    }

    /// Gets the news from a new manager, waiting for it
    private func getNews() -> News {
        let manager = IFNewsManager(defaults: defaults, session: session)
        let done = expectation(description: "news")
        let result = Result()
        manager.getNewsWithCompletionHandler { news, response, error in
            result.news = News(news: news, response: response, error: error, onMainThread: Thread.isMainThread)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return result.news
    }

    private func keep(_ news: String, from date: Date) {
        defaults.set(date, forKey: "newsTimestamp")
        defaults.set(news, forKey: "newsString")
    }

    private var keptNews: String? {
        return defaults.string(forKey: "newsString")
    }

    private var keptDate: Date? {
        return defaults.object(forKey: "newsTimestamp") as? Date
    }

    private func days(_ count: Double) -> TimeInterval {
        return count * 24 * 60 * 60
    }

    // MARK: - Today's news

    /// News downloaded earlier today is given again, without downloading it
    func testTodaysNewsIsntDownloadedAgain() {
        let today = Date()
        keep("Earlier today", from: today)

        let result = getNews()
        XCTAssertEqual(result.news, "Earlier today")
        XCTAssertNil(result.response)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.onMainThread)
        XCTAssertEqual(FakeNewsServer.requests, [])
        XCTAssertEqual(keptDate, today)
    }

    func testOlderNewsIsDownloadedAgain() {
        keep("Two days ago", from: Date(timeIntervalSinceNow: -days(2)))
        FakeNewsServer.answer = .success((200, Data(calendar.utf8)))

        let before = Date()
        let result = getNews()
        let after = Date()
        XCTAssertEqual(result.news, calendar)
        XCTAssertEqual(result.response?.url, calendarURL)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.onMainThread)
        XCTAssertEqual(FakeNewsServer.requests, [calendarURL])

        // It's kept, with when it was asked for
        XCTAssertEqual(keptNews, calendar)
        if let keptDate {
            XCTAssertTrue(keptDate >= before && keptDate <= after, "\(keptDate)")
        } else {
            XCTFail("No date kept")
        }
    }

    /// Only news from today counts, so news kept from a later day is downloaded again too
    func testLaterNewsIsDownloadedAgain() {
        keep("Two days from now", from: Date(timeIntervalSinceNow: days(2)))
        FakeNewsServer.answer = .success((200, Data(calendar.utf8)))

        XCTAssertEqual(getNews().news, calendar)
        XCTAssertEqual(keptNews, calendar)
    }

    func testTheFirstNewsIsDownloaded() {
        FakeNewsServer.answer = .success((200, Data(calendar.utf8)))

        XCTAssertEqual(getNews().news, calendar)
        XCTAssertEqual(FakeNewsServer.requests, [calendarURL])
        XCTAssertEqual(keptNews, calendar)
        XCTAssertNotNil(keptDate)
    }

    /// News kept without its text gives none
    func testTodaysDateWithNoNews() {
        defaults.set(Date(), forKey: "newsTimestamp")

        let result = getNews()
        XCTAssertNil(result.news)
        XCTAssertEqual(FakeNewsServer.requests, [])
    }

    // MARK: - Failures

    /// A failed download gives no news, and keeps what there was
    func testAFailedDownload() {
        let twoDaysAgo = Date(timeIntervalSinceNow: -days(2))
        keep("Two days ago", from: twoDaysAgo)
        FakeNewsServer.answer = .failure(URLError(.notConnectedToInternet))

        let result = getNews()
        XCTAssertEqual(result.news, "")
        XCTAssertNil(result.response)
        XCTAssertEqual((result.error as NSError?)?.domain, NSURLErrorDomain)
        XCTAssertEqual((result.error as NSError?)?.code, NSURLErrorNotConnectedToInternet)
        XCTAssertFalse(result.onMainThread)
        XCTAssertEqual(keptNews, "Two days ago")
        XCTAssertEqual(keptDate, twoDaysAgo)
    }

    /// A server's error page isn't news: it gives none, and keeps what there was, so the news is asked for again
    func testAServerError() {
        let twoDaysAgo = Date(timeIntervalSinceNow: -days(2))
        keep("Two days ago", from: twoDaysAgo)
        FakeNewsServer.answer = .success((404, Data("<html>Not Found</html>".utf8)))

        let result = getNews()
        XCTAssertEqual(result.news, "")
        XCTAssertEqual((result.response as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.onMainThread)
        XCTAssertEqual(keptNews, "Two days ago")
        XCTAssertEqual(keptDate, twoDaysAgo)
    }

    /// News that isn't UTF-8 is no news, and that's kept for the day
    func testNewsThatIsntUTF8() {
        FakeNewsServer.answer = .success((200, Data([0x4E, 0x65, 0xFF, 0x77, 0x73])))

        XCTAssertEqual(getNews().news, "")
        XCTAssertEqual(keptNews, "")
        XCTAssertNotNil(keptDate)
    }

    // MARK: - The scheme handler

    func testEachManagerHasItsOwnSchemeHandler() {
        let first = IFNewsManager(defaults: defaults, session: session)
        let second = IFNewsManager(defaults: defaults, session: session)
        XCTAssertNotIdentical(first.newsSchemeHandler, second.newsSchemeHandler)
    }
}
