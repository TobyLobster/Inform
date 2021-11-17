//
//  ZoomClientController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Incorporates changes contributed by Collin Pieper

#import "ZoomClientController.h"
#import "ZoomPreferenceWindow.h"
#import <ZoomPlugIns/ZoomGameInfoController.h>
#import <ZoomPlugIns/ZoomNotesController.h>
#import "ZoomStoryOrganiser.h"
#import <ZoomView/ZoomSkeinController.h>
#import <ZoomView/ZoomConnector.h>
#import <ZoomPlugIns/ZoomWindowThatCanBecomeKey.h>
#import "ZoomAppDelegate.h"
@import ZoomPlugIns.Swift;
@import ZoomView.Swift;
#import "Zoom-Swift.h"

@implementation ZoomClientController
@synthesize zoomView;

- (id) init {
    self = [super initWithWindowNibName: @"ZoomClient"];

    if (self) {
        [self setShouldCloseDocument: YES];
		isFullscreen = NO;
		finished = NO;
		closeConfirmed = NO;
    }

    return self;
}

- (void) dealloc {
    if (zoomView) [zoomView setDelegate: nil];
    if (zoomView) [zoomView killTask];
	
	if (fadeTimer) {
		[fadeTimer invalidate];
	}
}

- (void) windowDidLoad {
	if ([[self document] defaultView] != nil) {
		// Replace the view
		NSRect viewFrame = [zoomView frame];
		NSView* superview = [zoomView superview];
		
		[zoomView removeFromSuperview];
		//[zoomView release];
		zoomView = [(ZoomClient*)[self document] defaultView];
		
		[superview addSubview: zoomView];
		[zoomView setFrame: viewFrame];
		[zoomView setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
	}
	
	[self setWindowFrameAutosaveName: @"ZoomClientWindow"];

	[[self window] setAlphaValue: 0.9999];
    
	[zoomView setDelegate: self];
    [zoomView runNewServer: nil];
	
	// Add a skein view as an output receiver for the ZoomView
	[zoomView addOutputReceiver: [[self document] skein]];
	[self showLogoWindow];
	
	shownOnce = NO;
}

- (void) showWindow: (id) sender {
	[super showWindow: sender];
	
	if (!shownOnce) {
		// Display any errors that happened while loading
		if ([[[self document] loadingErrors] count] > 0) {
			// Combine them all into one huge error
			NSMutableString* errorText = [NSMutableString string];
			
			BOOL newline = NO;
			
			for (NSString* error in [[self document] loadingErrors]) {
				if (newline) [errorText appendString: @"\n\n"];
				[errorText appendString: error];
				newline = YES;
			}
			
			// Show an alert			
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString(@"Problems were encountered while loading this game", @"Problems were encountered while loading this game");
			alert.informativeText = errorText;
			[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"Continue")];
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			}];
		}
	}
	
	[self showLogoWindow];
	shownOnce = YES;
}

- (IBAction) reloadGame: (id) sender {
	// Get the file we're going to re-open
	NSString* filename = [(NSDocument*)[self document] fileURL].path;
	
	// Close ourselves down
	[[self document] close];
	
	// Reload the story
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL: [NSURL fileURLWithPath:filename] display: YES completionHandler: ^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
		//Do nothing
	}];
	
	// Done: now we can die happy
}

- (IBAction) restartZMachine: (id) sender {
	// Request from (eg) a menu item
	[zoomView runNewServer: nil];
}

- (void) zMachineStarted: (id) sender {
	// A new Z-Machine has started (ZoomView delegate method)
	[[self window] setDocumentEdited: [[ZoomPreferences globalPreferences] confirmGameClose]?YES:NO];
	
	finished = NO;
	[self synchronizeWindowTitleWithDocumentName];
	
	[zoomView setResources: [[self document] resources]];
    [[zoomView zMachine] loadStoryFile: [[self document] gameData]];
	
	if ([[self document] autosaveData] != nil) {
		NSCoder* decoder;
		
		decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData: [[self document] autosaveData] error: NULL];
		if (!decoder) {
			decoder = [[NSUnarchiver alloc] initForReadingWithData: [[self document] autosaveData]];
		}
		
		[zoomView restoreAutosaveFromCoder: decoder];
		
		[[self document] setAutosaveData: nil];
	}
	
	if ([[self document] defaultView] != nil && [[self document] saveData] != nil) {
		// Restore the save data
		[[(ZoomClient*)[self document] defaultView] restoreSaveState: [[self document] saveData]];
		[[self document] setSaveData: nil];
	} else if ([[self document] saveData] != nil) {
		// Restore the save data without restoring the view
		[zoomView restoreSaveState: [[self document] saveData]];
		[[self document] setSaveData: nil];
	}
}

