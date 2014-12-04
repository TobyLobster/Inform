//
//  ZoomGlkDocument.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkDocument.h"
#import "ZoomGlkWindowController.h"

@implementation ZoomGlkDocument

// = Initialisation/finalisation =

- (void) dealloc {
	if (clientPath)		[clientPath release];
	if (inputPath)		[inputPath release];
	if (storyData)		[storyData release];
	if (logo)			[logo release];
	if (plugIn)			[plugIn release];
	if (savedGamePath)	[savedGamePath release];
	
	[super dealloc];
}

- (NSData *)dataRepresentationOfType:(NSString *)type {
	// Glk documents are never saved
    return nil;
}

- (BOOL) loadDataRepresentation: (NSData*) data
						 ofType: (NSString*) type {
	// Neither are they really loaded: we initialise via the plugin
    return YES;
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newClientPath {
	[clientPath release];
	clientPath = [newClientPath copy];
}

- (void) setInputFilename: (NSString*) newInputPath {
	[inputPath release];
	inputPath = [newInputPath copy];
	
	[self setFileName: newInputPath];
}

- (void) setStoryData: (ZoomStory*) story {
	[storyData release];
	storyData = [story retain];
}

- (void) setLogo: (NSImage*) newLogo {
	[logo release];
	logo = [newLogo retain];
}

- (ZoomStory*) storyData {
	return storyData;
}

- (void) setPreferredSaveDirectory: (NSString*) dir {
	preferredSaveDir = [dir copy];
}

- (NSString*) preferredSaveDirectory {
	return preferredSaveDir;
}

- (void) setPlugIn: (ZoomPlugIn*) newPlugIn {
	[plugIn release];
	plugIn = [newPlugIn retain];
}

- (ZoomPlugIn*) plugIn {
	return [[plugIn retain] autorelease];
}

- (void) setSaveGame: (NSString*) saveGame {
	[savedGamePath release];
	savedGamePath = [saveGame copy];
}

// = Constructing the window controllers =

- (void) makeWindowControllers {
	// Set up the window controller
	ZoomGlkWindowController* controller = [[ZoomGlkWindowController alloc] init];
	
	// Give it the paths
	[controller setClientPath: clientPath];
	[controller setInputFilename: inputPath];
	[controller setCanOpenSaveGame: [[plugIn class] canLoadSavegames]];
	if (savedGamePath) [controller setSaveGame: savedGamePath];
	[controller setLogo: logo];
	
	// Add it as a controller for this document
	[self addWindowController: [controller autorelease]];
}

// = The display name =

- (NSString*) displayName {
	if (storyData && [storyData title] && [[storyData title] length] > 0) {
		return [storyData title];
	}
	
	return [super displayName];
}

@end
