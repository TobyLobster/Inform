//
//  IFFindWebViewTests.swift
//  InformTests
//

import XCTest
import WebKit

@MainActor
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
        return makeWebView(html: "<html><body>\(body)</body></html>")
    }

    /// A web view showing a page with the given HTML, which keeps what it stores in memory
    private func makeWebView(html: String) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: configuration)
        let waiter = LoadWaiter(expectation(description: "page loaded"))
        webView.navigationDelegate = waiter
        webView.loadHTMLString(html, baseURL: nil)
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

    /// Selects a match found by Find in Files in the context given, where the match is marked by brackets
    private func selectMatch(_ marked: String, after anchor: String? = nil, in webView: WKWebView) -> Bool {
        let start = (marked as NSString).range(of: "[")
        let end = (marked as NSString).range(of: "]")
        let range = NSRange(location: start.location, length: end.location - start.location - 1)
        let context = marked.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        return selectMatch(range, inContext: context, after: anchor, in: webView)
    }

    private func selectMatch(_ range: NSRange,
                             inContext context: String,
                             after anchor: String?,
                             in webView: WKWebView) -> Bool {
        let finished = expectation(description: "match selected")
        var selected = false
        webView.selectMatch(at: range, inContext: context, afterAnchor: anchor) { result in
            selected = result
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        return selected
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

    // MARK: - Find in Files

    /// A match found by Find in Files is selected where its context is, not where its text first is
    func testSelectingAMatchInItsContext() {
        let webView = makeWebView(body: "<p id=\"a\">A cat sat.</p><p id=\"b\">The cat ran.</p>")

        XCTAssertTrue(selectMatch("The [cat] ran.", in: webView))

        XCTAssertEqual(selection(in: webView), "cat")
        XCTAssertEqual(selectedElement(in: webView), "b")
    }

    /// The same line can be in more than one place, so the match is the first after its anchor, given by id or name
    func testSelectingAMatchAfterItsAnchor() {
        let webView = makeWebView(body: "<a id=\"c1\"></a><p id=\"x\">(About the ghost.)</p>"
                                      + "<a id=\"c2\"></a><p id=\"y\">(About the ghost.)</p>"
                                      + "<a name=\"c3\"></a><p id=\"z\">(About the ghost.)</p>")

        XCTAssertTrue(selectMatch("(About the [ghost].)", after: "c2", in: webView))
        XCTAssertEqual(selectedElement(in: webView), "y")
        XCTAssertTrue(selectMatch("(About the [ghost].)", after: "c3", in: webView))
        XCTAssertEqual(selectedElement(in: webView), "z")
        XCTAssertTrue(selectMatch("(About the [ghost].)", in: webView))
        XCTAssertEqual(selectedElement(in: webView), "x")
        XCTAssertTrue(selectMatch("(About the [ghost].)", after: "no-such-anchor", in: webView))
        XCTAssertEqual(selectedElement(in: webView), "x")
    }

    /// The search's text has spaces where the page's tags were, and the page has whitespace that the search's doesn't,
    /// so the two are compared without it, and the match can go across elements
    func testSelectingAMatchComparesTheTextWithoutWhitespace() {
        let body = "<table><tr><td>one</td><td id=\"t\">two <b>c</b>ats</td></tr></table>\n   <p>\n  other cats</p>"
        let text = IFDocParser(html: body).plainText as NSString
        let location = text.range(of: "cats").location
        var range = NSRange()
        let context = IFFindInFiles.getContextFromText(text as String,
                                                       withLocation: UInt(location),
                                                       andLength: 4,
                                                       findingContextRange: &range)
        XCTAssertEqual(context, "one two cats")
        let webView = makeWebView(body: body)

        XCTAssertTrue(selectMatch(range, inContext: context, after: nil, in: webView))

        XCTAssertEqual(selection(in: webView), "cats")
        let cell = run("window.getSelection().anchorNode.parentElement.closest(\"td\").id", in: webView) as? String
        XCTAssertEqual(cell, "t")
    }

    /// Where the context isn't in the page, as when the search left out some of its text, the first of the match's
    /// text after the anchor is selected
    func testSelectingAMatchWhoseContextIsntInThePage() {
        let webView = makeWebView(body: "<p id=\"a\">A cat.</p><a id=\"c1\"></a><p id=\"b\">The cat ran.</p>")

        XCTAssertTrue(selectMatch("The [cat] sat.", after: "c1", in: webView))

        XCTAssertEqual(selection(in: webView), "cat")
        XCTAssertEqual(selectedElement(in: webView), "b")
    }

    /// A match that isn't in the page leaves the selection as it was
    func testSelectingAMatchThatIsntInThePage() {
        let webView = makeWebView(body: "<p id=\"a\">A cat.</p><a id=\"c1\"></a><p id=\"b\">A dog.</p>")
        XCTAssertTrue(findNext("dog", .contains, in: webView))

        XCTAssertFalse(selectMatch("A [cat].", after: "c1", in: webView))
        XCTAssertFalse(selectMatch("Nothing [] here", in: webView))

        XCTAssertEqual(selection(in: webView), "dog")
    }

    /// Text in the page's scripts and styles isn't looked in
    func testSelectingAMatchLeavesOutScriptsAndStyles() {
        let webView = makeWebView(html: "<html><head><style>.cat {}</style></head><body>"
                                      + "<script>var cat;</script><p id=\"p\">cat</p></body></html>")

        XCTAssertTrue(selectMatch("[cat]", in: webView))

        XCTAssertEqual(selectedElement(in: webView), "p")
    }

    /// The match is scrolled into view
    func testSelectingAMatchScrollsItIntoView() throws {
        let webView = makeWebView(body: "<div style=\"height: 5000px\"></div><p id=\"p\">The cat.</p>")

        XCTAssertTrue(selectMatch("The [cat].", in: webView))

        let scrolled = try XCTUnwrap(run("window.scrollY", in: webView) as? Double)
        XCTAssertGreaterThan(scrolled, 4000)
    }

    /// In a page of the documentation, a match in the second of two code extracts that start the same is selected
    /// there, as Find in Files finds it
    func testSelectingAMatchInAPageOfTheDocumentation() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "WI_11_3", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        let parser = IFDocParser(html: html)
        let code = try XCTUnwrap(parser.codeInfo.first { $0.anchorTag == "code612" })
        let text = parser.plainText as NSString
        let location = text.range(of: "paranormal", range: code.range).location
        XCTAssertNotEqual(location, NSNotFound)
        var range = NSRange()
        let context = IFFindInFiles.getContextFromText(text as String,
                                                       withLocation: UInt(location),
                                                       andLength: 10,
                                                       findingContextRange: &range)
        let webView = makeWebView(html: html)

        XCTAssertTrue(selectMatch(range, inContext: context, after: "code612", in: webView))

        XCTAssertEqual(selection(in: webView), "paranormal")
        let anchor = run("""
            window.getSelection().anchorNode.parentElement.closest("blockquote").querySelector("a").id
            """, in: webView) as? String
        XCTAssertEqual(anchor, "code612")
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
