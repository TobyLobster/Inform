//
//  IFCompiler.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFCompiler.h"

#import "IFPreferences.h"

#import "IFNaturalProblem.h"
#import "IFInform6Problem.h"
#import "IFCblorbProblem.h"
#import "IFUtility.h"

static int mod = 0;

NSString* IFCompilerStartingNotification = @"IFCompilerStartingNotification";
NSString* IFCompilerStdoutNotification   = @"IFCompilerStdoutNotification";
NSString* IFCompilerStderrNotification   = @"IFCompilerStderrNotification";
NSString* IFCompilerFinishedNotification = @"IFCompilerFinishedNotification";

@implementation IFCompiler

// == Initialisation, etc ==

- (id) init {
    self = [super init];

    if (self) {
        settings = nil;
        inputFile = nil;
        theTask = nil;
        stdOut = stdErr = nil;
        delegate = nil;
        workingDirectory = nil;
		release = NO;
        releaseForTesting = NO;
		
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

    [theTask release];
    theTask = nil;

    [endTextString release];
    endTextString = nil;

    if (outputFile)       [outputFile release];
    if (workingDirectory) [workingDirectory release];    
    if (settings)         [settings release];
    if (inputFile)        [inputFile release];

    if (stdOut) [stdOut release];
    if (stdErr) [stdErr release];
	
	if (stdErrH) [stdErrH release];
	if (stdOutH) [stdOutH release];
	
    //if (delegate) [delegate release];
	
	if (problemsURL) [problemsURL release];
	if (problemHandler) [problemHandler release];

    [runQueue release];
	[progress release];

	[[NSNotificationCenter defaultCenter] removeObserver: self];

    [super dealloc];
}

// == Setup ==

- (void) setBuildForRelease: (BOOL) willRelease
                 forTesting: (BOOL) testing {
	release = willRelease;
    releaseForTesting = testing;
}

- (void) setSettings: (IFCompilerSettings*) set {
    if (settings) [settings release];

    settings = [set retain];
}

- (void) setInputFile: (NSString*) path {
    if (inputFile) [inputFile release];

    inputFile = [path copyWithZone: [self zone]];
}

- (NSString*) inputFile {
    return inputFile;
}

- (IFCompilerSettings*) settings {
    return settings;
}

- (void) deleteOutput {
    if (outputFile) {
        if ([[NSFileManager defaultManager] fileExistsAtPath: outputFile]) {
            NSLog(@"Removing '%@'", outputFile);
            NSError* error;
            [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:outputFile isDirectory:FALSE] error:&error];
        } else {
            NSLog(@"Compiler produced no output");
            // Nothing to do
        }
        
        [outputFile release];
        outputFile = nil;
    }
}

- (void) addCustomBuildStage: (NSString*) command
               withArguments: (NSArray*) arguments
              nextStageInput: (NSString*) file
				errorHandler: (NSObject<IFCompilerProblemHandler>*) handler
					   named: (NSString*) stageName {
    if (theTask) {
        // This starts a new build process, so we kill the old task if it's still
        // running
        if ([theTask isRunning]) {
            [theTask terminate];
        }
        [theTask release];
        theTask = nil;
    }

    [runQueue addObject: [NSArray arrayWithObjects:
        command,
        arguments,
        file,
		stageName,
		handler,
		nil]];
}

- (void) addNaturalInformStage {
    // Prepare the arguments
    NSMutableArray* args = [NSMutableArray arrayWithArray: [settings naturalInformCommandLineArguments]];

    [args addObject: @"-project"];
    [args addObject: [NSString stringWithString: [self currentStageInput]]];
	[args addObject: [NSString stringWithFormat: @"-format=%@", [settings fileExtension]]];
	
	if (release) {
		[args addObject: @"-release"];
	}
	
	if ([settings nobbleRng] && !release) {
		[args addObject: @"-rng"];
	}
	
    [self addCustomBuildStage: [settings naturalInformCompilerToUse]
                withArguments: args
               nextStageInput: [NSString stringWithFormat: @"%@/Build/auto.inf", [self currentStageInput]]
				 errorHandler: [[[IFNaturalProblem alloc] init] autorelease]
						named: [IFUtility localizedString: @"Compiling Natural Inform source"]];
}

