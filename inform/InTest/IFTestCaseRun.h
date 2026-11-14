//
//  IFTestCaseRun.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

@class IFTestCaseRun;

NS_ASSUME_NONNULL_BEGIN

///
/// What a run through the test cases asks of the project's controller, which looks the test cases up in the toolbar,
/// tests each, and shows the run's progress and its report
///
NS_SWIFT_UI_ACTOR
@protocol IFTestCaseRunDelegate <NSObject>

/// The test case at the index given, or nil if there's none
- (nullable NSString*) testCaseRun: (IFTestCaseRun*) run
                   testCaseAtIndex: (int) index NS_SWIFT_NAME(testCaseRun(_:testCaseAt:));
/// Whether the run has been cancelled
- (BOOL) testCaseRunIsCancelled: (IFTestCaseRun*) run;
/// Compiles and tests the run's current test case, showing how far the run has got
- (void) testCaseRunTestsCurrentTestCase: (IFTestCaseRun*) run;
/// Shows that the run has ended, whether it was cancelled or complete
- (void) testCaseRunDidFinish: (IFTestCaseRun*) run;
/// Shows the report on the test cases the run moved past: their reports combined, if there was more than one, or the
/// report at the URL given
- (void)       testCaseRun: (IFTestCaseRun*) run
     showReportOnTestCases: (int) numberTested
                fromReport: (nullable NSURL*) reportURL
    NS_SWIFT_NAME(testCaseRun(_:showReportOnTestCases:fromReport:));

@end

///
/// Test's run through an extension project's test cases, by their index, one after another: all of them for Test All,
/// or the one chosen
///
NS_SWIFT_UI_ACTOR
@interface IFTestCaseRun : NSObject

/// What the run asks of the project's controller
@property (atomic, weak, nullable) id<IFTestCaseRunDelegate> delegate;

/// The index of the test case being tested, or -1 between runs
@property (atomic, readonly) int currentIndex;
/// Whether the test case being tested comes after the first of the run. A compile clears the console unless it does.
@property (atomic, readonly, getter=isOnALaterTestCase) BOOL onALaterTestCase;
/// Whether the test case being tested is the run's last
@property (atomic, readonly, getter=isOnTheLastTestCase) BOOL onTheLastTestCase;
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

/// Moves to the run's next test case, or to its first between runs, and has the delegate test it. Ends the run instead
/// if it's past its last test case, the delegate has no test case at that index, or it's been cancelled. Returns
/// whether a test case is being tested
- (BOOL) startNextTestCase;
/// After the run's current test case didn't compile, starts the next once the compiler is done with this one, or ends
/// the run. A run that ends here, unless it was cancelled, shows its report if this test case's was made, at the URL
/// given
- (void) testCaseDidntCompileWithReport: (nullable NSURL*) reportURL NS_SWIFT_NAME(testCaseDidntCompile(withReport:));
/// After the story of the run's current test case has been played through its commands, starts the next, or ends the
/// run and, unless it was cancelled, shows its report, with this test case's at the URL given
- (void) testCaseWasPlayedWithReport: (nullable NSURL*) reportURL NS_SWIFT_NAME(testCaseWasPlayed(withReport:));

@end

NS_ASSUME_NONNULL_END
