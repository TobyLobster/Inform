//
//  IFCompiler.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//
//  This does the actual low level work of a build: executing tasks in background threads and
//  sending notifications with the results.

#import "IFCompiler.h"

#import "IFPreferences.h"

#import "IFUtility.h"
#import "IFProgress.h"
#import "IFCompilerSettings.h"
#import "IFCompilerStyles.h"
#import "Inform-Swift.h"

static unsigned int mod = 0;

NSString* const IFCompilerClearConsoleNotification = @"IFCompilerClearConsoleNotification";
NSString* const IFCompilerStartingNotification     = @"IFCompilerStartingNotification";
NSString* const IFCompilerStdoutNotification       = @"IFCompilerStdoutNotification";
NSString* const IFCompilerStderrNotification       = @"IFCompilerStderrNotification";
NSString* const IFCompilerFinishedNotification     = @"IFCompilerFinishedNotification";

@implementation IFCompiler {
    // The task
    /// Task where the compiler is running
    NSTask* theTask;

    // Settings, input, output
    /// Settings for the compiler
    IFCompilerSettings* settings;
    /// \c YES if compiling for release
    BOOL release;
    /// \c YES if compiling for releaseForTesting;
    BOOL releaseForTesting;
    /// The input file for this compiler
    NSString* inputFile;
    /// The output filename for this compiler
    NSString* outputFile;
    /// The working directory for this stage
    NSString* workingDirectory;
    /// \c YES if the output file should be deleted when the compiler is dealloced
    BOOL deleteOutputFile;

    /// The URL of the problems page we should show
    NSURL* problemsURL;
    /// The current problem handler
    id<IFCompilerProblemHandler> problemHandler;

    // Queue of processes to run
    /// Queue of tasks to run to produce the end result
    NSMutableArray* runQueue;

    // Output/input streams
    /// stdErr pipe
    NSPipe* stdErr;
    /// stdOut pipe
    NSPipe* stdOut;

    /// File handle for stderr
    NSFileHandle* stdErrH;
    /// File handle for stdout
    NSFileHandle* stdOutH;

    /// The start of a character at the end of what was read from stderr, kept until the rest arrives
    NSMutableData* stdErrPending;
    /// The start of a character at the end of what was read from stdout, kept until the rest arrives
    NSMutableData* stdOutPending;

    /// When =3, the task has finished: its stdout and stderr have ended, and it has terminated
    int finishCount;

    // Progress
    /// Progress indicator for compilation
    IFProgress* progress;
    /// Message to show at end of tasks
    NSString* endTextString;
}

#pragma mark - Initialisation, etc

