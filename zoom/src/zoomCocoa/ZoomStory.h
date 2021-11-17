//
//  ZoomStory.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ZoomPlugins/ifmetabase.h>

NS_ASSUME_NONNULL_BEGIN

@class ZoomMetadata;

// Notifications
extern NSNotificationName const ZoomStoryDataHasChangedNotification;

typedef NS_ENUM(unsigned, IFMB_Zarfian) {
	IFMD_Unrated NS_SWIFT_NAME(unrated) = 0x0,
	IFMD_Merciful NS_SWIFT_NAME(merciful),
	IFMD_Polite NS_SWIFT_NAME(polite),
	IFMD_Tough NS_SWIFT_NAME(tough),
	IFMD_Nasty NS_SWIFT_NAME(nasty),
	IFMD_Cruel NS_SWIFT_NAME(cruel)
};

@class ZoomStoryID;
@interface ZoomStory : NSObject {
	IFStory story;
	BOOL   needsFreeing;
	
	ZoomMetadata* metadata;
	
	NSMutableDictionary* extraMetadata;
}

// Information
+ (nullable NSString*) nameForKey: (NSString*) key;
+ (nullable NSString*) keyForTag: (NSInteger) tag;

// Initialisation
+ (nullable ZoomStory*) defaultMetadataForFile: (NSString*) filename DEPRECATED_MSG_ATTRIBUTE("Use +defaultMetadataForURL:error: instead");
+ (nullable ZoomStory*) defaultMetadataForURL: (NSURL*) filename
										error: (NSError**) outError;

- (instancetype) initWithStory: (IFStory) story
					  metadata: (ZoomMetadata*) metadataContainer;

@property (readonly, nullable) IFStory story NS_RETURNS_INNER_POINTER;
- (void) addID: (ZoomStoryID*) newID;

// Searching
- (BOOL) containsText: (NSString*) text;

// Accessors
@property (copy, nullable) NSString *title;
@property (copy, nullable) NSString *headline;
@property (copy, nullable) NSString *author;
@property (copy, nullable) NSString *genre;
@property int		year;
@property (copy, nullable) NSString *group;
@property IFMB_Zarfian zarfian;
@property (copy, nullable) NSString *teaser;
@property (copy, nullable) NSString *comment;
@property float rating;

@property int coverPicture;
@property (readwrite, copy) NSString *description;

- (nullable id) objectForKey: (NSString*) key; //!< Always returns an NSString (other objects are possible for other metadata)

// Setting data

- (void) setObject: (nullable id) value
			forKey: (NSString*) key;

// Identifying and comparing stories
//! Compound ID
@property (readonly, strong, nullable) ZoomStoryID *storyID;
//! Array of ZoomStoryIDs
@property (nonatomic, readonly, copy, nullable) NSArray<ZoomStoryID*> *storyIDs;
//! Story answers to this ID
- (BOOL)     hasID: (ZoomStoryID*) storyID;
//! Stories share an ID
- (BOOL)     isEquivalentToStory: (ZoomStory*) story;

// Sending notifications
//! Sends \c ZoomStoryDataHasChangedNotification
- (void) heyLookThingsHaveChangedOohShiney;

//! New story (DEPRECATED)
- (id) init UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
