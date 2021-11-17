//
//  ZoomGlkDocument.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkDocument.h"
#import "ZoomGlkWindowController.h"
#import "ZoomPlugIn.h"

@implementation ZoomGlkDocument

#pragma mark - Initialisation/finalisation

- (NSData *)dataOfType:(NSString *)type error:(NSError * _Nullable *)outError  {
	// Glk documents are never saved
    return nil;
}

- (BOOL) readFromData: (NSData*) data
			   ofType: (NSString*) type
				error: (NSError * _Nullable *)outError {
	// Neither are they really loaded: we initialise via the plugin
    return YES;
}

#pragma mark - Configuring the client

@synthesize clientPath;

- (void) setInputFilename: (NSString*) newInputPath {
	[self setInputURL: [NSURL fileURLWithPath: newInputPath]];
}

- (void) setInputURL: (NSURL*) inputPath {
	inputURL = [inputPath copy];
	
	self.fileURL = inputPath;
}

@synthesize storyData;
@synthesize logo;
@synthesize preferredSaveDirectory=preferredSaveDir;
@synthesize plugIn;
@synthesize saveGameURL=savedGamePath;

#pragma mark - Constructing the window controllers

- (void) makeWindowControllers {
	// Set up the window controller
	ZoomGlkWindowController* controller = [[ZoomGlkWindowController alloc] init];
	
	// Give it the paths
	[controller setClientPath: clientPath];
	[controller setInputFileURL: inputURL];
	[controller setCanOpenSaveGame: [[plugIn class] canLoadSavegames]];
	if (savedGamePath) [controller setSaveGameURL: savedGamePath];
	[controller setLogo: logo];
	
	// Add it as a controller for this document
	[self addWindowController: controller];
}

#pragma mark - The display name

- (NSString*) displayName {
	if (storyData && [storyData title] && [[storyData title] length] > 0) {
		return [storyData title];
	}
	
	return [super displayName];
}

@end
