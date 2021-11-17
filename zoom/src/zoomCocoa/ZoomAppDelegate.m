//
//  ZoomAppDelegate.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "ZoomAppDelegate.h"
#import <ZoomPlugIns/ZoomGameInfoController.h>
#import <ZoomPlugIns/ZoomNotesController.h>
#import <ZoomView/ZoomSkeinController.h>
#import "ZoomLeopard.h"

#import <ZoomPlugIns/ZoomMetadata.h>
#import "ZoomiFictionController.h"

#import <ZoomPlugIns/ZoomPlugIn.h>
#import <ZoomPlugIns/ZoomPlugInManager.h>
#import <ZoomPlugIns/ZoomPlugInController.h>
#import "ZoomStoryOrganiser.h"
#import <ZoomView/ZoomView-Swift.h>

#import <Sparkle/Sparkle.h>

static NSString* const ZoomOpenPanelLocation = @"ZoomOpenPanelLocation";

@implementation ZoomAppDelegate

#pragma mark - Initialisation
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
		NSURL *configURL = [NSURL fileURLWithPath: configDir];

		// Load the metadata
		NSURL* userDataURL = [configURL URLByAppendingPathComponent: @"metadata.iFiction" isDirectory: NO];
		NSURL* gameDataURL = [configURL URLByAppendingPathComponent: @"gamedata.iFiction" isDirectory: NO];
		NSData* infocomData = [NSData dataWithContentsOfURL: [[NSBundle mainBundle] URLForResource: @"infocom" withExtension: @"iFiction"]];
		NSData* archiveData = [NSData dataWithContentsOfURL: [[NSBundle mainBundle] URLForResource: @"archive" withExtension: @"iFiction"]];
		if (![userDataURL checkResourceIsReachableAndReturnError: NULL]) {
			userDataURL = nil;
		}
		if (![gameDataURL checkResourceIsReachableAndReturnError: NULL]) {
			gameDataURL = nil;
		}

		if (userDataURL)
			[gameIndices addObject: [[ZoomMetadata alloc] initWithContentsOfURL: userDataURL error: NULL]];
		else
			[gameIndices addObject: [[ZoomMetadata alloc] init]];

		if (gameDataURL)
			[gameIndices addObject: [[ZoomMetadata alloc] initWithContentsOfURL: gameDataURL error: NULL]];
		else
			[gameIndices addObject: [[ZoomMetadata alloc] init]];
		
		if (infocomData)
			[gameIndices addObject: [[ZoomMetadata alloc] initWithData: infocomData error: NULL]];
		if (archiveData)
			[gameIndices addObject: [[ZoomMetadata alloc] initWithData: archiveData error: NULL]];
	}
	
	return self;
}

