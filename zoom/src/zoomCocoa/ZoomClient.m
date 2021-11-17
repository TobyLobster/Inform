//
//  ZoomClient.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomClient.h"
#import <ZoomView/ZoomProtocol.h>
#import "ZoomClientController.h"
#import "ZoomStoryOrganiser.h"
#import <ZoomView/ZoomView-Swift.h>

#import "ZoomAppDelegate.h"

#import <ZoomPlugIns/ifmetabase.h>

// This deserves a note by itself: the autosave system is a bit weird. Strange bits are
// handled by strange objects for strange reasons. This is because we have:
//
//   zMachine (Model, runs in a seperate process)
//   ZoomClient (Also a model)
//   ZoomClientController (Controller)
//   ZoomView (View)
//
// These are used like this:
//
//     ZoomClient -> ZoomClientController -> ZoomView
//                                              |
//                                              v
//											 zMachine (Look, ma, I broke the paradigm!)
//
// But autosave state is distributed across all of them. So things that save stuff are
// kind of distributed, too.
//
// The zMachine is simple: we just derive save state from there: same as an undo buffer
// (which in Zoom is the same as a save file). We need the display state from the ZoomView.
// Technically, y'see, ZoomClient doesn't represent a running ZMachine: that's associated
// with the ZoomView (ZoomView has to be self-contained). So, we have an encoder there.
// The actual saving is done by ZoomClientController: ZoomClient represents a game, but
// ZoomClientController represents a session with a game, and the autosave data is
// associated with a session. Anyway, we save at the same time we store the data in the
// game info window, as that's the opportune moment.
//
// Loading has even more hair: we load the autosave data into the ZoomClient, so the
// ZoomClientController can pick it up and ask ZoomView to do the actual work of loading.
// (Actually, this is just saving in reverse, but with now with the involvement of
// ZoomClient).
//
// Hmph, there may have been a better way to design this, but I really wanted (and need)
// ZoomView to be a self-contained z-machine thingie. Which is what breaks the MVC
// paradigm. Well, that and the need for two completely seperate models (game data and
// game state). It makes sense if you don't care about autosave.
//
// Oh, and, umm, official Zoom terminology is 'Story' rather than 'Game'. Except I always
// forget that.

@implementation ZoomClient {
	BOOL wasRestored;
	NSMutableArray<NSString*>* loadingErrors;
}

- (id) init {
    self = [super init];

    if (self) {
        gameData = nil;
		story = nil;
		storyId = nil;
		autosaveData = nil;
		skein = [[ZoomSkein alloc] init];
		resources = nil;
		wasRestored = NO;
    }

    return self;
}

#pragma mark - Creating the document

- (void) makeWindowControllers {
    ZoomClientController* controller = [[ZoomClientController alloc] init];

    [self addWindowController: controller];
}

- (NSData *)dataOfType:(NSString *)type error:(NSError * _Nullable * _Nullable)outError {
    // Can't save, really

    return gameData;
}

