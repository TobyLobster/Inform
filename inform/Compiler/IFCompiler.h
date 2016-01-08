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

extern NSString* IFCompilerClearConsoleNotification;
extern NSString* IFCompilerStartingNotification;
extern NSString* IFCompilerStdoutNotification;
extern NSString* IFCompilerStderrNotification;
extern NSString* IFCompilerFinishedNotification;

typedef enum ECompilerProblemType {
    EProblemTypeNone,
    EProblemTypeInform7,
    EProblemTypeInform6,
    EProblemTypeCBlorb,
    EProblemTypeUnknown
} ECompilerProblemType;

//
// Protocol implemented by classes that can find alternative 'problems' files
//
@protocol IFCompilerProblemHandler

- (NSURL*) urlForProblemWithErrorCode: (int) errorCode;		// Returns the problem URL to use when the compiler finishes with a specific error code

@end

//
// Class that handles actually running a compiler (more like a 'make' class these days)
//
@interface IFCompiler : NSObject

//+ (NSString*) compilerExecutable;
- (void) setBuildForRelease: (BOOL) willRelease forTesting: (BOOL) testing;         // If set, debug options will be turned off while building								// Sets the settings to use while compiling											// Sets the initial input file											// Sets the build products directory
@property (atomic, copy) NSString *inputFile;                                       // Retrieves the input file name
@property (atomic, strong) IFCompilerSettings *settings;							// Retrieves the settings
@property (atomic, copy) NSString *directory;										// Retrieves the working directory path

- (void) prepareForLaunchWithBlorbStage: (BOOL) makeBlorb testCase:(NSString*) testCase;    // Prepares the first task for launch
@property (atomic, getter=isRunning, readonly) BOOL running;						// YES if a compiler is running

- (void) addCustomBuildStage: (NSString*) command									// Adds a new build stage to the compiler
               withArguments: (NSArray*) arguments
              nextStageInput: (NSString*) file
				errorHandler: (NSObject<IFCompilerProblemHandler>*) handler
					   named: (NSString*) stageName;
- (void) addNaturalInformStageUsingTestCase:(NSString*) testCase;					// Adds a new Natural Inform build stage to the compiler
- (void) addStandardInformStage: (BOOL) usingNaturalInform;							// Adds a new Inform 6 build stage to the compiler
@property (atomic, readonly, copy) NSString *currentStageInput;						// Pathname of the input file for the current build stage

- (void)      deleteOutput;															// Deletes the output from the compiler
@property (atomic, copy) NSString *outputFile;										// Path of the compiler output file
@property (atomic, readonly, copy) NSURL *problemsURL;								// URL of the file that should be shown in the 'Problems' tab; nil if we should use the standard problems.html file										// Sets the file that the compiler should target
- (void)      setDeletesOutput: (BOOL) deletes;										// If YES, the output is deleted when the compiler is deallocated

- (void) setDelegate: (id<NSObject>) delegate;										// Sets the delegate object for the compiler. The delegate is NOT RETAINED.
- (id)   delegate;																	// Retrieves the delegate object.

- (void) clearConsole;                                                              // Clears the console
- (void) launch;																	// Fires off the compiler task.

- (void) sendStdOut: (NSString*) data;												// Pretends that the given string appeared on the standard out of the task

@property (atomic, readonly, strong) IFProgress *progress;							// Retrieves the progress indicator for this compiler
- (void) setEndTextString: (NSString*) aEndTextString;

@end

//
// Delegate method prototypes
//
@interface NSObject(IFCompilerDelegate)

- (void) taskFinished:       (int) exitCode;										// Called when every stage has completed, or when a stage fails (ie, when compiling has finished for whatever reason)
- (void) receivedFromStdOut: (NSString*) data;										// Called when some data arrives on stdout from the compiler
- (void) receivedFromStdErr: (NSString*) data;										// Called when some data arrives on stderr from the compiler

@end

//
// Optional functions that can be implemented by the problem handler
//
@interface NSObject(IFOptionalProblemDelegate)

@property (atomic, readonly, copy) NSURL *urlForSuccess;															// Called only for the final stage, and can provide an optional page to show to indicate success

@end