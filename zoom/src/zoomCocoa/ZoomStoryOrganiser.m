//
//  ZoomStoryOrganiser.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>

#import <Cocoa/Cocoa.h>

#import "ZoomStoryOrganiser.h"
#import "ZoomAppDelegate.h"
#import <ZoomView/ZoomPreferences.h>
#import <ZoomView/ZoomView-Swift.h>
#import <ZoomPlugIns/ZoomPlugInManager.h>
#import <ZoomPlugIns/ZoomPlugIn.h>
#import "Zoom-Swift.h"

NSString*const ZoomStoryOrganiserChangedNotification = @"ZoomStoryOrganiserChangedNotification";
NSString*const ZoomStoryOrganiserProgressNotification = @"ZoomStoryOrganiserProgressNotification";

static NSString*const defaultName = @"ZoomStoryOrganiser";
static NSString*const extraDefaultsName = @"ZoomStoryOrganiserExtra";
static NSString*const ZoomGameDirectories = @"ZoomGameDirectories";
static NSString*const ZoomIdentityFilename = @".zoomIdentity";

// TODO: migrate to CoreData
// TODO: migrate to URL bookmarks

@interface ZoomStoryOrganiser ()

- (ZoomStoryID*) idForFile: (NSString*) filename;
- (void) renamedIdent: (ZoomStoryID*) ident toFilename: (NSString*) filename;

@end

@implementation ZoomStoryOrganiser

#pragma mark - Internal functions

- (NSDictionary*) dictionary {
	NSMutableDictionary* defaultDictionary = [NSMutableDictionary dictionary];
	
	NSEnumerator<NSString*>* filenameEnum = [filenamesToIdents keyEnumerator];
	
	for (NSString* filename in filenameEnum) {
		NSData* encodedId = [NSKeyedArchiver archivedDataWithRootObject: [filenamesToIdents objectForKey: filename] requiringSecureCoding: YES error: NULL];
		
		[defaultDictionary setObject: encodedId
							  forKey: filename];
	}
		
	return defaultDictionary;
}

- (NSDictionary*) extraDictionary {
	return [NSDictionary dictionary];
}

- (void) storePreferences {
	[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
											  forKey:defaultName];
	[[NSUserDefaults standardUserDefaults] setObject:[self extraDictionary] 
											  forKey:extraDefaultsName];
}

- (ZoomStoryID*) idForFile: (NSString*) filename {
	ZoomIsSpotlightIndexing = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath: filename]) return nil;
	return [ZoomStoryID idForURL: [NSURL fileURLWithPath: filename]];
}

- (void) preferenceThread: (NSDictionary*) threadDictionary {
	@autoreleasepool {
		NSFileManager *fm = [[NSFileManager alloc] init];
	NSDictionary* prefs = [threadDictionary objectForKey: @"preferences"];
	//NSDictionary* prefs2 = [threadDictionary objectForKey: @"extraPreferences"]; - unused, presently
	
	int counter = 0;
	
	// Notify the main thread that things are happening
		dispatch_async(dispatch_get_main_queue(), ^{
			[self startedActing];
		});
			
	// Preference keys indicate the filenames
	NSEnumerator* filenameEnum = [prefs keyEnumerator];
	
	for (NSString* filename in filenameEnum) @autoreleasepool {
		
		NSData* storyData = [prefs objectForKey: filename];
		ZoomStoryID* fileID = [NSKeyedUnarchiver unarchivedObjectOfClass: [ZoomStoryID class] fromData: storyData error: NULL];
		if (!fileID) {
			fileID = [NSUnarchiver unarchiveObjectWithData: storyData];
		}
		__block ZoomStoryID* realID;
		dispatch_sync(dispatch_get_main_queue(), ^{
			realID = [self idForFile: filename];
		});
		//ZoomStoryID* realID = [ZoomStoryID idForFile: filename];
		//ZoomStoryID* realID = [[ZoomStoryID alloc] initWithZCodeFile: filename];
		
		if (fileID != nil && realID != nil && [fileID isEqual: realID]) {
			// Check for a pre-existing entry
			[storyLock lock];
			
			NSString* oldFilename = [identsToFilenames objectForKey: fileID];
			ZoomStoryID* oldIdent = [filenamesToIdents objectForKey: filename];
			
			if (oldFilename && oldIdent && [oldFilename isEqualToString: filename] && [oldIdent isEqualTo: fileID]) {
				[storyLock unlock];
				continue;
			}
			
			// Remove old entries
			if (oldFilename) {
				NSInteger index = [storyFilenames indexOfObject: oldFilename];
				
				[identsToFilenames removeObjectForKey: fileID];
				
				[storyFilenames removeObjectAtIndex: index];
				[storyIdents removeObjectAtIndex: index];
			}
			
			if (oldIdent) {
				NSInteger index = [storyIdents indexOfObject: oldIdent];

				[filenamesToIdents removeObjectForKey: filename];
				
				[storyFilenames removeObjectAtIndex: index];
				[storyIdents removeObjectAtIndex: index];
			}
			
			// Add this entry
			NSString* newFilename = [filename copy];
			ZoomStoryID* newIdent    = [fileID copy];
			
			[storyFilenames addObject: newFilename];
			[storyIdents addObject: newIdent];
			
			if (newIdent != nil) {
				[identsToFilenames setObject: newFilename forKey: newIdent];
				[filenamesToIdents setObject: newIdent forKey: newFilename];
			}

			[storyLock unlock];
		}
		
		counter++;
		if (counter > 40) {
			counter = 0;
			dispatch_async(dispatch_get_main_queue(), ^{
				[self organiserChanged];
			});
		}
	}	
	
		dispatch_async(dispatch_get_main_queue(), ^{
			[self organiserChanged];
		});
	
	// If story organisation is on, we need to check for any disappeared stories that have appeared in
	// the organiser directory, and recreate any story data as required.
	//
	// REMEMBER: this is not the main thread! Don't make bad things happen!
	if ([[ZoomPreferences globalPreferences] keepGamesOrganised]) {
		// Directory scanning time. NSFileManager is not thread-safe, so we use opendir instead
		// (Yup, pain in the neck)
		// TODO: use thread-local fm instead
		NSString* orgDir = [[ZoomPreferences globalPreferences] organiserDirectory];
		DIR* orgD = opendir([fm fileSystemRepresentationWithPath: orgDir]);
		struct dirent* ent;
		
		while (orgD && (ent = readdir(orgD))) {
			NSString* groupName = [NSString stringWithUTF8String: ent->d_name];
			
			// Don't really want to iterate these
			if ([groupName isEqualToString: @".."] ||
				[groupName isEqualToString: @"."]) {
				continue;
			}
			
			// Must be a directory
			if (ent->d_type != DT_DIR) continue;
			
			// Iterate through the files in this directory
			NSString* newDir = [orgDir stringByAppendingPathComponent: groupName];
			
			DIR* groupD = opendir([fm fileSystemRepresentationWithPath: newDir]);
			struct dirent* gEnt;
			
			while (groupD && (gEnt = readdir(groupD))) {
				NSString* gameName = [NSString stringWithUTF8String: gEnt->d_name];
				
				// Don't really want to iterate these
				if ([gameName isEqualToString: @".."] ||
					[gameName isEqualToString: @"."]) {
					continue;
				}
				
				// Must be a directory
				if (gEnt->d_type != DT_DIR) continue;
				
				// See if there's a story file there
				NSString* gameDir = [newDir stringByAppendingPathComponent: gameName];
				NSString* gameFile = nil;
				__block ZoomStoryID* gameFileID = nil;
				
				// Iterate through the files in this directory
				DIR* gameD = opendir([fm fileSystemRepresentationWithPath: gameDir]);
				struct dirent* gameEnt;
				
				while (gameD && (gameEnt = readdir(gameD))) {
					NSString* gameFileName = [NSString stringWithUTF8String: gameEnt->d_name];
					if ([gameFileName isEqualToString: @".."] ||
						[gameFileName hasPrefix: @"."]) {
						continue;
					}
					
					NSString *tmpFileName = [gameDir stringByAppendingPathComponent: gameFileName];
					dispatch_sync(dispatch_get_main_queue(), ^{
						gameFileID = [self idForFile: tmpFileName];
					});
					if (gameFileID != nil) {
						gameFile = [gameDir stringByAppendingPathComponent: gameFileName];
						break;
					}
				}
				
				if (gameD) closedir(gameD);
				
				struct stat sb;
				if (gameFile == nil || stat([fm fileSystemRepresentationWithPath: gameFile], &sb) != 0) continue;
				
				// See if it's already in our database
				[storyLock lock];
				ZoomStoryID* fileID = [filenamesToIdents objectForKey: gameFile];
				
				if (fileID == nil) {
					// Pass this off to the main thread
					dispatch_async(dispatch_get_main_queue(), ^{
						[self foundFileNotInDatabase:@[groupName, gameName, gameFile]];
					});
				}
				[storyLock unlock];
			}
			
			if (groupD) closedir(groupD);
		}
		
		if (orgD) closedir(orgD);
	}

		dispatch_async(dispatch_get_main_queue(), ^{
			[self organiserChanged];
			
			// Tidy up
			[self endedActing];
		});

	// Done
	CFRelease((__bridge CFTypeRef)(self));
	}
}

