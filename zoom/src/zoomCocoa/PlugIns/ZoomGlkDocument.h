//
//  ZoomGlkDocument.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>

@class ZoomPlugIn;

NS_ASSUME_NONNULL_BEGIN

///
/// Document representing a Glk game
///
@interface ZoomGlkDocument : NSDocument {
	/// The Glk executable we'll run to play this game
	NSString* clientPath;
	/// The file we'll pass to the executable as the game to run
	NSURL* inputURL;
	/// The file that we'll pass as a savegame
	NSURL* savedGamePath;
	
	/// Metadata for this story
	ZoomStory* storyData;
	ZoomPlugIn* plugIn;
	/// The logo for this story
	NSImage* logo;
	/// Preferred save directory
	NSURL* preferredSaveDir;
}

// Configuring the client
//! The metadata associated with this story
@property (strong) ZoomStory *storyData;
//! Selects which GlkClient executable to run
@property (copy) NSString *clientPath;
//! The file that should be passed to the client as the file to run
- (void) setInputFilename: (NSString*) inputPath DEPRECATED_MSG_ATTRIBUTE("Use -setInputURL: instead");
//! The file that should be passed to the client as the file to run
- (void) setInputURL: (NSURL*) inputPath;
//! The logo to display for this story
@property (strong) NSImage *logo;
//! The plugin that created this document
@property (strong) ZoomPlugIn *plugIn;
//! A .glksave file that the game should load on first start up
@property (copy, nullable) NSURL *saveGameURL;

//! The preferred directory to put savegames into
@property (copy) NSURL *preferredSaveDirectory;

@end

NS_ASSUME_NONNULL_END