#pragma mark - Opening files

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
										   withIntermediateDirectories:NO
															attributes: nil
																 error:NULL]) {
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
	NSURL *fileURL = [NSURL fileURLWithPath: filename];
	// Just show the existing document if it already exists
	NSDocument* existingDocument = [[NSDocumentController sharedDocumentController] documentForURL: fileURL];
	if (existingDocument && [[existingDocument windowControllers] count] > 0) {
		[[[existingDocument windowControllers] objectAtIndex: 0] showWindow: self];
		return YES;
	}
	
	if (existingDocument) {
		NSLog(@"WARNING: found a leaked document for '%@'", filename);
	}
	
	// If this is a .signpost file, then pass it to the ifiction window
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"signpost"]) {
		[[ZoomiFictionController sharediFictionController] openSignPost: [NSData dataWithContentsOfURL: fileURL]
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
			fileProperties = [NSPropertyListSerialization propertyListWithData: [NSData dataWithContentsOfFile: propertyListPath]
															  options: NSPropertyListImmutable
																		format: nil
															  error: nil];
		}
		
		// Retrieve the story identifier
		ZoomStoryID* ident = nil;
		NSString* identString = [fileProperties objectForKey: @"ZoomGlkGameId"];
		
		if (identString) {
			ident = [[ZoomStoryID alloc] initWithIdString: identString];
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
	Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForURL: fileURL];
	
	if (pluginClass) {
		ZoomPlugIn* pluginInstance = [[pluginClass alloc] initWithURL: fileURL];
		
		if (pluginInstance) {
			// Register this game with iFiction
			ZoomStoryID* ident = [pluginInstance idForStory];
			ZoomStory* story = nil;
				
			if (ident != nil) {
				story = [self findStory: ident];
				if (story == nil) {
					story = [pluginInstance defaultMetadataWithError: NULL];
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
			NSString *fileStr = [self saveDirectoryForStoryId: ident];
			[pluginInstance setPreferredSaveDirectoryURL: fileStr ? [NSURL fileURLWithPath: fileStr] : nil];
			NSDocument* pluginDocument;
			
			if (saveFilename) {
				pluginDocument = [pluginInstance gameDocumentWithMetadata: story
															  saveGameURL: [NSURL fileURLWithPath: saveFilename]];
				[pluginDocument setFileURL: fileURL];
			} else {
				pluginDocument = [pluginInstance gameDocumentWithMetadata: story];
				[pluginDocument setFileURL: fileURL];
			}
			
			[[NSDocumentController sharedDocumentController] addDocument: pluginDocument];
			[pluginDocument makeWindowControllers];
			[pluginDocument showWindows];
			
			return YES;
		}
	}

	// See if there's a built-in document handler for this file type (basically, this means z-code files)
	// TODO: we should probably do this with a plug-in now
	if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL: fileURL
																			   display: YES
																				 error: NULL]) {
		return YES;
	}
	
	if ([[[filename pathExtension] lowercaseString] isEqualToString: @"ifiction"]) {
		// Load extra iFiction data (not a 'real' file in that it's displayed in the iFiction window)
		[[ZoomiFictionController sharediFictionController] mergeiFictionFromURL: fileURL
																		  error: NULL];
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
	// init the story organizer.
	[ZoomStoryOrganiser sharedStoryOrganiser];
	// See if there's a startup signpost file
	NSString* startupSignpost = [[(ZoomAppDelegate*)[NSApp delegate] zoomConfigDirectory] stringByAppendingPathComponent: @"launch.signpost"];
	BOOL isDir;

	if ([[NSFileManager defaultManager] fileExistsAtPath: startupSignpost
											 isDirectory: &isDir]) {
		// Do nothing if it's a directory
		if (isDir) return;
		
		// Read the file
		NSData* startupSignpostData = [NSData dataWithContentsOfFile: startupSignpost];
		
		// Delete it
		[[NSFileManager defaultManager] removeItemAtPath: startupSignpost
												   error: NULL];
		
		// Get the iFiction control to handle it
		[[ZoomiFictionController sharediFictionController] openSignPost: startupSignpostData
														  forceDownload: YES];
	}
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {
#ifdef DEVELOPMENTBUILD
	// Tell launch services to re-register the application (ensures that all the icons are always up to date)
	NSLog(@"Re-registering");
	LSRegisterURL((CFURLRef)[[NSBundle mainBundle] bundleURL], 1);
#else
	/*
	NSLog(@"Re-registering");
	LSRegisterURL((CFURLRef)[NSURL fileURLWithPath: [[NSBundle mainBundle] bundlePath]], 1);
	 */
#endif
	
	// Load the leopard extensions if we're running on the right version of OS X
    leopard = [[ZoomLeopard alloc] init];
	
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
		
		NSDate* nextCheck = [lastCheck dateByAddingTimeInterval: oneWeek];
		if (!lastCheck || [nextCheck compare: now] == NSOrderedAscending) {
			[[ZoomPlugInController sharedPlugInController] checkForUpdates: self];
		} else if (nextCheck) {
			NSLog(@"Zoom will next check for plugin updates on %@", nextCheck);
		}
	}
}

@synthesize leopard;

#pragma mark - General actions
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

#pragma mark - Application-wide data

- (NSArray*) gameIndices {
	return [gameIndices copy];
}

- (ZoomStory*) findStory: (ZoomStoryID*) gameID {
	for (ZoomMetadata* repository in gameIndices) {
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
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);

	for (NSString* libDir in libraryDirs) {
		BOOL isDir;
		
		NSString* zoomLib = [libDir stringByAppendingPathComponent: @"Zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	for (NSString* libDir in libraryDirs) {
		NSString* zoomLib = [libDir stringByAppendingPathComponent: @"Zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
									  withIntermediateDirectories: NO
													   attributes: nil
															error: NULL]) {
			return zoomLib;
		}
	}
	
	return nil;
}

- (IBAction) fixedOpenDocument: (id) sender {
	// The standard open dialog does not go through the applicationOpenFile: mechanism, or know about plugins.
	// This version does.
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	
	NSURL* directory = [[NSUserDefaults standardUserDefaults] URLForKey: ZoomOpenPanelLocation];
	if (directory == nil) {
		directory = [NSURL fileURLWithPath: NSHomeDirectory()];
	}
	
	// Set up the open panel
	[openPanel setDelegate: self];
	[openPanel setCanChooseFiles: YES];
	[openPanel setResolvesAliases: YES];
	[openPanel setTitle: NSLocalizedString(@"Open Story", @"Open Story")];
	[openPanel setDirectoryURL: directory];
	[openPanel setAllowsMultipleSelection: YES];
	
	// Run the panel
	NSInteger result = [openPanel runModal];
	if (result != NSModalResponseOK) return;
	
	// Remember the directory
	[[NSUserDefaults standardUserDefaults] setURL: [openPanel directoryURL]
										   forKey: ZoomOpenPanelLocation];
	
	// Open the file(s)
	NSArray* files = [openPanel URLs];
	for (NSURL *fileURL in files) {
		[self application: NSApp
				 openFile: fileURL.path];
	}
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	BOOL exists;
	BOOL isDirectory;
	BOOL isPackage;
	BOOL isReadable;
	
	exists = urlIsAvailableAndIsDirectory(url, &isDirectory, &isPackage, &isReadable, NULL);
	if (!exists) return NO;
	
	// Show directories that are not packages
	if (isDirectory) {
		if (isPackage) {
			return NO;
		} else {
			return YES;
		}
	}
	
	// Don't show non-readable files
	if (!isReadable) {
		return NO;
	}
	
	// Show files that have a valid plugin
	Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForURL: url];
	
	if (pluginClass != nil) {
		return YES;
	}
	NSString *urlUTI;
	if (![url getResourceValue:&urlUTI forKey:NSURLTypeIdentifierKey error:NULL]) {
		urlUTI = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)url.pathExtension, isDirectory ? kUTTypeDirectory : kUTTypeData));
	}
	
	// Show files that we can open with the ZoomClient document type
	NSString* type = @"public.zcode";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb.zcode";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb.glulx";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb";
	if ([urlUTI isEqualToString:type]) return YES;
	
	return NO;
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError * _Nullable *)outError {
	if (![self panel: sender shouldEnableURL: url]) {
		return NO;
	}
	
	BOOL exists;
	BOOL isDirectory;

	exists = urlIsAvailableAndIsDirectory(url, &isDirectory, NULL, NULL, NULL);
	
	if (!exists) return NO;
	if (isDirectory) return NO;
	
	return YES;
}