- (void) loadPreferences {
	NSDictionary* prefs = [[NSUserDefaults standardUserDefaults] objectForKey: defaultName];
	NSDictionary* extraPrefs = [[NSUserDefaults standardUserDefaults] objectForKey: extraDefaultsName];
	
	// Detach a thread to decode the dictionary
	NSDictionary* threadDictionary = @{
		@"preferences": prefs,
		@"extraPreferences": extraPrefs
	};
	
	// Run the thread
	CFRetain((__bridge CFTypeRef)(self)); // Released by the thread when it finishes
	NSThread *preferenceThread = [[NSThread alloc] initWithTarget: self
														 selector: @selector(preferenceThread:)
														   object: threadDictionary];
	preferenceThread.name = @"Zoom Preference Thread";
	[preferenceThread start];
}

- (void) organiserChanged {
	[self storePreferences];
	
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserChangedNotification
														object: self];
}

- (void) foundFileNotInDatabase: (NSArray*) info {
	ZoomIsSpotlightIndexing = NO;
	// Called from the preferenceThread (on the main thread) when a story not in the database is found
	NSString* groupName = [info objectAtIndex: 0];
	NSString* gameName = [info objectAtIndex: 1];
	NSString* gameFile = [info objectAtIndex: 2];
	
	static BOOL loggedNote = NO;
	if (!loggedNote) {
		loggedNote = YES;
	}
	
	// Check for story metadata first
	ZoomStoryID* newID = [ZoomStoryID idForFile: gameFile];
	
	if (newID == nil) {
		NSLog(@"Found unindexed game at %@, but failed to obtain an ID. Not indexing", gameFile);
		return;
	}
	
	BOOL otherFile;
	
	[storyLock lock];
	if ([identsToFilenames objectForKey: newID] != nil) {
		otherFile = YES;
		
		NSLog(@"Story %@ appears to be a duplicate of %@", gameFile, [identsToFilenames objectForKey: newID]);
	} else {
		otherFile = NO;
		
		NSLog(@"Story %@ not in database (will add)", gameFile);
	}
	[storyLock unlock];
	
	ZoomMetadata* data = [(ZoomAppDelegate*)[NSApp delegate] userMetadata];
	ZoomStory* oldStory = [(ZoomAppDelegate*)[NSApp delegate] findStory: newID];
	
	if (oldStory == nil) {
		NSLog(@"Creating metadata entry for story '%@'", gameName);
		
		ZoomStory* newStory = [ZoomStory defaultMetadataForFile: gameFile];
		
		[data copyStory: newStory];
		[data writeToDefaultFile];
		oldStory = newStory;
	} else {
		NSLog(@"Found metadata for story '%@'", gameName);
	}
	
	// Check for any resources associated with this story
	if ([oldStory objectForKey: @"ResourceFilename"] == nil) {
		NSString* possibleResource = [[gameFile stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"resource.blb"];
		BOOL isDir = NO;
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: possibleResource
														   isDirectory: &isDir];
		
		if (exists && !isDir) {
			NSLog(@"Found resources for game at %@", possibleResource);
			
			[oldStory setObject: possibleResource
						 forKey: @"ResourceFilename"];

			[data copyStory: oldStory];
			[data writeToDefaultFile];
		} else {
			possibleResource = [[[gameFile stringByDeletingLastPathComponent] stringByAppendingPathComponent: gameFile.stringByDeletingPathExtension.lastPathComponent] stringByAppendingPathExtension:@"blb"];
			isDir = NO;
			exists = [[NSFileManager defaultManager] fileExistsAtPath: possibleResource
														  isDirectory: &isDir];
			
			if (exists && !isDir) {
				NSLog(@"Found resources for game at %@", possibleResource);
				
				[oldStory setObject: possibleResource
							 forKey: @"ResourceFilename"];

				[data copyStory: oldStory];
				[data writeToDefaultFile];
			}
		}
	}
	
	// Now store with us
	[self addStory: gameFile
		 withIdent: newID
		  organise: NO];	
}

#pragma mark - Initialisation

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// User defaults
		NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
		ZoomStoryOrganiser* defaultPrefs = [[[self class] alloc] init];
		
		NSDictionary *appDefaults = @{defaultName: [defaultPrefs dictionary]};
		
		[defaults registerDefaults: appDefaults];
	});
}

- (id) init {
	self = [super init];
	
	if (self) {
		storyFilenames = [[NSMutableArray alloc] init];
		storyIdents = [[NSMutableArray alloc] init];
		
		filenamesToIdents = [[NSMutableDictionary alloc] init];
		identsToFilenames = [[NSMutableDictionary alloc] init];
		
		storyLock = [[NSLock alloc] init];
		
		// Any time a story changes, we move it
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(someStoryHasChanged:)
													 name: ZoomStoryDataHasChangedNotification
												   object: nil];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - The shared organiser

static ZoomStoryOrganiser* sharedOrganiser = nil;

+ (ZoomStoryOrganiser*) sharedStoryOrganiser {
	if (!sharedOrganiser) {
		sharedOrganiser = [[ZoomStoryOrganiser alloc] init];
		[sharedOrganiser loadPreferences];
	}
	
	return sharedOrganiser;
}

#pragma mark - Storing stories

- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident {
	[self addStory: filename
		 withIdent: ident
		  organise: NO];
}

- (void) removeStoryWithIdent: (ZoomStoryID*) ident
		   deleteFromMetadata: (BOOL) delete {
	[storyLock lock];
	
	NSString* filename = [identsToFilenames objectForKey: ident];
	
	if (filename != nil) {
		[filenamesToIdents removeObjectForKey: filename];
		[identsToFilenames removeObjectForKey: ident];
		
		NSInteger index = [storyFilenames indexOfObject: filename];
		if (index != NSNotFound) {
			[storyIdents removeObjectAtIndex: index];
			[storyFilenames removeObjectAtIndex: index];			
		}
	}
	
	if (delete) {
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] removeStoryWithIdent: ident];
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	}
	
	[storyLock unlock];
	[self organiserChanged];
}

