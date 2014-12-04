//
//  ZoomGlkPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkPlugIn.h"


@implementation ZoomGlkPlugIn

// = Initialisation =

- (id) initWithFilename: (NSString*) gameFile {
	self = [super initWithFilename: gameFile];
	
	if (self) {
	}
	
	return self;
}

- (void) dealloc {
	[clientPath release]; clientPath = nil;
	
	if (document) [document release];
	document = nil;
	
	[preferredSaveDir release];
	
	[super dealloc];
}

// = Overrides from ZoomPlugIn =

+ (BOOL) canLoadSavegames {
	return NO;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	if (!document) {
		// Set up the document for this game
		document = [[ZoomGlkDocument alloc] init];

		// Tell it what it needs to know
		[document setStoryData: story];
		[document setClientPath: clientPath];
		[document setInputFilename: [self gameFilename]];
		[document setLogo: [self logo]];
		[document setPreferredSaveDirectory: preferredSaveDir];
		[document setPlugIn: self];
	}
	
	// Return it
	return document;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
								saveGame: (NSString*) saveGame {
	if (!document) {
		// Set up the document for this game
		document = [[ZoomGlkDocument alloc] init];
		
		// Tell it what it needs to know
		[document setStoryData: story];
		[document setClientPath: clientPath];
		[document setInputFilename: [self gameFilename]];
		[document setLogo: [self logo]];
		[document setPreferredSaveDirectory: preferredSaveDir];
		[document setSaveGame: saveGame];
		[document setPlugIn: self];
	}
	
	// Return it
	return document;	
}

// = Configuring the client =

- (void) setClientPath: (NSString*) newPath {
	[clientPath release];
	clientPath = nil;
	clientPath = [newPath copy];
}

- (NSImage*) logo {
	return nil;
}

- (void) setPreferredSaveDirectory: (NSString*) dir {
	preferredSaveDir = [dir copy];
}

@end