- (void) zMachineFinished: (id) sender {
	// The z-machine has terminated (ZoomView delegate method)
	[[self window] setDocumentEdited: NO];

	finished = YES;
	[self synchronizeWindowTitleWithDocumentName];
	
	if (isFullscreen) [self playInFullScreen: self];
}

- (void) zoomViewIsNotResizable {
	[[self window] setContentMinSize: [zoomView frame].size];
}

- (BOOL) useSavePackage {
	// Using a save package allows us to restore games without needing to restart them first
	// It also allows us to show a preview in the iFiction window (ZoomView delegate method)
	return YES;
}

- (void) prepareSavePackage: (ZPackageFile*) file {
	NSMutableString* skeinXML = [[[[self document] skein] xmlData] mutableCopy];
	
	[skeinXML insertString: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
				   atIndex: 0];
	
	[file addData: [skeinXML dataUsingEncoding: NSUTF8StringEncoding]
	  forFilename: @"Skein.skein"];
	
	// Add information about our story ID
	[file addData: [NSPropertyListSerialization dataWithPropertyList: @{@"ZoomStoryId": [[[self document] storyId] description]}
															  format: NSPropertyListXMLFormat_v1_0
															 options: 0
															   error: nil]
													  forFilename: @"Info.plist"];
}

- (BOOL) loadedSkeinData: (NSData*) skeinData error:(NSError *__autoreleasing *)error {
	return [[[self document] skein] parseXmlData: skeinData error: error];
}

- (NSString*) defaultSaveDirectory {
	ZoomPreferences* prefs = [ZoomPreferences globalPreferences];
	
	if ([prefs keepGamesOrganised]) {
		// Get the directory for this game
		NSString* gameDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: [[self document] storyId]
																				  create: YES];
		NSString* saveDir = [gameDir stringByAppendingPathComponent: @"Saves"];
		
		BOOL isDir = NO;
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: saveDir
												  isDirectory: &isDir]) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath: saveDir
										   withIntermediateDirectories: NO
															attributes: nil
																 error: NULL]) {
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

- (void) showGamePreferences: (id) sender {
	ZoomPreferenceWindow* gamePrefs;
	
	gamePrefs = [[ZoomPreferenceWindow alloc] init];
	
	[NSApp beginSheet: [gamePrefs window]
	   modalForWindow: [self window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
    [NSApp runModalForWindow: [gamePrefs window]];
    [NSApp endSheet: [gamePrefs window]];
	
	[[gamePrefs window] orderOut: self];
}

#pragma mark - Setting up the game info window

- (IBAction) recordGameInfo: (id) sender {
	ZoomGameInfoController* sgI = [ZoomGameInfoController sharedGameInfoController];
	ZoomStory* storyInfo = [[self document] storyInfo];

	if ([sgI gameInfo] == storyInfo) {
		// Grr, annoying bug discovered here.
		// Previously we called [sgI title], etc directly here.
		// But, there was a case where the iFiction window could have become reactivated before this
		// call (didn't always happen, it seems, which is why I missed it). In this case, after the
		// title was set, the iFiction window would be notified that a change to the story settings
		// had occured, and update itself, AND THE GAMEINFO WINDOW, accordingly. Which replaced all
		// the rest of the settings with the settings of the currently selected game. DOH!
		NSDictionary* sgIValues = [sgI dictionary];
		
		[storyInfo setTitle: [sgIValues objectForKey: @"title"]];
		[storyInfo setHeadline: [sgIValues objectForKey: @"headline"]];
		[storyInfo setAuthor: [sgIValues objectForKey: @"author"]];
		[storyInfo setGenre: [sgIValues objectForKey: @"genre"]];
		[storyInfo setYear: [[sgIValues objectForKey: @"year"] intValue]];
		[storyInfo setGroup: [sgIValues objectForKey: @"group"]];
		[storyInfo setComment: [sgIValues objectForKey: @"comments"]];
		[storyInfo setTeaser: [sgIValues objectForKey: @"teaser"]];
		[storyInfo setZarfian: [[sgIValues objectForKey: @"zarfRating"] unsignedIntValue]];
		[storyInfo setRating: [[sgIValues objectForKey: @"rating"] floatValue]];
		
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	}
}

- (IBAction) updateGameInfo: (id) sender {
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
	}
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if (isFullscreen) {
		[self playInFullScreen: self];
	}
	
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[self recordGameInfo: self];

		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: nil];
	}
	
	if ([[ZoomNotesController sharedNotesController] infoOwner] == self) {
		[[ZoomNotesController sharedNotesController] setGameInfo: nil];
		[[ZoomNotesController sharedNotesController] setInfoOwner: nil];
	}
	
	if ([[ZoomSkeinController sharedSkeinController] skein] == [[self document] skein]) {
		[[ZoomSkeinController sharedSkeinController] setSkein: nil];
	}
}