- (BOOL)readFromData:(NSData *)data
			  ofType:(NSString *)type
			   error:(NSError * _Nullable * _Nullable)outError {
	ZoomIsSpotlightIndexing = NO;
	const unsigned char* bytes = [data bytes];
	BOOL isForm = NO;
	
	// No valid game can be less than 40 bytes long (in fact, it must be longer but 40 bytes is needed for the ID, etc)
	if ([data length] < 40) {
		if (outError) {
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileReadCorruptFileError
										userInfo: nil];
		}
		return NO;
	}
	
	// See if this looks like a Blorb file (begins with 'FORM')
	if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') isForm = YES;
	
	if ([type isEqualToString: @"public.blorb"] || isForm) {
		// Blorb files already have their resources pre-packaged: get the Z-Code chunk out of this file
		gameData = nil;
		
		ZoomBlorbFile* newRes = [[ZoomBlorbFile alloc] initWithData: data
															  error: outError];
		if (newRes == nil) {
			return NO;
		}
		
		[self setResources: newRes];
		
		NSArray* zcodChunks = [newRes chunksWithType: @"ZCOD"];
		if (zcodChunks == nil || [zcodChunks count] <= 0) {
			NSLog(@"Not a Z-Code file");
			if (outError) {
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSFileReadCorruptFileError
											userInfo: nil];
			}
			return NO;
		}
		
		gameData = [newRes dataForChunk: [zcodChunks objectAtIndex: 0]];
		if (gameData == nil) {
			if (outError) {
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSFileReadCorruptFileError
											userInfo: nil];
			}
			return NO;
		}
	} else {
		// Just a plain z-code file: load the lot
		gameData = data;
	}
	
	// Discover the metadata for this game
	storyId = [[ZoomStoryID alloc] initWithZCodeStory: gameData
												error: outError];

	if (storyId == nil) {
		// Can't ID this story
		gameData = nil;
		if (outError) {
			*outError = [NSError errorWithDomain: ZoomStoryIDErrorDomain
											code: ZoomStoryIDErrorNoIdentGenerated
										userInfo: nil];
		}
		return NO;
	}
	
	ZoomMetadata* userMetadata = [(ZoomAppDelegate*)[NSApp delegate] userMetadata];
	
	story = [userMetadata containsStoryWithIdent: storyId]?[userMetadata findOrCreateStory: storyId]:nil;
	
	if (!story) {
		// If there is no metadata, then make some up
		story = [(ZoomAppDelegate*)[NSApp delegate] findStory: storyId];
		
		if (story == nil) {
			story = [ZoomStory defaultMetadataForURL: [self fileURL] error: NULL];
		}
		
		[story addID: storyId];
		
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: story];
		
		story = [[(ZoomAppDelegate*)[NSApp delegate] userMetadata] findOrCreateStory: storyId];
	} else {
		// If there is some metadata, then keep it around
//		[story retain];
	}
	
	// Retrieve story resources (if available)
	NSString* resourceFilename = [story objectForKey: @"ResourceFilename"];
	if (resourceFilename != nil && [[NSFileManager defaultManager] fileExistsAtPath: resourceFilename]) {
		// Try to load the resources set for this game
		NSError *err;
		ZoomBlorbFile* newResources = [[ZoomBlorbFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath: resourceFilename] error: &err];
		
		if (newResources) {
			// Resources loaded OK: discard any resources we may have loaded earlier in findResourcesForFile
			resources = newResources;
		} else {
			// Failed to load the resources that were set
			[self addLoadingError: @"Failed to load resources: the resource file set for the story was found but is not a valid Blorb resource file"];
			[self addLoadingError: err.localizedDescription];
			[story setObject: nil
					  forKey: @"ResourceFilename"];
		}
	} else if (resourceFilename != nil) {
		// Resource file not found
		[self addLoadingError: resources==nil?@"Failed to load resources: the resources set for this story could not be found":
			@"Failed to load resources that were set for this story, but found alternatives in the directory with story file"];
		[story setObject: nil
				  forKey: @"ResourceFilename"];
	}
	
	// Store/organise this story
	[[ZoomStoryOrganiser sharedStoryOrganiser] addStoryAtURL: [self fileURL]
												withIdentity: storyId
													organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]
													   error: NULL];
    
    return YES;
}

#pragma mark - Document info

@synthesize gameData;
@synthesize storyInfo=story;
@synthesize storyId;

- (NSString*) displayName {
	if (story && [story title]) {
		if (wasRestored) {
			return [NSString stringWithFormat: NSLocalizedString(@"%@ (restored from %@)", @"%@ (restored from %@)"), [story title], [super displayName]];
		} else {
			return [story title];
		}
	}
	
	return [super displayName];
}

#pragma mark - Autosave

@synthesize autosaveData;

- (void) loadDefaultAutosave {
	if (autosaveData) autosaveData = nil;
	
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: storyId
																				  create: NO];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
		autosaveData = nil;
		return;
	}
	
	autosaveData = [NSData dataWithContentsOfFile: autosaveFile];
}

- (BOOL) checkResourceFile: (NSString*) file {
	return [self checkResourceURL: [NSURL fileURLWithPath: file] error: NULL];
}

- (BOOL) checkResourceURL: (NSURL*) file error: (NSError**) outError {
	BOOL exists, isDir;
	
	// Check that the file exists
	exists = urlIsAvailableAndIsDirectory(file, &isDir, NULL, NULL, outError);
	if (!exists || isDir) return NO;
	
	// Try to load it as a blorb resource file
	ZoomBlorbFile* newRes = [[ZoomBlorbFile alloc] initWithContentsOfURL: file error: outError];
	if (newRes == nil) return NO;
	
	// Set resources appropriately
	[self setResources: newRes];
	
	// Success!
	return YES;
}

