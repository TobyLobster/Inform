//
//  ZoomGlkPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkPlugIn.h"


@implementation ZoomGlkPlugIn

#pragma mark - Initialisation

- (id)initWithURL: (NSURL *) gameFile {
	self = [super initWithURL: gameFile];
	
	if (self) {
	}
	
	return self;
}

#pragma mark - Overrides from ZoomPlugIn

+ (BOOL) canLoadSavegames {
	return NO;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	if (!document) {
		// Set up the document for this game
		document = [[ZoomGlkDocument alloc] init];

		// Tell it what it needs to know
		document.storyData = story;
		document.clientPath = clientPath;
		[document setInputURL: self.gameURL];
		document.logo = self.logo;
		document.preferredSaveDirectory = preferredSaveDir;
		document.plugIn = self;
	}
	
	// Return it
	return document;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
							 saveGameURL: (NSURL *)saveGame {
	if (!document) {
		// Set up the document for this game
		document = [[ZoomGlkDocument alloc] init];
		
		// Tell it what it needs to know
		document.storyData = story;
		document.clientPath = clientPath;
		[document setInputURL: self.gameURL];
		document.logo = self.logo;
		document.preferredSaveDirectory = preferredSaveDir;
		document.saveGameURL = saveGame;
		document.plugIn = self;
	}
	
	// Return it
	return document;	
}

#pragma mark - Configuring the client

@synthesize clientPath;

- (NSImage*) logo {
	return nil;
}

@synthesize preferredSaveDirectoryURL = preferredSaveDir;

@end
