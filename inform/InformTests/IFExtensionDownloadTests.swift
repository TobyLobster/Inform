//
//  IFExtensionDownloadTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFExtensionDownloadTests: XCTestCase, @unchecked Sendable {
    private var folder: URL!

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private func download(_ url: URL) -> IFExtensionDownload {
        return IFExtensionDownload(url: url, window: nil, notifyDelegate: nil, javascriptId: "7")
    }

    /// A task for the download to treat as its own, which never runs
    private func task(for download: IFExtensionDownload) -> URLSessionDataTask {
        return URLSession(configuration: .ephemeral).dataTask(with: download.url)
    }

    private func response(_ download: IFExtensionDownload, _ dataTask: URLSessionDataTask,
                          _ response: URLResponse) throws -> URLSession.ResponseDisposition? {
        let delegate = try XCTUnwrap(download as? URLSessionDataDelegate)
        nonisolated(unsafe) var disposition: URLSession.ResponseDisposition?
        delegate.urlSession?(URLSession.shared, dataTask: dataTask, didReceive: response) { disposition = $0 }
        return disposition
    }

    private func receive(_ download: IFExtensionDownload, _ dataTask: URLSessionDataTask, _ data: String) throws {
        let delegate = try XCTUnwrap(download as? URLSessionDataDelegate)
        delegate.urlSession?(URLSession.shared, dataTask: dataTask, didReceive: Data(data.utf8))
    }

    /// The paths of the files this process has open
    private func openFilePaths() -> [String] {
        var paths: [String] = []
        for fd in 0..<min(getdtablesize(), 65536) {
            var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            if fcntl(fd, F_GETPATH, &path) != -1 {
                paths.append(String(cString: path))
            }
        }
        return paths
    }

    func testANewDownload() {
        let url = folder.appendingPathComponent("Locksmith.zip")
        let notified = NSObject()
        let newDownload = IFExtensionDownload(url: url, window: nil, notifyDelegate: notified, javascriptId: "7")

        XCTAssertEqual(newDownload.url, url)
        XCTAssertEqual(newDownload.state, .downloadNotStarted)
        XCTAssertNil(newDownload.window)
        XCTAssertTrue(newDownload.notifyDelegate === notified)
        XCTAssertEqual(newDownload.javascriptId, "7")
        XCTAssertNil(newDownload.connection)
        XCTAssertEqual(newDownload.receivedData, NSMutableData())
    }

    func testANewDownloadIsntKeptAlive() {
        weak var newDownload: IFExtensionDownload?
        autoreleasepool {
            newDownload = download(folder.appendingPathComponent("Locksmith.zip"))
        }
        XCTAssertNil(newDownload)
    }

    func testReceivingData() throws {
        let newDownload = download(folder.appendingPathComponent("Locksmith.zip"))
        let dataTask = task(for: newDownload)
        newDownload.connection = dataTask

        try receive(newDownload, dataTask, "Lock")
        try receive(newDownload, dataTask, "smith")
        XCTAssertEqual(newDownload.receivedData, NSMutableData(data: Data("Locksmith".utf8)))

        // A response, say after a redirect, starts the data again
        let ok = try XCTUnwrap(HTTPURLResponse(url: newDownload.url, statusCode: 200, httpVersion: nil, headerFields: nil))
        XCTAssertEqual(try response(newDownload, dataTask, ok), .allow)
        XCTAssertEqual(newDownload.receivedData?.length, 0)

        try receive(newDownload, dataTask, "Keys")
        let file = URLResponse(url: newDownload.url, mimeType: nil, expectedContentLength: 4, textEncodingName: nil)
        XCTAssertEqual(try response(newDownload, dataTask, file), .allow)
        XCTAssertEqual(newDownload.receivedData?.length, 0)
    }

    func testOtherTasksAreIgnored() throws {
        let newDownload = download(folder.appendingPathComponent("Locksmith.zip"))
        newDownload.connection = task(for: newDownload)
        let otherTask = task(for: newDownload)

        try receive(newDownload, newDownload.connection!, "Locksmith")
        try receive(newDownload, otherTask, "Keys")
        let notFound = try XCTUnwrap(HTTPURLResponse(url: newDownload.url, statusCode: 404, httpVersion: nil, headerFields: nil))

        XCTAssertEqual(try response(newDownload, otherTask, notFound), .allow)
        XCTAssertEqual(newDownload.receivedData, NSMutableData(data: Data("Locksmith".utf8)))
    }

    func testDownloadingAFile() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let zipURL = folder.appendingPathComponent("Locksmith.zip")
        try Data("Not really a zip file".utf8).write(to: zipURL)
        let newDownload = download(zipURL)

        XCTAssertTrue(newDownload.startAndInstall())
        XCTAssertEqual(newDownload.state, .downloadInProgress)
        XCTAssertEqual(newDownload.connection?.originalRequest?.url, zipURL)

        // Once it's downloaded, the download lets go of the task and the data
        let finished = expectation(for: NSPredicate { _, _ in newDownload.connection == nil }, evaluatedWith: nil)
        wait(for: [finished], timeout: 10)
        XCTAssertNil(newDownload.receivedData)

        // ...and doesn't keep open the temporary file it saved the data in
        XCTAssertEqual(openFilePaths().filter { path in
            let name = (path as NSString).lastPathComponent
            return name.hasPrefix("temp.") && name.hasSuffix(".zip")
        }, [])

        // With no project to install it in, it isn't installed
        XCTAssertFalse(NSDocumentController.shared.documents.contains { $0 is IFProject })
        XCTAssertEqual(newDownload.state, .installFailed)
    }

    func testAFinishedDownloadIsntKeptAlive() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let zipURL = folder.appendingPathComponent("Locksmith.zip")
        try Data("Not really a zip file".utf8).write(to: zipURL)
        weak var newDownload: IFExtensionDownload?

        autoreleasepool {
            let started = download(zipURL)
            XCTAssertTrue(started.startAndInstall())
            newDownload = started
        }

        // Once it has finished, nothing keeps it
        let released = expectation(for: NSPredicate { _, _ in newDownload == nil }, evaluatedWith: nil)
        wait(for: [released], timeout: 10)
    }
}
