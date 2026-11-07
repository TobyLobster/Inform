//
//  IFInformProtocolTests.swift
//  InformTests
//

import XCTest

/// A URL protocol client that records what the protocol tells it
private final class RecordingClient: NSObject, URLProtocolClient {
    private(set) var responses: [URLResponse] = []
    private(set) var storagePolicies: [URLCache.StoragePolicy] = []
    private(set) var data = Data()
    private(set) var finished = false
    private(set) var errors: [Error] = []
    /// Anything else it was told
    private(set) var others: [String] = []

    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        responses.append(response)
        storagePolicies.append(policy)
    }

    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {
        self.data.append(data)
    }

    func urlProtocolDidFinishLoading(_ protocol: URLProtocol) {
        finished = true
    }

    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) {
        errors.append(error)
    }

    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {
        others.append("redirected")
    }

    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {
        others.append("cached response is valid")
    }

    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {
        others.append("challenge")
    }

    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {
        others.append("cancelled challenge")
    }

    /// The code of the one error it was given, if that's all it was told
    var errorCode: Int? {
        guard errors.count == 1, responses.isEmpty, data.isEmpty, !finished, others.isEmpty else {
            return nil
        }
        let error = errors[0] as NSError
        XCTAssertEqual(error.domain, NSURLErrorDomain)
        return error.code
    }
}

final class IFInformProtocolTests: XCTestCase {

