//
//  IFNaturalExtensionProject.m
//  Inform
//
//  Created by Andrew Hunter on 18/11/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFNaturalExtensionProject.h"
#import "IFSingleFile.h"
#import "IFExtensionsManager.h"
#import "IFPreferences.h"

#import "IFAppDelegate.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"

@implementation IFNaturalExtensionProject

- (void) dealloc {
	[vw release];
	
	[super dealloc];
}

- (NSObject<IFProjectSetupView>*) configView {
	if (!vw) {
		vw = [[IFNaturalExtensionView alloc] init];
		[NSBundle oldLoadNibNamed: @"NaturalExtensionOptions"
                            owner: vw];
	}
	
	[vw setupControls];

	return vw;
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFProjectSetupView>*) view
         withStory: (NSString*) story {
}

- (NSString*) errorMessage {
	if (![vw authorName] || [[vw authorName] isEqualToString: @""]) {
		return [IFUtility localizedString: @"BadExtensionAuthor"];
	}
	if (![vw extensionName] || [[vw extensionName] isEqualToString: @""]) {
		return [IFUtility localizedString: @"BadExtensionName"];
	}
	
	return nil;
}

- (NSString*) confirmationMessage {
	if ([[NSFileManager defaultManager] fileExistsAtPath: [self saveFilename]]) {
		return [IFUtility localizedString: @"Extension already exists"];
	}

	return nil;
}

- (NSString*) saveFilename {
	NSString* extnDir = [IFUtility pathForInformExternalExtensions];
    extnDir = [extnDir stringByAppendingPathComponent: [vw authorName]];
    extnDir = [extnDir stringByAppendingPathComponent: [[vw extensionName] stringByAppendingPathExtension: @"i7x"]];
    return extnDir;
}

- (NSString*) openAsType {
	return @"Inform Extension Directory";
}

- (void) createDeepDirectory: (NSURL*) deepDirectory {
	// Creates a directory and any parent directories as required
    NSError* error;
    [[NSFileManager defaultManager] createDirectoryAtURL: deepDirectory
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
}

- (BOOL) createAndOpenDocument: (NSURL*) fileURL {
	NSString* contents1 = [NSString stringWithFormat: @"%@ by %@ begins here.\n\n", [vw extensionName], [vw authorName]];
	NSString* contents2 = [NSString stringWithFormat: @"\n\n%@ ends here.\n", [vw extensionName]];
	NSString* contents = [NSString stringWithFormat: @"%@%@", contents1, contents2];

    NSRange range = NSMakeRange([contents1 length], 0);

	NSData* contentData = [contents dataUsingEncoding: NSUTF8StringEncoding];

    if( ![fileURL isFileURL] ) {
        return NO;
    }
    
	// Try to create the extension directory, if necessary
    [self createDeepDirectory: [fileURL URLByDeletingLastPathComponent]];

	// Try to create the file
	if (![[NSFileManager defaultManager] createFileAtPath: [fileURL path]
												 contents: contentData
											   attributes: nil]) {
		return NO;
	}

	// Open the file
    NSError* error;
	IFSingleFile* newDoc = [[IFSingleFile alloc] initWithContentsOfURL: fileURL
                                                                ofType: @"Inform 7 extension"
                                                                 error: &error];
	[newDoc setInitialSelectionRange: range];
	[[NSDocumentController sharedDocumentController] addDocument: newDoc];
	[newDoc makeWindowControllers];
	[newDoc showWindows];
    [newDoc autorelease];

	// Update the list of extensions
	[[IFExtensionsManager sharedNaturalInformExtensionsManager] updateExtensions];
	
	return YES;
}

- (void) setInitialFocus: (NSWindow*) window {
    [vw setInitialFocus: window];
}

-(NSRange) initialSelectionRange {
    // Not used. createAndOpenDocument sets the initial range directly.
    return NSMakeRange(0, 0);
}

@end


@implementation IFNaturalExtensionView

- (NSView*) view {
	return view;
}

- (void) setupControls {
	NSString* longuserName = [[IFPreferences sharedPreferences] freshGameAuthorName];

	// If longuserName contains a '.', then we have to enclose it in quotes
	BOOL needQuotes = NO;
	int x;
	for (x=0; x<[longuserName length]; x++) {
		if ([longuserName characterAtIndex: x] == '.') needQuotes = YES;
	}
	
	if (needQuotes) longuserName = [NSString stringWithFormat: @"\"%@\"", longuserName];
	
	[name setStringValue: longuserName];
	[extensionName setStringValue: [IFUtility localizedString: @"New Extension"]];
}

- (NSString*) authorName {
	return [name stringValue];
}

- (NSString*) extensionName {
	return [extensionName stringValue];
}

- (void) setInitialFocus: (NSWindow*) window {
    [window makeFirstResponder: extensionName];
}

@end
