//
//  IFCompilerResultFiles.m
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//

#import "IFCompilerResultFiles.h"

@implementation IFCompilerResultFiles

+ (IFCompilerTabId) tabIdForFile: (NSString *) theFile
{
    /// Fixed dictionary of document names and their tabs
    NSDictionary* tabDictionary = @{@"debug log.txt":         @((int) IFTabDebugging),
                                    @"auto.inf":              @((int) IFTabInform6),
                                    @"problems.html":         @((int) IFTabReport),
                                    @"log of problems.txt":   @((int) IFTabReport),
                                    @"inbuild.html":          @((int) IFTabInBuild),
                                    @"compiler":              @((int) IFTabConsole)};

    NSString* lowerFile = theFile.lowercaseString;

    NSNumber* integer = tabDictionary[lowerFile];
    if( integer == nil ) {
        return IFTabInvalid;
    }
    return (IFCompilerTabId)integer.intValue;
}

+ (NSArray<NSString*>*) filesToShowOf: (NSArray<NSString*>*) files
                    showDebuggingLogs: (BOOL) showDebuggingLogs
                          problemsURL: (NSURL*) lastProblemURL {
	// The set of files we should avoid showing
	NSMutableSet* excludedFiles = [NSMutableSet set];

	if (!showDebuggingLogs) {
		[excludedFiles addObject: @"debug log.txt"];
		[excludedFiles addObject: @"auto.inf"];
	}

	NSString* excludedFilename = nil;
	if (lastProblemURL) {
		excludedFilename = lastProblemURL.path.lastPathComponent.stringByDeletingPathExtension.lowercaseString;
	}

    NSMutableArray<NSString*>* filesToShow = [NSMutableArray array];

	// Enumerate across the list of files
    for( NSString* key in files ) {
        NSString* type = key.pathExtension.lowercaseString;

		// Skip this file if it's in the excluded list
		if ([excludedFiles containsObject: key.lowercaseString]) continue;

		// HTML, text and inf files go in a tab view showing various different status messages
		// With NI, the problems file is most important: we substitute this if the compiler wants
		NSString* filename = key.stringByDeletingPathExtension.lowercaseString;

        bool tempFile = (key.length >= 4) && ([[key substringToIndex: 4].lowercaseString isEqualToString: @"temp"]);
        bool goodFileType = [type isEqualTo: @"inf"] ||
                            [type isEqualTo: @"txt"] ||
                            [type isEqualTo: @"html"] ||
                            [type isEqualTo: @"htm"];
        bool excludedFile = (lastProblemURL != nil) && ([filename isEqualToString: @"problems"] || [filename isEqualToString: excludedFilename]);

        if (!tempFile && !excludedFile && goodFileType) {
			[filesToShow addObject: key];
        }
    }

    return filesToShow;
}

@end
