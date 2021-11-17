//
//  ZoomGlkWindowController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkWindowController.h"
#import "ZoomPreferences.h"
#import <ZoomView/ZoomView-Swift.h>
#import "ZoomTextToSpeech.h"
#import "ZoomSkeinController.h"
#import "ZoomSkein.h"
#import "ZoomGlkDocument.h"
#import "ZoomGameInfoController.h"
#import "ZoomNotesController.h"
#import "ZoomWindowThatCanBecomeKey.h"
#import "ZoomGlkSaveRef.h"
#import "ZoomAppDelegate.h"
#import <ZoomPlugIns/ZoomPlugIns-swift.h>

#import <GlkView/GlkHub.h>
#import <GlkView/GlkView.h>
#import <GlkView/GlkSessionProtocol.h>
#import <GlkView/GlkFileRef.h>

///
/// Class to interface to Zoom's skein system
///
@interface ZoomGlkSkeinOutputReceiver : NSObject<GlkAutomation>{
	ZoomSkein* skein;
}

- (id) initWithSkein: (ZoomSkein*) skein;

@end

@implementation ZoomGlkSkeinOutputReceiver

- (id) initWithSkein: (ZoomSkein*) newSkein {
	self = [super init];
	
	if (self) {
		skein = newSkein;
	}
	
	return self;
}

- (IBAction) glkTaskHasStarted: (id) sender {
	[skein zoomInterpreterRestart];	
}

- (void) setGlkInputSource: (id) newSource {
}

- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view {
	[skein outputText: characters];
}

- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view {
	[skein zoomWaitingForInput];
	if (isLineInput) {
		[skein inputCommand: userInput];
	} else {
		[skein inputCharacter: userInput];
	}
}

- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view {
}

- (void) viewWaiting: (GlkView*) view {
	// Do nothing
}

- (void) viewIsWaitingForInput: (GlkView*) view {
}

@end

///
/// The window controller proper
///
@interface ZoomGlkWindowController(/*ZoomPrivate*/)

- (void) prefsChanged: (NSNotification*) not;

@end

@implementation ZoomGlkWindowController

+ (void) initialize {
	// Set up the Glk hub
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[GlkHub sharedGlkHub] useProcessHubName];
		[[GlkHub sharedGlkHub] setRandomHubCookie];
	});
}

#pragma mark - Preferences

+ (GlkPreferences*) glkPreferencesFromZoomPreferences {
	GlkPreferences* prefs = [[GlkPreferences alloc] init];
	ZoomPreferences* zPrefs = [ZoomPreferences globalPreferences];
	
	// Set the fonts according to the Zoom preferences object
	prefs.proportionalFont = zPrefs.fonts[0];
	prefs.fixedFont = zPrefs.fonts[4];
	
	// Set the typography options according to the Zoom preferences object
	prefs.textMargin = zPrefs.textMargin;
	prefs.useScreenFonts = zPrefs.useScreenFonts;
	prefs.useHyphenation = zPrefs.useHyphenation;
	prefs.useKerning = zPrefs.useKerning;
	prefs.useLigatures = zPrefs.useLigatures;
	
	prefs.scrollbackLength = zPrefs.scrollbackLength;
	
	// Set the foreground/background colours
	NSColor* foreground = zPrefs.colours[zPrefs.foregroundColour];
	NSColor* background = zPrefs.colours[zPrefs.backgroundColour];
	
	NSMutableDictionary* newStyles = [NSMutableDictionary dictionary];

	for (NSNumber* styleNum in [prefs styles]) {
		GlkStyle* thisStyle = [[prefs styles] objectForKey: styleNum];
		
		[thisStyle setTextColour: foreground];
		[thisStyle setBackColour: background];
		
		[newStyles setObject: thisStyle
					  forKey: styleNum];
	}
	
	[prefs setStyles: newStyles];
	
	return prefs;
}

#pragma mark - Initialisation

