//
//  IFTestCaseRunTests.swift
//  InformTests
//

import XCTest

/// Test's run through an extension project's test cases
@MainActor
final class IFTestCaseRunTests: XCTestCase {
    func testANewRunIsBetweenRuns() {
        let run = IFTestCaseRun()

        XCTAssertEqual(run.currentIndex, -1)
        XCTAssertFalse(run.isOnALaterTestCase)
        XCTAssertFalse(run.isOnTheLastTestCase)
        XCTAssertEqual(run.numberTested, 0)
    }

    func testTestAllGoesThroughEachTestCaseInTurn() {
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 0, to: 2)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 0)
        XCTAssertFalse(run.isOnALaterTestCase)
        XCTAssertFalse(run.isOnTheLastTestCase)
        XCTAssertFalse(run.isPastTheLastTestCase)
        XCTAssertEqual(run.numberStarted, 1)
        XCTAssertEqual(run.numberInRun, 3)
        XCTAssertEqual(run.percentageStarted, 100.0 / 3.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 1)
        XCTAssertTrue(run.isOnALaterTestCase)
        XCTAssertFalse(run.isOnTheLastTestCase)
        XCTAssertEqual(run.numberStarted, 2)
        XCTAssertEqual(run.percentageStarted, 200.0 / 3.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 2)
        XCTAssertTrue(run.isOnTheLastTestCase)
        XCTAssertFalse(run.isPastTheLastTestCase)
        XCTAssertEqual(run.percentageStarted, 100.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertFalse(run.isOnTheLastTestCase)
        XCTAssertTrue(run.isPastTheLastTestCase)

        run.finish()
        XCTAssertEqual(run.currentIndex, -1)
        XCTAssertEqual(run.numberTested, 3)
    }

    func testARunOfTheChosenTestCase() {
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 2, to: 2)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 2)
        XCTAssertTrue(run.isOnTheLastTestCase)
        XCTAssertFalse(run.isPastTheLastTestCase)
        XCTAssertEqual(run.numberStarted, 1)
        XCTAssertEqual(run.numberInRun, 1)
        XCTAssertEqual(run.percentageStarted, 100.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertTrue(run.isPastTheLastTestCase)

        run.finish()
        XCTAssertEqual(run.currentIndex, -1)
        XCTAssertEqual(run.numberTested, 1)
    }

    func testTheChosenTestCaseIsntALaterOne() {
        // So its compile clears the console, as the first of Test All's does
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 2, to: 2)

        run.moveToNextTestCase()

        XCTAssertFalse(run.isOnALaterTestCase)
    }

    func testFinishingCountsTheTestCasesMovedPast() {
        // As when the run is cancelled while a test case compiles
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 0, to: 2)
        run.moveToNextTestCase()
        run.moveToNextTestCase()

        run.finish()

        XCTAssertEqual(run.numberTested, 1)
    }

    func testTheNextRunStartsAtItsFirstTestCase() {
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 0, to: 2)
        run.moveToNextTestCase()
        run.moveToNextTestCase()
        run.finish()

        run.chooseTestCases(from: 1, to: 1)
        run.moveToNextTestCase()

        XCTAssertEqual(run.currentIndex, 1)
        XCTAssertEqual(run.numberStarted, 1)
    }

    // MARK: - Stepping through the test cases

    /// A run with a delegate that has the test cases given
    private func makeRun(testCases: [String],
                         from first: Int32,
                         to last: Int32) -> (IFTestCaseRun, RecordingRunDelegate) {
        let delegate = RecordingRunDelegate(testCases: testCases)
        let run = IFTestCaseRun()
        run.delegate = delegate
        run.chooseTestCases(from: first, to: last)
        return (run, delegate)
    }

    /// Where a test case's report would be
    private func report(_ index: Int) -> URL {
        return URL(fileURLWithPath: "/Reports/Report\(index).html")
    }

    /// Lets timers fire until the condition holds, for up to five seconds
    private func runTheRunLoop(until condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: 5)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    func testTestAllTestsEachTestCaseOnceTheOneBeforeHasBeenPlayed() {
        let (run, delegate) = makeRun(testCases: ["a", "b", "c"], from: 0, to: 2)

        XCTAssertTrue(run.startNextTestCase())
        run.testCaseWasPlayed(withReport: report(0))
        run.testCaseWasPlayed(withReport: report(1))
        run.testCaseWasPlayed(withReport: report(2))

        XCTAssertEqual(delegate.events, ["test 0, 1 of 3",
                                         "test 1, 2 of 3",
                                         "test 2, 3 of 3",
                                         "finished at -1, 3 tested",
                                         "report on 3 from Report2.html"])
    }

    func testTheChosenTestCasesReportIsShownOnceItsBeenPlayed() {
        let (run, delegate) = makeRun(testCases: ["a", "b", "c"], from: 1, to: 1)

        run.startNextTestCase()
        run.testCaseWasPlayed(withReport: report(1))

        XCTAssertEqual(delegate.events, ["test 1, 1 of 1",
                                         "finished at -1, 1 tested",
                                         "report on 1 from Report1.html"])
    }

    func testTheReportIsShownOnceTheLastTestCaseIsPlayedThoughItHasNoReportOfItsOwn() {
        let (run, delegate) = makeRun(testCases: ["a"], from: 0, to: 0)

        run.startNextTestCase()
        run.testCaseWasPlayed(withReport: nil)

        XCTAssertEqual(delegate.events.last, "report on 1 from none")
    }

    func testTheTestCaseAfterOneThatDidntCompileIsTestedOnceTheCompilerIsDone() {
        let (run, delegate) = makeRun(testCases: ["a", "b"], from: 0, to: 1)
        run.startNextTestCase()

        run.testCaseDidntCompile(withReport: report(0))

        // Not while the compiler is still finishing
        XCTAssertEqual(delegate.events, ["test 0, 1 of 2"])

        runTheRunLoop { delegate.events.count > 1 }
        XCTAssertEqual(delegate.events, ["test 0, 1 of 2",
                                         "test 1, 2 of 2"])
    }

    func testTheRunEndsAtOnceWithItsReportWhenTheLastTestCaseDoesntCompile() {
        let (run, delegate) = makeRun(testCases: ["a", "b"], from: 0, to: 1)
        run.startNextTestCase()
        run.testCaseWasPlayed(withReport: report(0))

        run.testCaseDidntCompile(withReport: report(1))

        XCTAssertEqual(delegate.events, ["test 0, 1 of 2",
                                         "test 1, 2 of 2",
                                         "finished at -1, 2 tested",
                                         "report on 2 from Report1.html"])
    }

    func testNoReportIsShownWhenTheLastTestCaseDoesntCompileAndHasNone() {
        let (run, delegate) = makeRun(testCases: ["a"], from: 0, to: 0)
        run.startNextTestCase()

        run.testCaseDidntCompile(withReport: nil)

        XCTAssertEqual(delegate.events, ["test 0, 1 of 1",
                                         "finished at -1, 1 tested"])
    }

    func testACancelledRunEndsBeforeItsNextTestCaseWithNoReport() {
        let (run, delegate) = makeRun(testCases: ["a", "b", "c"], from: 0, to: 2)
        run.startNextTestCase()

        delegate.isCancelled = true
        run.testCaseWasPlayed(withReport: report(0))

        XCTAssertEqual(delegate.events, ["test 0, 1 of 3",
                                         "finished at -1, 1 tested"])
    }

    func testARunCancelledAsATestCaseDidntCompileEndsWithNoReport() {
        let (run, delegate) = makeRun(testCases: ["a", "b", "c"], from: 0, to: 2)
        run.startNextTestCase()

        delegate.isCancelled = true
        run.testCaseDidntCompile(withReport: report(0))

        // The test case that didn't compile isn't counted, as the run hadn't moved past it
        XCTAssertEqual(delegate.events, ["test 0, 1 of 3",
                                         "finished at -1, 0 tested"])
    }

    func testTheRunEndsAtATestCaseTheDelegateDoesntHave() {
        let (run, delegate) = makeRun(testCases: ["a"], from: 0, to: 2)
        run.startNextTestCase()

        run.testCaseWasPlayed(withReport: report(0))

        XCTAssertEqual(delegate.events, ["test 0, 1 of 3",
                                         "finished at -1, 1 tested",
                                         "report on 1 from Report0.html"])
    }

    func testTestAllWithNoTestCasesEndsAtOnce() {
        // Test All chooses from the first to one before it
        let (run, delegate) = makeRun(testCases: [], from: 0, to: -1)

        XCTAssertFalse(run.startNextTestCase())

        XCTAssertEqual(delegate.events, ["finished at -1, 0 tested"])
    }
}

/// The project controller, for a run to ask: it has the test cases given, and notes what it's asked to do
@MainActor
private final class RecordingRunDelegate: NSObject, IFTestCaseRunDelegate {
    let testCases: [String]
    var isCancelled = false
    var events: [String] = []

    init(testCases: [String]) {
        self.testCases = testCases
    }

    func testCaseRun(_ run: IFTestCaseRun, testCaseAt index: Int32) -> String? {
        return testCases.indices.contains(Int(index)) ? testCases[Int(index)] : nil
    }

    func testCaseRunIsCancelled(_ run: IFTestCaseRun) -> Bool {
        return isCancelled
    }

    func testCaseRunTestsCurrentTestCase(_ run: IFTestCaseRun) {
        events.append("test \(run.currentIndex), \(run.numberStarted) of \(run.numberInRun)")
    }

    func testCaseRunDidFinish(_ run: IFTestCaseRun) {
        events.append("finished at \(run.currentIndex), \(run.numberTested) tested")
    }

    func testCaseRun(_ run: IFTestCaseRun,
                     showReportOnTestCases numberTested: Int32,
                     fromReport reportURL: URL?) {
        events.append("report on \(numberTested) from \(reportURL?.lastPathComponent ?? "none")")
    }
}
