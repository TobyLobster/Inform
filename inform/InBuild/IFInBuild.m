//
//  IFInBuild.m
//  Inform
//
//  Created by Toby Nelson in 2023
//

#import "IFInBuild.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

NSString* const IFInBuildStartingNotification = @"IFInTestStartingNotification";
NSString* const IFInBuildStdoutNotification   = @"IFInTestStdoutNotification";
NSString* const IFInBuildStderrNotification   = @"IFInTestStderrNotification";
NSString* const IFInBuildFinishedNotification = @"IFInTestFinishedNotification";


@implementation IFInBuild {
    // The task
    /// Task where InBuild is running
    NSTask*         theTask;

    // Output/input streams
    /// stdErr pipe
    NSPipe*         stdErrPipe;
    /// stdOut pipe
    NSPipe*         stdOutPipe;

    /// File handle for stderr
    NSFileHandle*   stdErrH;
    /// File handle for stdout
    NSFileHandle*   stdOutH;

    // Results
    //NSMutableString* stdOut;
    //NSMutableString* stdErr;

    int             exitCode;
}

@synthesize stdOut;
@synthesize stdErr;

// == Initialisation, etc ==

- (instancetype) init {
    self = [super init];

    if (self) {
        [self tidyUp];
    }

    return self;
}

-(void) tidyUp {
    theTask     = nil;
    stdOutPipe  = nil;
    stdErrPipe  = nil;
    stdErrH     = nil;
    stdOutH     = nil;
    exitCode    = 0;
    stdErr      = nil;
    stdOut      = nil;
}

#pragma mark - Setup

- (BOOL) isRunning {
    return (theTask != nil) ? theTask.running : NO;
}