- (BOOL) addStoryAtURL: (NSURL*) filename
		  withIdentity: (ZoomStoryID*) ident
			  organise: (BOOL) organise
				 error: (NSError**)error {
	if (ident == nil) {
		if (error) {
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain
										 code: paramErr
									 userInfo: nil];
		}
		return NO;
	}

	[storyLock lock];
	
	NSString* oldFilename = [[identsToFilenames objectForKey: ident] stringByStandardizingPath];
	ZoomStoryID* oldIdent = [filenamesToIdents objectForKey: oldFilename];
	
	// Get the story from the metadata database
	ZoomStory* theStory = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
	
#if DEVELOPMENT_BUILD
	NSLog(@"Adding %@ (IFID %@)", filename, ident);
	if (oldFilename) {
		NSLog(@"... previously %@ (%@)", oldFilename, oldIdent);
	}
#endif
	
	// If there's no story registered, then we need to create one
	if (theStory == nil) {
		// theStory = [[[NSApp delegate] userMetadata] findOrCreateStory: ident];
		Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForURL: filename];
		ZoomPlugIn* pluginInstance = pluginClass?[[pluginClass alloc] initWithURL: filename]:nil;
		
		if (pluginInstance) {
			theStory = [pluginInstance defaultMetadataWithError: error];
		} else {
			theStory = [ZoomStory defaultMetadataForURL: filename error: error];
		}
		if (theStory == nil) {
			[storyLock unlock];
			// Story somehow failed.
			return NO;
		}
		
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: theStory];
		if (theStory.title == nil) {
			theStory.title = filename.lastPathComponent.stringByDeletingPathExtension;
		}
		
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	}
		
	NSString *standardizedFile = filename.path.stringByStandardizingPath;
	if (oldFilename && oldIdent && [oldFilename isEqualToString: standardizedFile] && [oldIdent isEqualTo: ident]) {
		// Nothing to do
		[storyLock unlock];
#if DEVELOPMENT_BUILD
		NSLog(@"... looks OK");
#endif
		
		if (organise) {
			[self organiseStory: theStory
					  withIdent: ident] ;
		}
		return YES;
	}
	
	if (oldFilename) {
		[identsToFilenames removeObjectForKey: ident];
		[filenamesToIdents removeObjectForKey: oldFilename];
		
		NSInteger index = [storyFilenames indexOfObject: oldFilename];
		if (index != NSNotFound) {
			[storyFilenames removeObjectAtIndex: index];
			[storyIdents removeObjectAtIndex: index];
		}
	}

	if (oldIdent) {
		[filenamesToIdents removeObjectForKey: standardizedFile];
		[identsToFilenames removeObjectForKey: oldIdent];
	
		NSInteger index = [storyIdents indexOfObject: oldIdent];
		if (index != NSNotFound) {
			[storyFilenames removeObjectAtIndex: index];
			[storyIdents removeObjectAtIndex: index];
		}
	}
	
	[filenamesToIdents removeObjectForKey: standardizedFile];
	[identsToFilenames removeObjectForKey: ident];
	
	NSString* newFilename = [standardizedFile copy];
	ZoomStoryID* newIdent = [ident copy];
		
	[storyFilenames addObject: newFilename];
	[storyIdents addObject: newIdent];
	
	NSLog(@"... now %@ (%@)", newFilename, newIdent);
	
	if (newIdent != nil) {
		[identsToFilenames setObject: newFilename forKey: newIdent];
		[filenamesToIdents setObject: newIdent forKey: newFilename];
	}
	
	[storyLock unlock];
	
	if (organise) {
		[self organiseStory: theStory
				  withIdent: newIdent] ;
	}
	
	[self organiserChanged];

	return YES;
}

- (void) addStory: (NSString*) filename
		withIdent: (ZoomStoryID*) ident
		 organise: (BOOL) organise {
	[self addStoryAtURL: [NSURL fileURLWithPath: filename]
		   withIdentity: ident
			   organise: organise
				  error: NULL];
}

#pragma mark - Progress

- (void) startedActing {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserProgressNotification
														object: self
													  userInfo: @{@"ActionStarting": @YES}];
}

- (void) endedActing {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserProgressNotification
														object: self
													  userInfo: @{@"ActionStarting": @NO}];
}

#pragma mark - Retrieving story information

- (NSString*) filenameForIdent: (ZoomStoryID*) ident {
	NSString* res;
	
	[storyLock lock];
	res = [identsToFilenames objectForKey: ident];
	[storyLock unlock];
	
	return res;
}

- (ZoomStoryID*) identForFilename: (NSString*) filename {
	ZoomStoryID* res;
		
	[storyLock lock];
	res = [filenamesToIdents objectForKey: filename];
	[storyLock unlock];
	
	return res;
}

- (NSArray*) storyFilenames {
	return [storyFilenames copy];
}

- (NSArray*) storyIdents {
	return [storyIdents copy];
}

#pragma mark - Story-specific data

- (NSString*) directoryForName: (NSString*) name {
	// Gets rid of certain illegal characters from the name, returning a valid directory name
	//	(Most illegal characters are replaced by '?', but '/' is replaced by ':' - look in the finder
	//	to see why)
	
	// Techincally, only '/' and NUL are invalid characters under UNIX. We invalidate a few more so as to
	// avoid the possibility of slightly dumb-looking filenames.
	NSInteger len = [name length];
	unichar* result = malloc(len*sizeof(unichar));
	int x;
	
	for (x=0; x<len; x++) {
		result[x] = [name characterAtIndex: x];
		
		switch (result[x]) {
			case '/': result[x] = ':'; break;	// Makes some twisted kind of sense
			case ':': result[x] = '?'; break;
			default:
				if (result[x] < 32) result[x] = '?';
		}
	}
	
	NSString* dir = [[NSString alloc] initWithCharactersNoCopy: result
														length: len
												  freeWhenDone: YES];
	
	return dir;
}

- (NSString*) preferredDirectoryForIdent: (ZoomStoryID*) ident {
	// The preferred directory is defined by the story group and title
	// (Ungrouped/untitled if there is no story group/title)

	// TESTME: what does stringByAppendingPathComponent do in the case where the group/title
	// contains a '/' or other evil character?
	// NSString* confDir = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
	NSString* confDir = [[ZoomPreferences globalPreferences] organiserDirectory];
	ZoomStory* theStory = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
	
	confDir = [confDir stringByAppendingPathComponent: [self directoryForName: [theStory group]]];
	confDir = [confDir stringByAppendingPathComponent: [self directoryForName: [theStory title]]];
	
	return confDir;
}

