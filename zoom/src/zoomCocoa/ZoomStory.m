//
//  ZoomStory.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStory.h"
#import "ZoomStoryID.h"

#import "ZoomMetadata.h"
#import "ZoomBlorbFile.h"
#import "ZoomPreferences.h"
#import <ZoomView/ZoomView-Swift.h>

#import "ZoomAppDelegate.h"

#include "ifmetabase.h"

NSString* const ZoomStoryDataHasChangedNotification = @"ZoomStoryDataHasChangedNotification";
static NSString* const ZoomStoryExtraMetadata = @"ZoomStoryExtraMetadata";

static NSString* const ZoomStoryExtraMetadataChangedNotification = @"ZoomStoryExtraMetadataChangedNotification";

#ifndef __MAC_11_0
#define __MAC_11_0          110000
#endif

static inline BOOL urlIsAvailable(NSURL *url, BOOL *isDirectory) {
	if (![url checkResourceIsReachableAndReturnError: NULL]) {
		return NO;
	}
	if (isDirectory) {
		NSNumber *dirNum;
		[url getResourceValue: &dirNum forKey: NSURLIsDirectoryKey error: NULL];
		*isDirectory = dirNum.boolValue;
	}
	
	return YES;
}


@interface ZoomStory ()
- (NSString*) newKeyForOld: (NSString*) key NS_RETURNS_NOT_RETAINED;

@end

@implementation ZoomStory

+ (void) initialize {
	NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
	
	[defs registerDefaults: @{ZoomStoryExtraMetadata: @{}}];
}

+ (NSString*) nameForKey: (NSString*) key {
	// FIXME: internationalisation (this FIXME applies to most of Zoom, which is why it hasn't happened yet)
#define DICT @{@"title": @"Title", \
@"headline": @"Headline", \
@"author": @"Author", \
@"genre": @"Genre", \
@"group": @"Group", \
@"year": @"Year", \
@"zarfian": @"Zarfian rating", \
@"teaser": @"Teaser", \
@"comment": @"Comments", \
@"rating": @"My Rating", \
@"description": @"Description", \
@"coverpicture": @"Cover picture number"}
	
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_11_0
	static NSDictionary* keyNameDict = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		keyNameDict = DICT;
	});
#else
	static NSDictionary* const keyNameDict = DICT;
#endif
#undef DICT
	
	return [keyNameDict objectForKey: key];
}

+ (NSString*) keyForTag: (NSInteger) tag {
	switch (tag) {
		case 0: return @"title";
		case 1: return @"headline";
		case 2: return @"author";
		case 3: return @"genre";
		case 4: return @"group";
		case 5: return @"year";
		case 6: return @"zarfian";
		case 7: return @"teaser";
		case 8: return @"comment";
		case 9: return @"rating";
		case 10: return @"description";
		case 11: return @"coverpicture";
	}
	
	return nil;
}

