//
//  ZoomPlugIn.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

///
/// Base class for deriving Zoom plugins for playing new game types.
///
/// Note that plugins can be initialised in two circumstances: when retrieving game metadata, or when actually playing
/// the game. Game metadata might be requested from a seperate thread, notably when Zoom refreshes the
/// iFiction window on startup.
///
@interface ZoomPlugIn : NSObject {
@private
	NSString* gameFile;											// The game that this plugin will play
	NSData* gameData;											// The game data (loaded on demand)
}

// Informational functions (subclasses should normally override)
+ (NSString*) pluginVersion;									// The version of this plugin
+ (NSString*) pluginDescription;								// The description of this plugin
+ (NSString*) pluginAuthor;										// The author of this plugin

+ (BOOL) canLoadSavegames;										// YES if this plugin can load savegames as well as game files

+ (BOOL) canRunPath: (NSString*) path;							// YES if the specified file is one that the plugin can run

// Designated initialiser
- (id) initWithFilename: (NSString*) gameFile;					// Initialises this plugin to play a specific game

// Getting information about what this plugin should be doing
- (NSString*) gameFilename;										// Gets the game associated with this plugin
- (NSData*) gameData;											// Gets the data for the game associated with this plugin

// The game document + windows
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story;	// Retrieves/creates the document associated with this game (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story	// Retrieves/creates the document associated with this game along with the specified save game file (should not create window controllers immediately)
								saveGame: (NSString*) saveGame;

// Dealing with game metadata
- (ZoomStoryID*) idForStory;									// Retrieves the unique ID for this story (UUIDs are preferred, or MD5s if the game format does not support that)
- (ZoomStory*) defaultMetadata;									// Retrieves the default metadata for this story (used iff no metadata pre-exists for this story)
- (NSImage*) coverImage;										// Retrieves the picture to use for the cover image

- (NSImage*) resizeLogo: (NSImage*) input;						// Resizes a cover image so that it's suitable for use as a window logo

// More information from the main Zoom application
- (void) setPreferredSaveDirectory: (NSString*) dir;			// Sets the preferred directory to put savegames into

@end
