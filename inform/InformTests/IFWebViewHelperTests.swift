//
//  IFWebViewHelperTests.swift
//  InformTests
//

import WebKit
import XCTest

final class IFWebViewHelperTests: XCTestCase {

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

    /// Loads a URL through the helper's handler for the app's own URL schemes.
    private func load(_ url: String) -> RecordingTask {
        let helper: IFWebViewHelper = IFWebViewHelper(projectController: nil, with: nil)
        let task = RecordingTask(url)
        helper.webView(WKWebView(frame: .zero, configuration: WKWebViewConfiguration()), start: task)
        return task
    }

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

    /// The tests' web views keep their website data in memory, not in the user's Library.
    func testWebViewsKeepTheirDataInMemory() {
        let helper: IFWebViewHelper = IFWebViewHelper(projectController: nil, with: nil)
        let webView = helper.createWebView(withFrame: .zero)
        XCTAssertFalse(webView.configuration.websiteDataStore.isPersistent)
    }
}