+ (ZoomStory*) defaultMetadataForURL: (NSURL*) filename
							   error: (NSError**) outError {
	// Gets the standard metadata for the given file
	BOOL isDir;

	if (!urlIsAvailable(filename, &isDir)) {
		if (outError) {
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileReadNoSuchFileError
										userInfo: @{NSURLErrorKey: filename}];
		}
		return nil;
	}
	
	if (isDir) {
		if (outError) {
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileReadUnknownError
										userInfo: @{NSURLErrorKey: filename}];
		}
		return nil;
	}
	
	// Get the ID for this file
	// NSData* fileData = [NSData dataWithContentsOfFile: filename];
	ZoomStoryID* fileID = [ZoomStoryID idForURL: filename];
	ZoomMetadata* fileMetadata = nil;
	
	if (fileID == nil) {
		fileID = [[ZoomStoryID alloc] initWithData: [NSData dataWithContentsOfURL: filename]];
	}
	
	// If this file is a blorb file, then extract the IFmd chunk
	NSFileHandle* fh = [NSFileHandle fileHandleForReadingFromURL: filename
														   error: outError];
	if (!fh) {
		return nil;
	}
	NSData* data = [fh readDataOfLength: 64];
	const unsigned char* bytes = [data bytes];
	[fh closeFile];
	
	ZoomBlorbFile* blorb = nil;
	if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
		blorb = [[ZoomBlorbFile alloc] initWithContentsOfURL: filename
													   error: outError];
		NSData* ifMD = [blorb dataForChunkWithType: @"IFmd"];
		
		if (ifMD != nil) {
			fileMetadata = [[ZoomMetadata alloc] initWithData: ifMD error: NULL];
		} else {
			NSLog(@"Warning: found a game with an IFmd chunk, but was not able to parse it");
		}
	}
	
	// If we've got an ifMD chunk, then see if we can extract the story from it
	ZoomStory* result = nil;
	
	if (fileMetadata && [fileMetadata containsStoryWithIdent: fileID]) {
		result = [fileMetadata findOrCreateStory: fileID];
		
		if (result == nil) {
			NSLog(@"Warning: found a game with an IFmd chunk, but which did not appear to contain any relevant metadata (looked for ID: %@)", fileID);
		}
	}
	
	// If there's no result, then make up the data from the filename
	if (result == nil) {
		result = [[(ZoomAppDelegate*)[NSApp delegate] userMetadata] findOrCreateStory: fileID];
		
		// Add the ID
		[result addID: fileID];
		
		// Behaviour is different for stories that are organised
		NSString* orgDir = [[[ZoomPreferences globalPreferences] organiserDirectory] stringByStandardizingPath];
		BOOL storyIsOrganised = NO;
		
		NSURL* mightBeOrgURL = [[[filename URLByDeletingLastPathComponent] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
		NSString *mightBeOrgDir = [mightBeOrgURL.path stringByStandardizingPath];
		
		if ([orgDir caseInsensitiveCompare: mightBeOrgDir] == NSOrderedSame) storyIsOrganised = YES;
		if (![[[[filename lastPathComponent] stringByDeletingPathExtension] lowercaseString] isEqualToString: @"game"]) storyIsOrganised = NO;
		
		// Build the metadata
		NSString* groupName;
		NSString* gameName;
		
		if (storyIsOrganised) {
			gameName = [[filename URLByDeletingLastPathComponent] lastPathComponent];
			groupName = [[[filename URLByDeletingLastPathComponent] URLByDeletingLastPathComponent] lastPathComponent];
		} else {
			gameName = [[filename URLByDeletingPathExtension] lastPathComponent];
			groupName = @"";
		}
		
		[result setTitle: gameName];
		[result setGroup: groupName];
	}
	
	if (result != nil && ([result group] == nil || [[result group] isEqualToString: @""])) {
		// Use a default group based on the type of game this is
		BOOL isUlx = NO;
		
		if (blorb) {
			isUlx = [blorb dataForChunkWithType: @"GLUL"] != nil;
		} else {
			isUlx = bytes[0] == 'G' && bytes[1] == 'l' && bytes[2] == 'u' && bytes[3] == 'l';
		}
		
		if (isUlx) {
			[result setGroup: @"Glulx"];
		} else {
			[result setGroup: @"Z-Code"];
		}
	}
	
	// Return the result
	return result;
}

+ (ZoomStory*) defaultMetadataForFile: (NSString*) filename {
	return [self defaultMetadataForURL: [NSURL fileURLWithPath: filename]
								 error: NULL];
}

#pragma mark - Initialisation

- (id) init {
	[NSException raise: @"ZoomCannotInitialiseStoryException"
				format: @"Cannot initialise a ZoomStory object without a corresponding metabase"];
	return nil;
}

- (id) initWithStory: (IFStory) s
			metadata: (ZoomMetadata*) metadataContainer {
	self = [super init];
	
	if (self) {
		story = s;
		needsFreeing = NO;
		metadata = metadataContainer;
		
		extraMetadata = nil;
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(storyDying:)
													 name: ZoomMetadataWillDestroyStory
												   object: metadataContainer];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Notifications

- (void) storyDying: (NSNotification*) not {
	// If this story is removed from the metabase, then invalidate this object
	//
	// Ideally, all story objects should be destroyed before they get removed from the metabase, but 
	// it's going to be far too hard to keep track of them all, so this will do as an alternative.
	//
	// An improvement that might be made: stories could be put into a temporary metabase here so that
	// they continue to be completely valid (and recoverable if necessary). However, this is not yet
	// a required feature.
	//
	
	ZoomStoryID* ident = [[not userInfo] objectForKey: @"Ident"];
	
	if ([self hasID: ident]) {
		story = NULL;
	}
}

#pragma mark - Accessors

@synthesize story;

- (void) addID: (ZoomStoryID*) newID {
	if (story == NULL) return;
	
	IFID oldId = IFMB_IdForStory(story);
	
	if (IFMB_CompareIds(oldId, [newID ident]) != 0) {
		IFID newIdArray[2] = { oldId, [newID ident] };
		IFID newStoryId = IFMB_CompoundId(2, newIdArray);
		
		IFMB_CopyStory(NULL, story, newStoryId);
		IFMB_FreeId(newStoryId);
	}
}

- (NSString*) title {
	return [self objectForKey: @"title"];
}

- (NSString*) headline {
	return [self objectForKey: @"headline"];
}

- (NSString*) author {
	return [self objectForKey: @"author"];
}

- (NSString*) genre {
	return [self objectForKey: @"genre"];
}

- (int) year {
	NSString* stringYear = [self objectForKey: @"year"];
	
	if (stringYear)
		return [stringYear intValue];
	else
		return 0;
}

- (NSString*) group {
	return [self objectForKey: @"group"];
}

- (IFMB_Zarfian) zarfian {
	NSString* zarfian = [[self objectForKey: @"zarfian"] lowercaseString];
	
	if ([zarfian isEqualToString: @"merciful"]) {
		return IFMD_Merciful;
	} else if ([zarfian isEqualToString: @"polite"]) {
		return IFMD_Polite;
	} else if ([zarfian isEqualToString: @"tough"]) {
		return IFMD_Tough;
	} else if ([zarfian isEqualToString: @"nasty"]) {
		return IFMD_Nasty;
	} else if ([zarfian isEqualToString: @"cruel"]) {
		return IFMD_Cruel;
	}

	return IFMD_Unrated;
}

- (NSString*) teaser {
	return [self objectForKey: @"teaser"];
}

- (NSString*) comment {
	return [self objectForKey: @"comment"];
}

- (float)     rating {
	NSString* rating = [self objectForKey: @"rating"];
	
	if (rating) {
		return [rating floatValue];
	} else {
		return -1;
	}
}

- (int) coverPicture {
	NSString* coverPicture = [self objectForKey: @"coverpicture"];
	
	if (coverPicture) {
		return [coverPicture intValue];
	} else {
		return -1;
	}
}

- (NSString*) description {
	return [self objectForKey: @"description"];
}

#pragma mark - Setting data

// Setting data
- (void) setTitle: (NSString*) newTitle {
	[self setObject: newTitle
			 forKey: @"title"];
}

- (void) setHeadline: (NSString*) newHeadline {
	[self setObject: newHeadline
			 forKey: @"headline"];
}

- (void) setAuthor: (NSString*) newAuthor {
	[self setObject: newAuthor
			 forKey: @"author"];
}

- (void) setGenre: (NSString*) genre {
	[self setObject: genre
			 forKey: @"genre"];
}

- (void) setYear: (int) year {
	if (year > 0) {
		[self setObject: [NSString stringWithFormat: @"%i", year]
				 forKey: @"year"];
	} else {
		[self setObject: nil
				 forKey: @"year"];
	}
}

- (void) setGroup: (NSString*) group {
	[self setObject: group
			 forKey: @"group"];
}

- (void) setZarfian: (IFMB_Zarfian) zarfian {
	NSString* narf = nil; /* Are you pondering what I'm pondering? */
	
	switch (zarfian) {
		case IFMD_Merciful: narf = @"Merciful"; break;
		case IFMD_Polite: narf = @"Polite"; break;
		case IFMD_Tough: narf = @"Tough"; break;
		case IFMD_Nasty: narf = @"Nasty"; break;
		case IFMD_Cruel: narf = @"Cruel"; break;
		default: break;
	}
	
	[self setObject: narf
			 forKey: @"zarfian"];
}

- (void) setTeaser: (NSString*) teaser {
	[self setObject: teaser
			 forKey: @"teaser"];
}

- (void) setComment: (NSString*) comment {
	[self setObject: comment
			 forKey: @"comment"];
}

- (void) setRating: (float) rating {
	if (rating >= 0) {
		[self setObject: [NSString stringWithFormat: @"%g", rating]
				 forKey: @"rating"];
	} else {
		[self setObject: nil
				 forKey: @"rating"];
	}
}

- (void) setCoverPicture: (int) coverpicture {
	if (coverpicture >= 0) {
		[self setObject: [NSString stringWithFormat: @"%i", coverpicture]
				 forKey: @"coverpicture"];
	} else {
		[self setObject: nil
				 forKey: @"coverpicture"];
	}
}

- (void) setDescription: (NSString*) description {
	[self setObject: description
			 forKey: @"description"];
}

#pragma mark - NSCopying

/*
- (id) copyWithZone: (NSZone*) zone {
	IFMDStory* newStory = IFStory_Alloc();
	IFStory_Copy(newStory, story);
	
	ZoomStory* res;
	
	res = [[ZoomStory alloc] initWithStory: newStory];
	res->needsFreeing = YES;
	
	return res;
}
*/

#pragma mark - Story pseudo-dictionary methods

- (void) loadExtraMetadata {
	if (extraMetadata != nil) return;
	
	NSDictionary* dict = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomStoryExtraMetadata];
	
	// We retrieve the data for the first story ID only. Assuming nothing funny has happened, it
	// will be the same for all IDs associated with this story.
	if (dict == nil || ![dict isKindOfClass: [NSDictionary class]]) {
		extraMetadata = [[NSMutableDictionary alloc] init];
	} else {
		extraMetadata = [[dict objectForKey: [[[self storyIDs] objectAtIndex: 0] description]] mutableCopy];
	}
	
	if (extraMetadata == nil) {
		extraMetadata = [[NSMutableDictionary alloc] init];
	}
}

- (void) storeExtraMetadata {
	// Make a mutable copy of the metadata dictionary
	NSMutableDictionary* newExtraData = [[[NSUserDefaults standardUserDefaults] objectForKey: ZoomStoryExtraMetadata] mutableCopy];
	
	if (newExtraData == nil || ![newExtraData isKindOfClass: [NSMutableDictionary class]]) {
		newExtraData = [[NSMutableDictionary alloc] init];
	}
	
	// Add the data for all our story IDs
	for (ZoomStoryID* storyID in [self storyIDs]) {
		[newExtraData setObject: extraMetadata
						 forKey: [storyID description]];
	}
	
	// Store in the defaults
	[[NSUserDefaults standardUserDefaults] setObject: newExtraData
											  forKey: ZoomStoryExtraMetadata];
	
	// Notify the other stories about the change
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryExtraMetadataChangedNotification
														object: self];
}

