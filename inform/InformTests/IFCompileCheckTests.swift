//
//  IFCompileCheckTests.swift
//  InformTests
//

import XCTest

/// Whether a project needs compiling before its story is used
@MainActor
final class IFCompileCheckTests: XCTestCase {
    /// A project's source, settings and story, in a folder of the test's own
    private struct Files {
        let source: URL
        let settings: URL
        let output: URL
    }

    /// When the story was written
    private let compiled = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A source, settings and story, each written at the given time, or missing where the time is nil
    private func makeFiles(source: Date?, settings: Date?, output: Date?) throws -> Files {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }

        let files = Files(source: folder.appendingPathComponent("story.ni"),
                          settings: folder.appendingPathComponent("Settings.plist"),
                          output: folder.appendingPathComponent("output.ulx"))
        for (url, date) in [(files.source, source), (files.settings, settings), (files.output, output)] {
            guard let date else { continue }
            try Data("x".utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return files
    }

    /// Files whose story was written after its source and settings were last changed
    private func makeUpToDateFiles() throws -> Files {
        return try makeFiles(source: compiled - 60, settings: compiled - 120, output: compiled)
    }

    /// A check that has seen a compile succeed
    private func makeCompiledCheck() -> IFCompileCheck {
        let check = IFCompileCheck()
        check.compileDidSucceed()
        return check
    }

    private func needsCompile(_ check: IFCompileCheck,
                              _ files: Files,
                              force: Bool = false,
                              alwaysCompile: Bool = false,
                              unsavedChanges: Bool = false) -> Bool {
        return check.needsCompileForcing(force,
                                         alwaysCompile: alwaysCompile,
                                         unsavedChanges: unsavedChanges,
                                         sourceURL: files.source,
                                         settingsURL: files.settings,
                                         outputURL: files.output)
    }

    func testAnUpToDateStoryNeedsNoCompile() throws {
        XCTAssertFalse(needsCompile(makeCompiledCheck(), try makeUpToDateFiles()))
    }

    func testAStoryWrittenInTheSameSecondAsItsSourceNeedsNoCompile() throws {
        let files = try makeFiles(source: compiled, settings: compiled, output: compiled)

        XCTAssertFalse(needsCompile(makeCompiledCheck(), files))
    }

    func testTheFirstCompileCantBeSkipped() throws {
        // A new check doesn't know which test case the story is for
        XCTAssertTrue(needsCompile(IFCompileCheck(), try makeUpToDateFiles()))
    }

    func testAForcedCompileIsNeeded() throws {
        XCTAssertTrue(needsCompile(makeCompiledCheck(), try makeUpToDateFiles(), force: true))
    }

    func testTheAlwaysCompilePreferenceMeansACompileIsNeeded() throws {
        XCTAssertTrue(needsCompile(makeCompiledCheck(), try makeUpToDateFiles(), alwaysCompile: true))
    }

    func testUnsavedChangesMeanACompileIsNeeded() throws {
        XCTAssertTrue(needsCompile(makeCompiledCheck(), try makeUpToDateFiles(), unsavedChanges: true))
    }

    func testChangingTheTestCaseMeansACompileIsNeededUntilOneSucceeds() throws {
        let check = makeCompiledCheck()
        let files = try makeUpToDateFiles()

        check.testCaseDidChange()
        XCTAssertTrue(needsCompile(check, files))
        XCTAssertTrue(needsCompile(check, files), "asking doesn't count as compiling")

        check.compileDidSucceed()
        XCTAssertFalse(needsCompile(check, files))
    }

    func testAStoryMadeForReleaseIsntUsed() throws {
        // Go! after Release would run a story without the debugging commands or fixed random numbers
        let check = makeCompiledCheck()
        let files = try makeUpToDateFiles()

        check.compileDidStart(forRelease: true)
        check.compileDidSucceed()
        XCTAssertTrue(needsCompile(check, files))

        check.compileDidStart(forRelease: false)
        check.compileDidSucceed()
        XCTAssertFalse(needsCompile(check, files))
    }

    func testAStoryLeftByAFailedReleaseIsntUsed() throws {
        // A release that fails making its Blorb file has already written the story
        let check = makeCompiledCheck()

        check.compileDidStart(forRelease: true)

        XCTAssertTrue(needsCompile(check, try makeUpToDateFiles()))
    }

    func testAChangedSourceMeansACompileIsNeeded() throws {
        let files = try makeFiles(source: compiled + 1, settings: compiled - 120, output: compiled)

        XCTAssertTrue(needsCompile(makeCompiledCheck(), files))
    }

    func testChangedSettingsMeanACompileIsNeeded() throws {
        let files = try makeFiles(source: compiled - 60, settings: compiled + 1, output: compiled)

        XCTAssertTrue(needsCompile(makeCompiledCheck(), files))
    }

    func testAMissingStoryMeansACompileIsNeeded() throws {
        let files = try makeFiles(source: compiled - 60, settings: compiled - 120, output: nil)

        XCTAssertTrue(needsCompile(makeCompiledCheck(), files))
    }

    func testAMissingSourceOrSettingsMeansACompileIsNeeded() throws {
        let noSource   = try makeFiles(source: nil, settings: compiled - 120, output: compiled)
        let noSettings = try makeFiles(source: compiled - 60, settings: nil, output: compiled)

        XCTAssertTrue(needsCompile(makeCompiledCheck(), noSource))
        XCTAssertTrue(needsCompile(makeCompiledCheck(), noSettings))
    }
}
