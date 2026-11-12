//
//  IFExtensionTestCasesTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFExtensionTestCasesTests: XCTestCase {

    private let extensionText = "Lamplighting by Jane Doe begins here.\n\nA lamp is a kind of thing.\n\n"
        + "Lamplighting ends here.\n\n---- DOCUMENTATION ----\n\nLamps can be lit.\n\n"
        + "Example: * Lighthouse - A lamp at the top of a tower.\n\n\t*: \"Lighthouse\"\n\n"
        + "\tInclude Lamplighting by Jane Doe.\n\n"
        + "\tThe Lamp Room is a room. The great lamp is a lamp in the Lamp Room.\n\n"
        + "\tTest me with \"look / x lamp\".\n\n\n"
        + "Example: ** Café - A lamp in a café.\n\n\t*: \"Café\"\n\n"
        + "\tInclude Lamplighting by Jane Doe.\n\n"
        + "\tThe Café is a room.\n\n"
        + "\tTest me with \"look\".\n\n\n"

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// The path of an extension in an extension project's Source folder, whose documentation has two examples
    private func makeExtension() throws -> String {
        let source = try makeFolder().appendingPathComponent("Lamplighting.i7xp").appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let file = source.appendingPathComponent("extension.i7x")
        try extensionText.write(to: file, atomically: true, encoding: .utf8)
        return file.path
    }

    /// The path of the story beside an extension, where an extension project writes out the test case tested
    private func story(besideExtension file: String) -> String {
        return ((file as NSString).deletingLastPathComponent as NSString).appendingPathComponent("story.ni")
    }

    /// A problems page, as ni leaves after compiling a test case, with the markers intest looks for
    private func makeProblemsPage() throws -> URL {
        let page = try makeFolder().appendingPathComponent("Problems.html")
        try """
            <html><body>
             <!--CONTENT BEGINS-->
             <!--BANNER BEGINS-->
             <!--HEADING BEGINS-->
            Old heading
             <!--HEADING ENDS-->
             <!--BANNER ENDS-->
             <!--PROBLEMS BEGIN-->
            A problem
             <!--PROBLEMS END-->
             <!--CONTENT ENDS-->
            </body></html>

            """.write(to: page, atomically: true, encoding: .utf8)
        return page
    }

    // MARK: - The test cases

    func testHasNoTestCasesUntilRefreshed() {
        XCTAssertNil(IFExtensionTestCases().testCases)
    }

    func testFindsTheExtensionsTestCases() throws {
        let testCases = IFExtensionTestCases()

        testCases.refreshTestCases(forExtension: try makeExtension())

        XCTAssertEqual(testCases.testCases?.map { $0["testKey"] as? String }, ["A", "B"])
        XCTAssertEqual(testCases.testCases?.map { $0["testTitle"] as? String }, ["Lighthouse", "Café"])
    }

    func testHasNoTestCasesWithoutAnExtension() throws {
        let testCases = IFExtensionTestCases()
        testCases.refreshTestCases(forExtension: try makeExtension())

        testCases.refreshTestCases(forExtension: nil)

        XCTAssertEqual(testCases.testCases?.count, 0)
    }

    // MARK: - Testing a test case

    func testWritesOutATestCasesSource() throws {
        let file = try makeExtension()

        IFExtensionTestCases().extractSourceTask(forExtensionTestCase: "B", fromExtension: file,
                                                 outputToSourceFile: story(besideExtension: file))

        let source = try String(contentsOfFile: story(besideExtension: file), encoding: .utf8)
        XCTAssertTrue(source.contains("The Café is a room."))
        XCTAssertFalse(source.contains("Lamp Room"))
    }

    func testWritesOutNothingWithoutATestCase() throws {
        let file = try makeExtension()

        IFExtensionTestCases().extractSourceTask(forExtensionTestCase: nil, fromExtension: file,
                                                 outputToSourceFile: story(besideExtension: file))

        XCTAssertFalse(FileManager.default.fileExists(atPath: story(besideExtension: file)))
    }

    func testGivesATestCasesCommands() throws {
        let file = try makeExtension()
        let testCases = IFExtensionTestCases()

        XCTAssertEqual(testCases.testCommands(forExtensionTestCase: "A", ofExtension: file), ["look", "x lamp"])
        XCTAssertEqual(testCases.testCommands(forExtensionTestCase: "B", ofExtension: file), ["look"])
        XCTAssertNil(testCases.testCommands(forExtensionTestCase: "C", ofExtension: file))
    }

    // MARK: - Links to problems

    func testRedirectsATestCasesLinksToTheExtension() throws {
        let file = try makeExtension()
        let testCases = IFExtensionTestCases()
        let extensionLines = extensionText.components(separatedBy: "\n")

        for (testCase, line) in [("A", "\tThe Lamp Room is a room. The great lamp is a lamp in the Lamp Room."),
                                 ("B", "\tThe Café is a room.")] {
            testCases.extractSourceTask(forExtensionTestCase: testCase, fromExtension: file,
                                        outputToSourceFile: story(besideExtension: file))

            // Line 5 of each test case's source, after its title, a blank line, the Include and a blank line
            let link = testCases.redirectLinks(toExtensionSourceCode: ["Story.ni", testCase, "5"],
                                               inExtensionProject: true)

            XCTAssertEqual(link.count, 2, testCase)
            XCTAssertEqual(link.first as? String, "extension.i7x", testCase)
            let extensionLine = try XCTUnwrap(link.last as? Int)
            XCTAssertEqual(extensionLines[extensionLine - 1], line, testCase)
        }
    }

    func testLeavesTheLineOfATestCaseNotWrittenOut() {
        let link = IFExtensionTestCases().redirectLinks(toExtensionSourceCode: ["story.ni", "A", "5"],
                                                        inExtensionProject: true)

        XCTAssertEqual(link as NSArray, ["extension.i7x", 5] as NSArray)
    }

    func testTakesTheTestCaseFromOtherLinks() {
        let testCases = IFExtensionTestCases()

        XCTAssertEqual(testCases.redirectLinks(toExtensionSourceCode: ["Other.i7x", "B", "5"],
                                               inExtensionProject: true) as NSArray,
                       ["Other.i7x", "5"] as NSArray)
        XCTAssertEqual(testCases.redirectLinks(toExtensionSourceCode: ["story.ni", "A", "12"],
                                               inExtensionProject: false) as NSArray,
                       ["story.ni", "12"] as NSArray)
    }

    func testLeavesLinksWithoutATestCase() {
        let testCases = IFExtensionTestCases()

        XCTAssertEqual(testCases.redirectLinks(toExtensionSourceCode: ["story.ni", "12"],
                                               inExtensionProject: true) as NSArray,
                       ["story.ni", "12"] as NSArray)
        XCTAssertEqual(testCases.redirectLinks(toExtensionSourceCode: [], inExtensionProject: true).count, 0)
    }

    // MARK: - Reports

    func testWritesATestCasesReport() throws {
        let file = try makeExtension()
        let problems = try makeProblemsPage()
        let report = try makeFolder().appendingPathComponent("Report.html")
        let testCases = IFExtensionTestCases()

        XCTAssertTrue(testCases.generateReport(forTestCase: "A", ofExtension: file, errorCode: "right",
                                               problemsURL: problems, skeinNodeId: 42, skeinNodes: 2,
                                               outputURL: report))
        XCTAssertTrue(try String(contentsOf: report, encoding: .utf8)
            .contains("Example A: &#8216;Lighthouse&#8217;: Succeeded"))

        XCTAssertFalse(testCases.generateReport(forTestCase: "A", ofExtension: file, errorCode: "maybe",
                                                problemsURL: problems, skeinNodeId: 0, skeinNodes: 0,
                                                outputURL: report))
    }

    /// The folder of the reports on the test cases, removed when the test ends
    private func reportsFolder(of testCases: IFExtensionTestCases) -> URL {
        let folder = testCases.baseReportURL.deletingLastPathComponent()
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testPutsTheReportsInAFolderInTheAppsTemporaryFolder() {
        let testCases = IFExtensionTestCases()
        let reports = reportsFolder(of: testCases)

        XCTAssertEqual(reports.deletingLastPathComponent().path, IFUtility.temporaryDirectoryURL().path)
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: reports.path, isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
        XCTAssertEqual(testCases.baseReportURL.path, reports.appendingPathComponent("Inform-Report.html").path)
        XCTAssertEqual(testCases.reportURL(forTestCaseAt: 0).path,
                       reports.appendingPathComponent("Inform-Report-1.html").path)
        XCTAssertEqual(testCases.reportURL(forTestCaseAt: 1).path,
                       reports.appendingPathComponent("Inform-Report-2.html").path)
    }

    /// Two projects' test cases can be tested at the same time, so their reports mustn't overwrite each other's
    func testEachHasAFolderOfReportsOfItsOwn() {
        XCTAssertNotEqual(reportsFolder(of: IFExtensionTestCases()), reportsFolder(of: IFExtensionTestCases()))
    }

    /// intest finds each test case's report where it goes, from the base report's URL
    func testCombinesTheReportsWhereTheyGo() throws {
        let file = try makeExtension()
        let problems = try makeProblemsPage()
        let combined = try makeFolder().appendingPathComponent("Combined.html")
        let testCases = IFExtensionTestCases()
        _ = reportsFolder(of: testCases)
        for (index, testCase) in ["A", "B"].enumerated() {
            XCTAssertTrue(testCases.generateReport(forTestCase: testCase, ofExtension: file, errorCode: "right",
                                                   problemsURL: problems, skeinNodeId: 0, skeinNodes: 0,
                                                   outputURL: testCases.reportURL(forTestCaseAt: index)))
        }

        XCTAssertTrue(testCases.generateCombinedReport(forBaseInputURL: testCases.baseReportURL,
                                                       ofExtension: file, numTests: 2, outputURL: combined))

        let page = try String(contentsOf: combined, encoding: .utf8)
        XCTAssertTrue(page.contains("Lighthouse"))
        XCTAssertTrue(page.contains("Café"))
    }

    func testCombinesNoReports() throws {
        let file = try makeExtension()
        let folder = try makeFolder()

        XCTAssertFalse(IFExtensionTestCases().generateCombinedReport(
            forBaseInputURL: folder.appendingPathComponent("Inform-Report.html"), ofExtension: file, numTests: 0,
            outputURL: folder.appendingPathComponent("None.html")))
    }
}