- (void) addStandardInformStage: (BOOL) usingNaturalInform {
    if (!outputFile) [self outputFile];
    
    // Prepare the arguments
    NSMutableArray* args = [NSMutableArray arrayWithArray: [settings commandLineArgumentsForRelease: release
                                                                                         forTesting: releaseForTesting]];

    // [args addObject: @"-x"];
   
    [args addObject: [NSString stringWithString: [self currentStageInput]]];
    [args addObject: [NSString stringWithString: outputFile]];

    [self addCustomBuildStage: [settings compilerToUse]
                withArguments: args
               nextStageInput: outputFile
				 errorHandler: usingNaturalInform?[[[IFInform6Problem alloc] init] autorelease]:nil
						named: [IFUtility localizedString: @"Compiling Inform 6 source"]];
}

- (NSString*) currentStageInput {
    NSString* inFile = inputFile;
    if (![runQueue count] <= 0) inFile = [[runQueue lastObject] objectAtIndex: 2];

    return inFile;
}

- (BOOL) isRunning {
	return theTask!=nil?[theTask isRunning]:NO;
}

- (void) sendTaskDetails: (NSTask*) task {
	NSMutableString* taskMessage = [NSMutableString stringWithFormat: @"Launching: %@", [[task launchPath] lastPathComponent]];
	
	for( NSString* arg in [task arguments] ) {
		[taskMessage appendFormat: @" \"%@\"", arg];
	}

	[taskMessage appendString: @"\n"];
	[self sendStdOut: taskMessage];
}

