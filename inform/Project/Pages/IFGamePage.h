//
//  IFGamePage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"

@class GlkView;
@class IFSkeinView;
@class IFSkeinItem;
@class ZoomView;

//
// The 'game' page
//
#pragma mark - "Game Page"
@interface IFGamePage : IFPage

#pragma mark - Properties
@property (atomic, readonly, strong) ZoomView *   zoomView;       // The zoom view associated with the currently running game (NULL if a GLK game is running)
@property (atomic, readonly, strong) GlkView *    glkView;        // The glk view associated with the currently running game (if applicable)
@property (atomic, readonly)         BOOL         isRunningGame;  // YES if a game is running
@property (atomic, readonly)         BOOL         disableLogo;

#pragma mark - Methods
- (instancetype) initWithProjectController: (IFProjectController*) controller;

- (void) activateDebug;											// Notify that the next game run should be run with debugging on (breakpoints will be set)
- (void) setPointToRunTo: (IFSkeinItem*) item;                  // Sets the skein item to run to as soon as the game has started
- (void) setTestMe: (BOOL) willTestMe;							// Sets whether or not a 'test me' command should be generated (provided that there is no 'point to run to')
- (void) setTestCommands: (NSArray*) testCommands;              // Sets the list of commands to run (assuming there's no point to run to, and no testMe)
- (void) setSwitchToPage: (BOOL) switchToPage;                  // Do we want to switch to the game page?
- (BOOL) hasTestCommands;                                       // Do we have test commands?

- (void) startRunningGame: (NSString*) fileName;				// Starts running the game file with the given name in the game pane
- (void) stopRunningGame;										// Forcibly stops running the game
- (void) pauseRunningGame;										// Forcibly pauses the running game and enters the debugger

@end
