//
//  IFCompilerTests.swift
//  InformTests
//

import XCTest

/// A problem handler that gives the page it's made with, and remembers the exit codes it's asked about
private final class StubProblemHandler: NSObject, IFCompilerProblemHandler {
    private let problemURL: URL?
    private(set) var errorCodes: [Int32] = []

    init(problemURL: URL?) {
        self.problemURL = problemURL
    }

    func urlForProblem(errorCode: Int32) -> URL? {
        errorCodes.append(errorCode)
        return problemURL
    }
}

/// A problem handler that has a page for success too
private final class StubSuccessHandler: NSObject, IFCompilerProblemHandler {
    func urlForProblem(errorCode: Int32) -> URL? {
        return URL(string: "inform:/Problem.html")
    }

    var urlForSuccess: URL? {
        return URL(string: "inform:/Success.html")
    }
}

/// A notification the compiler posted
private struct Posted {
    let name: NSNotification.Name
    let userInfo: [AnyHashable: Any]

    var string: String? { userInfo["string"] as? String }
    var style: String? { userInfo["style"] as? String }
    var exitCode: Int? { userInfo["exitCode"] as? Int }
    var problemType: Int? { userInfo["problemType"] as? Int }
}

@MainActor
final class IFCompilerTests: XCTestCase {

    /// A new folder, removed when the test ends
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A compiler with settings for a Glulx story
    private func makeCompiler() -> IFCompiler {
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 256
        let compiler = IFCompiler()
        compiler.settings = settings
        return compiler
    }

