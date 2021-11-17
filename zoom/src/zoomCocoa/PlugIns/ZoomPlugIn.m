//
//  ZoomPlugIn.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#define VERBOSITY 1
#import "ZoomPlugIn.h"


@implementation ZoomPlugIn {
@private
	/// The game that this plugin will play
	NSURL* gameFile;
	/// The game data (loaded on demand)
	NSData* gameData;
}

#pragma mark - Informational functions (subclasses should normally override)

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
	return [self canRunURL: [NSURL fileURLWithPath: path]];
}

+ (BOOL) canRunURL: (NSURL*) path {
	return NO;
}

+ (NSArray<NSString*>*)supportedFileTypes {
	return @[];
}

#pragma mark - Designated initialiser

- (id) init {
	[NSException raise: @"ZoomNoPlugInFilename"
				format: @"An attempt was made to construct a plugin object without providing a filename"];
	
	return nil;
}

- (id) initWithFilename: (NSString*) filename {
	return [self initWithURL: [NSURL fileURLWithPath:filename]];
}

- (id) initWithURL:(NSURL *)fileURL {
	self = [super init];
	
	if (self) {
		gameFile = [fileURL copy];
		gameData = nil;
	}
	
	return self;
}

#pragma mark - Getting information about what this plugin should be doing

@synthesize gameURL=gameFile;
@synthesize gameData;

- (NSString *)gameFilename {
	return gameFile.path;
}

- (NSData*) gameData {
	if (gameData == nil) {
		gameData = [[NSData alloc] initWithContentsOfURL: gameFile];
	}
	
	return gameData;
}

#pragma mark - The game window

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story {
	[NSException raise: @"ZoomNoPlugInInterface" 
				format: @"An attempt was made to load a game whose plugin does not provide an interface"];
	
	return nil;
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
								saveGame: (NSString*) saveGame {
	return [self gameDocumentWithMetadata: story
							  saveGameURL: saveGame ? [NSURL fileURLWithPath: saveGame] : nil];
}

- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
							 saveGameURL: (NSURL *)saveGame {
	[NSException raise: @"ZoomNoPlugInInterface"
				format: @"An attempt was made to load a game whose plugin does not provide an interface"];
	
	return nil;
}

#pragma mark - Dealing with game metadata

- (ZoomStoryID*) idForStory {
	// Generate an MD5-based ID
	return [[ZoomStoryID alloc] initWithData: [self gameData]];
}

- (ZoomStory*) defaultMetadata {
	// Just use the default metadata-establishing routine
	return [self defaultMetadataWithError: NULL];
}

- (ZoomStory*) defaultMetadataWithError:(NSError *__autoreleasing *)outError {
	// Just use the default metadata-establishing routine
	return [ZoomStory defaultMetadataForURL: gameFile error: outError];
}

- (NSImage*) coverImage {
	return nil;
}

#pragma mark - More information

- (void) setPreferredSaveDirectory: (NSString*) dir {
	[self setPreferredSaveDirectoryURL: [NSURL fileURLWithPath: dir]];
}

- (void) setPreferredSaveDirectoryURL: (NSURL *) dir {
	// Default implementation does nothing
}

- (NSImage*) resizeLogo: (NSImage*) input {
	NSSize oldSize = [input size];
	NSImage* result = input;
		
	if (oldSize.width > 256 || oldSize.height > 256) {
		CGFloat scaleFactor;
		
		if (oldSize.width > oldSize.height) {
			scaleFactor = 256/oldSize.width;
		} else {
			scaleFactor = 256/oldSize.height;
		}
		
		NSSize newSize = NSMakeSize(scaleFactor * oldSize.width, scaleFactor * oldSize.height);
		
		result = [[NSImage alloc] initWithSize: newSize];
		[result lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		
		[input drawInRect: NSMakeRect(0,0, newSize.width, newSize.height)
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
		[result unlockFocus];
	}
	
	return result;
}

@end
