//
//  ZoomGlkWindowController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkView.h>

#import "ZoomGameInfoController.h"

@class ZoomSkein;
@class ZoomTextToSpeech;

///
/// WindowController for windows running a Glk interpreter
///
@interface ZoomGlkWindowController : NSWindowController {
	IBOutlet GlkView* glkView;										// The view onto the game this controller is running

	IBOutlet NSDrawer* logDrawer;									// The drawer that's opened while dealing with log messages
	IBOutlet NSTextView* logText;									// The text contained in the drawer
	
	NSString* clientPath;											// The Glk executable we'll run to play this game
	NSString* inputPath;											// The file we'll pass to the executable as the game to run
	NSString* savedGamePath;										// The .glksave folder to load
	BOOL canOpenSaveGames;											// YES if the plugin will actually load the save game
	BOOL shownSaveGameWarning;										// YES if the sheet to warn about the fact that this plugin can't load games has been shown
	NSImage* logo;													// The logo that we're going to show
	BOOL ttsAdded;													// Whether or not the GlkView has the tts receiver added to it
	ZoomTextToSpeech* tts;											// Text-to-speech object
	
	BOOL running;
	BOOL closeConfirmed;											// YES if the user has OKed closing the game while it's still running
	
	ZoomSkein* skein;												// The skein/transcript for this window
	
	BOOL isFullscreen;												// YES if this window has been switched to full-screen mode
	NSWindow* normalWindow;											// Cached version of the normal-sized window
	NSWindow* fullscreenWindow;										// Cached version of the full-screen window
	NSRect oldWindowFrame;											// Size of the window before it became full-screen
	
	NSObject<GlkFilePrompt>* promptHandler;							// The handler for the last save prompt that was presented
	NSSavePanel* lastPanel;											// The last save panel
}

// Configuring the client
- (void) setClientPath: (NSString*) clientPath;						// Selects which GlkClient executable to run
- (void) setInputFilename: (NSString*) inputPath;					// The file that should be passed to the client as the file to run
- (void) setLogo: (NSImage*) logo;									// The logo to display instead of the 'CocoaGlk' logo
- (void) setSaveGame: (NSString*) path;								// The .glksave saved game file that this controller should load on startup
- (void) setCanOpenSaveGame: (BOOL) canOpenSaveGame;				// Set to YES if the plugin knows how to open save games

@end
