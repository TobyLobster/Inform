//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "ZoomAppDelegate.h"
#import "ZoomGameInfoController.h"
#import "ZoomNotesController.h"
#import "ZoomSkeinController.h"

#import "ZoomMetadata.h"
#import "ZoomiFictionController.h"

#import "ZoomPlugIn.h"
#import "ZoomPlugInManager.h"
#import "ZoomPlugInController.h"
#import "ZoomStoryOrganiser.h"

#import <Sparkle/Sparkle.h>

NSString* ZoomOpenPanelLocation = @"ZoomOpenPanelLocation";

@implementation ZoomAppDelegate

// = Initialisation =
+ (void) initialization {
	
}

- (id) init {
	self = [super init];
	
	if (self) {
		// Ensure the plugins are available
		[[ZoomPlugInManager sharedPlugInManager] finishUpdatingPlugins];
		
		NSLog(@"= Loading plugins");
		[[ZoomPlugInManager sharedPlugInManager] loadPlugIns];
		
		gameIndices = [[NSMutableArray alloc] init];

		NSString* configDir = [self zoomConfigDirectory];

		// Load the metadata
		NSData* userData = [NSData dataWithContentsOfFile: [configDir stringByAppendingPathComponent: @"metadata.iFiction"]];
		NSData* gameData = [NSData dataWithContentsOfFile: [configDir stringByAppendingPathComponent: @"gamedata.iFiction"]];
		NSData* infocomData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"infocom" ofType: @"iFiction"]];
		NSData* archiveData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"archive" ofType: @"iFiction"]];
		
		if (userData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: userData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];

		if (gameData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: gameData] autorelease]];
		else
			[gameIndices addObject: [[[ZoomMetadata alloc] init] autorelease]];
		
		if (infocomData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: infocomData] autorelease]];
		if (archiveData) 
			[gameIndices addObject: [[[ZoomMetadata alloc] initWithData: archiveData] autorelease]];
	}
	
	return self;
}

- (void) dealloc {
	if (preferencePanel) [preferencePanel release];
	[gameIndices release];
	
	[super dealloc];
}

// = Opening files =

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
	// 'Opening an untitled file' is an action that occurs when the user clicks on the 'Z' icon...
    return YES;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)theApplication {
	// ... which we want to have the effect of showing the iFiction window
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
	
	return YES;
}

- (NSString*) saveDirectoryForStoryId: (ZoomStoryID*) storyId {
	ZoomPreferences* prefs = [ZoomPreferences globalPreferences];
	
	if ([prefs keepGamesOrganised]) {
		// Get the directory for this game
		NSString* gameDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: storyId
																				  create: YES];
		NSString* saveDir = [gameDir stringByAppendingPathComponent: @"Saves"];
		
		BOOL isDir = NO;
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: saveDir
												  isDirectory: &isDir]) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath: saveDir
															attributes: nil]) {
				// Couldn't create the directory
				return nil;
			}
			
			isDir = YES;
		} else {
			if (!isDir) {
				// Some inconsiderate person stuck a file here
				return nil;
			}
		}
		
		return saveDir;
	}	
	
	return nil;
}

