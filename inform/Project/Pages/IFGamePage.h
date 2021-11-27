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

#pragma mark "Game Page"

///
/// The 'game' page
///
@interface IFGamePage : IFPage

#pragma mark - Properties
/// The zoom view associated with the currently running game (\c nil if a GLK game is running)
@property (atomic, readonly, strong) ZoomView *   zoomView;
/// The glk view associated with the currently running game (if applicable)
@property (atomic, readonly, strong) GlkView *    glkView;
/// \c YES if a game is running
@property (atomic, readonly)         BOOL         isRunningGame;

@property (atomic, readonly)         BOOL         disableLogo;

#pragma mark - Methods
- (instancetype) initWithProjectController: (IFProjectController*) controller;

/// Notify that the next game run should be run with debugging on (breakpoints will be set)
- (void) activateDebug;
/// Sets the skein item to run to as soon as the game has started
- (void) setPointToRunTo: (IFSkeinItem*) item;
/// Sets whether or not a 'test me' command should be generated (provided that there is no 'point to run to')
- (void) setTestMe: (BOOL) willTestMe;
/// Sets the list of commands to run (assuming there's no point to run to, and no testMe)
- (void) setTestCommands: (NSArray*) testCommands;
/// Do we want to switch to the game page?
- (void) setSwitchToPage: (BOOL) switchToPage;
/// Do we have test commands?
@property (atomic, readonly) BOOL hasTestCommands;

/// Starts running the game file with the given name in the game pane
- (void) startRunningGame: (NSString*) fileName;
/// Forcibly stops running the game
- (void) stopRunningGame;
/// Forcibly pauses the running game and enters the debugger
- (void) pauseRunningGame;

@end