    /// A folder of the tests' own in Inform's documentation folder, which is in the tests' own home
    private var documentationFolder: URL {
        return URL(fileURLWithPath: IFUtility.pathForInformExternalDocumentation())
            .appendingPathComponent("IFInformProtocolTests")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: documentationFolder)
        super.tearDown()
    }

    /// Writes a file in the tests' own home
    private func write(_ text: String, to url: URL) throws -> Data {
        XCTAssertTrue(url.path.hasPrefix(NSHomeDirectory() + "/Library/"), url.path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(text.utf8)
        try data.write(to: url)
        return data
    }

    /// Asks a new protocol for a URL
    private func load(_ url: String) -> (client: RecordingClient, request: URLRequest) {
        let client = RecordingClient()
        let request = URLRequest(url: URL(string: url)!)
        let informProtocol = IFInformProtocol(request: request, cachedResponse: nil, client: client)
        informProtocol.startLoading()
        return (client, request)
    }

    private func resource(_ path: String) -> Data? {
        return FileManager.default.contents(atPath: Bundle.main.resourcePath! + "/" + path)
    }

    /// Checks that the client was given one response, with the data and type expected, and finished
    private func checkLoaded(_ loaded: (client: RecordingClient, request: URLRequest),
                             _ expected: Data?,
                             type: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        let client = loaded.client
        XCTAssertEqual(client.errors.count, 0, file: file, line: line)
        XCTAssertEqual(client.others, [], file: file, line: line)
        XCTAssertEqual(client.responses.count, 1, file: file, line: line)
        XCTAssertEqual(client.storagePolicies, [.allowedInMemoryOnly], file: file, line: line)
        XCTAssertTrue(client.finished, file: file, line: line)
        XCTAssertNotNil(expected, file: file, line: line)
        XCTAssertEqual(client.data, expected, file: file, line: line)

        guard let response = client.responses.first else {
            return
        }
        XCTAssertEqual(response.url, loaded.request.url, file: file, line: line)
        XCTAssertEqual(response.mimeType, type, file: file, line: line)
        XCTAssertEqual(response.expectedContentLength, Int64(client.data.count), file: file, line: line)
        XCTAssertNil(response.textEncodingName, file: file, line: line)
    }

    // MARK: - Which requests

    func testItAnswersInformURLsWithAPath() {
        for url in ["inform:/AdviceCredits.html", "inform:///App/Welcome/iftf-logo.svg", "inform://Extensions/Extensions.html", "inform:/"] {
            XCTAssertTrue(IFInformProtocol.canInit(with: URLRequest(url: URL(string: url)!)), url)
        }
    }

    func testItDoesntAnswerOtherURLs() {
        // NSURL gives the first two no path
        for url in ["inform:", "inform:AdviceCredits.html", "https://example.com/AdviceCredits.html", "file:///AdviceCredits.html"] {
            XCTAssertFalse(IFInformProtocol.canInit(with: URLRequest(url: URL(string: url)!)), url)
        }
    }

    /// Only a scheme in lower case, as the app writes it, is answered
    func testTheSchemeIsCaseSensitive() {
        XCTAssertFalse(IFInformProtocol.canInit(with: URLRequest(url: URL(string: "INFORM:/AdviceCredits.html")!)))
    }

    func testTheCanonicalRequestIsTheRequest() {
        let request = URLRequest(url: URL(string: "inform:/AdviceCredits.html")!)
        XCTAssertEqual(IFInformProtocol.canonicalRequest(for: request), request)
    }

    func testItKeepsWhatItsGiven() {
        let client = RecordingClient()
        let request = URLRequest(url: URL(string: "inform:/AdviceCredits.html")!)
        let cached = CachedURLResponse(response: URLResponse(url: request.url!, mimeType: "text/html",
                                                             expectedContentLength: 0, textEncodingName: nil),
                                       data: Data())
        let informProtocol = IFInformProtocol(request: request, cachedResponse: cached, client: client)
        XCTAssertEqual(informProtocol.request, request)
        XCTAssertIdentical(informProtocol.cachedResponse, cached)
        XCTAssertIdentical(informProtocol.client, client)
    }

    /// The app registers it, so Foundation reads an inform: URL with it, as for the welcome window's
    /// and the skein page's templates
    func testTheAppsTemplatesAreRead() throws {
        for name in ["NewsTemplate.html", "TestingTemplate.html"] {
            let read = try String(contentsOf: URL(string: "inform:/" + name)!, encoding: .utf8)
            XCTAssertEqual(Data(read.utf8), resource("en.lproj/" + name), name)
        }
    }

    // MARK: - Files in the resources

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

    // MARK: - Extensions pages

    /// An extensions URL's host, or the first folder of its path, says the page is in Inform's documentation folder
    func testAnExtensionsPage() throws {
        let page = try write("<p>Lamplighting</p>", to: documentationFolder.appendingPathComponent("Jane Doe/Lamplighting.html"))
        checkLoaded(load("inform://Extensions/IFInformProtocolTests/Jane%20Doe/Lamplighting.html"), page, type: "text/html")
        checkLoaded(load("inform://extensions/IFInformProtocolTests/Jane%20Doe/Lamplighting.html"), page, type: "text/html")
        checkLoaded(load("inform:/Extensions/IFInformProtocolTests/Jane%20Doe/Lamplighting.html"), page, type: "text/html")
        checkLoaded(load("inform:///extensions/IFInformProtocolTests/Jane%20Doe/Lamplighting.html"), page, type: "text/html")
    }

    /// An extensions page that isn't in the documentation folder is looked for in the resources, by its whole path
    func testAnExtensionsPageThatIsntThere() {
        checkLoaded(load("inform://Extensions/InformCoreVersion.txt"), resource("InformCoreVersion.txt"), type: "text/plain")
        XCTAssertEqual(load("inform:/Extensions/InformCoreVersion.txt").client.errorCode, NSURLErrorFileDoesNotExist)
    }

    // MARK: - Failures

    func testAMissingFile() {
        XCTAssertEqual(load("inform:/NoSuchFile.html").client.errorCode, NSURLErrorFileDoesNotExist)
        XCTAssertEqual(load("inform:/App/NoSuchFile.html").client.errorCode, NSURLErrorFileDoesNotExist)
        XCTAssertEqual(load("inform://Extensions/NoSuchFile.html").client.errorCode, NSURLErrorFileDoesNotExist)
    }

    /// A folder is reported as missing too
    func testAFolder() {
        XCTAssertEqual(load("inform:/bg_images").client.errorCode, NSURLErrorFileDoesNotExist)
        XCTAssertEqual(load("inform:/").client.errorCode, NSURLErrorFileDoesNotExist)
    }

    func testStoppingDoesNothing() {
        let client = RecordingClient()
        let request = URLRequest(url: URL(string: "inform:/AdviceCredits.html")!)
        IFInformProtocol(request: request, cachedResponse: nil, client: client).stopLoading()
        XCTAssertTrue(client.responses.isEmpty)
        XCTAssertTrue(client.errors.isEmpty)
        XCTAssertFalse(client.finished)
        XCTAssertEqual(client.others, [])
    }
}