- (id) init {
	self = [super initWithWindowNibPath: [[NSBundle bundleForClass: [ZoomGlkWindowController class]] pathForResource: @"GlkWindow"
																											  ofType: @"nib"]
								  owner: self];
	
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												selector: @selector(prefsChanged:)
													 name: ZoomPreferences.preferencesHaveChangedNotification
												  object: nil];
		
		skein = [[ZoomSkein alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	if (glkView) [glkView setDelegate: nil];
}

- (void) maybeStartView {
	// If we're sufficiently configured to start the application, then do so
	if (glkView && clientPath && inputURL) {
		tts = [[ZoomTextToSpeech alloc] init];
		[tts setSkein: skein];

		[glkView setDelegate: self];
		[glkView addOutputReceiver: [[ZoomGlkSkeinOutputReceiver alloc] initWithSkein: skein]];
		[glkView setPreferences: [ZoomGlkWindowController glkPreferencesFromZoomPreferences]];
		[glkView setInputFileURL: inputURL];
		
		if (savedGameURL) {
			if (canOpenSaveGames) {
				NSURL* saveSkeinPath = [savedGameURL URLByAppendingPathComponent: @"Skein.skein" isDirectory: NO];
				NSURL* saveDataPath = [savedGameURL URLByAppendingPathComponent: @"Save.data" isDirectory: NO];

				if ([saveDataPath checkResourceIsReachableAndReturnError: NULL]) {
					[glkView addInputFileURL: saveDataPath
									 withKey: @"savegame"];
					
					if ([saveSkeinPath checkResourceIsReachableAndReturnError: NULL]) {
						[skein parseXMLContentsAtURL: saveSkeinPath error: NULL];
					}
				}
			}
		}
		
		[glkView launchClientApplication: clientPath
						   withArguments: [NSArray array]];
		
		[self prefsChanged: nil];
	}
}

- (IBAction)showWindow:(id)sender {
	[super showWindow: sender];
	
	if (savedGameURL && !canOpenSaveGames && !shownSaveGameWarning) {
		shownSaveGameWarning = YES;
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"This interpreter is unable to load saved states", @"This interpreter is unable to load saved states");
		alert.informativeText = NSLocalizedString(@"Interpreter can't load save games info", @"Due to a limitation in the design of the interpreter for this story, Zoom is unable to request that it load a saved state file.\n\nYou will need to use the story's own restore function to request that it load the state that you selected.");
		[alert addButtonWithTitle: NSLocalizedString(@"Continue", @"Continue")];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			//Do nothing
		}];
	}
}

- (void) windowDidLoad {
	// Configure the view
	[glkView setRandomViewCookie];
	
	// Set the default log message
	[logText setString: @"Zoom CocoaGlk Plugin\n"];
	
	// Set up the window borders
	if (![[ZoomPreferences globalPreferences] showGlkBorders])
		[glkView setBorderWidth: 0];
	else
		[glkView setBorderWidth: 2];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) prefsChanged: (NSNotification*) not {
	// TODO: actually change the preferences (might need some changes to the way Glk styles work here; styles are traditionally fixed after they are set...)
	if (glkView == nil) return;

	if (!ttsAdded) [glkView addOutputReceiver: tts];
	ttsAdded = YES;
	[tts setImmediate: [[ZoomPreferences globalPreferences] speakGameText]];
	
	// Set up the window borders
	if (![[ZoomPreferences globalPreferences] showGlkBorders])
		[glkView setBorderWidth: 0];
	else
		[glkView setBorderWidth: 2];
}

#pragma mark - Configuring the client

