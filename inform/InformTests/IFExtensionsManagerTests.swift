//
//  IFExtensionsManagerTests.swift
//  InformTests
//

import XCTest

final class IFExtensionsManagerTests: XCTestCase {

    private struct FirstLine {
        let result: IFExtensionResult
        let author: String?
        let title: String?
        let version: String?
    }

    /// Reads an extension file that starts with the given line, as the extensions manager does
    /// for legacy extensions and for the extension in an extension project.
    private func read(firstLine: String) throws -> FirstLine {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("i7x")
        try (firstLine + "\n\nInclude Basic Screen Effects by Emily Short.\n").write(to: file, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }

        var author: NSString?
        var title: NSString?
        var version: NSString?
        let result = IFExtensionsManager.sharedNaturalInform
            .info(forNaturalInformExtension: file.path, author: &author, title: &title, version: &version)
        return FirstLine(result: result, author: author as String?, title: title as String?, version: version as String?)
    }

    func testReadsTheTitleAuthorAndVersion() throws {
        let line = try read(firstLine: "Version 2/090402 of The Locksmith Kit by Emily Short begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Locksmith Kit")
        XCTAssertEqual(line.author, "Emily Short")
        XCTAssertEqual(line.version, "Version 2/090402")
    }

    func testReadsAnExtensionWithNoVersion() throws {
        let line = try read(firstLine: "Locksmith by Emily Short begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Locksmith")
        XCTAssertEqual(line.author, "Emily Short")
        XCTAssertNil(line.version)
    }

    /// A title can start with "Version" without the extension having a version.
    func testReadsATitleThatStartsWithVersion() throws {
        let line = try read(firstLine: "Version Control by Jane Doe begins here.")
        XCTAssertEqual(line.result, .success)
        XCTAssertEqual(line.title, "Version Control")
        XCTAssertEqual(line.author, "Jane Doe")
        XCTAssertNil(line.version)
    }

    func testRejectsAFileThatIsNotAnExtension() throws {
        XCTAssertEqual(try read(firstLine: "\"An Interactive Fiction\" by Jane Doe").result, .notValid)
        // Without an author
        XCTAssertEqual(try read(firstLine: "Locksmith begins here.").result, .notValid)

        var author: NSString?
        var title: NSString?
        var version: NSString?
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        XCTAssertEqual(IFExtensionsManager.sharedNaturalInform
            .info(forNaturalInformExtension: missing, author: &author, title: &title, version: &version), .notFound)
    }
}
