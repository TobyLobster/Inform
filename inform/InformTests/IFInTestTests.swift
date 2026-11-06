//
//  IFInTestTests.swift
//  InformTests
//

import XCTest

final class IFInTestTests: XCTestCase {

    private let lighthouse = """
        Example: * Lighthouse - A lamp at the top of a tower.

        \t*: "Lighthouse"

        \tInclude Lamplighting by Jane Doe.

        \tThe Lamp Room is a room. The great lamp is a lamp in the Lamp Room.

        \tTest me with "look / x lamp".


        """

    private let cafe = """
        Example: ** Café - A lamp in a café.

        \t*: "Café"

        \tInclude Lamplighting by Jane Doe.

        \tThe Café is a room.

        \tTest me with "look".


        """

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// An extension project in a new folder, whose documentation has the given examples.
    /// Returns the path of its extension, as IFProject gives it.
    private func makeExtensionProject(examples: [String]) throws -> String {
        let source = try makeFolder()
            .appendingPathComponent("Lamplighting.i7xp")
            .appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let text = "Lamplighting by Jane Doe begins here.\n\nA lamp is a kind of thing.\n\nLamplighting ends here.\n\n"
            + "---- DOCUMENTATION ----\n\nLamps can be lit.\n\n" + examples.joined()
        let file = source.appendingPathComponent("extension.i7x")
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file.path
    }

    /// A page with the markers intest looks for in the problems page it's given
    private func makeProblemsPage(in folder: URL) throws -> URL {
        let page = folder.appendingPathComponent("Problems.html")
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

    private func lines(of path: String) throws -> [String] {
        return try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: "\n")
    }

    private func occurrences(of text: String, in page: String) -> Int {
        return page.components(separatedBy: text).count - 1
    }

    // MARK: - The catalogue

