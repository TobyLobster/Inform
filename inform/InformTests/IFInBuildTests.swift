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

    /// A project with a line of source, in the given folder
    private func makeProject(in folder: URL) throws -> URL {
        let project = folder.appendingPathComponent("Lighthouse.inform")
        let source = project.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "\"Lighthouse\" by Jane Doe\n\nThe Lamp Room is a room.\n"
            .write(to: source.appendingPathComponent("story.ni"), atomically: true, encoding: .utf8)
        return project
    }

    /// An extension, in the given folder
    private func makeExtension(in folder: URL) throws -> URL {
        let file = folder.appendingPathComponent("Lamplighting.i7x")
        try "Lamplighting by Jane Doe begins here.\n\nA lamp is a kind of thing.\n\nLamplighting ends here.\n"
            .write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Where the extension is installed in the project
    private func installedExtension(in project: URL) -> URL {
        return project.deletingPathExtension().appendingPathExtension("materials")
            .appendingPathComponent("Extensions")
            .appendingPathComponent("Jane Doe")
            .appendingPathComponent("Lamplighting.i7x")
    }

    private func install(in project: URL, confirmed: Bool, results: URL,
                         settings: IFCompilerSettings = IFCompilerSettings()) throws -> Int32 {
        let folder = project.deletingLastPathComponent()
        return IFInBuild().executeForInfo(withProject: project,
                                          action: "-install",
                                          forExtension: try makeExtension(in: folder),
                                          withInternal: internalURL,
                                          withConfirmation: confirmed,
                                          withResults: results,
                                          settings: settings)
    }

    func testHasNoOutputBeforeItsFirstRun() {
        let inBuild = IFInBuild()
        XCTAssertNil(inBuild.stdOut)
        XCTAssertNil(inBuild.stdErr)
    }

    func testReportsOnAnExtensionWithoutInstallingIt() throws {
        let folder = try makeFolder()
        let project = try makeProject(in: folder)
        let results = folder.appendingPathComponent("Report.html")

        XCTAssertEqual(try install(in: project, confirmed: false, results: results), 0)

        let page = try String(contentsOf: results, encoding: .utf8)
        XCTAssertTrue(page.contains("Lamplighting by Jane Doe"))
        XCTAssertFalse(page.contains("There was an error running inbuild"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installedExtension(in: project).path))
    }

    func testInstallsAnExtensionOnceConfirmed() throws {
        let folder = try makeFolder()
        let project = try makeProject(in: folder)
        let results = folder.appendingPathComponent("Report.html")

        XCTAssertEqual(try install(in: project, confirmed: true, results: results), 0)

        let page = try String(contentsOf: results, encoding: .utf8)
        XCTAssertTrue(page.contains("This extension has now been installed"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installedExtension(in: project).path))
    }

    func testTheErrorPageGivesTheCommand() throws {
        let folder = try makeFolder()
        let missing = folder.appendingPathComponent("Missing.inform")
        let results = folder.appendingPathComponent("Report.html")

        let settings = IFCompilerSettings()
        settings.allowLegacyExtensionDirectory = true
        XCTAssertNotEqual(try install(in: missing, confirmed: true, results: results, settings: settings), 0)
        var page = try String(contentsOf: results, encoding: .utf8)
        XCTAssertTrue(page.contains("-project\n      \(missing.path)\n      -install\n"))
        XCTAssertTrue(page.contains("-deprecated-external\n"))
        XCTAssertTrue(page.contains(IFUtility.pathForInformExternalAppSupport()))
        XCTAssertTrue(page.contains("-confirmed\n"))

        settings.allowLegacyExtensionDirectory = false
        XCTAssertNotEqual(try install(in: missing, confirmed: false, results: results, settings: settings), 0)
        page = try String(contentsOf: results, encoding: .utf8)
        XCTAssertTrue(page.contains("-project\n"))
        XCTAssertFalse(page.contains("-deprecated-external"))
        XCTAssertFalse(page.contains("-confirmed"))
    }

    func testTakesTheCensus() throws {
        let inBuild = IFInBuild()

        XCTAssertEqual(inBuild.executeForCensus(), 0)

        // A JSON object, with an entry for each extension in the extensions folder, if there is one
        let census = try JSONSerialization.jsonObject(with: Data(((inBuild.stdOut as String?) ?? "").utf8))
        XCTAssertNotNil(census as? [String: Any])
    }

    func testConvertsMarkdownToHTML() throws {
        let folder = try makeFolder()
        let markdown = folder.appendingPathComponent("Problem.md")
        let html = folder.appendingPathComponent("Problem.html")
        try "# A Problem\n\nSomething *went* wrong.\n".write(to: markdown, atomically: true, encoding: .utf8)
        let inBuild = IFInBuild()

        let exitCode = inBuild.execute(forConvertingMarkdown: markdown.path,
                                       toHTML: html.path,
                                       withInternal: internalURL,
                                       settings: IFCompilerSettings())

        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(try String(contentsOf: html, encoding: .utf8).contains("Something <em>went</em> wrong."))
        XCTAssertEqual(inBuild.stdErr as String?, "")
    }

    func testKeepsWhatInbuildWroteOnItsLastRun() throws {
        let folder = try makeFolder()
        let markdown = folder.appendingPathComponent("Problem.md")
        let html = folder.appendingPathComponent("Problem.html")
        let inBuild = IFInBuild()

        XCTAssertNotEqual(inBuild.execute(forConvertingMarkdown: markdown.path, toHTML: html.path,
                                          withInternal: internalURL, settings: IFCompilerSettings()), 0)
        XCTAssertEqual(inBuild.stdOut as String?, "")
        XCTAssertEqual(inBuild.stdErr as String?, "inbuild: fatal error: no Markdown source: \(markdown.path)\n")

        try "Nothing went wrong.\n".write(to: markdown, atomically: true, encoding: .utf8)
        XCTAssertEqual(inBuild.execute(forConvertingMarkdown: markdown.path, toHTML: html.path,
                                       withInternal: internalURL, settings: IFCompilerSettings()), 0)
        XCTAssertEqual(inBuild.stdOut as String?, "")
        XCTAssertEqual(inBuild.stdErr as String?, "")
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