#pragma mark - Validation

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
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

#pragma mark - Saving skeins, transcripts, etc

- (IBAction) saveTranscript: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	panel.allowedFileTypes = @[(NSString*)kUTTypePlainText];

	NSURL* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] URLForKey: ZoomSkeinTranscriptURLDefaultsKey];
	}
	if (directory == nil) {
		directory = [NSURL fileURLWithPath:NSHomeDirectory()];
	}
	
	panel.directoryURL = directory;
	NSString *data = [[[ZoomSkeinController sharedSkeinController] skein] transcriptToPoint: nil];
	
	[panel beginSheetModalForWindow: [NSApp mainWindow] completionHandler: ^(NSModalResponse result) {
		[self saveTranscript: panel returnCode: result stringData: data];
	}];
}

- (IBAction) copyTranscript: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
	
	[pasteboard clearContents];
	[pasteboard declareTypes: @[NSPasteboardTypeString]
					   owner: self];
	[pasteboard setString: [[[ZoomSkeinController sharedSkeinController] skein] transcriptToPoint: nil] 
				  forType: NSPasteboardTypeString];
}

- (IBAction) saveRecording: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	panel.allowedFileTypes = @[(NSString*)kUTTypePlainText];

	NSURL* directoryURL = nil;
	if (directoryURL == nil) {
		directoryURL = [[NSUserDefaults standardUserDefaults] URLForKey: ZoomSkeinTranscriptURLDefaultsKey];
	}
	if (directoryURL == nil) {
		directoryURL = [NSURL fileURLWithPath:NSHomeDirectory()];
	}
	
	panel.directoryURL = directoryURL;
	NSString *saveData = [[[ZoomSkeinController sharedSkeinController] skein] recordingToPoint: nil];
	
	[panel beginSheetModalForWindow: [NSApp mainWindow] completionHandler: ^(NSModalResponse result) {
		[self saveTranscript: panel returnCode: result stringData: saveData];
	}];
}