- (void) setClientPath: (NSString*) newPath {
	// Set the client path
	clientPath = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

- (void) setSaveGameURL: (NSURL*) path {
	// Set the saved game path
	savedGameURL = [path copy];
}

- (void) setCanOpenSaveGame: (BOOL) newCanOpenSaveGame {
	canOpenSaveGames = newCanOpenSaveGame;
}

- (void) setInputFileURL: (NSURL*) newPath {
	// Set the input path
	inputURL = [newPath copy];
	
	// Start it if we've got enough information
	[self maybeStartView];
}

@synthesize logo;

- (BOOL) disableLogo {
	return logo == nil || ![[ZoomPreferences globalPreferences] showCoverPicture];
}

- (NSURL*) preferredSaveDirectory {
	if (!canOpenSaveGames && savedGameURL) {
		// If the user has requested a particular save game and the interpreter doesn't know how to load it, then open the directory containing the game that they wanted
		return [savedGameURL URLByDeletingLastPathComponent];
	} else {
		// Otherwise use whatever the document thinks should be used
		return [[self document] preferredSaveDirectory];
	}
}

#pragma mark - Log messages

- (void) showLogMessage: (NSString*) message
			 withStatus: (GlkLogStatus) status {
	// Choose a style for this message
	CGFloat msgSize = 10;
	NSColor* msgColour = [NSColor systemGrayColor];
	BOOL isBold = NO;
	
	switch (status) {
		case GlkLogRoutine:
			break;
			
		case GlkLogInformation:
			isBold = YES;
			break;
			
		case GlkLogCustom:
			msgSize = 12;
			msgColour = [NSColor textColor];
			break;
			
		case GlkLogWarning:
			msgColour = [NSColor systemBlueColor];
			msgSize = 12;
			break;
			
		case GlkLogError:
			msgSize = 12;
			msgColour = [NSColor systemRedColor];
			isBold = YES;
			break;
			
		case GlkLogFatalError:
			msgSize = 12;
			msgColour = [NSColor systemOrangeColor];
			isBold = YES;
			break;
	}
	
	// Create the attributes for this style
	NSFont* font;
	
	if (isBold) {
		font = [NSFont boldSystemFontOfSize: msgSize];
	} else {
		font = [NSFont systemFontOfSize: msgSize];
	}
	
	NSDictionary* msgAttributes = @{NSFontAttributeName: font,
									NSForegroundColorAttributeName: msgColour};
	
	// Create the attributed string
	NSAttributedString* newMsg = [[NSAttributedString alloc] initWithString: [message stringByAppendingString: @"\n"]
																 attributes: msgAttributes];
	
	// Append this message to the log
	[[logText textStorage] beginEditing];
	[[logText textStorage] appendAttributedString: newMsg];
	[[logText textStorage] endEditing];
	
	// Show the log drawer
	if (status >= GlkLogWarning && (status >= GlkLogFatalError || [[ZoomPreferences globalPreferences] displayWarnings])) {
		[logPanel makeKeyAndOrderFront: self];
	}
}

- (void) showLog: (id) sender {
	[logPanel makeKeyAndOrderFront: self];
}

- (void) windowWillClose: (NSNotification*) not {
	[glkView terminateClient];
}

#pragma mark - The game info window

- (IBAction) recordGameInfo: (id) sender {
	ZoomGameInfoController* sgI = [ZoomGameInfoController sharedGameInfoController];
	ZoomStory* storyInfo = [(ZoomGlkDocument*)[self document] storyData];
	
	if ([sgI gameInfo] == storyInfo) {
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
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];
	}
}

#pragma mark - Gaining/losing focus

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomSkeinController sharedSkeinController] setSkein: skein];

	[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: self];
	[[ZoomGameInfoController sharedGameInfoController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];

	[[ZoomNotesController sharedNotesController] setGameInfo: [(ZoomGlkDocument*)[self document] storyData]];
	[[ZoomNotesController sharedNotesController] setInfoOwner: self];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[self recordGameInfo: self];
		
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: nil];
	}

	if ([[ZoomNotesController sharedNotesController] infoOwner] == self) {
		[[ZoomNotesController sharedNotesController] setGameInfo: nil];
		[[ZoomNotesController sharedNotesController] setInfoOwner: nil];
	}
	
	if ([[ZoomSkeinController sharedSkeinController] skein] == skein) {
		[[ZoomSkeinController sharedSkeinController] setSkein: nil];
	}
}

#pragma mark - Closing the window

