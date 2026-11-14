//
//  IFRuntimeProblemPageTests.swift
//  InformTests
//

import XCTest

/// The page explaining a run-time problem that a story reported
@MainActor
final class IFRuntimeProblemPageTests: XCTestCase {
    private let materials = "/Projects/Lighthouse.materials"
    private let internalFiles = "/Applications/Inform.app/Contents/Resources/Internal"
    /// The folder of Basic Inform's problems, as a story compiled with debugging names it
    private let basicInformRTPs = "INTERNAL/Extensions/Graham Nelson/Basic Inform.i7xd/Materials/Inter/BasicInformKit/RTPs"

    private func page(_ problem: String, in directory: String?) -> IFRuntimeProblemPage {
        return IFRuntimeProblemPage(problem: problem,
                                    inDirectory: directory,
                                    materialsDirectory: materials,
                                    internalDirectory: internalFiles)
    }

    /// Where the page made from a problem's markdown file is written
    private var temporaryPage: URL {
        return IFUtility.temporaryDirectoryURL().appendingPathComponent("temp.html")
    }

    /// The page for a problem in a new folder, made with inbuild and the app's internal files from the markdown
    /// given, written in the folder as the problem's markdown file, or from no file there
    private func makePage(_ problem: String, withMarkdown markdown: String?) throws -> IFRuntimeProblemPage {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Locks Kit")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        if let markdown {
            try markdown.write(to: folder.appendingPathComponent("\(problem).md"), atomically: true, encoding: .utf8)
        }
        let temporaryPage = self.temporaryPage
        try? FileManager.default.removeItem(at: temporaryPage)
        addTeardownBlock { try? FileManager.default.removeItem(at: temporaryPage) }

        let page = IFRuntimeProblemPage(problem: problem,
                                        inDirectory: folder.path,
                                        materialsDirectory: materials,
                                        internalDirectory: IFUtility.path(forInformInternalAppSupport: ""))
        page.makePageFromMarkdown(with: IFInBuild(), settings: IFCompilerSettings())
        return page
    }

    func testANumberedProblemHasTheAppsPage() {
        let page = page("P26", in: nil)

        XCTAssertEqual(page.appPageURL?.absoluteString, "inform:/RTP_P26.html")
        XCTAssertNil(page.markdownPath)
    }

    /// The app has no page for a problem like this, from a story compiled without debugging, so a page saying so is
    /// written
    func testAProblemTheAppHasNoPageForHasAPageSayingSo() throws {
        let page = page("SaidInvalidSnippet", in: nil)

        let url = try XCTUnwrap(page.appPageURL)
        XCTAssertTrue(url.isFileURL, url.absoluteString)
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("run-time problem SaidInvalidSnippet"), html)
        XCTAssertNil(page.markdownPath)
    }

    /// The problem's name is as the story wrote it, so it's shown as written
    func testThePageSayingThereIsNoPageShowsTheProblemsNameAsWritten() throws {
        let page = page("<b>&", in: nil)

        let html = try String(contentsOf: try XCTUnwrap(page.appPageURL), encoding: .utf8)
        XCTAssertTrue(html.contains("run-time problem &lt;b&gt;&amp;"), html)
    }

    func testAProblemInInformsInternalFilesIsMadeFromItsMarkdownThere() {
        let page = page("SaidInvalidSnippet", in: basicInformRTPs)

        XCTAssertEqual(page.markdownPath,
                       internalFiles + "/Extensions/Graham Nelson/Basic Inform.i7xd/Materials/Inter/BasicInformKit/RTPs/SaidInvalidSnippet.md")
        XCTAssertNil(page.appPageURL)
    }

    func testTheInternalFilesAreNamedInAnyCase() {
        XCTAssertEqual(page("Problem", in: "Internal/Kits/RTPs").markdownPath, internalFiles + "/Kits/RTPs/Problem.md")
        XCTAssertEqual(page("Problem", in: "internal/Kits/RTPs").markdownPath, internalFiles + "/Kits/RTPs/Problem.md")
    }

    func testAProblemInTheProjectsMaterialsIsMadeFromItsMarkdownThere() {
        let page = page("Problem", in: "MATERIALS/Extensions/Emily Short/Locks.i7xd/Materials/Inter/LocksKit/RTPs")

        XCTAssertEqual(page.markdownPath,
                       materials + "/Extensions/Emily Short/Locks.i7xd/Materials/Inter/LocksKit/RTPs/Problem.md")
        XCTAssertNil(page.appPageURL)
    }

    func testAProblemInAFolderGivenInFullIsMadeFromItsMarkdownThere() {
        let page = page("Problem", in: "/Users/Shared/Kits/LocksKit/RTPs")

        XCTAssertEqual(page.markdownPath, "/Users/Shared/Kits/LocksKit/RTPs/Problem.md")
        XCTAssertNil(page.appPageURL)
    }

    func testAProblemInMaterialsHasNoPageWithoutAMaterialsFolder() {
        let page = IFRuntimeProblemPage(problem: "Problem",
                                        inDirectory: "MATERIALS/Kits/RTPs",
                                        materialsDirectory: nil,
                                        internalDirectory: internalFiles)

        XCTAssertNil(page.markdownPath)
        XCTAssertNil(page.appPageURL)
    }

    func testTheAppsPageIsShownForAProblemWithNoFolder() {
        XCTAssertEqual(page("P26", in: nil).pageURL?.absoluteString, "inform:/RTP_P26.html")
    }

    func testThePageMadeFromAProblemsMarkdownIsShownFromTheTemporaryFolder() {
        XCTAssertEqual(page("Problem", in: "/Users/Shared/Kits/LocksKit/RTPs").pageURL, temporaryPage)
    }

    func testNoPageIsShownForAProblemInMaterialsWithoutAMaterialsFolder() {
        let page = IFRuntimeProblemPage(problem: "Problem",
                                        inDirectory: "MATERIALS/Kits/RTPs",
                                        materialsDirectory: nil,
                                        internalDirectory: internalFiles)

        XCTAssertNil(page.pageURL)
    }

    func testThePageIsMadeFromTheProblemsMarkdown() throws {
        let page = try makePage("Problem", withMarkdown: "# A Problem\n\nSomething *went* wrong.\n")

        let html = try String(contentsOf: try XCTUnwrap(page.pageURL), encoding: .utf8)
        XCTAssertTrue(html.contains("Something <em>went</em> wrong."), html)
    }

    /// When inbuild can't make the page, the page it writes about its error is shown in its place
    func testInbuildsErrorIsShownWhenThePageCantBeMade() throws {
        let page = try makePage("Problem", withMarkdown: nil)

        let html = try String(contentsOf: try XCTUnwrap(page.pageURL), encoding: .utf8)
        XCTAssertTrue(html.contains("There was an error running inbuild"), html)
        XCTAssertTrue(html.contains("Locks Kit/Problem.md"), html)
    }

    func testNothingIsMadeForAProblemWithNoFolder() {
        try? FileManager.default.removeItem(at: temporaryPage)
        let inBuild = IFInBuild()

        page("P26", in: nil).makePageFromMarkdown(with: inBuild, settings: IFCompilerSettings())

        XCTAssertNil(inBuild.stdOut, "inbuild was run")
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryPage.path))
    }
}