- (BOOL)application: (NSApplication *)theApplication 
		   openFile: (NSString *)filename {
	// Just show the existing document if it already exists
	NSDocument* existingDocument = [[NSDocumentController sharedDocumentController] documentForFileName: filename];
	if (existingDocument && [[existingDocument windowControllers] count] > 0) {
		[[[existingDocument windowControllers] objectAtIndex: 0] showWindow: self];
		return YES;
	}
	
	if (existingDocument) {
		NSLog(@"WARNING: found a leaked document for '%@'", filename);
	}
	
	// If this is a .signpost file, then pass it to the ifiction window
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"signpost"]) {
		[[ZoomiFictionController sharediFictionController] openSignPost: [NSData dataWithContentsOfFile: filename]
														  forceDownload: NO];
		return YES;
	}
	
	// If this is a .zoomplugin file, then install it
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"zoomplugin"]) {
		if ([[ZoomPlugInManager sharedPlugInManager] installPlugIn: filename]) {
			[[ZoomPlugInController sharedPlugInController] showWindow: self];
			if ([[ZoomPlugInManager sharedPlugInManager] restartRequired]) {
				[[ZoomPlugInController sharedPlugInController] needsRestart];
			}
		}
		return YES;
	}

	// If this is a .glksave file, then set up to load the saved story instead
	NSString* saveFilename = nil;
	
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"glksave"]) {
		// Try to load the property list from the package
		NSString* propertyListPath = [filename stringByAppendingPathComponent: @"Info.plist"];
		NSDictionary* fileProperties = nil;
		if ([[NSFileManager defaultManager] fileExistsAtPath: propertyListPath]) {
			fileProperties = [NSPropertyListSerialization propertyListFromData: [NSData dataWithContentsOfFile: propertyListPath]
															  mutabilityOption: NSPropertyListImmutable
																		format: nil
															  errorDescription: nil];
		}
		
		// Retrieve the story identifier
		ZoomStoryID* ident = nil;
		NSString* identString = [fileProperties objectForKey: @"ZoomGlkGameId"];
		
		if (identString) {
			ident = [[ZoomStoryID alloc] initWithIdString: identString];
			[ident autorelease];
		}
		
		// Try to get the filename of the game file that owns this story
		saveFilename = filename;
		filename = nil;
		if (ident) {
			filename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: ident];
		}
	}
	
	if (filename == nil) {
		// TODO: report that we couldn't load this file
		return NO;
	}

	// See if there's a plug-in that can handle this file. This gives plug-ins first shot at handling blorb files.
	Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: filename];
	
	if (pluginClass) {
		// TODO: work out when to release this class
		ZoomPlugIn* pluginInstance = [[pluginClass alloc] initWithFilename: filename];
		
		if (pluginInstance) {
			// Register this game with iFiction
			ZoomStoryID* ident = [pluginInstance idForStory];
			ZoomStory* story = nil;
				
			if (ident != nil) {
				story = [self findStory: ident];
				if (story == nil) {
					story = [pluginInstance defaultMetadata];
					if (story != nil) {
						[[self userMetadata] copyStory: story
												  toId: ident];
					}
				}
				
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: ident
														   organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]];					
				filename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: ident];
			}
			
			// ... we've managed to load this file with the given plug-in, so display it
			[pluginInstance setPreferredSaveDirectory: [self saveDirectoryForStoryId: ident]];
			NSDocument* pluginDocument;
			
			if (saveFilename) {
				pluginDocument = [pluginInstance gameDocumentWithMetadata: story
																 saveGame: saveFilename];
				[pluginDocument setFileName: saveFilename];
			} else {
				pluginDocument = [pluginInstance gameDocumentWithMetadata: story];
				[pluginDocument setFileName: filename];
			}
			
			[[NSDocumentController sharedDocumentController] addDocument: pluginDocument];
			[pluginDocument makeWindowControllers];
			[pluginDocument showWindows];
			
			[pluginInstance autorelease];
			
			return YES;
		}
	}

	// See if there's a built-in document handler for this file type (basically, this means z-code files)
	// TODO: we should probably do this with a plug-in now
	if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																				display: YES]) {
		return YES;
	}
	
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"ifiction"]) {
		// Load extra iFiction data (not a 'real' file in that it's displayed in the iFiction window)
		[[ZoomiFictionController sharediFictionController] mergeiFictionFromFile: filename];
		return YES;
	}
		
	return NO;
}