- (BOOL) windowShouldClose: (id) sender {
	// Get confirmation if required
	if (!closeConfirmed && running && [[ZoomPreferences globalPreferences] confirmGameClose]) {
		//BOOL autosave = [[ZoomPreferences globalPreferences] autosaveGames];
		NSString* msg;
		
		msg = NSLocalizedString(@"Finish game question info", @"There is still a story playing in this window. Are you sure you wish to finish it without saving? The current state of the game will be lost.");
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"Finish the game?", @"Finish the game?");
		alert.informativeText = msg;
		[alert addButtonWithTitle: NSLocalizedString(@"Finish", @"Finish")];
		[alert addButtonWithTitle: NSLocalizedString(@"Continue playing", @"Continue playing")];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
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
	
	return YES;
}

#pragma mark - Going fullscreen

- (IBAction) playInFullScreen: (id) sender {
	if (isFullscreen) {
		// Show the menubar
		[NSMenu setMenuBarVisible: YES];
		
		// Stop being fullscreen
		__strong GlkView *tmpView = glkView;
		[tmpView removeFromSuperview];
		
		[tmpView setScaleFactor: 1.0];
		[tmpView setFrame: [[normalWindow contentView] bounds]];
		[[normalWindow contentView] addSubview: tmpView];
		tmpView = nil;
		
		// Swap windows back
		if (normalWindow) {
			[fullscreenWindow setDelegate: nil];
			[fullscreenWindow setInitialFirstResponder: nil];
			
			[normalWindow setDelegate: self];
			[normalWindow setWindowController: self];
			[self setWindow: normalWindow];
			[normalWindow setInitialFirstResponder: glkView];
			[normalWindow setFrame: oldWindowFrame
						   display: YES];
			[normalWindow makeKeyAndOrderFront: self];
			
			[fullscreenWindow orderOut: self];
			fullscreenWindow = nil;
 		}
		
		//[self setWindowFrameAutosaveName: @"ZoomClientWindow"];
		isFullscreen = NO;
	} else {
		// Do nothing if the game is not running
		if (!running) return;
		
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
			[fullscreenWindow setOpaque: NO];
			if ([(ZoomAppDelegate*)[NSApp delegate] leopard]) {
				[fullscreenWindow setBackgroundColor: [NSColor clearColor]];				
			}
			
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
		
		__strong GlkView *tmpView = glkView;
		[tmpView removeFromSuperview];
		[[fullscreenWindow contentView] addSubview: tmpView];
		tmpView = nil;
		
		[normalWindow setInitialFirstResponder: nil];
		[normalWindow setDelegate: nil];
		
		[fullscreenWindow setInitialFirstResponder: glkView];
		[fullscreenWindow makeFirstResponder: glkView];
		[fullscreenWindow setDelegate: self];
		
		[fullscreenWindow setWindowController: self];
		[self setWindow: fullscreenWindow];
		
		// Start being fullscreen
		[[self window] makeKeyAndOrderFront: self];
		oldWindowFrame = [[self window] frame];
		
		// Finish off glkView
		NSSize oldGlkViewSize = [glkView frame].size;
		
		tmpView = glkView;
		[tmpView removeFromSuperviewWithoutNeedingDisplay];
		
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
			[[self window] setContentView: [[ClearView alloc] init]];
			[[self window] setFrame: frame
							display: YES
							animate: NO];
		}
		
		// Resize, reposition the glkView
		NSRect newGlkViewFrame = [[[self window] contentView] bounds];
		NSRect newGlkViewBounds;
		
		newGlkViewBounds.origin = NSMakePoint(0,0);
		newGlkViewBounds.size   = newGlkViewFrame.size;
		
		double ratio = newGlkViewFrame.size.width/oldGlkViewSize.width;
		[tmpView setFrame: newGlkViewFrame];
		[tmpView setScaleFactor: ratio];
		
		// Add it back in again
		[[[self window] contentView] addSubview: tmpView];
		
		// Perform an animation in Leopard
		if ([(ZoomAppDelegate*)[NSApp delegate] leopard]) {
			[[(ZoomAppDelegate*)[NSApp delegate] leopard]
			 fullScreenView: glkView
			 fromFrame: oldWindowFrame
			 toFrame: frame];			
		}
		
		isFullscreen = YES;
	}
}

