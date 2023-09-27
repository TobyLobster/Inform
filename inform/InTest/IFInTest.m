//
//  IFInTest.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFInTest.h"
#import "IFUtility.h"

NSString* const IFInTestStartingNotification = @"IFInTestStartingNotification";
NSString* const IFInTestStdoutNotification   = @"IFInTestStdoutNotification";
NSString* const IFInTestStderrNotification   = @"IFInTestStderrNotification";
NSString* const IFInTestFinishedNotification = @"IFInTestFinishedNotification";


@interface ConcordancePair : NSObject
@end

@implementation ConcordancePair {
@public
    int left;
    int right;
}

@end

@interface IFTestCaseData : NSObject
@end

@implementation IFTestCaseData {
@public
    // Concordance data
    NSMutableArray<ConcordancePair*>* concordance;
}

- (instancetype) init {
    self = [super init];

    if (self) {
        concordance = [[NSMutableArray alloc] init];
    }
    return self;
}

@end

@implementation IFInTest {
    // The task
    /// Task where \c InTest is running
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
    NSMutableString* stdOut;
    NSMutableString* stdErr;

    int             exitCode;

    /// Data for each test case
    NSMutableDictionary<NSString*,IFTestCaseData*>* testCaseData;
}

// == Initialisation, etc ==

