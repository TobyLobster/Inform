//
//  IFNewsCustomSchemeHandlerTests.swift
//  InformTests
//

import WebKit
import XCTest

/// A URL scheme task that records what the handler tells it
private final class RecordingSchemeTask: NSObject, WKURLSchemeTask {
    let request: URLRequest
    private(set) var responses: [URLResponse] = []
    private(set) var data = Data()
    private(set) var finished = false
    private(set) var errors: [Error] = []

    init(_ url: String) {
        request = URLRequest(url: URL(string: url)!)
    }

    func didReceive(_ response: URLResponse) {
        responses.append(response)
    }

    func didReceive(_ data: Data) {
        self.data.append(data)
    }

    func didFinish() {
        finished = true
    }

    func didFailWithError(_ error: Error) {
        errors.append(error)
    }

    /// The code of the one error it was given, if that's all it was told
    var errorCode: Int? {
        guard errors.count == 1, responses.isEmpty, data.isEmpty, !finished else {
            return nil
        }
        let error = errors[0] as NSError
        XCTAssertEqual(error.domain, NSURLErrorDomain)
        return error.code
    }
}

final class IFNewsCustomSchemeHandlerTests: XCTestCase {

    private static let webView = WKWebView(frame: .zero)

    /// Asks a new handler for a URL
    private func load(_ url: String) -> RecordingSchemeTask {
        let task = RecordingSchemeTask(url)
        IFNewsCustomSchemeHandler().webView(IFNewsCustomSchemeHandlerTests.webView, start: task)
        return task
    }

    private func resource(_ path: String) -> Data? {
        return FileManager.default.contents(atPath: Bundle.main.resourcePath! + "/" + path)
    }

    /// Checks that the task was given one response, with the data and type expected, and finished
    private func checkLoaded(_ task: RecordingSchemeTask,
                             _ expected: Data?,
                             type: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        XCTAssertEqual(task.errors.count, 0, file: file, line: line)
        XCTAssertEqual(task.responses.count, 1, file: file, line: line)
        XCTAssertTrue(task.finished, file: file, line: line)
        XCTAssertNotNil(expected, file: file, line: line)
        XCTAssertEqual(task.data, expected, file: file, line: line)

        guard let response = task.responses.first else {
            return
        }
        XCTAssertEqual(response.url, task.request.url, file: file, line: line)
        XCTAssertEqual(response.mimeType, type, file: file, line: line)
        XCTAssertEqual(response.expectedContentLength, Int64(task.data.count), file: file, line: line)
        XCTAssertNil(response.textEncodingName, file: file, line: line)
    }

    // MARK: - Files

    /// The news page's logo
    func testAFileInAFolderOfTheResources() {
        checkLoaded(load("inform:///App/Welcome/iftf-logo.svg"), resource("App/Welcome/iftf-logo.svg"),
                    type: "image/svg+xml")
    }

    func testALocalisedFile() {
        checkLoaded(load("inform:/AdviceCredits.html"), resource("en.lproj/AdviceCredits.html"), type: "text/html")
    }

    func testTheTypeComesFromTheExtension() {
        checkLoaded(load("inform:/InformCoreVersion.txt"), resource("InformCoreVersion.txt"), type: "text/plain")
        checkLoaded(load("inform:/messages_to_objc.js"), resource("messages_to_objc.js"), type: "text/javascript")
    }

    /// A file with no type is given as HTML
    func testAFileWithNoExtension() {
        checkLoaded(load("inform:/Library/Standard"), resource("Library/Standard"), type: "text/html")
    }

    /// An image that's a file of its own is given as it is, not as an image from the asset catalog
    func testAnImageFile() {
        checkLoaded(load("inform:/Welcome%20Background.png"), resource("Welcome Background.png"), type: "image/png")
    }

    func testTheSchemeIsntCaseSensitive() {
        checkLoaded(load("INFORM:/AdviceCredits.html"), resource("en.lproj/AdviceCredits.html"), type: "text/html")
    }

    // MARK: - Images in the asset catalog

    /// An image that's only in the asset catalog is given as TIFF, whatever the extension asked for
    func testAnImageInTheAssetCatalog() {
        let tiff = NSImage(named: "White")?.tiffRepresentation
        checkLoaded(load("inform:/White.png"), tiff, type: "image/tiff")
        checkLoaded(load("inform:/White.jpg"), tiff, type: "image/tiff")
    }

    /// Asking for the image at twice the size gives the same image
    func testAnImageAtTwiceTheSize() {
        checkLoaded(load("inform:/White@2x.png"), NSImage(named: "White")?.tiffRepresentation, type: "image/tiff")
    }

    // MARK: - Failures

    func testAMissingFile() {
        XCTAssertEqual(load("inform:/NoSuchFile.html").errorCode, NSURLErrorFileDoesNotExist)
        XCTAssertEqual(load("inform:/App/NoSuchFile.html").errorCode, NSURLErrorFileDoesNotExist)
    }

    /// A path that goes up out of the resources folder, as NSURL gives for a percent-encoded slash, gets nothing
    func testNothingOutsideTheResources() {
        XCTAssertEqual(load("inform:/..%2FInfo.plist").errorCode, NSURLErrorNoPermissionsToReadFile)
        XCTAssertEqual(load("inform:/App%2F..%2F..%2FInfo.plist").errorCode, NSURLErrorNoPermissionsToReadFile)
        XCTAssertEqual(load("inform:/../Info.plist").errorCode, NSURLErrorNoPermissionsToReadFile)

        // Going up and back down again is refused too
        XCTAssertEqual(load("inform:/App%2F..%2FAdviceCredits.html").errorCode, NSURLErrorNoPermissionsToReadFile)
    }

    func testAFolder() {
        XCTAssertEqual(load("inform:/bg_images").errorCode, NSURLErrorFileIsDirectory)
    }

    /// With no path, it's the resources folder itself
    func testNoPath() {
        XCTAssertEqual(load("inform:/").errorCode, NSURLErrorFileIsDirectory)

        // NSURL gives these no path at all
        XCTAssertEqual(load("inform:").errorCode, NSURLErrorFileIsDirectory)
        XCTAssertEqual(load("inform:AdviceCredits.html").errorCode, NSURLErrorFileIsDirectory)
    }

    /// Another scheme gets no answer at all
    func testAnotherScheme() {
        let task = load("https://example.com/AdviceCredits.html")
        XCTAssertTrue(task.responses.isEmpty)
        XCTAssertTrue(task.data.isEmpty)
        XCTAssertTrue(task.errors.isEmpty)
        XCTAssertFalse(task.finished)
    }

    func testStoppingATaskDoesNothing() {
        let task = RecordingSchemeTask("inform:/AdviceCredits.html")
        IFNewsCustomSchemeHandler().webView(IFNewsCustomSchemeHandlerTests.webView, stop: task)
        XCTAssertTrue(task.responses.isEmpty)
        XCTAssertTrue(task.errors.isEmpty)
        XCTAssertFalse(task.finished)
    }
}
