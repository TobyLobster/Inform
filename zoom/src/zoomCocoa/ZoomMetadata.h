//
//  ZoomMetadata.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZoomStory.h"
#import "ZoomStoryID.h"

// Notifications
extern NSString* ZoomMetadataWillDestroyStory;			// A story with a particular ID will be destroyed

// Cocoa interface to the C ifmetadata class

@interface ZoomMetadata : NSObject {
	NSString* filename;
	struct IFMetabase* metadata;
	
	NSLock* dataLock;
}

// Initialisation
- (id) init;											// Blank metadata
- (id) initWithContentsOfFile: (NSString*) filename;	// Calls initWithData
- (id) initWithData: (NSData*) xmlData;					// Designated initialiser

// Thread safety [called by ZoomStory]
- (void) lock;
- (void) unlock;
	
// Information about the parse
- (NSArray*) errors;

// Retrieving information
- (BOOL) containsStoryWithIdent: (ZoomStoryID*) ident;
- (ZoomStory*) findOrCreateStory: (ZoomStoryID*) ident;
- (NSArray*)   stories;

// Storing information
- (void) copyStory: (ZoomStory*) story;
- (void) copyStory: (ZoomStory*) story
			  toId: (ZoomStoryID*) copyID;
- (void) removeStoryWithIdent: (ZoomStoryID*) ident;

// Saving the file
- (NSData*) xmlData;
- (BOOL)    writeToFile: (NSString*)path
			 atomically: (BOOL)flag;
- (BOOL) writeToDefaultFile;

@end
