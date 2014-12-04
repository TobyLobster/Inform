//
//  ZoomPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#define VERBOSITY 1
#import "ZoomPlugIn.h"


@implementation ZoomPlugIn

// = Informational functions (subclasses should normally override) =

+ (NSString*) pluginVersion {
	NSLog(@"Warning: loaded a plugin which does not provide pluginVersion");
	
	return @"Unknown";
}

+ (NSString*) pluginDescription {
	NSLog(@"Warning: loaded a plugin which does not provide pluginDescription");
	
	return @"Unknown plugin";
}

+ (NSString*) pluginAuthor {
	NSLog(@"Warning: loaded a plugin which does not provide pluginAuthor");
	
	return @"Joe Anonymous";
}

+ (BOOL) canLoadSavegames {
	return NO;
}

+ (BOOL) canRunPath: (NSString*) path {
	return NO;
}

// = Designated initialiser =

- (id) init {
	[NSException raise: @"ZoomNoPlugInFilename"
				format: @"An attempt was made to construct a plugin object without providing a filename"];
	
	return nil;
}

- (id) initWithFilename: (NSString*) filename {
	self = [super init];
	
	if (self) {
		gameFile = [filename copy];
		gameData = nil;
	}
	
	return self;
}

- (void) dealloc {
	[gameData release]; gameData = nil;
	[gameFile release]; gameFile = nil;
	
	[super dealloc];
}

// = Getting information about what this plugin should be doing =

- (NSString*) gameFilename {
	return gameFile;
}

- (NSData*) gameData {
	if (gameData == nil) {
		gameData = [[NSData alloc] initWithContentsOfFile: gameFile];
	}
	
	return gameData;
}

// = The game window =

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	[NSException raise: @"ZoomNoPlugInInterface" 
				format: @"An attempt was made to load a game whose plugin does not provide an interface"];
	
	return nil;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
								saveGame: (NSString*) saveGame {
	[NSException raise: @"ZoomNoPlugInInterface" 
				format: @"An attempt was made to load a game whose plugin does not provide an interface"];
	
	return nil;	
}

// = Dealing with game metadata =

- (ZoomStoryID*) idForStory {
	// Generate an MD5-based ID
	return [[[ZoomStoryID alloc] initWithData: [self gameData]] autorelease];
}

- (ZoomStory*) defaultMetadata {
	// Just use the default metadata-establishing routine
	return [ZoomStory defaultMetadataForFile: gameFile]; 
}

- (NSImage*) coverImage {
	return nil;
}

// = More information =

- (void) setPreferredSaveDirectory: (NSString*) dir {
	// Default implementation does nothing
}

- (NSImage*) resizeLogo: (NSImage*) input {
	NSSize oldSize = [input size];
	NSImage* result = input;
		
	if (oldSize.width > 256 || oldSize.height > 256) {
		float scaleFactor;
		
		if (oldSize.width > oldSize.height) {
			scaleFactor = 256/oldSize.width;
		} else {
			scaleFactor = 256/oldSize.height;
		}
		
		NSSize newSize = NSMakeSize(scaleFactor * oldSize.width, scaleFactor * oldSize.height);
		
		result = [[[NSImage alloc] initWithSize: newSize] autorelease];
		[result lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		
		[input drawInRect: NSMakeRect(0,0, newSize.width, newSize.height)
				 fromRect: NSMakeRect(0,0, oldSize.width, oldSize.height)
				operation: NSCompositeSourceOver
				 fraction: 1.0];
		[result unlockFocus];
	}
	
	return result;
}

@end