- (BOOL) windowShouldClose: (id) sender {
	// Get confirmation if required
	if (!closeConfirmed && !finished && [[ZoomPreferences globalPreferences] confirmGameClose]) {
		BOOL autosave = [[ZoomPreferences globalPreferences] autosaveGames];
		NSString* msg;
		
		if (autosave) {
			msg = NSLocalizedString(@"There is still a story playing in this window. Are you sure you wish to finish it? The current state of the game will be automatically saved.", @"There is still a story playing in this window. Are you sure you wish to finish it? The current state of the game will be automatically saved.");
		} else {
			msg = NSLocalizedString(@"Finish game question info", @"There is still a story playing in this window. Are you sure you wish to finish it without saving? The current state of the game will be lost.");
		}
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"Finish the game?", @"Finish the game?");
		alert.informativeText = msg;
		[alert addButtonWithTitle: NSLocalizedString(@"Finish", @"Finish")];
		[alert addButtonWithTitle: NSLocalizedString(@"Continue playing", @"Continue playing")];
		[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == NSAlertFirstButtonReturn) {
				// Close the window
				self->closeConfirmed = YES;
				[[NSRunLoop currentRunLoop] performSelector: @selector(performClose:)
													 target: [self window]
												   argument: self
													  order: 32
													  modes: @[NSDefaultRunLoopMode]];
			}
		}];
		
		return NO;
	}
	
	// Record any game information
	[self recordGameInfo: self];
	
	// Record autosave data
	BOOL autosave = [[ZoomPreferences globalPreferences] autosaveGames];
	
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: [[self document] storyId]
																				  create: autosave];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	if (autosave) {
		NSKeyedArchiver* theCoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding: YES];
	
		BOOL saveOK = [zoomView createAutosaveDataWithCoder: theCoder];
	
		// Produce an autosave file
		if (saveOK) {
			[theCoder finishEncoding];
			NSData* autosaveData = theCoder.encodedData;
			[autosaveData writeToFile: autosaveFile atomically: YES];
		}
	} else {
		if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
			[[NSFileManager defaultManager] removeItemAtPath: autosaveFile
													   error: NULL];
		}
	}
		
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification {
	// Can't do stuff here: [self document] has been set to nil
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];

		[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: nil];
	}
	
	[[ZoomConnector sharedConnector] removeView: zoomView];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: self];
	
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [[self document] storyInfo]];
	[[ZoomSkeinController sharedSkeinController] setSkein: [[self document] skein]];
	[[zoomView textToSpeech] setSkein: [[self document] skein]];

	[[ZoomNotesController sharedNotesController] setGameInfo: [[self document] storyInfo]];
	[[ZoomNotesController sharedNotesController] setInfoOwner: self];
}

#pragma mark - GameInfo updates

- (IBAction) infoNameChanged: (id) sender {
	[[[self document] storyInfo] setTitle: [[ZoomGameInfoController sharedGameInfoController] title]];
}