-(int) executeInBuildForInfoWithProject: (NSURL*) projectURL
                                 action: (NSString*) action
                           forExtension: (NSURL*) extensionURL
                           withInternal: (NSURL*) internalURL
                       withConfirmation: (bool) confirmed
                            withResults: (NSURL*) resultsURL
                               settings: (IFCompilerSettings*) settings {
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    // Build a command with arguments:
    //  inbuild -project PROJECTDIR -install EXTENSION -results RESULTS

    NSMutableArray *mutableArgs = [[NSMutableArray alloc] init];
    [mutableArgs addObject: @"-project"];
    [mutableArgs addObject: projectURL.path];
    [mutableArgs addObject: action];
    [mutableArgs addObject: extensionURL.path];
    [mutableArgs addObject: @"-results"];
    [mutableArgs addObject: resultsURL.path];
    [mutableArgs addObject: @"-internal"];
    [mutableArgs addObject: internalURL.path];

    if (settings.allowLegacyExtensionDirectory) {
        NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
        if (externalPath != nil) {
            [mutableArgs addObject: @"-deprecated-external"];
            [mutableArgs addObject: externalPath];
        }
    }

    if (confirmed) {
        [mutableArgs addObject: @"-confirmed"];
    }

    NSString *command = [IFUtility pathForInformExecutable: @"inbuild" version: settings.compilerVersion];

    // InBuild Start notification
    //NSDictionary* uiDict = @{@"command": command,
    //                         @"args": mutableArgs};
    //[[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStartingNotification
    //                                                    object: self
    //                                                  userInfo: uiDict];

    stdErr = [[NSMutableString alloc] init];
    stdOut = [[NSMutableString alloc] init];

    // Prepare the task (based on http://stackoverflow.com/questions/412562/execute-a-terminal-command-from-a-cocoa-app )
    theTask = [[NSTask alloc] init];

    theTask.arguments = mutableArgs;
    theTask.launchPath = command;
    theTask.currentDirectoryPath = NSTemporaryDirectory();

    NSMutableString* message = [[NSMutableString alloc] init];
    [message appendFormat:@"Current Directory: %@\n", NSTemporaryDirectory()];
    [message appendFormat:@"Command: %@\n", command];
    [message appendString:@"Args: "];
    for(NSString* arg in mutableArgs) {
        bool hasSpaces = ( [arg indexOf:@" "] != NSNotFound );
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: arg];
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: @"\n      "];
    }
    NSLog(@"%@", message);

    // Prepare the task's IO
    stdErrPipe = [[NSPipe alloc] init];
    stdOutPipe = [[NSPipe alloc] init];

    theTask.standardOutput = stdOutPipe;
    theTask.standardError = stdErrPipe;
    theTask.standardInput = [NSPipe pipe];       // "The magic line that keeps your log where it belongs"

    stdOutH = stdOutPipe.fileHandleForReading;
    stdErrH = stdErrPipe.fileHandleForReading;

    // Start the task
    [theTask launch];

    // Wait until finished
    NSMutableData *data = [NSMutableData dataWithCapacity:512];
    while (theTask.running) {
        [data appendData:[stdOutH readDataToEndOfFile]];
    }
    [data appendData:[stdOutH readDataToEndOfFile]];

    // Record output
    stdOut = [[[NSString alloc] initWithData: data
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    stdErr = [[[NSString alloc] initWithData: [stdErrH readDataToEndOfFile]
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    exitCode = theTask.terminationStatus;

    /*
     // Stdout
     uiDict = @{@"string": stdOut};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStdoutNotification
     object: self
     userInfo: uiDict];

     // Stderr
     uiDict = @{@"string": stdErr};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStderrNotification
     object: self
     userInfo: uiDict];
     // InTest Finished Notification
     uiDict = @{@"exitCode": @(exitCode)};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildFinishedNotification
     object: self
     userInfo: uiDict];
     */
    if (exitCode != 0) {
        // Write error messaging as HTML page to resultsURL
        NSString * errorHTML = [NSString stringWithFormat:
                                @"<HTML><body>There was an error running inbuild:<br><pre>%@\nstdout: %@\nstderr: %@exit code: %d</pre></body></html>",
                                message, stdOut, stdErr, exitCode];

        [errorHTML writeToFile: resultsURL.path
                    atomically: NO
                      encoding: NSStringEncodingConversionAllowLossy
                         error: nil];
    }
    NSLog(@"stdout: %@", stdOut);
    NSLog(@"stderr: %@", stdErr);
    NSLog(@"exit code: %d", exitCode);
    return exitCode;
}

-(int) executeInBuildForCensus {
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
    if (externalPath == nil) {
        return 0;
    }
    externalPath = [externalPath stringByAppendingPathComponent: @"Extensions"];

    NSString* internalPath = [IFUtility pathForInformInternalAppSupport:@""];

    // Build a command with arguments:
    // inbuild -inspect -recursive -contents-of ~/Library/Inform/Extensions

    NSMutableArray *mutableArgs = [[NSMutableArray alloc] init];
    [mutableArgs addObject: @"-inspect"];
    [mutableArgs addObject: @"-recursive"];
    [mutableArgs addObject: @"-contents-of"];
    [mutableArgs addObject: externalPath];
    [mutableArgs addObject: @"-internal"];
    [mutableArgs addObject: internalPath];
    [mutableArgs addObject: @"-json"];
    [mutableArgs addObject: @"-"];

    // Use latest inbuild
    NSString *command = [IFUtility pathForInformExecutable: @"inbuild" version: @""];

    // InBuild Start notification
    //NSDictionary* uiDict = @{@"command": command,
    //                         @"args": mutableArgs};
    //[[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStartingNotification
    //                                                    object: self
    //                                                  userInfo: uiDict];

    stdErr = [[NSMutableString alloc] init];
    stdOut = [[NSMutableString alloc] init];

    // Prepare the task (based on http://stackoverflow.com/questions/412562/execute-a-terminal-command-from-a-cocoa-app )
    theTask = [[NSTask alloc] init];

    theTask.arguments = mutableArgs;
    theTask.launchPath = command;
    theTask.currentDirectoryPath = NSTemporaryDirectory();

    NSMutableString* message = [[NSMutableString alloc] init];
    [message appendFormat:@"Current Directory: %@\n", NSTemporaryDirectory()];
    [message appendFormat:@"Command: %@\n", command];
    [message appendString:@"Args: "];
    for(NSString* arg in mutableArgs) {
        bool hasSpaces = ( [arg indexOf:@" "] != NSNotFound );
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: arg];
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: @"\n      "];
    }
    NSLog(@"%@", message);

    // Prepare the task's IO
    stdErrPipe = [[NSPipe alloc] init];
    stdOutPipe = [[NSPipe alloc] init];

    theTask.standardOutput = stdOutPipe;
    theTask.standardError = stdErrPipe;
    theTask.standardInput = [NSPipe pipe];       // "The magic line that keeps your log where it belongs"

    stdOutH = stdOutPipe.fileHandleForReading;
    stdErrH = stdErrPipe.fileHandleForReading;

    // Start the task
    [theTask launch];

    // Wait until finished
    NSMutableData *data = [NSMutableData dataWithCapacity:512];
    while (theTask.running) {
        [data appendData:[stdOutH readDataToEndOfFile]];
    }
    [data appendData:[stdOutH readDataToEndOfFile]];

    // Record output
    stdOut = [[[NSString alloc] initWithData: data
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    stdErr = [[[NSString alloc] initWithData: [stdErrH readDataToEndOfFile]
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    exitCode = theTask.terminationStatus;

    /*
     // Stdout
     uiDict = @{@"string": stdOut};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStdoutNotification
     object: self
     userInfo: uiDict];

     // Stderr
     uiDict = @{@"string": stdErr};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildStderrNotification
     object: self
     userInfo: uiDict];
     // InTest Finished Notification
     uiDict = @{@"exitCode": @(exitCode)};
     [[NSNotificationCenter defaultCenter] postNotificationName: IFInBuildFinishedNotification
     object: self
     userInfo: uiDict];
     */

    NSLog(@"stdout: %@", stdOut);
    NSLog(@"stderr: %@", stdErr);
    NSLog(@"exit code: %d", exitCode);

    return exitCode;
}

-(int) executeInBuildForConvertingMarkdown: (NSString*) markdownFilepath
                                    toHTML: (NSString*) htmlFilepath
                              withInternal: (NSURL*) internalURL
                                  settings: (IFCompilerSettings*) settings {
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    // Build a command with arguments:
    // inbuild -internal INTERNAL -markdown-from MARKDOWNFILE -markdown-to HTMLFILE

    NSMutableArray *mutableArgs = [[NSMutableArray alloc] init];
    [mutableArgs addObject: @"-internal"];
    [mutableArgs addObject: internalURL.path];
    [mutableArgs addObject: @"-markdown-from"];
    [mutableArgs addObject: markdownFilepath];
    [mutableArgs addObject: @"-markdown-to"];
    [mutableArgs addObject: htmlFilepath];

    NSString *command = [IFUtility pathForInformExecutable: @"inbuild" version: settings.compilerVersion];

    stdErr = [[NSMutableString alloc] init];
    stdOut = [[NSMutableString alloc] init];

    // Prepare the task (based on http://stackoverflow.com/questions/412562/execute-a-terminal-command-from-a-cocoa-app )
    theTask = [[NSTask alloc] init];

    theTask.arguments = mutableArgs;
    theTask.launchPath = command;
    theTask.currentDirectoryPath = NSTemporaryDirectory();

    NSMutableString* message = [[NSMutableString alloc] init];
    [message appendFormat:@"Current Directory: %@\n", NSTemporaryDirectory()];
    [message appendFormat:@"Command: %@\n", command];
    [message appendString:@"Args: "];
    for(NSString* arg in mutableArgs) {
        bool hasSpaces = ( [arg indexOf:@" "] != NSNotFound );
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: arg];
        if( hasSpaces ) [message appendString: @"'"];
        [message appendString: @"\n      "];
    }
    NSLog(@"%@", message);

    // Prepare the task's IO
    stdErrPipe = [[NSPipe alloc] init];
    stdOutPipe = [[NSPipe alloc] init];

    theTask.standardOutput = stdOutPipe;
    theTask.standardError = stdErrPipe;
    theTask.standardInput = [NSPipe pipe];       // "The magic line that keeps your log where it belongs"

    stdOutH = stdOutPipe.fileHandleForReading;
    stdErrH = stdErrPipe.fileHandleForReading;

    // Start the task
    [theTask launch];

    // Wait until finished
    NSMutableData *data = [NSMutableData dataWithCapacity:512];
    while (theTask.running) {
        [data appendData:[stdOutH readDataToEndOfFile]];
    }
    [data appendData:[stdOutH readDataToEndOfFile]];

    // Record output
    stdOut = [[[NSString alloc] initWithData: data
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    stdErr = [[[NSString alloc] initWithData: [stdErrH readDataToEndOfFile]
                                    encoding: NSUTF8StringEncoding] mutableCopy];
    exitCode = theTask.terminationStatus;

    if (exitCode != 0) {
        // Write error messaging as HTML page to resultsURL
        NSString * errorHTML = [NSString stringWithFormat:
                                @"<HTML><body>There was an error running inbuild:<br><pre>%@\nstdout: %@\nstderr: %@exit code: %d</pre></body></html>",
                                message, stdOut, stdErr, exitCode];

        [errorHTML writeToFile: htmlFilepath
                    atomically: NO
                      encoding: NSStringEncodingConversionAllowLossy
                         error: nil];
    }
    NSLog(@"stdout: %@", stdOut);
    NSLog(@"stderr: %@", stdErr);
    NSLog(@"exit code: %d", exitCode);
    return exitCode;
}

@end
