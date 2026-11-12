//
//  IFHistoryEvent.h
//  Inform
//
//  Created by Andrew Hunter on 23/04/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


//
// This represents an event in the history of a project pane. (Ie, an action
// to perform when the backwards or forwards buttons are pressed)
//
NS_SWIFT_UI_ACTOR
@interface IFHistoryEvent : NSObject

// Initialisation

/// An event with no actions
- (instancetype) init NS_DESIGNATED_INITIALIZER;

// Recording

/// Adds an action to the event, which replaying it performs after those added before
- (void) addAction: (void (^)(void)) action;

// Replaying

/// Replays the event: performs its actions, in the order they were added
- (void) replay;

@end

NS_ASSUME_NONNULL_END