- (IBAction) infoHeadlineChanged: (id) sender {
	[[[self document] storyInfo] setHeadline: [[ZoomGameInfoController sharedGameInfoController] headline]];
}

- (IBAction) infoAuthorChanged: (id) sender {
	[[[self document] storyInfo] setAuthor: [[ZoomGameInfoController sharedGameInfoController] author]];
}

- (IBAction) infoGenreChanged: (id) sender {
	[[[self document] storyInfo] setGenre: [[ZoomGameInfoController sharedGameInfoController] genre]];
}

- (IBAction) infoYearChanged: (id) sender {
	[[[self document] storyInfo] setYear: [[ZoomGameInfoController sharedGameInfoController] year]];
}

- (IBAction) infoGroupChanged: (id) sender {
	[[[self document] storyInfo] setGroup: [[ZoomGameInfoController sharedGameInfoController] group]];
}

- (IBAction) infoCommentsChanged: (id) sender {
	[[[self document] storyInfo] setComment: [[ZoomGameInfoController sharedGameInfoController] comments]];
}

- (IBAction) infoTeaserChanged: (id) sender {
	[[[self document] storyInfo] setTeaser: [[ZoomGameInfoController sharedGameInfoController] teaser]];
}

- (IBAction) infoZarfRatingChanged: (id) sender {
	[[[self document] storyInfo] setZarfian: [[ZoomGameInfoController sharedGameInfoController] zarfRating]];
}

- (IBAction) infoMyRatingChanged: (id) sender {
	[[[self document] storyInfo] setRating: [[ZoomGameInfoController sharedGameInfoController] rating]];
}

- (IBAction) infoResourceChanged: (id) sender {
	ZoomStory* story = [[self document] storyInfo];
	if (story == nil) return;
	
	// Update the resource path
	[story setObject: [[ZoomGameInfoController sharedGameInfoController] resourceFilename]
			  forKey: @"ResourceFilename"];
	
	// Perform organisation
	if ([[ZoomPreferences globalPreferences] keepGamesOrganised]) {
		[[ZoomStoryOrganiser sharedStoryOrganiser] organiseStory: story];
	}
}

#pragma mark - Various IB actions