- (BOOL) directory: (NSString*) dir
		 isForGame: (ZoomStoryID*) ident {
	// If the preferences get corrupted or something similarily silly happens,
	// we want to avoid having games point to the wrong directories. This
	// routine checks that a directory belongs to a particular game.
	BOOL isDir;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: dir
											  isDirectory: &isDir]) {
		// Corner case
		return YES;
	}
	
	if (!isDir) // Files belong to no game
		return NO;
	
	NSString* idFile = [dir stringByAppendingPathComponent: ZoomIdentityFilename];
	if (![[NSFileManager defaultManager] fileExistsAtPath: idFile
											  isDirectory: &isDir]) {
		// Directory has no identification
		return NO;
	}
	
	if (isDir) // Identification must be a file
		return NO;
	
	NSData *fileData = [NSData dataWithContentsOfFile: idFile];
	if (!fileData) {
		// we need data, of course
		return NO;
	}
	
	ZoomStoryID* owner = [NSKeyedUnarchiver unarchivedObjectOfClass: [ZoomStoryID class] fromData: fileData error: NULL];
	if (!owner) {
		owner = [NSUnarchiver unarchiveObjectWithData: fileData];
	}
	
	if (owner && [owner isKindOfClass: [ZoomStoryID class]] && [owner isEqual: ident])
		return YES;
	
	// Directory belongs to some other game
	return NO;
}

- (NSString*) findDirectoryForIdent: (ZoomStoryID*) ident
					  createGameDir: (BOOL) createGame
					 createGroupDir: (BOOL) createGroup {
	// Assuming a story doesn't already have a directory, find (and possibly create)
	// a directory for it
	BOOL isDir;
	
	ZoomStory* theStory = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
	NSString* group = [self directoryForName: [theStory group]];
	NSString* title = [self directoryForName: [theStory title]];
	
	if (group == nil || [group isEqualToString: @""])
		group = @"Ungrouped";
	if (title == nil || [title isEqualToString: @""])
		title = @"Untitled";
	
	// Find the root directory
	// NSString* rootDir = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
	NSString* rootDir = [[ZoomPreferences globalPreferences] organiserDirectory];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: rootDir
											  isDirectory: &isDir]) {
		if (createGroup) {
			[[NSFileManager defaultManager] createDirectoryAtPath: rootDir
									  withIntermediateDirectories: NO
													   attributes: nil
															error: NULL];
			isDir = YES;
		} else {
			return nil;
		}
	}
	
	if (!isDir) {
		static BOOL warned = NO;
		
		if (!warned) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString(@"Game library not found", @"Game library not found");
			alert.informativeText = [NSString stringWithFormat: NSLocalizedString(@"Warning: %@ is a file", @"Warning: %@ is a file"), rootDir];
			[alert runModal];
		}
		warned = YES;
		return nil;
	}
	
	// Find the group directory
	NSString* groupDir = [rootDir stringByAppendingPathComponent: group];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: groupDir
											  isDirectory: &isDir]) {
		if (createGroup) {
			[[NSFileManager defaultManager] createDirectoryAtPath: groupDir
									  withIntermediateDirectories: NO
													   attributes: nil
															error: NULL];
			isDir = YES;
		} else {
			return nil;
		}
	}
	
	if (!isDir) {
		static BOOL warned = NO;
		
		if (!warned) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString(@"Group directory not found", @"Group directory not found");
			alert.informativeText = [NSString stringWithFormat: NSLocalizedString(@"Warning: %@ is a file", @"Warning: %@ is a file"), groupDir];
			[alert runModal];
		}
		warned = YES;
		return nil;
	}
	
	// Now the game directory
	NSString* gameDir = [groupDir stringByAppendingPathComponent: title];
	int number = 0;
	const int maxNumber = 20;
	
	while (![self directory: gameDir 
				  isForGame: ident] &&
		   number < maxNumber) {
		number++;
		gameDir = [groupDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %i", title, number]];
	}
	
	if (number >= maxNumber) {
		static BOOL warned = NO;
		
		if (!warned) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Game directory not found";
			alert.informativeText = [NSString stringWithFormat: @"Zoom was unable to locate a directory for the game '%@'", title];
			[alert runModal];
		}
		warned = YES;
		return nil;
	}
	
	// Create the directory if necessary
	if (![[NSFileManager defaultManager] fileExistsAtPath: gameDir
											  isDirectory: &isDir]) {
		if (createGame) {
			[[NSFileManager defaultManager] createDirectoryAtPath: gameDir
									  withIntermediateDirectories: NO
													   attributes: nil
															error: NULL];
		} else {
			if (createGroup) {
				// Special case, really. Sometimes we need to know where we're going to move the game to
				return gameDir;
			} else {
				return nil;
			}
		}
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: gameDir
											  isDirectory: &isDir] || !isDir) {
		// Chances of reaching here should have been eliminated previously
		return nil;
	}
	
	// Create the identifier file
	NSString* identityFile = [gameDir stringByAppendingPathComponent: ZoomIdentityFilename];
	NSData *dat = [NSKeyedArchiver archivedDataWithRootObject: ident
										requiringSecureCoding: YES
														error: NULL];
	[dat writeToFile: identityFile
			 options: 0
			   error: NULL];
	
	return gameDir;
}

- (NSString*) directoryForIdent: (ZoomStoryID*) ident
						 create: (BOOL) create {
	NSString* confDir = nil;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		
	// If there is a directory in the preferences, then that's the directory to use
	NSDictionary* gameDirs = [defaults objectForKey: ZoomGameDirectories];
	
	if (gameDirs && [ident description] != nil)
		confDir = [gameDirs objectForKey: [ident description]];

	BOOL isDir=NO;
	if (confDir && ![[NSFileManager defaultManager] fileExistsAtPath: confDir
											  isDirectory: &isDir]) {
		confDir = nil;
	}
	
	if (!isDir)
		confDir = nil;
	
	if (confDir && [self directory: confDir isForGame: ident])
		return confDir;
	
	confDir = nil;
	
	NSString* gameDir = [self findDirectoryForIdent: ident
									  createGameDir: create
									 createGroupDir: create];
	
	if (gameDir == nil) return nil;
		
	// Store this directory as the dir for this game
	NSMutableDictionary* newGameDirs = [gameDirs mutableCopy];

	if (newGameDirs == nil) {
		newGameDirs = [[NSMutableDictionary alloc] init];
	}

	if (ident != nil && [ident description] != nil) {
		[newGameDirs setObject: gameDir
						forKey: [ident description]];
		[defaults setObject: newGameDirs
					 forKey: ZoomGameDirectories];
	}
	
	return gameDir;
}