- (IBAction) saveSkein: (id) sender {
	if ([NSApp mainWindow] == nil) return;
	if ([[ZoomSkeinController sharedSkeinController] skein] == nil) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	panel.allowedFileTypes = @[@"skein"];
	
	NSURL* directory = nil;
	if (directory == nil) {
		directory = [[NSUserDefaults standardUserDefaults] URLForKey: ZoomSkeinTranscriptURLDefaultsKey];
	}
	if (directory == nil) {
		directory = [NSURL fileURLWithPath: NSHomeDirectory()];
	}
	
	ZoomSkein* skein = [[ZoomSkeinController sharedSkeinController] skein];
	NSString* xml = [skein xmlData];
	panel.directoryURL = directory;
	
	[panel beginSheetModalForWindow: [NSApp mainWindow] completionHandler: ^(NSModalResponse result) {
		[self saveTranscript: panel returnCode: result stringData: xml];
	}];
}

- (void) saveTranscript: (NSSavePanel *) panel 
             returnCode: (NSModalResponse) returnCode
			 stringData: (NSString*) data {
	if (returnCode != NSModalResponseOK) {
		return;
	}
	
	// Remember the directory we last saved in
	[[NSUserDefaults standardUserDefaults] setURL: [panel directoryURL]
										   forKey: ZoomSkeinTranscriptURLDefaultsKey];
	
	// Save the data
	NSData* charData = [data dataUsingEncoding: NSUTF8StringEncoding];
	[charData writeToURL: [panel URL]
			  atomically: YES];
}

- (IBAction) showPluginManager: (id) sender {
	[[ZoomPlugInController sharedPlugInController] showWindow: self];
}

#pragma mark - Check for updates

- (IBAction) checkForUpdates: (id) sender {
	[updater checkForUpdates: self];
	[[ZoomPlugInController sharedPlugInController] checkForUpdates: self];
}

@end

BOOL urlIsAvailableAndIsDirectory(NSURL *url, BOOL *isDirectory, BOOL *isPackage, BOOL *isReadable, NSError **error) {
	if (![url checkResourceIsReachableAndReturnError: error]) {
		return NO;
	}
	if (isDirectory) {
		NSNumber *dirNum;
		[url getResourceValue: &dirNum forKey: NSURLIsDirectoryKey error: NULL];
		*isDirectory = dirNum.boolValue;
	}
	if (isPackage) {
		NSNumber *dirNum;
		[url getResourceValue: &dirNum forKey: NSURLIsPackageKey error: NULL];
		*isPackage = dirNum.boolValue;
	}
	if (isReadable) {
		NSNumber *dirNum;
		[url getResourceValue: &dirNum forKey: NSURLIsReadableKey error: NULL];
		*isReadable = dirNum.boolValue;
	}
	
	return YES;
}
