//
//  IFGamePage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomViewProtocols.h>
#import "IFPage.h"

NS_ASSUME_NONNULL_BEGIN

@class GlkView;
@class IFPreferences;
@class IFSkeinItem;
@class ZoomView;

#pragma mark "Game Page"

///
/// The 'game' page
///
@interface IFGamePage : IFPage

#pragma mark - Properties
/// The zoom view associated with the currently running game (\c nil if a GLK game is running)
@property (atomic, readonly, strong, nullable) ZoomView *   zoomView;
/// The glk view associated with the currently running game (\c nil if a Z-Machine game is running)
@property (atomic, readonly, strong, nullable) GlkView *    glkView;
/// \c YES if a game is running
@property (atomic, readonly)                   BOOL         isRunningGame;

#pragma mark - Methods
- (instancetype) initWithProjectController: (nullable IFProjectController*) controller NS_DESIGNATED_INITIALIZER;

/// The scale factor of the Zoom view that shows a Z-machine story, for the app's text size in the given preferences
+ (CGFloat) zoomScaleFactorForPreferences: (IFPreferences*) preferences;

/// Notify that the next game run should be run with debugging on (breakpoints will be set)
- (void) activateDebug;
/// Sets the skein item to run to as soon as the game has started
- (void) setPointToRunTo: (nullable IFSkeinItem*) item;
/// Sets the list of commands to run, in the order they are typed (assuming there's no point to run to)
- (void) setTestCommands: (nullable NSArray<NSString*>*) testCommands;
/// An input source that types the test commands in order, for either kind of game, or \c nil if there are none.
/// The commands are cleared, so they are only typed once.
- (nullable id<ZoomViewInputSource>) takeTestCommands;
/// Do we want to switch to the game page?
- (void) setSwitchToPage: (BOOL) switchToPage;

/// Starts running the game file with the given name in the game pane
- (void) startRunningGame: (NSString*) fileName;
/// Forcibly stops running the game
- (void) stopRunningGame;

@end

NS_ASSUME_NONNULL_END