- (void) prepareForLaunchWithBlorbStage: (BOOL) makeBlorb {
    // Kill off any old tasks...
    if (theTask) {
        if ([theTask isRunning]) {
            [theTask terminate];
        }
        [theTask release];
        theTask = nil;		
    }

	// There are no problems
	[problemsURL release]; problemsURL = nil;

    if (deleteOutputFile) [self deleteOutput];

    // Prepare the arguments
    if ([runQueue count] <= 0) {
        if ([[IFPreferences sharedPreferences] runBuildSh] && ![IFUtility isSandboxed]) {
            NSString* buildsh;

            buildsh = [@"~/build.sh" stringByExpandingTildeInPath];
            
			[self addCustomBuildStage: buildsh
						withArguments: [NSArray array]
					   nextStageInput: [self currentStageInput]
						 errorHandler: nil
								named: @"Debug build stage"];
        }

        if ([settings usingNaturalInform]) {
            [self addNaturalInformStage];
        }

        if (![settings usingNaturalInform] || [settings compileNaturalInformOutput]) {
            [self addStandardInformStage: [settings usingNaturalInform]];
        }

		if (makeBlorb && [settings usingNaturalInform]) {
			// Blorb files kind of create an exception: we change our output file, for instance, and the input file is determined by the blurb file output by NI
			NSString* extension;

			if ([settings zcodeVersion] > 128) {
				extension = @"gblorb";
			} else {
				extension = @"zblorb";
			}

			// Work out the new output file
			NSString* oldOutput = [self outputFile];
			NSString* newOutput = [NSString stringWithFormat: @"%@.%@", [oldOutput stringByDeletingPathExtension], extension];

			// Work out where the blorb is coming from (this will only work for project directories, which luckily is all the current version of Inform will compile)
			NSString* blorbFile = [NSString stringWithFormat: @"%@/Release.blurb",
				[[[self currentStageInput] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]];

			// Add a cBlorb stage
            NSString *cBlorbLocation = [[[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"cBlorb"];

			[self addCustomBuildStage: cBlorbLocation
						withArguments: [NSArray arrayWithObjects:
							blorbFile, 
							newOutput, 
							nil]
					   nextStageInput: newOutput
						 errorHandler: [[[IFCblorbProblem alloc] initWithBuildDir: [[self currentStageInput] stringByDeletingLastPathComponent]] autorelease]
								named: @"cBlorb build stage"];
			
			// Change the output file
			[self setOutputFile: newOutput];
		}
    }

    /*
    NSMutableArray* args = [NSMutableArray arrayWithArray: [settings commandLineArguments]];

    [args addObject: @"-x"];

    [args addObject: [NSString stringWithString: inputFile]];
    [args addObject: [NSString stringWithString: outputFile]];
     */
    
	NSString* stageName = [[runQueue objectAtIndex: 0] objectAtIndex: 3];
    [progress setMessage: stageName];
    [endTextString release];
    endTextString = nil;
	[progress startProgress];
	
    NSArray* args     = [[runQueue objectAtIndex: 0] objectAtIndex: 1];
    NSString* command = [[runQueue objectAtIndex: 0] objectAtIndex: 0];
	
	[problemHandler release]; problemHandler = nil;
	if ([[runQueue objectAtIndex: 0] count] > 4) {
		problemHandler = [[[runQueue objectAtIndex: 0] objectAtIndex: 4] retain];
	}
	
    [[args retain] autorelease];
    [[command retain] autorelease];
    [runQueue removeObjectAtIndex: 0];

    // Prepare the task
    theTask = [[NSTask alloc] init];
    finishCount = 0;
	
	if ([settings debugMemory]) {
		NSMutableDictionary* newEnvironment = [[theTask environment] mutableCopy];
		if (!newEnvironment) newEnvironment = [[NSMutableDictionary alloc] init];
		
		[newEnvironment setObject: @"1"
						   forKey: @"MallocGuardEdges"];
		[newEnvironment setObject: @"1"
						   forKey: @"MallocScribble"];
		[newEnvironment setObject: @"1"
						   forKey: @"MallocBadFreeAbort"];
		[newEnvironment setObject: @"512"
						   forKey: @"MallocCheckHeapStart"];
		[newEnvironment setObject: @"256"
						   forKey: @"MallocCheckHeapEach"];
		[newEnvironment setObject: @"1"
						   forKey: @"MallocStackLogging"];
		
		[theTask setEnvironment: newEnvironment];
		[newEnvironment release];
	}
	
	NSMutableString* executeString = [@"" mutableCopy];
		
	[executeString appendString: command];
	[executeString appendString: @" \\\n\t"];

	for( NSString* arg in args ) {
		[executeString appendString: arg];
		[executeString appendString: @" "];
	}
		
	[executeString appendString: @"\n"];
	[self sendStdOut: executeString];
	[executeString release]; executeString = nil;

    [theTask setArguments:  args];
    [theTask setLaunchPath: command];
    if (workingDirectory)
        [theTask setCurrentDirectoryPath: workingDirectory];
    else
        [theTask setCurrentDirectoryPath: NSTemporaryDirectory()];

    // Prepare the task's IO

    // waitForDataInBackground is a daft way of doing things and a waste of a thread
    if (stdErr) [stdErr release];
    if (stdOut) [stdOut release];
	
	if (stdErrH) [stdErrH release];
	if (stdOutH) [stdOutH release];
	
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    stdErr = [[NSPipe alloc] init];
    stdOut = [[NSPipe alloc] init];

    [theTask setStandardOutput: stdOut];
    [theTask setStandardError:  stdErr];

    stdErrH = [[stdErr fileHandleForReading] retain];
    stdOutH = [[stdOut fileHandleForReading] retain];

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

- (void) launch {
    [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStartingNotification
                                                        object: self];
	[self sendTaskDetails: theTask];
    [theTask launch];
}

- (NSURL*)    problemsURL {
	return problemsURL;
}

- (NSString*) outputFile {
    if (outputFile == nil) {
        outputFile = [[NSString stringWithFormat: @"%@/Inform-%x-%x.%@",
            NSTemporaryDirectory(), (int) time(NULL), ++mod, [settings fileExtension]] retain];
        deleteOutputFile = YES;
    }

    return [NSString stringWithString: outputFile];
}

- (void) setOutputFile: (NSString*) file {
    if (outputFile) [outputFile release];
    outputFile = [file copy];
    deleteOutputFile = NO;
}

- (void) setDeletesOutput: (BOOL) deletes {
    deleteOutputFile = deletes;
}

- (void) setDelegate: (id<NSObject>) dg {
	delegate = dg;
    //if (delegate) [delegate release];
    //delegate = [dg retain];
}

- (id) delegate {
    return delegate;
}

- (void) setDirectory: (NSString*) path {
    if (workingDirectory) [workingDirectory release];
    workingDirectory = [path copy];
}

- (NSString*) directory {
    return [[workingDirectory copy] autorelease];
}

- (void) taskHasReallyFinished {
	int exitCode = [theTask terminationStatus];

    if ([runQueue count] == 0) {
        if (exitCode != 0 && problemHandler) {
			[problemsURL release]; problemsURL = nil;
			
			problemsURL = [[problemHandler urlForProblemWithErrorCode: exitCode] copy];
		} else if (exitCode == 0 && problemHandler) {
			if ([problemHandler respondsToSelector: @selector(urlForSuccess)]) {
				problemsURL = [[problemHandler urlForSuccess] copy];
			}
		}
			
        if (delegate &&
            [delegate respondsToSelector: @selector(taskFinished:)]) {
            [delegate taskFinished: exitCode];
        }

		[progress stopProgress];
        
        // Show final message from compiler
        if( endTextString ) {
            [progress setMessage: endTextString];
            [endTextString release];
            endTextString = nil;
        }
        NSDictionary* uiDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt: exitCode],
                                @"exitCode",
                                nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerFinishedNotification
                                                            object: self
                                                          userInfo: uiDict];
    } else {
        if (exitCode != 0) {
			if (problemHandler) {
				[problemsURL release]; problemsURL = nil;
				
				problemsURL = [[problemHandler urlForProblemWithErrorCode: exitCode] copy];
			}
			
            // The task failed
            if (delegate &&
                [delegate respondsToSelector: @selector(taskFinished:)]) {
                [delegate taskFinished: exitCode];
            }
            [progress stopProgress];
            
            // Show final message from compiler
            if( endTextString ) {
                [progress setMessage: endTextString];
                [endTextString release];
                endTextString = nil;
            }
            
            // Notify everyone of the failure
            NSDictionary* uiDict = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInt: exitCode],
                @"exitCode",
                nil];
            [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerFinishedNotification
                                                                object: self
                                                              userInfo: uiDict];
            
            // Give up
            [runQueue removeAllObjects];
            [theTask release];
            theTask = nil;
            
            return;
        }
        
        // Prepare the next task for launch
        if (theTask) {
            if ([theTask isRunning]) {
                [theTask terminate];
            }
            [theTask release];
            theTask = nil;
        }
		
		NSString* stageName = [[runQueue objectAtIndex: 0] objectAtIndex: 3];
        [progress setMessage: stageName];
		
        NSArray* args     = [[runQueue objectAtIndex: 0] objectAtIndex: 1];
        NSString* command = [[runQueue objectAtIndex: 0] objectAtIndex: 0];

		[problemHandler release]; problemHandler = nil;
		if ([[runQueue objectAtIndex: 0] count] > 4) {
			problemHandler = [[[runQueue objectAtIndex: 0] objectAtIndex: 4] retain];
		}

		[[args retain] autorelease];
        [[command retain] autorelease];
        [runQueue removeObjectAtIndex: 0];

        theTask = [[NSTask alloc] init];
        finishCount = 0;
		
		if ([settings debugMemory]) {
			NSMutableDictionary* newEnvironment = [[theTask environment] mutableCopy];
			if (!newEnvironment) newEnvironment = [[NSMutableDictionary alloc] init];
			
			[newEnvironment setObject: @"1"
							   forKey: @"MallocGuardEdges"];
			[newEnvironment setObject: @"1"
							   forKey: @"MallocScribble"];
			[newEnvironment setObject: @"1"
							   forKey: @"MallocBadFreeAbort"];
			[newEnvironment setObject: @"512"
							   forKey: @"MallocCheckHeapStart"];
			[newEnvironment setObject: @"256"
							   forKey: @"MallocCheckHeapEach"];
			[newEnvironment setObject: @"1"
							   forKey: @"MallocStackLogging"];
			
			[theTask setEnvironment: newEnvironment];
			[newEnvironment release];
		}
		
		NSMutableString* executeString = [@"" mutableCopy];
			
		[executeString appendString: command];
		[executeString appendString: @" \\\n\t"];
			
		for( NSString* arg in args ) {
			[executeString appendString: arg];
			[executeString appendString: @" "];
		}
			
		[executeString appendString: @"\n"];
		[self sendStdOut: executeString];
		[executeString release]; executeString = nil;
		
        // Prepare the task
        [theTask setArguments:  args];
        [theTask setLaunchPath: command];
        if (workingDirectory)
            [theTask setCurrentDirectoryPath: workingDirectory];
        else
            [theTask setCurrentDirectoryPath: NSTemporaryDirectory()];

        // Prepare the task's IO
        if (stdErr) [stdErr release];
        if (stdOut) [stdOut release];

		if (stdErrH) [stdErrH release];
        if (stdOutH) [stdOutH release];

        [[NSNotificationCenter defaultCenter] removeObserver: self];

        stdErr = [[NSPipe alloc] init];
        stdOut = [[NSPipe alloc] init];

        [theTask setStandardOutput: stdOut];
        [theTask setStandardError:  stdErr];

        stdErrH = [[stdErr fileHandleForReading] retain];
        stdOutH = [[stdOut fileHandleForReading] retain];

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

        // Launch it
		[self sendTaskDetails: theTask];
        [theTask launch];
    }
}