- (instancetype) init {
    self = [super init];

    if (self) {
		progress = [[IFProgress alloc] initWithPriority: IFProgressPriorityCompiler
                                       showsProgressBar: YES
                                              canCancel: NO];

        deleteOutputFile = YES;
        runQueue = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) dealloc {
    if (deleteOutputFile) [self deleteOutput];

	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Setup

- (void) setBuildForRelease: (BOOL) willRelease
                 forTesting: (BOOL) testing {
	release = willRelease;
    releaseForTesting = testing;
}

@synthesize settings;
@synthesize inputFile;

- (void) deleteOutput {
    if (outputFile) {
        if ([[NSFileManager defaultManager] fileExistsAtPath: outputFile]) {
            NSLog(@"Removing '%@'", outputFile);
            [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:outputFile isDirectory:FALSE] error: nil];
        } else {
            NSLog(@"Compiler produced no output");
            // Nothing to do
        }
        
        outputFile = nil;
    }
}

- (void) addCustomBuildStage: (NSString*) command
               withArguments: (NSArray*) arguments
              nextStageInput: (NSString*) file
				errorHandler: (id<IFCompilerProblemHandler>) handler
					   named: (NSString*) stageName {
    if (theTask) {
        // This starts a new build process, so we kill the old task if it's still
        // running
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    if( handler )
    {
        [runQueue addObject: @[command,
                               arguments,
                               file,
                               stageName,
                               handler]];
    }
    else
    {
        [runQueue addObject: @[command,
                               arguments,
                               file,
                               stageName]];
    }
}

- (void) addNaturalInformStageUsingTestCase:(NSString*) testCase {
    // Prepare the arguments
    NSMutableArray* args = [NSMutableArray arrayWithArray: settings.naturalInformCommandLineArguments];

    [args addObject: [NSString stringWithFormat: @"-%@",
                     [IFUtility compilerProjectParameterName: settings.compilerVersion]]];
    [args addObject: [self.currentStageInput copy]];

    NSString* formatValue = settings.fileExtension;
    NSString* debugValue = @"";

    if ([IFUtility compilerVersion: settings.compilerVersion isAfter: @"6M62"]) {
        if ([formatValue isEqualToStringCaseInsensitive:@"z8"]) {
            formatValue = @"Inform6/16";
        } else {
            formatValue = @"Inform6/32";
        }
        if (!release) {
            debugValue = @"d";
        }
    }
    [args addObject: [NSString stringWithFormat: @"-%@=%@%@",
                      [IFUtility compilerFormatParameterName: settings.compilerVersion],
                      formatValue,
                      debugValue]];
	
	if (release && !releaseForTesting) {
		[args addObject: @"-release"];
	}

	if (settings.nobbleRng && !release) {
		[args addObject: @"-rng"];
	}

    if (settings.basicInform) {
        [args addObject: @"-basic"];
    }

    if(( testCase != nil ) && (testCase.length > 0))
    {
        [args addObject: @"-case"];
        [args addObject: [NSString stringWithFormat:@"%@", testCase]];
    }
	
    [self addCustomBuildStage: settings.naturalInformCompilerToUse
                withArguments: args
               nextStageInput: [NSString stringWithFormat: @"%@/Build/auto.inf", self.currentStageInput]
				 errorHandler: [[NaturalProblem alloc] init]
						named: [IFUtility localizedString: @"Compiling Natural Inform source"]];
}

- (void) addStandardInformStage {
    if (!outputFile) [self outputFile];
    
    // Prepare the arguments
    NSMutableArray* args = [[settings commandLineArgumentsForRelease: release
                                                          forTesting: releaseForTesting] mutableCopy];

    [args addObject: [self.currentStageInput copy]];
    [args addObject: [outputFile copy]];

    [self addCustomBuildStage: settings.inform6CompilerToUse
                withArguments: args
               nextStageInput: outputFile
				 errorHandler: [[Inform6Problem alloc] init]
						named: [IFUtility localizedString: @"Compiling Inform 6 source"]];
}

- (NSString*) currentStageInput {
    NSString* inFile = inputFile;
    if (runQueue.count > 0) inFile = runQueue.lastObject[2];

    return inFile;
}

- (BOOL) isRunning {
	return (theTask != nil) ? theTask.running : NO;
}

- (NSString*) quoteIfNeeded: (NSString*) arg {
    if ([arg containsString:@" "]) {
        return [NSString stringWithFormat: @"\"%@\"", arg];
    }
    return arg;
}

- (void) sendTaskDetails: (NSTask*) task {
    NSMutableString* taskMessage = [NSMutableString stringWithFormat: @"Launching: %@", [self quoteIfNeeded: task.launchPath]];

	for( NSString* arg in task.arguments ) {
        [taskMessage appendFormat: @" \\\n    %@", [self quoteIfNeeded: arg]];
	}

	[taskMessage appendString: @"\n"];
	[self sendStdOut: taskMessage withStyle: IFStyleLaunch];
}

-(void) prepareNext {
    NSString* stageName = runQueue[0][3];
    progress.message = stageName;

    NSArray* args     = runQueue[0][1];
    NSString* command = runQueue[0][0];

    problemHandler = nil;
    if ([runQueue[0] count] > 4) {
        problemHandler = runQueue[0][4];
    }

    [runQueue removeObjectAtIndex: 0];

    // Prepare the task
    theTask = [[NSTask alloc] init];
    finishCount = 0;

    theTask.arguments = args;
    theTask.launchPath = command;
    if (workingDirectory)
        theTask.currentDirectoryPath = workingDirectory;
    else
        theTask.currentDirectoryPath = NSTemporaryDirectory();

    // Prepare the task's IO
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    stdErr = [[NSPipe alloc] init];
    stdOut = [[NSPipe alloc] init];

    theTask.standardOutput = stdOut;
    theTask.standardError = stdErr;

    stdErrH = stdErr.fileHandleForReading;
    stdOutH = stdOut.fileHandleForReading;

    stdErrPending = [[NSMutableData alloc] init];
    stdOutPending = [[NSMutableData alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(stdOutWaiting:)
                                                 name: NSFileHandleDataAvailableNotification
                                               object: stdOutH];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(stdErrWaiting:)
                                                 name: NSFileHandleDataAvailableNotification
                                               object: stdErrH];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(taskDidFinish:)
                                                 name: NSTaskDidTerminateNotification
                                               object: theTask];
    
    [stdOutH waitForDataInBackgroundAndNotify];
    [stdErrH waitForDataInBackgroundAndNotify];
}

- (BOOL) prepareForLaunchWithBlorbStage: (BOOL) makeBlorb testCase:(NSString*) testCase {
    // Kill off any old tasks...
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;		
    }

	// There are no problems
	problemsURL = nil;

    if (deleteOutputFile) [self deleteOutput];

    // Prepare the arguments
    if (runQueue.count <= 0) {
        if ([IFPreferences sharedPreferences].runBuildSh && ![IFUtility isSandboxed]) {
            NSString* buildsh;

            buildsh = (@"~/build.sh").stringByExpandingTildeInPath;
            
			[self addCustomBuildStage: buildsh
						withArguments: @[]
					   nextStageInput: self.currentStageInput
						 errorHandler: nil
								named: @"Debug build stage"];
        }

        if (![settings isNaturalInformCompilerPathValid])
        {
            return NO;
        }
        [self addNaturalInformStageUsingTestCase: testCase];

        [self addStandardInformStage];

        if (makeBlorb) {
			// Blorb files kind of create an exception: we change our output file, for instance,
            // and the input file is determined by the blurb file output by NI
			NSString* extension;

			if (settings.zcodeVersion > 128) {
				extension = @"gblorb";
			} else {
				extension = @"zblorb";
			}

			// Work out the new output file
			NSString* oldOutput  = self.outputFile;
			NSString* newOutput  = [oldOutput.stringByDeletingPathExtension stringByAppendingPathExtension: extension];

			// Work out where the blorb is coming from
            NSString* buildDir   = self.currentStageInput.stringByDeletingLastPathComponent;
            NSString* projectdir = buildDir.stringByDeletingLastPathComponent;
			NSString* blorbFile  = [projectdir stringByAppendingPathComponent: @"Release.blurb"];

			// Add a cBlorb stage
            NSString *cBlorbLocation = [IFUtility pathForInformExecutable: @"cBlorb" version: settings.compilerVersion];

			[self addCustomBuildStage: cBlorbLocation
						withArguments: @[blorbFile, newOutput]
					   nextStageInput: newOutput
						 errorHandler: [[CBlorbProblem alloc] initWithBuildDir: buildDir]
								named: @"cBlorb build stage"];

			// Change the output file
			self.outputFile = newOutput;
		}
    }

    endTextString = nil;
    [progress startProgress];

    [self prepareNext];
    return YES;
}