- (void) extraDataChanged: (NSNotification*) not {
	// Respond to notifications about changing metadata
	if (extraMetadata) {
		extraMetadata = nil;
		
		// (Reloading prevents a potential bug in the future. It's not absolutely required right now)
		[self loadExtraMetadata];
	}
}

- (NSString*) newKeyForOld: (NSString*) key {
#define DICT @{@"title": @"bibliographic.title", \
@"headline": @"bibliographic.headline", \
@"author": @"bibliographic.author", \
@"genre": @"bibliographic.genre", \
@"group": @"bibliographic.group", \
@"year": @"bibliographic.firstpublished", \
@"zarfian": @"bibliographic.forgiveness", \
@"teaser": @"zoom.teaser", \
@"comment": @"zoom.comment", \
@"rating": @"zoom.rating", \
@"description": @"bibliographic.description", \
@"coverpicture": @"zcode.coverpicture"}
	
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_11_0
	static NSDictionary* newForOldDict = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		newForOldDict = DICT;
	});
#else
	static NSDictionary* const newForOldDict = DICT;
#endif
#undef DICT
	NSString *result = newForOldDict[key];
	if (result) {
		return result;
	}

	if ([key containsString: @"."]) {
		return key;
	}
	
	return [NSString stringWithFormat: @"zoom.extra.%@", key];
}

