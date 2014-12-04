//
//  ZoomStory.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZoomMetadata;

// Notifications
extern NSString* ZoomStoryDataHasChangedNotification;

enum IFMB_Zarfian {
	IFMD_Unrated = 0x0,
	IFMD_Merciful,
	IFMD_Polite,
	IFMD_Tough,
	IFMD_Nasty,
	IFMD_Cruel
};

@class ZoomStoryID;
@interface ZoomStory : NSObject {
	struct IFStory* story;
	BOOL   needsFreeing;
	
	ZoomMetadata* metadata;
	
	NSMutableDictionary* extraMetadata;
}

// Information
+ (NSString*) nameForKey: (NSString*) key;
+ (NSString*) keyForTag: (int) tag;

// Initialisation
+ (ZoomStory*) defaultMetadataForFile: (NSString*) filename;

- (id) initWithStory: (struct IFStory*) story
			metadata: (ZoomMetadata*) metadataContainer;

- (struct IFStory*) story;
- (void) addID: (ZoomStoryID*) newID;

// Searching
- (BOOL) containsText: (NSString*) text;

// Accessors
- (NSString*) title;
- (NSString*) headline;
- (NSString*) author;
- (NSString*) genre;
- (int)       year;
- (NSString*) group;
- (unsigned)  zarfian;
- (NSString*) teaser;
- (NSString*) comment;
- (float)     rating;

- (int)		  coverPicture;
- (NSString*) description;

- (id) objectForKey: (id) key; // Always returns an NSString (other objects are possible for other metadata)

// Setting data
- (void) setTitle:		  (NSString*) newTitle;
- (void) setHeadline:	  (NSString*) newHeadline;
- (void) setAuthor:		  (NSString*) newAuthor;
- (void) setGenre:		  (NSString*) genre;
- (void) setYear:		  (int) year;
- (void) setGroup:		  (NSString*) group;
- (void) setZarfian:	  (unsigned) zarfian;
- (void) setTeaser:		  (NSString*) teaser;
- (void) setComment:	  (NSString*) comment;
- (void) setRating:		  (float) rating;

- (void) setCoverPicture: (int) picture;
- (void) setDescription:  (NSString*) description;

- (void) setObject: (id) value
			forKey: (id) key;

// Identifying and comparing stories
- (ZoomStoryID*) storyID;								// Compound ID
- (NSArray*) storyIDs;									// Array of ZoomStoryIDs
- (BOOL)     hasID: (ZoomStoryID*) storyID;				// Story answers to this ID
- (BOOL)     isEquivalentToStory: (ZoomStory*) story;   // Stories share an ID

// Sending notifications
- (void) heyLookThingsHaveChangedOohShiney; // Sends ZoomStoryDataHasChangedNotification

- (id) init;								// New story (DEPRECATED)

@end

#import "ZoomMetadata.h"