- (BOOL) launchWithInTestStage: (NSString*) path
                       command: (NSString*) command
                      testCase: (NSString*) testCase {
    // Kill off any old tasks...
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    // There are no problems
    problemsURL = nil;

    if (deleteOutputFile) [self deleteOutput];

    // Prepare the arguments
    if (runQueue.count <= 0) {

        // Add a cBlorb stage
        NSString *intestLocation = [IFUtility pathForInformExecutable: @"intest" version: @""]; // Use latest intest

        NSString *inform7Location = [IFUtility pathForCompiler: settings.compilerVersion];
        NSString *inform6Location = [IFUtility pathForInformExecutable: @"inform6" version: settings.compilerVersion];
        NSString *ginterpreterLocation = [IFUtility pathForInformExecutable: @"glulxe" version: settings.compilerVersion];
        NSString *zinterpreterLocation = [IFUtility pathForInformExecutable: @"dumb-frotz" version: settings.compilerVersion];
        NSFileManager* fm = [NSFileManager defaultManager];

        NSError* error;
        NSURL* results = [[IFUtility temporaryDirectoryURL] URLByAppendingPathComponent:@"intest_results.html"];
        NSURL* workspace = [[IFUtility temporaryDirectoryURL] URLByAppendingPathComponent:@"InTestWorkspace"];

        if (![fm createDirectoryAtURL: workspace withIntermediateDirectories:YES attributes:nil error: &error]) {
            return FALSE;
        }

        NSMutableArray* args = [NSMutableArray array];
        // intest PATH -internal INTERNAL -results FILE -set 'I7 = ...' -set 'I6 = ...' -set 'GINTERPRETER = ...' -set 'ZINTERPRETER = ...' -workspace WORKSPACE COMMAND CASE
        [args addObject:path];
        [args addObject:@"-internal"];
        [args addObject:[IFUtility pathForInformInternalAppSupport: settings.compilerVersion]];
        [args addObject:@"-results"];
        [args addObject:results.path];
        [args addObject:@"-set"];
        [args addObject:[NSString stringWithFormat:@"I7COMPILER = %@", inform7Location]];
        [args addObject:@"-set"];
        [args addObject:[NSString stringWithFormat:@"I6COMPILER = %@", inform6Location]];
        [args addObject:@"-set"];
        [args addObject:[NSString stringWithFormat:@"GINTERPRETER = %@", ginterpreterLocation]];
        [args addObject:@"-set"];
        [args addObject:[NSString stringWithFormat:@"ZINTERPRETER = %@", zinterpreterLocation]];
        [args addObject:@"-workspace"];
        [args addObject:workspace.path];
        [args addObject:command];
        [args addObject:testCase];

        NSString* buildDir   = self.currentStageInput.stringByDeletingLastPathComponent;
        [self addCustomBuildStage: intestLocation
                    withArguments: args
                   nextStageInput: results.path
                     errorHandler: [[IntestProblem alloc] initWithBuildDir: buildDir]
                            named: @"Intest build stage"];

        // Change the output file
        self.outputFile = results.path;
    }

    endTextString = nil;
    [progress startProgress];

    [self prepareNext];

    // Launch it
    [self sendTaskDetails: theTask];
    [theTask launch];
    return YES;
}

