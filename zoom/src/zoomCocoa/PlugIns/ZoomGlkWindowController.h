//
//  ZoomGlkWindowController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkView.h>

#import <ZoomPlugIns/ZoomGameInfoController.h>

@class ZoomSkein;
@class ZoomTextToSpeech;

///
/// WindowController for windows running a Glk interpreter
///
@interface ZoomGlkWindowController : NSWindowController<NSWindowDelegate, GlkViewDelegate> {
	//! The view onto the game this controller is running
	IBOutlet GlkView* glkView;

	//! The panel that has log messages
	IBOutlet NSPanel* logPanel;
	//! The text contained in the drawer
	IBOutlet NSTextView* logText;
	
	//! The Glk executable we'll run to play this game
	NSString* clientPath;
	//! The file we'll pass to the executable as the game to run
	NSURL* inputURL;
	//! The .glksave folder to load
	NSURL* savedGameURL;
	//! YES if the plugin will actually load the save game
	BOOL canOpenSaveGames;
	//! YES if the sheet to warn about the fact that this plugin can't load games has been shown
	BOOL shownSaveGameWarning;
	//! The logo that we're going to show
	NSImage* logo;
	//! Whether or not the GlkView has the tts receiver added to it
	BOOL ttsAdded;
	//! Text-to-speech object
	ZoomTextToSpeech* tts;
	
	BOOL running;
	//! \c YES if the user has OKed closing the game while it's still running
	BOOL closeConfirmed;
	
	//! The skein/transcript for this window
	ZoomSkein* skein;
	
	//! YES if this window has been switched to full-screen mode
	BOOL isFullscreen;
	//! Cached version of the normal-sized window
	NSWindow* normalWindow;
	//! Cached version of the full-screen window
	NSWindow* fullscreenWindow;
	//! Size of the window before it became full-screen
	NSRect oldWindowFrame;
	
	//! The handler for the last save prompt that was presented
	id<GlkFilePrompt> promptHandler;
	//! The last save panel
	NSSavePanel* lastPanel;
}

// Configuring the client
//! Selects which GlkClient executable to run
- (void) setClientPath: (NSString*) clientPath;
//! The file that should be passed to the client as the file to run
- (void) setInputFileURL: (NSURL*) inputPath;
//! The logo to display instead of the 'CocoaGlk' logo
- (void) setLogo: (NSImage*) logo;
//! The .glksave saved game file URL that this controller should load on startup
- (void) setSaveGameURL: (NSURL*) path;
//! Set to \c YES if the plugin knows how to open save games
- (void) setCanOpenSaveGame: (BOOL) canOpenSaveGame;

@property (copy) NSImage *logo;

@end