- (BOOL) moveStoryToPreferredDirectoryWithIdent: (ZoomStoryID*) ident {
	// Get the current directory
	NSString* currentDir = [self directoryForIdent: ident 
											create: NO];
	currentDir = [currentDir stringByStandardizingPath];
	
	if (currentDir == nil) return NO;

#ifdef DEVELOPMENT_BUILD
	NSLog(@"Moving %@ to its preferred path (currently at %@)", ident, currentDir);
#endif
	
	// Get the 'ideal' directory
	NSString* idealDir = [self findDirectoryForIdent: ident
									   createGameDir: NO
									  createGroupDir: YES];
	idealDir = [idealDir stringByStandardizingPath];
	
	// See if they already match
	if ([[idealDir lowercaseString] isEqualToString: [currentDir lowercaseString]]) 
		return YES;
	
#ifdef DEVELOPMENT_BUILD
	NSLog(@"Ideal location is %@", idealDir);
#endif
	
	// If they don't match, then idealDir should be new (or something weird has just occured)
	// Hmph. HFS+ is case-insensitve, and stringByStandardizingPath does not take account of this. This could
	// cause some major problems with organiseStory:withIdent:, as that deletes/copies files...
	// We're dealing with this by calling lowercaseString, but there's no guarantee that this matches the algorithm
	// used for comparing filenames internally to HFS+.
	//
	// Don't even think about UFS or HFSX. There's no way to tell which we're using
	if ([[NSFileManager defaultManager] fileExistsAtPath: idealDir]) {
		// Doh!
		NSLog(@"Wanted to move game from '%@' to '%@', but '%@' already exists", currentDir, idealDir, idealDir);
		return NO;
	}
	
	// Move the old directory to the new directory
	
	// Vague possibilities of this failing: in particular, currentDir may be not write-accessible or
	// something might appear there between our check and actually moving the directory	
	if (![[NSFileManager defaultManager] moveItemAtPath: currentDir
												 toPath: idealDir
												  error: NULL]) {
		NSLog(@"Failed to move '%@' to '%@'", currentDir, idealDir);
		return NO;
	}
	
	// Success: store the new directory in the defaults
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSDictionary* gameDirs = [defaults objectForKey: ZoomGameDirectories];
	if (gameDirs == nil) gameDirs = [NSDictionary dictionary];
	NSMutableDictionary* newGameDirs = [gameDirs mutableCopy];
	
	if (newGameDirs == nil) {
		newGameDirs = [[NSMutableDictionary alloc] init];
	}
	
	if (ident != nil && [ident description] != nil) {
		[newGameDirs setObject: idealDir
						forKey: [ident description]];
		[defaults setObject: newGameDirs
					 forKey: ZoomGameDirectories];	
	}
	
	return YES;
}

- (void) someStoryHasChanged: (NSNotification*) not {
	ZoomStory* story = [not object];
	
#ifdef DEVELOPMENT_BUILD
	NSLog(@"Story %@ has changed", [story title]);
#endif
	
	if (![story isKindOfClass: [ZoomStory class]]) {
		NSLog(@"someStoryHasChanged: called with a non-story object (too many spoons?)");
		return; // Unlikely but possible. If I'm a spoon, that is.
	}
	
	// De and requeue this to be done next time through the run loop
	// (stops this from being performed multiple times when many story parameters are updated together)
	[[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(finishChangingStory:)
											   target: self
											 argument: story];
	[[NSRunLoop currentRunLoop] performSelector: @selector(finishChangingStory:)
										 target: self
									   argument: story
										  order: 128
										  modes: @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
}

- (void) finishChangingStory: (ZoomStory*) story {
	// For our pre-arranged stories, several IDs are possible, but more usually one
	NSArray* storyIDs = [story storyIDs];
	BOOL changed = NO;
	
#ifdef DEVELOPMENT_BUILD
	NSLog(@"Finishing changing %@", [story title]);
#endif
	
	for (ZoomStoryID* ident in storyIDs) {
		NSInteger identID = [storyIdents indexOfObject: ident];
		
		if (identID != NSNotFound) {
			// Get the old location of the game
			ZoomStoryID* realID = [storyIdents objectAtIndex: identID];
			
			NSString* oldGameFile = [self directoryForIdent: ident
													 create: NO];
			NSString* oldGameLoc = [storyFilenames objectAtIndex: identID];
			oldGameFile = [oldGameFile stringByAppendingPathComponent: [oldGameLoc lastPathComponent]];
			
			oldGameFile = [oldGameFile stringByStandardizingPath];
			oldGameLoc = [oldGameLoc stringByStandardizingPath];
			
#ifdef DEVELOPMENT_BUILD
			NSLog(@"ID %@ (%@) is located at %@ (%@)", ident, realID, oldGameFile, oldGameLoc);
#endif
			
			// Actually perform the move
			if ([self moveStoryToPreferredDirectoryWithIdent: [storyIdents objectAtIndex: identID]]) {
				changed = YES;
			
				// Store the new location of the game, if necessary
				if (/* DISABLES CODE */ (YES) || [oldGameLoc isEqualToString: oldGameFile]) {
					NSString* newGameFile = [[self directoryForIdent: ident create: NO] stringByAppendingPathComponent: [oldGameLoc lastPathComponent]];
					newGameFile = [newGameFile stringByStandardizingPath];
					
#ifdef DEVELOPMENT_BUILD
					NSLog(@"Have moved to %@", newGameFile);
#endif
					
					if (![oldGameFile isEqualToString: newGameFile]) {
						[filenamesToIdents removeObjectForKey: oldGameFile];
						
						if (realID != nil) {
							[filenamesToIdents setObject: realID
												  forKey: newGameFile];
							[identsToFilenames setObject: newGameFile
												  forKey: realID];
						}
						
						[storyFilenames replaceObjectAtIndex: identID
												  withObject: newGameFile];
					}
				}
			}
		}
	}
	
	if (changed)
		[self organiserChanged];
}

#pragma mark - Reorganising stories

- (void) organiseStory: (ZoomStory*) story
			 withIdent: (ZoomStoryID*) ident {
	NSString* filename = [self filenameForIdent: ident];
	
	if (filename == nil) {
		NSLog(@"WARNING: Attempted to organise a story with no filename");
		return;
	}
	
#if DEVELOPMENT_BUILD
	NSLog(@"Organising %@ (%@)", [story title], ident);
#endif
	
	[storyLock lock];
	
	NSString* oldFilename = filename;

#if DEVELOPMENT_BUILD
	NSLog(@"... currently at %@", oldFilename);
#endif
	
	// Copy to a standard directory, change the filename we're using
	filename = [filename stringByStandardizingPath];
		
	NSString* fileDir = [self directoryForIdent: ident create: YES];
	NSString* destFile = [fileDir stringByAppendingPathComponent: [oldFilename lastPathComponent]];
	destFile = [destFile stringByStandardizingPath];
	
#if DEVELOPMENT_BUILD
	NSLog(@"... best directory %@ (file will be %@)", fileDir, destFile);
#endif
	
	if (![filename isEqualToString: destFile]) {
		BOOL moved = NO;
		
		if ([[filename lowercaseString] isEqualToString: [destFile lowercaseString]]) {
			// *LIKELY* that these are in fact the same file with different case names
			// Cocoa doesn't seem to provide a good way to see if too paths are actually the same:
			// so the semantics of this might be incorrect in certain edge cases. We move to ensure
			// that everything is nice and safe
			[[NSFileManager defaultManager] moveItemAtPath: filename
													toPath: destFile
													 error: NULL];
			
			moved = YES;
			filename = destFile;
		}
		
		// The file might already be organised, but in the wrong directory
		// NSString* gameStorageDirectory = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
		NSString* gameStorageDirectory = [[ZoomPreferences globalPreferences] organiserDirectory];
		NSArray* storageComponents = [gameStorageDirectory pathComponents];

		NSArray* filenameComponents = [filename pathComponents];
		BOOL outsideOrganisation = YES;
		
		if ([filenameComponents count] == [storageComponents count]+3) {
			// filenameComponents should have 3 components extra over the storage directory: group/title/game.z5
			
			// Compare the components
			int x;
			outsideOrganisation = NO;
			for (x=0; x<[storageComponents count]; x++) {
				// Note, there's no way to see if we're using a case-sensitive file system or not. We assume
				// we are, as that's the default. People running with HFSX or UFS can just put up with the
				// odd weirdness occuring due to this.
				NSString* c1 = [[filenameComponents objectAtIndex: x] lowercaseString];
				NSString* c2 = [[storageComponents objectAtIndex: x] lowercaseString];
				
				if (![c1 isEqualToString: c2]) {
					outsideOrganisation = YES;
					break;
				}
			}
		}
		
		if (!outsideOrganisation) {
			// Have to move the file from the directory its in to the new directory
			// Really want to move resources and savegames too... Hmm
			NSString* oldDir = [filename stringByDeletingLastPathComponent];
			NSEnumerator* dirEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: oldDir error:NULL] objectEnumerator];
			
			for (NSString* fileToMove in dirEnum) {
#if DEVELOPMENT_BUILD
				NSLog(@"... reorganising %@ to %@", [oldDir stringByAppendingPathComponent: fileToMove], [fileDir stringByAppendingPathComponent: fileToMove]);
#endif

				[[NSFileManager defaultManager] moveItemAtPath: [oldDir stringByAppendingPathComponent: fileToMove]
														toPath: [fileDir stringByAppendingPathComponent: fileToMove]
														 error: NULL];
			}
			
			moved = YES;
			filename = destFile;
		}
		
		// If we haven't already moved the file, then
		if (!moved) {
			[[NSFileManager defaultManager] removeItemAtPath: destFile error: NULL];
			if ([[NSFileManager defaultManager] copyItemAtPath: filename
														toPath: destFile
														 error: NULL]) {
				filename = destFile;
			} else {
				NSLog(@"Warning: couldn't copy '%@' to '%@'", filename, destFile);
			}
		}
		
		// Notify the workspace of the change
		[[NSWorkspace sharedWorkspace] noteFileSystemChanged: filename];
		[[NSWorkspace sharedWorkspace] noteFileSystemChanged: destFile];
	}
	
	// Update the indexes
	NSInteger filenameIndex = [storyFilenames indexOfObject: oldFilename];
	if (filenameIndex != NSNotFound) {
		[storyFilenames removeObjectAtIndex: filenameIndex];
		[storyIdents removeObjectAtIndex: filenameIndex];
	}

	if (ident != nil) {
#if DEVELOPMENT_BUILD
		NSLog(@"... %@ <=> %@", ident, filename);
#endif		
		
		[identsToFilenames setObject: filename
							  forKey: ident];
		[filenamesToIdents removeObjectForKey: oldFilename];
		[filenamesToIdents setObject: ident
							  forKey: filename];
		
		[storyFilenames addObject: filename];
		[storyIdents	addObject: ident];
	}
	
	// Organise the story's resources
	NSString* resources = [story objectForKey: @"ResourceFilename"];
	if (resources != nil && [[NSFileManager defaultManager] fileExistsAtPath: resources]) {
		NSString* dir = [self directoryForIdent: ident
										 create: NO];
		BOOL exists, isDir;
		NSFileManager* fm = [NSFileManager defaultManager];
		
		if (dir == nil) {
			NSLog(@"No organised directory for game: cannot store resources");
			[storyLock unlock];
			return;
		}
		
		exists = [fm fileExistsAtPath: dir
						  isDirectory: &isDir];
		if (!exists || !isDir) {
			NSLog(@"Organised directory for game does not exist");
			return;
		}
		
		NSString* newFile = [dir stringByAppendingPathComponent: @"resource.blb"];
		NSString* oldFile = resources;
		
		newFile = [newFile stringByStandardizingPath];
		oldFile = [oldFile stringByStandardizingPath];
		
		if (![[oldFile lowercaseString] isEqualToString: [newFile lowercaseString]]) {
			if ([fm fileExistsAtPath: newFile]) {
				[fm removeItemAtPath: newFile
							   error: NULL];
			}
			
			if (![fm copyItemAtPath: resources
							 toPath: newFile
							  error: NULL]) {
				NSLog(@"Unable to copy resource file to new location");
			} else {
				resources = newFile;
			}
			
			[story setObject: resources
					  forKey: @"ResourceFilename"];
		}
	} else {
		[story setObject: nil
				  forKey: @"ResourceFilename"];
	}

	[storyLock unlock];
}