// == Notifications ==
- (void) sendStdOut: (NSString*) data {
	if (delegate &&
		[delegate respondsToSelector: @selector(receivedFromStdOut:)]) {
		[delegate receivedFromStdOut: data]; 
	}
	
	NSDictionary* uiDict = [NSDictionary dictionaryWithObjectsAndKeys:
		data,
		@"string",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStdoutNotification
														object: self
													  userInfo: uiDict];
}

- (void) stdOutWaiting: (NSNotification*) not {
	if (finishCount >= 3) return;

    NSData* inData = [stdOutH availableData];

    if ([inData length]) {
        NSString* newStr = [[[NSString alloc] initWithData:inData
                                                  encoding:NSISOLatin1StringEncoding] autorelease];
		[self sendStdOut:newStr];

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
	
    NSData* inData = [stdErrH availableData];

    if ([inData length]) {
        NSString* newStr = [[[NSString alloc] initWithData:inData
                                                  encoding:NSISOLatin1StringEncoding] autorelease];
        if (delegate &&
            [delegate respondsToSelector: @selector(receivedFromStdErr:)]) {
            [delegate receivedFromStdErr: newStr];
        }

        NSDictionary* uiDict = [NSDictionary dictionaryWithObjectsAndKeys:
                newStr,
                @"string",
                nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: IFCompilerStderrNotification
                                                            object: self
                                                          userInfo: uiDict];
        
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

- (IFProgress*) progress {
	return progress;
}

- (void) setEndTextString: (NSString*) aEndTextString {
    endTextString = [aEndTextString retain];
}

@end