#pragma mark - Ending the game

- (void) taskHasStarted {
	[[self window] setDocumentEdited: YES];	
	
	running = YES;
	closeConfirmed = NO;
}

- (void) taskHasCrashed {
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (crashed)", [[self document] displayName], nil]];
}

- (void) taskHasFinished {
	if (isFullscreen) [self playInFullScreen: self];
	
	[[self window] setTitle: [NSString stringWithFormat: @"%@ (finished)", [[self document] displayName], nil]];	

	[[self window] setDocumentEdited: NO];
	running = NO;
}

#pragma mark - Saving the game

- (BOOL) promptForFilesForUsage: (NSString*) usage
					 forWriting: (BOOL) writing
						handler: (id<GlkFilePrompt>) handler
			 preferredDirectory: (NSURL*) preferredDirectory {
	if (![usage isEqualToString: GlkFileUsageSavedGame]) {
		// We only customise save game generation
		return NO;
	}
	
	// Remember the handler
	promptHandler = handler;
	
	// Create the prompt window
	if (writing) {
		// Create a save dialog
		NSSavePanel* panel = [NSSavePanel savePanel];
		
		panel.allowedFileTypes = @[@"glksave"];
		if (preferredDirectory != nil) [panel setDirectoryURL: preferredDirectory];
		
		[panel beginSheetModalForWindow: [self window] completionHandler: ^(NSModalResponse result) {
			[self panelDidEnd:panel returnCode:result];
		}];
		
		lastPanel = panel;
	} else {
		// Create an open dialog
		NSOpenPanel* panel = [NSOpenPanel openPanel];
		
		NSMutableArray* allowedFiletypes = [[glkView fileTypesForUsage: usage] mutableCopy];
		[allowedFiletypes insertObject: @"glksave"
							   atIndex: 0];
		
		if (preferredDirectory != nil) [panel setDirectoryURL: preferredDirectory];
		
		[panel setAllowedFileTypes: allowedFiletypes];
		
		[panel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
			[self panelDidEnd:panel returnCode:result];
		}];

		lastPanel = panel;
	}
	
	return YES;
}

- (void) panelDidEnd: (NSSavePanel*) panel
		  returnCode: (NSModalResponse) returnCode {
	if (!promptHandler) return;
	
	if (returnCode == NSModalResponseOK) {
		// TODO: preview
		if ([[[[panel URL] pathExtension] lowercaseString] isEqualToString: @"glksave"]) {
			ZoomGlkSaveRef* saveRef = [[ZoomGlkSaveRef alloc] initWithPlugIn: [[self document] plugIn]
																		path: [[panel URL] path]];
			[saveRef setSkein: skein];
			[promptHandler promptedFileRef: saveRef];
		} else {
			GlkFileRef* promptRef = [[GlkFileRef alloc] initWithPath: [panel URL]];
			[promptHandler promptedFileRef: promptRef];
		}
		
		[[NSUserDefaults standardUserDefaults] setURL: [panel directoryURL]
											   forKey: @"GlkSaveDirectory"];
		if ([self respondsToSelector: @selector(savePreferredDirectory:)]) {
			[self savePreferredDirectory: [[panel directoryURL] path]];
		}
	} else {
		[promptHandler promptCancelled];
	}
	
	promptHandler = nil;
	lastPanel = nil;
}

#pragma mark - Speech commands

- (IBAction) stopSpeakingMove: (id) sender {
	[tts beQuiet];
}

- (IBAction) speakMostRecent: (id) sender {
	[tts resetMoves];
	[tts speakLastText];
}

- (IBAction) speakNext: (id) sender {
	[tts speakNextMove];
}

- (IBAction) speakPrevious: (id) sender {
	[tts speakPreviousMove];
}

@end