- (void) organiseStory: (ZoomStory*) story {
	BOOL organised = NO;
	
	for (ZoomStoryID* thisID in story.storyIDs) {
		NSString* filename = [self filenameForIdent: thisID];
		
		if (filename != nil) {
			[self organiseStory: story
					  withIdent: thisID];
			organised = YES;
		}
	}
	
	if (!organised) {
		NSLog(@"WARNING: attempted to organise story with no IDs");
	}
}

/// Forces an organisation of all the stories stored in the database.
///
/// This is useful if, for example, the 'keep games organised' option is switched on/off
- (void) organiseAllStories {
	// Create the information dictionary
	NSDictionary* threadDictionary = @{
	};
	
	[storyLock lock];
	if (alreadyOrganising) {
		NSLog(@"ZoomStoryOrganiser: organiseAllStories called while Zoom was already in the process of organising");
		[storyLock unlock];
		return;
	}
	
	alreadyOrganising = YES;
	
	// Run a separate thread to do (some of) the work
	CFRetain((__bridge CFTypeRef)(self)); // Released by the thread when it finishes
	NSThread *organizerThread = [[NSThread alloc] initWithTarget: self
														selector: @selector(organiserThread:)
														  object: threadDictionary];
	organizerThread.name = @"Zoom Organiser Thread";
	[organizerThread start];
	[storyLock unlock];
}

- (void) renamedIdent: (ZoomStoryID*) ident
		   toFilename: (NSString*) filename {
	if (ident == nil) return;
	
	filename = [NSString stringWithString: filename];
	
	[storyLock lock];
	
	NSString* oldFilename = [identsToFilenames objectForKey: ident];
	ZoomStoryID* oldID = [filenamesToIdents objectForKey: oldFilename];
	
	if (oldFilename) [identsToFilenames removeObjectForKey: ident];
	if (oldID) [filenamesToIdents removeObjectForKey: oldFilename];
	
	[identsToFilenames setObject: filename
						  forKey: ident];
	[filenamesToIdents setObject: ident
						  forKey: filename];
	
	[storyLock unlock];
	
	[self organiserChanged];
}