- (void) applicationWillTerminate: (NSNotification*) not {
	// Make sure that the plugin manager is finalised
	[[ZoomPlugInManager sharedPlugInManager] finishedWithObject];
	[ZoomDownload removeTemporaryDirectory];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// See if there's a startup signpost file
	NSString* startupSignpost = [[[NSApp delegate] zoomConfigDirectory] stringByAppendingPathComponent: @"launch.signpost"];
	BOOL isDir;

	if ([[NSFileManager defaultManager] fileExistsAtPath: startupSignpost
											 isDirectory: &isDir]) {
		// Do nothing if it's a directory
		if (isDir) return;
		
		// Read the file
		NSData* startupSignpostData = [NSData dataWithContentsOfFile: startupSignpost];
		
		// Delete it
		[[NSFileManager defaultManager] removeFileAtPath: startupSignpost
												 handler: nil];
		
		// Get the iFiction control to handle it
		[[ZoomiFictionController sharediFictionController] openSignPost: startupSignpostData
														  forceDownload: YES];
	}
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
#ifdef DEVELOPMENTBUILD
	// Tell launch services to re-register the application (ensures that all the icons are always up to date)
	NSLog(@"Re-registering");
	LSRegisterURL((CFURLRef)[NSURL fileURLWithPath: [[NSBundle mainBundle] bundlePath]], 1);
#else
	/*
	NSLog(@"Re-registering");
	LSRegisterURL((CFURLRef)[NSURL fileURLWithPath: [[NSBundle mainBundle] bundlePath]], 1);
	 */
#endif
	
	// Load the leopard extensions if we're running on the right version of OS X
	if (NSAppKitVersionNumber >= 949) {
		NSBundle* leopardBundle = [NSBundle bundleWithPath: [[NSBundle mainBundle] pathForAuxiliaryExecutable: @"LeopardExtns.bundle"]];
		[leopardBundle load];
		leopard = [[[leopardBundle principalClass] alloc] init];
	}
	
	// Ensure the shared plugin controller is created
	[ZoomPlugInController sharedPlugInController];
	
	// Force a check for update if check for updates is turned on and it's been more than a week since we last
	// checked (or if we've never checked)
	BOOL checkForUpdates = NO;
	
	NSNumber* checkForUpdatesDefault = [[NSUserDefaults standardUserDefaults] valueForKey: @"SUCheckAtStartup"];
	if (checkForUpdatesDefault && [checkForUpdatesDefault isKindOfClass: [NSNumber class]]) {
		checkForUpdates = [checkForUpdatesDefault boolValue];
	}
	
	if (checkForUpdates) {
		NSTimeInterval oneWeek = 60*60*24*7;
		
		NSDate* now = [NSDate date];
		NSDate* lastCheck = nil;
		lastCheck = [[NSUserDefaults standardUserDefaults] valueForKey: @"ZoomLastPluginCheck"];
		if (lastCheck && ![lastCheck isKindOfClass: [NSDate class]]) lastCheck = nil;
		
		NSDate* nextCheck = [lastCheck addTimeInterval: oneWeek];
		if (!lastCheck || [nextCheck compare: now] == NSOrderedAscending) {
			[[ZoomPlugInController sharedPlugInController] checkForUpdates: self];
		} else if (nextCheck) {
			NSLog(@"Zoom will next check for plugin updates on %@", nextCheck);
		}
	}
}

- (id<ZoomLeopard>) leopard {
	return leopard;
}

// = General actions =
- (IBAction) showPreferences: (id) sender {
	if (!preferencePanel) {
		preferencePanel = [[ZoomPreferenceWindow alloc] init];
	}
	
	[[preferencePanel window] center];
	[preferencePanel setPreferences: [ZoomPreferences globalPreferences]];
	[[preferencePanel window] makeKeyAndOrderFront: self];
}

- (IBAction) displayGameInfoWindow: (id) sender {
	[[ZoomGameInfoController sharedGameInfoController] showWindow: self];
	
	// Blank out the game info window
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == nil) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
	}
}

- (IBAction) displaySkein: (id) sender {
	[[ZoomSkeinController sharedSkeinController] showWindow: self];

	[NSApp sendAction: @selector(updateSkein:)
				   to: nil
				 from: self];
}

