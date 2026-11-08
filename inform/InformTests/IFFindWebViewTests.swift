//
//  IFFindWebViewTests.swift
//  InformTests
//

import XCTest
import WebKit

final class IFFindWebViewTests: XCTestCase {

    /// Tells a test when its web view has finished loading the page
    private final class LoadWaiter: NSObject, WKNavigationDelegate {
        let loaded: XCTestExpectation

        init(_ loaded: XCTestExpectation) {
            self.loaded = loaded
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded.fulfill()
        }
    }

    private let caseInsensitive = IFFindType(rawValue: IFFindType.contains.rawValue
                                                       | IFFindType.caseInsensitive.rawValue)!

    /// A web view showing a page with the given body, which keeps what it stores in memory
    private func makeWebView(body: String) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: configuration)
        let waiter = LoadWaiter(expectation(description: "page loaded"))
        webView.navigationDelegate = waiter
        webView.loadHTMLString("<html><body>\(body)</body></html>", baseURL: nil)
        withExtendedLifetime(waiter) {
            waitForExpectations(timeout: 10)
        }
        webView.navigationDelegate = nil
        return webView
    }

    private func findNext(_ match: String, _ type: IFFindType, in webView: WKWebView) -> Bool {
        let finished = expectation(description: "find finished")
        var found = false
        webView.findNextMatch(match, of: type) { result in
            found = result
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return found
    }

    private func findPrevious(_ match: String, _ type: IFFindType, in webView: WKWebView) -> Bool {
        let finished = expectation(description: "find finished")
        var found = false
        webView.findPreviousMatch(match, of: type) { result in
            found = result
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return found
    }

    private func selection(in webView: WKWebView) -> String? {
        let finished = expectation(description: "selection read")
        var selected: String?
        webView.currentSelectionForFind { result in
            selected = result
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return selected
    }

    private func run(_ script: String, in webView: WKWebView) -> Any? {
        let finished = expectation(description: "script run")
        var value: Any?
        webView.evaluateJavaScript(script) { result, error in
            XCTAssertNil(error)
            value = result
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return value
    }

    /// The id of the element holding the start of the page's selection
    private func selectedElement(in webView: WKWebView) -> String? {
        return run("window.getSelection().anchorNode.parentNode.id", in: webView) as? String
    }

    func testFindingTheNextMatch() {
        let webView = makeWebView(body: "<p>The quick brown fox</p>")
        XCTAssertTrue(findNext("quick", .contains, in: webView))
        XCTAssertEqual(selection(in: webView), "quick")
        XCTAssertFalse(findNext("zebra", .contains, in: webView))
    }

    func testFindingThePreviousMatch() {
        let webView = makeWebView(body: "<p>The quick brown fox</p>")
        XCTAssertTrue(findPrevious("fox", .contains, in: webView))
        XCTAssertEqual(selection(in: webView), "fox")
        XCTAssertFalse(findPrevious("zebra", .contains, in: webView))
    }

    /// Finding matches case unless the type says not to
    func testCase() {
        let webView = makeWebView(body: "<p>The quick brown fox</p>")
        XCTAssertFalse(findNext("QUICK", .contains, in: webView))
        XCTAssertFalse(findPrevious("FOX", .contains, in: webView))
        XCTAssertTrue(findNext("QUICK", caseInsensitive, in: webView))
        XCTAssertEqual(selection(in: webView), "quick")
        XCTAssertTrue(findPrevious("FOX", caseInsensitive, in: webView))
        XCTAssertEqual(selection(in: webView), "fox")
    }

    /// Each find starts from the last match, and goes round past either end of the page
    func testFindingGoesOnFromTheLastMatchAndWraps() {
        let webView = makeWebView(body: "<p><span id=\"a\">cat</span> and <span id=\"b\">cat</span></p>")
        XCTAssertTrue(findNext("cat", .contains, in: webView))
        XCTAssertEqual(selectedElement(in: webView), "a")
        XCTAssertTrue(findNext("cat", .contains, in: webView))
        XCTAssertEqual(selectedElement(in: webView), "b")
        XCTAssertTrue(findNext("cat", .contains, in: webView))
        XCTAssertEqual(selectedElement(in: webView), "a")
        XCTAssertTrue(findPrevious("cat", .contains, in: webView))
        XCTAssertEqual(selectedElement(in: webView), "b")
        XCTAssertTrue(findPrevious("cat", .contains, in: webView))
        XCTAssertEqual(selectedElement(in: webView), "a")
    }

    /// The completion handlers can be left out
    func testFindingWithoutCompletionHandlers() {
        let webView = makeWebView(body: "<p>The quick brown fox</p>")
        webView.findNextMatch("quick", of: .contains, completionHandler: nil)
        webView.findPreviousMatch("fox", of: .contains, completionHandler: nil)
        XCTAssertTrue(findNext("brown", .contains, in: webView))
    }

    /// Only plain text can be found: the find controller asks without the case flag
    func testFindTypes() {
        let webView = WKWebView()
        XCTAssertTrue(webView.canUse(.contains))
        XCTAssertFalse(webView.canUse(.beginsWith))
        XCTAssertFalse(webView.canUse(.completeWord))
        XCTAssertFalse(webView.canUse(.regexp))
        XCTAssertFalse(webView.canUse(.invalidType))
        XCTAssertFalse(webView.canUse(caseInsensitive))
    }

    func testCurrentSelection() {
        let webView = makeWebView(body: "<p>The <span id=\"b\">quick brown</span> fox</p>")
        XCTAssertEqual(selection(in: webView), "")
        _ = run("""
            var range = document.createRange();
            range.selectNodeContents(document.getElementById("b"));
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
            """, in: webView)
        XCTAssertEqual(selection(in: webView), "quick brown")
    }

    /// The find controller takes anything that responds to findNextMatch:ofType:completionHandler: as a delegate,
    /// and asks before using the optional methods
    func testAWebViewIsAFindDelegate() {
        let webView = WKWebView()
        XCTAssertTrue(webView.conforms(to: IFFindDelegate.self))
        XCTAssertTrue(webView.responds(to: #selector(IFFindDelegate.findNextMatch(_:of:completionHandler:))))
        XCTAssertTrue(webView.responds(to: #selector(IFFindDelegate.findPreviousMatch(_:of:completionHandler:))))
        XCTAssertTrue(webView.responds(to: #selector(IFFindDelegate.canUse(_:))))
        XCTAssertTrue(webView.responds(to: #selector(IFFindDelegate.currentSelectionForFind(completionHandler:))))
        XCTAssertFalse(webView.responds(to: #selector(IFFindDelegate.findAllMatches(_:of:in:in:withIdentifier:))))
        XCTAssertFalse(webView.responds(to: #selector(IFFindDelegate.replaceFound(with:))))
    }
}