- (void) reorganiseStoriesToNewDirectory: (NSString*) newStoryDirectory {
	// Changes the story organisation directory
	// Should be called before changing the story directory in the preferences
	if (![[NSFileManager defaultManager] fileExistsAtPath: newStoryDirectory]) {
		if (![[NSFileManager defaultManager] createDirectoryAtPath: newStoryDirectory
									   withIntermediateDirectories: NO
														attributes: nil
															 error: NULL]) {
			NSLog(@"WARNING: Can't reorganise to %@ - couldn't create directory", newStoryDirectory);
			return;
		}
	}
	
	[storyLock lock];
	
	// Get the old story directory
	NSString* lastStoryDirectory = [[[ZoomPreferences globalPreferences] organiserDirectory] copy];
	
	// Nothing to do if it's not different
	if ([[lastStoryDirectory lowercaseString] isEqualToString: [newStoryDirectory lowercaseString]]) {
		[storyLock unlock];
		[storyLock lock];
	}
	
	// Move the stories around
	[self startedActing];

	// List of files in our database
	NSArray* filenames = [[filenamesToIdents allKeys] copy];
	
	// Parts of directories
	NSArray* originalComponents = [lastStoryDirectory pathComponents];
	
	for (NSString* filename in filenames) @autoreleasepool {
		NSInteger x;

		// Retrieve info about the file
		ZoomStoryID* storyID = [filenamesToIdents objectForKey: filename];
		NSArray* filenameComponents = [filename pathComponents];
		
		// Do nothing if the file is definitely outside the organisation structure
		if ([filenameComponents count] <= [originalComponents count]+1) {
			NSLog(@"WARNING: Not organising %@, as it doesn't appear to have been organised before", filename);
			continue;	// Can't be equivalent.
		}
		
		// Work out where this file would end up
		NSString* newFilename = newStoryDirectory;
		for (x=[originalComponents count]; x<[filenameComponents count]; x++) {
			newFilename = [newFilename stringByAppendingPathComponent: [filenameComponents objectAtIndex: x]];
		}
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: filename]) {
			// File has gone away - note that with the way this algorithm is implemented, this is expected to happen
			// If the file now exists in the new location, update our database
			// If not, then log a warning
			if (storyID == nil) {
				NSLog(@"WARNING: Not organising %@, as its information appears to have disappeared from the database", filename);
			} else if (![[NSFileManager defaultManager] fileExistsAtPath: newFilename]) {
				NSLog(@"WARNING: The file %@ appears to have gone away somewhere mysterious", filename);
			} else {
				[storyLock unlock];
				[self renamedIdent: storyID
						toFilename: newFilename];
				[storyLock lock];
			}
			continue;
		}
		
		// If filename is in the original directory, then move it to the new one
		BOOL isOrganised = YES;
		for (x=0; x<[originalComponents count]; x++) {
			if ([[filenameComponents objectAtIndex: x] caseInsensitiveCompare: [originalComponents objectAtIndex: x]] != NSOrderedSame) {
				isOrganised = NO;
				break;
			}
		}
		
		if (!isOrganised) {
			NSLog(@"WARNING: Not organising %@, as it doesn't appear to have been organised before", filename);
			continue;	// Can't be equivalent.
		}
		
		// Work out what to move to where
		NSInteger component = [originalComponents count];
		
		NSString* componentToMove = nil;
		
		NSString* moveFrom = nil;
		NSString* moveTo = nil;

		while (component < [filenameComponents count]) {
			componentToMove = [filenameComponents objectAtIndex: [originalComponents count]];

			moveFrom = [lastStoryDirectory stringByAppendingPathComponent: componentToMove];
			moveTo = [newStoryDirectory stringByAppendingPathComponent: componentToMove];

			if (![[NSFileManager defaultManager] fileExistsAtPath: moveTo]) {
				break;
			}
		}
		
		if ([[NSFileManager defaultManager] fileExistsAtPath: moveTo]) {
			NSLog(@"WARNING: Not moving %@, as it would clobber a file at %@", moveFrom, moveTo);
			continue;
		}
		
		if (componentToMove == nil) {
			// Should never happen
			NSLog(@"WARNING: Programmer is a spoon (tried to move something that we should have discarded earlier)");
			continue;
		}
		
		// OK, move the file
		if (![[NSFileManager defaultManager] moveItemAtPath: moveFrom
													 toPath: moveTo
													  error: NULL]) {
			NSLog(@"WARNING: Failed to move %@ to %@", moveFrom, moveTo);
			continue;
		}
		
		// Update our database		
		[storyLock unlock];
		[self renamedIdent: storyID
				toFilename: newFilename];
		[storyLock lock];
	}
	[self endedActing];
	
	[storyLock unlock];
		
	[self storePreferences];
	[[NSUserDefaults standardUserDefaults] synchronize];	// In case we later crash
}

#pragma mark - Reorganising story files

- (NSString*) gameStorageDirectory {
	// We also can't use the user defaults from a thread (legacy: we're using the ZoomPreferences object now)
	return [[ZoomPreferences globalPreferences] organiserDirectory];
	// return [[NSUserDefaults standardUserDefaults] objectForKey: ZoomGameStorageDirectory];
}

- (NSDictionary*) storyInfoForFilename: (NSString*) filename {
	[storyLock lock];
	
	ZoomStoryID* storyID = [filenamesToIdents objectForKey: filename];
	ZoomStory* story = nil;
	
	if (storyID) story = [(ZoomAppDelegate*)[NSApp delegate] findStory: storyID];

	[storyLock unlock];
	
	return [NSDictionary dictionaryWithObjectsAndKeys: storyID, @"storyID", story, @"story", nil];
}