    func testListsTheExamplesAsTestCases() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])

        let testCases = IFInTest().refreshExtensionCatalogue(file)

        XCTAssertEqual(testCases.map { $0["testKey"] as? String }, ["A", "B"])
        XCTAssertEqual(testCases.map { $0["testTitle"] as? String }, ["Lighthouse", "Café"])
    }

    func testListsAnExampleWithoutAStoryTitle() throws {
        // intest gives no title for an example whose source doesn't start with one
        let shed = """
            Example: * Shed - A lamp in a shed.

            \t*: Include Lamplighting by Jane Doe.

            \tThe Shed is a room.

            \tTest me with "look".


            """
        let file = try makeExtensionProject(examples: [lighthouse, shed, cafe])

        let testCases = IFInTest().refreshExtensionCatalogue(file)

        XCTAssertEqual(testCases.map { $0["testKey"] as? String }, ["A", "B", "C"])
        XCTAssertEqual(testCases.map { $0["testTitle"] as? String }, ["Lighthouse", "Example B", "Café"])
    }

    func testListsNoTestCasesForAnExtensionWithoutExamples() throws {
        let file = try makeExtensionProject(examples: [])

        XCTAssertEqual(IFInTest().refreshExtensionCatalogue(file).count, 0)
    }

    func testListsNoTestCasesWhenIntestFails() throws {
        let file = try makeFolder().appendingPathComponent("Missing.i7xp/Source/extension.i7x").path

        XCTAssertEqual(IFInTest().refreshExtensionCatalogue(file).count, 0)
    }

    // MARK: - Source and line numbers

    func testWritesTheSourceOfATestCase() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let sourceFile = try makeFolder().appendingPathComponent("story.ni").path

        IFInTest().extractSourceTask(forExtensionFile: file, forTestCase: "B", outputToSourceFile: sourceFile)

        let source = try lines(of: sourceFile)
        XCTAssertEqual(source.first, "\"Café\"")
        XCTAssertTrue(source.contains("The Café is a room."))
        XCTAssertFalse(source.contains { $0.contains("Lamp Room") })
    }

    func testGivesTheExtensionLineOfEachTestCaseLine() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let folder = try makeFolder()
        let extensionLines = try lines(of: file)
        let inTest = IFInTest()

        for (testCase, line) in [("A", "The Lamp Room is a room. The great lamp is a lamp in the Lamp Room."),
                                 ("B", "The Café is a room.")] {
            let sourceFile = folder.appendingPathComponent("\(testCase).ni").path
            inTest.extractSourceTask(forExtensionFile: file, forTestCase: testCase, outputToSourceFile: sourceFile)

            // Line 5 of each test case's source, after the title, a blank line, the Include and a blank line
            XCTAssertEqual(try lines(of: sourceFile)[4], line)
            let extensionLine = Int(inTest.adjustLine(5, forTestCase: testCase))
            XCTAssertEqual(extensionLines[extensionLine - 1], "\t" + line, testCase)
        }
    }

    func testLeavesTheLinesOfOtherTestCasesAlone() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let sourceFile = try makeFolder().appendingPathComponent("story.ni").path
        let inTest = IFInTest()

        XCTAssertEqual(inTest.adjustLine(5, forTestCase: "A"), 5)

        inTest.extractSourceTask(forExtensionFile: file, forTestCase: "A", outputToSourceFile: sourceFile)
        XCTAssertNotEqual(inTest.adjustLine(5, forTestCase: "A"), 5)
        XCTAssertEqual(inTest.adjustLine(5, forTestCase: "B"), 5)
    }

    func testForgetsATestCasesLinesWhenIntestFails() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let sourceFile = try makeFolder().appendingPathComponent("story.ni").path
        let inTest = IFInTest()
        inTest.extractSourceTask(forExtensionFile: file, forTestCase: "A", outputToSourceFile: sourceFile)
        XCTAssertNotEqual(inTest.adjustLine(5, forTestCase: "A"), 5)

        try FileManager.default.removeItem(atPath: file)
        inTest.extractSourceTask(forExtensionFile: file, forTestCase: "A", outputToSourceFile: sourceFile)

        XCTAssertEqual(inTest.adjustLine(5, forTestCase: "A"), 5)
    }

    // MARK: - Test commands

    func testGivesTheCommandsOfATestCase() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let inTest = IFInTest()

        XCTAssertEqual(inTest.testCommands(forExtension: file, testCase: "A"), "look\nx lamp\n")
        XCTAssertEqual(inTest.testCommands(forExtension: file, testCase: "B"), "look\n")
        XCTAssertNil(inTest.testCommands(forExtension: file, testCase: "C"))
    }

    // MARK: - Reports

    func testWritesAReport() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let folder = try makeFolder()
        let report = folder.appendingPathComponent("Report-1.html")

        let exitCode = IFInTest().generateReport(forExtension: file,
                                                 testCase: "A",
                                                 errorCode: "right",
                                                 problemsURL: try makeProblemsPage(in: folder),
                                                 skeinNodeId: 42,
                                                 skeinNodes: 2,
                                                 outputURL: report)

        XCTAssertEqual(exitCode, 0)
        let page = try String(contentsOf: report, encoding: .utf8)
        XCTAssertTrue(page.contains("Example A: &#8216;Lighthouse&#8217;: Succeeded"))
        XCTAssertTrue(page.contains("skein:42?case=A"))
        XCTAssertTrue(page.contains("Transcript of play (2 turns)"))
        XCTAssertFalse(page.contains("Old heading"))
    }

    func testWritesNoReportForAnOutcomeIntestDoesntKnow() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let folder = try makeFolder()
        let report = folder.appendingPathComponent("Report-1.html")

        let exitCode = IFInTest().generateReport(forExtension: file,
                                                 testCase: "A",
                                                 errorCode: "maybe",
                                                 problemsURL: try makeProblemsPage(in: folder),
                                                 skeinNodeId: 0,
                                                 skeinNodes: 0,
                                                 outputURL: report)

        XCTAssertNotEqual(exitCode, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: report.path))
    }

    func testCombinesReports() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let folder = try makeFolder()
        let problems = try makeProblemsPage(in: folder)
        let combined = folder.appendingPathComponent("Combined.html")
        let inTest = IFInTest()
        // Named as IFProject's report URLs are
        for (index, (testCase, outcome)) in [("A", "right"), ("B", "i7")].enumerated() {
            XCTAssertEqual(inTest.generateReport(forExtension: file,
                                                 testCase: testCase,
                                                 errorCode: outcome,
                                                 problemsURL: problems,
                                                 skeinNodeId: 0,
                                                 skeinNodes: 0,
                                                 outputURL: folder.appendingPathComponent("Inform-Report-\(index + 1).html")), 0)
        }

        let exitCode = inTest.generateCombinedReport(forExtension: file,
                                                     baseInputURL: folder.appendingPathComponent("Inform-Report.html"),
                                                     numTests: 2,
                                                     outputURL: combined)

        XCTAssertEqual(exitCode, 0)
        let page = try String(contentsOf: combined, encoding: .utf8)
        XCTAssertEqual(occurrences(of: "Example A: &#8216;Lighthouse&#8217;: Succeeded", in: page), 1)
        XCTAssertEqual(occurrences(of: "Example B: &#8216;Café&#8217;: Couldn't Test", in: page), 1)
        XCTAssertEqual(occurrences(of: "<html>", in: page), 1)
        XCTAssertEqual(occurrences(of: "</html>", in: page), 1)
    }

    func testCombinesNoReportsForNoTests() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let folder = try makeFolder()
        let combined = folder.appendingPathComponent("Combined.html")

        let exitCode = IFInTest().generateCombinedReport(forExtension: file,
                                                         baseInputURL: folder.appendingPathComponent("Inform-Report.html"),
                                                         numTests: 0,
                                                         outputURL: combined)

        XCTAssertNotEqual(exitCode, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: combined.path))
    }

    // MARK: - Notifications

    /// Runs the block, and returns the user info of each notification the IFInTest posts meanwhile
    private func notifications(from inTest: IFInTest, during block: () -> Void) -> [(NSNotification.Name, [AnyHashable: Any])] {
        var posted: [(NSNotification.Name, [AnyHashable: Any])] = []
        let names: [NSNotification.Name] = [.IFInTestStarting, .IFInTestStdout, .IFInTestStderr, .IFInTestFinished]
        let observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: inTest, queue: nil) { notification in
                posted.append((notification.name, notification.userInfo ?? [:]))
            }
        }
        block()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        return posted
    }

    func testTellsWhatIntestIsDoing() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let project = ((file as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        let inTest = IFInTest()

        let posted = notifications(from: inTest) {
            _ = inTest.refreshExtensionCatalogue(file)
        }

        XCTAssertEqual(posted.map { $0.0 }, [.IFInTestStarting, .IFInTestStdout, .IFInTestStderr, .IFInTestFinished])
        guard posted.count == 4 else { return }
        XCTAssertEqual(posted[0].1["command"] as? String, IFUtility.path(forInformExecutable: "intest", version: ""))
        XCTAssertEqual(posted[0].1["args"] as? [String],
                       [project, "-no-history", "-threads=1", "-using", "-extension", file, "-do", "-catalogue"])
        XCTAssertEqual(posted[1].1["string"] as? String,
                       "extension Example A = Lighthouse\nextension Example B = Café\n")
        XCTAssertEqual(posted[2].1["string"] as? String, "")
        XCTAssertEqual(posted[3].1["exitCode"] as? Int, 0)
    }

    func testTellsWhenIntestFails() throws {
        let file = try makeExtensionProject(examples: [lighthouse, cafe])
        let inTest = IFInTest()

        let posted = notifications(from: inTest) {
            _ = inTest.testCommands(forExtension: file, testCase: "C")
        }

        XCTAssertEqual(posted.map { $0.0 }, [.IFInTestStarting, .IFInTestStdout, .IFInTestStderr, .IFInTestFinished])
        guard posted.count == 4 else { return }
        XCTAssertEqual(posted[1].1["string"] as? String, "")
        XCTAssertEqual(posted[2].1["string"] as? String, "intest: fatal error: unable to find any such extension example\n")
        XCTAssertEqual(posted[3].1["exitCode"] as? Int, 2)
    }
}
