//
//  IFCompiler.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IFCompilerSettings;
@class IFProgress;
@protocol IFCompilerDelegate;

extern NSNotificationName const IFCompilerClearConsoleNotification;
extern NSNotificationName const IFCompilerStartingNotification;
extern NSNotificationName const IFCompilerStdoutNotification;
extern NSNotificationName const IFCompilerStderrNotification;
extern NSNotificationName const IFCompilerFinishedNotification;

typedef NS_ENUM(int, ECompilerProblemType) {
    EProblemTypeNone NS_SWIFT_NAME(none),
    EProblemTypeInform7 NS_SWIFT_NAME(inform7),
    EProblemTypeInform6 NS_SWIFT_NAME(inform6),
    EProblemTypeCBlorb NS_SWIFT_NAME(cBlorb),
    EProblemTypeUnknown NS_SWIFT_NAME(unknown)
};

///
/// Protocol implemented by classes that can find alternative 'problems' files
///
@protocol IFCompilerProblemHandler <NSObject>

/// Returns the problem URL to use when the compiler finishes with a specific error code
- (nullable NSURL*) urlForProblemWithErrorCode: (int) errorCode NS_SWIFT_NAME(urlForProblem(errorCode:));

@optional
/// Called only for the final stage, and can provide an optional page to show to indicate success
@property (atomic, readonly, copy, nullable) NSURL *urlForSuccess;

@end

///
/// Class that handles actually running a compiler (more like a 'make' class these days)
///
@interface IFCompiler : NSObject

//+ (NSString*) compilerExecutable;
/// If set, debug options will be turned off while building
- (void) setBuildForRelease: (BOOL) willRelease forTesting: (BOOL) testing NS_SWIFT_NAME(setBuild(forRelease:forTesting:));
/// The input file name.
@property (atomic, copy) NSString *inputFile;
/// Retrieves the settings
/// Sets the settings to use while compiling
@property (atomic, strong) IFCompilerSettings *settings;
/// Sets the build products directory.
/// Retrieves the working directory path.
@property (atomic, copy) NSString *directory;

/// Prepares the first task for launch
- (BOOL) prepareForLaunchWithBlorbStage: (BOOL) makeBlorb testCase:(nullable NSString*) testCase;
/// \c YES if a compiler is running
@property (atomic, getter=isRunning, readonly) BOOL running;

- (BOOL) launchWithInTestStage: (NSString*) path
                       command: (NSString*) command
                      testCase: (NSString*) testCase;

/// Adds a new build stage to the compiler
- (void) addCustomBuildStage: (NSString*) command
               withArguments: (NSArray<NSString*>*) arguments
              nextStageInput: (NSString*) file
				errorHandler: (nullable id<IFCompilerProblemHandler>) handler
					   named: (NSString*) stageName;
/// Adds a new Natural Inform build stage to the compiler
- (void) addNaturalInformStageUsingTestCase:(NSString*) testCase;
/// Adds a new Inform 6 build stage to the compiler
- (void) addStandardInformStage;
/// Pathname of the input file for the current build stage
@property (atomic, readonly, copy) NSString *currentStageInput;

/// Deletes the output from the compiler
- (void)      deleteOutput;
/// Path of the compiler output file
@property (atomic, copy) NSString *outputFile;
/// URL of the file that should be shown in the 'Problems' tab; nil if we should use the standard problems.html file
@property (atomic, readonly, copy, nullable) NSURL *problemsURL;
// Sets the file that the compiler should target
/// If YES, the output is deleted when the compiler is deallocated
@property (atomic) BOOL deletesOutput;
- (void)      setDeletesOutput: (BOOL) deletes;

/// Sets the delegate object for the compiler. The delegate is NOT RETAINED.
- (void) setDelegate: (nullable id<IFCompilerDelegate>) delegate;
/// Retrieves the delegate object.
- (nullable id<IFCompilerDelegate>)   delegate;
/// The delegate object.
@property (atomic, weak, nullable) id<IFCompilerDelegate> delegate;

/// Clears the console
- (void) clearConsole;
/// Fires off the compiler task.
- (void) launch;

/// Pretends that the given string appeared on the standard out of the task
- (void) sendStdOut: (NSString*) data
          withStyle: (NSString*) style;

/// Retrieves the progress indicator for this compiler
@property (atomic, readonly, strong) IFProgress *progress;

@property (atomic, readwrite, copy, nullable) NSString *endTextString;

@end

///
/// Delegate method prototypes
///
@protocol IFCompilerDelegate<NSObject>
@optional

/// Called when every stage has completed, or when a stage fails (ie, when compiling has finished for whatever reason)
- (void) taskFinished:       (int) exitCode;
/// Called when some data arrives on stdout from the compiler
- (void) receivedFromStdOut: (NSString*) data;
/// Called when some data arrives on stderr from the compiler
- (void) receivedFromStdErr: (NSString*) data;

@end

NS_ASSUME_NONNULL_END