- (void) organiserThread: (NSDictionary*) dict {
	@autoreleasepool {
		NSFileManager *fm = [[NSFileManager alloc] init];
	// Start things rolling
		dispatch_async(dispatch_get_main_queue(), ^{
			[self startedActing];
		});
	
	__block NSString* gameStorageDirectory;
		dispatch_sync(dispatch_get_main_queue(), ^{
			gameStorageDirectory = [[self gameStorageDirectory] copy];
		});
	NSArray* storageComponents = [gameStorageDirectory pathComponents];
	
	// Get the list of stories we need to update
	// It is assumed any new stories at this point will be organised correctly
	[storyLock lock];
	NSArray* filenames = [[filenamesToIdents allKeys] copy];
	[storyLock unlock];
	
	for (NSString* filename in filenames) @autoreleasepool {
		// First: check that the file exists
		struct stat sb;
		
		// Get the file system path
		
		[storyLock lock];
		if (stat([fm fileSystemRepresentationWithPath: filename], &sb) != 0) {
			// The story does not exist: remove from the database and keep moving
			
			ZoomStoryID* oldID = [filenamesToIdents objectForKey: filename];
			
			if (oldID != nil) {
				// Is actually still in the database as that filename
				[filenamesToIdents removeObjectForKey: filename];
				[identsToFilenames removeObjectForKey: oldID];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self organiserChanged];
				});
			}
			
			[storyLock unlock];
			continue;
		}
		
		// OK, the story still exists with that filename. Pass this off to the main thread
		// for organisation
		// [(ZoomStoryOrganiser*)[subThreadConnection rootProxy] reorganiseStoryWithFilename: filename];
		// ---  FAILS, creates duplicates sometimes
		
		// There are a few possibilities:
		//
		//		1. The story is outside the organisation directory
		//		2. The story is in the organisation directory, but in the wrong group
		//		3. The story is in the organisation directory, but in the wrong directory
		//		4. There are multiple copies of the story in the directory
		//
		// 2 and 3 here are not exclusive. There may be a story in the organisation directory with the
		// same title, so the 'ideal' location might turn out to be unavailable.
		//
		// In case 1, act as if the story has been newly added, except move the old story to the trash. Finished.
		// In case 2, move the story directory to the new group. Rename if it already exists there (pick
		//		something generic, I guess). Fall through to check case 3.
		// In case 3, pick the 'best' possible name, and rename it
		// In case 4, merge the story directories. (We'll leave this out for the moment)
		//
		// Also a faint chance that the file/directory will disappear while we're operating on it.
		//
		// We have a problem being in a separate thread. NSFileManager can only be called from the
		// main thread :-( We can call Unix file functions, but in order to get the UNIX path, we need to call
		// NSFileManager.

		// Can't lock the story while calling the main thread, or we might deadlock
		[storyLock unlock];
		
		// Get the story information
		__block NSDictionary* storyInfo;
		dispatch_sync(dispatch_get_main_queue(), ^{
			storyInfo = [self storyInfoForFilename: filename];
		});
		
		ZoomStoryID* storyID = [storyInfo objectForKey: @"storyID"];
		ZoomStory* story = [storyInfo objectForKey: @"story"];
		
		if (storyID == nil || story == nil) {
			// No info (file has gone away?)
			NSLog(@"Organiser: failed to reorganise file '%@' - couldn't find any information for this file", filename);
			continue;
		}
		
		// CHECK FOR CASE 1 - does filename begin with gameStorageDirectory?
		NSArray* filenameComponents = [filename pathComponents];
		BOOL outsideOrganisation = YES;
		
		if ([filenameComponents count] == [storageComponents count]+3) {
			// filenameComponents should have 3 components extra over the storage directory: group/title/game.z5
			
			// Compare the components
			int x;
			outsideOrganisation = NO;
			for (x=0; x<[storageComponents count]; x++) {
				// Note, there's no way to see if we're using a case-sensitive file system or not. We assume
				// we are, as that's the default. People running with HFSX or UFS can just put up with the
				// odd weirdness occuring due to this.
				NSString* c1 = [[filenameComponents objectAtIndex: x] lowercaseString];
				NSString* c2 = [[storageComponents objectAtIndex: x] lowercaseString];
				
				if (![c1 isEqualToString: c2]) {
					outsideOrganisation = YES;
					break;
				}
			}
		}
		
		if (outsideOrganisation) {
			// CASE 1 HAS OCCURED. Organise this story
			NSLog(@"File %@ outside of organisation directory: organising", filename);
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[self organiseStory: story withIdent: storyID];
			});
			continue;
		}
		
		// CHECK FOR CASE 2: story is in the wrong group
		BOOL inWrongGroup = NO;
		
		[storyLock lock];
		NSString* expectedGroup = [self directoryForName: [[story group] copy]];
		NSString* actualGroup = [filenameComponents objectAtIndex: [filenameComponents count]-3];
		if (expectedGroup == nil || [expectedGroup isEqualToString: @""]) expectedGroup = @"Ungrouped";
		[storyLock unlock];
		
		if (![[actualGroup lowercaseString] isEqualToString: [expectedGroup lowercaseString]]) {
			NSLog(@"Organiser: File %@ not in the expected group (%@ vs %@)", filename, actualGroup, expectedGroup);
			inWrongGroup = YES;
		}
		
		// CHECK FOR CASE 3: story is in the wrong directory
		BOOL inWrongDirectory = NO;
		
		[storyLock lock];
		NSString* expectedDir = [self directoryForName: [[story title] copy]];
		NSString* actualDir = [filenameComponents objectAtIndex: [filenameComponents count]-2];
		[storyLock unlock];
		
		if (![[actualDir lowercaseString] isEqualToString: [expectedDir lowercaseString]]) {
			NSLog(@"Organiser: File %@ not in the expected directory (%@ vs %@)", filename, actualDir, expectedDir);
			inWrongDirectory = YES;
		}
		
		// Deal with these two cases: create the group/move the directory
		if (inWrongGroup) {
			// Create the group directory if required
			NSString* groupDirectory = [gameStorageDirectory stringByAppendingPathComponent: expectedGroup];
			
			// Create the group directory if it doesn't already exist
			// Don't organise this file if there's a file already here

			if (stat([fm fileSystemRepresentationWithPath: groupDirectory], &sb) == 0) {
				if ((sb.st_mode&S_IFDIR) == 0) {
					// Oops, this is a file: can't move anything here
					NSLog(@"Organiser: Can't create group directory at %@ - there's a file in the way", groupDirectory);
					continue;
				}
			} else {
				NSLog(@"Organiser: Creating group directory at %@", groupDirectory);
				int err = mkdir([fm fileSystemRepresentationWithPath: groupDirectory], 0755);
				
				if (err != 0) {
					// strerror & co aren't thread-safe so we can't safely retrieve the actual error number
					NSLog(@"Organiser: Failed to create directory at %@", groupDirectory);
					continue;
				}
			}
		}
		
		if (inWrongGroup || inWrongDirectory) {
			// Move the game (semi-atomically)
			[storyLock lock];
			
			NSString* oldDirectory = [filename stringByDeletingLastPathComponent];
			
			NSString* groupDirectory = [gameStorageDirectory stringByAppendingPathComponent: expectedGroup];
			NSString* titleDirectory;
			
			int count = 0;
			
			// Work out where to put the game (duplicates might exist)
			do {
				if (count == 0) {
					titleDirectory = [groupDirectory stringByAppendingPathComponent: expectedDir];
				} else {
					titleDirectory = [groupDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"%@ %i", expectedDir, count]];
				}
				
				if ([[titleDirectory lowercaseString] isEqualToString: [oldDirectory lowercaseString]]) {
					// Nothing to do!
					NSLog(@"Organiser: oops, name difference is due to multiple stories with the same title");
					break;
				}
				
				if (stat([fm fileSystemRepresentationWithPath: titleDirectory], &sb) == 0) {
					// Already exists - try the next name along
					count++;
					continue;
				}
				
				// Doesn't exist at the moment: OK for renaming
				break;
			} while (1);

			if ([[titleDirectory lowercaseString] isEqualToString: [oldDirectory lowercaseString]]) {
				// Still nothing to do
				[storyLock unlock];
				continue;
			}
			
			// Move the game to its new home
			NSLog(@"Organiser: Moving %@ to %@", oldDirectory, titleDirectory);
			
			if (rename([fm fileSystemRepresentationWithPath: oldDirectory], [fm fileSystemRepresentationWithPath: titleDirectory]) != 0) {
				[storyLock unlock];
				
				NSLog(@"Organiser: Failed to move %@ to %@ (rename failed)", oldDirectory, titleDirectory);
				continue;
			}
			
			// Change the storyFilenames array
			/* -- ??
			NSInteger oldIndex = [storyFilenames indexOfObject: filename];
			
			if (oldIndex != NSNotFound) {
				[storyFilenames removeObjectAtIndex: oldIndex];
				[storyIdents removeObjectAtIndex: oldIndex];
			}
			 */
			
			[storyFilenames addObject: [titleDirectory stringByAppendingPathComponent: [filename lastPathComponent]]];
			//[storyIdents addObject: storyID];

			[storyLock unlock];
			
			// Update filenamesToIdents and identsToFilenames appropriately
			NSString *tmpString = [titleDirectory stringByAppendingPathComponent: [filename lastPathComponent]];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self renamedIdent: storyID
						toFilename: tmpString];
			});
		}
	}
	
	// Not organising any more
	[storyLock lock];
	alreadyOrganising = NO;
	[storyLock unlock];
	
	// Tidy up
	CFRelease((__bridge CFTypeRef)(self));
	
		dispatch_async(dispatch_get_main_queue(), ^{
			[self endedActing];
		});
	}
}

@end