- (void) clearConsole {
    [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerClearConsoleNotification
                                                        object: self];
}

- (void) launch {
    [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStartingNotification
                                                        object: self];
	[self sendTaskDetails: theTask];
    [theTask launch];
}

@synthesize problemsURL;

@synthesize outputFile;
- (NSString*) outputFile {
    if (outputFile == nil) {
        outputFile = [NSString stringWithFormat: @"%@/Inform-%x-%x.%@",
            NSTemporaryDirectory(), (unsigned int) time(NULL), ++mod, settings.fileExtension];
        deleteOutputFile = YES;
    }

    return [outputFile copy];
}

- (void) setOutputFile: (NSString*) file {
    outputFile = [file copy];
    deleteOutputFile = NO;
}

@synthesize directory = workingDirectory;

- (void) taskHasReallyFinished {
	int exitCode = theTask.terminationStatus;
    ECompilerProblemType problemType = EProblemTypeNone;

    if( exitCode != 0 ) {
        if ([problemHandler isKindOfClass: [NaturalProblem class]]) {
            problemType = EProblemTypeInform7;
        } else if ([problemHandler isKindOfClass: [Inform6Problem class]]) {
            problemType = EProblemTypeInform6;
        } else if ([problemHandler isKindOfClass: [CBlorbProblem class]]) {
            problemType = EProblemTypeCBlorb;
        } else if (problemHandler != nil) {
            problemType = EProblemTypeUnknown;
        }
    }

    if (runQueue.count == 0) {
        if (exitCode != 0 && problemHandler) {
			problemsURL = [[problemHandler urlForProblemWithErrorCode: exitCode] copy];
		} else if (exitCode == 0 && problemHandler) {
			if ([problemHandler respondsToSelector: @selector(urlForSuccess)]) {
				problemsURL = [problemHandler.urlForSuccess copy];
			}
		}

		[progress stopProgress];
        
        // Show final message from compiler
        if( endTextString ) {
            progress.message = endTextString;
            endTextString = nil;
        }
        NSDictionary* uiDict = @{@"exitCode": @(exitCode),
                                 @"problemType": @(problemType)};
        [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerFinishedNotification
                                                            object: self
                                                          userInfo: uiDict];
    } else {
        if (exitCode != 0) {
			if (problemHandler) {
				problemsURL = [[problemHandler urlForProblemWithErrorCode: exitCode] copy];
			}
			
            // The task failed
            [progress stopProgress];
            
            // Show final message from compiler
            if( endTextString ) {
                progress.message = endTextString;
                endTextString = nil;
            }
            else
            {
                progress.message = [[NSString alloc] initWithFormat:@"Error code %d", exitCode];
            }
            
            // Notify everyone of the failure
            NSDictionary* uiDict = @{@"exitCode": @(exitCode),
                                     @"problemType": @(problemType)};
            [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerFinishedNotification
                                                                object: self
                                                              userInfo: uiDict];
            
            // Give up
            [runQueue removeAllObjects];
            theTask = nil;
            
            return;
        }
        
        // Prepare the next task for launch
        if (theTask) {
            if (theTask.running) {
                [theTask terminate];
            }
            theTask = nil;
        }

        [self prepareNext];

        // Launch it
		[self sendTaskDetails: theTask];
        [theTask launch];
    }
}

