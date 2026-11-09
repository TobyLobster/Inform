//
//  IFTestCaseRun.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Test's run through an extension project's test cases, by their index, one after another: all of them for Test All,
/// or the one chosen
///
@interface IFTestCaseRun : NSObject

/// The index of the test case being tested, or -1 between runs
@property (atomic, readonly) int currentIndex;
/// Whether the test case being tested comes after the first of the run. A compile clears the console unless it does.
@property (atomic, readonly, getter=isOnALaterTestCase) BOOL onALaterTestCase;
/// Whether the run has moved past its last test case
@property (atomic, readonly, getter=isPastTheLastTestCase) BOOL pastTheLastTestCase;
/// How many of the run's test cases have been started, counting the one being tested
@property (atomic, readonly) int numberStarted;
/// How many test cases the run has
@property (atomic, readonly) int numberInRun;
/// How far the run has got, as a percentage of its test cases started
@property (atomic, readonly) double percentageStarted;
/// How many test cases the last run moved past, counted when it finished
@property (atomic, readonly) int numberTested;

/// Chooses the test cases for the run, from the first index to the last
- (void) chooseTestCasesFrom: (int) first
                          to: (int) last;
/// Moves to the run's next test case, or to its first between runs
- (void) moveToNextTestCase;
/// Ends the run, counting the test cases it moved past
- (void) finish;

@end

NS_ASSUME_NONNULL_END
