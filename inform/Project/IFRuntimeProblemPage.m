//
//  IFRuntimeProblemPage.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFRuntimeProblemPage.h"
#import "NSString+IFStringExtensions.h"

@implementation IFRuntimeProblemPage {
    NSURL* errorURL;
    NSString* markdownPath;
}

- (instancetype) initWithProblem: (NSString*) error
                     inDirectory: (NSString*) directory
              materialsDirectory: (NSString*) materialsDirectory
               internalDirectory: (NSString*) internalDirectory {
    self = [super init];

    if (self) {
        if (directory == nil) {
            // If no directory is present, then redirect using old method (looks for a regular resource within the App).

            // The file that might contain the error
            NSString* errorFile = [NSString stringWithFormat: @"RTP_%@", error];

            // See if the file exists
            if ([[NSBundle mainBundle] pathForResource: errorFile
                                                ofType: @"html"] == nil) {
                // The error file cannot be found: use a default
                NSLog(@"Warning: run-time error file '%@.html' not found, using RTP_Unknown.html instead", errorFile);
                errorFile = @"RTP_Unknown";
            }

            // This URL is where the error file will reside
            errorURL = [NSURL URLWithString: [NSString stringWithFormat: @"inform:/%@.html", errorFile]];
        } else {
            NSString* errorFile = [NSString stringWithFormat: @"%@.md", error];
            if ([directory startsWithCaseInsensitive:@"Internal/"]) {
                // If directory starts with "Internal/" then resolve the path to inside the internal directory
                markdownPath = [[internalDirectory stringByAppendingPathComponent: [directory substringFromIndex: 9]] stringByAppendingPathComponent: errorFile];
            } else if ([directory startsWithCaseInsensitive:@"Materials/"]) {
                markdownPath = [[materialsDirectory stringByAppendingPathComponent: [directory substringFromIndex: 10]] stringByAppendingPathComponent: errorFile];
            } else {
                // Otherwise the directory is given in full
                markdownPath = [directory stringByAppendingPathComponent: errorFile];
            }
        }
    }

    return self;
}

- (NSURL*) appPageURL {
    return errorURL;
}

- (NSString*) markdownPath {
    return markdownPath;
}

@end
