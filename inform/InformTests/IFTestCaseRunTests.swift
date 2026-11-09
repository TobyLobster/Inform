//
//  IFTestCaseRunTests.swift
//  InformTests
//

import XCTest

/// Test's run through an extension project's test cases
final class IFTestCaseRunTests: XCTestCase {
    func testANewRunIsBetweenRuns() {
        let run = IFTestCaseRun()

        XCTAssertEqual(run.currentIndex, -1)
        XCTAssertFalse(run.isOnALaterTestCase)
        XCTAssertEqual(run.numberTested, 0)
    }

    func testTestAllGoesThroughEachTestCaseInTurn() {
        let run = IFTestCaseRun()
        run.chooseTestCases(from: 0, to: 2)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 0)
        XCTAssertFalse(run.isOnALaterTestCase)
        XCTAssertFalse(run.isPastTheLastTestCase)
        XCTAssertEqual(run.numberStarted, 1)
        XCTAssertEqual(run.numberInRun, 3)
        XCTAssertEqual(run.percentageStarted, 100.0 / 3.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 1)
        XCTAssertTrue(run.isOnALaterTestCase)
        XCTAssertEqual(run.numberStarted, 2)
        XCTAssertEqual(run.percentageStarted, 200.0 / 3.0, accuracy: 0.0001)

        run.moveToNextTestCase()
        XCTAssertEqual(run.currentIndex, 2)
        XCTAssertFalse(run.isPastTheLastTestCase)
        XCTAssertEqual(run.percentageStarted, 100.0, accuracy: 0.0001)

        run.moveToNextTestCase()
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
}
