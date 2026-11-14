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

    weak var delegate: (any IFTestCaseRunDelegate)?

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

    /// The test case at the run's index, which the delegate looks up
    private final var currentTestCase: String? {
        return delegate?.testCaseRun(self, testCaseAt: currentTestCaseIndex)
    }

    /// Whether the delegate says the run has been cancelled
    private final var isCancelled: Bool {
        return delegate?.testCaseRunIsCancelled(self) ?? false
    }

    func startNextTestCase() -> Bool {
        moveToNextTestCase()

        // Did we reach the end of the test cases?
        if (isPastTheLastTestCase || currentTestCase == nil) || isCancelled {
            finishRun()
            return false
        }

        delegate?.testCaseRunTestsCurrentTestCase(self)
        return true
    }

    func testCaseDidntCompile(withReport reportURL: URL?) {
        if startNextTestCaseSoon() {
            return
        }

        // All test cases finished.

        // Create a consolidated report and display it.
        if !isCancelled && reportURL != nil {
            delegate?.testCaseRun(self, showReportOnTestCases: numberTested, fromReport: reportURL)
        }
    }

    func testCaseWasPlayed(withReport reportURL: URL?) {
        // Start next case
        if startNextTestCase() {
            return
        }

        // All test cases finished. Create a consolidated report and display it.
        if !isCancelled {
            delegate?.testCaseRun(self, showReportOnTestCases: numberTested, fromReport: reportURL)
        }
    }

    /// Starts the next test case once the compiler is done with the current one, or, after the last, at once. Ends the
    /// run, as `startNextTestCase` does, if there's no current test case or the run's been cancelled. Returns whether
    /// a test case is being tested, or is to be
    private final func startNextTestCaseSoon() -> Bool {
        if currentTestCase == nil || isCancelled {
            finishRun()
            return false
        }

        // After the last test case, finish now, so that the caller knows to make the report
        if isOnTheLastTestCase {
            return startNextTestCase()
        }

        // Enforce a delay to let current task finish gracefully before starting another
        Timer.scheduledTimer(timeInterval: 0.0,
                             target: self,
                             selector: #selector(startNextTestCase),
                             userInfo: nil,
                             repeats: false)
        return true
    }

    /// Ends the run, and tells the delegate
    private final func finishRun() {
        finish()
        delegate?.testCaseRunDidFinish(self)
    }
}
