//
//  IFTestReportTests.swift
//  InformTests
//

import XCTest

/// What goes into an extension project's test reports: the code for a problem the compiler found, how far down the
/// skein the story was played, and a single test case's report as the combined one
final class IFTestReportTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - The code for a problem the compiler found

    func testNoProblemHasNoCode() {
        XCTAssertNil(IFTestReport.intestCode(for: .none))
    }

    func testInform6sProblemsAreI6() {
        XCTAssertEqual(IFTestReport.intestCode(for: .inform6), "i6")
    }

    func testEveryOtherProblemIsI7() {
        XCTAssertEqual(IFTestReport.intestCode(for: .inform7), "i7")
        XCTAssertEqual(IFTestReport.intestCode(for: .cBlorb), "i7")
        XCTAssertEqual(IFTestReport.intestCode(for: .unknown), "i7")
    }

    func testANumberThatIsNoProblemTypeHasNoCode() throws {
        let notAType = try XCTUnwrap(ECompilerProblemType(rawValue: 99))
        XCTAssertNil(IFTestReport.intestCode(for: notAType))
    }

    // MARK: - How far down the skein the story was played

    func testTheKnotsPlayedThroughAreTheKnotAndThoseAboveItApartFromTheRoot() {
        let skein = IFSkein(project: nil)
        let look = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let north = look.addChild(IFSkeinItem(skein: skein, command: "north"))
        let jump = north.addChild(IFSkeinItem(skein: skein, command: "jump"))

        XCTAssertEqual(IFTestReport.skeinNodes(to: look), 1)
        XCTAssertEqual(IFTestReport.skeinNodes(to: north), 2)
        XCTAssertEqual(IFTestReport.skeinNodes(to: jump), 3)
    }

    func testTheRootAndNoKnotAreNotPlayedThroughAny() {
        XCTAssertEqual(IFTestReport.skeinNodes(to: IFSkein(project: nil).rootItem), 0)
        XCTAssertEqual(IFTestReport.skeinNodes(to: IFSkeinItem(skein: nil, command: "look")), 0)
        XCTAssertEqual(IFTestReport.skeinNodes(to: nil), 0)
    }

    // MARK: - A single test case's report as the combined one

    private func write(_ text: String, to name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func contents(of url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testTheReportReplacesTheCombinedOne() throws {
        let report = try write("This test case's report", to: "Inform-Report-1.html")
        let combined = try write("An earlier report", to: "Problems.html")

        IFTestReport.copy(report, toCombinedURL: combined)

        XCTAssertEqual(try contents(of: combined), "This test case's report")
        XCTAssertEqual(try contents(of: report), "This test case's report")
    }

    func testWithNoCombinedReportTheReportIsStillCopied() throws {
        let report = try write("This test case's report", to: "Inform-Report-1.html")
        let combined = folder.appendingPathComponent("Problems.html")

        IFTestReport.copy(report, toCombinedURL: combined)

        XCTAssertEqual(try contents(of: combined), "This test case's report")
    }

    func testWithNoReportTheCombinedOneIsStillRemoved() throws {
        let report = folder.appendingPathComponent("Inform-Report-1.html")
        let combined = try write("An earlier report", to: "Problems.html")

        IFTestReport.copy(report, toCombinedURL: combined)

        XCTAssertFalse(FileManager.default.fileExists(atPath: combined.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: report.path))
    }
}