- (instancetype) init {
    self = [super init];

    if (self) {
        [self tidyUp];
        testCaseData = [[NSMutableDictionary alloc] init];
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
	return theTask!=nil?theTask.running:NO;
}

-(void) executeInTestForExtension: (NSString*)extensionPathName
                         withArgs: (NSArray*) args {
    if (theTask) {
        if (theTask.running) {
            [theTask terminate];
        }
        theTask = nil;
    }

    NSMutableArray *mutableArgs = [[NSMutableArray alloc] initWithArray:args];
    [mutableArgs insertObject: extensionPathName.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent
                      atIndex: 0];

    NSString *command = [IFUtility pathForInformExecutable: @"intest" version: @""];

    // InTest Start notification
    NSDictionary* uiDict = @{@"command": command,
                             @"args": mutableArgs};
    [[NSNotificationCenter defaultCenter] postNotificationName: IFInTestStartingNotification
                                                        object: self
                                                      userInfo: uiDict];

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
    //NSLog(@"%@", message);

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

    // Stdout
    uiDict = @{@"string": stdOut};
    [[NSNotificationCenter defaultCenter] postNotificationName: IFInTestStdoutNotification
                                                        object: self
                                                      userInfo: uiDict];

    // Stderr
    uiDict = @{@"string": stdErr};
    [[NSNotificationCenter defaultCenter] postNotificationName: IFInTestStderrNotification
                                                        object: self
                                                      userInfo: uiDict];

    // InTest Finished Notification
    uiDict = @{@"exitCode": @(exitCode)};
    [[NSNotificationCenter defaultCenter] postNotificationName: IFInTestFinishedNotification
                                                        object: self
                                                      userInfo: uiDict];
}

-(void) extractSourceTaskForExtensionFile: (NSString*) extensionPathName
                              forTestCase: (NSString*) testCase
                       outputToSourceFile: (NSString*) sourcePathName {
    NSArray* args     = @[ @"-no-history",
                           @"-threads=1",
                           @"-using",
                           @"-extension",   extensionPathName,
                           @"-do",
                           @"-source",      testCase,
                           @"-to",          sourcePathName,
                           @"-concordance", testCase ];
    [self executeInTestForExtension:extensionPathName withArgs:args];

    // Parse concordance
    IFTestCaseData* data = [[IFTestCaseData alloc] init];

    if( exitCode == 0 )
    {
        NSArray* lines = [stdOut componentsSeparatedByString:@"\n"];
        for( NSString* line in lines ) {
            NSInteger equalsIndex = [line indexOf: @" "];
            if( equalsIndex != NSNotFound )
            {
                NSString* left  = [line substringToIndex: equalsIndex].stringByTrimmingWhitespace;
                NSString* right = [line substringFromIndex: equalsIndex + 1].stringByTrimmingWhitespace;
                ConcordancePair * pair = [[ConcordancePair alloc] init];
                pair->left  = left.intValue;
                pair->right = right.intValue;
                [data->concordance addObject: pair];
            }
        }
    }

    testCaseData[testCase] = data;

    // Task is completed - tidy up.
    [self tidyUp];
}

- (NSArray*) refreshExtensionCatalogue:(NSString*) extensionPathName {

    // Get latest catalogue
    NSArray* args     = @[@"-no-history",
                          @"-threads=1",
                          @"-using",
                          @"-extension", extensionPathName,
                          @"-do",
                          @"-catalogue" ];
    [self executeInTestForExtension:extensionPathName withArgs:args];

    // Interpret results
    NSMutableArray* testCases = [[NSMutableArray alloc] init];

    if( exitCode == 0 )
    {
        NSArray* lines = [stdOut componentsSeparatedByString:@"\n"];
        for( NSString* line in lines ) {
            if( [line startsWith: @"extension "] ) {
                NSInteger equalsIndex = [line indexOf: @"="];
                if( equalsIndex != NSNotFound )
                {
                    unichar buffer[2];
                    buffer[0] = 'A' + testCases.count;
                    buffer[1] = 0;
                    NSString* key = [NSString stringWithCharacters: buffer length:1];
                    NSString* title = [line substringFromIndex: equalsIndex + 1].stringByTrimmingWhitespace;
                    [testCases addObject: @{ @"testKey": key,
                                             @"testTitle": title }];
                }
            }
        }
    }

    // Task is completed - tidy up.
    [self tidyUp];

    return testCases;
}

- (NSString*) testCommandsForExtension: (NSString*) extensionPathName
                              testCase: (NSString*) testCase {
    // Get latest catalogue
    NSArray* args     = @[@"-no-history",
                          @"-threads=1",
                          @"-using",
                          @"-extension", extensionPathName,
                          @"-do",
                          @"-script", testCase ];
    [self executeInTestForExtension:extensionPathName withArgs:args];

    // Interpret results
    NSString* results = nil;
    if( exitCode == 0 ) {
        results = stdOut;
    }

    [self tidyUp];
    return results;
}

- (int) generateReportForExtension: (NSString*) extensionPathName
                          testCase: (NSString*) testCase
                         errorCode: (NSString*) errorCode
                       problemsURL: (NSURL*) problemsURL
                          skeinURL: (NSURL*) skeinURL
                       skeinNodeId: (unsigned long) skeinNodeId
                        skeinNodes: (int) skeinNodes
                         outputURL: (NSURL*) outputURL
{
    // Get latest catalogue
    NSArray* args     = @[@"-no-history",
                          @"-threads=1",
                          @"-using",
                          @"-extension", extensionPathName,
                          @"-do",
                          @"-report",
                          testCase,
                          errorCode,
                          problemsURL.path,
                          [NSString stringWithFormat:@"n%lu", skeinNodeId],
                          [NSString stringWithFormat:@"t%d", skeinNodes],
                          @"-to",
                          outputURL.path];
    [self executeInTestForExtension:extensionPathName withArgs:args];

    [self tidyUp];
    return exitCode;
}

- (int) generateCombinedReportForExtension: (NSString*) extensionPathName
                              baseInputURL: (NSURL*) baseInputURL
                                  numTests: (int) numTests
                                 outputURL: (NSURL*) outputURL
{
    // Get latest catalogue
    NSArray* args     = @[@"-no-history",
                          @"-threads=1",
                          @"-using",
                          @"-extension", extensionPathName,
                          @"-do",
                          @"-combine",
                          baseInputURL.path,
                          [NSString stringWithFormat:@"-%d", numTests],
                          @"-to",
                          outputURL.path];
    [self executeInTestForExtension:extensionPathName withArgs:args];

    [self tidyUp];
    return exitCode;
}

-(int) adjustLine:(int) lineNumber forTestCase:(NSString*) testCase {
    IFTestCaseData* data = testCaseData[testCase];

    if( data != nil ) {
        for( ConcordancePair* pair in [data->concordance reverseObjectEnumerator] ) {
            if( lineNumber >= pair->left ) {
                return lineNumber + pair->right;
            }
        }
    }
    return lineNumber;
}

@end
