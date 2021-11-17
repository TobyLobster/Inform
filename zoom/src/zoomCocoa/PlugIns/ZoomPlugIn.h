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

NS_ASSUME_NONNULL_BEGIN

///
/// Base class for deriving Zoom plugins for playing new game types.
///
/// Note that plugins can be initialised in two circumstances: when retrieving game metadata, or when actually playing
/// the game. Game metadata might be requested from a seperate thread, notably when Zoom refreshes the
/// iFiction window on startup.
///
@interface ZoomPlugIn : NSObject

// Informational functions (subclasses should normally override)
//! The version of this plugin
@property (class, readonly, copy) NSString *pluginVersion;
//! The description of this plugin
@property (class, readonly, copy) NSString *pluginDescription;
//! The author of this plugin
@property (class, readonly, copy) NSString *pluginAuthor;

/// \c YES if this plugin can load savegames as well as game files
@property (class, readonly) BOOL canLoadSavegames;

/// \c YES if the specified file is one that the plugin can run
+ (BOOL) canRunPath: (NSString*) path DEPRECATED_MSG_ATTRIBUTE("Use +canRunURL: instead");

/// \c YES if the specified file URL is one that the plugin can run
+ (BOOL) canRunURL: (NSURL*) path;

@property (class, readonly, copy) NSArray<NSString*> *supportedFileTypes;

//! Initialises this plugin to play a specific game
- (nullable id) initWithFilename: (NSString*) gameFile DEPRECATED_MSG_ATTRIBUTE("Use -initWithURL: instead");

// Designated initialiser
//! Initialises this plugin to play a specific game
- (nullable id) initWithURL: (NSURL*) gameFile NS_DESIGNATED_INITIALIZER;

// Getting information about what this plugin should be doing
//! Gets the game associated with this plugin
@property (readonly, copy) NSString *gameFilename DEPRECATED_MSG_ATTRIBUTE("Use -gameURL instead");
//! Gets the game associated with this plugin
@property (readonly, copy) NSURL *gameURL;
//! Gets the data for the game associated with this plugin
@property (readonly, copy, nullable) NSData *gameData;

// The game document + windows
//! Retrieves/creates the document associated with this game (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story;
//! Retrieves/creates the document associated with this game along with the specified save game file (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
								saveGame: (NSString*) saveGame DEPRECATED_MSG_ATTRIBUTE("Use -gameDocumentWithMetadata:saveGameURL: instead");

//! Retrieves/creates the document associated with this game along with the specified save game file (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
							 saveGameURL: (NSURL*) saveGame;

// Dealing with game metadata
//! Retrieves the unique ID for this story (UUIDs are preferred, or MD5s if the game format does not support that)
- (nullable ZoomStoryID*) idForStory;
//! Retrieves the default metadata for this story (used iff no metadata pre-exists for this story)
- (nullable ZoomStory*) defaultMetadata DEPRECATED_MSG_ATTRIBUTE("Use -defaultMetadataWithError: instead") NS_SWIFT_UNAVAILABLE("");
//! Retrieves the default metadata for this story (used iff no metadata pre-exists for this story)
- (nullable ZoomStory*) defaultMetadataWithError:(NSError**)outError;
//! Retrieves the picture to use for the cover image
@property (readonly, nonatomic, copy, nullable) NSImage *coverImage;

//! Resizes a cover image so that it's suitable for use as a window logo
- (NSImage*) resizeLogo: (NSImage*) input;

// More information from the main Zoom application
//! Sets the preferred directory to put savegames into
- (void) setPreferredSaveDirectoryURL: (NSURL*) dir;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