    /// A project with the given source, in a new folder, with what Inform puts in a new one
    private func makeProject(source: String) throws -> URL {
        let project = try makeFolder().appendingPathComponent("Lighthouse.inform")
        let sourceFolder = project.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("Build"), withIntermediateDirectories: true)
        try source.write(to: sourceFolder.appendingPathComponent("story.ni"), atomically: true, encoding: .utf8)
        try "\(UUID().uuidString)\n".write(to: project.appendingPathComponent("uuid.txt"), atomically: true, encoding: .utf8)
        return project
    }

    /// A compiler for the project, set up as IFProject sets one up
    private func makeCompiler(for project: URL) -> IFCompiler {
        let compiler = makeCompiler()
        compiler.outputFile = project.appendingPathComponent("Build/output.ulx").path
        compiler.inputFile = project.path
        compiler.directory = project.appendingPathComponent("Build").path
        return compiler
    }

    private func addShellStage(to compiler: IFCompiler, _ script: String, named name: String = "Test stage",
                               nextStageInput: String = "next", errorHandler: IFCompilerProblemHandler? = nil) {
        compiler.addCustomBuildStage("/bin/sh",
                                     withArguments: ["-c", script],
                                     nextStageInput: nextStageInput,
                                     errorHandler: errorHandler,
                                     named: name)
    }

    /// Runs the block, which starts the compiler, and returns what the compiler posts until it has finished
    private func run(_ compiler: IFCompiler, timeout: TimeInterval = 20, starting start: () -> Void) -> [Posted] {
        nonisolated(unsafe) var posted: [Posted] = []
        let names: [NSNotification.Name] = [.IFCompilerClearConsole, .IFCompilerStarting, .IFCompilerStdout,
                                            .IFCompilerStderr, .IFCompilerFinished]
        let observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: compiler, queue: nil) { notification in
                posted.append(Posted(name: notification.name, userInfo: notification.userInfo ?? [:]))
            }
        }
        defer { observers.forEach { NotificationCenter.default.removeObserver($0) } }

        let finished = expectation(forNotification: .IFCompilerFinished, object: compiler)
        start()
        wait(for: [finished], timeout: timeout)
        return posted
    }

    /// Prepares the compiler's stages, launches them, and returns what the compiler posts until it has finished
    private func launch(_ compiler: IFCompiler, blorb: Bool = false, timeout: TimeInterval = 20) -> [Posted] {
        return run(compiler, timeout: timeout) {
            XCTAssertTrue(compiler.prepareForLaunch(withBlorbStage: blorb, testCase: nil))
            compiler.launch()
        }
    }

    /// What the stages wrote to stdout
    private func output(_ posted: [Posted]) -> String {
        return posted.filter { $0.name == .IFCompilerStdout && $0.style == IFStyleBase }.compactMap(\.string).joined()
    }

    /// What the stages wrote to stderr
    private func errors(_ posted: [Posted]) -> String {
        return posted.filter { $0.name == .IFCompilerStderr }.compactMap(\.string).joined()
    }

    /// The command line of each stage launched, as the console shows it
    private func launches(_ posted: [Posted]) -> [String] {
        return posted.filter { $0.name == .IFCompilerStdout && $0.style == IFStyleLaunch }.compactMap(\.string)
    }

    private func finishes(_ posted: [Posted]) -> [Posted] {
        return posted.filter { $0.name == .IFCompilerFinished }
    }

    /// An argument as the console shows it
    private func quoted(_ argument: String) -> String {
        return argument.contains(" ") ? "\"\(argument)\"" : argument
    }

    // MARK: - Running stages

    func testRunsAStageAndTellsWhatItWrites() {
        let compiler = makeCompiler()
        let script = "printf 'out\\n'; printf 'err\\n' >&2"
        addShellStage(to: compiler, script)

        let posted = launch(compiler)

        XCTAssertEqual(posted.first?.name, .IFCompilerStarting)
        XCTAssertEqual(launches(posted), ["Launching: /bin/sh \\\n    -c \\\n    \"\(script)\"\n"])
        XCTAssertEqual(output(posted), "out\n")
        XCTAssertEqual(errors(posted), "err\n")
        XCTAssertEqual(posted.last?.name, .IFCompilerFinished)
        XCTAssertEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.none.rawValue))
        XCTAssertNil(compiler.problemsURL)
    }

    func testReadsWhatAStageWritesAsUTF8() {
        let compiler = makeCompiler()
        addShellStage(to: compiler, "printf 'Caf\\303\\251\\n'; printf 'Caf\\303\\251\\n' >&2")

        let posted = launch(compiler)

        XCTAssertEqual(output(posted), "Café\n")
        XCTAssertEqual(errors(posted), "Café\n")
    }

    func testReadsACharacterSplitBetweenReads() {
        let compiler = makeCompiler()
        addShellStage(to: compiler, "printf 'Caf\\303'; printf 'Caf\\303' >&2; sleep 0.3; printf '\\251\\n'; printf '\\251\\n' >&2")

        let posted = launch(compiler)

        XCTAssertEqual(output(posted), "Café\n")
        XCTAssertEqual(errors(posted), "Café\n")
    }

    func testReadsWhatIsntUTF8AsLatin1() {
        let compiler = makeCompiler()
        // The second ends with what would start a character in UTF-8
        addShellStage(to: compiler, "printf 'Caf\\351\\n'; printf 'Caf\\303' >&2")

        let posted = launch(compiler)

        XCTAssertEqual(output(posted), "Café\n")
        XCTAssertEqual(errors(posted), "Caf\u{C3}")
    }

    func testTellsWhileAStageIsRunning() {
        let compiler = makeCompiler()
        addShellStage(to: compiler, "sleep 0.5", named: "Sleeping")
        XCTAssertFalse(compiler.isRunning)

        _ = run(compiler) {
            XCTAssertTrue(compiler.prepareForLaunch(withBlorbStage: false, testCase: nil))
            XCTAssertEqual(compiler.progress.message, "Sleeping")
            XCTAssertFalse(compiler.isRunning)
            compiler.launch()
            XCTAssertTrue(compiler.isRunning)
            XCTAssertTrue(compiler.progress.isInProgress)
        }

        XCTAssertFalse(compiler.isRunning)
        XCTAssertFalse(compiler.progress.isInProgress)
    }

    func testRunsEachStageInTurn() throws {
        let log = try makeFolder().appendingPathComponent("log.txt").path
        let compiler = makeCompiler()
        compiler.inputFile = "input"
        XCTAssertEqual(compiler.currentStageInput, "input")
        for stage in 1...3 {
            addShellStage(to: compiler, "printf \(stage) >> '\(log)'", named: "Stage \(stage)", nextStageInput: "input \(stage)")
        }
        XCTAssertEqual(compiler.currentStageInput, "input 3")

        let posted = launch(compiler)

        XCTAssertEqual(try String(contentsOfFile: log, encoding: .utf8), "123")
        XCTAssertEqual(posted.filter { $0.name == .IFCompilerStarting }.count, 1)
        XCTAssertEqual(launches(posted).count, 3)
        XCTAssertEqual(finishes(posted).count, 1)
        XCTAssertEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(compiler.progress.message, "Stage 3")
        XCTAssertEqual(compiler.currentStageInput, "input")
    }

    func testRunsAStageInTheBuildFolder() throws {
        let folder = try makeFolder()
        let compiler = makeCompiler()
        addShellStage(to: compiler, "pwd -P")
        compiler.directory = folder.path

        let posted = launch(compiler)

        let workingFolder = output(posted).trimmingCharacters(in: .newlines)
        XCTAssertEqual(URL(fileURLWithPath: workingFolder).resolvingSymlinksInPath(), folder.resolvingSymlinksInPath())
    }

    func testStopsAtTheFirstStageThatFails() throws {
        let marker = try makeFolder().appendingPathComponent("ran.txt").path
        let compiler = makeCompiler()
        let handler = StubProblemHandler(problemURL: URL(string: "inform:/Problem.html"))
        addShellStage(to: compiler, "exit 3", named: "Failing", errorHandler: handler)
        addShellStage(to: compiler, "touch '\(marker)'")

        let posted = launch(compiler)

        XCTAssertEqual(launches(posted).count, 1)
        XCTAssertEqual(finishes(posted).count, 1)
        XCTAssertEqual(posted.last?.exitCode, 3)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.unknown.rawValue))
        XCTAssertEqual(handler.errorCodes, [3])
        XCTAssertEqual(compiler.problemsURL, URL(string: "inform:/Problem.html"))
        XCTAssertEqual(compiler.progress.message, "Error code 3")
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker))
        XCTAssertFalse(compiler.isRunning)

        // The stages after it are forgotten, and the problem with them
        addShellStage(to: compiler, "exit 0")
        let next = launch(compiler)
        XCTAssertEqual(launches(next).count, 1)
        XCTAssertEqual(next.last?.exitCode, 0)
        XCTAssertNil(compiler.problemsURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker))
    }

    func testGivesTheLastStagesProblemsPage() {
        let compiler = makeCompiler()
        let handler = StubProblemHandler(problemURL: URL(string: "inform:/Problem.html"))
        addShellStage(to: compiler, "exit 2", named: "Failing", errorHandler: handler)

        let posted = launch(compiler)

        XCTAssertEqual(posted.last?.exitCode, 2)
        XCTAssertEqual(handler.errorCodes, [2])
        XCTAssertEqual(compiler.problemsURL, URL(string: "inform:/Problem.html"))
        // The last stage's message isn't replaced by its error code
        XCTAssertEqual(compiler.progress.message, "Failing")
    }

    func testGivesTheLastStagesPageForSuccess() {
        let compiler = makeCompiler()
        addShellStage(to: compiler, "exit 0", errorHandler: StubSuccessHandler())
        _ = launch(compiler)
        XCTAssertEqual(compiler.problemsURL, URL(string: "inform:/Success.html"))

        // A handler with no page for success gives none
        let handler = StubProblemHandler(problemURL: URL(string: "inform:/Problem.html"))
        addShellStage(to: compiler, "exit 0", errorHandler: handler)
        _ = launch(compiler)
        XCTAssertNil(compiler.problemsURL)
        XCTAssertEqual(handler.errorCodes, [])
    }

    func testShowsTheEndTextOnceFinished() {
        let compiler = makeCompiler()
        addShellStage(to: compiler, "exit 0")

        _ = run(compiler) {
            XCTAssertTrue(compiler.prepareForLaunch(withBlorbStage: false, testCase: nil))
            compiler.endTextString = "All done"
            compiler.launch()
        }

        XCTAssertEqual(compiler.progress.message, "All done")
        XCTAssertNil(compiler.endTextString)
    }

    func testClearsTheConsole() {
        let compiler = IFCompiler()
        let cleared = expectation(forNotification: .IFCompilerClearConsole, object: compiler)

        compiler.clearConsole()

        wait(for: [cleared], timeout: 1)
    }

    func testSendsTextAsIfACompilerWroteIt() {
        let compiler = IFCompiler()
        nonisolated(unsafe) var userInfo: [AnyHashable: Any]?
        let observer = NotificationCenter.default.addObserver(forName: .IFCompilerStdout, object: compiler, queue: nil) {
            userInfo = $0.userInfo
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        compiler.sendStdOut("Hello", withStyle: IFStyleProgress)

        XCTAssertEqual(userInfo?["string"] as? String, "Hello")
        XCTAssertEqual(userInfo?["style"] as? String, IFStyleProgress)
    }

    // MARK: - The output file

    func testMakesATemporaryOutputFile() throws {
        var path = ""
        try autoreleasepool {
            let compiler = makeCompiler()
            path = compiler.outputFile
            XCTAssertEqual((path as NSString).deletingLastPathComponent, (NSTemporaryDirectory() as NSString).standardizingPath)
            XCTAssertTrue((path as NSString).lastPathComponent.hasPrefix("Inform-"))
            XCTAssertEqual((path as NSString).pathExtension, "ulx")
            XCTAssertEqual(compiler.outputFile, path)
            try Data().write(to: URL(fileURLWithPath: path))
        }

        // It's deleted with the compiler
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testKeepsAnOutputFileItsGiven() throws {
        let file = try makeFolder().appendingPathComponent("output.ulx")
        try Data().write(to: file)

        autoreleasepool {
            let compiler = makeCompiler()
            compiler.outputFile = file.path
            XCTAssertEqual(compiler.outputFile, file.path)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeletesItsOutputWhenAsked() throws {
        let file = try makeFolder().appendingPathComponent("output.ulx")
        try Data().write(to: file)
        let compiler = makeCompiler()
        compiler.outputFile = file.path

        compiler.deleteOutput()

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        // And makes a temporary file next
        XCTAssertNotEqual(compiler.outputFile, file.path)
    }

    func testDeletesItsTemporaryOutputBeforeEachRun() throws {
        let compiler = makeCompiler()
        let path: String = compiler.outputFile
        try Data().write(to: URL(fileURLWithPath: path))
        addShellStage(to: compiler, "exit 0")

        _ = launch(compiler)

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Inform's stages

    /// The command line that Inform 7 is launched with, for the given settings
    private func inform7Launch(testCase: String? = "",
                               setUp: (IFCompiler, IFCompilerSettings) -> Void = { _, _ in }) -> String {
        let compiler = makeCompiler()
        compiler.inputFile = "/Missing/Lighthouse.inform"
        setUp(compiler, compiler.settings!)
        compiler.addNaturalInformStage(usingTestCase: testCase)
        XCTAssertEqual(compiler.currentStageInput, "/Missing/Lighthouse.inform/Build/auto.inf")

        // As when only the index is refreshed: the stage added first is the only one
        let posted = launch(compiler)

        XCTAssertEqual(launches(posted).count, 1)
        XCTAssertNotEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.inform7.rawValue))
        return launches(posted).first ?? ""
    }

    func testGivesInform7ItsArguments() {
        let settings = IFCompilerSettings()
        let launch = inform7Launch()

        let arguments = settings.naturalInformCommandLineArguments
            + ["-project", "/Missing/Lighthouse.inform", "-format=Inform6/32d"]
        XCTAssertEqual(launch, "Launching: \(quoted(settings.naturalInformCompilerToUse!))"
                       + arguments.map { " \\\n    \(quoted($0))" }.joined() + "\n")
    }

    func testGivesInform7TheOptionsChosen() {
        XCTAssertTrue(inform7Launch(testCase: "B").hasSuffix(" \\\n    -case \\\n    B\n"))
        XCTAssertTrue(inform7Launch { _, settings in settings.zcodeVersion = 8 }.contains(" \\\n    -format=Inform6/16d"))
        XCTAssertTrue(inform7Launch { _, settings in settings.nobbleRng = true }.hasSuffix(" \\\n    -rng\n"))
        XCTAssertTrue(inform7Launch { _, settings in settings.basicInform = true }.hasSuffix(" \\\n    -basic\n"))

        let release = inform7Launch(testCase: "B") { compiler, settings in
            compiler.setBuild(forRelease: true, forTesting: false)
            settings.nobbleRng = true
        }
        XCTAssertTrue(release.hasSuffix(" \\\n    -format=Inform6/32 \\\n    -release \\\n    -case \\\n    B\n"))

        let releaseForTesting = inform7Launch { compiler, _ in compiler.setBuild(forRelease: true, forTesting: true) }
        XCTAssertTrue(releaseForTesting.hasSuffix(" \\\n    -format=Inform6/32\n"))
    }

    func testGivesAnOlderInform7ItsOwnFormat() {
        let launch = inform7Launch { _, settings in settings.compilerVersion = "6M62" }

        XCTAssertTrue(launch.contains("/6M62/"))
        XCTAssertTrue(launch.hasSuffix(" \\\n    -project \\\n    /Missing/Lighthouse.inform \\\n    -format=ulx\n"))
    }

    func testGivesInform6ItsArguments() {
        let compiler = makeCompiler()
        compiler.inputFile = "/Missing/Lighthouse.inform"
        compiler.outputFile = "/Missing/output.ulx"
        compiler.addStandardInformStage()
        XCTAssertEqual(compiler.currentStageInput, "/Missing/output.ulx")

        let posted = launch(compiler)

        let settings = compiler.settings!
        let arguments = settings.commandLineArguments(forRelease: false, forTesting: false)
            + ["/Missing/Lighthouse.inform", "/Missing/output.ulx"]
        XCTAssertEqual(launches(posted), ["Launching: \(quoted(settings.inform6CompilerToUse!))"
                                          + arguments.map { " \\\n    \(quoted($0))" }.joined() + "\n"])
        XCTAssertNotEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.inform6.rawValue))
    }

    func testGivesInform6ATemporaryOutputFile() {
        let compiler = makeCompiler()
        compiler.inputFile = "/Missing/Lighthouse.inform"

        compiler.addStandardInformStage()

        XCTAssertEqual(compiler.currentStageInput, compiler.outputFile)
        XCTAssertTrue(compiler.outputFile.hasPrefix((NSTemporaryDirectory() as NSString).standardizingPath))
    }

    func testCompilesAProject() throws {
        try XCTSkipIf(IFPreferences.shared.runBuildSh, "The build.sh preference adds a stage")
        let project = try makeProject(source: "\"Lighthouse\" by Jane Doe\n\nThe Lamp Room is a room.\n")
        let compiler = makeCompiler(for: project)

        let posted = launch(compiler, timeout: 120)

        XCTAssertEqual(launches(posted).count, 2)
        XCTAssertEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.none.rawValue))
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.appendingPathComponent("Build/output.ulx").path))
        XCTAssertNil(compiler.problemsURL)
    }

    func testTellsOfAnInform7Problem() throws {
        try XCTSkipIf(IFPreferences.shared.runBuildSh, "The build.sh preference adds a stage")
        let project = try makeProject(source: "\"Lighthouse\" by Jane Doe\n\nThe Lamp Room is a room. The Lamp Room is a container.\n")
        let compiler = makeCompiler(for: project)

        let posted = launch(compiler, timeout: 120)

        // Inform 6 isn't run
        XCTAssertEqual(launches(posted).count, 1)
        XCTAssertEqual(posted.last?.exitCode, 1)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.inform7.rawValue))
        // The project's own problems page is shown
        XCTAssertNil(compiler.problemsURL)
        XCTAssertEqual(compiler.progress.message, "Error code 1")
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.appendingPathComponent("Build/output.ulx").path))
    }

    func testMakesABlorbFileForRelease() throws {
        try XCTSkipIf(IFPreferences.shared.runBuildSh, "The build.sh preference adds a stage")
        let project = try makeProject(source: "\"Lighthouse\" by Jane Doe\n\nThe Lamp Room is a room.\n")
        let compiler = makeCompiler(for: project)
        compiler.setBuild(forRelease: true, forTesting: false)

        let posted = launch(compiler, blorb: true, timeout: 120)

        XCTAssertEqual(launches(posted).count, 3)
        XCTAssertEqual(posted.last?.exitCode, 0)
        let blorb = project.appendingPathComponent("Build/output.gblorb").path
        XCTAssertEqual(compiler.outputFile, blorb)
        XCTAssertTrue(FileManager.default.fileExists(atPath: blorb))
        XCTAssertEqual(compiler.problemsURL?.lastPathComponent, "StatusCblorb.html")
    }

    func testRunsIntest() throws {
        let compiler = makeCompiler()
        let settings = compiler.settings!

        let posted = run(compiler) {
            XCTAssertTrue(compiler.launchWith(inTestStage: "/Missing/Lighthouse.i7xp", command: "-test", testCase: "A"))
        }

        let results = IFUtility.temporaryDirectoryURL().appendingPathComponent("intest_results.html").path
        let workspace = IFUtility.temporaryDirectoryURL().appendingPathComponent("InTestWorkspace").path
        let version: String = settings.compilerVersion
        let arguments = ["/Missing/Lighthouse.i7xp",
                         "-internal", IFUtility.path(forInformInternalAppSupport: version),
                         "-results", results,
                         "-set", "I7COMPILER = \(IFUtility.path(forCompiler: version) ?? "")",
                         "-set", "I6COMPILER = \(IFUtility.path(forInformExecutable: "inform6", version: version) ?? "")",
                         "-set", "GINTERPRETER = \(IFUtility.path(forInformExecutable: "glulxe", version: version) ?? "")",
                         "-set", "ZINTERPRETER = \(IFUtility.path(forInformExecutable: "dumb-frotz", version: version) ?? "")",
                         "-workspace", workspace,
                         "-test", "A"]
        let intest = IFUtility.path(forInformExecutable: "intest", version: "") ?? ""
        XCTAssertEqual(posted.first?.name, .IFCompilerStarting)
        XCTAssertEqual(posted.filter { $0.name == .IFCompilerStarting }.count, 1)
        XCTAssertEqual(launches(posted), ["Launching: \(quoted(intest))" + arguments.map { " \\\n    \(quoted($0))" }.joined() + "\n"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace))
        XCTAssertEqual(compiler.outputFile, results)
        XCTAssertNotEqual(posted.last?.exitCode, 0)
        XCTAssertEqual(posted.last?.problemType, Int(ECompilerProblemType.unknown.rawValue))
        XCTAssertEqual(compiler.problemsURL?.path, results)
    }
}