- (IBAction) displayNoteWindow: (id) sender {
	[[ZoomNotesController sharedNotesController] showWindow: self];
}

- (IBAction) showiFiction: (id) sender {
	[[[ZoomiFictionController sharediFictionController] window] makeKeyAndOrderFront: self];
}

// = Application-wide data =

- (NSArray*) gameIndices {
	return gameIndices;
}

- (ZoomStory*) findStory: (ZoomStoryID*) gameID {
	NSEnumerator* indexEnum = [gameIndices objectEnumerator];
	ZoomMetadata* repository;
	
	while (repository = [indexEnum nextObject]) {
		if (![repository containsStoryWithIdent: gameID]) continue;
		
		ZoomStory* res = [repository findOrCreateStory: gameID];
		return res;
	}
	
	return nil;
}

- (ZoomMetadata*) userMetadata {
	return [gameIndices objectAtIndex: 0];
}

- (NSString*) zoomConfigDirectory {
	// The app delegate may not be the best place for this routine... Maybe a function somewhere
	// would be better?
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	NSEnumerator* libEnum;
	NSString* libDir;

	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		BOOL isDir;
		
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	libEnum = [libraryDirs objectEnumerator];
	
	while (libDir = [libEnum nextObject]) {
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
													   attributes:nil]) {
			return zoomLib;
		}
	}
	
	return nil;
}

- (IBAction) fixedOpenDocument: (id) sender {
	// The standard open dialog does not go through the applicationOpenFile: mechanism, or know about plugins.
	// This version does.
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	
	NSString* directory = [[NSUserDefaults standardUserDefaults] objectForKey: ZoomOpenPanelLocation];
	if (directory == nil) {
		directory = [@"~" stringByStandardizingPath];
	} else {
		directory = [directory stringByStandardizingPath];
	}
	
	// Set up the open panel
	[openPanel setDelegate: self];
	[openPanel setCanChooseFiles: YES];
	[openPanel setResolvesAliases: YES];
	[openPanel setTitle: @"Open Story"];
	[openPanel setDirectory: directory];
	[openPanel setAllowsMultipleSelection: YES];
	
	// Run the panel
	int result = [openPanel runModal];
	if (result != NSFileHandlingPanelOKButton) return;
	
	// Remember the directory
	[[NSUserDefaults standardUserDefaults] setObject: [openPanel directory]
											  forKey: ZoomOpenPanelLocation];
	
	// Open the file(s)
	NSArray* files = [openPanel filenames];
	NSEnumerator* fileEnum = [files objectEnumerator];
	NSString* file;
	while (file = [fileEnum nextObject]) {
		[self application: NSApp
				 openFile: file];
	}
}

- (BOOL)		panel:(id)sender 
   shouldShowFilename:(NSString *)filename {
	BOOL exists;
	BOOL isDirectory;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
												  isDirectory: &isDirectory];
	if (!exists) return NO;
	
	// Show directories that are not packages
	if (isDirectory) {
		if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename]) {
			return NO;
		} else {
			return YES;
		}
	}
	
	// Don't show non-readable files
	if (![[NSFileManager defaultManager] isReadableFileAtPath: filename]) {
		return NO;
	}
	
	// Show files that have a valid plugin
	Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: filename];
	
	if (pluginClass != nil) {
		return YES;
	}
	
	// Show files that we can open with the ZoomClient document type
	NSArray* extensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType: @"ZCode story"];
	NSEnumerator* extnEnum = [extensions objectEnumerator];
	NSString* extn;
	NSString* fileExtension = [[filename pathExtension] lowercaseString];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}

	extensions = [NSArray arrayWithObjects: @"zblorb", @"zlb", nil];
	extnEnum = [extensions objectEnumerator];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}
	
	extensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType: @"Blorb resource file"];
	extnEnum = [extensions objectEnumerator];
	while (extn = [extnEnum nextObject]) {
		if ([extn isEqualToString: fileExtension]) return YES;
	}
	
	return NO;
}

