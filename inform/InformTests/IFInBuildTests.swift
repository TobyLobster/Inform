//
//  IFInBuildTests.swift
//  InformTests
//

import XCTest

final class IFInBuildTests: XCTestCase {

    /// A new folder whose name isn't ASCII, so the command line in an error page isn't either.
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Café")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        return folder
    }

    private var internalURL: URL {
        URL(fileURLWithPath: IFUtility.path(forInformInternalAppSupport: ""))
    }

    private func assertErrorPage(at url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        let page = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(page.contains("There was an error running inbuild"), file: file, line: line)
        XCTAssertTrue(page.contains("Café"), file: file, line: line)
    }

    func testWritesAnErrorPageWhenInstallingFails() throws {
        let folder = try makeFolder()
        let results = folder.appendingPathComponent("Report.html")

        let exitCode = IFInBuild().executeForInfo(withProject: folder.appendingPathComponent("Missing.inform"),
                                                  action: "-install",
                                                  forExtension: folder.appendingPathComponent("Missing.i7x"),
                                                  withInternal: internalURL,
                                                  withConfirmation: false,
                                                  withResults: results,
                                                  settings: IFCompilerSettings())

        XCTAssertNotEqual(exitCode, 0)
        try assertErrorPage(at: results)
    }

    func testWritesAnErrorPageWhenConvertingMarkdownFails() throws {
        let folder = try makeFolder()
        let html = folder.appendingPathComponent("Error.html")

        let exitCode = IFInBuild().execute(forConvertingMarkdown: folder.appendingPathComponent("Missing.md").path,
                                           toHTML: html.path,
                                           withInternal: internalURL,
                                           settings: IFCompilerSettings())

        XCTAssertNotEqual(exitCode, 0)
        try assertErrorPage(at: html)
    }
}
