//
//  IFTestCaseRun.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFTestCaseRun.h.
//

import Foundation

@objc @implementation extension IFTestCaseRun {
    /// Current index of test cases to test
    private final var currentTestCaseIndex: Int32 = -1
    /// Range of test cases to test
    private final var startTestCaseIndex: Int32 = 0
    /// Range of test cases to test
    private final var endTestCaseIndex: Int32 = 0
    /// Number of test cases tested
    private final var numberOfTestCases: Int32 = 0

    var currentIndex: Int32 {
        return currentTestCaseIndex
    }

    @objc(onALaterTestCase)
    var isOnALaterTestCase: Bool {
        @objc(isOnALaterTestCase)
        get {
            return (currentTestCaseIndex != -1) && (currentTestCaseIndex > startTestCaseIndex)
        }
    }

    @objc(onTheLastTestCase)
    var isOnTheLastTestCase: Bool {
        @objc(isOnTheLastTestCase)
        get {
            return (currentTestCaseIndex != -1) && (currentTestCaseIndex == endTestCaseIndex)
        }
    }

    @objc(pastTheLastTestCase)
    var isPastTheLastTestCase: Bool {
        @objc(isPastTheLastTestCase)
        get {
            return currentTestCaseIndex > endTestCaseIndex
        }
    }

    var numberStarted: Int32 {
        return currentTestCaseIndex - startTestCaseIndex + 1
    }

    var numberInRun: Int32 {
        return 1 + (endTestCaseIndex - startTestCaseIndex)
    }

    var percentageStarted: Double {
        return 100.0 * Double(numberStarted) / Double(numberInRun)
    }

    var numberTested: Int32 {
        return numberOfTestCases
    }

    func chooseTestCases(from first: Int32,
                         to last: Int32) {
        startTestCaseIndex = first
        endTestCaseIndex = last
    }

    func moveToNextTestCase() {
        if currentTestCaseIndex == -1 {
            // Move to first test case
            currentTestCaseIndex = startTestCaseIndex
        }
        else {
            // Move to next test case
            currentTestCaseIndex += 1
        }
    }

    func finish() {
        numberOfTestCases = currentTestCaseIndex - startTestCaseIndex
        currentTestCaseIndex = -1
    }
}
