//
//  ZoomStoryOrganiser.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomStory.h"
#import "ZoomStoryID.h"
#import "ZoomBlorbFile.h"


@protocol ZoomStoryIDFetcherProtocol

- (out bycopy ZoomStoryID*) idForFile: (in bycopy NSString*) filename;
- (void) renamedIdent: (in bycopy ZoomStoryID*) ident
		   toFilename: (in bycopy NSString*) filename;

@end

// The story organiser is used to store story locations and identifications
// (Mainly to build up the iFiction window)

// Notifications
extern NSString* ZoomStoryOrganiserChangedNotification;
extern NSString* ZoomStoryOrganiserProgressNotification;

@interface ZoomStoryOrganiser : NSObject<ZoomStoryIDFetcherProtocol> {
	// Arrays of the stories and their idents
	NSMutableArray* storyFilenames;
	NSMutableArray* storyIdents;
	
	// Dictionaries associating them
	NSMutableDictionary* filenamesToIdents;
	NSMutableDictionary* identsToFilenames;
	
	// Preference loading/checking thread
	NSPort* port1;
	NSPort* port2;
	NSConnection* mainThread;
	NSConnection* subThread;
	
	NSLock* storyLock;
	
	// Story organising thread
	BOOL alreadyOrganising;
}

// The shared organiser
+ (ZoomStoryOrganiser*) sharedStoryOrganiser;

// Image management
+ (NSImage*) frontispieceForBlorb: (ZoomBlorbFile*) decodedFile;
+ (NSImage*) frontispieceForFile: (NSString*) filename;

// Storing stories
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident;
- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise;

- (void) removeStoryWithIdent: (ZoomStoryID*) ident
		   deleteFromMetadata: (BOOL) delete;

// Sending notifications
- (void) organiserChanged;

// Retrieving story information
- (NSString*) filenameForIdent: (ZoomStoryID*) ident;
- (ZoomStoryID*) identForFilename: (NSString*) filename;

- (NSArray*) storyFilenames;
- (NSArray*) storyIdents;

// Story-specific data
- (NSString*) directoryForIdent: (ZoomStoryID*) ident
						 create: (BOOL) create;

// Progress
- (void) startedActing;
- (void) endedActing;

// Organising stories
- (void)      organiseStory: (ZoomStory*) story;
- (void)      organiseStory: (ZoomStory*) story
				  withIdent: (ZoomStoryID*) ident;
- (void)      organiseAllStories;
- (void)      reorganiseStoriesTo: (NSString*) newStoryDirectory;

@end