- (IBAction) playInFullScreen: (id) sender {
	if (isFullscreen) {
		ZoomView *theView = zoomView;
		// Show the menubar
		[NSMenu setMenuBarVisible: YES];

		// Stop being fullscreen
		[theView removeFromSuperview];
		
		[theView setScaleFactor: 1.0];
		[theView setFrame: [[normalWindow contentView] bounds]];
		[[normalWindow contentView] addSubview: theView];
		
		// Swap windows back
		if (normalWindow) {
			[fullscreenWindow setDelegate: nil];
			[fullscreenWindow setInitialFirstResponder: nil];
			
			[normalWindow setDelegate: self];
			[normalWindow setWindowController: self];
			[self setWindow: normalWindow];
			[normalWindow setInitialFirstResponder: zoomView];
			[normalWindow makeKeyAndOrderFront: self];

			[fullscreenWindow orderOut: self];
		}
		
		[self setWindowFrameAutosaveName: @"ZoomClientWindow"];
		isFullscreen = NO;
	} else {
		// As of 10.4, we need to create a separate full-screen window (10.4 tries to be 'clever' with the window borders, which messes things up
		if (!normalWindow) normalWindow = [self window];
		if (!fullscreenWindow) {
			fullscreenWindow = [[ZoomWindowThatCanBecomeKey alloc] initWithContentRect: [[[self window] contentView] bounds] 
																				styleMask: NSWindowStyleMaskBorderless
																			   backing: NSBackingStoreBuffered
																				 defer: YES];
			
			[fullscreenWindow setLevel: NSFloatingWindowLevel];
			[fullscreenWindow setHidesOnDeactivate: YES];
			[fullscreenWindow setReleasedWhenClosed: NO];
			
			if (![fullscreenWindow canBecomeKeyWindow]) {
				[NSException raise: @"ZoomProgrammerIsASpoon"
							format: @"For some reason, the full screen window won't accept key"];
			}
		}
		
		// Swap the displayed windows over
		[self setWindowFrameAutosaveName: @""];
		[fullscreenWindow setFrame: [normalWindow frame]
						   display: NO];
		[fullscreenWindow makeKeyAndOrderFront: self];
		
		ZoomView *theView = zoomView;
		[theView removeFromSuperview];
		[[fullscreenWindow contentView] addSubview: theView];
		
		[normalWindow setInitialFirstResponder: nil];
		[normalWindow setDelegate: nil];

		NSView* newFirstResponder = [zoomView textView];
		if (newFirstResponder == nil) newFirstResponder = zoomView;
		[fullscreenWindow setInitialFirstResponder: newFirstResponder];
		[fullscreenWindow makeFirstResponder: newFirstResponder];
		[fullscreenWindow setDelegate: self];

		[fullscreenWindow setWindowController: self];
		[self setWindow: fullscreenWindow];
		
		// Start being fullscreen
		[[self window] makeKeyAndOrderFront: self];
		oldWindowFrame = [[self window] frame];
		
		// Finish off zoomView
		NSSize oldZoomViewSize = [zoomView frame].size;
		
		[zoomView removeFromSuperviewWithoutNeedingDisplay];
		
		// Hide the menubar
		[NSMenu setMenuBarVisible: NO];
				
		// Resize the window
		NSRect frame = [[[self window] screen] frame];
		if (![(ZoomAppDelegate*)[NSApp delegate] leopard]) {
			[[self window] setShowsResizeIndicator: NO];
			frame = [NSWindow frameRectForContentRect: frame
											styleMask: NSWindowStyleMaskBorderless];
			[[self window] setFrame: frame
							display: YES
							animate: YES];			
			[normalWindow orderOut: self];
		} else {
			[fullscreenWindow setOpaque: NO];
			[fullscreenWindow setBackgroundColor: [NSColor clearColor]];
			[[self window] setContentView: [[ClearView alloc] init]];
			[[self window] setFrame: frame
							display: YES
							animate: NO];
		}
		
		// Resize, reposition the zoomView
		NSRect newZoomViewFrame = [[[self window] contentView] bounds];
		NSRect newZoomViewBounds;
		
		newZoomViewBounds.origin = NSMakePoint(0,0);
		newZoomViewBounds.size   = newZoomViewFrame.size;
		
		double ratio = oldZoomViewSize.width/newZoomViewFrame.size.width;
		[zoomView setFrame: newZoomViewFrame];
		[zoomView setScaleFactor: ratio];
		
		// Add it back in again
		[[[self window] contentView] addSubview: zoomView];
		
		// Perform an animation in Leopard
		if ([(ZoomAppDelegate*)[NSApp delegate] leopard]) {
			[[(ZoomAppDelegate*)[NSApp delegate] leopard]
			 fullScreenView: zoomView
			 fromFrame: oldWindowFrame
			 toFrame: frame];			
		}
		
		isFullscreen = YES;
	}
}

#pragma mark - Showing a logo

