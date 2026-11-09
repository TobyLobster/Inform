//
//  IFRuntimeProblemPageTests.swift
//  InformTests
//

import XCTest

/// The page explaining a run-time problem that a story reported
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

    func testANumberedProblemHasTheAppsPage() {
        let page = page("P26", in: nil)

        XCTAssertEqual(page.appPageURL?.absoluteString, "inform:/RTP_P26.html")
        XCTAssertNil(page.markdownPath)
    }

    func testAProblemTheAppHasNoPageForHasTheUnknownPage() {
        let page = page("SaidInvalidSnippet", in: nil)

        XCTAssertEqual(page.appPageURL?.absoluteString, "inform:/RTP_Unknown.html")
        XCTAssertNil(page.markdownPath)
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
}