#pragma mark - Notifications

- (void) sendStdOut: (NSString*) data
          withStyle: (NSString*) style {
	NSDictionary* uiDict = @{
        @"string": data,
        @"style": style
    };
	[[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStdoutNotification
														object: self
													  userInfo: uiDict];
}

/// Turns what a stage wrote into text. It's read as UTF-8, keeping back the start of a character
/// at the end until the rest of it arrives, or as Latin-1 if it isn't UTF-8. Empty data, at the end
/// of the output, gives what was kept back.
- (NSString*) stringFromData: (NSData*) data pending: (NSMutableData*) pending {
    [pending appendData: data];

    NSUInteger complete = pending.length;
    if (data.length > 0) {
        // Find the last character's first byte, after at most three continuation bytes
        const unsigned char* bytes = pending.bytes;
        NSUInteger start = complete;
        while (start > 0 && complete - start < 3 && (bytes[start - 1] & 0xC0) == 0x80) {
            start--;
        }

        if (start > 0) {
            unsigned char first = bytes[start - 1];
            NSUInteger size = 1;
            if ((first & 0xE0) == 0xC0) size = 2;
            else if ((first & 0xF0) == 0xE0) size = 3;
            else if ((first & 0xF8) == 0xF0) size = 4;

            // Keep it back if it's incomplete
            if (complete - (start - 1) < size) complete = start - 1;
        }
    }

    if (complete == 0) return nil;

    NSString* result = [[NSString alloc] initWithData: [pending subdataWithRange: NSMakeRange(0, complete)]
                                             encoding: NSUTF8StringEncoding];
    if (result == nil) {
        // It isn't UTF-8, so read all of it as Latin-1
        result = [[NSString alloc] initWithData: pending
                                       encoding: NSISOLatin1StringEncoding];
        complete = pending.length;
    }

    [pending replaceBytesInRange: NSMakeRange(0, complete) withBytes: NULL length: 0];
    return result;
}

- (void) stdOutWaiting: (NSNotification*) not {
	if (finishCount >= 3) return;

    NSData* inData = stdOutH.availableData;

    NSString* newStr = [self stringFromData: inData pending: stdOutPending];
    if (newStr.length) {
		[self sendStdOut: newStr
               withStyle: IFStyleBase];
    }

    if (inData.length) {
        [stdOutH waitForDataInBackgroundAndNotify];
    } else {
        finishCount++;

        if (finishCount == 3) {
            [self taskHasReallyFinished];
        }
    }
}

- (void) stdErrWaiting: (NSNotification*) not {
	if (finishCount >= 3) return;
	
    NSData* inData = stdErrH.availableData;

    NSString* newStr = [self stringFromData: inData pending: stdErrPending];
    if (newStr.length) {
        NSDictionary* uiDict = @{@"string": newStr};
        [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStderrNotification
                                                            object: self
                                                          userInfo: uiDict];
    }

    if (inData.length) {
        [stdErrH waitForDataInBackgroundAndNotify];
    } else {
        finishCount++;

        if (finishCount == 3) {
            [self taskHasReallyFinished];
        }
    }
}

- (void) taskDidFinish: (NSNotification*) not {
    finishCount++;

    if (finishCount == 3) {
        [self taskHasReallyFinished];
    }
}

@synthesize progress;
@synthesize endTextString;

@end