- (NSImage*) resizeLogo: (NSImage*) input {
	NSSize oldSize = [input size];
	NSImage* result = input;
	
	if (oldSize.width > 256 || oldSize.height > 256) {
		CGFloat scaleFactor;
		
		if (oldSize.width > oldSize.height) {
			scaleFactor = 256/oldSize.width;
		} else {
			scaleFactor = 256/oldSize.height;
		}
		
		NSSize newSize = NSMakeSize(scaleFactor * oldSize.width, scaleFactor * oldSize.height);
		
		result = [[NSImage alloc] initWithSize: newSize];
		[result lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		
		[input drawInRect: NSMakeRect(0,0, newSize.width, newSize.height)
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
		[result unlockFocus];
	}
	
	return result;
}

- (NSImage*) logo {
	NSImage* result = [ZoomStoryOrganiser frontispieceForURL: [[self document] fileURL]];
	if (result == nil) return nil;
	
	return [self resizeLogo: result];
}

- (void) positionLogoWindow {
	// Position relative to the window
	NSRect frame = [[[self window] contentView] convertRect: [[[self window] contentView] bounds] toView: nil];
	NSRect windowFrame = [[self window] frame];
	
	// Position on screen
	frame.origin.x += windowFrame.origin.x;
	frame.origin.y += windowFrame.origin.y;
	
	// Position the logo window
	[logoWindow setFrame: frame
				 display: YES];
}

- (void) showLogoWindow {
	// Fading the logo out like this stops it from flickering
	waitTime = 1.0;
	fadeTime = 0.5;
	NSImage* logo = [self logo];
	
	if (logo == nil) return;
	if (logoWindow) return;
	if (fadeTimer) return;
	
	// Don't show this if this view is not on the screen
	if (![[ZoomPreferences globalPreferences] showCoverPicture]) return;
	if ([self window] == nil) return;
	if (![[self window] isVisible]) return;
	
	// Create the window
	logoWindow = [[NSWindow alloc] initWithContentRect: [[[self window] contentView] frame]				// Gets the size, we position later
											 styleMask: NSWindowStyleMaskBorderless
											   backing: NSBackingStoreBuffered
												 defer: YES];
	[logoWindow setOpaque: NO];
	[logoWindow setBackgroundColor: [NSColor clearColor]];
	
	// Create the image view that goes inside
	NSImageView* fadeContents = [[NSImageView alloc] initWithFrame: [[logoWindow contentView] frame]];
	
	[fadeContents setImage: logo];
	[logoWindow setContentView: fadeContents];
	
	fadeTimer = [NSTimer timerWithTimeInterval: waitTime
										target: self
									  selector: @selector(startToFadeLogo)
									  userInfo: nil
									   repeats: NO];
	[[NSRunLoop currentRunLoop] addTimer: fadeTimer
								 forMode: NSDefaultRunLoopMode];
	
	// Position the window correctly
	[self positionLogoWindow];
	
	// Show the window
	[logoWindow orderFront: self];
	[[self window] addChildWindow: logoWindow
						  ordered: NSWindowAbove];
}

- (void) startToFadeLogo {
	fadeTimer = nil;
	
	fadeTimer = [NSTimer timerWithTimeInterval: 0.01
										target: self
									  selector: @selector(fadeLogo)
									  userInfo: nil
									   repeats: YES];
	[[NSRunLoop currentRunLoop] addTimer: fadeTimer
								 forMode: NSDefaultRunLoopMode];
	
	fadeStart = [NSDate date];
}

- (void) fadeLogo {
	NSTimeInterval timePassed = [[NSDate date] timeIntervalSinceDate: fadeStart];
	CGFloat fadeAmount = timePassed/fadeTime;
	
	if (fadeAmount < 0 || fadeAmount > 1) {
		// Finished fading: get rid of the window + the timer
		[fadeTimer invalidate];
		fadeTimer = nil;
		
		[[logoWindow parentWindow] removeChildWindow: logoWindow];
		logoWindow = nil;
		
		fadeStart = nil;
	} else {
		fadeAmount = -2.0*fadeAmount*fadeAmount*fadeAmount + 3.0*fadeAmount*fadeAmount;
		
		[logoWindow setAlphaValue: 1.0 - fadeAmount];
	}
}

#pragma mark - Interacting with the skein

- (void) restartGame {
	 // Will force a restart
	 [[self zoomView] runNewServer: nil];
}

- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) fromPoint {
	 id<ZoomViewInputSource> inputSource = [ZoomSkein
											inputSourceFromSkeinItem: fromPoint
											toItem: point];
	 
	 
	 [[self zoomView] setInputSource: inputSource];
}

#pragma mark - Window title

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
	if (finished) {
		return [NSString stringWithFormat: NSLocalizedString(@"%@ (finished)", @"Game finished window title formatter"), displayName];
	}
	
	return displayName;
}

#pragma mark - Text to speech

- (IBAction) stopSpeakingMove: (id) sender {
	[[zoomView textToSpeech] beQuiet];
}

- (IBAction) speakMostRecent: (id) sender {
	[[zoomView textToSpeech] resetMoves];
	[[zoomView textToSpeech] speakLastText];
}

- (IBAction) speakNext: (id) sender {
	[[zoomView textToSpeech] speakNextMove];
}

- (IBAction) speakPrevious: (id) sender {
	[[zoomView textToSpeech] speakPreviousMove];
}

@end
