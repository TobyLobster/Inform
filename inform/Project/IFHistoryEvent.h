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

- (instancetype) init NS_UNAVAILABLE;
/// Initialise with the specified object as an invocation target
- (instancetype) initWithObject: (id) target NS_DESIGNATED_INITIALIZER;

// Building the invocation

/// The target for the proxy object; nil once the proxy has recorded an action
@property (atomic, readwrite, strong, nullable) id target;
/// The proxy object to use for this history item
@property (atomic, readonly, strong) id proxy;

/// Adds an action to the event, which replaying it performs after what was recorded before
- (void) addAction: (void (^)(void)) action;

// Replaying

/// Replays the event: performs its actions, and sends the messages sent to its proxy, in the order they were recorded
- (void) replay;

@end

NS_ASSUME_NONNULL_END
