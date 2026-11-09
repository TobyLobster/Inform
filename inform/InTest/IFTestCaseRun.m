//
//  IFTestCaseRun.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFTestCaseRun.h"

@implementation IFTestCaseRun {
    /// Current index of test cases to test
    int currentTestCaseIndex;
    /// Range of test cases to test
    int startTestCaseIndex;
    /// Range of test cases to test
    int endTestCaseIndex;
    /// Number of test cases tested
    int numberOfTestCases;
}

- (instancetype) init {
    self = [super init];

    if (self) {
        currentTestCaseIndex = -1;
        numberOfTestCases = 0;
    }

    return self;
}

- (int) currentIndex {
    return currentTestCaseIndex;
}

- (BOOL) isOnALaterTestCase {
    return !(currentTestCaseIndex < 1);
}

- (BOOL) isPastTheLastTestCase {
    return currentTestCaseIndex > endTestCaseIndex;
}

- (int) numberStarted {
    return currentTestCaseIndex - startTestCaseIndex + 1;
}

- (int) numberInRun {
    return 1 + (endTestCaseIndex - startTestCaseIndex);
}

- (double) percentageStarted {
    return 100.0 * (double) self.numberStarted / (double) self.numberInRun;
}

- (int) numberTested {
    return numberOfTestCases;
}

- (void) chooseTestCasesFrom: (int) first
                          to: (int) last {
    startTestCaseIndex = first;
    endTestCaseIndex = last;
}

- (void) moveToNextTestCase {
    if( currentTestCaseIndex == -1 ) {
        // Move to first test case
        currentTestCaseIndex = startTestCaseIndex;
    }
    else {
        // Move to next test case
        currentTestCaseIndex++;
    }
}

- (void) finish {
    numberOfTestCases = currentTestCaseIndex - startTestCaseIndex;
    currentTestCaseIndex = -1;
}

@end
