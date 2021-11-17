//
//  IFCompiler.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IFCompilerSettings;
@class IFProgress;

extern NSNotificationName const IFCompilerClearConsoleNotification;
extern NSNotificationName const IFCompilerStartingNotification;
extern NSNotificationName const IFCompilerStdoutNotification;
extern NSNotificationName const IFCompilerStderrNotification;
extern NSNotificationName const IFCompilerFinishedNotification;

@protocol IFCompilerDelegate;

typedef NS_ENUM(int, ECompilerProblemType) {
    EProblemTypeNone,
    EProblemTypeInform7,
    EProblemTypeInform6,
    EProblemTypeCBlorb,
    EProblemTypeUnknown
};

///
/// Protocol implemented by classes that can find alternative 'problems' files
///
@protocol IFCompilerProblemHandler <NSObject>

/// Returns the problem URL to use when the compiler finishes with a specific error code
- (NSURL*) urlForProblemWithErrorCode: (int) errorCode;

@optional
/// Called only for the final stage, and can provide an optional page to show to indicate success
@property (atomic, readonly, copy) NSURL *urlForSuccess;

@end

//
// Class that handles actually running a compiler (more like a 'make' class these days)
//
@interface IFCompiler : NSObject

//+ (NSString*) compilerExecutable;
- (void) setBuildForRelease: (BOOL) willRelease forTesting: (BOOL) testing;         // If set, debug options will be turned off while building								// Sets the settings to use while compiling											// Sets the initial input file											// Sets the build products directory
/// Retrieves the input file name
@property (atomic, copy) NSString *inputFile;
/// Retrieves the settings
@property (atomic, strong) IFCompilerSettings *settings;
/// Retrieves the working directory path
@property (atomic, copy) NSString *directory;

- (void) prepareForLaunchWithBlorbStage: (BOOL) makeBlorb testCase:(NSString*) testCase;    // Prepares the first task for launch
@property (atomic, getter=isRunning, readonly) BOOL running;						// YES if a compiler is running

/// Adds a new build stage to the compiler
- (void) addCustomBuildStage: (NSString*) command
               withArguments: (NSArray*) arguments
              nextStageInput: (NSString*) file
				errorHandler: (id<IFCompilerProblemHandler>) handler
					   named: (NSString*) stageName;
/// Adds a new Natural Inform build stage to the compiler
- (void) addNaturalInformStageUsingTestCase:(NSString*) testCase;
/// Adds a new Inform 6 build stage to the compiler
- (void) addStandardInformStage: (BOOL) usingNaturalInform;
/// Pathname of the input file for the current build stage
@property (atomic, readonly, copy) NSString *currentStageInput;

/// Deletes the output from the compiler
- (void)      deleteOutput;
/// Path of the compiler output file
@property (atomic, copy) NSString *outputFile;
/// URL of the file that should be shown in the 'Problems' tab; nil if we should use the standard problems.html file
@property (atomic, readonly, copy) NSURL *problemsURL;
// Sets the file that the compiler should target
/// If YES, the output is deleted when the compiler is deallocated
- (void)      setDeletesOutput: (BOOL) deletes;

/// Sets the delegate object for the compiler. The delegate is NOT RETAINED.
- (void) setDelegate: (id<IFCompilerDelegate>) delegate;
/// Retrieves the delegate object.
- (id<IFCompilerDelegate>)   delegate;

@property (atomic, weak) id<IFCompilerDelegate> delegate;

/// Clears the console
- (void) clearConsole;
/// Fires off the compiler task.
- (void) launch;

/// Pretends that the given string appeared on the standard out of the task
- (void) sendStdOut: (NSString*) data;

/// Retrieves the progress indicator for this compiler
@property (atomic, readonly, strong) IFProgress *progress;

- (void) setEndTextString: (NSString*) aEndTextString;

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
