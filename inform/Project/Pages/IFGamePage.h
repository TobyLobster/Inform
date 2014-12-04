//
//  IFGamePage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"

#import <GlkView/GlkView.h>
#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomSkeinItem.h>

extern NSString* IFGlulxInterpreterName;						// The user defaults key that contains the glulx interpreter to use; if unset, the value in the plist is used

//
// The 'game' page
//
@interface IFGamePage : IFPage {
	GlkView*		 gView;										// The Glk (glulxe) view
    ZoomView*        zView;										// The Z-Machinev view
    NSString*        gameToRun;									// The filename of the game to start
	ZoomSkeinItem*   pointToRunTo;								// The skein item to run the game until	
	BOOL			 testMe;									// YES if we should send 'test me' as the first command to the game
	
	IFProgress*      gameRunningProgress;						// The progress indicator (how much we've compiled, how the game is running, etc)
    NSView*          semiTransparentView;
	
	BOOL             setBreakpoint;								// YES if we are allowed to set breakpoints
    BOOL             isRunningGame;
}

// The game view
- (void) activateDebug;											// Notify that the next game run should be run with debugging on (breakpoints will be set)
- (void) startRunningGame: (NSString*) fileName;				// Starts running the game file with the given name in the game pane
- (void) stopRunningGame;										// Forcibly stops running the game
- (void) pauseRunningGame;										// Forcibly pauses the running game and enters the debugger

- (ZoomView*) zoomView;											// The zoom view associated with the currently running game (NULL if a GLK game is running)
- (GlkView*) glkView;											// The glk view associated with the currently running game (if applicable)
- (BOOL) isRunningGame;											// YES if a game is running

- (void) setPointToRunTo: (ZoomSkeinItem*) item;				// Sets the skein item to run to as soon as the game has started
- (void) setTestMe: (BOOL) willTestMe;							// Sets whether or not a 'test me' command should be generated (provided that there is no 'point to run to')

- (id) initWithProjectController: (IFProjectController*) controller;

- (BOOL) disableLogo;

@end