- (void) findResourcesForFile: (NSString*) resFilename {
	// If we're loading a .zX game, then look for resources
	// If we're foo.zX, look in:
	//   foo.blb
	//   foo.zlb
	//   resources.blb
	// for the resources

	if (resFilename != nil) {
		NSString* resPath = [resFilename stringByDeletingLastPathComponent];
		NSString* resPrefix = [[resFilename lastPathComponent] stringByDeletingPathExtension];
		
		NSString* fileToCheck;
		
		// foo.blb
		fileToCheck = [[resPath stringByAppendingPathComponent: resPrefix] stringByAppendingPathExtension: @"blb"];
		if (![self checkResourceFile: fileToCheck]) {
			// foo.zlb
			fileToCheck = [[resPath stringByAppendingPathComponent: resPrefix] stringByAppendingPathExtension: @"zlb"];

			if (![self checkResourceFile: fileToCheck]) {
				// foo.zblorb
				fileToCheck = [[resPath stringByAppendingPathComponent: resPrefix] stringByAppendingPathExtension: @"zblorb"];
				if (![self checkResourceFile: fileToCheck]) {
					// resources.blb
					fileToCheck = [resPath stringByAppendingPathComponent: @"resources.blb"];
					[self checkResourceFile: fileToCheck];
				}
			}
		}
	}
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)wrapper
					 ofType:(NSString *)docType
					  error:(NSError * _Nullable * _Nullable)outError {
	if (![docType isEqualToString: @"public.qut"] && ![wrapper isDirectory]) {
		// Note that resources might come from elsewhere later on in the load process, too
		[self findResourcesForFile: [[self fileURL] path]];
		
		// Pass files onto the data loader
		return [self readFromData: [wrapper regularFileContents]
						   ofType: docType
							error: outError];
	}

	if (![docType isEqualToString: @"uk.org.logicalshift.zoomsave"] &&
		![docType isEqualToString: @"public.qut"]) {
		// Process only zoomSave files
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		}
		return NO;
	}
	
	BOOL isSingleFile = [docType isEqualToString: @"public.qut"];
	
	// NOTE: a future version of Zoom will add a story type identifier to the zoomSave file format, to
	// support various types of Glk games.
	
	// Read the IFhd section of the save data to find the story identifier
	NSData* quetzal = isSingleFile?[wrapper regularFileContents]:[[[wrapper fileWrappers] objectForKey: @"save.qut"] regularFileContents];
	ZoomStoryID* storyID = nil;
	
	if (quetzal == nil) {
		// Not a valid zoomSave file
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Not a valid Zoom savegame package", @"Not a valid Zoom savegame package"),
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: NSLocalizedString(@"%@ does not contain a valid 'save.qut' file", @"%@ does not contain a valid 'save.qut' file"), [[wrapper filename] lastPathComponent]]
			}];
		}
		return NO;
	}
	
	const unsigned char* bytes = [quetzal bytes];
	NSUInteger len = [quetzal length];
	NSUInteger pos = 16;
	
	while (pos < len) {
		unsigned int blockLength = (bytes[pos]<<24)  | (bytes[pos+1]<<16) | (bytes[pos+2]<<8) | bytes[pos+3];
		const unsigned char* header = (bytes + pos - 4);
		
		if (memcmp(header, "IFhd", 4) == 0) {
			if (blockLength == 13 && pos + blockLength <= len) {
				unsigned int release = (bytes[pos+4]<<8)|bytes[pos+5];
				const unsigned char* serial = bytes + pos + 6;
				unsigned int checksum = (bytes[pos+12]<<8)|bytes[pos+13];
				
				// Set up the ZoomStoryID object for this savegame
				storyID = [[ZoomStoryID alloc] initWithZcodeRelease: release
															 serial: serial
														   checksum: checksum];
			}
		}
		
		if ((blockLength&1) == 1) blockLength++;
		pos += blockLength+8;
	}
	
	if ((pos-4) > len) {
		NSString *msg;
		NSString *info;
		// Not a valid zoomSave file
		if (!isSingleFile) {
			msg = NSLocalizedString(@"Not a valid Zoom savegame package", @"Not a valid Zoom savegame package");
			info = [NSString stringWithFormat: NSLocalizedString(@"%@ does not contain a valid 'save.qut' file", @"%@ does not contain a valid 'save.qut' file"), [[wrapper filename] lastPathComponent]];
		} else {
			msg = NSLocalizedString(@"Not a valid Quetzal file", @"Not a valid Quetzal file");
			info = [NSString stringWithFormat: NSLocalizedString(@"%@ is not a valid Quetzal file", @"%@ is not a valid Quetzal file"), [[wrapper filename] lastPathComponent]];
		}
		
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSFileReadCorruptFileError
										userInfo:@{
				NSLocalizedDescriptionKey: msg,
				NSLocalizedFailureReasonErrorKey: info,
			}];
		}
		return NO;
	}
	
	// If this isn't a single file, then try retrieving the ID from the Info.plist file (if it exists)
	if (!isSingleFile) {
		NSData* plist = [[[wrapper fileWrappers] objectForKey: @"Info.plist"] regularFileContents];
		
		if (plist != nil) {
			NSDictionary* plistDict = [NSPropertyListSerialization propertyListWithData: plist
																				options: NSPropertyListImmutable
																				 format: nil
																				  error: nil];
			NSString* idString  = [plistDict objectForKey: @"ZoomStoryId"];
			if (idString != nil) {
				storyID = [[ZoomStoryID alloc] initWithIdString: idString];
			}
		}
	}
	
	// Get the game file for this save from the story organiser
	NSString* gameFile = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: storyID];
	[self findResourcesForFile: gameFile];
	
	if (gameFile == nil) {
		// Couldn't find a story for this savegame
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to find story file", @"Unable to find story file"),
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: NSLocalizedString(@"Zoom does not know where a valid story file for '%@' is and so is unable to load it", @"Zoom does not know where a valid story file for '%@' is and so is unable to load it"), [[wrapper filename] lastPathComponent]]
			}];
		}
		return NO;
	}
	
	NSError *underlying;
	NSData* data = [NSData dataWithContentsOfFile: gameFile options: 0 error: &underlying];
	if (data == nil) {
		// Couldn't find the story data for this savegame
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to find story file", @"Unable to find story file"),
				NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat: NSLocalizedString(@"Zoom is unable to load a valid story file for '%@' (tried '%@')", @"Zoom is unable to load a valid story file for '%@' (tried '%@')"), [[wrapper filename] lastPathComponent], gameFile],
				NSUnderlyingErrorKey: underlying
			}];
		}
		return NO;		
	}
	
	if (isSingleFile) {
		// No more to do
		saveData = [quetzal subdataWithRange:NSMakeRange(12, quetzal.length - 12)];

		wasRestored = YES;
		
		[self setFileURL: [NSURL fileURLWithPath: gameFile]];
		return [self readFromData: data
						   ofType: @"public.zcode"
							error: outError];
	}
	
	// Get the saved view state for this game
	NSData* savedViewArchive = [[[wrapper fileWrappers] objectForKey: @"ZoomStatus.dat"] regularFileContents];
	ZoomView* savedView = nil;
		
	if (savedViewArchive) {
//		savedView = [NSKeyedUnarchiver unarchivedObjectOfClass: [ZoomView class] fromData: savedViewArchive error: NULL];
		// Needed because some class in NSTextStorage doesn't play nice with secure coding.
		savedView = [NSKeyedUnarchiver unarchiveObjectWithData: savedViewArchive];
		if (!savedView) {
			savedView = [NSUnarchiver unarchiveObjectWithData: savedViewArchive];
		}
	}
	
	if (savedView == nil || ![savedView isKindOfClass: [ZoomView class]]) {
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to load saved screen state", @"Unable to load saved screen state"),
				NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: NSLocalizedString(@"Zoom was unable to find the saved screen state for '%@', and so is unable to start it", @"Zoom was unable to find the saved screen state for '%@', and so is unable to start it"), [[wrapper filename] lastPathComponent]]
			}];
		}
		return NO;
	}
	
	// Get the skein for this game
	NSData* skeinArchive = [[[wrapper fileWrappers] objectForKey: @"Skein.skein"] regularFileContents];
	if (skeinArchive) {
		//TODO: handle skein load failures
		[skein parseXmlData: skeinArchive error: NULL];
	}
	
	// OK, we're ready to roll!
	defaultView = savedView;
	saveData = [quetzal subdataWithRange:NSMakeRange(12, quetzal.length - 12)];
	
	// NOTE: saveData is the data minus the 'FORM' chunk - that is, valid input for state_decompile()
	// (which doesn't use this chunk)
	wasRestored = YES;
	
	[self setFileURL: [NSURL fileURLWithPath: gameFile]];
	return [self readFromData: data
					   ofType: @"public.zcode"
						error: outError];
}

@synthesize defaultView;
@synthesize saveData;
@synthesize skein;
@synthesize resources;

#pragma mark - Errors that might have happened but we recovered from

- (void) addLoadingError: (NSString*) loadingError {
	// Using this mechanism allows us to report that we couldn't find any resources (for instance) to the
	// controller, so it can display a proper error messages
	if (!loadingErrors) loadingErrors = [[NSMutableArray alloc] init];
	
	[loadingErrors addObject: [loadingError copy]];
}

- (NSArray*) loadingErrors {
	return [loadingErrors copy];
}

@end
