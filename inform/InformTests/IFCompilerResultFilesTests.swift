//
//  IFCompilerResultFilesTests.swift
//  InformTests
//

import XCTest

/// Choosing the files in a build folder that the Errors page shows a tab for, and the tab each one is
final class IFCompilerResultFilesTests: XCTestCase {

    private let problemsURL = URL(fileURLWithPath: "/Projects/Story.inform/Build/Problems.html")

    private func filesToShow(_ files: [String], showDebuggingLogs: Bool = false, problemsURL: URL? = nil) -> [String] {
        return IFCompilerResultFiles.filesToShow(of: files, showDebuggingLogs: showDebuggingLogs, problemsURL: problemsURL)
    }

    func testTheTabForEachFileOfResults() {
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Debug log.txt"), .tabDebugging)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "auto.inf"), .tabInform6)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Problems.html"), .tabReport)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Log of Problems.txt"), .tabReport)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "inbuild.html"), .tabInBuild)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "compiler"), .tabConsole)
    }

    func testTheTabIsFoundByTheNameInAnyCase() {
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "DEBUG LOG.TXT"), .tabDebugging)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Auto.INF"), .tabInform6)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "problems.HTML"), .tabReport)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "InBuild.html"), .tabInBuild)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Compiler"), .tabConsole)
    }

    func testOtherFilesHaveNoTabOfTheirOwn() {
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Notes.txt"), .tabInvalid)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Problems.htm"), .tabInvalid)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "auto"), .tabInvalid)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: "Build/auto.inf"), .tabInvalid)
        XCTAssertEqual(IFCompilerResultFiles.tabId(forFile: ""), .tabInvalid)
    }

    func testInform6FilesTextFilesAndWebPagesAreShownInTheirOrder() {
        XCTAssertEqual(filesToShow(["Problems.html", "Notes.TXT", "Story.inf", "Index.htm", "inbuild.html"]),
                       ["Problems.html", "Notes.TXT", "Story.inf", "Index.htm", "inbuild.html"])
    }

    func testOtherTypesOfFileAreLeftOut() {
        XCTAssertEqual(filesToShow(["output.ulx", "gameinfo.dbg", "Metadata.iFiction", "Release.blurb",
                                    "compiler", "Problems.html", "Notes.text", "Index.xhtml"]),
                       ["Problems.html"])
    }

    func testTemporaryFilesAreLeftOut() {
        XCTAssertEqual(filesToShow(["Temp.txt", "temporary.html", "TEMP.inf", "temp", "tmp.txt", "tem.txt",
                                    "Contemporary.txt"]),
                       ["tmp.txt", "tem.txt", "Contemporary.txt"])
    }

    func testTheDebuggingLogsAreLeftOutUnlessTheyAreToBeShown() {
        let files = ["Debug log.txt", "auto.inf", "AUTO.INF", "Problems.html", "Debug log.html"]

        XCTAssertEqual(filesToShow(files), ["Problems.html", "Debug log.html"])
        XCTAssertEqual(filesToShow(files, showDebuggingLogs: true), files)
    }

    func testTheProblemsPageIsLeftOutWhenTheCompilerGaveOne() {
        let files = ["Problems.html", "problems.txt", "Debug log.txt", "Problems page.html"]

        XCTAssertEqual(filesToShow(files, showDebuggingLogs: true), files)
        XCTAssertEqual(filesToShow(files, showDebuggingLogs: true, problemsURL: problemsURL),
                       ["Debug log.txt", "Problems page.html"])
    }

    func testAFileWithTheNameOfTheCompilersProblemsPageIsLeftOut() {
        let files = ["Problems.html", "Errors.htm", "errors.txt", "Notes.txt"]
        let errorsURL = URL(fileURLWithPath: "/Projects/Story.inform/Build/Errors.html")

        XCTAssertEqual(filesToShow(files, problemsURL: errorsURL), ["Notes.txt"])
    }
}