- (id) objectForKey: (NSString*) key {
	if (story == NULL) return nil;

	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" 
					format: @"Metadata key is not a string"];
		return nil;
	}
	
	[metadata lock];
	
	id newKey = [self newKeyForOld: key];
	IFChar* value = IFMB_GetValue(story, [newKey UTF8String]);
	
	if (value != nil) {
		int len = IFMB_StrLen(value);
		NSString* result = [[NSString alloc] initWithBytes:value length:len*2 encoding:NSUTF16LittleEndianStringEncoding];
		if (result) {
			[metadata unlock];
			return result;
		}
		unichar* characters = malloc(sizeof(unichar)*len);
		int x;
		
		for (x=0; x<len; x++) characters[x] = value[x];
		
		result = [[NSString alloc] initWithCharactersNoCopy: characters
													 length: len
											   freeWhenDone: YES];
		
		[metadata unlock];
		return result;
	} else {
		[metadata unlock];
		[self loadExtraMetadata];
		return [extraMetadata objectForKey: key];
	}
}

- (void) setObject: (id) value
			forKey: (NSString*) key {
	if (story == NULL) return;

	if ([key isEqualToString: @"rating"] && [value isKindOfClass: [NSNumber class]]) {
		[self setRating: [value floatValue]];
		return;
	}
	
	if (![value isKindOfClass: [NSString class]] && value != nil) {
		[NSException raise: @"ZoomBadValue" format: @"Metadata value is not a string"];
		return;
	}
	if (![key isKindOfClass: [NSString class]]) {
		[NSException raise: @"ZoomKeyNotString" format: @"Metadata key is not a string"];
		return;
	}
	
	if ([[self objectForKey: key] isEqualTo: value] && [self objectForKey: key] != value) {
		// Nothing to do
		return;
	}
	
	[metadata lock];
	
	IFChar* metaValue = nil;
	
	if (value != nil) {
		metaValue = malloc(sizeof(IFChar)*([value length]+1));
		
		unichar* characters = malloc(sizeof(unichar)*[value length]);
		NSInteger x;
		
		[value getCharacters: characters];
		
		for (x=0; x<[value length]; x++) {
			metaValue[x] = characters[x];
		}
		metaValue[x] = 0;
		
		free(characters);
	}
	
	IFMB_SetValue(story, [[self newKeyForOld: key] UTF8String], metaValue);
	if (metaValue) free(metaValue);
	
	[metadata unlock];
	
	[self heyLookThingsHaveChangedOohShiney];
}