- (BOOL)        panel:(id)sender
	  isValidFilename:(NSString *)filename {
	if (![self panel: sender shouldShowFilename: filename]) return NO; 

	BOOL exists;
	BOOL isDirectory;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
												  isDirectory: &isDirectory];
	
	if (!exists) return NO;
	if (isDirectory) return NO;
	
	return YES;
}

// = Validation =

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem {
	SEL sel = [menuItem action];
	
	if (sel == @selector(saveTranscript:)
		|| sel == @selector(saveSkein:)
		|| sel == @selector(saveRecording:)
		|| sel == @selector(copyTranscript:)) {
		if ([NSApp mainWindow] == nil) return NO;
		return [[ZoomSkeinController sharedSkeinController] skein] != nil;
	}
	
	return YES;
}

// = Saving skeins, transcripts, etc =

- (IBAction) saveTranscript: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setRequiredFileType: @"txt"];

	NSString* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomTranscriptPath"];
	}
	if (directory == nil) {
		directory = NSHomeDirectory();
	}
	
    [panel beginSheetForDirectory: directory
                             file: nil
                   modalForWindow: [NSApp mainWindow]
                    modalDelegate: self
                   didEndSelector: @selector(saveTranscript:returnCode:contextInfo:) 
                      contextInfo: [[[[ZoomSkeinController sharedSkeinController] skein] transcriptToPoint: nil] retain]];
}

- (IBAction) copyTranscript: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	
	[pasteboard declareTypes: [NSArray arrayWithObjects: NSStringPboardType, nil]
					   owner: self];
	[pasteboard setString: [[[ZoomSkeinController sharedSkeinController] skein] transcriptToPoint: nil] 
				  forType: NSStringPboardType];
}

- (IBAction) saveRecording: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setRequiredFileType: @"txt"];
	
	NSString* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomTranscriptPath"];
	}
	if (directory == nil) {
		directory = NSHomeDirectory();
	}
	
    [panel beginSheetForDirectory: directory
                             file: nil
                   modalForWindow: [NSApp mainWindow]
                    modalDelegate: self
                   didEndSelector: @selector(saveTranscript:returnCode:contextInfo:) 
                      contextInfo: [[[[ZoomSkeinController sharedSkeinController] skein] recordingToPoint: nil] retain]];
}

- (IBAction) saveSkein: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setRequiredFileType: @"skein"];
	
	NSString* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomTranscriptPath"];
	}
	if (directory == nil) {
		directory = NSHomeDirectory();
	}
	
	ZoomSkein* skein = [[ZoomSkeinController sharedSkeinController] skein];
	NSString* xml = [skein xmlData];
	
    [panel beginSheetForDirectory: directory
                             file: nil
                   modalForWindow: [NSApp mainWindow]
                    modalDelegate: self
                   didEndSelector: @selector(saveTranscript:returnCode:contextInfo:) 
                      contextInfo: [xml retain]];
}

- (void) saveTranscript: (NSSavePanel *) panel 
             returnCode: (int) returnCode 
            contextInfo: (void*) contextInfo {
	NSString* data = (NSString*)contextInfo;
	[data autorelease];

	if (returnCode != NSOKButton) return;
	
	// Remember the directory we last saved in
	[[NSUserDefaults standardUserDefaults] setObject: [panel directory]
											  forKey: @"ZoomTranscriptPath"];
	
	// Save the data
	NSData* charData = [data dataUsingEncoding: NSUTF8StringEncoding];
	[charData writeToFile: [panel filename]
			   atomically: YES];
}

- (IBAction) showPluginManager: (id) sender {
	[[ZoomPlugInController sharedPlugInController] showWindow: self];
}

// = Check for updates =

- (IBAction) checkForUpdates: (id) sender {
	[updater checkForUpdates: self];
	[[ZoomPlugInController sharedPlugInController] checkForUpdates: self];
}

@end