#pragma mark - Searching

- (BOOL) containsText: (NSString*) text {
	if (story == NULL) return NO;

	// List of strings to check against
	NSArray* stringsToCheck = [[NSArray alloc] initWithObjects: 
		[self title], [self headline], [self author], [self genre], [self group], nil];
	
	// List of words to match against (we take off a word for each match)
	NSMutableArray<NSString*>* words = [[text componentsSeparatedByString: @" "] mutableCopy];
	
	// Loop through each string to check against
	NSEnumerator* searchEnum = [stringsToCheck objectEnumerator];
	NSString* string;
	
	while ([words count] > 0 && (string = [searchEnum nextObject])) {
		NSInteger num;
		
		for (num=0; num<[words count]; num++) {
			if ([[words objectAtIndex: num] length] == 0 ||
				[string rangeOfString: [words objectAtIndex: num]
							  options: NSCaseInsensitiveSearch].location != NSNotFound) {
				// Found this word
				[words removeObjectAtIndex: num];
				num--;
				continue;
			}
		}
	}

	// Finish up
	BOOL success = [words count] <= 0;
	
	// Is true if there are no words left to match
	return success;
}

#pragma mark - Sending notifications

- (void) heyLookThingsHaveChangedOohShiney {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryDataHasChangedNotification
														object: self];
}

// Identifying and comparing stories

- (ZoomStoryID*) storyID {
	if (story == NULL) return nil;
	return [[ZoomStoryID alloc] initWithIdent: IFMB_IdForStory(story)];
}

- (NSArray*) storyIDs {
	if (story == NULL) return nil;

	NSMutableArray* idArray = [NSMutableArray array];
	
	[metadata lock];
	
	int ident;
	int count;
	
	IFID singleId[1] = { IFMB_IdForStory(story) };
	IFID* ids = IFMB_SplitId(singleId[0], &count);
	
	if (ids == NULL) {
		ids = singleId;
		count = 1;
	}
	
	for (ident = 0; ident < count; ident++) {
		ZoomStoryID* theId = [[ZoomStoryID alloc] initWithIdent: ids[ident]];
		if (theId) {
			[idArray addObject: theId];
		}
	}
	
	[metadata unlock];
	
	return [idArray copy];
}

- (BOOL) hasID: (ZoomStoryID*) storyID {
	if (story == NULL) return NO;

	NSArray* ourIds = [self storyIDs];
	
	return [ourIds containsObject: storyID];
}

- (BOOL) isEquivalentToStory: (ZoomStory*) eqStory {
	if (story == NULL) return NO;

	if (eqStory == self) return YES; // Shortcut
	
	NSArray* theirIds = [eqStory storyIDs];
	NSArray* ourIds = [self storyIDs];
	
	[metadata lock];
	
	for (ZoomStoryID* thisId in theirIds) {
		if ([ourIds containsObject: thisId]) {
			[metadata unlock];
			return YES;
		}
	}
	
	[metadata unlock];
	
	return NO;
}

@end
